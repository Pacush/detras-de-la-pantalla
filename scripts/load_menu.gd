extends Control

signal back_to_menu
signal slot_selected(slot_name: String)

@onready var slots_container = $ScrollContainer/VBoxContainer

func _ready() -> void:
	$Header/BackButton.pressed.connect(_on_back_pressed)
	load_save_slots()

func load_save_slots() -> void:
	# Limpiar slots anteriores
	for child in slots_container.get_children():
		child.queue_free()
	
	# Obtener todos los slots guardados
	var save_slots = Dialogic.Save.get_slot_names()
	if save_slots.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No hay partidas guardadas"
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.modulate = Color(0.7, 0.7, 0.7, 1)
		slots_container.add_child(empty_label)
		return
	
	# Mostrar cada slot
	for slot_name in save_slots:
		var save_data = Dialogic.Save.get_slot_info(slot_name)
		var button = create_slot_button(slot_name, save_data)
		slots_container.add_child(button)

func create_slot_button(slot_name: String, save_data: Dictionary) -> Button:
	var button = Button.new()
	var timeline_name = save_data.get("timeline", "")
	
	var current_line = save_data.get("dialogic_state_info", {}).get("text", "Inicio del juego").left(40)
	
	button.text = "[%s]\n%s\n%s" % [slot_name, timeline_name, current_line]
	button.custom_minimum_size = Vector2(400, 100)
	button.pressed.connect(_on_slot_selected.bind(slot_name))
	return button

func _on_slot_selected(slot_name: String) -> void:
	# Emitimos la señal hacia main.gd con el nombre del slot
	slot_selected.emit(slot_name)

func _on_back_pressed() -> void:
	back_to_menu.emit()
