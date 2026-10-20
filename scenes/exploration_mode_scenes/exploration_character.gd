extends CharacterBody2D

enum Role { PLAYER, COMPANION }

@export var character_role: Role = Role.PLAYER
@export var character_texture: Texture2D
@export var animation_frames: SpriteFrames
@export var target_to_follow: Node2D
@export var speed: float = 300.0
@export var follow_distance: float = 100.0
@export var altura_deseada: float = 150.0
@export var limite_camara_derecha: int = 2500
@export var limite_camara_abajo: int = 1080

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camara: Camera2D = $Camera2D

func _ready() -> void:
	if animation_frames:
		animated_sprite.sprite_frames = animation_frames
		animated_sprite.play("idle")
		_scale_sprite_to_height(altura_deseada)
	elif character_texture:
		var frames: SpriteFrames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.add_frame("idle", character_texture, 1.0)
		frames.add_animation("walk")
		frames.set_animation_loop("walk", true)
		frames.add_frame("walk", character_texture, 1.0)
		animated_sprite.sprite_frames = frames
		animated_sprite.play("idle")
		_scale_sprite_to_height(altura_deseada)

	if character_role == Role.PLAYER:
		camara.make_current()
		camara.limit_right = limite_camara_derecha
		camara.limit_left = 0
		camara.limit_bottom = limite_camara_abajo

func _scale_sprite_to_height(target_height: float) -> void:
	if not animated_sprite.sprite_frames:
		return
	var texture: Texture2D = animated_sprite.sprite_frames.get_frame_texture("idle", 0)
	if texture and texture.get_height() > 0:
		var factor: float = target_height / float(texture.get_height())
		animated_sprite.scale = Vector2(factor, factor)

func _physics_process(_delta: float) -> void:
	match character_role:
		Role.PLAYER:
			_comportamiento_jugador()
		Role.COMPANION:
			_comportamiento_acompanante()
	move_and_slide()

func _comportamiento_jugador() -> void:
	var direction: float = Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = direction * speed
		animated_sprite.flip_h = direction < 0.0
		_play_anim("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		_play_anim("idle")

func _comportamiento_acompanante() -> void:
	if target_to_follow:
		var distance: float = abs(target_to_follow.global_position.x - global_position.x)
		if distance > follow_distance:
			var diff: float = target_to_follow.global_position.x - global_position.x
			var direction: float = 1.0 if diff > 0.0 else -1.0
			velocity.x = direction * (speed * 0.9)
			animated_sprite.flip_h = direction < 0.0
			_play_anim("walk")
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			_play_anim("idle")
	else:
		_play_anim("idle")

func _play_anim(anim_name: String) -> void:
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
