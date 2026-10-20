extends CanvasLayer
## Minijuego 1 — "Organizar la Mochila"
## Connect-the-dots estilo Flow Free.
##
## Señales:
##   completado  → el jugador terminó todos los niveles con éxito.
##   fallido     → (reservado para uso futuro / retry externo)

signal completado
signal fallido

# ─────────────────────────────────────────────
# Configuración interna
# ─────────────────────────────────────────────

enum State { PLAYING, TRANSITION }

const MIN_SEGMENT  := 3
const MARGIN       := 20.0
const SHOW_TIMER   := true
const TOP_SPACE    := 60.0

var levels: Array = [
	{"n": 5, "k": 4, "time": 20},
	{"n": 6, "k": 5, "time": 20},
	{"n": 7, "k": 6, "time": 30},
	{"n": 8, "k": 7, "time": 30},
	{"n": 9, "k": 8, "time": 60},
]

var palette: Array = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW,
	Color.ORANGE, Color.CYAN, Color.PURPLE, Color.MAGENTA,
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
	if state != State.PLAYING or not timer_running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		time_out()
	var shown := ceili(time_left)
	if shown != last_shown_second:
		last_shown_second = shown
		_draw_node.queue_redraw()


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
		24.0, 80.0
	)
	grid_origin = Vector2(
		(vp.x - grid_w * cell_size) / 2.0,
		top + (vp.y - top - grid_h * cell_size) / 2.0
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
	var owner_mg: CanvasLayer

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL

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

	func _draw() -> void:
		var mg := owner_mg
		if mg == null or mg.colors.is_empty():
			return

		var vp := mg.get_viewport().get_visible_rect().size

		# Fondo oscuro
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.1, 0.95))

		# Título
		draw_string(
			ThemeDB.fallback_font,
			Vector2(vp.x / 2.0 - 120, 28),
			"Organiza tu mochila",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE
		)

		# Instrucción
		draw_string(
			ThemeDB.fallback_font,
			Vector2(mg.grid_origin.x, mg.grid_origin.y - 34),
			"Conecta todos los puntos del mismo color y llena la cuadrícula.  [R] = reiniciar nivel",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.75, 0.75)
		)

		# Contador de tiempo
		if mg.SHOW_TIMER:
			var secs := ceili(mg.time_left)
			var txt := "%d:%02d" % [floori(secs / 60.0), secs % 60]
			var col := Color.WHITE if secs > 10 else Color.RED
			draw_string(
				ThemeDB.fallback_font,
				Vector2(mg.grid_origin.x, mg.grid_origin.y - 12),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col
			)

		# Número de nivel
		draw_string(
			ThemeDB.fallback_font,
			Vector2(vp.x - mg.grid_origin.x - 60, mg.grid_origin.y - 12),
			"Nivel %d/%d" % [mg.level_index + 1, mg.levels.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.LIGHT_GRAY
		)

		# Cuadrícula
		for x in range(mg.grid_w + 1):
			var px :float = mg.grid_origin.x + x * mg.cell_size
			draw_line(
				Vector2(px, mg.grid_origin.y),
				Vector2(px, mg.grid_origin.y + mg.grid_h * mg.cell_size),
				Color.DARK_GRAY, 2
			)
		for y in range(mg.grid_h + 1):
			var py :float = mg.grid_origin.y + y * mg.cell_size
			draw_line(
				Vector2(mg.grid_origin.x, py),
				Vector2(mg.grid_origin.x + mg.grid_w * mg.cell_size, py),
				Color.DARK_GRAY, 2
			)

		# Caminos dibujados
		var line_w :float = mg.cell_size * 0.4
		for id in mg.paths.keys():
			var p: Array = mg.paths[id]
			if p.size() == 0:
				continue
			var col: Color = mg.colors[id]
			var pts := PackedVector2Array()
			for cell in p:
				pts.append(mg.cell_center(cell))
			if pts.size() >= 2:
				draw_polyline(pts, col, line_w, true)
			for pt in pts:
				draw_circle(pt, line_w * 0.5, col)

		# Puntos fijos
		for id in mg.endpoints.keys():
			for cell in mg.endpoints[id]:
				draw_circle(mg.cell_center(cell), mg.cell_size * 0.35, mg.colors[id])
