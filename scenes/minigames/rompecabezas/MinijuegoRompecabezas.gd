extends CanvasLayer
## Minijuego 1 de Romina — Rompecabezas de la foto de perfil.
##
## Toda la interacción pasa por un Control raíz (gui_input), igual que el minijuego de la
## mochila: el input de Dialogic (DialogicNode_Input) se come los eventos de mouse en la fase
## GUI, así que Area2D / _unhandled_input no funcionarían aquí.
## Emite `completado` al terminar y se destruye solo.

signal completado

const IMAGENES: Array[String] = [
	"res://assets/minigames/rompecabezas/foto_perfil_1.png"
]
const COLUMNAS: int = 4
const FILAS: int = 3
const MARGEN_ENCAJE: float = 0.28   # fracción del tamaño de pieza

var _raiz: Control
var _tablero: ColorRect
var _referencia: TextureRect
var _lbl_info: Label
var _lbl_msg: Label
var _piezas: Array[Control] = []
var _destinos: Dictionary = {}      # Control -> Vector2 (esquina superior izquierda final)
var _fijadas: Dictionary = {}       # Control -> true
var _arrastrada: Control = null
var _offset: Vector2 = Vector2.ZERO
var _tam_pieza: Vector2 = Vector2.ZERO
var _colocadas: int = 0
var _tiempo: float = 0.0
var _jugando: bool = false


func _ready() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.gui_input.connect(_on_gui_input)
	add_child(_raiz)

	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0.04, 0.04, 0.07, 0.96)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)

	var titulo: Label = Label.new()
	titulo.text = "Arma tu foto de perfil"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.78, 0.84))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(0, 18)
	titulo.size = Vector2(vp.x, 40)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(titulo)

	_lbl_info = Label.new()
	_lbl_info.position = Vector2(20, 20)
	_lbl_info.add_theme_font_size_override("font_size", 18)
	_lbl_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_lbl_info)

	_lbl_msg = Label.new()
	_lbl_msg.position = Vector2(0, vp.y - 70)
	_lbl_msg.size = Vector2(vp.x, 40)
	_lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_msg.add_theme_font_size_override("font_size", 28)
	_lbl_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_lbl_msg)

	_construir_rompecabezas(vp)
	_jugando = true
	_actualizar_info()


func _process(delta: float) -> void:
	if _jugando:
		_tiempo += delta
		_actualizar_info()


func _elegir_textura() -> Texture2D:
	var candidatas: Array[Texture2D] = []
	for ruta: String in IMAGENES:
		if ResourceLoader.exists(ruta):
			var tex: Texture2D = load(ruta) as Texture2D
			if tex != null:
				candidatas.append(tex)
	if candidatas.is_empty():
		# Fallback: sprite de Romina, para que el minijuego nunca quede vacío.
		return load("res://assets/characters/Romina/Romina Glad.png") as Texture2D
	return candidatas[randi() % candidatas.size()]


func _construir_rompecabezas(vp: Vector2) -> void:
	var textura: Texture2D = _elegir_textura()
	var tam_img: Vector2 = textura.get_size()
	var area_max: Vector2 = vp * Vector2(0.55, 0.62)
	var escala: float = minf(area_max.x / tam_img.x, area_max.y / tam_img.y)
	var tam_tablero: Vector2 = tam_img * escala
	var origen: Vector2 = Vector2((vp.x - tam_tablero.x) / 2.0, (vp.y - tam_tablero.y) / 2.0 + 10.0)
	_tam_pieza = tam_tablero / Vector2(COLUMNAS, FILAS)
	var region_pieza: Vector2 = tam_img / Vector2(COLUMNAS, FILAS)

	_tablero = ColorRect.new()
	_tablero.color = Color(1, 1, 1, 0.07)
	_tablero.position = origen
	_tablero.size = tam_tablero
	_tablero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_tablero)

	_referencia = TextureRect.new()
	_referencia.texture = textura
	_referencia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_referencia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_referencia.size = Vector2(190, 140)
	_referencia.position = Vector2(vp.x - 210, 20)
	_referencia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_referencia)

	var rect_ref: Rect2 = Rect2(_referencia.position, _referencia.size)
	var rect_tab: Rect2 = Rect2(origen, tam_tablero)

	for cx: int in COLUMNAS:
		for cy: int in FILAS:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(Vector2(cx, cy) * region_pieza, region_pieza)

			var pieza: TextureRect = TextureRect.new()
			pieza.texture = atlas
			pieza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pieza.stretch_mode = TextureRect.STRETCH_SCALE
			pieza.size = _tam_pieza
			pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var borde: Panel = Panel.new()
			var estilo: StyleBoxFlat = StyleBoxFlat.new()
			estilo.bg_color = Color(0, 0, 0, 0)
			estilo.set_border_width_all(1)
			estilo.border_color = Color(0, 0, 0, 0.55)
			borde.add_theme_stylebox_override("panel", estilo)
			borde.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pieza.add_child(borde)

			_raiz.add_child(pieza)
			_destinos[pieza] = origen + Vector2(cx, cy) * _tam_pieza
			pieza.position = _posicion_aleatoria(vp, rect_tab, rect_ref)
			_piezas.append(pieza)


func _posicion_aleatoria(vp: Vector2, rect_tab: Rect2, rect_ref: Rect2) -> Vector2:
	var pos: Vector2 = Vector2.ZERO
	for _i: int in 60:
		pos = Vector2(
			randf_range(8.0, vp.x - _tam_pieza.x - 8.0),
			randf_range(70.0, vp.y - _tam_pieza.y - 8.0)
		)
		var rp: Rect2 = Rect2(pos, _tam_pieza)
		if not rect_tab.intersects(rp) and not rect_ref.intersects(rp):
			return pos
	return pos


func _on_gui_input(event: InputEvent) -> void:
	if not _jugando:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_agarrar(mb.position)
		else:
			_soltar()
		_raiz.accept_event()

	elif event is InputEventMouseMotion and _arrastrada != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_arrastrada.position = mm.position + _offset
		_raiz.accept_event()


func _agarrar(punto: Vector2) -> void:
	# La última pieza hija está al frente, así que se busca de atrás hacia delante.
	for i: int in range(_piezas.size() - 1, -1, -1):
		var p: Control = _piezas[i]
		if _fijadas.has(p):
			continue
		if Rect2(p.position, p.size).has_point(punto):
			_arrastrada = p
			_offset = p.position - punto
			_raiz.move_child(p, _raiz.get_child_count() - 1)
			_piezas.erase(p)
			_piezas.append(p)
			return


func _soltar() -> void:
	if _arrastrada == null:
		return
	var p: Control = _arrastrada
	_arrastrada = null
	var destino: Vector2 = _destinos[p]
	if p.position.distance_to(destino) <= _tam_pieza.length() * MARGEN_ENCAJE:
		p.position = destino
		_fijadas[p] = true
		_raiz.move_child(p, _tablero.get_index() + 1)   # las colocadas quedan al fondo
		_colocadas += 1
		_actualizar_info()
		if _colocadas >= _piezas.size():
			_terminar()


func _terminar() -> void:
	_jugando = false
	_lbl_msg.text = "¡Foto lista!"
	await get_tree().create_timer(1.6).timeout
	var tween: Tween = create_tween()
	tween.tween_property(_raiz, "modulate:a", 0.0, 0.5)
	await tween.finished
	completado.emit()
	queue_free()


func _actualizar_info() -> void:
	_lbl_info.text = "Piezas: %d/%d\nTiempo: %02d:%02d" % [
		_colocadas, COLUMNAS * FILAS, int(_tiempo / 60.0), int(_tiempo) % 60
	]
