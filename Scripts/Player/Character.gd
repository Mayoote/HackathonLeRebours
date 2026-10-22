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

# --- NOUVEAU : réglages de la manette Arduino (modifiables dans l'Inspecteur) ---
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

signal lives_changed(lives: int)
signal died

@onready var sprite: DirectionalSprite3D = $Visual/Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var ground_ray: RayCast3D = $GroundRay

# Même valeur que PIEZO_SEUIL (150) de manette.gd, divisée par 1023
const PIEZO_SEUIL_FORCE := 0.15

var lives: int
var invincible := 0.0
var spawn: Vector3
var prefix: String

# NOUVEAU : état de la manette
var _cap := Vector3.ZERO            # direction "tout droit" pour le codeur
var _veut_saut_joystick := false
var _veut_saut_codeur := false
var _force_piezo := -1.0            # -1 = pas de coup en attente
var _sauts_auto := 0                # 2e saut du codeur en attente


func _ready() -> void:
	add_to_group("player")
	lives = max_lives
	spawn = global_position
	prefix = "p%d_" % player_id
	if appearance_folder != "":
		sprite.sprites_folder = appearance_folder
	# NOUVEAU : on branche les signaux de l'autoload Manette
	if use_manette:
		Manette.joy_btn_pressed.connect(_on_joy_btn)
		Manette.enc_btn_pressed.connect(_on_enc_btn)
		Manette.piezo_hit.connect(_on_piezo)


# NOUVEAU : ces fonctions notent juste la demande, elle est traitée dans _physics_process
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

	# --- Sauts ---
	if is_on_floor():
		if Input.is_action_just_pressed(prefix + "jump") or _veut_saut_joystick:
			# clavier ou bouton du joystick : saut normal
			velocity.y = JUMP_VELOCITY
		elif _veut_saut_codeur:
			# bouton du codeur : 1er saut, le 2e suivra au sommet
			velocity.y = saut_codeur
			_sauts_auto = 1
		elif _force_piezo >= 0.0:
			# piézo : plus le coup est fort, plus le saut est haut
			var t := clampf(inverse_lerp(PIEZO_SEUIL_FORCE, 1.0, _force_piezo), 0.0, 1.0)
			velocity.y = lerpf(saut_piezo_min, saut_piezo_max, t)
	# Les demandes non utilisées (en l'air) sont jetées
	_veut_saut_joystick = false
	_veut_saut_codeur = false
	_force_piezo = -1.0

	# 2e saut du codeur : quand le joueur arrive en haut et commence à redescendre
	if _sauts_auto > 0 and not is_on_floor() and velocity.y <= 0.0:
		velocity.y = saut_codeur
		_sauts_auto -= 1

	# --- Déplacement ---
	# on tourne l'input avec la caméra pour que "haut" = haut de l'écran
	var input_dir := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var vitesse_codeur := 0.0
	if use_manette:
		# NOUVEAU : le joystick s'ajoute au clavier
		var joy: Vector2 = Manette.joy
		if inverser_joy_x:
			joy.x = -joy.x
		if inverser_joy_y:
			joy.y = -joy.y
		input_dir = (input_dir + joy).limit_length(1.0)
		# NOUVEAU : plus on tourne le codeur vite, plus on avance vite
		vitesse_codeur = clampf(absf(Manette.enc_rpm) / rpm_max, 0.0, 1.0) * vitesse_codeur_max

	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam else 0.0
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, yaw)

	# NOUVEAU : "tout droit" = dernière direction prise, ou le haut de l'écran au début
	if _cap == Vector3.ZERO:
		_cap = Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	if direction.length() > 0.1:
		_cap = direction.normalized()

	var cible: Vector3 = direction * SPEED + _cap * vitesse_codeur
	velocity.x = move_toward(velocity.x, cible.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, cible.z, acceleration * delta)

	move_and_slide()

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
