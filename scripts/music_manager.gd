extends Node
## Música de fondo con transiciones suaves (fade out / fade in) y repetición con pausa.
##
## - play_track(id) cambia de canción con fundido cruzado; si ya suena esa, no hace nada.
## - Al terminar una canción espera LOOP_GAP segundos y la repite.
## - Sigue sonando con el juego pausado (menú de pausa).
## main.gd crea una instancia y es el único que la usa.

const TRACKS: Dictionary = {
	"menu": "res://assets/sounds/main-menu.mp3",
	"darwin": "res://assets/sounds/darwins-theme.mp3",
	"romina": "res://assets/sounds/rominas-theme.mp3",
	"minijuego1": "res://assets/sounds/minigame-1.mp3",
	"minijuego2": "res://assets/sounds/minigame-2.mp3",
}

const FADE_TIME: float = 1.5
const LOOP_GAP: float = 3.0      # segundos de silencio entre una vuelta y la siguiente
const SILENT_DB: float = -60.0
const MUSIC_DB: float = -3.0

var _players: Array[AudioStreamPlayer] = []
var _current: AudioStreamPlayer = null
var _track_id: String = ""
var _tweens: Dictionary = {}     # AudioStreamPlayer -> Tween
var _gap_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = SILENT_DB
		p.finished.connect(_on_player_finished.bind(p))
		add_child(p)
		_players.append(p)

	_gap_timer = Timer.new()
	_gap_timer.one_shot = true
	_gap_timer.wait_time = LOOP_GAP
	_gap_timer.timeout.connect(_on_gap_timeout)
	add_child(_gap_timer)


## Cambia a la canción `id` ("" = silencio). No reinicia si ya es la actual.
func play_track(id: String, fade: float = FADE_TIME) -> void:
	if id == _track_id:
		return
	_track_id = id
	_gap_timer.stop()

	var old: AudioStreamPlayer = _current
	_current = null
	if old != null:
		_fade_out(old, fade)

	if id == "":
		return

	var stream: AudioStream = _load_stream(id)
	if stream == null:
		push_warning("[Música] No se pudo cargar la canción '%s'." % id)
		return

	# Se usa el reproductor que no está sonando como canción actual.
	var next: AudioStreamPlayer = _players[0] if old != _players[0] else _players[1]
	_kill_tween(next)
	next.stop()
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_current = next
	_fade_to(next, MUSIC_DB, fade)


func stop_music(fade: float = FADE_TIME) -> void:
	play_track("", fade)


func current_track() -> String:
	return _track_id


func _load_stream(id: String) -> AudioStream:
	var path: String = str(TRACKS.get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	# El bucle lo manejamos nosotros (con pausa), así que el stream no debe repetirse solo.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	return stream


func _on_player_finished(player: AudioStreamPlayer) -> void:
	if player == _current and _track_id != "":
		_gap_timer.start(LOOP_GAP)


func _on_gap_timeout() -> void:
	if _current != null and _track_id != "":
		_kill_tween(_current)
		_current.volume_db = MUSIC_DB
		_current.play()


func _fade_to(player: AudioStreamPlayer, target_db: float, time: float) -> void:
	_kill_tween(player)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "volume_db", target_db, time)
	_tweens[player] = t


func _fade_out(player: AudioStreamPlayer, time: float) -> void:
	_kill_tween(player)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "volume_db", SILENT_DB, time)
	t.tween_callback(player.stop)
	_tweens[player] = t


func _kill_tween(player: AudioStreamPlayer) -> void:
	var t: Variant = _tweens.get(player, null)
	if t is Tween and (t as Tween).is_valid():
		(t as Tween).kill()
	_tweens.erase(player)
