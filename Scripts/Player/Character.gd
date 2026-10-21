# Character.gd — joueur en vue à la 3e personne (caméra derrière, façon Mario)
# L'animation du personnage est gérée par directional_sprite.gd (nœud Visual/Sprite).
# Déplacements relatifs à la caméra : « avancer » = aller là où regarde la caméra.
# Caméra : souris ou joystick droit. Échap libère la souris, un clic la reprend.

extends CharacterBody3D

@export_group("Déplacement")
@export var SPEED = 7.0
@export var JUMP_VELOCITY = 7.0
## Vitesse à laquelle le joueur atteint sa vitesse max (plus grand = plus nerveux)
@export var acceleration := 50.0
## Au-dessus de cette vitesse, on joue l'animation de course au lieu de la marche
@export var run_speed := 6.0
## En dessous de cette hauteur, le joueur réapparaît à son point de départ
@export var fall_limit_y := -20.0

@export_group("Caméra")
@export var mouse_sensitivity := 0.003
@export var stick_sensitivity := 3.0
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 10.0

@onready var sprite: DirectionalSprite3D = $Visual/Sprite
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var _spawn_position: Vector3


func _ready() -> void:
	_spawn_position = global_position
	spring_arm.add_excluded_object(get_rid())  # la caméra ne se cogne pas contre le joueur
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rotate_camera(yaw: float, pitch: float) -> void:
	camera_pivot.rotation.y += yaw
	spring_arm.rotation.x = clamp(spring_arm.rotation.x + pitch,
		deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func _physics_process(delta: float) -> void:
	# Caméra au joystick droit
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look:
		_rotate_camera(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)

	# Gravité
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Saut
	if Input.is_action_just_pressed("ui_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Déplacement relatif à l'orientation de la caméra
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, camera_pivot.rotation.y)
	velocity.x = move_toward(velocity.x, direction.x * SPEED, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, acceleration * delta)

	move_and_slide()

	# Animation du personnage : direction regardée et action en cours
	if direction.length() > 0.1:
		sprite.facing = direction.normalized()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		sprite.animation = "jump"
	elif horizontal_speed > run_speed:
		sprite.animation = "run"
	elif horizontal_speed > 0.5:
		sprite.animation = "walk"
	else:
		sprite.animation = "idle"

	# Chute dans le vide : retour au point de départ
	if global_position.y < fall_limit_y:
		global_position = _spawn_position
		velocity = Vector3.ZERO
