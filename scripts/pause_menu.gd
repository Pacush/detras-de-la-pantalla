extends Control
## Menú de pausa: barra lateral con el estilo pixel art del juego y submenús a pantalla completa.

signal resume_requested
signal go_to_main_menu

const UI = preload("res://scripts/ui/ui_style.gd")
const C = preload("res://scripts/ui/ui_colors.gd")

@onready var sidebar: PanelContainer = $Sidebar
@onready var overlay: ColorRect = $Overlay

var history_menu_scene: PackedScene = preload("res://scenes/PauseHistoryMenu.tscn")
var save_menu_scene: PackedScene = preload("res://scenes/PauseSaveMenu.tscn")
var load_menu_scene: PackedScene = preload("res://scenes/PauseLoadMenu.tscn")
var settings_menu_scene: PackedScene = preload("res://scenes/PauseSettingsMenu.tscn")

var current_submenu: Control = null


func _ready() -> void:
	theme = UI.make_theme()
	overlay.color = C.OVERLAY_PAUSE
	sidebar.add_theme_stylebox_override("panel", UI.panel_style())
	UI.style_title($Sidebar/VBoxContainer/Title as Label, 44)

	for child: Node in $Sidebar/VBoxContainer.get_children():
		var btn: Button = child as Button
		if btn != null:
			UI.style_button(btn, 26, 56.0)

	$Sidebar/VBoxContainer/ResumeButton.pressed.connect(_on_resume)
	$Sidebar/VBoxContainer/HistoryButton.pressed.connect(_on_history)
	$Sidebar/VBoxContainer/SaveButton.pressed.connect(_on_save)
	$Sidebar/VBoxContainer/LoadButton.pressed.connect(_on_load)
	$Sidebar/VBoxContainer/SettingsButton.pressed.connect(_on_settings)
	$Sidebar/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu)
	$Sidebar/VBoxContainer/QuitButton.pressed.connect(_on_quit)

	# Animación de entrada
	sidebar.modulate.a = 0.0
	overlay.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(sidebar, "modulate:a", 1.0, 0.3)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)


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
	sidebar.hide()

	if current_submenu:
		current_submenu.queue_free()

	current_submenu = scene.instantiate() as Control
	$SubmenuContainer.add_child(current_submenu)

	if current_submenu.has_signal("back_to_menu"):
		current_submenu.connect("back_to_menu", _on_submenu_back)


func _on_submenu_back() -> void:
	if current_submenu:
		current_submenu.queue_free()
		current_submenu = null
	sidebar.show()
