extends Control

signal start_new_game
signal load_game
signal show_settings
signal quit_game

@onready var buttons_container = $VBoxContainer
@onready var title = $Title

func _ready() -> void:
	# Conectar botones
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	
	# Animación de entrada suave
	buttons_container.modulate.a = 0
	title.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(buttons_container, "modulate:a", 1.0, 0.5)

func _on_new_game_pressed() -> void:
	start_new_game.emit()

func _on_load_game_pressed() -> void:
	load_game.emit()

func _on_settings_pressed() -> void:
	show_settings.emit()

func _on_quit_pressed() -> void:
	quit_game.emit()

func disable_menu() -> void:
	for button in buttons_container.get_children():
		if button is Button:
			button.disabled = true

func enable_menu() -> void:
	for button in buttons_container.get_children():
		if button is Button:
			button.disabled = false
