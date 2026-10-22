extends PanelContainer
## Tarjeta de una historia (sprite + nombre) para la vista de selección.
## Maneja sus propias animaciones de hover, click, selección y descarte.
##
## Uso: instanciar el script con .new() y llamar setup() ANTES de add_child().
## (Sin class_name a propósito: se carga con preload desde story_select.gd.)

signal card_pressed(story_id: String)
signal hover_changed(card: PanelContainer, hovering: bool)

const CARD_SIZE: Vector2 = Vector2(380, 560)
const HOVER_SCALE: float = 1.07
const PRESS_SCALE: float = 0.97
const ANIM_TIME: float = 0.22

const BG_NORMAL: Color = Color(0.06, 0.06, 0.09, 1.0)
const BG_HOVER: Color = Color(0.12, 0.10, 0.18, 1.0)
const BORDER_NORMAL: Color = Color(0.30, 0.28, 0.42, 1.0)
const BORDER_HOVER: Color = Color(0.90, 0.80, 1.00, 1.0)
const SPRITE_NORMAL: Color = Color(0.70, 0.70, 0.76, 1.0)
const SPRITE_HOVER: Color = Color(1.0, 1.0, 1.0, 1.0)
const LABEL_NORMAL: Color = Color(0.72, 0.70, 0.80, 1.0)
const LABEL_HOVER: Color = Color(1.0, 1.0, 1.0, 1.0)
const DIM_COLOR: Color = Color(0.5, 0.5, 0.55, 1.0)
const SHADOW_HOVER: int = 28

var story_id: String = ""

var _display_name: String = ""
var _texture: Texture2D = null
var _font: Font = null

var _style: StyleBoxFlat
var _sprite: TextureRect
var _name_label: Label
var _tween: Tween

var _hovered: bool = false
var _pressing: bool = false
var _dimmed: bool = false
var _interactive: bool = false
var _locked: bool = false


func setup(id: String, display_name: String, texture: Texture2D, font: Font) -> void:
	story_id = id
	_display_name = display_name
	_texture = texture
	_font = font


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE

	_style = StyleBoxFlat.new()
	_style.bg_color = BG_NORMAL
	_style.border_color = BORDER_NORMAL
	_style.set_border_width_all(4)
	_style.set_corner_radius_all(14)
	_style.shadow_color = Color(0.70, 0.50, 1.0, 0.40)
	_style.shadow_size = 0
	add_theme_stylebox_override("panel", _style)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	_sprite = TextureRect.new()
	_sprite.texture = _texture
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sprite.modulate = SPRITE_NORMAL
	box.add_child(_sprite)

	_name_label = Label.new()
	_name_label.text = _display_name
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 40)
	if _font != null:
		_name_label.add_theme_font_override("font", _font)
	_name_label.modulate = LABEL_NORMAL
	box.add_child(_name_label)

	resized.connect(_update_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size / 2.0


# ──────────────────────────────────────────────
# API usada por la vista
# ──────────────────────────────────────────────

## Animación de entrada. Hasta que termina, la tarjeta no reacciona al mouse.
func play_intro(delay: float) -> void:
	_interactive = false
	scale = Vector2.ONE * 0.88
	modulate.a = 0.0
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_delay(delay)
	_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_delay(delay)
	_tween.chain().tween_callback(_on_intro_finished)


## Oscurece levemente la tarjeta (cuando el mouse está sobre la otra).
func set_dimmed(value: bool) -> void:
	_dimmed = value
	_apply_state()


## Click confirmado: la tarjeta crece y brilla.
func play_selected() -> void:
	_locked = true
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.12, 0.35)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	_tween.tween_property(_style, "border_color", Color.WHITE, 0.2)
	_tween.tween_property(_style, "bg_color", BG_HOVER, 0.2)
	_tween.tween_property(_style, "shadow_size", SHADOW_HOVER * 2, 0.35)
	_tween.tween_property(_sprite, "modulate", SPRITE_HOVER, 0.2)
	_tween.tween_property(_name_label, "modulate", LABEL_HOVER, 0.2)


## La otra tarjeta fue elegida: se desvanece y se encoge.
func play_dismissed() -> void:
	_locked = true
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2.ONE * 0.9, 0.4)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)


# ──────────────────────────────────────────────
# Input
# ──────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if _locked or not _interactive:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		_pressing = true
		_apply_state()
	else:
		var was_pressing: bool = _pressing
		_pressing = false
		# Solo cuenta como click si se suelta dentro de la tarjeta.
		var inside: bool = Rect2(Vector2.ZERO, size).has_point(mb.position)
		if was_pressing and inside:
			card_pressed.emit(story_id)
		else:
			_apply_state()


func _on_mouse_entered() -> void:
	_hovered = true
	hover_changed.emit(self, true)
	_apply_state()


func _on_mouse_exited() -> void:
	_hovered = false
	hover_changed.emit(self, false)
	_apply_state()


# ──────────────────────────────────────────────
# Animación de estado (hover / press / dim)
# ──────────────────────────────────────────────

func _on_intro_finished() -> void:
	_interactive = true
	# Si el mouse ya estaba encima cuando terminó la entrada, sincronizar.
	_hovered = get_global_rect().has_point(get_global_mouse_position())
	if _hovered:
		hover_changed.emit(self, true)
	_apply_state()


func _apply_state() -> void:
	if not _interactive or _locked:
		return

	var target_scale: float = 1.0
	if _hovered:
		target_scale = PRESS_SCALE if _pressing else HOVER_SCALE

	var border: Color = BORDER_HOVER if _hovered else BORDER_NORMAL
	var bg: Color = BG_HOVER if _hovered else BG_NORMAL
	var sprite_mod: Color = SPRITE_HOVER if _hovered else SPRITE_NORMAL
	var label_mod: Color = LABEL_HOVER if _hovered else LABEL_NORMAL
	var shadow: int = SHADOW_HOVER if _hovered else 0
	var card_mod: Color = DIM_COLOR if (_dimmed and not _hovered) else Color.WHITE

	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target_scale, ANIM_TIME)
	_tween.tween_property(self, "modulate", card_mod, ANIM_TIME)
	_tween.tween_property(_style, "border_color", border, ANIM_TIME)
	_tween.tween_property(_style, "bg_color", bg, ANIM_TIME)
	_tween.tween_property(_style, "shadow_size", shadow, ANIM_TIME)
	_tween.tween_property(_sprite, "modulate", sprite_mod, ANIM_TIME)
	_tween.tween_property(_name_label, "modulate", label_mod, ANIM_TIME)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
