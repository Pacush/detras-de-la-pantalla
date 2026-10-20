extends Control

var escena_exploracion  = preload("res://scenes/exploration_mode_scenes/ExplorationMode.tscn")
var main_menu_scene     = preload("res://scenes/MainMenu.tscn")
var load_menu_scene     = preload("res://scenes/LoadMenu.tscn")
var settings_menu_scene = preload("res://scenes/SettingsMenu.tscn")
var minijuego_mochila_scene = preload("res://scenes/minigames/organizar_mochila/MinijuegoOrganizarMochila.tscn")

var current_menu: Node = null
var nivel_instanciado: Node = null
var minijuego_activo: Node = null
var game_started: bool = false

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
	transition_layer.modulate.a = 0.0
	Dialogic.signal_event.connect(_on_dialogic_signal)
	show_main_menu()


# ──────────────────────────────────────────────
# MENÚ PRINCIPAL
# ──────────────────────────────────────────────

func show_main_menu() -> void:
	game_started = false

	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()

	if get_tree().has_meta("dialogic_layout_node"):
		var layout: Node = get_tree().get_meta("dialogic_layout_node")
		if is_instance_valid(layout):
			layout.queue_free()
		get_tree().remove_meta("dialogic_layout_node")

	if nivel_instanciado:
		nivel_instanciado.queue_free()
		nivel_instanciado = null

	if minijuego_activo:
		minijuego_activo.queue_free()
		minijuego_activo = null

	if current_menu:
		current_menu.queue_free()

	current_menu = main_menu_scene.instantiate()
	add_child(current_menu)
	current_menu.start_new_game.connect(_on_new_game_pressed)
	current_menu.load_game.connect(_on_load_game_pressed)
	current_menu.show_settings.connect(_on_settings_pressed)
	current_menu.quit_game.connect(_on_quit_pressed)


func show_load_menu() -> void:
	if current_menu:
		current_menu.queue_free()
	current_menu = load_menu_scene.instantiate()
	add_child(current_menu)
	current_menu.back_to_menu.connect(show_main_menu)
	current_menu.slot_selected.connect(load_saved_game)


func show_settings_menu() -> void:
	if current_menu:
		current_menu.queue_free()
	current_menu = settings_menu_scene.instantiate()
	add_child(current_menu)
	current_menu.back_to_menu.connect(show_main_menu)


func _on_new_game_pressed() -> void:
	start_game()

func _on_load_game_pressed() -> void:
	show_load_menu()

func _on_settings_pressed() -> void:
	show_settings_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()


func start_game() -> void:
	if game_started:
		return
	game_started = true
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	background_node.show()
	Dialogic.start("timeline")


func load_saved_game(slot_name: String) -> void:
	if game_started:
		return
	game_started = true
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	background_node.show()
	Dialogic.Save.load(slot_name)


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

		# ── Capítulo 1: fin del capítulo → exploración ──
		"cap1_fin":
			Dialogic.paused = true
			await _transicion_cap1_a_exploracion()

		# ── Minijuego 2 placeholder (aún no implementado) ──
		"trigger_minijuego_peso_silencio":
			# TODO: instanciar MinijuegoPesoSilencio cuando esté listo.
			# Por ahora simplemente continúa el timeline.
			print("[Minijuego] 'El Peso del Silencio' aún no implementado — continuando.")


# ──────────────────────────────────────────────
# MINIJUEGO 1 — ORGANIZAR LA MOCHILA
# ──────────────────────────────────────────────

func _iniciar_minijuego_mochila() -> void:
	# Fade suave a negro antes de mostrar el minijuego
	await fade_to_black()

	minijuego_activo = minijuego_mochila_scene.instantiate()
	add_child(minijuego_activo)

	# Escuchar la señal de victoria del minijuego
	minijuego_activo.completado.connect(_on_minijuego_mochila_completado)

	await fade_from_black()


func _on_minijuego_mochila_completado() -> void:
	# El minijuego se destruye solo al emitir la señal.
	# Aquí ya no existe en el árbol, solo limpiamos la referencia.
	minijuego_activo = null

	# Fade a negro para la transición de vuelta a la novela visual
	await fade_to_black()

	# Reanudar el timeline de Dialogic donde quedó pausado
	Dialogic.paused = false

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
# TRANSICIÓN CAP 1 → EXPLORACIÓN
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
