extends RefCounted
## Ajustes del jugador guardados en disco (user://settings.cfg): volumen, velocidad del texto y
## tamaño del texto de los diálogos y de los nombres. Sin class_name: usar con preload.

const PATH: String = "user://settings.cfg"
const DEFAULT_VOLUME: float = 1.0
const DEFAULT_SPEED: float = 1.0

## Tamaños de texto: el 0 es el original del estilo de Dialogic; los otros dos lo multiplican.
const TEXT_SIZE_FACTORS: Array[float] = [1.0, 1.4, 1.8]
const TEXT_SIZE_NAMES: Array[String] = ["Normal", "Grande", "Muy grande"]

# Valores en uso (se leen una vez al arrancar y se actualizan al cambiarlos en Ajustes).
static var _size_dialog: int = 0
static var _size_name: int = 0


## Lee el archivo y aplica los ajustes guardados. Llamar una vez al arrancar el juego.
static func load_and_apply() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	apply_volume(float(cfg.get_value("audio", "volume", DEFAULT_VOLUME)))
	apply_speed(float(cfg.get_value("texto", "velocidad", DEFAULT_SPEED)))
	_size_dialog = clampi(int(cfg.get_value("texto", "tam_dialogo", 0)), 0, TEXT_SIZE_FACTORS.size() - 1)
	_size_name = clampi(int(cfg.get_value("texto", "tam_nombre", 0)), 0, TEXT_SIZE_FACTORS.size() - 1)


static func get_volume() -> float:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	return float(cfg.get_value("audio", "volume", DEFAULT_VOLUME))


static func get_speed() -> float:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return float(ProjectSettings.get_setting("dialogic/text/speed", DEFAULT_SPEED))
	return float(cfg.get_value("texto", "velocidad", DEFAULT_SPEED))


## Tamaño elegido (0 = Normal, 1 = Grande, 2 = Muy grande) del texto del diálogo ("dialogo")
## o de los nombres de los personajes ("nombre").
static func get_text_size(kind: String) -> int:
	return _size_name if kind == "nombre" else _size_dialog


static func apply_volume(value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	AudioServer.set_bus_mute(bus_idx, value <= 0.001)


static func apply_speed(value: float) -> void:
	# set_setting no existe en Dialogic 2 Alpha 19: se modifica el ajuste del proyecto.
	ProjectSettings.set_setting("dialogic/text/speed", value)


## Pone el tamaño de texto elegido en la caja de diálogo y en la etiqueta del nombre del layout
## de Dialogic que esté en pantalla (si no hay ninguno, no hace nada). Es seguro llamarlo varias
## veces: el tamaño original se recuerda en el propio nodo y siempre se parte de él.
static func apply_text_sizes(tree: SceneTree) -> void:
	if not tree.has_meta("dialogic_layout_node"):
		return
	var layout_var: Variant = tree.get_meta("dialogic_layout_node")
	if not is_instance_valid(layout_var):
		return
	var layout: Node = layout_var as Node

	var texto: RichTextLabel = layout.find_child("DialogicNode_DialogText", true, false) as RichTextLabel
	if texto != null:
		var tam: int = roundi(_base_size(texto, "normal_font_size") * TEXT_SIZE_FACTORS[_size_dialog])
		for prop: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			texto.add_theme_font_size_override(prop, tam)

	var etiqueta: Label = layout.find_child("DialogicNode_NameLabel", true, false) as Label
	if etiqueta != null:
		var base: int = _base_size(etiqueta, "font_size")
		var tam_n: int = roundi(base * TEXT_SIZE_FACTORS[_size_name])
		etiqueta.add_theme_font_size_override("font_size", tam_n)
		# La caja del nombre cuelga del borde superior del cuadro de diálogo: al crecer la letra se
		# sube lo mismo que crece para que no se meta sobre el texto del diálogo.
		var panel: Control = etiqueta.get_parent() as Control
		var fuente: Font = etiqueta.get_theme_font("font")
		if panel != null and fuente != null:
			var crece: float = fuente.get_height(tam_n) - fuente.get_height(base)
			var aplicado: float = float(panel.get_meta("subida_nombre", 0.0))
			panel.position.y -= crece - aplicado
			panel.set_meta("subida_nombre", crece)
			panel.set_deferred("size", Vector2.ZERO)   # se reajusta al texto (si no, no encoge al bajar de tamaño)


## Tamaño de letra original de un nodo (el que le puso el estilo de Dialogic), recordado en el nodo.
static func _base_size(nodo: Control, prop: String) -> int:
	var clave: String = "tam_base_" + prop
	if not nodo.has_meta(clave):
		nodo.set_meta(clave, nodo.get_theme_font_size(prop))
	return int(nodo.get_meta(clave))


static func save_volume(value: float) -> void:
	_save("audio", "volume", value)


static func save_speed(value: float) -> void:
	_save("texto", "velocidad", value)


static func save_text_size(kind: String, index: int) -> void:
	index = clampi(index, 0, TEXT_SIZE_FACTORS.size() - 1)
	if kind == "nombre":
		_size_name = index
		_save("texto", "tam_nombre", index)
	else:
		_size_dialog = index
		_save("texto", "tam_dialogo", index)


static func _save(section: String, key: String, value: Variant) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)   # si no existe todavía, se crea al guardar
	cfg.set_value(section, key, value)
	cfg.save(PATH)
