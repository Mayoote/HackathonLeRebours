# Rocher sur une corniche, poussé par le piégeur (joystick).
# S'il tombe sur le joueur, il l'écrase. Ensuite il se brise et revient sur la corniche.

extends CharacterBody3D

@export var speed := 5.0
@export var acceleration := 20.0
@export var cooldown := 6.0

@onready var visual: Node3D = $Visual

var input := Vector2.ZERO
var start: Vector3
var cooldown_left := 0.0
var fallen := false
var roll_sound: AudioStreamPlayer


func _ready() -> void:
	start = global_position
	roll_sound = AudioStreamPlayer.new()
	roll_sound.stream = Sfx.stream("rocher_roule")
	roll_sound.volume_db = -40
	add_child(roll_sound)
	roll_sound.play()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if not visible:
		return
	if not is_on_floor():
		velocity += get_gravity() * 3.0 * delta

	if not fallen:
		var cam := get_viewport().get_camera_3d()
		var yaw := cam.global_rotation.y if cam else 0.0
		var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
		velocity.x = move_toward(velocity.x, dir.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, acceleration * delta)

	var falling := velocity.y < -3.0
	move_and_slide()

	var moving := Vector2(velocity.x, velocity.z)
	if moving.length() > 0.1:
		visual.rotate(Vector3(moving.y, 0, -moving.x).normalized(), moving.length() * delta / 1.8)
	roll_sound.volume_db = lerpf(-40.0, -4.0, clampf(moving.length() / speed, 0.0, 1.0)) if not fallen else -40.0

	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if falling and other and other.has_method("kill"):
			other.kill()

	# tombé de la corniche : il s'écrase en bas, puis revient
	if not fallen and global_position.y < start.y - 2.5:
		fallen = true
		velocity.x *= 0.3
		velocity.z *= 0.3
	if fallen and is_on_floor():
		land()


func land() -> void:
	set_physics_process(false)
	Sfx.play("rocher_chute")
	await get_tree().create_timer(1.2).timeout
	await create_tween().tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.2).finished
	visible = false
	global_position = start
	velocity = Vector3.ZERO
	cooldown_left = cooldown
	await get_tree().create_timer(cooldown).timeout
	visual.scale = Vector3.ONE
	visible = true
	fallen = false
	set_physics_process(true)
