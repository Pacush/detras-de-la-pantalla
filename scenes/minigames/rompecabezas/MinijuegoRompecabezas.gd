extends CanvasLayer
## Minijuego 1 de Romina — Rompecabezas de la foto de perfil.
##
## Toda la interacción pasa por un Control raíz (gui_input), igual que el minijuego de la
## mochila: el input de Dialogic (DialogicNode_Input) se come los eventos de mouse en la fase
## GUI, así que Area2D / _unhandled_input no funcionarían aquí.
## Emite `completado` al terminar y se destruye solo.
##
## Estética: paleta de los menús (noche profunda, lavandas y azules pastel), tipografía pixel,
## paneles con borde, piezas con sombra que se levantan al agarrarlas y encajan con una pequeña
## animación (destello, rebote y onda).

signal completado

const UI = preload("res://scripts/ui/ui_style.gd")
const C = preload("res://scripts/ui/ui_colors.gd")

const IMAGENES: Array[String] = [
	"res://assets/minigames/rompecabezas/foto_perfil_1.png"
]
const COLUMNAS: int = 4
const FILAS: int = 3
const MARGEN_ENCAJE: float = 0.28   # fracción del tamaño de pieza
const MARCO_PAD: float = 16.0
const SOMBRA_REPOSO: Vector2 = Vector2(4.0, 6.0)
const SOMBRA_ALTA: Vector2 = Vector2(10.0, 14.0)

var _raiz: Control
var _marco: Panel
var _marco_estilo: StyleBoxFlat
var _tablero: Control
var _referencia: TextureRect
var _lbl_titulo: Label
var _lbl_piezas: Label
var _lbl_tiempo: Label
var _lbl_msg: Label
var _lbl_ayuda: Label
var _barra_fill: ColorRect
var _barra_w: float = 0.0
var _piezas: Array[Control] = []
var _destinos: Dictionary = {}      # Control -> Vector2 (esquina superior izquierda final)
var _fijadas: Dictionary = {}       # Control -> true
var _sombras: Dictionary = {}       # Control -> ColorRect
var _bordes: Dictionary = {}        # Control -> StyleBoxFlat
var _slots: Dictionary = {}         # Control -> StyleBoxFlat (casilla de destino)
var _slot_resaltado: StyleBoxFlat = null
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

	_crear_fondo()

	_lbl_titulo = _etiqueta("Arma tu foto de perfil", 44, C.TITLE)
	_lbl_titulo.position = Vector2(0, 18)
	_lbl_titulo.size = Vector2(vp.x, 60)
	_lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_lbl_titulo.add_theme_constant_override("shadow_offset_x", 2)
	_lbl_titulo.add_theme_constant_override("shadow_offset_y", 2)
	_raiz.add_child(_lbl_titulo)

	var rect_hud: Rect2 = _crear_hud()

	_lbl_msg = _etiqueta("", 52, C.ACCENT)
	_lbl_msg.position = Vector2(0, vp.y - 110)
	_lbl_msg.size = Vector2(vp.x, 70)
	_lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_msg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_lbl_msg.add_theme_constant_override("shadow_offset_x", 2)
	_lbl_msg.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_msg.pivot_offset = Vector2(vp.x * 0.5, 35.0)
	_raiz.add_child(_lbl_msg)

	_lbl_ayuda = _etiqueta("Arrastra cada pieza hasta su lugar en el marco", 18, C.TEXT_MUTED)
	_lbl_ayuda.position = Vector2(0, vp.y - 44)
	_lbl_ayuda.size = Vector2(vp.x, 28)
	_lbl_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raiz.add_child(_lbl_ayuda)

	_construir_rompecabezas(vp, rect_hud)
	_jugando = true
	_actualizar_info()


func _process(delta: float) -> void:
	if _jugando:
		_tiempo += delta
		_actualizar_info()


# ──────────────────────────────────────────────
# CONSTRUCCIÓN DE LA INTERFAZ
# ──────────────────────────────────────────────

func _etiqueta(texto: String, tam: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = texto
	l.add_theme_font_override("font", UI.PIX_FONT)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_panel(fondo: Color, borde: Color, ancho: int = 3, radio: int = 8, sombra: int = 0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	if sombra > 0:
		s.shadow_color = C.PANEL_SHADOW
		s.shadow_size = sombra
	return s


func _crear_fondo() -> void:
	# Degradado de noche profunda.
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(C.BG_TOP, 0.96), Color(C.BG_BOTTOM, 0.97)])
	var gtex: GradientTexture2D = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	gtex.width = 8
	gtex.height = 256
	var fondo: TextureRect = TextureRect.new()
	fondo.texture = gtex
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)

	# Viñeta suave.
	var g2: Gradient = Gradient.new()
	g2.offsets = PackedFloat32Array([0.55, 1.0])
	g2.colors = PackedColorArray([Color(0, 0, 0.03, 0.0), Color(0, 0, 0.03, 0.55)])
	var t2: GradientTexture2D = GradientTexture2D.new()
	t2.gradient = g2
	t2.fill = GradientTexture2D.FILL_RADIAL
	t2.fill_from = Vector2(0.5, 0.5)
	t2.fill_to = Vector2(1.0, 0.5)
	t2.width = 256
	t2.height = 256
	var vineta: TextureRect = TextureRect.new()
	vineta.texture = t2
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(vineta)


## Panel de piezas y tiempo (arriba a la izquierda). Devuelve su rectángulo.
func _crear_hud() -> Rect2:
	var panel: Panel = Panel.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(320, 128)
	panel.add_theme_stylebox_override("panel", _estilo_panel(C.PANEL_BG, C.PANEL_BORDER, 3, 8, 14))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(panel)

	_lbl_piezas = _etiqueta("", 28, C.TEXT)
	_lbl_piezas.position = Vector2(20, 12)
	panel.add_child(_lbl_piezas)

	_lbl_tiempo = _etiqueta("", 28, C.ACCENT_BLUE)
	_lbl_tiempo.position = Vector2(20, 54)
	panel.add_child(_lbl_tiempo)

	_barra_w = 280.0
	var pista: ColorRect = ColorRect.new()
	pista.color = C.SLIDER_TRACK
	pista.position = Vector2(20, 102)
	pista.size = Vector2(_barra_w, 10)
	pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pista)

	_barra_fill = ColorRect.new()
	_barra_fill.color = C.SLIDER_FILL_HI
	_barra_fill.size = Vector2(0.0, 10.0)
	_barra_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pista.add_child(_barra_fill)

	var borde: Panel = Panel.new()
	borde.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	borde.add_theme_stylebox_override("panel", _estilo_panel(Color(0, 0, 0, 0), C.PANEL_BORDER, 1, 0))
	borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pista.add_child(borde)

	return Rect2(panel.position, panel.size)


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


func _construir_rompecabezas(vp: Vector2, rect_hud: Rect2) -> void:
	var textura: Texture2D = _elegir_textura()
	var tam_img: Vector2 = textura.get_size()
	var area_max: Vector2 = vp * Vector2(0.55, 0.62)
	var escala: float = minf(area_max.x / tam_img.x, area_max.y / tam_img.y)
	var tam_tablero: Vector2 = tam_img * escala
	var origen: Vector2 = Vector2((vp.x - tam_tablero.x) / 2.0, (vp.y - tam_tablero.y) / 2.0 + 10.0)
	_tam_pieza = tam_tablero / Vector2(COLUMNAS, FILAS)
	var region_pieza: Vector2 = tam_img / Vector2(COLUMNAS, FILAS)

	# Marco exterior del tablero (con brillo que se enciende al terminar).
	_marco = Panel.new()
	_marco_estilo = _estilo_panel(C.PANEL_BG, C.PANEL_BORDER, 3, 10, 22)
	_marco_estilo.shadow_color = C.PANEL_SHADOW
	_marco.add_theme_stylebox_override("panel", _marco_estilo)
	_marco.position = origen - Vector2(MARCO_PAD, MARCO_PAD)
	_marco.size = tam_tablero + Vector2(MARCO_PAD, MARCO_PAD) * 2.0
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_marco)

	_tablero = Control.new()
	_tablero.position = origen
	_tablero.size = tam_tablero
	_tablero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_tablero)

	var fondo_tab: ColorRect = ColorRect.new()
	fondo_tab.color = C.SLIDER_TRACK
	fondo_tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tablero.add_child(fondo_tab)

	# Panel de referencia (arriba a la derecha).
	var panel_ref: Panel = Panel.new()
	panel_ref.size = Vector2(216, 184)
	panel_ref.position = Vector2(vp.x - panel_ref.size.x - 24.0, 24.0)
	panel_ref.add_theme_stylebox_override("panel", _estilo_panel(C.PANEL_BG, C.PANEL_BORDER, 3, 8, 14))
	panel_ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(panel_ref)
	var lbl_ref: Label = _etiqueta("Referencia", 20, C.TEXT_MUTED)
	lbl_ref.position = Vector2(14, 8)
	panel_ref.add_child(lbl_ref)

	_referencia = TextureRect.new()
	_referencia.texture = textura
	_referencia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_referencia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_referencia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_referencia.size = Vector2(190, 140)
	_referencia.position = Vector2(13, 36)
	_referencia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_ref.add_child(_referencia)

	var rect_ref: Rect2 = Rect2(panel_ref.position, panel_ref.size)
	var rect_tab: Rect2 = Rect2(_marco.position, _marco.size)

	for cx: int in COLUMNAS:
		for cy: int in FILAS:
			var pos_local: Vector2 = Vector2(cx, cy) * _tam_pieza

			# Casilla de destino (se resalta cuando la pieza arrastrada está cerca).
			var slot: Panel = Panel.new()
			var estilo_slot: StyleBoxFlat = _estilo_panel(Color(C.PANEL_BORDER, 0.10), Color(C.PANEL_BORDER, 0.55), 1, 0)
			slot.add_theme_stylebox_override("panel", estilo_slot)
			slot.position = pos_local
			slot.size = _tam_pieza
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_tablero.add_child(slot)

			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(Vector2(cx, cy) * region_pieza, region_pieza)

			# Pieza: contenedor con sombra, imagen y marco (para poder animarla entera).
			var pieza: Control = Control.new()
			pieza.size = _tam_pieza
			pieza.pivot_offset = _tam_pieza * 0.5
			pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var sombra: ColorRect = ColorRect.new()
			sombra.color = Color(0, 0, 0.03, 0.5)
			sombra.position = SOMBRA_REPOSO
			sombra.size = _tam_pieza
			sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pieza.add_child(sombra)

			var img: TextureRect = TextureRect.new()
			img.texture = atlas
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_SCALE
			img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pieza.add_child(img)

			var borde: Panel = Panel.new()
			var estilo: StyleBoxFlat = _estilo_panel(Color(0, 0, 0, 0), C.ACCENT_DIM, 2, 0)
			borde.add_theme_stylebox_override("panel", estilo)
			borde.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pieza.add_child(borde)

			_raiz.add_child(pieza)
			_destinos[pieza] = origen + pos_local
			_sombras[pieza] = sombra
			_bordes[pieza] = estilo
			_slots[pieza] = estilo_slot
			pieza.position = _posicion_aleatoria(vp, rect_tab, rect_ref, rect_hud)
			_piezas.append(pieza)

			# Entrada: las piezas aparecen con un pequeño pop escalonado.
			pieza.modulate.a = 0.0
			pieza.scale = Vector2(0.85, 0.85)
			var tw: Tween = create_tween().set_parallel(true)
			var retraso: float = 0.04 * float(_piezas.size())
			tw.tween_property(pieza, "modulate:a", 1.0, 0.25).set_delay(retraso)
			tw.tween_property(pieza, "scale", Vector2.ONE, 0.3).set_delay(retraso) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _posicion_aleatoria(vp: Vector2, rect_tab: Rect2, rect_ref: Rect2, rect_hud: Rect2) -> Vector2:
	var pos: Vector2 = Vector2.ZERO
	for _i: int in 80:
		pos = Vector2(
			randf_range(8.0, vp.x - _tam_pieza.x - 14.0),
			randf_range(90.0, vp.y - _tam_pieza.y - 20.0)
		)
		var rp: Rect2 = Rect2(pos, _tam_pieza).grow(6.0)
		if not rect_tab.intersects(rp) and not rect_ref.intersects(rp) and not rect_hud.intersects(rp):
			return pos
	return pos


# ──────────────────────────────────────────────
# INPUT
# ──────────────────────────────────────────────

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
		_resaltar_destino(_arrastrada)
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
			_levantar(p, true)
			return


func _soltar() -> void:
	if _arrastrada == null:
		return
	var p: Control = _arrastrada
	_arrastrada = null
	_quitar_resaltado()
	var destino: Vector2 = _destinos[p]
	if p.position.distance_to(destino) <= _tam_pieza.length() * MARGEN_ENCAJE:
		_encajar(p, destino)
	else:
		_levantar(p, false)


## La pieza se "levanta" al agarrarla (más grande, sombra más lejana) y vuelve a posarse al soltarla.
func _levantar(p: Control, arriba: bool) -> void:
	var sombra: ColorRect = _sombras[p]
	var tw: Tween = create_tween().set_parallel(true)
	if arriba:
		tw.tween_property(p, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sombra, "position", SOMBRA_ALTA, 0.1)
		tw.tween_property(sombra, "color:a", 0.38, 0.1)
		tw.tween_property(_bordes[p], "border_color", C.ACCENT, 0.1)
	else:
		tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sombra, "position", SOMBRA_REPOSO, 0.16)
		tw.tween_property(sombra, "color:a", 0.5, 0.16)
		tw.tween_property(_bordes[p], "border_color", C.ACCENT_DIM, 0.16)


## Resalta la casilla de destino cuando la pieza arrastrada está lo bastante cerca para encajar.
func _resaltar_destino(p: Control) -> void:
	var cerca: bool = p.position.distance_to(_destinos[p]) <= _tam_pieza.length() * MARGEN_ENCAJE
	var estilo: StyleBoxFlat = _slots[p] if cerca else null
	if estilo == _slot_resaltado:
		return
	_quitar_resaltado()
	if estilo != null:
		estilo.border_color = C.ACCENT
		estilo.bg_color = Color(C.ACCENT, 0.22)
		estilo.set_border_width_all(3)
		_slot_resaltado = estilo


func _quitar_resaltado() -> void:
	if _slot_resaltado != null:
		_slot_resaltado.border_color = Color(C.PANEL_BORDER, 0.55)
		_slot_resaltado.bg_color = Color(C.PANEL_BORDER, 0.10)
		_slot_resaltado.set_border_width_all(1)
		_slot_resaltado = null


## Encaje: la pieza se asienta con un rebote, un destello y una onda; queda fija al fondo.
func _encajar(p: Control, destino: Vector2) -> void:
	_fijadas[p] = true
	_raiz.move_child(p, _marco.get_index() + 2)   # las colocadas quedan bajo las demás piezas
	_colocadas += 1

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(p, "position", destino, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sombras[p], "color:a", 0.0, 0.2)
	tw.tween_property(_bordes[p], "border_color", Color(C.ACCENT_DIM, 0.35), 0.3)
	var pop: Tween = create_tween()
	pop.tween_property(p, "scale", Vector2(1.08, 1.08), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Destello blanco sobre la pieza.
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(C.TITLE, 0.55)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(flash)
	var tf: Tween = create_tween()
	tf.tween_property(flash, "modulate:a", 0.0, 0.35)
	tf.tween_callback(flash.queue_free)

	# Onda que se expande desde el borde de la pieza.
	var onda: Panel = Panel.new()
	onda.add_theme_stylebox_override("panel", _estilo_panel(Color(0, 0, 0, 0), C.ACCENT, 3, 2))
	onda.position = destino
	onda.size = _tam_pieza
	onda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(onda)
	var to: Tween = create_tween().set_parallel(true)
	to.tween_property(onda, "position", destino - Vector2(22, 22), 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	to.tween_property(onda, "size", _tam_pieza + Vector2(44, 44), 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	to.tween_property(onda, "modulate:a", 0.0, 0.4)
	to.chain().tween_callback(onda.queue_free)

	# Barra de progreso.
	var total: int = COLUMNAS * FILAS
	create_tween().tween_property(_barra_fill, "size:x", _barra_w * float(_colocadas) / float(total), 0.25) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	_actualizar_info()
	if _colocadas >= total:
		_terminar()


func _terminar() -> void:
	_jugando = false
	_lbl_ayuda.visible = false

	# El marco del tablero se enciende y aparece el mensaje.
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_marco_estilo, "border_color", C.ACCENT, 0.4)
	tw.tween_property(_marco_estilo, "shadow_color", Color(C.GLOW, 0.8), 0.4)
	tw.tween_property(_barra_fill, "color", C.ACCENT, 0.4)
	_lbl_msg.text = "¡Foto lista!"
	_lbl_msg.modulate.a = 0.0
	_lbl_msg.scale = Vector2(0.8, 0.8)
	tw.tween_property(_lbl_msg, "modulate:a", 1.0, 0.35)
	tw.tween_property(_lbl_msg, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(1.6).timeout
	var salida: Tween = create_tween()
	salida.tween_property(_raiz, "modulate:a", 0.0, 0.5)
	await salida.finished
	completado.emit()
	queue_free()


func _actualizar_info() -> void:
	_lbl_piezas.text = "Piezas %d/%d" % [_colocadas, COLUMNAS * FILAS]
	_lbl_tiempo.text = "Tiempo %02d:%02d" % [int(_tiempo / 60.0), int(_tiempo) % 60]
