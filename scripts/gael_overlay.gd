extends Control
## Gael_19 asomándose por el borde izquierdo mientras se chatea con él (historia de Romina).
##
## - Sprite pegado al extremo izquierdo: solo se ve el 70% del ancho, el 30% izquierdo queda
##   fuera de pantalla (como si se asomara).
## - Opacidad 75%.
## - Luz azul de celular que sube desde abajo (shader), con un parpadeo muy sutil.
## - Tamaño y altura como los de Dialogic: alto de pantalla completo + offset del personaje.
## Va DENTRO del layout de Dialogic, justo antes de la caja de texto: sobre fondo y retratos,
## pero por debajo de la caja. main.gd lo coloca ahí y lo muestra/oculta según quién habla.
## (Si fuera una CanvasLayer aparte quedaría por encima de la caja de texto.)

const TEX_GAEL: String = "res://assets/characters/Generic Bad Man/Generic Bad Man.png"
const OFFSET_Y: float = 200.0            # offset del personaje en gael_19.dch
const VISIBLE_FRACTION: float = 0.7      # fracción del ancho que se ve (30% fuera por la izquierda)
const OPACIDAD: float = 0.75
const FADE_IN: float = 0.5
const SLIDE_OUT: float = 0.7             # lo que tarda en deslizarse fuera de pantalla

const SHADER_CODE: String = """
shader_type canvas_item;
uniform vec3 luz : source_color = vec3(0.30, 0.55, 1.0);
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform float altura : hint_range(0.0, 1.0) = 0.35;   // desde dónde empieza a subir la luz
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float k = smoothstep(altura, 1.0, UV.y);                  // más fuerte abajo
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float parpadeo = 0.92 + 0.08 * sin(TIME * 2.6);
	vec3 base = c.rgb * vec3(0.62, 0.68, 0.92);               // el resto queda en penumbra azulada
	vec3 ilum = luz * k * fuerza * parpadeo * (0.35 + 0.65 * lum) * 1.1;
	c.rgb = base + ilum;
	COLOR = c;
}
"""

var _sprite: TextureRect = null
var _material: ShaderMaterial = null
var _tween: Tween = null
var _x_final: float = 0.0
var _x_fuera: float = 0.0                # posición totalmente fuera de pantalla (a la izquierda)
var _visible_on: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load(TEX_GAEL) as Texture2D
	if tex == null:
		push_warning("[Gael] No se encontró el sprite de Gael_19.")
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tam: Vector2 = tex.get_size()
	var escala: float = vp.y / tam.y
	var tam_pantalla: Vector2 = tam * escala

	_sprite = TextureRect.new()
	_sprite.texture = tex
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.size = tam_pantalla
	# 30% del ancho fuera de pantalla por la izquierda.
	_x_final = -tam_pantalla.x * (1.0 - VISIBLE_FRACTION)
	_x_fuera = -tam_pantalla.x - 20.0
	_sprite.position = Vector2(_x_fuera, vp.y + OFFSET_Y * escala - tam_pantalla.y)

	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("fuerza", 0.0)
	_sprite.material = _material
	_sprite.modulate.a = 0.0
	add_child(_sprite)


## Muestra (true) o esconde (false) a Gael con animación. Idempotente.
func mostrar(activo: bool) -> void:
	if _sprite == null or activo == _visible_on:
		return
	_visible_on = activo
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if activo:
		_tween.tween_property(_sprite, "modulate:a", OPACIDAD, FADE_IN)
		_tween.tween_property(_sprite, "position:x", _x_final, FADE_IN) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_fuerza, _fuerza_actual(), 1.0, FADE_IN * 1.4)
	else:
		# Se desliza entero hacia la izquierda hasta salir de pantalla; recién entonces desaparece.
		_tween.tween_property(_sprite, "position:x", _x_fuera, SLIDE_OUT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(_sprite, "modulate:a", 0.0, 0.01).set_delay(SLIDE_OUT)
		_tween.tween_method(_set_fuerza, _fuerza_actual(), 0.0, 0.0).set_delay(SLIDE_OUT)


## Lo esconde de golpe (menú principal, minijuegos...).
func ocultar_ya() -> void:
	if _sprite == null:
		return
	_visible_on = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_sprite.modulate.a = 0.0
	_sprite.position.x = _x_fuera
	_set_fuerza(0.0)


func _fuerza_actual() -> float:
	return float(_material.get_shader_parameter("fuerza")) if _material != null else 0.0


func _set_fuerza(v: float) -> void:
	if _material != null:
		_material.set_shader_parameter("fuerza", v)
