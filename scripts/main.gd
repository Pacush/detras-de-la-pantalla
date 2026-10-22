extends Control

var escena_exploracion  = preload("res://scenes/exploration_mode_scenes/ExplorationMode.tscn")
var main_menu_scene     = preload("res://scenes/MainMenu.tscn")
var load_menu_scene     = preload("res://scenes/LoadMenu.tscn")
var settings_menu_scene = preload("res://scenes/SettingsMenu.tscn")
var story_select_scene  = preload("res://scenes/StorySelect.tscn")
var history_menu_scene: PackedScene = preload("res://scenes/PauseHistoryMenu.tscn")
var minijuego_mochila_scene = preload("res://scenes/minigames/organizar_mochila/MinijuegoOrganizarMochila.tscn")
var minijuego_rompecabezas_scene = preload("res://scenes/minigames/rompecabezas/MinijuegoRompecabezas.tscn")

const MenuBackdrop = preload("res://scripts/ui/menu_backdrop.gd")
const UI = preload("res://scripts/ui/ui_style.gd")
const Click = preload("res://scripts/ui/ui_click.gd")
const MusicManager = preload("res://scripts/music_manager.gd")
const UserSettings = preload("res://scripts/ui/user_settings.gd")

# Música de fondo (menú, tema de cada historia, minijuegos), con fundidos y bucle con pausa.
var music: MusicManager = null

# Fondo animado compartido por el menú principal y sus submenús (no se reinicia al navegar).
var menu_backdrop: Control = null

# Historial abierto desde el botón de la esquina (mismo panel que el de la pausa).
var _history_layer: CanvasLayer = null

var current_menu: Node = null
var nivel_instanciado: Node = null
var minijuego_activo: Node = null
var game_started: bool = false
var current_story: String = ""

# Timeline de entrada de cada historia.
const STORY_TIMELINES: Dictionary = {
	"darwin": "timeline",
	"romina": "timeline_romina",
}

# Capa de estática (señal romina_estatica): se crea la primera vez que se usa.
var _static_layer: CanvasLayer = null
var _static_material: ShaderMaterial = null

# Shader de estática para la señal romina_estatica: desplaza bandas horizontales de la
# pantalla, separa los canales de color y mezcla ruido tipo nieve.
const STATIC_SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 18.0);
	float band = floor(uv.y * 28.0);
	float torn = step(0.55, hash(vec2(band + 7.0, t)));
	float shift = (hash(vec2(band, t)) - 0.5) * 0.12 * strength * torn;
	vec2 suv = vec2(uv.x + shift, uv.y);
	float ca = 0.012 * strength;
	float r = texture(screen_tex, suv + vec2(ca, 0.0)).r;
	float g = texture(screen_tex, suv).g;
	float b = texture(screen_tex, suv - vec2(ca, 0.0)).b;
	vec3 col = vec3(r, g, b);
	float n = hash(floor(FRAGCOORD.xy / 3.0) + t);
	col = mix(col, vec3(n), strength * 0.45);
	COLOR = vec4(col, 1.0);
}
"""

# Shader de desaturación para la señal pasillo_desaturar
const DESATURACION_SHADER_CODE: String = """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(gray), amount);
	COLOR = color;
}
"""

@onready var transition_layer: ColorRect = $TransitionLayer/ColorRect
@onready var background_node: TextureRect = $Background

func _ready() -> void:
	UserSettings.load_and_apply()   # volumen y velocidad de texto de la última sesión
	transition_layer.modulate.a = 0.0
	music = MusicManager.new()
	add_child(music)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	show_main_menu()


# ──────────────────────────────────────────────
# MENÚ PRINCIPAL
# ──────────────────────────────────────────────

func show_main_menu() -> void:
	game_started = false
	_ocultar_estatica()
	_cerrar_historial(false)

	# skip_ending = true: sin el timeline de cierre de Dialogic, que crearía un layout nuevo
	# (con el fondo y el botón de historial) justo encima del menú.
	var layout: Variant = null
	if get_tree().has_meta("dialogic_layout_node"):
		# El meta puede apuntar a un nodo ya liberado por Dialogic: se guarda como Variant.
		layout = get_tree().get_meta("dialogic_layout_node")

	var habia_timeline: bool = Dialogic.current_timeline != null
	if is_instance_valid(layout):
		# Limpia el estado de Dialogic (retratos, texto, fondo...) mientras sus nodos siguen
		# vivos. Si no, quedan retratos apuntando a nodos liberados y la siguiente partida
		# falla en leave_character ("has_meta on null").
		Dialogic.clear(Dialogic.ClearFlags.KEEP_VARIABLES)
	else:
		Dialogic.current_state_info["portraits"] = {}
	if habia_timeline:
		Dialogic.end_timeline(true)

	if is_instance_valid(layout):
		(layout as Node).queue_free()
	if get_tree().has_meta("dialogic_layout_node"):
		get_tree().remove_meta("dialogic_layout_node")

	if nivel_instanciado:
		nivel_instanciado.queue_free()
		nivel_instanciado = null

	if minijuego_activo:
		minijuego_activo.queue_free()
		minijuego_activo = null

	if current_menu:
		current_menu.queue_free()

	_ensure_backdrop()
	music.play_track("menu")
	current_menu = main_menu_scene.instantiate()
	add_child(current_menu)
	current_menu.start_new_game.connect(_on_new_game_pressed)
	current_menu.load_game.connect(_on_load_game_pressed)
	current_menu.show_settings.connect(_on_settings_pressed)
	current_menu.quit_game.connect(_on_quit_pressed)


func _ensure_backdrop() -> void:
	if menu_backdrop != null and is_instance_valid(menu_backdrop):
		return
	menu_backdrop = MenuBackdrop.new()
	add_child(menu_backdrop)


func _free_backdrop() -> void:
	if menu_backdrop != null and is_instance_valid(menu_backdrop):
		menu_backdrop.queue_free()
	menu_backdrop = null


func show_load_menu() -> void:
	if current_menu:
		current_menu.queue_free()
	_ensure_backdrop()
	music.play_track("menu")
	current_menu = load_menu_scene.instantiate()
	add_child(current_menu)
	current_menu.back_to_menu.connect(show_main_menu)
	current_menu.slot_selected.connect(load_saved_game)


func show_story_select() -> void:
	if current_menu:
		current_menu.queue_free()
	current_menu = story_select_scene.instantiate()
	add_child(current_menu)
	current_menu.back_to_menu.connect(show_main_menu)
	current_menu.story_selected.connect(_on_story_selected)


func _on_story_selected(story_id: String) -> void:
	# La vista ya animó la selección; fundido a negro y arranca la historia.
	await fade_to_black()
	start_game(story_id)
	await fade_from_black()


func show_settings_menu() -> void:
	if current_menu:
		current_menu.queue_free()
	_ensure_backdrop()
	music.play_track("menu")
	current_menu = settings_menu_scene.instantiate()
	add_child(current_menu)
	current_menu.back_to_menu.connect(show_main_menu)


func _on_new_game_pressed() -> void:
	show_story_select()

func _on_load_game_pressed() -> void:
	show_load_menu()

func _on_settings_pressed() -> void:
	show_settings_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()


func start_game(story_id: String = "darwin") -> void:
	if game_started:
		return
	game_started = true
	current_story = story_id
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	_free_backdrop()
	music.play_track(story_id)   # "darwin" o "romina": tema de la historia
	background_node.show()
	var timeline_name: String = STORY_TIMELINES.get(story_id, "timeline")
	Dialogic.start(timeline_name)
	_traducir_interfaz_dialogic()


func load_saved_game(slot_name: String) -> void:
	if game_started:
		return
	game_started = true
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	_free_backdrop()
	background_node.show()
	restore_story_from_slot(slot_name)
	Dialogic.Save.load(slot_name)
	_traducir_interfaz_dialogic()


## Historia en curso ("darwin" o "romina"). Si no se conoce, se deduce del timeline activo.
func get_current_story() -> String:
	if current_story != "":
		return current_story
	if Dialogic.current_timeline != null:
		return "romina" if Dialogic.current_timeline.resource_path.contains("romina") else "darwin"
	return "darwin"


## Al cargar una partida, recupera de qué historia era para que los siguientes guardados la registren.
func restore_story_from_slot(slot_name: String) -> void:
	var info: Dictionary = Dialogic.Save.get_slot_info(slot_name)
	current_story = str(info.get("story", ""))
	_musica_de_historia_tras_cargar()


## Tras cargar una partida, pone el tema de su historia (se espera a que Dialogic termine de cargar).
func _musica_de_historia_tras_cargar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	music.play_track(get_current_story())


## Los botones de la capa de historial de Dialogic vienen en inglés: se traducen y se estilizan.
func _traducir_interfaz_dialogic() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not get_tree().has_meta("dialogic_layout_node"):
		return
	var layout_var: Variant = get_tree().get_meta("dialogic_layout_node")
	if not is_instance_valid(layout_var):
		return
	var layout: Node = layout_var as Node
	var traducciones: Dictionary = {"ShowHistory": "Historial", "HideHistory": "Cerrar"}
	for nombre: String in traducciones:
		for nodo: Node in layout.find_children(nombre, "Button", true, false):
			var btn: Button = nodo as Button
			btn.text = traducciones[nombre]
			# Mismo estilo pixel art que los menús (incluye el sonido de click).
			UI.style_button(btn, 22, 48.0)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_END

			# El botón "Historial" abre nuestro panel (igual al de la pausa) en vez del de Dialogic.
			if nombre == "ShowHistory":
				var capa_dialogic: Node = btn.get_parent()
				var original: Callable = Callable(capa_dialogic, "_on_show_history_pressed")
				if btn.pressed.is_connected(original):
					btn.pressed.disconnect(original)
				btn.pressed.connect(_abrir_historial)


## Abre el historial con el mismo panel del menú de pausa y detiene Dialogic mientras está abierto.
func _abrir_historial() -> void:
	if _history_layer != null and is_instance_valid(_history_layer):
		return
	Dialogic.paused = true

	_history_layer = CanvasLayer.new()
	_history_layer.layer = 900   # sobre Dialogic y los minijuegos, bajo la pausa (1000)
	add_child(_history_layer)

	var velo: ColorRect = ColorRect.new()
	velo.color = UI.C.OVERLAY_PAUSE
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_layer.add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: Control = history_menu_scene.instantiate() as Control
	_history_layer.add_child(panel)
	panel.connect("back_to_menu", _cerrar_historial)


func _cerrar_historial(reanudar: bool = true) -> void:
	if _history_layer == null or not is_instance_valid(_history_layer):
		_history_layer = null
		return
	_history_layer.queue_free()
	_history_layer = null
	if reanudar:
		Dialogic.paused = false


# ──────────────────────────────────────────────
# SEÑALES DE DIALOGIC
# ──────────────────────────────────────────────

func _on_dialogic_signal(signal_name: String) -> void:
	match signal_name:

		# ── Timeline original ──
		"leave_library_table":
			Dialogic.paused = true
			iniciar_exploracion()

		# ── Capítulo 1: minijuego 1 (Organizar la Mochila) ──
		"trigger_minijuego_mochila":
			Dialogic.paused = true
			_iniciar_minijuego_mochila()

		# ── Capítulo 1: pasillo desaturado ──
		"pasillo_desaturar":
			_aplicar_desaturacion_fondo()

		# ── Capítulo 1: Darwin con postura encorvada ──
		"darwin_postura_encorvada":
			_forzar_portrait_darwin("broken")

		# ── Fin de la historia (Darwin o Romina) → fundido a negro y menú principal ──
		"cap1_fin", "romina_cap1_fin":
			Dialogic.paused = true
			await _terminar_historia_y_volver_al_menu()

		# ── Minijuego 2 placeholder (aún no implementado) ──
		"trigger_minijuego_peso_silencio":
			# TODO: instanciar MinijuegoPesoSilencio cuando esté listo.
			# Por ahora simplemente continúa el timeline.
			print("[Minijuego] 'El Peso del Silencio' aún no implementado — continuando.")

		# ── Capítulo 1 de Romina: minijuego 1 (Rompecabezas) ──
		"trigger_minijuego_rompecabezas":
			Dialogic.paused = true
			_iniciar_minijuego_rompecabezas()

		# ── Capítulo 1 de Romina: la interfaz del celular se distorsiona ──
		"romina_estatica":
			_reproducir_estatica()

		# ── Minijuego 2 de Romina placeholder (aún no implementado) ──
		"trigger_minijuego_nudo_red":
			# TODO: instanciar MinijuegoNudoRed cuando esté listo (con RETRY al fallar).
			# Por ahora simplemente continúa el timeline.
			print("[Minijuego] 'El Nudo en la Red' aún no implementado — continuando.")


# ──────────────────────────────────────────────
# MINIJUEGO 1 — ORGANIZAR LA MOCHILA
# ──────────────────────────────────────────────

func _iniciar_minijuego_mochila() -> void:
	# Fade suave a negro antes de mostrar el minijuego (la música cambia a la vez)
	music.play_track("minijuego1")
	await fade_to_black()

	minijuego_activo = minijuego_mochila_scene.instantiate()
	add_child(minijuego_activo)

	# Escuchar la señal de victoria del minijuego
	minijuego_activo.completado.connect(_on_minijuego_completado)

	await fade_from_black()


## Compartido por todos los minijuegos: limpia la referencia y reanuda Dialogic.
func _on_minijuego_completado() -> void:
	# El minijuego se destruye solo al emitir la señal.
	# Aquí ya no existe en el árbol, solo limpiamos la referencia.
	minijuego_activo = null

	# Fade a negro para la transición de vuelta a la novela visual; vuelve el tema del personaje
	music.play_track(get_current_story())
	await fade_to_black()

	# Reanudar el timeline de Dialogic donde quedó pausado
	Dialogic.paused = false

	await fade_from_black()


# ──────────────────────────────────────────────
# MINIJUEGO 1 DE ROMINA — ROMPECABEZAS
# ──────────────────────────────────────────────

func _iniciar_minijuego_rompecabezas() -> void:
	music.play_track("minijuego1")
	await fade_to_black()

	minijuego_activo = minijuego_rompecabezas_scene.instantiate()
	add_child(minijuego_activo)
	minijuego_activo.completado.connect(_on_minijuego_completado)

	await fade_from_black()


# ──────────────────────────────────────────────
# EFECTOS VISUALES — CAP 1
# ──────────────────────────────────────────────

func _aplicar_desaturacion_fondo() -> void:
	var shader: Shader = Shader.new()
	shader.code = DESATURACION_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("amount", 0.0)
	background_node.material = mat

	var tween: Tween = create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("amount", v),
		0.0, 0.85, 2.0
	)


## Estática visual sobre toda la pantalla (Romina, opción A): ráfaga intensa que decae.
func _reproducir_estatica() -> void:
	_asegurar_capa_estatica()
	_static_layer.visible = true

	var set_strength: Callable = func(v: float) -> void: _static_material.set_shader_parameter("strength", v)
	var tween: Tween = create_tween()
	tween.tween_method(set_strength, 0.0, 1.0, 0.15)
	tween.tween_interval(0.5)
	tween.tween_method(set_strength, 1.0, 0.55, 0.2)
	tween.tween_method(set_strength, 0.55, 1.0, 0.1)
	tween.tween_interval(0.3)
	tween.tween_method(set_strength, 1.0, 0.0, 1.4)
	tween.tween_callback(_ocultar_estatica)


func _asegurar_capa_estatica() -> void:
	if _static_layer != null:
		return
	_static_layer = CanvasLayer.new()
	_static_layer.layer = 50   # encima de Dialogic, debajo del fundido a negro (100)
	add_child(_static_layer)

	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shader: Shader = Shader.new()
	shader.code = STATIC_SHADER_CODE
	_static_material = ShaderMaterial.new()
	_static_material.shader = shader
	_static_material.set_shader_parameter("strength", 0.0)
	rect.material = _static_material
	_static_layer.visible = false


func _ocultar_estatica() -> void:
	if _static_layer != null:
		_static_layer.visible = false


func _forzar_portrait_darwin(portrait_name: String) -> void:
	var darwin: DialogicCharacter = DialogicResourceUtil.get_character_resource("darwin")
	if darwin == null:
		push_warning("[Main] No se encontró el personaje 'darwin'.")
		return
	if not Dialogic.Portraits.is_character_joined(darwin):
		push_warning("[Main] Darwin no está en escena.")
		return
	Dialogic.Portraits.change_character_portrait(darwin, portrait_name)


# ──────────────────────────────────────────────
# FIN DE HISTORIA → MENÚ PRINCIPAL
# ──────────────────────────────────────────────

func _terminar_historia_y_volver_al_menu() -> void:
	await fade_to_black()
	background_node.hide()
	background_node.material = null
	current_story = ""

	# Al reanudar, Dialogic cierra el timeline por su cuenta (con su timeline de cierre, que
	# retira el layout). Se espera a que termine antes de mostrar el menú para no pisarlo.
	Dialogic.paused = false
	var frames: int = 0
	while Dialogic.current_timeline != null and frames < 180:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame

	show_main_menu()   # limpia lo que quede del layout de Dialogic y muestra el menú
	await fade_from_black()


# ──────────────────────────────────────────────
# TRANSICIÓN CAP 1 → EXPLORACIÓN (ya no se usa al terminar las historias)
# ──────────────────────────────────────────────

func _transicion_cap1_a_exploracion() -> void:
	await fade_to_black()
	background_node.hide()
	background_node.material = null
	Dialogic.paused = false
	Dialogic.end_timeline()
	nivel_instanciado = escena_exploracion.instantiate()
	add_child(nivel_instanciado)
	await fade_from_black()


# ──────────────────────────────────────────────
# TRANSICIONES GENÉRICAS
# ──────────────────────────────────────────────

func iniciar_exploracion() -> void:
	await fade_to_black()
	background_node.hide()
	Dialogic.paused = false
	Dialogic.end_timeline()
	nivel_instanciado = escena_exploracion.instantiate()
	add_child(nivel_instanciado)
	await fade_from_black()


func fade_to_black() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(transition_layer, "modulate:a", 1.0, 1.0)
	await tween.finished


func fade_from_black() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(transition_layer, "modulate:a", 0.0, 1.0)
	await tween.finished
