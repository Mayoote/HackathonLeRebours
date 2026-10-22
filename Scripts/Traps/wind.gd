# Vent contrôlé par le piégeur (encodeur) : pousse le joueur le long de l'axe X
# strength va de -1 (vers la gauche du niveau) à 1 (vers la droite)

extends Node3D

@export var max_push := 6.5  # < vitesse du joueur : il peut toujours avancer contre le vent
@export var area_size := Vector3(70, 10, 42)

var strength := 0.0
var particles: CPUParticles3D
var sound: AudioStreamPlayer
var streak_mat: StandardMaterial3D


func _ready() -> void:
	particles = CPUParticles3D.new()
	# traînées alignées sur l'axe du vent (X)
	var streak := BoxMesh.new()
	streak.size = Vector3(3.0, 0.1, 0.1)
	var mat := StandardMaterial3D.new()
	streak_mat = mat
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.55)
	streak.material = mat
	particles.mesh = streak
	particles.amount = 120
	particles.lifetime = 1.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = area_size / 2
	particles.gravity = Vector3.ZERO
	particles.spread = 4.0
	particles.emitting = false
	add_child(particles)

	sound = AudioStreamPlayer.new()
	sound.stream = Sfx.stream("vent")
	sound.bus = Sfx.BUS
	sound.volume_db = -40
	add_child(sound)
	sound.play()


func add(amount: float) -> void:
	strength = clampf(strength + amount, -1.0, 1.0)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and absf(strength) > 0.03:
		player.push += Vector3(strength * max_push, 0, 0)

	var force := absf(strength)
	particles.emitting = force > 0.05
	streak_mat.albedo_color.a = 0.2 + force * 0.5
	particles.direction = Vector3(signf(strength), 0, 0)
	particles.initial_velocity_min = 18.0 + force * 18.0
	particles.initial_velocity_max = 24.0 + force * 22.0
	sound.volume_db = lerpf(-40.0, -3.0, force)
	sound.pitch_scale = 0.8 + force * 0.4
