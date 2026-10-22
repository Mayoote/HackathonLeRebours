# Meule de foin déplacée par le piégeur : bloque le passage, plus lente que le joueur.
# Sert à faire comprendre au piégeur qu'il peut bouger des objets (rocher de la grotte).

extends CharacterBody3D

@export var speed := 6.0
@export var acceleration := 20.0

@onready var visual: Node3D = $Visual

var input := Vector2.ZERO  # réglé par le piégeur
var sound: AudioStreamPlayer
var was_blocked := false


func _ready() -> void:
	sound = AudioStreamPlayer.new()
	sound.stream = Sfx.stream("meule_glisse")
	sound.bus = Sfx.BUS
	sound.volume_db = -40
	add_child(sound)
	sound.play()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * 3.0 * delta

	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	velocity.x = move_toward(velocity.x, dir.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, acceleration * delta)
	var before := Vector2(velocity.x, velocity.z).length()
	move_and_slide()

	var moving := Vector2(velocity.x, velocity.z)
	# elle roule dans le sens où elle avance
	if moving.length() > 0.1:
		visual.rotation.y = atan2(moving.x, moving.y)
		visual.get_child(0).rotate_x(moving.length() * delta / 2.0)
	sound.volume_db = lerpf(-40.0, -6.0, clampf(moving.length() / speed, 0.0, 1.0))

	var blocked := get_slide_collision_count() > 0 and before > speed * 0.6 and moving.length() < before * 0.5
	if blocked and not was_blocked:
		Sfx.play("meule_choc", -6.0)
	was_blocked = blocked
