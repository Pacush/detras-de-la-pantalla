extends "res://scripts/ui/ui_panel_menu.gd"
## Historial de diálogos recientes.

const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")
const MAX_ENTRIES: int = 20


func _ready() -> void:
	build_frame("Historial", 14)
	_load_history()


func _load_history() -> void:
	for child: Node in list.get_children():
		child.queue_free()

	# Solo entradas con texto real.
	var valid: Array = []
	for entry: Variant in Dialogic.History.get_simple_history():
		if entry is Dictionary and str(entry.get("text", "")).strip_edges() != "":
			valid.append(entry)

	if valid.is_empty():
		add_message("Aquí aparecerá lo que se ha dicho hasta ahora.\nTodavía no hay nada que recordar.")
		return

	for i: int in range(maxi(0, valid.size() - MAX_ENTRIES), valid.size()):
		var entry_dict: Dictionary = valid[i]
		# Algunos eventos guardan el personaje como "character", otros como "speaker".
		var speaker: String = str(entry_dict.get("character", entry_dict.get("speaker", "")))
		if speaker == "":
			speaker = "Narrador"
		_add_entry(speaker, str(entry_dict.get("text", "")))

	scroll_to_end()


func _add_entry(speaker: String, text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Barra lateral: azul para el narrador, lavanda para los personajes.
	var bar: ColorRect = ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.color = C.ACCENT_BLUE if speaker == "Narrador" else C.ACCENT
	row.add_child(bar)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)

	var name_label: Label = Label.new()
	name_label.text = speaker
	name_label.add_theme_color_override("font_color", bar.color)
	column.add_child(name_label)

	var text_label: Label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("font_size", 22)
	column.add_child(text_label)

	list.add_child(row)
