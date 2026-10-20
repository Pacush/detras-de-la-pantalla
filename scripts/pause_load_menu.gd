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
	
	# Obtener todos los slots
	var save_slots = Dialogic.Save.get_slot_names()
	
	if save_slots.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No hay partidas guardadas"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		slots_container.add_child(empty_label)
		return
	
	# Mostrar cada slot
	for slot_name in save_slots:
		var save_data = Dialogic.Save.get_slot_info(slot_name)
		create_slot_load_button(slot_name, save_data)

func create_slot_load_button(slot_name: String, save_data: Dictionary) -> void:
	var button = Button.new()
	var timeline_name = save_data.get("timeline", "")
	var text_preview = save_data.get("dialogic_state_info", {}).get("text", "")
	if text_preview.length() > 40:
		text_preview = text_preview.substr(0, 37) + "..."
	
	var button_text = "[%s]\n%s\n%s" % [slot_name, timeline_name, text_preview]
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 100)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_slot_selected.bind(slot_name))
	
	slots_container.add_child(button)

func _on_slot_selected(slot_name: String) -> void:
	Dialogic.Save.load(slot_name)
	# No emitimos back_to_menu porque el juego carga automáticamente
	# Pero despauzamos
	PauseManager.unpause()

func _on_back() -> void:
	back_to_menu.emit()
