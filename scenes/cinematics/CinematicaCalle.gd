extends CanvasLayer
## Cinemática in-game: Darwin caminando de noche por la calle (previa al minijuego 2).
##
## - Mundo (cielo morado, farolas lejanas, lluvia ligera, suelo) dibujado en baja resolución
##   (1/4) y escalado sin filtro para el look pixel art. Darwin va encima a resolución completa.
## - Darwin usa el sprite "Broken" en el centro, con el mismo tamaño y offset que le da Dialogic
##   (contenedor "center": altura de pantalla completa, origen abajo al centro, offset (0, 200)).
## - Camina de frente: rebote vertical suave y un leve balanceo.
## - Una farola lenta cruza por arriba: cuando pasa sobre él lo ilumina y luego lo deja en sombra.
## No emite señales: main.gd la crea y la libera.

const TEX_DARWIN: String = "res://assets/characters/Darwin/Darwin Broken.png"
const TEX_DARWIN_RAGE: String = "res://assets/characters/Darwin/Darwin Rage.png"
const SHAKE_PX: float = 4.0              # vibración de furia (minijuego 2)
const SHAKE_INTERVAL: float = 0.035
const DARWIN_OFFSET_Y: float = 400.0      # offset del personaje en darwin.dch
const PIXEL_SHRINK: int = 4               # el mundo se dibuja a 1/4 de resolución

# --- Caminata ---
const STEP_HZ: float = 0.85               # ciclos de rebote por segundo
const BOB_PX: float = 12.0

# --- Farola que cruza ---
const LAMP_PERIOD: float = 10.0           # segundos por pasada
const LAMP_START: float = 0.04            # fase inicial (0..1)
const LIT: Color = Color(1.0, 0.93, 0.82)
const SHADOW: Color = Color(0.40, 0.40, 0.66)
const LAMP_WARM: Color = Color(1.0, 0.82, 0.55)

# --- Cielo (de arriba a abajo) ---
const SKY_TOP: Color = Color(0.17, 0.15, 0.47)
const SKY_MID: Color = Color(0.30, 0.23, 0.60)
const SKY_LOW: Color = Color(0.52, 0.37, 0.68)
const SKY_HORIZON: Color = Color(0.70, 0.52, 0.72)
const GROUND_FAR: Color = Color(0.22, 0.16, 0.42)
const GROUND_NEAR: Color = Color(0.07, 0.05, 0.17)
const TREE: Color = Color(0.09, 0.07, 0.26, 0.9)

const RAIN_COUNT: int = 46
const DUST_COUNT: int = 36

# --- Ambiente opresivo / ira ---
const ZOOM_MAX: float = 0.07              # empuje de camara lento hacia Darwin
const ZOOM_TAU: float = 28.0
const SWAY_PX: float = 4.0                # vaiven de camara
const HEART_PERIOD: float = 1.2           # latido en calma...
const HEART_PERIOD_FURY: float = 0.6      # ...y desbocado en furia
const HEART_ZOOM: float = 0.006
const FURIA_ZOOM: float = 0.03            # la camara se cierra sobre el cuando se enfurece
const IMPACTO_ZOOM: float = 0.035         # golpe de camara al estallar la furia
const CAM_SHAKE_PX: float = 5.0           # temblor de camara en furia
const TINTE_FURIA: Color = Color(1.0, 0.6, 0.64)   # el mundo se tine de rojo
const ROJO_IRA: Color = Color(0.9, 0.08, 0.12)
const STATIC_LAYER: int = 85              # sobre la cinematica (80), bajo el minijuego (90)
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

# Sprite de Darwin. main.gd puede cambiarlo antes de añadir la escena (p. ej. el camino a la
# escuela usa la expresión inexpresiva).
var textura_darwin: String = TEX_DARWIN
# Pulso (latido de cámara, viñeta y destello). Se desactiva en el camino a la escuela; el
# minijuego 2 lo usa.
var con_pulso: bool = true

var _t: float = 0.0
var _mundo: Control
var _darwin: TextureRect
var _glow: TextureRect
var _raiz: Control
var _cont: SubViewportContainer
var _vineta: TextureRect
var _rojo: TextureRect
var _static_rect: ColorRect
var _static_mat: ShaderMaterial
var _furia_amt: float = 0.0               # 0..1, suavizado
var _impacto: float = 0.0
var _static_pico: float = 0.0
var _fase_latido: float = 0.0
var _cam_shake: Vector2 = Vector2.ZERO
var _cam_timer: float = 0.0
var _darwin_base: Vector2 = Vector2.ZERO
var _tex_normal: Texture2D = null
var _tex_rage: Texture2D = null
var _furia: bool = false
var _shake: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0
var _vp: Vector2 = Vector2(1920, 1080)
var _lamp_x: float = 0.0                  # en píxeles de pantalla
var _lamp_alpha: float = 0.0
var _light: float = 0.0
var _grain: PackedVector2Array = PackedVector2Array()
var _grain_timer: float = 0.0
var _rain: Array[Vector3] = []            # x, y, velocidad (en píxeles del mundo)
var _dust: Array[Vector3] = []            # x, y, fase


func _ready() -> void:
	_vp = get_viewport().get_visible_rect().size
	_t = LAMP_START * LAMP_PERIOD

	var raiz: Control = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP     # que el clic no avance el diálogo
	add_child(raiz)
	_raiz = raiz
	raiz.pivot_offset = _vp * 0.5

	# Mundo en baja resolución.
	var contenedor: SubViewportContainer = SubViewportContainer.new()
	_cont = contenedor
	contenedor.stretch = true
	contenedor.stretch_shrink = PIXEL_SHRINK
	contenedor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(contenedor)

	var sub: SubViewport = SubViewport.new()
	sub.transparent_bg = false
	sub.handle_input_locally = false
	contenedor.add_child(sub)

	_mundo = Control.new()
	_mundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mundo.draw.connect(_dibujar_mundo)
	sub.add_child(_mundo)

	_crear_darwin(raiz)
	_crear_glow(raiz)
	_crear_vineta(raiz)
	_crear_sombras_extra(raiz)
	_crear_estatica()
	_iniciar_particulas()


# ──────────────────────────────────────────────
# CONSTRUCCIÓN
# ──────────────────────────────────────────────

func _crear_darwin(raiz: Control) -> void:
	_tex_normal = load(textura_darwin) as Texture2D
	_tex_rage = load(TEX_DARWIN_RAGE) as Texture2D
	if _tex_normal == null:
		push_warning("[Cinemática] No se encontró el sprite de Darwin.")
		return

	_darwin = TextureRect.new()
	_darwin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_darwin.stretch_mode = TextureRect.STRETCH_SCALE
	_darwin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_darwin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_darwin)
	_aplicar_sprite(_tex_normal)


## Coloca el sprite igual que Dialogic: altura de pantalla completa, origen abajo al centro y
## offset del personaje (escalado). Cada sprite se ajusta por su propio tamaño.
func _aplicar_sprite(tex: Texture2D) -> void:
	var tam: Vector2 = tex.get_size()
	var escala: float = _vp.y / tam.y
	var tam_pantalla: Vector2 = tam * escala
	_darwin.texture = tex
	_darwin.size = tam_pantalla
	_darwin_base = Vector2(_vp.x * 0.5 - tam_pantalla.x * 0.5, _vp.y + (DARWIN_OFFSET_Y * escala) - tam_pantalla.y)
	_darwin.position = _darwin_base
	_darwin.pivot_offset = Vector2(tam_pantalla.x * 0.5, tam_pantalla.y)


## Furia (marcador fuera de la zona en el minijuego 2): sprite "Rage" y vibración.
func set_furia(activa: bool) -> void:
	if activa == _furia or _darwin == null:
		return
	_furia = activa
	if activa:
		_impacto = 1.0        # golpe de camara
		_static_pico = 1.0    # y una rafaga de estatica
	if activa and _tex_rage != null:
		_aplicar_sprite(_tex_rage)
	else:
		_aplicar_sprite(_tex_normal)
		_shake = Vector2.ZERO


func _crear_glow(raiz: Control) -> void:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(LAMP_WARM, 0.55), Color(LAMP_WARM, 0.14), Color(LAMP_WARM, 0.0)
	])
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256

	_glow = TextureRect.new()
	_glow.texture = gtex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = Vector2(1300, 1300)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	raiz.add_child(_glow)


func _crear_vineta(raiz: Control) -> void:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.40, 1.0])
	grad.colors = PackedColorArray([Color(0.0, 0.0, 0.05, 0.0), Color(0.0, 0.0, 0.05, 0.85)])
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	var vineta: TextureRect = TextureRect.new()
	vineta.texture = gtex
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vineta = vineta
	raiz.add_child(vineta)


## Sombra pesada desde arriba y destello rojo de ira en los bordes (solo visible en furia).
func _crear_sombras_extra(raiz: Control) -> void:
	var g1: Gradient = Gradient.new()
	g1.offsets = PackedFloat32Array([0.0, 0.5])
	g1.colors = PackedColorArray([Color(0.0, 0.0, 0.04, 0.6), Color(0.0, 0.0, 0.04, 0.0)])
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
	raiz.add_child(techo)

	var g2: Gradient = Gradient.new()
	g2.offsets = PackedFloat32Array([0.25, 1.0])
	g2.colors = PackedColorArray([Color(ROJO_IRA, 0.0), Color(ROJO_IRA, 0.6)])
	var t2: GradientTexture2D = GradientTexture2D.new()
	t2.gradient = g2
	t2.fill = GradientTexture2D.FILL_RADIAL
	t2.fill_from = Vector2(0.5, 0.5)
	t2.fill_to = Vector2(1.0, 0.5)
	t2.width = 256
	t2.height = 256
	_rojo = TextureRect.new()
	_rojo.texture = t2
	_rojo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rojo.stretch_mode = TextureRect.STRETCH_SCALE
	_rojo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rojo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rojo.modulate.a = 0.0
	raiz.add_child(_rojo)


## Estatica por encima de la cinematica y por debajo del minijuego (rafaga al enfurecer).
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


## Camara y ambiente: empuje lento, vaiven, latido (mas rapido en furia), temblor, tinte rojo.
func _atmosfera(delta: float) -> void:
	_furia_amt = move_toward(_furia_amt, 1.0 if _furia else 0.0, delta * 2.5)
	_impacto = maxf(0.0, _impacto - delta * 2.2)
	_static_pico = maxf(0.0, _static_pico - delta * 1.8)

	var periodo: float = lerpf(HEART_PERIOD, HEART_PERIOD_FURY, _furia_amt)
	_fase_latido = fposmod(_fase_latido + delta / periodo, 1.0)
	var latido: float = exp(-pow(_fase_latido * 9.0, 2.0)) + 0.6 * exp(-pow((_fase_latido - 0.22) * 9.0, 2.0))
	if not con_pulso:
		latido = 0.0

	var zoom: float = 1.0 + ZOOM_MAX * (1.0 - exp(-_t / ZOOM_TAU)) \
			+ HEART_ZOOM * latido * (1.0 + _furia_amt) + FURIA_ZOOM * _furia_amt + IMPACTO_ZOOM * _impacto
	_raiz.scale = Vector2(zoom, zoom)

	_cam_timer -= delta
	if _cam_timer <= 0.0:
		_cam_timer = SHAKE_INTERVAL
		_cam_shake = Vector2(randf_range(-CAM_SHAKE_PX, CAM_SHAKE_PX), randf_range(-CAM_SHAKE_PX, CAM_SHAKE_PX))
	_raiz.position = Vector2(sin(_t * 0.37) * SWAY_PX, cos(_t * 0.29) * SWAY_PX * 0.6) + _cam_shake * _furia_amt

	_cont.modulate = Color.WHITE.lerp(TINTE_FURIA, _furia_amt * 0.75)
	_vineta.modulate.a = clampf(0.9 + 0.1 * latido + 0.2 * _furia_amt, 0.0, 1.0)
	_rojo.modulate.a = _furia_amt * (0.45 + 0.55 * latido)

	var fuerza: float = _furia_amt * 0.08 + _static_pico * 0.45
	_static_rect.visible = fuerza > 0.005
	_static_mat.set_shader_parameter("strength", clampf(fuerza, 0.0, 1.0))


func _iniciar_particulas() -> void:
	var w: float = _vp.x / float(PIXEL_SHRINK)
	var h: float = _vp.y / float(PIXEL_SHRINK)
	for i: int in RAIN_COUNT:
		_rain.append(Vector3(randf() * w, randf() * h, randf_range(150.0, 230.0)))
	for i: int in DUST_COUNT:
		_dust.append(Vector3(randf() * w, randf() * h * 0.8, randf() * TAU))


# ──────────────────────────────────────────────
# ANIMACIÓN
# ──────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_atmosfera(delta)

	# Farola que cruza: va de izquierda a derecha por arriba.
	var u: float = fposmod(_t, LAMP_PERIOD) / LAMP_PERIOD
	_lamp_x = lerpf(-0.12, 1.12, u) * _vp.x
	var borde: float = minf(smoothstep(0.0, 0.08, u), smoothstep(1.0, 0.92, u))
	_lamp_alpha = borde
	var ancho: float = _vp.x * 0.20
	var d: float = (_lamp_x - _vp.x * 0.5) / ancho
	_light = exp(-d * d) * borde

	# Caminata: rebote suave (dos pasos por ciclo) y balanceo lateral.
	if _darwin != null:
		var fase: float = _t * TAU * STEP_HZ
		var paso: float = absf(sin(fase))
		if _furia:
			_shake_timer -= delta
			if _shake_timer <= 0.0:
				_shake_timer = SHAKE_INTERVAL
				_shake = Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX) * 0.6)
		_darwin.position = _darwin_base + Vector2(0.0, -paso * BOB_PX) + _shake
		_darwin.scale = Vector2(1.0, 1.0 - 0.005 * (1.0 - paso))
		_darwin.modulate = SHADOW.lerp(LIT, _light).lerp(Color(1.0, 0.5, 0.52), _furia_amt * 0.4)

	# Halo de la farola (aditivo, sobre Darwin).
	if _glow != null:
		var ly: float = _lamp_y_pantalla(u)
		_glow.position = Vector2(_lamp_x, ly) - _glow.size * 0.5
		_glow.modulate.a = _lamp_alpha

	# Lluvia, polvo y grano.
	var w: float = _vp.x / float(PIXEL_SHRINK)
	var h: float = _vp.y / float(PIXEL_SHRINK)
	for i: int in _rain.size():
		var r: Vector3 = _rain[i]
		r.y += r.z * delta
		r.x += r.z * delta * 0.22
		if r.y > h or r.x > w + 10.0:
			r = Vector3(randf() * w * 1.1 - 20.0, -8.0, randf_range(150.0, 230.0))
		_rain[i] = r
	for i: int in _dust.size():
		var p: Vector3 = _dust[i]
		p.x += (sin(_t * 0.4 + p.z) * 3.0 + 2.0) * delta
		p.y += (cos(_t * 0.3 + p.z) * 2.0 + 1.0) * delta
		if p.x > w:
			p.x = 0.0
		if p.y > h:
			p.y = 0.0
		_dust[i] = p
	_grain_timer -= delta
	if _grain_timer <= 0.0:
		_grain_timer = 0.09
		_grain.clear()
		for i: int in 80:
			_grain.append(Vector2(floorf(randf() * w), floorf(randf() * h)))

	_mundo.queue_redraw()


func _lamp_y_pantalla(u: float) -> float:
	# La lámpara está fuera de cámara, por encima del borde superior.
	var arco: float = 1.0 - pow(2.0 * u - 1.0, 2.0)
	return -_vp.y * 0.07 + arco * 14.0


# ──────────────────────────────────────────────
# DIBUJO DEL MUNDO (baja resolución)
# ──────────────────────────────────────────────

func _dibujar_mundo() -> void:
	var s: Vector2 = _mundo.size
	var w: float = s.x
	var h: float = s.y
	var hy: float = h * 0.62                   # horizonte
	var cx: float = w * 0.5
	var u: float = fposmod(_t, LAMP_PERIOD) / LAMP_PERIOD
	var lx: float = _lamp_x / float(PIXEL_SHRINK)
	var ly: float = _lamp_y_pantalla(u) / float(PIXEL_SHRINK)

	# Cielo en bandas (posterizado).
	var paso_y: float = 2.0
	var y: float = 0.0
	while y < hy:
		var tt: float = floorf((y / hy) * 16.0) / 16.0
		_mundo.draw_rect(Rect2(0.0, y, w, paso_y), _color_cielo(tt))
		y += paso_y

	# Siluetas de árboles a los lados.
	_dibujar_arboles(w, hy)

	# Suelo.
	y = hy
	while y < h:
		var tt: float = (y - hy) / (h - hy)
		_mundo.draw_rect(Rect2(0.0, y, w, paso_y), GROUND_FAR.lerp(GROUND_NEAR, floorf(tt * 8.0) / 8.0))
		y += paso_y
	_dibujar_calle(w, h, hy, cx)

	# Luz de la farola (fuera de cámara) que cruza por arriba.
	if _lamp_alpha > 0.01:
		_dibujar_luz_farola(lx, ly, h)

	# Polvo flotante, lluvia y grano.
	for p: Vector3 in _dust:
		_mundo.draw_rect(Rect2(floorf(p.x), floorf(p.y), 1.0, 1.0), Color(0.85, 0.8, 1.0, 0.22))
	for r: Vector3 in _rain:
		_mundo.draw_line(Vector2(floorf(r.x), floorf(r.y)), Vector2(floorf(r.x - 1.0), floorf(r.y - 5.0)),
				Color(0.80, 0.80, 0.97, 0.30), 1.0)
	for g: Vector2 in _grain:
		_mundo.draw_rect(Rect2(g, Vector2.ONE), Color(1.0, 0.95, 1.0, 0.10))


func _color_cielo(t: float) -> Color:
	if t < 0.45:
		return SKY_TOP.lerp(SKY_MID, t / 0.45)
	if t < 0.8:
		return SKY_MID.lerp(SKY_LOW, (t - 0.45) / 0.35)
	return SKY_LOW.lerp(SKY_HORIZON, (t - 0.8) / 0.2)


func _dibujar_arboles(w: float, hy: float) -> void:
	for lado: int in 2:
		var base_x: float = 0.0 if lado == 0 else w
		var dir: float = 1.0 if lado == 0 else -1.0
		for j: int in 4:
			var bx: float = base_x + dir * (6.0 + float(j) * 15.0) + sin(_t * 0.5 + float(j) + float(lado)) * 0.8
			var by: float = hy - 34.0 - float(j % 2) * 22.0
			_mundo.draw_circle(Vector2(bx, by), 26.0 - float(j) * 2.0, TREE)
			_mundo.draw_rect(Rect2(bx - 2.0, by, 4.0, hy - by + 6.0), TREE)


func _dibujar_calle(w: float, h: float, hy: float, cx: float) -> void:
	var linea: Color = Color(0.62, 0.52, 0.85, 0.16)
	# Líneas transversales que se acercan (da sensación de avanzar).
	for i: int in 8:
		var z: float = fposmod(float(i) / 8.0 + _t * 0.06, 1.0)
		var yy: float = hy + (h - hy) * z * z
		_mundo.draw_line(Vector2(0.0, floorf(yy)), Vector2(w, floorf(yy)), Color(linea, linea.a * z), 1.0)
	# Bordes de la acera hacia el punto de fuga.
	for lado: float in [-1.0, 1.0]:
		_mundo.draw_line(Vector2(cx + lado * 18.0, hy), Vector2(cx + lado * w * 0.62, h), linea, 1.0)


func _dibujar_luz_farola(lx: float, ly: float, h: float) -> void:
	var a: float = _lamp_alpha
	# Haz de luz que baja desde fuera de cámara.
	var haz: PackedVector2Array = PackedVector2Array([
		Vector2(lx - 6.0, ly), Vector2(lx + 6.0, ly), Vector2(lx + 95.0, h), Vector2(lx - 95.0, h)
	])
	_mundo.draw_colored_polygon(haz, Color(LAMP_WARM, 0.07 * a))
	# Resplandor que entra por el borde superior (la lámpara no se ve).
	_mundo.draw_circle(Vector2(lx, ly), 78.0, Color(LAMP_WARM, 0.06 * a))
	_mundo.draw_circle(Vector2(lx, ly), 54.0, Color(LAMP_WARM, 0.10 * a))
	_mundo.draw_circle(Vector2(lx, ly), 32.0, Color(LAMP_WARM, 0.16 * a))
