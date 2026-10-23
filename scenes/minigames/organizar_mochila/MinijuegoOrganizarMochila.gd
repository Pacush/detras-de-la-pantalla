extends CanvasLayer
## Minijuego 1 — "Organizar la Mochila"
## Connect-the-dots estilo Flow Free.
##
## Señales:
##   completado  → el jugador terminó todos los niveles con éxito.
##   fallido     → (reservado para uso futuro / retry externo)
##
## Estética: paleta de los menús (noche profunda, lavandas y azules pastel), tipografía pixel,
## panel con borde, colores de cables apagados y animaciones al conectar / completar / fallar.

signal completado
signal fallido

# ─────────────────────────────────────────────
# Configuración interna
# ─────────────────────────────────────────────

enum State { PLAYING, TRANSITION }

const MIN_SEGMENT  := 3
const MARGIN       := 20.0
const SHOW_TIMER   := true
const TOP_SPACE    := 150.0     # espacio para título y cabecera
const MAX_CELL     := 96.0
const PANEL_PAD    := 22.0
const RIPPLE_TIME  := 0.5
const MSG_TIME     := 0.9

var levels: Array = [
	{"n": 5, "k": 4, "time": 20},
	{"n": 6, "k": 5, "time": 20},
	{"n": 7, "k": 6, "time": 30},
	#{"n": 8, "k": 7, "time": 30},
	#{"n": 9, "k": 8, "time": 60},
]

# Colores de los cables: pasteles apagados que casan con la interfaz y se distinguen entre sí.
var palette: Array = [
	Color(0.42, 0.58, 0.98),   # azul pervinca
	Color(0.45, 0.85, 0.70),   # menta
	Color(0.95, 0.85, 0.50),   # amarillo suave
	Color(0.95, 0.55, 0.50),   # coral
	Color(0.95, 0.60, 0.82),   # rosa
	Color(0.72, 0.62, 0.95),   # lavanda
	Color(0.45, 0.85, 0.95),   # celeste
	Color(0.97, 0.70, 0.42),   # durazno
]

var grid_w: int = 5
var grid_h: int = 5
var cell_size: float = 80.0
var grid_origin: Vector2 = Vector2.ZERO

var colors: Array         = []
var endpoints: Dictionary = {}
var dot_at: Dictionary    = {}
var paths: Dictionary     = {}
var occupied: Dictionary  = {}

var is_dragging: bool   = false
var current_id: int     = -1
var state: State        = State.PLAYING
var level_index: int    = 0

var time_left: float    = 0.0
var timer_running: bool = false
var last_shown_second: int = -1

# Animaciones
var anim_t: float = 0.0
var ripples: Array = []            # {pos, col, age, big}
var msg: String = ""
var msg_age: float = 0.0
var msg_bad: bool = false

var _draw_node: _MinijuegoDrawNode


func _ready() -> void:
	layer = 128
	_draw_node = _MinijuegoDrawNode.new()
	_draw_node.owner_mg = self
	add_child(_draw_node)
	randomize()
	get_viewport().size_changed.connect(_on_viewport_resized)
	load_level(0)


func _on_viewport_resized() -> void:
	update_layout()


func _process(delta: float) -> void:
	anim_t += delta
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i]["age"] += delta
		if ripples[i]["age"] > RIPPLE_TIME:
			ripples.remove_at(i)
	if msg != "":
		msg_age += delta
		if msg_age > MSG_TIME:
			msg = ""
	_draw_node.queue_redraw()   # pulsos y ondas continuos

	if state != State.PLAYING or not timer_running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		time_out()
	last_shown_second = ceili(time_left)


func add_ripple(pos: Vector2, col: Color, big: bool = false) -> void:
	ripples.append({"pos": pos, "col": col, "age": 0.0, "big": big})


func show_msg(text: String, bad: bool) -> void:
	msg = text
	msg_age = 0.0
	msg_bad = bad


# ─────────────────────────────────────────────
# Flujo del juego
# ─────────────────────────────────────────────

func load_level(index: int) -> void:
	level_index = index
	var cfg: Dictionary = levels[index]
	grid_w = cfg["n"]
	grid_h = cfg["n"]
	generate_puzzle(cfg["k"])
	reset_board()
	state = State.PLAYING
	update_layout()


func reset_board() -> void:
	paths.clear()
	occupied.clear()
	for id in endpoints.keys():
		paths[id] = []
	is_dragging       = false
	current_id        = -1
	time_left         = float(levels[level_index]["time"])
	timer_running     = false
	last_shown_second = -1
	_draw_node.queue_redraw()


func time_out() -> void:
	timer_running = false
	is_dragging   = false
	current_id    = -1
	state         = State.TRANSITION
	show_msg("Se acabó el tiempo", true)
	await get_tree().create_timer(0.8).timeout
	reset_board()
	state = State.PLAYING


func check_win() -> void:
	for id in endpoints.keys():
		if not is_complete(id):
			return
	if occupied.size() != grid_w * grid_h:
		return

	timer_running = false
	state         = State.TRANSITION
	show_msg("¡Conectado!", false)
	for id in endpoints.keys():
		for cell in endpoints[id]:
			add_ripple(cell_center(cell), colors[id], true)
	await get_tree().create_timer(0.6).timeout

	if level_index + 1 < levels.size():
		load_level(level_index + 1)
	else:
		emit_signal("completado")
		queue_free()


# ─────────────────────────────────────────────
# Generación de niveles
# ─────────────────────────────────────────────

func generate_puzzle(k: int) -> void:
	endpoints.clear()
	dot_at.clear()
	colors = palette.duplicate()
	colors.shuffle()

	var path: Array = generate_hamiltonian_path(grid_w, grid_h)
	var n: int = path.size()

	var lengths: Array = []
	for i in range(k):
		lengths.append(MIN_SEGMENT)
	for i in range(n - k * MIN_SEGMENT):
		lengths[randi() % k] += 1

	var cursor := 0
	for id in range(k):
		var first: Vector2i = path[cursor]
		var last: Vector2i  = path[cursor + lengths[id] - 1]
		endpoints[id] = [first, last]
		dot_at[first] = id
		dot_at[last]  = id
		cursor += lengths[id]


func generate_hamiltonian_path(w: int, h: int) -> Array:
	var path: Array = []
	for y in range(h):
		if y % 2 == 0:
			for x in range(w):
				path.append(Vector2i(x, y))
		else:
			for x in range(w - 1, -1, -1):
				path.append(Vector2i(x, y))

	var dirs: Array = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for i in range(w * h * 40):
		if randf() < 0.5:
			path.reverse()
		var q: Vector2i = path[0] + dirs[randi() % 4]
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
			continue
		var j: int = path.find(q)
		if j <= 1:
			continue
		var prefix: Array = path.slice(0, j)
		prefix.reverse()
		path = prefix + path.slice(j)
	return path


# ─────────────────────────────────────────────
# Layout
# ─────────────────────────────────────────────

func update_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var top := TOP_SPACE if SHOW_TIMER else 0.0
	cell_size = clampf(
		floorf(minf((vp.x - MARGIN * 2) / grid_w, (vp.y - MARGIN * 2 - top) / grid_h)),
		24.0, MAX_CELL
	)
	grid_origin = Vector2(
		floorf((vp.x - grid_w * cell_size) / 2.0),
		floorf(top + (vp.y - top - grid_h * cell_size) / 2.0)
	)
	_draw_node.queue_redraw()


# ─────────────────────────────────────────────
# Stroke logic (llamado desde _MinijuegoDrawNode)
# ─────────────────────────────────────────────

func world_to_grid(screen_pos: Vector2) -> Vector2i:
	var p := (screen_pos - grid_origin) / cell_size
	return Vector2i(floori(p.x), floori(p.y))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_w and cell.y < grid_h


func cell_center(cell: Vector2i) -> Vector2:
	return grid_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func handle_press(screen_pos: Vector2) -> void:
	if state != State.PLAYING:
		return
	begin_stroke(world_to_grid(screen_pos))


func handle_release() -> void:
	if state != State.PLAYING:
		return
	end_stroke()


func handle_drag(screen_pos: Vector2) -> void:
	if state != State.PLAYING or not is_dragging:
		return
	drag_to(world_to_grid(screen_pos))


func handle_key_r() -> void:
	if state != State.PLAYING:
		return
	reset_board()


func begin_stroke(cell: Vector2i) -> void:
	if not in_bounds(cell):
		return
	var id := -1
	if dot_at.has(cell):
		id = dot_at[cell]
		truncate_path(id, 0)
		paths[id].append(cell)
		occupied[cell] = id
	elif occupied.has(cell):
		id = occupied[cell]
		var idx: int = paths[id].find(cell)
		truncate_path(id, idx + 1)
	else:
		return
	is_dragging   = true
	current_id    = id
	timer_running = true
	add_ripple(cell_center(cell), colors[id])   # feedback al tomar el cable
	_draw_node.queue_redraw()


func end_stroke() -> void:
	is_dragging = false
	current_id  = -1
	_draw_node.queue_redraw()


func drag_to(target: Vector2i) -> void:
	if not in_bounds(target):
		return
	var guard := 0
	while is_dragging and guard < 40:
		guard += 1
		var last: Vector2i = paths[current_id].back()
		if target == last:
			break
		var d    := target - last
		var step := Vector2i.ZERO
		if absi(d.x) >= absi(d.y):
			step.x = clampi(d.x, -1, 1)
		else:
			step.y = clampi(d.y, -1, 1)
		if not try_step(last + step):
			break
	_draw_node.queue_redraw()


func try_step(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var path: Array = paths[current_id]

	if occupied.get(cell, -1) == current_id:
		truncate_path(current_id, path.find(cell) + 1)
		return true

	if dot_at.has(cell) and dot_at[cell] != current_id:
		return false

	if occupied.has(cell):
		var other: int = occupied[cell]
		truncate_path(other, paths[other].find(cell))

	path.append(cell)
	occupied[cell] = current_id

	if dot_at.get(cell, -1) == current_id:
		# Cable conectado: onda en ambos extremos.
		for e in endpoints[current_id]:
			add_ripple(cell_center(e), colors[current_id], true)
		is_dragging = false
		current_id  = -1
		check_win()

	return true


func truncate_path(id: int, keep: int) -> void:
	var p: Array = paths[id]
	for i in range(keep, p.size()):
		occupied.erase(p[i])
	p.resize(keep)


func is_complete(id: int) -> bool:
	var p: Array = paths[id]
	if p.size() < 2:
		return false
	return p.back() != p[0] and dot_at.get(p.back(), -1) == id


# ─────────────────────────────────────────────
# Nodo de dibujo + input
# ─────────────────────────────────────────────

## Hijo Control que vive dentro del CanvasLayer.
##
## IMPORTANTE: debe ser un Control (no un Node2D) porque Dialogic usa su
## propio Control de pantalla completa (FullAdvanceInputLayer/DialogicNode_Input)
## que cambia dinámicamente su mouse_filter a STOP mientras detecta el click
## de avance de texto — y eso intercepta el evento en la fase de GUI input,
## ANTES de que _unhandled_input llegue a cualquier Node2D, sin importar el
## CanvasLayer o el z-order. Un Node2D nunca participa en esa fase de GUI,
## así que jamás podría ganarle. Un Control sí compite en esa misma fase,
## y al estar en un CanvasLayer con layer más alto, gana el hit-test.
class _MinijuegoDrawNode extends Control:
	const UI = preload("res://scripts/ui/ui_style.gd")
	const C = preload("res://scripts/ui/ui_colors.gd")
	const ROJO: Color = Color(0.90, 0.45, 0.52)

	var owner_mg: CanvasLayer
	var _panel: StyleBoxFlat = null

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		_panel = StyleBoxFlat.new()
		_panel.bg_color = C.PANEL_BG
		_panel.border_color = C.PANEL_BORDER
		_panel.set_border_width_all(3)
		_panel.set_corner_radius_all(10)
		_panel.shadow_color = C.PANEL_SHADOW
		_panel.shadow_size = 22

	func _gui_input(event: InputEvent) -> void:
		if owner_mg == null:
			return

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if event.pressed:
				owner_mg.handle_press(event.position)
			else:
				owner_mg.handle_release()

		elif event is InputEventMouseMotion and owner_mg.is_dragging:
			accept_event()
			owner_mg.handle_drag(event.position)

	func _unhandled_key_input(event: InputEvent) -> void:
		if owner_mg == null:
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			owner_mg.handle_key_r()

	## Cable con brillo suave, cuerpo y núcleo claro (extremos redondeados).
	func _cable(pts: PackedVector2Array, col: Color, w: float, glow_a: float) -> void:
		var capas: Array = [
			[w * 1.9, Color(col, glow_a)],
			[w * 1.35, Color(col, glow_a * 1.4)],
			[w, Color(col.darkened(0.12), 0.96)],
			[w * 0.34, Color(col.lightened(0.45), 0.85)],
		]
		for capa: Array in capas:
			var ancho: float = capa[0]
			var c: Color = capa[1]
			if pts.size() >= 2:
				draw_polyline(pts, c, ancho, true)
			for pt: Vector2 in pts:
				draw_circle(pt, ancho * 0.5, c)

	func _draw() -> void:
		var mg := owner_mg
		if mg == null or mg.colors.is_empty():
			return

		var vp := mg.get_viewport().get_visible_rect().size
		var font: Font = UI.PIX_FONT
		var t: float = mg.anim_t
		var cs: float = mg.cell_size
		var org: Vector2 = mg.grid_origin
		var gsize: Vector2 = Vector2(mg.grid_w, mg.grid_h) * cs
		var panel_rect: Rect2 = Rect2(org, gsize).grow(mg.PANEL_PAD)

		# ── Fondo: noche profunda con degradado ──
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0.0), vp, Vector2(0.0, vp.y)]),
			PackedColorArray([
				Color(C.BG_TOP, 0.96), Color(C.BG_TOP, 0.96),
				Color(C.BG_BOTTOM, 0.97), Color(C.BG_BOTTOM, 0.97)
			])
		)

		# ── Título ──
		draw_string(font, Vector2(2.0, 82.0), "Organiza tu mochila", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0.0, 80.0), "Organiza tu mochila", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, C.TITLE)

		# ── Cabecera: tiempo (izq.), nivel (der.) y barra de tiempo ──
		var base_y: float = panel_rect.position.y - 26.0
		if mg.SHOW_TIMER:
			var secs := ceili(mg.time_left)
			var urgente: bool = secs <= 10 and mg.timer_running
			var txt := "%d:%02d" % [floori(secs / 60.0), secs % 60]
			var col: Color = C.TEXT
			if urgente:
				col = C.TEXT.lerp(ROJO, 0.55 + 0.45 * sin(t * 9.0))
			draw_string(font, Vector2(panel_rect.position.x, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, col)

			var total: float = float(mg.levels[mg.level_index]["time"])
			var frac: float = clampf(mg.time_left / total, 0.0, 1.0)
			var barra: Rect2 = Rect2(panel_rect.position.x, panel_rect.position.y - 16.0, panel_rect.size.x, 7.0)
			draw_rect(barra, C.SLIDER_TRACK)
			draw_rect(Rect2(barra.position, Vector2(barra.size.x * frac, barra.size.y)), C.SLIDER_FILL_HI.lerp(ROJO, 1.0 - clampf(frac * 3.0, 0.0, 1.0)))
			draw_rect(barra, C.PANEL_BORDER, false, 1.0)

		var nivel_txt: String = "Nivel %d/%d" % [mg.level_index + 1, mg.levels.size()]
		var nivel_w: float = font.get_string_size(nivel_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(font, Vector2(panel_rect.end.x - nivel_w, base_y), nivel_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, C.ACCENT)

		# ── Panel ──
		draw_style_box(_panel, panel_rect)

		# ── Casillas ──
		for y in range(mg.grid_h):
			for x in range(mg.grid_w):
				var cell: Vector2i = Vector2i(x, y)
				var r: Rect2 = Rect2(org + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-2.0)
				draw_rect(r, C.SLIDER_TRACK)
				if mg.occupied.has(cell):
					var oc: Color = mg.colors[mg.occupied[cell]]
					draw_rect(r, Color(oc, 0.15))
				draw_rect(r, Color(C.PANEL_BORDER, 0.45), false, 1.0)

		# ── Cables ──
		var line_w: float = cs * 0.34
		for id in mg.paths.keys():
			var p: Array = mg.paths[id]
			if p.size() == 0:
				continue
			var pts := PackedVector2Array()
			for cell in p:
				pts.append(mg.cell_center(cell))
			var activo: bool = id == mg.current_id
			var completo: bool = mg.is_complete(id)
			var glow: float = 0.08
			if activo:
				glow = 0.20 + 0.06 * sin(t * 10.0)
			elif completo:
				glow = 0.12 + 0.05 * sin(t * 2.5 + float(id))
			_cable(pts, mg.colors[id], line_w, glow)

		# ── Puntos fijos ──
		for id in mg.endpoints.keys():
			var col: Color = mg.colors[id]
			var completo2: bool = mg.is_complete(id)
			var activo2: bool = id == mg.current_id
			for cell in mg.endpoints[id]:
				var c: Vector2 = mg.cell_center(cell)
				var rad: float = cs * 0.33
				var pulso: float = 0.5 + 0.5 * sin(t * 3.0 + float(id) * 1.7)
				if not completo2:
					# Late suave invitando a conectar (más fuerte si es el cable en uso).
					var extra: float = (6.0 if activo2 else 3.0) * pulso
					draw_arc(c, rad * 1.28 + extra, 0.0, TAU, 32, Color(col, 0.30 + 0.30 * pulso), 3.0, true)
				else:
					draw_arc(c, rad * 1.3, 0.0, TAU, 32, Color(col, 0.55), 3.0, true)
				draw_circle(c + Vector2(2.0, 3.0), rad, Color(0, 0, 0, 0.45))      # sombra
				draw_circle(c, rad, col.darkened(0.15))
				draw_circle(c, rad * 0.82, col)
				draw_circle(c + Vector2(-rad * 0.28, -rad * 0.3), rad * 0.24, Color(1, 1, 1, 0.4))   # brillo

		# ── Ondas (tomar cable / conectar) ──
		for rp: Dictionary in mg.ripples:
			var k: float = clampf(float(rp["age"]) / mg.RIPPLE_TIME, 0.0, 1.0)
			var rc: Color = rp["col"]
			var big: bool = rp["big"]
			var radio: float = cs * (0.30 + (0.85 if big else 0.55) * k)
			draw_arc(rp["pos"], radio, 0.0, TAU, 36, Color(rc.lightened(0.3), (1.0 - k) * 0.9), 3.0 * (1.0 - k) + 1.0, true)

		# ── Instrucción ──
		var ins: String = "Conecta los puntos del mismo color y llena toda la cuadrícula.   [R] reiniciar nivel"
		draw_string(font, Vector2(0.0, panel_rect.end.y + 38.0), ins, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, C.TEXT_MUTED)

		# ── Mensaje central (conectado / tiempo agotado) ──
		if mg.msg != "":
			var a: float = 1.0 - smoothstep(0.6, 1.0, mg.msg_age / mg.MSG_TIME)
			var tint: Color = ROJO if mg.msg_bad else C.ACCENT
			draw_rect(panel_rect, Color(tint, 0.14 * a))
			var my: float = panel_rect.get_center().y + 16.0
			var placa: Rect2 = Rect2(Vector2(0.0, my - 54.0), Vector2(vp.x, 76.0))
			draw_rect(placa, Color(C.BG_DEEP, 0.82 * a))
			draw_string(font, Vector2(2.0, my + 2.0), mg.msg, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 48, Color(0, 0, 0, 0.6 * a))
			draw_string(font, Vector2(0.0, my), mg.msg, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 48, Color(tint.lightened(0.25), a))
