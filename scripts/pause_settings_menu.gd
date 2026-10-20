extends Control

signal back_to_menu

func _ready() -> void:
	$Panel/VBoxContainer/Header/BackButton.pressed.connect(_on_back)
	
	# Conectar sliders
	$Panel/VBoxContainer/ScrollContainer/VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value_changed.connect(_on_master_volume_changed)
	$Panel/VBoxContainer/ScrollContainer/VBoxContainer/TextSpeedContainer/TextSpeedSlider.value_changed.connect(_on_text_speed_changed)
	
	# Cargar valores actuales
	_load_settings()
	
	# Animación de entrada
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _load_settings() -> void:
	# Volumen maestro - Corrección: Leer el volumen real
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var master_vol = db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx))
	$Panel/VBoxContainer/ScrollContainer/VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value = master_vol
	
	# Velocidad del texto
	var text_speed = Dialogic.Settings.get_setting('text_speed', 1.0)
	$Panel/VBoxContainer/ScrollContainer/VBoxContainer/TextSpeedContainer/TextSpeedSlider.value = text_speed

func _on_master_volume_changed(value: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	
	# Corrección: linear_to_db (Sintaxis de Godot 4)
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
	AudioServer.set_bus_mute(master_bus_idx, value <= 0.001)

func _on_text_speed_changed(value: float) -> void:
	# Corrección: Modificar el ajuste directamente para evitar el error de Dialogic 2
	ProjectSettings.set_setting("dialogic/text/speed", value)

func _on_back() -> void:
	back_to_menu.emit()
