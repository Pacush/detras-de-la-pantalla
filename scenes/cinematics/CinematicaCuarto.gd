extends CanvasLayer
## Cinemática in-game: Romina inquieta y abrumada en su cuarto (fondo del minijuego 2 de Romina).
##
## - Fondo: room-romina-2.png a pantalla completa, oscurecido y enfriado, con un empuje de cámara
##   muy lento hacia ella, un leve vaivén y latidos que hacen "pulsar" toda la escena.
## - Romina en el centro con el mismo tamaño y offset que le da Dialogic (contenedor "center":
##   altura de pantalla completa, origen abajo al centro, offset (0, 200)).
## - Luz azul del celular que sube desde abajo (mismo shader que Gael_19), con parpadeos y
##   destellos de notificación; resplandor azul en la parte baja de la pantalla.
## - "Romina Uneasy" mira a la izquierda: se voltea a intervalos aleatorios (0.5–3 s) y respira
##   de forma pesada: crece suave y vuelve algo más rápido.
## - Viñeta muy cerrada que late, sombra pesada desde arriba y polvo azul flotando.
## - registrar_fallo(): muestra "Romina Broken" 1 s con vibración de 4 px, una ráfaga de estática
##   (mitad de intensa que romina_estatica), un golpe de cámara y un destello rojizo. Luego
##   vuelve sola al bucle inquieto.
## No emite señales: main.gd la crea y la libera.

const TEX_FONDO: String = "res://assets/backgrounds/room-romina-2.png"
const TEX_UNEASY: String = "res://assets/characters/Romina/Romina Uneasy.png"
const TEX_BROKEN: String = "res://assets/characters/Romina/Romina Broken.png"
const ROMINA_OFFSET_Y: float = 400.0      # offset del personaje en romina.dch

# --- Inquietud (volteo) ---
const FLIP_MIN: float = 0.5
const FLIP_MAX: float = 3.0

# --- Respiración pesada ---
const BREATH_PERIOD: float = 4.4          # segundos por ciclo
const BREATH_RISE: float = 0.6            # fracción del ciclo que dura la inhalación (lenta)
const BREATH_AMOUNT: float = 0.035        # cuánto crece (3.5 %)

# --- Ambiente opresivo ---
const FONDO_TINTE: Color = Color(0.46, 0.5, 0.74)   # fondo oscuro y frío
const ZOOM_MAX: float = 0.08              # empuje de cámara lento (8 %)
const ZOOM_TAU: float = 30.0              # lo rápido que se acerca (segundos)
const SWAY_PX: float = 4.0                # vaivén de la cámara
const HEART_PERIOD: float = 1.15          # segundos por latido
const HEART_ZOOM: float = 0.007           # cuánto "late" la escena
const LUZ_AZUL: Color = Color(0.30, 0.55, 1.0)
const LUZ_ROJA: Color = Color(1.0, 0.25, 0.3)
const DUST_COUNT: int = 46

# --- Fallo ---
const BROKEN_TIME: float = 1.0
const SHAKE_PX: float = 4.0
const SHAKE_INTERVAL: float = 0.035
const IMPACTO_ZOOM: float = 0.03          # golpe de cámara al fallar
const STATIC_LAYER: int = 85              # sobre la cinemática (80), bajo el minijuego (90)
const STATIC_PEAK: float = 0.5            # la mitad de la intensidad de romina_estatica (1.0)

# Luz azul de celular desde abajo (mismo efecto que Gael_19, más intenso y con destellos).
const ROMINA_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec3 luz : source_color = vec3(0.30, 0.55, 1.0);
uniform float fuerza : hint_range(0.0, 2.0) = 1.0;
uniform float altura : hint_range(0.0, 1.0) = 0.30;   // desde donde empieza a subir la luz
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float k = smoothstep(altura, 1.0, UV.y);                  // mas fuerte abajo
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 base = c.rgb * vec3(0.55, 0.60, 0.86);               // el resto queda en penumbra azulada
	vec3 ilum = luz * k * fuerza * (0.35 + 0.65 * lum) * 1.25;
	c.rgb = base + ilum;
	COLOR = c;
}
"""

# Misma estatica que romina_estatica en main.gd.
const STATIC_SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 18.0);
	float band = floor(uv.y * 28.0);
	float torn = step(0.55, hash(vec2(band + 7.0, t)));
	float shift = (hash(vec2(band, t)) - 0.5) * 0.12 * strength * torn;
	vec2 suv = vec2(uv.x + shift, uv.y);
	float ca = 0.012 * strength;
	float r = texture(screen_tex, suv + vec2(ca, 0.0)).r;
	float g = texture(screen_tex, suv).g;
	float b = texture(screen_tex, suv - vec2(ca, 0.0)).b;
	vec3 col = vec3(r, g, b);
	float n = hash(floor(FRAGCOORD.xy / 3.0) + t);
	col = mix(col, vec3(n), strength * 0.45);
	COLOR = vec4(col, 1.0);
}
"""

var _t: float = 0.0                       # fase de la respiración (arranca al azar)
var _vivo: float = 0.0                    # tiempo desde que empezó la cinemática
var _vp: Vector2 = Vector2(1920, 1080)
var _raiz: Control
var _romina: TextureRect
var _romina_mat: ShaderMaterial = null
var _glow: TextureRect
var _vineta: TextureRect
var _polvo: Control
var _base: Vector2 = Vector2.ZERO
var _tex_uneasy: Texture2D = null
var _tex_broken: Texture2D = null
var _mirando_derecha: bool = false        # el sprite original mira a la izquierda
var _flip_timer: float = 1.0
var _broken_timer: float = 0.0
var _shake: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0
var _impacto: float = 0.0                 # golpe del ultimo fallo (decae solo)
var _destello: float = 0.0                # destello de notificacion (decae solo)
var _destello_timer: float = 2.0
var _motas: Array[Vector3] = []           # x, y, fase (en pixeles de pantalla)
var _static_mat: ShaderMaterial = null
var _static_rect: ColorRect = null
var _static_tween: Tween = null


func _ready() -> void:
	_vp = get_viewport().get_visible_rect().size
	_flip_timer = randf_range(FLIP_MIN, FLIP_MAX)
	_t = randf() * BREATH_PERIOD   # no siempre arranca en el mismo punto de la respiración
	_destello_timer = randf_range(1.5, 3.5)

	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP     # que el clic no avance el diálogo
	_raiz.pivot_offset = _vp * 0.5
	add_child(_raiz)

	var fondo: TextureRect = TextureRect.new()
	fondo.texture = load(TEX_FONDO) as Texture2D
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.modulate = FONDO_TINTE
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fondo)

	_crear_romina()
	_crear_glow()
	_crear_polvo()
	_crear_sombras()
	_crear_estatica()

	for i: int in DUST_COUNT:
		_motas.append(Vector3(randf() * _vp.x, randf() * _vp.y, randf() * TAU))


func _crear_romina() -> void:
	_tex_uneasy = load(TEX_UNEASY) as Texture2D
	_tex_broken = load(TEX_BROKEN) as Texture2D
	if _tex_uneasy == null:
		push_warning("[Cinemática] No se encontró el sprite Romina Uneasy.")
		return
	_romina = TextureRect.new()
	_romina.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_romina.stretch_mode = TextureRect.STRETCH_SCALE
	_romina.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_romina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = ROMINA_SHADER_CODE
	_romina_mat = ShaderMaterial.new()
	_romina_mat.shader = shader
	_romina.material = _romina_mat
	_raiz.add_child(_romina)
	_aplicar_sprite(_tex_uneasy)


## Coloca el sprite igual que Dialogic: altura de pantalla completa, origen abajo al centro y
## offset del personaje (escalado). Cada sprite se ajusta por su propio tamaño.
func _aplicar_sprite(tex: Texture2D) -> void:
	var tam: Vector2 = tex.get_size()
	var escala: float = _vp.y / tam.y
	var tam_pantalla: Vector2 = tam * escala
	_romina.texture = tex
	_romina.size = tam_pantalla
	_base = Vector2(_vp.x * 0.5 - tam_pantalla.x * 0.5, _vp.y + (ROMINA_OFFSET_Y * escala) - tam_pantalla.y)
	_romina.position = _base
	_romina.pivot_offset = Vector2(tam_pantalla.x * 0.5, tam_pantalla.y)   # voltea y respira desde los pies


## Resplandor azul del celular que sube desde el borde inferior (aditivo).
func _crear_glow() -> void:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85)])
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 8
	gtex.height = 256
	_glow = TextureRect.new()
	_glow.texture = gtex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.size = Vector2(_vp.x, _vp.y * 0.6)
	_glow.position = Vector2(0.0, _vp.y * 0.4)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_raiz.add_child(_glow)


func _crear_polvo() -> void:
	_polvo = Control.new()
	_polvo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_polvo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_polvo.draw.connect(_dibujar_polvo)
	_raiz.add_child(_polvo)


## Sombra pesada desde arriba y viñeta muy cerrada (que late).
func _crear_sombras() -> void:
	# Techo: oscuro arriba, se desvanece hacia el centro.
	var g1: Gradient = Gradient.new()
	g1.offsets = PackedFloat32Array([0.0, 0.5])
	g1.colors = PackedColorArray([Color(0.0, 0.0, 0.04, 0.62), Color(0.0, 0.0, 0.04, 0.0)])
	var t1: GradientTexture2D = GradientTexture2D.new()
	t1.gradient = g1
	t1.fill = GradientTexture2D.FILL_LINEAR
	t1.fill_from = Vector2(0.5, 0.0)
	t1.fill_to = Vector2(0.5, 1.0)
	t1.width = 8
	t1.height = 256
	var techo: TextureRect = TextureRect.new()
	techo.texture = t1
	techo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	techo.stretch_mode = TextureRect.STRETCH_SCALE
	techo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	techo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(techo)

	var g2: Gradient = Gradient.new()
	g2.offsets = PackedFloat32Array([0.30, 1.0])
	g2.colors = PackedColorArray([Color(0.0, 0.0, 0.04, 0.0), Color(0.0, 0.0, 0.04, 0.9)])
	var t2: GradientTexture2D = GradientTexture2D.new()
	t2.gradient = g2
	t2.fill = GradientTexture2D.FILL_RADIAL
	t2.fill_from = Vector2(0.5, 0.5)
	t2.fill_to = Vector2(1.0, 0.5)
	t2.width = 256
	t2.height = 256
	_vineta = TextureRect.new()
	_vineta.texture = t2
	_vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vineta.stretch_mode = TextureRect.STRETCH_SCALE
	_vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(_vineta)


func _crear_estatica() -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.layer = STATIC_LAYER
	add_child(capa)
	_static_rect = ColorRect.new()
	_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_static_rect)
	_static_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = Shader.new()
	shader.code = STATIC_SHADER_CODE
	_static_mat = ShaderMaterial.new()
	_static_mat.shader = shader
	_static_mat.set_shader_parameter("strength", 0.0)
	_static_rect.material = _static_mat
	_static_rect.visible = false


# ──────────────────────────────────────────────
# FALLO
# ──────────────────────────────────────────────

## Se llama cada vez que se suma un fallo en el minijuego.
func registrar_fallo() -> void:
	if _romina == null:
		return
	if _tex_broken != null:
		_aplicar_sprite(_tex_broken)
	_broken_timer = BROKEN_TIME
	_shake_timer = 0.0
	_impacto = 1.0
	_lanzar_estatica()


## Ráfaga de estática a media intensidad (misma forma que romina_estatica, comprimida a ~1 s).
func _lanzar_estatica() -> void:
	if _static_tween != null and _static_tween.is_valid():
		_static_tween.kill()
	_static_rect.visible = true
	var fijar: Callable = func(v: float) -> void: _static_mat.set_shader_parameter("strength", v)
	_static_tween = create_tween()
	_static_tween.tween_method(fijar, 0.0, STATIC_PEAK, 0.08)
	_static_tween.tween_interval(0.25)
	_static_tween.tween_method(fijar, STATIC_PEAK, STATIC_PEAK * 0.55, 0.1)
	_static_tween.tween_method(fijar, STATIC_PEAK * 0.55, STATIC_PEAK, 0.07)
	_static_tween.tween_method(fijar, STATIC_PEAK, 0.0, 0.5)
	_static_tween.tween_callback(func() -> void: _static_rect.visible = false)


# ──────────────────────────────────────────────
# ANIMACIÓN
# ──────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_vivo += delta
	_impacto = maxf(0.0, _impacto - delta * 2.2)
	_destello = maxf(0.0, _destello - delta * 3.0)

	# Latido doble (pum-pum) que hace pulsar la escena.
	var ph: float = fposmod(_vivo / HEART_PERIOD, 1.0)
	var latido: float = exp(-pow(ph * 9.0, 2.0)) + 0.6 * exp(-pow((ph - 0.22) * 9.0, 2.0))

	# Cámara: empuje lento hacia ella + vaivén + latido + golpe al fallar.
	var zoom: float = 1.0 + ZOOM_MAX * (1.0 - exp(-_vivo / ZOOM_TAU)) + HEART_ZOOM * latido + IMPACTO_ZOOM * _impacto
	_raiz.scale = Vector2(zoom, zoom)
	_raiz.position = Vector2(sin(_vivo * 0.37) * SWAY_PX, cos(_vivo * 0.29) * SWAY_PX * 0.6)

	# Destellos de notificación del celular.
	_destello_timer -= delta
	if _destello_timer <= 0.0:
		_destello_timer = randf_range(1.2, 4.0)
		_destello = randf_range(0.5, 1.0)
	var parpadeo: float = 0.9 + 0.1 * sin(_vivo * 2.6) + 0.05 * sin(_vivo * 17.0)
	var luz: float = (0.95 * parpadeo + 0.5 * _destello + 0.15 * latido) * (1.0 + 0.3 * _impacto)

	# Resplandor inferior (se tiñe de rojo con el golpe) y viñeta que late.
	_glow.self_modulate = Color(LUZ_AZUL.lerp(LUZ_ROJA, clampf(_impacto * 0.8, 0.0, 1.0)), clampf(0.30 * luz, 0.0, 1.0))
	_vineta.modulate.a = clampf(0.88 + 0.12 * latido + 0.25 * _impacto, 0.0, 1.0)

	# Polvo azul que sube despacio.
	for i: int in _motas.size():
		var m: Vector3 = _motas[i]
		m.y -= (8.0 + 6.0 * sin(m.z)) * delta
		m.x += sin(_vivo * 0.5 + m.z) * 6.0 * delta
		if m.y < -6.0:
			m = Vector3(randf() * _vp.x, _vp.y + 6.0, randf() * TAU)
		_motas[i] = m
	_polvo.queue_redraw()

	if _romina == null:
		return

	_romina_mat.set_shader_parameter("fuerza", luz)
	_romina_mat.set_shader_parameter("luz", LUZ_AZUL.lerp(LUZ_ROJA, clampf(_impacto * 0.7, 0.0, 1.0)))

	var roto: bool = _broken_timer > 0.0
	if roto:
		_broken_timer -= delta
		_shake_timer -= delta
		if _shake_timer <= 0.0:
			_shake_timer = SHAKE_INTERVAL
			_shake = Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX))
		if _broken_timer <= 0.0:
			# Vuelve al bucle inquieto.
			_shake = Vector2.ZERO
			_aplicar_sprite(_tex_uneasy)
			_flip_timer = randf_range(FLIP_MIN, FLIP_MAX)
			roto = false
	else:
		_flip_timer -= delta
		if _flip_timer <= 0.0:
			_flip_timer = randf_range(FLIP_MIN, FLIP_MAX)
			_mirando_derecha = not _mirando_derecha

	# Respiración: inhala lento y exhala un poco más rápido, ambos suaves.
	var u: float = fposmod(_t, BREATH_PERIOD) / BREATH_PERIOD
	var k: float
	if u < BREATH_RISE:
		k = smoothstep(0.0, 1.0, u / BREATH_RISE)
	else:
		k = 1.0 - smoothstep(0.0, 1.0, (u - BREATH_RISE) / (1.0 - BREATH_RISE))
	var crece: float = 1.0 + BREATH_AMOUNT * k

	_romina.scale = Vector2(-crece if _mirando_derecha else crece, crece)
	_romina.position = _base + (_shake if roto else Vector2.ZERO)


func _dibujar_polvo() -> void:
	for m: Vector3 in _motas:
		var a: float = 0.10 + 0.14 * (0.5 + 0.5 * sin(_vivo * 1.3 + m.z))
		var lado: float = 2.0 if sin(m.z * 3.0) > 0.0 else 3.0
		_polvo.draw_rect(Rect2(floorf(m.x), floorf(m.y), lado, lado), Color(0.55, 0.75, 1.0, a))
