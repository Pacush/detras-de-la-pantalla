extends Control

signal resume_requested
signal go_to_main_menu

@onready var sidebar = $Sidebar

var history_menu_scene = preload("res://scenes/PauseHistoryMenu.tscn")
var save_menu_scene = preload("res://scenes/PauseSaveMenu.tscn")
var load_menu_scene = preload("res://scenes/PauseLoadMenu.tscn")
var settings_menu_scene = preload("res://scenes/PauseSettingsMenu.tscn")

var current_submenu = null

func _ready() -> void:
	# Conectar botones del menú principal
	$Sidebar/VBoxContainer/ResumeButton.pressed.connect(_on_resume)
	$Sidebar/VBoxContainer/HistoryButton.pressed.connect(_on_history)
	$Sidebar/VBoxContainer/SaveButton.pressed.connect(_on_save)
	$Sidebar/VBoxContainer/LoadButton.pressed.connect(_on_load)
	$Sidebar/VBoxContainer/SettingsButton.pressed.connect(_on_settings)
	$Sidebar/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu)
	$Sidebar/VBoxContainer/QuitButton.pressed.connect(_on_quit)
	
	# Animación de entrada
	sidebar.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(sidebar, "modulate:a", 1.0, 0.3)

func _on_resume() -> void:
	resume_requested.emit()

func _on_history() -> void:
	show_submenu(history_menu_scene)

func _on_save() -> void:
	show_submenu(save_menu_scene)

func _on_load() -> void:
	show_submenu(load_menu_scene)

func _on_settings() -> void:
	show_submenu(settings_menu_scene)

func _on_main_menu() -> void:
	go_to_main_menu.emit()

func _on_quit() -> void:
	get_tree().quit()

func show_submenu(scene: PackedScene) -> void:
	# Ocultar sidebar
	sidebar.hide()
	
	# Limpiar submenu anterior
	if current_submenu:
		current_submenu.queue_free()
	
	# Crear nuevo submenu
	current_submenu = scene.instantiate()
	$SubmenuContainer.add_child(current_submenu)
	
	# Conectar señal de regreso
	if current_submenu.has_signal("back_to_menu"):
		current_submenu.back_to_menu.connect(_on_submenu_back)

func _on_submenu_back() -> void:
	if current_submenu:
		current_submenu.queue_free()
		current_submenu = null
	sidebar.show()
