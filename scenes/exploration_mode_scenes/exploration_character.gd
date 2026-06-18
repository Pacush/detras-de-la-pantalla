extends CharacterBody2D

# 1. Definimos los roles posibles
enum Role { PLAYER, COMPANION }

# 2. Variables exportadas (Aparecerán en el panel derecho del editor)
@export var character_role: Role = Role.PLAYER
@export var character_texture: Texture2D # Para arrastrar el PNG del personaje
@export var target_to_follow: Node2D # A quién seguirá (solo si es companion)
@export var speed: float = 300.0
@export var follow_distance: float = 100.0
@export var altura_deseada: float = 150.0
@export var limite_camara_derecha: int = 2500
@export var limite_camara_abajo: int = 1080

@onready var sprite = $Sprite2D
@onready var camara = $Camera2D

func _ready() -> void:
	if character_texture:
		sprite.texture = character_texture

		var altura_original = character_texture.get_height()

		if altura_original > 0:
			var factor_escala = altura_deseada / altura_original
			sprite.scale = Vector2(factor_escala, factor_escala)
	if character_role == Role.PLAYER:
		camara.make_current()
		camara.limit_right = limite_camara_derecha
		camara.limit_left = 0
		camara.limit_bottom = limite_camara_abajo

func _physics_process(delta: float) -> void:
	# El personaje decide cómo comportarse según su rol asignado
	match character_role:
		Role.PLAYER:
			_comportamiento_jugador()
		Role.COMPANION:
			_comportamiento_acompanante()
			
	move_and_slide()

func _comportamiento_jugador() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction:
		velocity.x = direction * speed
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

func _comportamiento_acompanante() -> void:
	if target_to_follow:
		var distance = abs(target_to_follow.global_position.x - global_position.x)
		
		if distance > follow_distance:
			var direction = sign(target_to_follow.global_position.x - global_position.x)
			# Se mueve un poco más lento que su objetivo para que parezca que lo sigue
			velocity.x = direction * (speed * 0.9) 
			sprite.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
