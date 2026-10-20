extends Control

signal back_to_menu

@onready var slots_container = $Panel/VBoxContainer/ScrollContainer/VBoxContainer

func _ready() -> void:
	$Panel/VBoxContainer/Header/BackButton.pressed.connect(_on_back)
	load_save_slots()
	
	# Animación de entrada
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func load_save_slots() -> void:
	# Limpiar slots anteriores
	for child in slots_container.get_children():
		child.queue_free()
	
	# Crear botones para slots (1-5)
	for slot_num in range(1, 6):
		var slot_name = "slot_%d" % slot_num
		create_slot_save_button(slot_name, slot_num)

func create_slot_save_button(slot_name: String, slot_num: int) -> void:
	var button = Button.new()
	
	# 1. Obtenemos la lista real de slots que existen en el disco
	var saved_slots = Dialogic.Save.get_slot_names()
	
	var button_text = ""
	
	# 2. Comprobamos si nuestro slot actual está dentro de esa lista
	if not slot_name in saved_slots:
		button_text = "[Slot %d] - Vacío" % slot_num
	else:
		# Si existe, sacamos la información (aunque los metadatos base estén vacíos)
		var existing_data = Dialogic.Save.get_slot_info(slot_name)
		var timeline_name = existing_data.get("timeline", "")
		
		# Extraemos un pedazo del último texto para que el jugador sepa dónde guardó
		var current_line = existing_data.get("dialogic_state_info", {}).get("text", "Partida guardada").left(35)
		
		button_text = "[Slot %d] - %s\n%s..." % [slot_num, timeline_name, current_line]
	
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 80)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_slot_selected.bind(slot_name))
	
	slots_container.add_child(button)

func _on_slot_selected(slot_name: String) -> void:
	Dialogic.Save.save(slot_name)
	back_to_menu.emit()

func _on_back() -> void:
	back_to_menu.emit()
