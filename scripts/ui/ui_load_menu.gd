extends "res://scripts/ui/ui_panel_menu.gd"
## Selector de partidas guardadas, compartido por el menú principal y el de pausa.
## Cada versión decide qué hacer al elegir un slot sobrescribiendo _on_slot_chosen().


func _ready() -> void:
	build_frame("Cargar Partida")
	_fill_slots()


func _fill_slots() -> void:
	for child: Node in list.get_children():
		child.queue_free()

	var save_slots: Variant = Dialogic.Save.get_slot_names()
	if save_slots.is_empty():
		add_message("Todavía no hay partidas guardadas.\nCuando guardes una, aparecerá aquí.")
		return

	for slot_name: Variant in save_slots:
		var slot: String = str(slot_name)
		var info: Dictionary = Dialogic.Save.get_slot_info(slot)
		var btn: Button = make_list_button(UI.slot_text(slot, info), 116.0)
		btn.pressed.connect(_on_slot_chosen.bind(slot))


## Se sobrescribe en cada menú concreto.
func _on_slot_chosen(_slot_name: String) -> void:
	pass
