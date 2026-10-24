extends RefCounted
## Sonido de click de la interfaz. Un único reproductor compartido, colgado de la raíz del árbol
## para que siga sonando aunque el botón se destruya al instante (p. ej. "Atrás") y con el juego pausado.
##
##   const Click = preload("res://scripts/ui/ui_click.gd")
##   Click.play(self)

const CLICK_PATH: String = "res://assets/sounds/interface-click.mp3"

static var _player: AudioStreamPlayer = null


static func play(from: Node) -> void:
	if not is_instance_valid(_player):
		if not ResourceLoader.exists(CLICK_PATH):
			return
		var stream: AudioStream = load(CLICK_PATH) as AudioStream
		if stream == null:
			return
		_player = AudioStreamPlayer.new()
		_player.stream = stream
		_player.volume_db = -3.0
		_player.bus = &"Master"
		_player.max_polyphony = 4          # clicks rápidos se superponen en vez de cortarse
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		from.get_tree().root.add_child(_player)
	_player.play()
