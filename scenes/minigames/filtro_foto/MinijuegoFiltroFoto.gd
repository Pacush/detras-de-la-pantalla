extends CanvasLayer
## Minijuego 1 de Romina — "Filtro de Foto".
##
## Romina prepara su foto de perfil antes de subirla a una red social ficticia:
##   1. Elige un filtro de color.
##   2. Elige un sticker y lo acomoda sobre la foto (clic para colocar, arrastrar para mover).
##   3. Pulsa "Publicar".
##
## Señal:
##   completado → el jugador publicó la foto (el nodo se libera solo después).
##
## Todo se construye en código. Los controles son nodos Control (no Node2D) para
## que ganen el hit-test de GUI frente al input layer de Dialogic.

signal completado

const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")
const PHOTO_PATH: String = "res://assets/characters/Romina/Romina Glad.png"
const PHOTO_SIZE: float = 420.0
const STICKER_SIZE: float = 72.0

const COL_BG: Color = Color(0.04, 0.04, 0.08, 0.96)
const COL_PANEL: Color = Color(0.07, 0.08, 0.12, 1.0)
const COL_ACCENT: Color = Color(0.72, 0.68, 0.88, 1.0)
const COL_TEXT: Color = Color(0.84, 0.84, 0.94, 1.0)
const COL_MUTED: Color = Color(0.50, 0.50, 0.62, 1.0)
const COL_BTN: Color = Color(0.08, 0.09, 0.14, 1.0)
const COL_BTN_HOVER: Color = Color(0.14, 0.13, 0.21, 1.0)
const COL_BORDER: Color = Color(0.26, 0.28, 0.40, 1.0)
const COL_BTN_DISABLED: Color = Color(0.05, 0.05, 0.08, 1.0)
const COL_BORDER_DISABLED: Color = Color(0.15, 0.16, 0.22, 1.0)

const FILTERS: Array = [
	{"name": "Normal", "tint": Color(1.0, 1.0, 1.0, 1.0)},
	{"name": "Cálido", "tint": Color(1.0, 0.86, 0.72, 1.0)},
	{"name": "Frío", "tint": Color(0.74, 0.86, 1.0, 1.0)},
	{"name": "Sepia", "tint": Color(0.86, 0.70, 0.52, 1.0)},
]

## Stickers de 8x8 píxeles ("#" = pixel pintado).
const STICKERS: Array = [
	{
		"name": "Corazón",
		"color": Color(0.95, 0.38, 0.52, 1.0),
		"rows": [
			".##..##.",
			"########",
			"########",
			"########",
			".######.",
			"..####..",
			"...##...",
			"........",
		],
	},
	{
		"name": "Estrella",
		"color": Color(1.0, 0.86, 0.35, 1.0),
		"rows": [
			"...##...",
			"...##...",
			"########",
			".######.",
			"..####..",
			".##..##.",
			".#....#.",
			"........",
		],
	},
	{
		"name": "Destello",
		"color": Color(0.70, 0.92, 1.0, 1.0),
		"rows": [
			"...##...",
			"...##...",
			"...##...",
			"########",
			"########",
			"...##...",
			"...##...",
			"...##...",
		],
	},
	{
		"name": "Carita",
		"color": Color(1.0, 0.78, 0.40, 1.0),
		"rows": [
			"..####..",
			".######.",
			"##.##.##",
			"########",
			"#.####.#",
			"##....##",
			".######.",
			"..####..",
		],
	},
]

var _root: Control
var _photo_area: Control
var _photo: TextureRect
var _sticker: TextureRect
var _hint: Label
var _publish: Button

var _filter_group: ButtonGroup
var _sticker_group: ButtonGroup
var _sticker_textures: Array[Texture2D] = []

var _selected_sticker: int = -1
var _sticker_placed: bool = false
var _finishing: bool = false


func _ready() -> void:
	layer = 90
	_build_sticker_textures()
	_build_ui()

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.4)


# ──────────────────────────────────────────────
# CONSTRUCCIÓN DE LA UI
# ──────────────────────────────────────────────

func _build_sticker_textures() -> void:
	for sticker: Dictionary in STICKERS:
		var rows: Array = sticker["rows"]
		var color: Color = sticker["color"]
		var img: Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		for y in range(8):
			var row: String = rows[y]
			for x in range(8):
				if row[x] == "#":
					img.set_pixel(x, y, color)
		_sticker_textures.append(ImageTexture.create_from_image(img))


func _build_ui() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = COL_BG
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	_root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var title: Label = _make_label("Nueva foto de perfil", 52, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 90)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(title)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 90)
	center.add_child(row)

	row.add_child(_build_photo_panel())
	row.add_child(_build_controls_panel())


func _build_photo_panel() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_ACCENT
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", sb)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(_make_label("tu_perfil", 22, COL_MUTED))

	_photo_area = Control.new()
	_photo_area.custom_minimum_size = Vector2(PHOTO_SIZE, PHOTO_SIZE)
	_photo_area.clip_contents = true
	_photo_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_photo_area.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_photo_area.gui_input.connect(_on_photo_gui_input)
	box.add_child(_photo_area)

	var fill: ColorRect = ColorRect.new()
	fill.color = Color(0.12, 0.12, 0.17, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_area.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_photo = TextureRect.new()
	_photo.texture = load(PHOTO_PATH) as Texture2D
	if _photo.texture == null:
		push_warning("[FiltroFoto] No se pudo cargar la foto: %s" % PHOTO_PATH)
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_area.add_child(_photo)
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sticker = TextureRect.new()
	_sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sticker.stretch_mode = TextureRect.STRETCH_SCALE
	_sticker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticker.size = Vector2(STICKER_SIZE, STICKER_SIZE)
	_sticker.pivot_offset = Vector2(STICKER_SIZE, STICKER_SIZE) / 2.0
	_sticker.visible = false
	_photo_area.add_child(_sticker)

	return panel


func _build_controls_panel() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 16)

	# ── Filtros ──
	box.add_child(_make_label("Filtro", 30, COL_ACCENT))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	_filter_group = ButtonGroup.new()
	for i in range(FILTERS.size()):
		var f: Dictionary = FILTERS[i]
		var filter_name: String = f["name"]
		var b: Button = _make_toggle(filter_name)
		b.button_group = _filter_group
		b.button_pressed = (i == 0)
		b.toggled.connect(_on_filter_toggled.bind(i))
		grid.add_child(b)

	# ── Stickers ──
	box.add_child(_make_label("Sticker", 30, COL_ACCENT))

	var sticker_row: HBoxContainer = HBoxContainer.new()
	sticker_row.add_theme_constant_override("separation", 12)
	box.add_child(sticker_row)

	_sticker_group = ButtonGroup.new()
	for i in range(STICKERS.size()):
		var b: Button = _make_toggle("")
		b.icon = _sticker_textures[i]
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.custom_minimum_size = Vector2(88, 88)
		b.button_group = _sticker_group
		b.toggled.connect(_on_sticker_toggled.bind(i))
		sticker_row.add_child(b)

	# ── Pista ──
	_hint = _make_label("Elige un sticker y haz clic en la foto para colocarlo.", 20, COL_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(460, 64)
	box.add_child(_hint)

	# ── Publicar ──
	_publish = Button.new()
	_publish.text = "Publicar"
	_publish.disabled = true
	_publish.focus_mode = Control.FOCUS_NONE
	_publish.custom_minimum_size = Vector2(0, 68)
	_publish.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(_publish)
	_publish.pressed.connect(_on_publish_pressed)
	box.add_child(_publish)

	return box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", PIX_FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_toggle(text: String) -> Button:
	var b: Button = Button.new()
	b.toggle_mode = true
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(b)
	return b


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.set_content_margin_all(12.0)
	return s


func _style_button(b: Button) -> void:
	b.add_theme_font_override("font", PIX_FONT)
	b.add_theme_font_size_override("font_size", 26)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(color_name, COL_TEXT)
	b.add_theme_color_override("font_disabled_color", COL_MUTED)
	b.add_theme_stylebox_override("normal", _box(COL_BTN, COL_BORDER))
	b.add_theme_stylebox_override("hover", _box(COL_BTN_HOVER, COL_ACCENT))
	b.add_theme_stylebox_override("pressed", _box(COL_BTN_HOVER, Color.WHITE))
	b.add_theme_stylebox_override("hover_pressed", _box(COL_BTN_HOVER, Color.WHITE))
	b.add_theme_stylebox_override("disabled", _box(COL_BTN_DISABLED, COL_BORDER_DISABLED))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ──────────────────────────────────────────────
# INTERACCIÓN
# ──────────────────────────────────────────────

func _on_filter_toggled(pressed: bool, index: int) -> void:
	if not pressed:
		return
	var f: Dictionary = FILTERS[index]
	var tint: Color = f["tint"]
	var t: Tween = create_tween()
	t.tween_property(_photo, "modulate", tint, 0.25)


func _on_sticker_toggled(pressed: bool, index: int) -> void:
	if not pressed:
		return
	_selected_sticker = index
	_sticker.texture = _sticker_textures[index]
	if _sticker_placed:
		_hint.text = "Arrastra el sticker para acomodarlo o pulsa Publicar."
	else:
		_hint.text = "Haz clic en la foto para colocar el sticker."


func _on_photo_gui_input(event: InputEvent) -> void:
	if _finishing:
		return

	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _selected_sticker < 0:
			_hint.text = "Primero elige un sticker."
			return
		_place_sticker(mb.position)
		return

	# Arrastrar para acomodar el sticker ya colocado.
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _sticker_placed and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_place_sticker(mm.position)


func _place_sticker(local_pos: Vector2) -> void:
	var half: float = STICKER_SIZE / 2.0
	var area: Vector2 = _photo_area.size
	var p: Vector2 = Vector2(
		clampf(local_pos.x, half, maxf(half, area.x - half)),
		clampf(local_pos.y, half, maxf(half, area.y - half))
	)
	_sticker.position = p - Vector2(half, half)

	if not _sticker_placed:
		_sticker_placed = true
		_sticker.visible = true
		_publish.disabled = false
		_hint.text = "Arrastra el sticker para acomodarlo o pulsa Publicar."
		_sticker.scale = Vector2.ONE * 1.5
		var t: Tween = create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_sticker, "scale", Vector2.ONE, 0.25)


func _on_publish_pressed() -> void:
	if _finishing:
		return
	_finishing = true
	_publish.disabled = true
	_publish.text = "Subiendo..."
	_hint.text = ""

	var t: Tween = create_tween()
	t.tween_interval(0.9)
	t.tween_callback(_publish.set_text.bind("Publicado"))
	t.tween_interval(0.7)
	t.tween_property(_root, "modulate:a", 0.0, 0.4)
	t.tween_callback(_finish)


func _finish() -> void:
	completado.emit()
	queue_free()
