extends Node

const Saved = preload("res://scripts/ui/user_settings.gd")


func _ready() -> void:
	var tl: DialogicTimeline = DialogicTimeline.new()
	tl.from_text("[style name=\"style2 (custom)\"]\nromina (glad): Hola, esto es una prueba del tamano del texto en el cuadro de dialogo.\nSegunda linea.")
	Dialogic.start(tl)
	await get_tree().create_timer(2.0).timeout
	_reporta("ORIGINAL (sin aplicar)")

	for combo: Array in [[0, 0], [1, 1], [2, 2], [2, 0], [0, 2], [0, 0]]:
		Saved._size_dialog = combo[0]
		Saved._size_name = combo[1]
		Saved.apply_text_sizes(get_tree())
		await get_tree().process_frame
		await get_tree().process_frame
		_reporta("dialogo=%d nombre=%d" % combo)
	# Menu de ajustes: se crea sin errores y muestra las dos filas nuevas.
	var menu: Node = load("res://scenes/SettingsMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var sliders: Array[Node] = menu.find_children("*", "HSlider", true, false)
	var etiquetas: Array[String] = []
	for l: Node in menu.find_children("*", "Label", true, false):
		etiquetas.append((l as Label).text)
	print("AJUSTES sliders=%d etiquetas=%s" % [sliders.size(), etiquetas])
	print("FIN_TEST")


func _reporta(titulo: String) -> void:
	var layout: Node = get_tree().get_meta("dialogic_layout_node") as Node
	var texto: RichTextLabel = layout.find_child("DialogicNode_DialogText", true, false) as RichTextLabel
	var etiqueta: Label = layout.find_child("DialogicNode_NameLabel", true, false) as Label
	var panel: Control = etiqueta.get_parent() as Control
	print("== %s | texto=%d (nombre texto: '%s') | nombre=%d | panel nombre pos.y=%s alto=%s | texto alto contenido=%s" % [
		titulo, texto.get_theme_font_size("normal_font_size"), etiqueta.text,
		etiqueta.get_theme_font_size("font_size"), panel.position.y, panel.size.y, texto.get_content_height()])
