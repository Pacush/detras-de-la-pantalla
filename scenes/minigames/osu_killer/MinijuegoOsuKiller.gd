extends CanvasLayer
## Minijuego 2 de Romina — "El Nudo en la Red" (estilo osu!).
##
## Haz clic en los nodos cuando el anillo los alcance; en las líneas, mantén el clic y sigue
## la bolita hasta el final. Demasiados fallos y el nudo se cierra: el minijuego se reinicia
## solo (RETRY). `completado` se emite únicamente al ganar y el nodo se destruye solo.
##
## Todo el input va por un Control raíz (gui_input), igual que la mochila y el rompecabezas:
## Dialogic (DialogicNode_Input) se come los eventos de mouse en la fase GUI, así que Area2D o
## _unhandled_input no funcionarían. Los nodos no son escenas: se dibujan en un solo Control.
##
## Estética: nodos dibujados en baja resolución (1/3) y escalados sin filtro (pixel art), con la
## paleta de los menús. Cada acierto/fallo lanza una animación; los sliders muestran con ondas,
## anillo giratorio y estela que se está manteniendo el clic.
##
## Pensado para jugarse SOBRE una cinemática de fondo: fondo semitransparente, fade-in propio,
## `espera_inicial` segundos de cinemática antes de aparecer y luego INSTRUCCION_TIME segundos
## con la instrucción a la vista antes de empezar.

signal completado
## Se suma un fallo (nodo perdido); la cinematica de fondo reacciona.
signal fallo_sumado

const UI = preload("res://scripts/ui/ui_style.gd")
const C = preload("res://scripts/ui/ui_colors.gd")

# --- Reglas (frenético: muchos nodos, rápidos) ---
const MIN_DURATION: float = 16.0          # la partida dura entre MIN y MAX segundos
const MAX_DURATION: float = 21.0
const SPAWN_START: float = 0.62           # segundos entre nodos al empezar...
const SPAWN_END: float = 0.34             # ...y al final de la partida (acelera)
const PAIR_CHANCE: float = 0.28           # probabilidad de que salgan dos nodos a la vez
const SLIDER_CHANCE: float = 0.16
const MAX_FALLOS: int = 7                 # al séptimo fallo, RETRY

# --- Nodos ---
const PIX: int = 3                        # los nodos se dibujan a 1/3 de resolución
const RADIO: float = 48.0                 # en píxeles de pantalla
const APPROACH_TIME: float = 0.8
const MISS_GRACE: float = 0.25            # margen tras llegar el anillo antes de contar fallo
const SLIDE_TIME: float = 1.1
const SLIDER_START_WINDOW: float = 0.3    # qué tan cerca del tiempo hay que empezar un slider
const FOLLOW_RADIO: float = 62.0
const SLIDER_LEN: Vector2 = Vector2(230.0, 400.0)
const MAX_DIST_FRAC: float = 0.25        # un nodo nuevo sale como mucho a 1/4 del ancho de pantalla del anterior
const MARGEN_X: float = 140.0
const MARGEN_TOP: float = 150.0           # deja libre el HUD
const MARGEN_BOTTOM: float = 150.0
const POP_TIME: float = 0.14              # animación de aparición
const EFECTO_TIME: float = 0.4

# --- Apariencia ---
const FADE_IN_TIME: float = 1.0
const FADE_OUT_TIME: float = 0.6
const INSTRUCCION_TIME: float = 5.0
const RESULT_TIME: float = 1.5
const SHADE: Color = Color(0.02, 0.03, 0.08, 0.62)   # sombrea la cinemática de fondo
const COL_CUERPO: Color = Color(0.09, 0.10, 0.22, 0.96)
const COL_CAMINO: Color = Color(0.12, 0.14, 0.30, 0.92)
const COL_SOMBRA: Color = Color(0.0, 0.0, 0.03, 0.55)
const COL_ROJO: Color = Color(0.85, 0.42, 0.5)

const INSTRUCCION: Array[String] = [
	"Bloquea los nodos: haz clic cuando el anillo los alcance.",
	"En las líneas, mantén el clic y desliza siguiendo el nodo.",
	"Cinco fallos y el nudo se cierra.",
]


## Un nodo en pantalla: círculo simple o slider (línea que se sigue con el mouse).
class Nodo extends RefCounted:
	var es_slider: bool = false
	var pos: Vector2 = Vector2.ZERO
	var fin: Vector2 = Vector2.ZERO
	var t: float = 0.0                    # tiempo desde que apareció
	var deslizando: bool = false
	var slide_t: float = 0.0
	var seguido: float = 0.0              # tiempo que el mouse siguió la bolita
	var siguiendo: bool = false
	var estela: float = 0.0               # temporizador de la estela


## Texto flotante con la puntuación de cada nodo.
class Aviso extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var texto: String = ""
	var color: Color = Color.WHITE
	var edad: float = 0.0


## Animación al pulsar/fallar un nodo: aplastamiento, onda expansiva y chispas.
class Efecto extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE
	var fallo: bool = false
	var edad: float = 0.0
	var dur: float = 0.4
	var escala: float = 1.0
	var dirs: PackedVector2Array = PackedVector2Array()
	var vels: PackedFloat32Array = PackedFloat32Array()


## Partícula suelta (estela de la bolita del slider).
class Chispa extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var edad: float = 0.0
	var vida: float = 0.4
	var color: Color = Color.WHITE


## Segundos que corre la cinemática de fondo antes de mostrar el minijuego (la fija main.gd).
var espera_inicial: float = 0.0

var running: bool = false
var puntos: int = 0
var fallos: int = 0
var combo: int = 0
var elapsed: float = 0.0
var duracion: float = 16.0

var _raiz: Control
var _mundo: Control                       # nodos y efectos, en baja resolución
var _dibujo: Control                      # HUD y textos, a resolución completa
var _nodos: Array[Nodo] = []
var _avisos: Array[Aviso] = []
var _efectos: Array[Efecto] = []
var _chispas: Array[Chispa] = []
var _spawn_timer: float = 0.0
var _ultimo_fue_slider: bool = false
var _ultima_pos: Vector2 = Vector2(-1.0, -1.0)   # donde termino el ultimo nodo generado
var _slider_activo: bool = false
var _result: String = ""                  # "", "win" o "lose"
var _result_timer: float = 0.0
var _intro: bool = true                   # la instrucción se muestra grande antes de empezar
var _terminado: bool = false
var _tiempo: float = 0.0                  # reloj para animaciones continuas
var _combo_pop: float = 0.0


func _ready() -> void:
	randomize()
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.gui_input.connect(_on_gui_input)
	_raiz.modulate.a = 0.0
	add_child(_raiz)

	var sombra: ColorRect = ColorRect.new()
	sombra.color = SHADE
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)

	# Nodos en baja resolución (pixel art), sobre fondo transparente.
	var contenedor: SubViewportContainer = SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.stretch_shrink = PIX
	contenedor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(contenedor)

	var sub: SubViewport = SubViewport.new()
	sub.transparent_bg = true
	sub.handle_input_locally = false
	contenedor.add_child(sub)

	_mundo = Control.new()
	_mundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mundo.draw.connect(_dibujar_mundo)
	sub.add_child(_mundo)

	_dibujo = Control.new()
	_dibujo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dibujo.draw.connect(_dibujar_hud)
	_raiz.add_child(_dibujo)

	_entrar()


func _entrar() -> void:
	if espera_inicial > 0.0:
		await get_tree().create_timer(espera_inicial).timeout
	var tween: Tween = create_tween()
	tween.tween_property(_raiz, "modulate:a", 1.0, FADE_IN_TIME)
	await tween.finished
	# Con el minijuego visible pero sin correr, se deja leer la instrucción.
	await get_tree().create_timer(INSTRUCCION_TIME).timeout
	_intro = false
	_iniciar_intento()


func _iniciar_intento() -> void:
	_nodos.clear()
	_avisos.clear()
	_efectos.clear()
	_chispas.clear()
	puntos = 0
	fallos = 0
	combo = 0
	elapsed = 0.0
	duracion = randf_range(MIN_DURATION, MAX_DURATION)
	_spawn_timer = 0.3
	_ultimo_fue_slider = false
	_ultima_pos = Vector2(-1.0, -1.0)
	_slider_activo = false
	_result = ""
	running = true


# ──────────────────────────────────────────────
# BUCLE
# ──────────────────────────────────────────────

func _process(delta: float) -> void:
	_tiempo += delta
	_combo_pop = maxf(0.0, _combo_pop - delta * 5.0)

	for i: int in range(_avisos.size() - 1, -1, -1):
		_avisos[i].edad += delta
		if _avisos[i].edad > 0.7:
			_avisos.remove_at(i)
	for i: int in range(_efectos.size() - 1, -1, -1):
		_efectos[i].edad += delta
		if _efectos[i].edad > _efectos[i].dur:
			_efectos.remove_at(i)
	for i: int in range(_chispas.size() - 1, -1, -1):
		var ch: Chispa = _chispas[i]
		ch.edad += delta
		ch.pos += ch.vel * delta
		if ch.edad > ch.vida:
			_chispas.remove_at(i)

	if running:
		elapsed += delta
		var generando: bool = elapsed < duracion
		if generando:
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_timer = lerpf(SPAWN_START, SPAWN_END, clampf(elapsed / duracion, 0.0, 1.0))
				_generar()
		for n: Nodo in _nodos.duplicate():
			_actualizar_nodo(n, delta)
		if running and not generando and _nodos.is_empty():
			_terminar_intento(true)
	elif _result == "lose":
		_result_timer -= delta
		if _result_timer <= 0.0:
			_iniciar_intento()   # RETRY

	_mundo.queue_redraw()
	_dibujo.queue_redraw()


func _generar() -> void:
	# Mientras hay un slider en pantalla no salen más nodos (no podrías hacer clic en ellos).
	if _slider_activo:
		return
	var primero: Nodo = Nodo.new()
	primero.pos = _pos_libre(Vector2(-9999.0, -9999.0), _ultima_pos)
	if not _ultimo_fue_slider and randf() < SLIDER_CHANCE:
		primero.es_slider = true
		var vp: Vector2 = _raiz.size
		var dir: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		var fin: Vector2 = primero.pos + dir * randf_range(SLIDER_LEN.x, SLIDER_LEN.y)
		fin.x = clampf(fin.x, MARGEN_X, vp.x - MARGEN_X)
		fin.y = clampf(fin.y, MARGEN_TOP, vp.y - MARGEN_BOTTOM)
		primero.fin = fin
		_slider_activo = true
	_ultimo_fue_slider = primero.es_slider
	_ultima_pos = primero.fin if primero.es_slider else primero.pos
	_nodos.append(primero)

	# A veces salen dos a la vez (más frenético).
	if not primero.es_slider and randf() < PAIR_CHANCE:
		var segundo: Nodo = Nodo.new()
		segundo.pos = _pos_libre(primero.pos, primero.pos)
		_ultima_pos = segundo.pos
		segundo.t = -0.12                 # aparece un instante después
		_nodos.append(segundo)


## Posición al azar que no se pisa con los nodos actuales ni con `evitar`.
func _pos_libre(evitar: Vector2, centro: Vector2) -> Vector2:
	var vp: Vector2 = _raiz.size
	var max_d: float = vp.x * MAX_DIST_FRAC
	var pos: Vector2 = Vector2.ZERO
	for _i: int in 20:
		if centro.x < 0.0:
			pos = Vector2(
				randf_range(MARGEN_X, vp.x - MARGEN_X),
				randf_range(MARGEN_TOP, vp.y - MARGEN_BOTTOM)
			)
		else:
			# Punto al azar dentro del circulo de radio max_d alrededor del nodo anterior.
			var d: float = max_d * sqrt(randf())
			pos = centro + Vector2.RIGHT.rotated(randf() * TAU) * d
			pos.x = clampf(pos.x, MARGEN_X, vp.x - MARGEN_X)
			pos.y = clampf(pos.y, MARGEN_TOP, vp.y - MARGEN_BOTTOM)
		var libre: bool = pos.distance_to(evitar) > RADIO * 3.2
		for n: Nodo in _nodos:
			if pos.distance_to(n.pos) < RADIO * 2.6 or (n.es_slider and pos.distance_to(n.fin) < RADIO * 2.6):
				libre = false
		if libre:
			return pos
	return pos


func _actualizar_nodo(n: Nodo, delta: float) -> void:
	if not n.deslizando:
		n.t += delta
		if n.t > APPROACH_TIME + MISS_GRACE:
			_resolver(n, 0)
		return

	n.slide_t += delta
	var bolita: Vector2 = _pos_bolita(n)
	var mouse: Vector2 = _raiz.get_local_mouse_position()
	n.siguiendo = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mouse.distance_to(bolita) <= FOLLOW_RADIO
	if n.siguiendo:
		n.seguido += delta
		# Estela de chispas mientras se mantiene el clic sobre la bolita.
		n.estela -= delta
		if n.estela <= 0.0:
			n.estela = 0.03
			var ch: Chispa = Chispa.new()
			ch.pos = bolita + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			ch.vel = Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
			ch.vida = randf_range(0.3, 0.5)
			ch.color = C.ACCENT if randf() < 0.5 else C.ACCENT_BLUE
			_chispas.append(ch)
	if n.slide_t >= SLIDE_TIME:
		_resolver(n, _puntos_slider(n))


func _pos_bolita(n: Nodo) -> Vector2:
	return n.pos.lerp(n.fin, clampf(n.slide_t / SLIDE_TIME, 0.0, 1.0))


func _puntos_slider(n: Nodo) -> int:
	var ratio: float = n.seguido / SLIDE_TIME
	if ratio >= 0.9:
		return 300
	if ratio >= 0.6:
		return 100
	if ratio >= 0.3:
		return 50
	return 0


func _puntos_circulo(n: Nodo) -> int:
	var dif: float = absf(APPROACH_TIME - n.t)
	if dif <= 0.06:
		return 300
	if dif <= 0.14:
		return 100
	if dif <= 0.24:
		return 50
	return 0


func _color_puntos(pts: int) -> Color:
	match pts:
		300:
			return C.TITLE
		100:
			return C.ACCENT_BLUE
		50:
			return C.ACCENT
	return COL_ROJO


## Un nodo se resuelve con `pts` puntos (0 = fallo).
func _resolver(n: Nodo, pts: int) -> void:
	if not _nodos.has(n):
		return
	_nodos.erase(n)
	if n.es_slider:
		_slider_activo = false
	puntos += pts

	# Dónde ocurre la animación: un slider terminado explota en su final.
	var donde: Vector2 = n.pos
	if n.es_slider and n.deslizando:
		donde = _pos_bolita(n)
	_lanzar_efecto(donde, _color_puntos(pts), pts == 0, 1.0 if pts < 300 else 1.25)

	var aviso: Aviso = Aviso.new()
	aviso.pos = donde
	aviso.texto = str(pts) if pts > 0 else "X"
	aviso.color = _color_puntos(pts)
	_avisos.append(aviso)

	if pts == 0:
		fallos += 1
		combo = 0
		fallo_sumado.emit()
		if fallos >= MAX_FALLOS and running:
			_terminar_intento(false)
	else:
		combo += 1
		_combo_pop = 1.0


func _lanzar_efecto(pos: Vector2, color: Color, fallo: bool, escala: float) -> void:
	var e: Efecto = Efecto.new()
	e.pos = pos
	e.color = color
	e.fallo = fallo
	e.escala = escala
	e.dur = EFECTO_TIME
	var cuantas: int = 6 if fallo else 11
	for i: int in cuantas:
		var ang: float = TAU * float(i) / float(cuantas) + randf_range(-0.25, 0.25)
		e.dirs.append(Vector2.RIGHT.rotated(ang))
		e.vels.append(randf_range(70.0, 150.0) * escala)
	_efectos.append(e)


func _terminar_intento(gano: bool) -> void:
	running = false
	_nodos.clear()
	_slider_activo = false
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
# INPUT
# ──────────────────────────────────────────────

func _on_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_raiz.accept_event()
	if mb.pressed and running:
		_clic(mb.position)


func _clic(punto: Vector2) -> void:
	# Se atiende el nodo más antiguo bajo el cursor.
	for n: Nodo in _nodos:
		if n.t < 0.0 or (n.es_slider and n.deslizando):
			continue
		if punto.distance_to(n.pos) > RADIO:
			continue
		if n.es_slider:
			# Solo se puede empezar si el anillo ya está cerca del círculo.
			if absf(APPROACH_TIME - n.t) <= SLIDER_START_WINDOW:
				n.deslizando = true
				_lanzar_efecto(n.pos, C.ACCENT_BLUE, false, 0.7)   # "agarrado"
			else:
				_resolver(n, 0)
		else:
			_resolver(n, _puntos_circulo(n))
		return


# ──────────────────────────────────────────────
# DIBUJO DE NODOS Y EFECTOS (baja resolución)
# ──────────────────────────────────────────────

func _dibujar_mundo() -> void:
	var c: Control = _mundo
	var r: float = RADIO / float(PIX)

	# Los sliders van debajo de los círculos.
	for n: Nodo in _nodos:
		if n.es_slider:
			_dibujar_slider(c, n, r)
	for n: Nodo in _nodos:
		if not n.es_slider:
			_dibujar_circulo(c, n, r)

	for e: Efecto in _efectos:
		_dibujar_efecto(c, e, r)

	for ch: Chispa in _chispas:
		var k: float = ch.edad / ch.vida
		var lado: float = 2.0 if k < 0.6 else 1.0
		c.draw_rect(Rect2((ch.pos / float(PIX)).floor(), Vector2(lado, lado)), Color(ch.color, 1.0 - k))


## Pop de aparición: crece con un pequeño rebote.
func _pop(t: float) -> float:
	var x: float = clampf(t / POP_TIME, 0.0, 1.0)
	return lerpf(0.5, 1.0, 1.0 - pow(1.0 - x, 3.0))


func _dibujar_circulo(c: Control, n: Nodo, r: float) -> void:
	if n.t < 0.0:
		return
	var q: Vector2 = (n.pos / float(PIX)).floor()
	var s: float = _pop(n.t)
	var a: float = clampf(n.t / (POP_TIME * 0.8), 0.0, 1.0)
	var rr: float = r * s
	var progreso: float = clampf(n.t / APPROACH_TIME, 0.0, 1.0)

	c.draw_circle(q + Vector2(2.0, 2.0), rr, Color(COL_SOMBRA, COL_SOMBRA.a * a))   # sombra dura
	c.draw_circle(q, rr, Color(COL_CUERPO, COL_CUERPO.a * a))
	c.draw_arc(q, rr - 1.0, 0.0, TAU, 28, Color(C.ACCENT, a), 2.0, false)
	c.draw_arc(q, rr * 0.58, 0.0, TAU, 20, Color(C.ACCENT_BLUE, 0.55 * a), 1.0, false)
	c.draw_circle(q, 1.6, Color(C.ACCENT, a))

	# Anillo de aproximación (de 3x a 1x): se vuelve blanco al estar a punto de llegar.
	var cerca: float = smoothstep(0.7, 1.0, progreso)
	var col_anillo: Color = C.ACCENT_DIM.lerp(Color.WHITE, 0.35 + 0.65 * cerca)
	c.draw_arc(q, r * lerpf(3.0, 1.0, progreso), 0.0, TAU, 40, Color(col_anillo, a), 1.0 + cerca, false)


func _dibujar_slider(c: Control, n: Nodo, r: float) -> void:
	var a: float = clampf(n.t / (POP_TIME * 0.8), 0.0, 1.0)
	var p0: Vector2 = (n.pos / float(PIX)).floor()
	var p1: Vector2 = (n.fin / float(PIX)).floor()
	var s: float = _pop(n.t)
	var rr: float = r * s
	var dir: Vector2 = (p1 - p0).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * rr

	# Sombra y camino.
	c.draw_line(p0 + Vector2(2, 2), p1 + Vector2(2, 2), Color(COL_SOMBRA, COL_SOMBRA.a * a), rr * 2.0)
	c.draw_circle(p0 + Vector2(2, 2), rr, Color(COL_SOMBRA, COL_SOMBRA.a * a))
	c.draw_circle(p1 + Vector2(2, 2), rr, Color(COL_SOMBRA, COL_SOMBRA.a * a))
	c.draw_line(p0, p1, Color(COL_CAMINO, COL_CAMINO.a * a), rr * 2.0)
	c.draw_circle(p0, rr, Color(COL_CAMINO, COL_CAMINO.a * a))
	c.draw_circle(p1, rr, Color(COL_CAMINO, COL_CAMINO.a * a))
	# Bordes del camino.
	c.draw_line(p0 + perp, p1 + perp, Color(C.ACCENT_DIM, a), 1.0)
	c.draw_line(p0 - perp, p1 - perp, Color(C.ACCENT_DIM, a), 1.0)
	c.draw_arc(p0, rr - 1.0, 0.0, TAU, 28, Color(C.ACCENT, a), 2.0, false)
	c.draw_arc(p1, rr - 1.0, 0.0, TAU, 28, Color(C.ACCENT_BLUE, a), 2.0, false)
	c.draw_circle(p1, 1.6, Color(C.ACCENT_BLUE, a))

	if not n.deslizando:
		# Anillo de aproximación en el inicio.
		var progreso: float = clampf(n.t / APPROACH_TIME, 0.0, 1.0)
		var cerca: float = smoothstep(0.7, 1.0, progreso)
		var col: Color = C.ACCENT_DIM.lerp(Color.WHITE, 0.35 + 0.65 * cerca)
		c.draw_arc(p0, r * lerpf(3.0, 1.0, progreso), 0.0, TAU, 40, Color(col, a), 1.0 + cerca, false)
		c.draw_circle(p0, 1.6, Color(C.ACCENT, a))
		return

	# --- Deslizando: se nota que el clic está pulsado ---
	var bolita: Vector2 = (_pos_bolita(n) / float(PIX)).floor()
	var fr: float = FOLLOW_RADIO / float(PIX)
	var sig: bool = n.siguiendo
	# Tramo ya recorrido, relleno.
	c.draw_line(p0, bolita, Color(C.ACCENT_BLUE, 0.45 if sig else 0.2), rr * 1.1)

	if sig:
		# Ondas que salen de la bolita (clic mantenido).
		for k: int in 3:
			var ph: float = fposmod(_tiempo * 2.2 + float(k) / 3.0, 1.0)
			c.draw_arc(bolita, r * (0.7 + ph * 1.5), 0.0, TAU, 28, Color(C.ACCENT, (1.0 - ph) * 0.7), 1.0, false)
		# Anillo de seguimiento: segmentos que giran, verde-lavanda brillante.
		var col_ring: Color = Color(0.7, 0.95, 0.85, 0.95)
		var giro: float = _tiempo * 3.5
		for i: int in 12:
			var a0: float = giro + TAU * float(i) / 12.0
			c.draw_arc(bolita, fr, a0, a0 + TAU / 12.0 * 0.6, 4, col_ring, 2.0, false)
		var pulso: float = 1.0 + 0.1 * sin(_tiempo * 22.0)
		c.draw_circle(bolita + Vector2(1, 1), r * 0.78 * pulso, COL_SOMBRA)
		c.draw_circle(bolita, r * 0.78 * pulso, C.ACCENT)
		c.draw_circle(bolita, r * 0.46 * pulso, Color.WHITE)
	else:
		# Se perdió el seguimiento o se soltó el clic: anillo rojo parpadeando y bolita apagada.
		var parpadeo: float = 0.5 + 0.5 * sin(_tiempo * 16.0)
		c.draw_arc(bolita, fr, 0.0, TAU, 32, Color(COL_ROJO, 0.35 + 0.5 * parpadeo), 2.0, false)
		c.draw_circle(bolita + Vector2(1, 1), r * 0.7, COL_SOMBRA)
		c.draw_circle(bolita, r * 0.7, C.ACCENT_DIM)
		c.draw_circle(bolita, r * 0.38, C.TEXT_MUTED)


func _dibujar_efecto(c: Control, e: Efecto, r: float) -> void:
	var k: float = clampf(e.edad / e.dur, 0.0, 1.0)
	var q: Vector2 = (e.pos / float(PIX)).floor()
	var s: float = e.escala

	if e.fallo:
		# El nodo se encoge y se tiñe de rojo con una X.
		var rr: float = r * (1.0 - 0.6 * k)
		c.draw_circle(q, rr, Color(COL_ROJO, 0.55 * (1.0 - k)))
		c.draw_arc(q, rr, 0.0, TAU, 24, Color(COL_ROJO, 1.0 - k), 2.0, false)
		var d: float = r * 0.5 * (1.0 - 0.4 * k)
		c.draw_line(q + Vector2(-d, -d), q + Vector2(d, d), Color(COL_ROJO, 1.0 - k), 2.0)
		c.draw_line(q + Vector2(-d, d), q + Vector2(d, -d), Color(COL_ROJO, 1.0 - k), 2.0)
	else:
		# Aplastamiento: el cuerpo se contrae con un destello blanco...
		var squash: float = 1.0 - 0.5 * clampf(k * 3.0, 0.0, 1.0)
		var flash: float = 1.0 - clampf(k * 3.0, 0.0, 1.0)
		c.draw_circle(q, r * squash * s, Color(1, 1, 1, 0.85 * flash))
		c.draw_arc(q, r * squash * s, 0.0, TAU, 28, Color(e.color, flash), 2.0, false)
		# ...y sale una onda expansiva.
		c.draw_arc(q, r * (1.0 + 1.4 * k * s), 0.0, TAU, 36, Color(e.color, 1.0 - k), 2.0 * (1.0 - k) + 1.0, false)

	# Chispas cuadradas que salen disparadas.
	for i: int in e.dirs.size():
		var f: float = 1.0 - pow(1.0 - k, 2.0)
		var p: Vector2 = q + e.dirs[i] * (e.vels[i] / float(PIX)) * f * 0.5
		var lado: float = 2.0 if k < 0.5 else 1.0
		c.draw_rect(Rect2(p.floor(), Vector2(lado, lado)), Color(e.color, 1.0 - k))


# ──────────────────────────────────────────────
# HUD (resolución completa)
# ──────────────────────────────────────────────

func _dibujar_hud() -> void:
	var c: Control = _dibujo
	var font: Font = UI.PIX_FONT
	var vs: Vector2 = c.size

	for a: Aviso in _avisos:
		var k: float = a.edad / 0.7
		c.draw_string(font, a.pos + Vector2(-26.0, -RADIO - 10.0 - 34.0 * k), a.texto,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(a.color, 1.0 - k))

	var restante: float = maxf(duracion - elapsed, 0.0) if running else 0.0
	c.draw_string(font, Vector2(40.0, 56.0), "Puntos: %d" % puntos, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, C.TEXT)
	var t_txt: String = "Tiempo: %.1f" % restante
	var t_w: float = font.get_string_size(t_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	c.draw_string(font, Vector2(vs.x - 40.0 - t_w, 56.0), t_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, C.TEXT)
	var f_txt: String = "Fallos: %d/%d" % [fallos, MAX_FALLOS]
	var f_w: float = font.get_string_size(f_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	c.draw_string(font, Vector2((vs.x - f_w) * 0.5, 56.0), f_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
			COL_ROJO if fallos >= MAX_FALLOS - 2 else C.TEXT_MUTED)

	# Combo (late al sumar).
	if combo >= 2 and running:
		var tam: int = 30 + int(round(10.0 * _combo_pop))
		var cb: String = "Combo x%d" % combo
		var cw: float = font.get_string_size(cb, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		c.draw_string(font, Vector2((vs.x - cw) * 0.5, 104.0), cb, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, C.ACCENT)

	if _intro:
		var y: float = vs.y * 0.5 - 40.0
		for linea: String in INSTRUCCION:
			var w: float = font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
			c.draw_string(font, Vector2((vs.x - w) * 0.5, y), linea, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, C.TITLE)
			y += 56.0
	elif _result != "":
		var msg: String = "Se acabó..." if _result == "win" else "..."
		var mw: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		c.draw_string(font, Vector2((vs.x - mw) * 0.5, vs.y * 0.5), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, C.TEXT)
