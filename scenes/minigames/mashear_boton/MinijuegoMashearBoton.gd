extends CanvasLayer
## Minijuego 2 de Darwin — "El Peso del Silencio" (machacar ESPACIO).
##
## Mantén el marcador dentro de la zona móvil mientras caen palabras despectivas.
## Si fallas, el minijuego se reinicia solo (RETRY); `completado` se emite únicamente al ganar
## y el nodo se destruye solo, igual que los otros minijuegos.
##
## Pensado para jugarse SOBRE una cinemática: el fondo es semitransparente y todo entra con un
## fade-in. `espera_inicial` son los segundos que corre la cinemática antes de aparecer.
## El input va por _input (y se marca como manejado) porque Dialogic está pausado pero su
## DialogicNode_Input se comería ESPACIO como "avanzar diálogo".

signal completado
## Cambia cuando el marcador sale o vuelve a la zona segura (la cinemática lo usa para la furia de Darwin).
signal fuera_de_zona_cambiado(fuera: bool)

const UI = preload("res://scripts/ui/ui_style.gd")
const C = preload("res://scripts/ui/ui_colors.gd")

# --- Dificultad ---
const DURATION: float = 45.0        # segundos a sobrevivir
const PUSH: float = 0.065           # empuje por pulsación
const DRIFT: float = 0.18           # resistencia constante por segundo
const GUST: float = 0.05            # variación de ráfagas
const SAFE_HALF: float = 0.12       # mitad del ancho de la zona segura
const MAX_OUTSIDE: float = 2.0      # segundos tolerados fuera de la zona
const RESULT_TIME: float = 1.5      # cuánto se muestra el resultado
const ZONE_RANGE: float = 0.25      # cuánto se aleja la zona del centro
const ZONE_SPEED: float = 0.9       # velocidad de movimiento de la zona

# --- Apariencia ---
const FADE_IN_TIME: float = 1.0
const FADE_OUT_TIME: float = 0.6
const INSTRUCCION_TIME: float = 3.0   # la instrucción se lee este tiempo antes de empezar
const SHADE: Color = Color(0.02, 0.02, 0.07, 0.62)   # sombrea la cinemática de fondo
const WORDS: Array[String] = [
	"Raro", "Fenómeno", "Extraño", "Callado", "Rarito", "Nadie te habló",
	"Qué asco", "Invisible", "Molesto", "Solo", "Cállate", "Das pena",
]
const WORD_INTERVAL: float = 0.5
const WORD_SPEED: Vector2 = Vector2(70.0, 180.0)
const WORD_SIZE: Vector2i = Vector2i(24, 56)
const WORD_ALPHA: Vector2 = Vector2(0.12, 0.42)
const WORD_DRIFT: Vector2 = Vector2(-18.0, 18.0)

## Segundos de espera antes de mostrar el minijuego (la cinemática corre mientras tanto).
var espera_inicial: float = 0.0

var value: float = 0.5
var display_value: float = 0.5
var zone_center: float = 0.5
var elapsed: float = 0.0
var outside_time: float = 0.0
var running: bool = false

var _raiz: Control
var _palabras: Control
var _result: String = ""            # "", "win" o "lose"
var _result_timer: float = 0.0
var _phase: float = 0.0
var _zone_phase: float = 0.0
var _flash: float = 0.0
var _word_timer: float = 0.0
var _speeds: Dictionary = {}        # Label -> Vector2
var _terminado: bool = false
var _fuera: bool = false


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP   # que el clic no avance el diálogo
	_raiz.modulate.a = 0.0
	add_child(_raiz)

	var sombra: ColorRect = ColorRect.new()
	sombra.color = SHADE
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)

	_palabras = Control.new()
	_palabras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_palabras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palabras.clip_contents = true
	_raiz.add_child(_palabras)

	var dibujo: Control = Control.new()
	dibujo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dibujo.draw.connect(_dibujar.bind(dibujo))
	_raiz.add_child(dibujo)
	dibujo.name = "Dibujo"

	_entrar()


func _entrar() -> void:
	if espera_inicial > 0.0:
		await get_tree().create_timer(espera_inicial).timeout
	var tween: Tween = create_tween()
	tween.tween_property(_raiz, "modulate:a", 1.0, FADE_IN_TIME)
	await tween.finished
	# Con el minijuego ya visible pero sin correr, se deja leer la instrucción.
	await get_tree().create_timer(INSTRUCCION_TIME).timeout
	_iniciar_intento()


func _iniciar_intento() -> void:
	elapsed = 0.0
	outside_time = 0.0
	_phase = randf() * TAU
	_zone_phase = randf() * TAU
	zone_center = _zona_en(0.0)
	value = zone_center
	display_value = value
	_result = ""
	running = true


func _zona_en(t: float) -> float:
	# Dos ondas combinadas: movimiento suave pero poco predecible.
	var w: float = sin(t * ZONE_SPEED + _zone_phase) * 0.6 + sin(t * ZONE_SPEED * 2.3 + _zone_phase * 1.7) * 0.4
	return 0.5 + ZONE_RANGE * w


func _input(event: InputEvent) -> void:
	if not running:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.keycode == KEY_SPACE:
		if key.pressed and not key.echo:
			value += PUSH
			_flash = 1.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_actualizar_palabras(delta)
	_flash = maxf(0.0, _flash - delta * 8.0)

	if running:
		elapsed += delta
		zone_center = _zona_en(elapsed)

		var gust: float = sin(elapsed * 1.7 + _phase) * 0.5 + sin(elapsed * 0.6 + _phase * 2.0) * 0.5
		value -= maxf(DRIFT + gust * GUST, 0.03) * delta

		var fuera: bool = absf(value - zone_center) > SAFE_HALF
		_set_fuera(fuera)
		if fuera:
			outside_time += delta
		else:
			outside_time = maxf(0.0, outside_time - delta * 0.5)

		if value <= 0.0 or value >= 1.0 or outside_time >= MAX_OUTSIDE:
			value = clampf(value, 0.0, 1.0)
			_terminar_intento(false)
		elif elapsed >= DURATION:
			_terminar_intento(true)
	elif _result == "lose":
		_result_timer -= delta
		if _result_timer <= 0.0:
			_iniciar_intento()   # RETRY

	display_value = lerpf(display_value, value, 1.0 - exp(-20.0 * delta))
	var dibujo: Node = _raiz.get_node_or_null("Dibujo")
	if dibujo != null:
		(dibujo as Control).queue_redraw()


func _set_fuera(fuera: bool) -> void:
	if fuera == _fuera:
		return
	_fuera = fuera
	fuera_de_zona_cambiado.emit(fuera)


func _terminar_intento(gano: bool) -> void:
	running = false
	_set_fuera(false)
	_result = "win" if gano else "lose"
	_result_timer = RESULT_TIME
	if gano:
		_ganar()


func _ganar() -> void:
	if _terminado:
		return
	_terminado = true
	await get_tree().create_timer(RESULT_TIME).timeout
	var tween: Tween = create_tween()
	tween.tween_property(_raiz, "modulate:a", 0.0, FADE_OUT_TIME)
	await tween.finished
	completado.emit()
	queue_free()


# ──────────────────────────────────────────────
# PALABRAS QUE CAEN
# ──────────────────────────────────────────────

func _actualizar_palabras(delta: float) -> void:
	if _raiz.modulate.a <= 0.01:
		return
	_word_timer -= delta
	if _word_timer <= 0.0:
		_word_timer = WORD_INTERVAL
		_nueva_palabra()

	for label: Label in _speeds.keys():
		label.position += (_speeds[label] as Vector2) * delta
		if label.position.y > _palabras.size.y:
			_speeds.erase(label)
			label.queue_free()


func _nueva_palabra() -> void:
	var label: Label = Label.new()
	label.text = WORDS.pick_random()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI.PIX_FONT)
	label.add_theme_font_size_override("font_size", randi_range(WORD_SIZE.x, WORD_SIZE.y))
	label.modulate = Color(C.TEXT, randf_range(WORD_ALPHA.x, WORD_ALPHA.y))
	_palabras.add_child(label)
	label.position = Vector2(
		randf_range(0.0, maxf(_palabras.size.x - 260.0, 0.0)),
		-label.get_minimum_size().y
	)
	_speeds[label] = Vector2(
		randf_range(WORD_DRIFT.x, WORD_DRIFT.y),
		randf_range(WORD_SPEED.x, WORD_SPEED.y)
	)


# ──────────────────────────────────────────────
# DIBUJO DE LA BARRA
# ──────────────────────────────────────────────

func _dibujar(c: Control) -> void:
	var font: Font = UI.PIX_FONT
	var vs: Vector2 = c.size
	var bar_w: float = minf(vs.x * 0.5, 960.0)
	var bar_h: float = 44.0
	var cx: float = vs.x * 0.5
	var bar: Rect2 = Rect2(cx - bar_w * 0.5, vs.y - 190.0, bar_w, bar_h)
	var fondo_barra: Color = Color(C.BG_DEEP, 0.92)

	# Progreso (arriba)
	var prog: Rect2 = Rect2(bar.position.x, bar.position.y - 36.0, bar_w, 10.0)
	c.draw_rect(prog, fondo_barra)
	c.draw_rect(Rect2(prog.position, Vector2(bar_w * clampf(elapsed / DURATION, 0.0, 1.0), prog.size.y)), C.ACCENT_BLUE)
	c.draw_rect(prog, C.PANEL_BORDER, false, 2.0)

	# Barra y zona segura (se mueve)
	c.draw_rect(bar, fondo_barra)
	var safe_w: float = bar_w * SAFE_HALF * 2.0
	var zx: float = bar.position.x + bar_w * zone_center
	c.draw_rect(Rect2(zx - safe_w * 0.5, bar.position.y, safe_w, bar_h), Color(C.ACCENT_BLUE, 0.55))
	c.draw_rect(Rect2(zx - safe_w * 0.5, bar.position.y, safe_w, bar_h), C.ACCENT_BLUE, false, 2.0)

	# Marcador
	var outside: bool = absf(value - zone_center) > SAFE_HALF
	var mx: float = bar.position.x + bar_w * clampf(display_value, 0.0, 1.0)
	c.draw_rect(Rect2(mx - 6.0, bar.position.y - 10.0, 12.0, bar_h + 20.0),
			Color(0.85, 0.42, 0.5) if outside else C.TITLE)
	c.draw_rect(bar, Color(C.ACCENT, 0.45 + 0.55 * _flash), false, 4.0)

	# Tolerancia (abajo)
	var tol: Rect2 = Rect2(bar.position.x, bar.end.y + 14.0, bar_w, 10.0)
	c.draw_rect(tol, fondo_barra)
	c.draw_rect(Rect2(tol.position, Vector2(bar_w * clampf(outside_time / MAX_OUTSIDE, 0.0, 1.0), tol.size.y)), Color(0.85, 0.42, 0.5))
	c.draw_rect(tol, C.PANEL_BORDER, false, 2.0)

	var msg: String = "Presiona rápidamente ESPACIO para mantenerte en la zona"
	if _result == "win" || _result == "lose":
		msg = "..."
	var tw: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(font, Vector2(cx - tw * 0.5, tol.end.y + 52.0), msg,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, C.TEXT)
