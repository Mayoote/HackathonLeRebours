extends CharacterBody3D

@export_range(1, 2) var player_id := 1
@export_dir var appearance_folder := ""

@export var SPEED = 7.0
@export var JUMP_VELOCITY = 17.0
@export var gravity_scale := 4.0
@export var acceleration := 50.0
@export var run_speed := 6.0
@export var fall_limit_y := -20.0

@export var max_lives := 3
@export var invincible_time := 1.5
@export var knockback := 14.0

signal lives_changed(lives: int)
signal died

@onready var sprite: DirectionalSprite3D = $Visual/Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var ground_ray: RayCast3D = $GroundRay

var lives: int
var invincible := 0.0
var spawn: Vector3
var prefix: String


func _ready() -> void:
	add_to_group("player")
	lives = max_lives
	spawn = global_position
	prefix = "p%d_" % player_id
	if appearance_folder != "":
		sprite.sprites_folder = appearance_folder


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta

	if Input.is_action_just_pressed(prefix + "jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# on tourne l'input avec la caméra pour que "haut" = haut de l'écran
	var input_dir := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam else 0.0
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
	velocity.x = move_toward(velocity.x, direction.x * SPEED, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, acceleration * delta)

	move_and_slide()

	if direction.length() > 0.1:
		sprite.facing = direction.normalized()
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		sprite.animation = "jump"
	elif speed > run_speed:
		sprite.animation = "run"
	elif speed > 0.5:
		sprite.animation = "walk"
	else:
		sprite.animation = "idle"

	update_shadow()

	if invincible > 0.0:
		invincible -= delta
		sprite.visible = invincible <= 0.0 or int(invincible * 12) % 2 == 0

	if global_position.y < fall_limit_y:
		global_position = spawn
		velocity = Vector3.ZERO
		lose_life()


# ombre collée au sol sous le perso, plus petite quand il est haut
func update_shadow() -> void:
	shadow.visible = ground_ray.is_colliding()
	if not shadow.visible:
		return
	var ground := ground_ray.get_collision_point()
	shadow.global_position = ground + Vector3.UP * 0.15
	var height := global_position.y - ground.y
	var s := clampf(1.0 - (height - 3.75) / 12.0, 0.5, 1.0)
	shadow.scale = Vector3(s, 1, s)


func take_hit(from: Vector3) -> void:
	if invincible > 0.0 or lives <= 0:
		return
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	velocity = away * knockback + Vector3.UP * JUMP_VELOCITY * 0.6
	lose_life()


func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		died.emit()
		set_physics_process(false)
	else:
		invincible = invincible_time
