extends "res://scripts/ui/ui_panel_menu.gd"
## Guardar partida: 5 ranuras.

const SLOT_COUNT: int = 5

var _saving: bool = false


func _ready() -> void:
	build_frame("Guardar Partida")
	_fill_slots()


func _fill_slots() -> void:
	for child: Node in list.get_children():
		child.queue_free()

	var saved_slots: Variant = Dialogic.Save.get_slot_names()
	for slot_num: int in range(1, SLOT_COUNT + 1):
		var slot_name: String = "slot_%d" % slot_num
		var text: String
		if slot_name in saved_slots:
			text = UI.slot_text(slot_name, Dialogic.Save.get_slot_info(slot_name))
		else:
			text = "%s\nVacía" % UI.slot_label(slot_name)
		var btn: Button = make_list_button(text, 116.0 if slot_name in saved_slots else 92.0)
		btn.pressed.connect(_on_slot_selected.bind(slot_name))


## Datos que se guardan junto a la partida: historia, fecha/hora y último diálogo.
func _build_slot_info() -> Dictionary:
	var story: String = ""
	var main_scene: Node = get_tree().current_scene
	if main_scene != null and main_scene.has_method("get_current_story"):
		story = str(main_scene.call("get_current_story"))

	var preview: String = ""
	for entry: Variant in Dialogic.History.get_simple_history():
		if entry is Dictionary and str(entry.get("text", "")).strip_edges() != "":
			preview = str(entry.get("text", ""))

	return {
		"story": story,
		"saved_at": UI.now_text(),
		"saved_unix": Time.get_unix_time_from_system(),
		"preview": preview,
	}


func _on_slot_selected(slot_name: String) -> void:
	if _saving:
		return
	_saving = true
	Dialogic.Save.save(slot_name, false, Dialogic.Save.ThumbnailMode.NONE, _build_slot_info())
	footer.text = "Partida guardada en la %s." % UI.slot_label(slot_name).to_lower()
	# Pausa breve para que se lea el aviso antes de volver (el árbol está pausado).
	await get_tree().create_timer(0.7, true).timeout
	back_to_menu.emit()
