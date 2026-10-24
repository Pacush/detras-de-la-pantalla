extends "res://scripts/ui/ui_load_menu.gd"
## Cargar partida desde el menú de pausa.


func _on_slot_chosen(slot_name: String) -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene != null and main_scene.has_method("restore_story_from_slot"):
		main_scene.call("restore_story_from_slot", slot_name)
	Dialogic.Save.load(slot_name)
	# El juego carga solo; únicamente hay que salir de la pausa.
	PauseManager.unpause()
