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
@export_group("Manette Arduino")
## Active la manette pour ce joueur (le clavier continue de marcher).
@export var use_manette := true
## Coche si le joystick va à gauche quand tu pousses à droite.
@export var inverser_joy_x := false
## Coche si le joueur va vers le haut de l'écran quand tu tires le joystick vers toi.
@export var inverser_joy_y := false
## Vitesse d'avance quand tu tournes le codeur au maximum.
@export var vitesse_codeur_max := 9.0
## Vitesse de rotation du codeur (tr/min affichés) qui donne la vitesse maximum.
@export var rpm_max := 60.0
## Force de chaque saut déclenché par le bouton du codeur (double saut).
@export var saut_codeur := 15.0
## Saut le plus faible avec le piézo (petit coup).
@export var saut_piezo_min := 10.0
## Saut le plus fort avec le piézo (gros coup).
@export var saut_piezo_max := 26.0

signal respawned

@onready var sprite: DirectionalSprite3D = $Visual/Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var ground_ray: RayCast3D = $GroundRay

# Même valeur que PIEZO_SEUIL (150) de manette.gd, divisée par 1023
const PIEZO_SEUIL_FORCE := 0.15

var spawn: Vector3
var prefix: String
var push := Vector3.ZERO  # poussée extérieure (vent), remise à zéro chaque frame
var slow_left := 0.0
var invincible := 0.0
var step_timer := 0.0
var in_water := 0  # nombre de zones d'eau peu profonde où se trouve le joueur
var was_on_floor := true

# état de la manette
var _cap := Vector3.ZERO            # direction "tout droit" pour le codeur
var _veut_saut_joystick := false
var _veut_saut_codeur := false
var _force_piezo := -1.0            # -1 = pas de coup en attente
var _sauts_auto := 0                # 2e saut du codeur en attente


func _ready() -> void:
	add_to_group("player")
	spawn = global_position
	prefix = "p%d_" % player_id
	if appearance_folder != "":
		sprite.sprites_folder = appearance_folder
	if use_manette:
		Manette.joy_btn_pressed.connect(_on_joy_btn)
		Manette.enc_btn_pressed.connect(_on_enc_btn)
		Manette.piezo_hit.connect(_on_piezo)


# ces fonctions notent juste la demande, elle est traitée dans _physics_process
func _on_joy_btn() -> void:
	_veut_saut_joystick = true


func _on_enc_btn() -> void:
	_veut_saut_codeur = true


func _on_piezo(force: float) -> void:
	_force_piezo = force


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
	else:
		_sauts_auto = 0

	if is_on_floor():
		if Input.is_action_just_pressed(prefix + "jump") or _veut_saut_joystick:
			velocity.y = JUMP_VELOCITY
			Sfx.play("saut", -6.0)
		elif _veut_saut_codeur:
			# bouton du codeur : 1er saut, le 2e suivra au sommet
			velocity.y = saut_codeur
			_sauts_auto = 1
			Sfx.play("saut", -6.0)
		elif _force_piezo >= 0.0:
			# piézo : plus le coup est fort, plus le saut est haut
			var t := clampf(inverse_lerp(PIEZO_SEUIL_FORCE, 1.0, _force_piezo), 0.0, 1.0)
			velocity.y = lerpf(saut_piezo_min, saut_piezo_max, t)
			Sfx.play("saut", -6.0)
	# les demandes non utilisées (en l'air) sont jetées
	_veut_saut_joystick = false
	_veut_saut_codeur = false
	_force_piezo = -1.0

	# 2e saut du codeur : quand le joueur arrive en haut et commence à redescendre
	if _sauts_auto > 0 and not is_on_floor() and velocity.y <= 0.0:
		velocity.y = saut_codeur
		_sauts_auto -= 1

	# on tourne l'input avec la caméra pour que "haut" = haut de l'écran
	var input_dir := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var vitesse_codeur := 0.0
	if use_manette:
		# le joystick s'ajoute au clavier
		var joy: Vector2 = Manette.joy
		if inverser_joy_x:
			joy.x = -joy.x
		if inverser_joy_y:
			joy.y = -joy.y
		input_dir = (input_dir + joy).limit_length(1.0)
		# plus on tourne le codeur vite, plus on avance vite
		vitesse_codeur = clampf(absf(Manette.enc_rpm) / rpm_max, 0.0, 1.0) * vitesse_codeur_max
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam else 0.0
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)
	# "tout droit" = dernière direction prise, ou le haut de l'écran au début
	if _cap == Vector3.ZERO:
		_cap = Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	if direction.length() > 0.1:
		_cap = direction.normalized()
	var speed_now: float = SPEED * (slow_factor if slow_left > 0.0 else 1.0) * (water_factor if in_water > 0 else 1.0)
	slow_left -= delta
	sprite.modulate = Color(0.8, 0.78, 0.6) if slow_left > 0.0 else Color.WHITE
	var codeur_now: float = vitesse_codeur * speed_now / SPEED
	var target := direction * speed_now + _cap * codeur_now + push
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	push = Vector3.ZERO

	move_and_slide()

	if is_on_floor() and not was_on_floor:
		Sfx.play("atterrissage", -8.0)
	was_on_floor = is_on_floor()

	if direction.length() > 0.1:
		sprite.facing = direction.normalized()
	elif vitesse_codeur > 0.5:
		sprite.facing = _cap
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
	if is_on_floor() and (direction.length() > 0.1 or vitesse_codeur > 0.5) and step_timer <= 0.0:
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
