extends Node

## Autoload manager para el menú de pausa
## Se inicializa automáticamente en project.godot

var pause_menu_scene = preload("res://scenes/PauseMenu.tscn")
var is_paused = false
var current_pause_menu = null
var pause_canvas_layer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Funciona incluso cuando está pausado

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC
		# Evitar que se pueda pausar si aún estamos en el Menú Principal
		var main_scene = get_tree().current_scene
		if main_scene and "game_started" in main_scene and not main_scene.game_started:
			return
			
		if is_paused:
			unpause()
		else:
			pause()
		get_tree().root.set_input_as_handled()

func pause() -> void:
	is_paused = true
	get_tree().paused = true
	get_tree().call_group("music_manager", "set_ducked", true)   # música al 50% en la pausa
	
	# Crear CanvasLayer con nivel alto
	pause_canvas_layer = CanvasLayer.new()
	pause_canvas_layer.layer = 1000  # Encima de todo
	get_tree().root.add_child(pause_canvas_layer)
	
	# Instanciar menú de pausa como hijo del CanvasLayer
	current_pause_menu = pause_menu_scene.instantiate()
	pause_canvas_layer.add_child(current_pause_menu)
	current_pause_menu.resume_requested.connect(unpause)
	current_pause_menu.go_to_main_menu.connect(_on_go_to_main_menu)

func unpause() -> void:
	is_paused = false
	get_tree().paused = false
	get_tree().call_group("music_manager", "set_ducked", false)
	
	if pause_canvas_layer:
		pause_canvas_layer.queue_free()
		pause_canvas_layer = null
	
	if current_pause_menu:
		current_pause_menu = null

func _on_go_to_main_menu() -> void:
	unpause()
	
	# La escena principal limpia Dialogic por su cuenta (end_timeline con skip_ending). No se
	# llama aquí a Dialogic.end_timeline() a secas: ejecuta el timeline de cierre, que crea un
	# layout nuevo de pantalla completa encima del menú y se come todos los clics.
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("show_main_menu"):
		main_scene.show_main_menu()
	else:
		Dialogic.paused = false
		Dialogic.end_timeline(true)
		get_tree().change_scene_to_file("res://main.tscn")

func get_input_state() -> void:
	# Útil para debugging
	pass
