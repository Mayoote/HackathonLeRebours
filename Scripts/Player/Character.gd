# Character.gd — un joueur en vue isométrique (caméra fixe partagée par les deux joueurs)
# Les déplacements suivent l'écran : « haut » = vers le haut de l'écran, quelle que soit
# l'orientation de la caméra du niveau.
# Touches : actions p1_* pour le joueur 1, p2_* pour le joueur 2 (Projet > Paramètres > Contrôles).
# L'animation du personnage est gérée par directional_sprite.gd (nœud Visual/Sprite).

extends CharacterBody3D

## 1 = joueur 1 (ZQSD + Espace), 2 = joueur 2 (flèches + Entrée)
@export_range(1, 2) var player_id := 1
## Dossier des sprites de ce joueur (vide = celui réglé sur Visual/Sprite)
@export_dir var appearance_folder := ""

@export_group("Déplacement")
@export var SPEED = 7.0
@export var JUMP_VELOCITY = 10.0
## Vitesse à laquelle le joueur atteint sa vitesse max (plus grand = plus nerveux)
@export var acceleration := 50.0
## Au-dessus de cette vitesse, on joue l'animation de course au lieu de la marche
@export var run_speed := 6.0
## En dessous de cette hauteur, le joueur réapparaît à son point de départ
@export var fall_limit_y := -20.0

@onready var sprite: DirectionalSprite3D = $Visual/Sprite

var _spawn_position: Vector3
var _prefix: String


func _ready() -> void:
	_spawn_position = global_position
	_prefix = "p%d_" % player_id
	if appearance_folder != "":
		sprite.sprites_folder = appearance_folder


func _physics_process(delta: float) -> void:
	# Gravité
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Saut
	if Input.is_action_just_pressed(_prefix + "jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Déplacement relatif à l'écran (on tourne l'entrée selon l'orientation de la caméra)
	var input_dir := Input.get_vector(_prefix + "left", _prefix + "right", _prefix + "up", _prefix + "down")
	var camera := get_viewport().get_camera_3d()
	var camera_yaw := camera.global_rotation.y if camera else 0.0
	var direction := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, camera_yaw)
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
