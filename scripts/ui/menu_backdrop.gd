extends Control
## Fondo animado de los menús: gradiente nocturno, polvo flotante, lluvia de píxeles,
## scanlines + viñeta + grano y relámpagos lejanos.
## main.gd mantiene UNA instancia viva mientras se navega por los menús, así la animación
## no se reinicia al pasar del menú principal a Cargar/Ajustes.

const C = preload("res://scripts/ui/ui_colors.gd")

const OVERLAY_SHADER_CODE: String = """
shader_type canvas_item;
uniform float scan_strength = 0.10;
uniform float vignette_strength = 0.80;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	float line = step(1.5, mod(FRAGCOORD.y, 3.0));
	float d = distance(UV, vec2(0.5));
	float vig = smoothstep(0.30, 0.85, d) * vignette_strength;
	float g = hash(floor(FRAGCOORD.xy / 2.0) + floor(TIME * 12.0));
	float speck = step(0.993, g);
	float a = clamp(line * scan_strength + vig, 0.0, 1.0);
	a = max(a, speck * 0.10);
	vec3 rgb = mix(vec3(0.0), vec3(0.75, 0.78, 0.90), speck);
	COLOR = vec4(rgb, a);
}
"""

var _rain: CPUParticles2D
var _dust: CPUParticles2D
var _flash: ColorRect
var _flash_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var base: ColorRect = ColorRect.new()
	base.color = C.BG_DEEP
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([C.BG_TOP, C.BG_BOTTOM])
	var grad_tex: GradientTexture2D = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	grad_tex.width = 8
	grad_tex.height = 256
	var sky: TextureRect = TextureRect.new()
	sky.texture = grad_tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dust = _make_dust()
	add_child(_dust)
	_rain = _make_rain()
	add_child(_rain)
	_layout()
	get_viewport().size_changed.connect(_layout)

	var overlay: ColorRect = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = OVERLAY_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	overlay.material = mat
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_flash = ColorRect.new()
	_flash.color = Color(0.70, 0.75, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_on_flash_timer)
	add_child(_flash_timer)
	_flash_timer.start(randf_range(5.0, 10.0))


func _make_rain() -> CPUParticles2D:
	var img: Image = Image.create_empty(2, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.62, 0.82, 0.55))
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = 160
	p.lifetime = 1.8
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(-0.18, 1.0)
	p.spread = 2.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 650.0
	p.initial_velocity_max = 900.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.particle_flag_align_y = true
	return p


func _make_dust() -> CPUParticles2D:
	var img: Image = Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.75, 0.75, 0.90, 1.0))
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35),
		Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0),
	])
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = 45
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2(0.0, -2.0)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 18.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = fade
	return p


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_rain.position = Vector2(vp.x * 0.5, -20.0)
	_rain.emission_rect_extents = Vector2(vp.x * 0.5 + 250.0, 1.0)
	_dust.position = vp * 0.5
	_dust.emission_rect_extents = vp * 0.5


func _on_flash_timer() -> void:
	# Relámpago lejano: dos destellos tenues.
	var t: Tween = create_tween()
	t.tween_property(_flash, "color:a", 0.10, 0.05)
	t.tween_property(_flash, "color:a", 0.0, 0.25)
	t.tween_property(_flash, "color:a", 0.06, 0.05)
	t.tween_property(_flash, "color:a", 0.0, 0.60)
	_flash_timer.start(randf_range(7.0, 15.0))
