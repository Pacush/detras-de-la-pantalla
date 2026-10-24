extends Control
## Vista de selección de historia (se muestra al pulsar "Nuevo Juego").
##
## Señales:
##   story_selected(story_id) → el jugador eligió una historia (ya terminó la animación).
##   back_to_menu             → el jugador volvió al menú principal.

signal story_selected(story_id: String)
signal back_to_menu

const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")
const StoryCard = preload("res://scripts/story_card.gd")

## Para agregar una historia nueva basta con añadir una entrada aquí.
const STORIES: Array = [
	{
		"id": "darwin",
		"name": "Darwin",
		"sprite": "res://assets/characters/Darwin/Darwin Mad.png",
	},
	{
		"id": "romina",
		"name": "Romina",
		"sprite": "res://assets/characters/Romina/Romina Glad.png",
		# Azul de su sprite / luz de celular: borde, brillo y fondo al pasar el mouse.
		"colors": {
			"border_normal": Color(0.22, 0.33, 0.55, 1.0),
			"border_hover": Color(0.45, 0.68, 1.0, 1.0),
			"bg_hover": Color(0.08, 0.12, 0.22, 1.0),
			"glow": Color(0.30, 0.55, 1.0, 0.45),
		},
	},
]

var _cards: Array[StoryCard] = []
var _title: Label
var _back_button: Button
var _selected: bool = false


func _ready() -> void:
	_build_ui()
	_play_intro()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root_box)

	# ── Título ──
	_title = Label.new()
	_title.text = "Selecciona una historia"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(0, 140)
	_title.add_theme_font_override("font", PIX_FONT)
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color.WHITE)
	root_box.add_child(_title)

	# ── Tarjetas centradas ──
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(center)

	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_row.add_theme_constant_override("separation", 120)
	center.add_child(cards_row)

	for story: Dictionary in STORIES:
		var card: StoryCard = StoryCard.new()
		var texture: Texture2D = load(story["sprite"]) as Texture2D
		if texture == null:
			push_warning("[StorySelect] No se pudo cargar el sprite: %s" % story["sprite"])
		card.setup(story["id"], story["name"], texture, PIX_FONT, story.get("colors", {}))
		card.card_pressed.connect(_on_card_pressed)
		card.hover_changed.connect(_on_card_hover_changed)
		cards_row.add_child(card)
		_cards.append(card)

	# ── Botón volver ──
	var footer: HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	root_box.add_child(footer)

	_back_button = Button.new()
	_back_button.text = "Volver"
	_back_button.custom_minimum_size = Vector2(220, 56)
	_back_button.add_theme_font_override("font", PIX_FONT)
	_back_button.add_theme_font_size_override("font_size", 24)
	_back_button.pressed.connect(_on_back_pressed)
	footer.add_child(_back_button)


func _play_intro() -> void:
	_title.modulate.a = 0.0
	_back_button.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "modulate:a", 1.0, 0.5)
	tween.tween_property(_back_button, "modulate:a", 1.0, 0.5).set_delay(0.4)

	var delay: float = 0.2
	for card: StoryCard in _cards:
		card.play_intro(delay)
		delay += 0.15


func _on_card_hover_changed(card: StoryCard, hovering: bool) -> void:
	if _selected:
		return
	# Al pasar el mouse sobre una tarjeta, las demás se oscurecen levemente.
	for other: StoryCard in _cards:
		if other != card:
			other.set_dimmed(hovering)


func _on_card_pressed(story_id: String) -> void:
	if _selected:
		return
	_selected = true
	_back_button.disabled = true

	for card: StoryCard in _cards:
		if card.story_id == story_id:
			card.play_selected()
		else:
			card.play_dismissed()

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_title, "modulate:a", 0.0, 0.4)
	tween.tween_property(_back_button, "modulate:a", 0.0, 0.3)

	# Dejar que se aprecie la animación antes de pasar a la novela visual.
	await get_tree().create_timer(0.6).timeout
	story_selected.emit(story_id)


func _on_back_pressed() -> void:
	if _selected:
		return
	_selected = true
	back_to_menu.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _selected:
		get_viewport().set_input_as_handled()
		_on_back_pressed()
