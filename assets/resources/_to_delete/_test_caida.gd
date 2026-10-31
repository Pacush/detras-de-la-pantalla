extends Node
## Prueba temporal: reproduce la caída/levantarse de Darwin y la imprime.

var main: Node = null
var t: float = 0.0
var avance: float = 0.0

func _ready() -> void:
	print("[TEST] fall exists=", ResourceLoader.exists("res://assets/sounds/fall.mp3"), " load=", load("res://assets/sounds/fall.mp3"), " paper load=", load("res://assets/sounds/paper_rip.mp3"))
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(1.0).timeout
	main.game_started = true
	if main.current_menu:
		main.current_menu.queue_free()
		main.current_menu = null
	main._free_backdrop()
	main.background_node.show()
	Dialogic.signal_event.connect(_on_signal)
	var tl: DialogicTimeline = DialogicTimeline.new()
	tl.from_text("""[style name="style2 (custom)"]
[background arg="res://assets/backgrounds/school.png" fade="0.0"]
join darwin (broken) center [animation="Fade In" length="0.1"]
[wait time="0.5"]
Ahi es cuando siento un empujon.
[wait time="0.3"]
[signal arg="darwin_caer"]
[wait time="0.4"]
Mi mochila sale volando.
[wait time="0.3"]
[signal arg="sfx_papel"]
Arrancan paginas.
[wait time="0.3"]
[signal arg="darwin_levantarse"]
[wait time="0.4"]
Fin de la prueba.
""")
	Dialogic.start(tl)
	print("[TEST] timeline iniciado")


func _on_signal(s: String) -> void:
	print("[TEST ", snappedf(t, 0.01), "] signal_event: ", s, "  paused(ya procesado por main)=", Dialogic.paused)
	await get_tree().process_frame
	await get_tree().process_frame
	var n: int = 0
	for h: Node in main.get_children():
		if h is AudioStreamPlayer:
			n += 1
	print("[TEST ", snappedf(t, 0.01), "] 2 frames despues de ", s, ": paused=", Dialogic.paused, " AudioStreamPlayers en main=", n)


func _process(delta: float) -> void:
	t += delta
	avance += delta
	if main == null:
		return
	if avance > 0.7:
		avance = 0.0
		Dialogic.Inputs.dialogic_action.emit()
	var darwin: DialogicCharacter = DialogicResourceUtil.get_character_resource("darwin")
	if darwin != null and Dialogic.Portraits.is_character_joined(darwin):
		var nodo: Node = Dialogic.Portraits.get_character_node(darwin)
		if nodo != null and Engine.get_process_frames() % 60 == 0:
			print("[TEST ", snappedf(t, 0.01), "] darwin.y=", snappedf(nodo.position.y, 0.1), " textbox=", Dialogic.Text.is_textbox_visible(), " paused=", Dialogic.paused)
	if t > 25.0:
		get_tree().quit()
