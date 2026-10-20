extends Node2D
# Connect Dots (estilo Flow Free) - Godot 4.x
# Pega este script en un Node2D vacío.
# R = reiniciar el nivel actual.

enum State { PLAYING, TRANSITION }

const MIN_SEGMENT := 3
const MARGIN := 20.0
const SHOW_TIMER := true        # pon false para ocultar el contador (el límite sigue activo)
const TOP_SPACE := 40.0         # espacio arriba para el contador

# Dificultad progresiva: tamaño del tablero (n x n) y cantidad de colores
var levels: Array = [
	{"n": 5, "k": 4, "time": 20},
	{"n": 6, "k": 5, "time": 20},
	{"n": 7, "k": 6, "time": 20},
	{"n": 8, "k": 7, "time": 20},
	{"n": 9, "k": 8, "time": 20},
]

var palette: Array = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW,
	Color.ORANGE, Color.CYAN, Color.PURPLE, Color.MAGENTA,
]

var grid_w: int = 5
var grid_h: int = 5
var cell_size: float = 80.0
var grid_origin: Vector2 = Vector2.ZERO

var colors: Array = []          # id -> Color
var endpoints: Dictionary = {}  # id -> [Vector2i, Vector2i]
var dot_at: Dictionary = {}     # Vector2i -> id
var paths: Dictionary = {}      # id -> Array[Vector2i]
var occupied: Dictionary = {}   # Vector2i -> id

var is_dragging: bool = false
var current_id: int = -1
var state: State = State.PLAYING
var level_index: int = 0

var time_left: float = 0.0
var timer_running: bool = false
var last_shown_second: int = -1


func _ready() -> void:
	randomize()
	get_viewport().size_changed.connect(update_layout)
	load_level(0)


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
		queue_redraw()


# =====================================================================
#  Flujo del juego
# =====================================================================
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
	is_dragging = false
	current_id = -1
	time_left = float(levels[level_index]["time"])
	timer_running = false
	last_shown_second = -1
	queue_redraw()


func time_out() -> void:
	timer_running = false
	is_dragging = false
	current_id = -1
	state = State.TRANSITION
	print("¡Tiempo agotado! Intenta de nuevo...")
	await get_tree().create_timer(0.8).timeout
	reset_board()
	state = State.PLAYING


func check_win() -> void:
	for id in endpoints.keys():
		if not is_complete(id):
			return
	# Hay que llenar todo el tablero
	if occupied.size() != grid_w * grid_h:
		return

	timer_running = false
	state = State.TRANSITION
	await get_tree().create_timer(0.6).timeout
	if level_index + 1 < levels.size():
		print("¡Nivel completado! Cargando siguiente...")
		load_level(level_index + 1)
	else:
		print("¡Has completado todos los niveles! ¡Juego terminado!")
		load_level(0)


# =====================================================================
#  Generación de niveles (siempre tienen solución y llenan el tablero)
# =====================================================================
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
		var last: Vector2i = path[cursor + lengths[id] - 1]
		endpoints[id] = [first, last]
		dot_at[first] = id
		dot_at[last] = id
		cursor += lengths[id]


# Camino que recorre todo el tablero: serpiente + algoritmo "backbite"
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


# =====================================================================
#  Layout y dibujo (estilo original)
# =====================================================================
func update_layout() -> void:
	var vp := get_viewport_rect().size
	var top := TOP_SPACE if SHOW_TIMER else 0.0
	cell_size = clampf(floorf(minf((vp.x - MARGIN * 2) / grid_w, (vp.y - MARGIN * 2 - top) / grid_h)), 24.0, 80.0)
	grid_origin = Vector2(
		(vp.x - grid_w * cell_size) / 2.0,
		top + (vp.y - top - grid_h * cell_size) / 2.0
	)
	queue_redraw()


func _draw() -> void:
	if colors.is_empty():
		return

	# Contador de tiempo
	if SHOW_TIMER:
		var secs := ceili(time_left)
		var txt := "%d:%02d" % [floori(secs / 60.0), secs % 60]
		var col := Color.WHITE if secs > 10 else Color.RED
		draw_string(ThemeDB.fallback_font, Vector2(grid_origin.x, grid_origin.y - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)

	# Cuadrícula
	for x in range(grid_w + 1):
		var px := grid_origin.x + x * cell_size
		draw_line(Vector2(px, grid_origin.y), Vector2(px, grid_origin.y + grid_h * cell_size), Color.DARK_GRAY, 2)
	for y in range(grid_h + 1):
		var py := grid_origin.y + y * cell_size
		draw_line(Vector2(grid_origin.x, py), Vector2(grid_origin.x + grid_w * cell_size, py), Color.DARK_GRAY, 2)

	# Caminos
	var line_w := cell_size * 0.4
	for id in paths.keys():
		var p: Array = paths[id]
		if p.size() == 0:
			continue
		var col: Color = colors[id]
		var pts := PackedVector2Array()
		for cell in p:
			pts.append(cell_center(cell))
		if pts.size() >= 2:
			draw_polyline(pts, col, line_w, true)
		for pt in pts:
			draw_circle(pt, line_w * 0.5, col)

	# Puntos (encima de las líneas)
	for id in endpoints.keys():
		for cell in endpoints[id]:
			draw_circle(cell_center(cell), cell_size * 0.35, colors[id])


func cell_center(cell: Vector2i) -> Vector2:
	return grid_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func world_to_grid(pos: Vector2) -> Vector2i:
	var p := (pos - grid_origin) / cell_size
	return Vector2i(floori(p.x), floori(p.y))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_w and cell.y < grid_h


# =====================================================================
#  Entrada
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		reset_board()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_stroke(world_to_grid(get_local_mouse_position()))
		else:
			end_stroke()
	elif event is InputEventMouseMotion and is_dragging:
		drag_to(world_to_grid(get_local_mouse_position()))


func begin_stroke(cell: Vector2i) -> void:
	if not in_bounds(cell):
		return

	var id := -1
	if dot_at.has(cell):
		# Empezar desde un punto: se reinicia el camino de ese color
		id = dot_at[cell]
		truncate_path(id, 0)
		paths[id].append(cell)
		occupied[cell] = id
	elif occupied.has(cell):
		# Retomar una línea existente desde esa casilla
		id = occupied[cell]
		var idx: int = paths[id].find(cell)
		truncate_path(id, idx + 1)
	else:
		return

	is_dragging = true
	current_id = id
	timer_running = true
	queue_redraw()


func end_stroke() -> void:
	is_dragging = false
	current_id = -1
	queue_redraw()


# Avanza casilla por casilla hacia el cursor (evita saltos con el mouse rápido)
func drag_to(target: Vector2i) -> void:
	if not in_bounds(target):
		return
	var guard := 0
	while is_dragging and guard < 40:
		guard += 1
		var last: Vector2i = paths[current_id].back()
		if target == last:
			break
		var d := target - last
		var step := Vector2i.ZERO
		if absi(d.x) >= absi(d.y):
			step.x = clampi(d.x, -1, 1)
		else:
			step.y = clampi(d.y, -1, 1)
		if not try_step(last + step):
			break
	queue_redraw()


func try_step(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var path: Array = paths[current_id]

	# Volver sobre el propio camino: se recorta
	if occupied.get(cell, -1) == current_id:
		truncate_path(current_id, path.find(cell) + 1)
		return true

	# Los puntos de otros colores son infranqueables
	if dot_at.has(cell) and dot_at[cell] != current_id:
		return false

	# Cortar la línea de otro color
	if occupied.has(cell):
		var other: int = occupied[cell]
		truncate_path(other, paths[other].find(cell))

	path.append(cell)
	occupied[cell] = current_id

	# Llegó al punto final de su color: el trazo termina solo
	if dot_at.get(cell, -1) == current_id:
		is_dragging = false
		current_id = -1
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
