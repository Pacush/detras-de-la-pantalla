extends Control
var escena_exploracion = preload("res://scenes/exploration_mode_scenes/ExplorationMode.tscn")
var nivel_instanciado = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.start("timeline")
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_dialogic_signal(signalName: String):
	if signalName == "leave_library_table":
		iniciar_exploracion()

func iniciar_exploracion():
	$Background.hide()
	$Character.hide()
	nivel_instanciado = escena_exploracion.instantiate()
	add_child(nivel_instanciado)
