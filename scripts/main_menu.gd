extends Control
## Menú principal — estética pixel art sombría y melancólica.
##
## El fondo animado (lluvia, polvo, viñeta, relámpagos) lo pone main.gd con menu_backdrop.gd,
## para que siga vivo al entrar a Cargar partida / Ajustes. Aquí solo van título y botones.

signal start_new_game
signal load_game
signal show_settings
signal quit_game

const UI = preload("res://scripts/ui/ui_style.gd")
const C = preload("res://scripts/ui/ui_colors.gd")
const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")

const TITLE_FONT_SIZE: int = 84
const BUTTON_FONT_SIZE: int = 28
const BUTTON_HEIGHT: float = 64.0

const GHOST_A_BASE: Vector2 = Vector2(5, 4)
const GHOST_B_BASE: Vector2 = Vector2(-5, 2)

@onready var buttons_container: VBoxContainer = $VBoxContainer
@onready var title: Label = $Title

var _glitch_timer: Timer
var _ghost_a: Label
var _ghost_b: Label
var _divider: Control


func _ready() -> void:
	_style_title()
	_style_buttons()

	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	_play_intro()


# ──────────────────────────────────────────────
# TÍTULO: sombras desfasadas, glitch ocasional, respiración
# ──────────────────────────────────────────────

func _style_title() -> void:
	title.add_theme_font_override("font", PIX_FONT)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", C.TITLE)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 1.0))
	title.add_theme_constant_override("outline_size", 8)

	_ghost_a = _make_ghost(Color(0.45, 0.25, 0.55, 0.60))
	_ghost_b = _make_ghost(Color(0.20, 0.42, 0.55, 0.50))
	_set_ghost_offset(_ghost_a, GHOST_A_BASE)
	_set_ghost_offset(_ghost_b, GHOST_B_BASE)

	# Línea divisoria pixelada bajo el título con un rombo central
	_divider = Control.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.anchor_left = 0.5
	_divider.anchor_right = 0.5
	_divider.offset_left = -180.0
	_divider.offset_right = 180.0
	_divider.offset_top = 232.0
	_divider.offset_bottom = 236.0
	_divider.pivot_offset = Vector2(180.0, 2.0)
	add_child(_divider)

	var line: ColorRect = ColorRect.new()
	line.color = Color(0.35, 0.33, 0.50, 0.85)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var gem: ColorRect = ColorRect.new()
	gem.color = C.ACCENT
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size = Vector2(12, 12)
	gem.position = Vector2(180.0 - 6.0, 2.0 - 6.0)
	gem.pivot_offset = Vector2(6, 6)
	gem.rotation = PI / 4.0
	_divider.add_child(gem)

	_glitch_timer = Timer.new()
	_glitch_timer.one_shot = true
	_glitch_timer.timeout.connect(_on_glitch_timer)
	add_child(_glitch_timer)
	_glitch_timer.start(randf_range(3.0, 6.0))


func _make_ghost(col: Color) -> Label:
	var g: Label = Label.new()
	g.text = title.text
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_behind_parent = true
	g.add_theme_font_override("font", PIX_FONT)
	g.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	g.add_theme_color_override("font_color", col)
	title.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return g


func _set_ghost_offset(ghost: Label, v: Vector2) -> void:
	ghost.offset_left = v.x
	ghost.offset_right = v.x
	ghost.offset_top = v.y
	ghost.offset_bottom = v.y


func _jitter_ghosts(dx: float, dy: float) -> void:
	_set_ghost_offset(_ghost_a, GHOST_A_BASE + Vector2(dx, dy))
	_set_ghost_offset(_ghost_b, GHOST_B_BASE - Vector2(dx, dy))
	title.modulate.a = 0.75


func _reset_ghosts() -> void:
	_set_ghost_offset(_ghost_a, GHOST_A_BASE)
	_set_ghost_offset(_ghost_b, GHOST_B_BASE)
	title.modulate.a = 1.0


func _on_glitch_timer() -> void:
	var t: Tween = create_tween()
	for _i in range(4):
		t.tween_callback(_jitter_ghosts.bind(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0)))
		t.tween_interval(0.04)
	t.tween_callback(_reset_ghosts)
	_glitch_timer.start(randf_range(3.5, 7.0))


func _start_title_breathing() -> void:
	var t: Tween = create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(title, "modulate:a", 0.80, 2.4)
	t.tween_property(title, "modulate:a", 1.0, 2.4)


# ──────────────────────────────────────────────
# BOTONES (estilo compartido con el resto de menús)
# ──────────────────────────────────────────────

func _style_buttons() -> void:
	for child: Node in buttons_container.get_children():
		var btn: Button = child as Button
		if btn != null:
			UI.style_button(btn, BUTTON_FONT_SIZE, BUTTON_HEIGHT)


# ──────────────────────────────────────────────
# ENTRADA
# ──────────────────────────────────────────────

func _play_intro() -> void:
	title.modulate.a = 0.0
	_divider.scale = Vector2(0.0, 1.0)

	var t: Tween = create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(title, "modulate:a", 1.0, 1.2)
	t.tween_property(_divider, "scale:x", 1.0, 0.9).set_delay(0.5)
	t.finished.connect(_start_title_breathing)

	var delay: float = 0.7
	for child: Node in buttons_container.get_children():
		var btn: Button = child as Button
		if btn == null:
			continue
		btn.modulate.a = 0.0
		btn.scale = Vector2.ONE * 0.92
		var bt: Tween = btn.create_tween().set_parallel(true)
		bt.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		bt.tween_property(btn, "modulate:a", 1.0, 0.5).set_delay(delay)
		bt.tween_property(btn, "scale", Vector2.ONE, 0.5).set_delay(delay)
		delay += 0.12


# ──────────────────────────────────────────────
# SEÑALES HACIA main.gd
# ──────────────────────────────────────────────

func _on_new_game_pressed() -> void:
	start_new_game.emit()

func _on_load_game_pressed() -> void:
	load_game.emit()

func _on_settings_pressed() -> void:
	show_settings.emit()

func _on_quit_pressed() -> void:
	quit_game.emit()

func disable_menu() -> void:
	for button in buttons_container.get_children():
		if button is Button:
			button.disabled = true

func enable_menu() -> void:
	for button in buttons_container.get_children():
		if button is Button:
			button.disabled = false
