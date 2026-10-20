extends Control

signal back_to_menu

func _ready() -> void:
	$Panel/VBoxContainer/Header/BackButton.pressed.connect(_on_back)
	load_history()
	
	# Animación de entrada
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func load_history() -> void:
	var container = $Panel/VBoxContainer/ScrollContainer/VBoxContainer
	
	# 1. Limpiar contenedor anterior
	for child in container.get_children():
		child.queue_free()
	
	# 2. Obtener el historial completo
	var history_log = Dialogic.History.get_simple_history()
	
	# 3. Filtrar para quedarnos SOLO con los que tienen texto real
	var dialogos_validos = []
	for entry in history_log:
		if entry.has("text") and entry.get("text", "").strip_edges() != "":
			dialogos_validos.append(entry)
	
	# 4. Si después de filtrar hay diálogos, los mostramos
	if not dialogos_validos.is_empty():
		# Calcular para mostrar solo los últimos 20
		var start_index = max(0, dialogos_validos.size() - 20)
		
		for i in range(start_index, dialogos_validos.size()):
			var entry = dialogos_validos[i]
			
			# Algunos eventos guardan el personaje como "character", otros como "speaker"
			var speaker = entry.get("character", entry.get("speaker", ""))
			if speaker == "": 
				speaker = "Narrador"
				
			var text = entry.get("text", "")
			add_history_entry(speaker, text)
	else:
		# Si está vacío (o no está activado en Dialogic)
		var empty_label = Label.new()
		empty_label.text = "No hay historial disponible.\n(Asegúrate de activarlo en los ajustes de Dialogic)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.6, 0.6, 0.6, 1)
		container.add_child(empty_label)

func add_history_entry(speaker: String, text: String) -> void:
	var entry_container = VBoxContainer.new()
	entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Nombre del personaje
	var speaker_label = Label.new()
	speaker_label.text = "[%s]" % speaker
	speaker_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1, 1))
	speaker_label.add_theme_font_size_override("font_size", 16)
	entry_container.add_child(speaker_label)
	
	# Texto del diálogo
	var text_label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 14)
	entry_container.add_child(text_label)
	
	# Separador
	var separator = HSeparator.new()
	entry_container.add_child(separator)
	
	$Panel/VBoxContainer/ScrollContainer/VBoxContainer.add_child(entry_container)

func _on_back() -> void:
	back_to_menu.emit()
