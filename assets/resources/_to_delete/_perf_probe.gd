extends Node
## TEMPORAL: mide rendimiento de cada escena con los monitores de Godot (para el informe).

const ESCENAS: Array = [
	["Menu principal (main.tscn)", "res://main.tscn", 6.0],
	["Minijuego Mochila", "res://scenes/minigames/organizar_mochila/MinijuegoOrganizarMochila.tscn", 6.0],
	["Minijuego Rompecabezas", "res://scenes/minigames/rompecabezas/MinijuegoRompecabezas.tscn", 6.0],
	["Minijuego Mashear Boton", "res://scenes/minigames/mashear_boton/MinijuegoMashearBoton.tscn", 10.0],
	["Minijuego Osu (Nudo en la Red)", "res://scenes/minigames/osu_killer/MinijuegoOsuKiller.tscn", 10.0],
	["Cinematica Calle", "res://scenes/cinematics/CinematicaCalle.tscn", 6.0],
	["Cinematica Cuarto", "res://scenes/cinematics/CinematicaCuarto.tscn", 6.0],
]


func _ready() -> void:
	print("PERF_HW|", OS.get_name(), "|", OS.get_processor_name(), "|", RenderingServer.get_video_adapter_name(),
		"|", get_viewport().get_visible_rect().size, "|vsync=", DisplayServer.window_get_vsync_mode(),
		"|maxfps=", Engine.max_fps, "|godot=", Engine.get_version_info().get("string", "?"))
	await get_tree().create_timer(1.0).timeout
	for e: Array in ESCENAS:
		await _medir(str(e[0]), str(e[1]), float(e[2]))
	print("PERF_DONE")


func _medir(nombre: String, ruta: String, dur: float) -> void:
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		print("PERF|", nombre, "|NO SE PUDO CARGAR")
		return
	var n: Node = ps.instantiate()
	if "espera_inicial" in n:
		n.set("espera_inicial", 0.0)
	add_child(n)
	await _muestrear(nombre, dur)
	if n.has_method("set_furia"):
		n.call("set_furia", true)
		await _muestrear(nombre + " [furia]", 4.0)
	n.queue_free()
	await get_tree().create_timer(0.8).timeout


func _muestrear(nombre: String, dur: float) -> void:
	await get_tree().create_timer(dur * 0.4).timeout   # calentamiento
	var fps: Array[float] = []
	var proc: Array[float] = []
	var draws: Array[float] = []
	var mem_max: float = 0.0
	var nodos: float = 0.0
	var t: float = 0.0
	while t < dur * 0.6:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		mem_max = maxf(mem_max, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		nodos = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var fps_min: float = fps.min()
	print("PERF|", nombre, "|fps_prom=%.1f|fps_min=%.1f|proceso_ms=%.2f|drawcalls=%.0f|mem_estatica_MB=%.1f|nodos=%d" % [
		_prom(fps), fps_min, _prom(proc), _prom(draws), mem_max, int(nodos)])


func _prom(a: Array[float]) -> float:
	var s: float = 0.0
	for v: float in a:
		s += v
	return s / float(a.size())
