extends "res://scripts/ui/ui_load_menu.gd"
## Cargar partida desde el menú principal. main.gd escucha slot_selected.

signal slot_selected(slot_name: String)


func _on_slot_chosen(slot_name: String) -> void:
	slot_selected.emit(slot_name)
