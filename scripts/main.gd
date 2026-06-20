extends Control
var escena_exploracion = preload("res://scenes/exploration_mode_scenes/ExplorationMode.tscn")
var nivel_instanciado = null
@onready var transition_layer = $TransitionLayer/ColorRect
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	transition_layer.modulate.a = 0.0
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.start("timeline")
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_dialogic_signal(signalName: String):
	if signalName == "leave_library_table":
		Dialogic.paused = true
		iniciar_exploracion()

func iniciar_exploracion():
	await fade_to_black()
	$Background.hide()
	Dialogic.paused = false
	Dialogic.end_timeline()
	nivel_instanciado = escena_exploracion.instantiate()
	await add_child(nivel_instanciado)
	await fade_from_black()

func fade_to_black():
	var tween_oscurecer = create_tween()
	tween_oscurecer.tween_property(transition_layer, "modulate:a", 1.0, 1.0)
	await tween_oscurecer.finished
	
func fade_from_black():
	var tween_aclarar = create_tween()
	tween_aclarar.tween_property(transition_layer, "modulate:a", 0.0, 1.0)
