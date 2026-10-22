extends Control
## Menú principal — estética pixel art sombría y melancólica.
##
## Todo el estilo se construye en código (colores, fuentes, partículas, shader)
## para que la escena quede simple y los nodos conserven sus nombres.

signal start_new_game
signal load_game
signal show_settings
signal quit_game

const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")

# ── Paleta: azules grisáceos apagados con acento lavanda ──
const COL_BG_TOP: Color = Color(0.10, 0.12, 0.19, 1.0)
const COL_BG_BOTTOM: Color = Color(0.02, 0.02, 0.05, 1.0)
const COL_TITLE: Color = Color(0.78, 0.76, 0.90, 1.0)
const COL_TEXT: Color = Color(0.82, 0.82, 0.93, 1.0)
const COL_TEXT_DISABLED: Color = Color(0.35, 0.36, 0.45, 1.0)
const COL_ACCENT: Color = Color(0.72, 0.68, 0.88, 1.0)
const COL_BTN_BG: Color = Color(0.07, 0.08, 0.12, 0.88)
const COL_BTN_BG_HOVER: Color = Color(0.13, 0.12, 0.19, 0.95)
const COL_BTN_BORDER: Color = Color(0.24, 0.26, 0.36, 1.0)
const COL_BTN_BORDER_HOVER: Color = Color(0.72, 0.68, 0.88, 1.0)
const COL_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.7)
const COL_GLOW: Color = Color(0.55, 0.45, 0.85, 0.45)
const COL_BTN_DIM: Color = Color(0.78, 0.78, 0.85, 1.0)

const TITLE_FONT_SIZE: int = 84
const BUTTON_FONT_SIZE: int = 28
const BUTTON_HEIGHT: float = 64.0
const MARKER_SIZE: float = 12.0

const GHOST_A_BASE: Vector2 = Vector2(5, 4)
const GHOST_B_BASE: Vector2 = Vector2(-5, 2)

## Scanlines + viñeta + grano parpadeante, todo en un solo overlay.
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

@onready var buttons_container: VBoxContainer = $VBoxContainer
@onready var title: Label = $Title
@onready var background: ColorRect = $Background

var _rain: CPUParticles2D
var _dust: CPUParticles2D
var _flash: ColorRect
var _flash_timer: Timer
var _glitch_timer: Timer
var _ghost_a: Label
var _ghost_b: Label
var _divider: Control
var _mouse_driven: bool = false


func _ready() -> void:
	_build_atmosphere()
	_style_title()
	_style_buttons()

	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	_play_intro()


func _input(event: InputEvent) -> void:
	# Si el jugador usa teclado/gamepad, el resaltado deja de seguir al mouse.
	if event is InputEventKey or event is InputEventJoypadButton:
		_mouse_driven = false


# ──────────────────────────────────────────────
# ATMÓSFERA: gradiente, lluvia, polvo, overlay y relámpagos
# ──────────────────────────────────────────────

func _build_atmosphere() -> void:
	var insert_at: int = background.get_index() + 1

	# Gradiente vertical sobre el color base
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([COL_BG_TOP, COL_BG_BOTTOM])
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
	move_child(sky, insert_at)

	# Polvo flotante lento (detrás de la lluvia)
	_dust = _make_dust()
	add_child(_dust)
	move_child(_dust, insert_at + 1)

	# Lluvia de píxeles
	_rain = _make_rain()
	add_child(_rain)
	move_child(_rain, insert_at + 2)

	_layout_atmosphere()
	get_viewport().size_changed.connect(_layout_atmosphere)

	# Overlay final (scanlines + viñeta + grano) y flash de relámpago
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


func _layout_atmosphere() -> void:
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


# ──────────────────────────────────────────────
# TÍTULO: sombras desfasadas, glitch ocasional, respiración
# ──────────────────────────────────────────────

func _style_title() -> void:
	title.add_theme_font_override("font", PIX_FONT)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", COL_TITLE)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 1.0))
	title.add_theme_constant_override("outline_size", 8)

	_ghost_a = _make_ghost(Color(0.45, 0.25, 0.55, 0.60))
	_ghost_b = _make_ghost(Color(0.20, 0.42, 0.55, 0.50))
	_set_ghost_offset(_ghost_a, GHOST_A_BASE)
	_set_ghost_offset(_ghost_b, GHOST_B_BASE)

	# Línea divisoria pixelada bajo el título con un rombo central
	_divider = Control.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.anchor_left = 0.5
	_divider.anchor_right = 0.5
	_divider.offset_left = -180.0
	_divider.offset_right = 180.0
	_divider.offset_top = 232.0
	_divider.offset_bottom = 236.0
	_divider.pivot_offset = Vector2(180.0, 2.0)
	add_child(_divider)

	var line: ColorRect = ColorRect.new()
	line.color = Color(0.35, 0.33, 0.50, 0.85)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var gem: ColorRect = ColorRect.new()
	gem.color = COL_ACCENT
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size = Vector2(12, 12)
	gem.position = Vector2(180.0 - 6.0, 2.0 - 6.0)
	gem.pivot_offset = Vector2(6, 6)
	gem.rotation = PI / 4.0
	_divider.add_child(gem)

	_glitch_timer = Timer.new()
	_glitch_timer.one_shot = true
	_glitch_timer.timeout.connect(_on_glitch_timer)
	add_child(_glitch_timer)
	_glitch_timer.start(randf_range(3.0, 6.0))


func _make_ghost(col: Color) -> Label:
	var g: Label = Label.new()
	g.text = title.text
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_behind_parent = true
	g.add_theme_font_override("font", PIX_FONT)
	g.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	g.add_theme_color_override("font_color", col)
	title.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return g


func _set_ghost_offset(ghost: Label, v: Vector2) -> void:
	ghost.offset_left = v.x
	ghost.offset_right = v.x
	ghost.offset_top = v.y
	ghost.offset_bottom = v.y


func _jitter_ghosts(dx: float, dy: float) -> void:
	_set_ghost_offset(_ghost_a, GHOST_A_BASE + Vector2(dx, dy))
	_set_ghost_offset(_ghost_b, GHOST_B_BASE - Vector2(dx, dy))
	title.modulate.a = 0.75


func _reset_ghosts() -> void:
	_set_ghost_offset(_ghost_a, GHOST_A_BASE)
	_set_ghost_offset(_ghost_b, GHOST_B_BASE)
	title.modulate.a = 1.0


func _on_glitch_timer() -> void:
	var t: Tween = create_tween()
	for _i in range(4):
		t.tween_callback(_jitter_ghosts.bind(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0)))
		t.tween_interval(0.04)
	t.tween_callback(_reset_ghosts)
	_glitch_timer.start(randf_range(3.5, 7.0))


func _start_title_breathing() -> void:
	var t: Tween = create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(title, "modulate:a", 0.80, 2.4)
	t.tween_property(title, "modulate:a", 1.0, 2.4)


# ──────────────────────────────────────────────
# BOTONES
# ──────────────────────────────────────────────

func _style_buttons() -> void:
	for child: Node in buttons_container.get_children():
		var btn: Button = child as Button
		if btn != null:
			_style_button(btn)


func _make_button_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COL_BTN_BG
	s.border_color = COL_BTN_BORDER
	s.set_border_width_all(4)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = 54.0
	s.content_margin_right = 16.0
	# Sombra dura estilo pixel art; al resaltar se vuelve un resplandor.
	s.shadow_color = COL_SHADOW
	s.shadow_size = 1
	s.shadow_offset = Vector2(4, 4)
	return s


func _style_button(btn: Button) -> void:
	var style: StyleBoxFlat = _make_button_style()
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var disabled_style: StyleBoxFlat = _make_button_style()
	disabled_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
	disabled_style.border_color = Color(0.15, 0.16, 0.22, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_font_override("font", PIX_FONT)
	btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(color_name, COL_TEXT)
	btn.add_theme_color_override("font_disabled_color", COL_TEXT_DISABLED)

	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.modulate = COL_BTN_DIM

	# Marcador cuadrado que aparece al resaltar
	var marker: ColorRect = ColorRect.new()
	marker.color = COL_ACCENT
	marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	marker.position = Vector2(10.0, 0.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.modulate.a = 0.0
	btn.add_child(marker)

	btn.set_meta("style", style)
	btn.set_meta("marker", marker)

	btn.resized.connect(_on_button_resized.bind(btn))
	btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))
	btn.focus_entered.connect(_animate_button.bind(btn, true, false))
	btn.focus_exited.connect(_animate_button.bind(btn, false, false))
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))


func _on_button_resized(btn: Button) -> void:
	var marker: ColorRect = btn.get_meta("marker")
	marker.position.y = (btn.size.y - MARKER_SIZE) / 2.0
	btn.pivot_offset = Vector2(0.0, btn.size.y / 2.0)


func _on_button_mouse_entered(btn: Button) -> void:
	if btn.disabled:
		return
	_mouse_driven = true
	btn.grab_focus()


func _on_button_mouse_exited(btn: Button) -> void:
	# Con mouse, el resaltado se apaga al salir; con teclado se conserva.
	if _mouse_driven and btn.has_focus():
		btn.release_focus()


func _on_button_down(btn: Button) -> void:
	_animate_button(btn, true, true)


func _on_button_up(btn: Button) -> void:
	_animate_button(btn, btn.has_focus(), false)


func _animate_button(btn: Button, highlighted: bool, pressed: bool) -> void:
	var style: StyleBoxFlat = btn.get_meta("style")
	var marker: ColorRect = btn.get_meta("marker")

	var old: Variant = btn.get_meta("tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()

	var target_scale: float = 1.0
	if highlighted:
		target_scale = 0.98 if pressed else 1.04

	var d: float = 0.2
	var t: Tween = btn.create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE * target_scale, d)
	t.tween_property(btn, "modulate", Color.WHITE if highlighted else COL_BTN_DIM, d)
	t.tween_property(style, "bg_color", COL_BTN_BG_HOVER if highlighted else COL_BTN_BG, d)
	t.tween_property(style, "border_color", COL_BTN_BORDER_HOVER if highlighted else COL_BTN_BORDER, d)
	t.tween_property(style, "shadow_color", COL_GLOW if highlighted else COL_SHADOW, d)
	t.tween_property(style, "shadow_size", 18 if highlighted else 1, d)
	t.tween_property(style, "shadow_offset", Vector2.ZERO if highlighted else Vector2(4, 4), d)
	t.tween_property(marker, "modulate:a", 1.0 if highlighted else 0.0, d)
	t.tween_property(marker, "position:x", 22.0 if highlighted else 10.0, d)
	btn.set_meta("tween", t)


# ──────────────────────────────────────────────
# ENTRADA
# ──────────────────────────────────────────────

func _play_intro() -> void:
	title.modulate.a = 0.0
	_divider.scale = Vector2(0.0, 1.0)

	var t: Tween = create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(title, "modulate:a", 1.0, 1.2)
	t.tween_property(_divider, "scale:x", 1.0, 0.9).set_delay(0.5)
	t.finished.connect(_start_title_breathing)

	var delay: float = 0.7
	for child: Node in buttons_container.get_children():
		var btn: Button = child as Button
		if btn == null:
			continue
		btn.modulate.a = 0.0
		btn.scale = Vector2.ONE * 0.92
		var bt: Tween = btn.create_tween().set_parallel(true)
		bt.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		bt.tween_property(btn, "modulate:a", 1.0, 0.5).set_delay(delay)
		bt.tween_property(btn, "scale", Vector2.ONE, 0.5).set_delay(delay)
		delay += 0.12


# ──────────────────────────────────────────────
# SEÑALES HACIA main.gd
# ──────────────────────────────────────────────

func _on_new_game_pressed() -> void:
	start_new_game.emit()

func _on_load_game_pressed() -> void:
	load_game.emit()

func _on_settings_pressed() -> void:
	show_settings.emit()

func _on_quit_pressed() -> void:
	quit_game.emit()

func disable_menu() -> void:
	for button in buttons_container.get_children():
		if button is Button:
			button.disabled = true

func enable_menu() -> void:
	for button in buttons_container.get_children():
		if button is Button:
			button.disabled = false
