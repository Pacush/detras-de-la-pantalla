extends Control
## Base de los submenús (Cargar, Guardar, Historial, Ajustes; menú principal y pausa).
## Construye el marco: panel centrado con título, botón "Atrás" y una lista con scroll.
## Los submenús heredan con `extends "res://scripts/ui/ui_panel_menu.gd"` y llaman a build_frame().

signal back_to_menu

const UI = preload("res://scripts/ui/ui_style.gd")
const C = preload("res://scripts/ui/ui_colors.gd")

var panel: PanelContainer
var list: VBoxContainer
var back_button: Button
var footer: Label
var _scroll: ScrollContainer


func build_frame(title_text: String, list_separation: int = 12) -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	panel = PanelContainer.new()
	add_child(panel)
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)

	var title: Label = Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.style_title(title, 40)
	header.add_child(title)

	back_button = Button.new()
	back_button.text = "Atrás"
	back_button.custom_minimum_size = Vector2(170, 56)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	UI.style_button(back_button, 24, 56.0)

	column.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", list_separation)
	_scroll.add_child(list)

	footer = Label.new()
	footer.add_theme_color_override("font_color", C.ACCENT_BLUE)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.custom_minimum_size.y = 30.0
	column.add_child(footer)

	_play_intro()


func _play_intro() -> void:
	modulate.a = 0.0
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.3)


## Botón de slot / lista: pixel art, texto a la izquierda, alto cómodo para dos líneas.
func make_list_button(text: String, min_height: float = 92.0) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(btn)
	UI.style_button(btn, 22, min_height)
	return btn


func add_message(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", C.TEXT_MUTED)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size.y = 80.0
	list.add_child(lbl)
	return lbl


func scroll_to_end() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_back_pressed() -> void:
	back_to_menu.emit()
