extends RefCounted
## Ajustes del jugador guardados en disco (user://settings.cfg): volumen y velocidad del texto.
## Sin class_name: usar con preload.

const PATH: String = "user://settings.cfg"
const DEFAULT_VOLUME: float = 1.0
const DEFAULT_SPEED: float = 1.0


## Lee el archivo y aplica los ajustes guardados. Llamar una vez al arrancar el juego.
static func load_and_apply() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	apply_volume(float(cfg.get_value("audio", "volume", DEFAULT_VOLUME)))
	apply_speed(float(cfg.get_value("texto", "velocidad", DEFAULT_SPEED)))


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


static func apply_volume(value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	AudioServer.set_bus_mute(bus_idx, value <= 0.001)


static func apply_speed(value: float) -> void:
	# set_setting no existe en Dialogic 2 Alpha 19: se modifica el ajuste del proyecto.
	ProjectSettings.set_setting("dialogic/text/speed", value)


static func save_volume(value: float) -> void:
	_save("audio", "volume", value)


static func save_speed(value: float) -> void:
	_save("texto", "velocidad", value)


static func _save(section: String, key: String, value: float) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)   # si no existe todavía, se crea al guardar
	cfg.set_value(section, key, value)
	cfg.save(PATH)
