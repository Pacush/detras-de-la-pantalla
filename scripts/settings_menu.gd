extends Control

signal back_to_menu

func _ready() -> void:
	$Header/BackButton.pressed.connect(_on_back_pressed)
	
	# Conectar sliders a funciones
	$VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value_changed.connect(_on_master_volume_changed)
	$VBoxContainer/TextSpeedContainer/TextSpeedSlider.value_changed.connect(_on_text_speed_changed)
	
	# Cargar valores actuales
	_load_settings()

func _load_settings() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	var master_vol = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	$VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value = master_vol
	
	# Regresamos a get_setting, que sí existe y no te da error
	var text_speed = Dialogic.Settings.get_setting('text_speed', 1.0)
	$VBoxContainer/TextSpeedContainer/TextSpeedSlider.value = text_speed

func _on_master_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	
	# SOLUCIÓN 2: Asignar el volumen correcto convirtiendo el valor del slider a decibeles
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	
	# Opcional: Silenciar el canal por completo si el slider llega a 0
	AudioServer.set_bus_mute(bus_idx, value <= 0.001)

func _on_text_speed_changed(value: float) -> void:
	# Como set_setting no existe, modificamos el multiplicador directamente en la raíz de Godot
	ProjectSettings.set_setting("dialogic/text/speed", value)

func _on_back_pressed() -> void:
	back_to_menu.emit()
