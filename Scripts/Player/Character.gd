extends CharacterBody3D

@export_range(1, 2) var player_id := 1
@export_dir var appearance_folder := ""

@export var SPEED = 7.0
@export var JUMP_VELOCITY = 17.0
@export var gravity_scale := 4.0
@export var acceleration := 50.0
@export var run_speed := 6.0
@export var fall_limit_y := -20.0
@export var slow_factor := 0.45
@export var water_factor := 0.6

# réglages de la manette Arduino (modifiables dans l'Inspecteur)
# Le joueur n'utilise que le joystick 1 : on le bouge pour marcher, on l'enfonce pour sauter.
# Le joystick 2, le codeur et le piézo sont au piégeur (voir trapper.gd).
@export_group("Manette Arduino")
## Active la manette pour ce joueur (le clavier continue de marcher).
@export var use_manette := true
## Coche si le joystick va à gauche quand tu pousses à droite.
@export var inverser_joy_x := false
## Coche si le joueur va vers le haut de l'écran quand tu tires le joystick vers toi.
@export var inverser_joy_y := false

signal respawned

@onready var sprite: DirectionalSprite3D = $Visual/Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var ground_ray: RayCast3D = $GroundRay

var spawn: Vector3
var prefix: String
var push := Vector3.ZERO  # poussée extérieure (vent), remise à zéro chaque frame
var slow_left := 0.0
var invincible := 0.0
var step_timer := 0.0
var in_water := 0  # nombre de zones d'eau peu profonde où se trouve le joueur
var was_on_floor := true

# état de la manette
var _veut_saut_joystick := false


func _ready() -> void:
	add_to_group("player")
	spawn = global_position
	prefix = "p%d_" % player_id
	if appearance_folder != "":
		sprite.sprites_folder = appearance_folder
	if use_manette:
		Manette.joy_btn_pressed.connect(_on_joy_btn)


# on note juste la demande, elle est traitée dans _physics_process
func _on_joy_btn() -> void:
	_veut_saut_joystick = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta

	if is_on_floor() and (Input.is_action_just_pressed(prefix + "jump") or _veut_saut_joystick):
		velocity.y = JUMP_VELOCITY
		Sfx.play("saut", -6.0)
	# un appui en l'air est jeté
	_veut_saut_joystick = false

	# on tourne l'input avec la caméra pour que "haut" = haut de l'écran
	var input_dir := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	if use_manette:
		# le joystick 1 s'ajoute au clavier
		var joy: Vector2 = Manette.joy
		if inverser_joy_x:
			joy.x = -joy.x
		if inverser_joy_y:
			joy.y = -joy.y
		input_dir = (input_dir + joy).limit_length(1.0)
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam else 0.0
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
	var speed_now: float = SPEED * (slow_factor if slow_left > 0.0 else 1.0) * (water_factor if in_water > 0 else 1.0)
	slow_left -= delta
	sprite.modulate = Color(0.8, 0.78, 0.6) if slow_left > 0.0 else Color.WHITE
	var target := direction * speed_now + push
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	push = Vector3.ZERO

	move_and_slide()

	if is_on_floor() and not was_on_floor:
		Sfx.play("atterrissage", -8.0)
	was_on_floor = is_on_floor()

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

	step_timer -= delta
	if is_on_floor() and direction.length() > 0.1 and step_timer <= 0.0:
		step_timer = 0.28 if speed > run_speed else 0.4
		if in_water > 0:
			Sfx.play("pas_eau", -10.0, randf_range(0.85, 1.15))
		else:
			Sfx.play("pas_herbe_%d" % randi_range(1, 2), -16.0, randf_range(0.9, 1.1))

	update_shadow()

	if invincible > 0.0:
		invincible -= delta
		sprite.visible = invincible <= 0.0 or int(invincible * 12) % 2 == 0

	if global_position.y < fall_limit_y:
		respawn()


# ombre au sol pendant les sauts, plus petite quand il est haut
func update_shadow() -> void:
	shadow.visible = ground_ray.is_colliding() and not is_on_floor()
	if not shadow.visible:
		return
	var ground := ground_ray.get_collision_point()
	# le bas du sprite c'est le bout du pied, pas l'appui : on recule un peu l'ombre
	# (et on la monte pour qu'elle passe au-dessus des dalles du chemin)
	var back := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam:
		back = Vector3(-cam.global_basis.z.x, 0, -cam.global_basis.z.z).normalized()
	shadow.global_position = ground + Vector3.UP * 0.55 + back * 0.7
	var height := global_position.y - ground.y
	var s := clampf(1.0 - (height - 3.75) / 12.0, 0.5, 1.0)
	shadow.scale = Vector3(s, 1, s)


# écrasé, tombé dans le vide... : retour au début du niveau
func kill() -> void:
	if invincible > 0.0:
		return
	respawn()


func respawn() -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	slow_left = 0.0
	invincible = 1.0
	Sfx.play("respawn", -4.0)
	respawned.emit()


func slow_down(seconds: float) -> void:
	slow_left = maxf(slow_left, seconds)
