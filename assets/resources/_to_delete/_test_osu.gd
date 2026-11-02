extends Node

var _saltado: bool = false

func _ready() -> void:
	var scn: Node = load("res://scenes/minigames/osu_killer/MinijuegoOsuKiller.tscn").instantiate()
	scn.connect("saltado", func() -> void: _saltado = true)
	add_child(scn)
	await get_tree().process_frame
	scn._intro = false
	scn._iniciar_intento()
	scn._spawn_timer = 999.0
	scn._raiz.modulate.a = 1.0
	var Cls: Variant = scn.get_script().get_script_constant_map()["Nodo"]

	var m: Vector2 = scn._raiz.get_local_mouse_position()
	var n: Variant = Cls.new()
	n.pos = m
	n.t = scn.APPROACH_TIME
	scn._nodos.append(n)
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_Z
	ev.pressed = true
	scn._input(ev)
	print("TEST puntos tras Z: ", scn.puntos, " (esperado 300)")

	var n2: Variant = Cls.new()
	n2.pos = m
	n2.t = scn.APPROACH_TIME
	scn._nodos.append(n2)
	var ev2: InputEventKey = InputEventKey.new()
	ev2.keycode = KEY_X
	ev2.pressed = true
	scn._input(ev2)
	print("TEST puntos tras X: ", scn.puntos, " (esperado 600)")

	# Z mantenida cuenta como clic sostenido (no se puede simular la tecla: solo se comprueba que no falla)
	print("TEST sostenida sin pulsar: ", scn._accion_sostenida(), " (esperado false)")

	scn.derrotas = 1
	scn._terminar_intento(false)
	print("TEST derrotas=", scn.derrotas, " boton visible=", scn._btn_saltar.visible, " (esperado 2 / false)")
	scn._terminar_intento(false)
	print("TEST derrotas=", scn.derrotas, " boton visible=", scn._btn_saltar.visible, " (esperado 3 / true)")
	await get_tree().process_frame
	await get_tree().process_frame
	print("TEST rect boton: ", scn._btn_saltar.get_global_rect(), " ventana: ", get_viewport().get_visible_rect().size)

	scn._btn_saltar.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	print("TEST saltado emitido: ", _saltado, " | minijuego liberado: ", not is_instance_valid(scn))
	print("FIN_TEST")
