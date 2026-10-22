extends Node
## Estilo y animación de un botón pixel art (sombra dura, marcador cuadrado, resplandor).
## Se agrega como hijo del botón desde UI.style_button(); cada botón tiene su propia instancia.

const C = preload("res://scripts/ui/ui_colors.gd")
const Click = preload("res://scripts/ui/ui_click.gd")
const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")
const MARKER_SIZE: float = 12.0

var _btn: Button
var _style: StyleBoxFlat
var _marker: ColorRect
var _tween: Tween = null
var _mouse_driven: bool = false


func attach(btn: Button, font_size: int, min_height: float) -> void:
	_btn = btn
	_style = _make_style()
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, _style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var disabled_style: StyleBoxFlat = _make_style()
	disabled_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
	disabled_style.border_color = Color(0.15, 0.16, 0.22, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_font_override("font", PIX_FONT)
	btn.add_theme_font_size_override("font_size", font_size)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(color_name, C.TEXT)
	btn.add_theme_color_override("font_disabled_color", C.TEXT_DISABLED)

	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, min_height)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.modulate = C.BTN_DIM

	_marker = ColorRect.new()
	_marker.color = C.ACCENT
	_marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	_marker.position = Vector2(10.0, 0.0)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.modulate.a = 0.0
	btn.add_child(_marker)

	btn.resized.connect(_on_resized)
	btn.mouse_entered.connect(_on_mouse_entered)
	btn.mouse_exited.connect(_on_mouse_exited)
	btn.focus_entered.connect(_animate.bind(true, false))
	btn.focus_exited.connect(_animate.bind(false, false))
	btn.button_down.connect(_on_button_down)
	btn.button_up.connect(_on_button_up)
	btn.pressed.connect(_on_pressed)
	_on_resized()


func _input(event: InputEvent) -> void:
	# Con teclado/gamepad, el resaltado deja de seguir al mouse.
	if event is InputEventKey or event is InputEventJoypadButton:
		_mouse_driven = false


func _make_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = C.BTN_BG
	s.border_color = C.BTN_BORDER
	s.set_border_width_all(4)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = 54.0
	s.content_margin_right = 16.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	s.shadow_color = C.SHADOW
	s.shadow_size = 1
	s.shadow_offset = Vector2(4, 4)
	return s


func _on_resized() -> void:
	_marker.position.y = (_btn.size.y - MARKER_SIZE) / 2.0
	_btn.pivot_offset = Vector2(0.0, _btn.size.y / 2.0)


func _on_mouse_entered() -> void:
	if _btn.disabled:
		return
	_mouse_driven = true
	_btn.grab_focus()


func _on_mouse_exited() -> void:
	if _mouse_driven and _btn.has_focus():
		_btn.release_focus()


func _on_pressed() -> void:
	Click.play(_btn)


func _on_button_down() -> void:
	_animate(true, true)


func _on_button_up() -> void:
	_animate(_btn.has_focus(), false)


func _animate(highlighted: bool, pressed: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var target_scale: float = 1.0
	if highlighted:
		target_scale = 0.98 if pressed else 1.03

	var d: float = 0.2
	_tween = _btn.create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_btn, "scale", Vector2.ONE * target_scale, d)
	_tween.tween_property(_btn, "modulate", Color.WHITE if highlighted else C.BTN_DIM, d)
	_tween.tween_property(_style, "bg_color", C.BTN_BG_HOVER if highlighted else C.BTN_BG, d)
	_tween.tween_property(_style, "border_color", C.BTN_BORDER_HOVER if highlighted else C.BTN_BORDER, d)
	_tween.tween_property(_style, "shadow_color", C.GLOW if highlighted else C.SHADOW, d)
	_tween.tween_property(_style, "shadow_size", 18 if highlighted else 1, d)
	_tween.tween_property(_style, "shadow_offset", Vector2.ZERO if highlighted else Vector2(4, 4), d)
	_tween.tween_property(_marker, "modulate:a", 1.0 if highlighted else 0.0, d)
	_tween.tween_property(_marker, "position:x", 22.0 if highlighted else 10.0, d)
