# Grosse boule qui roule toute seule derrière le joueur dans le couloir final.
# Elle se réveille quand le joueur dépasse trigger_x et roule moins vite que lui :
# il s'en sort s'il ne traîne pas devant les pièges. Elle passe par-dessus les trous.

extends Node3D

@export var trigger_x := 24.0
@export var start_x := -2.0
@export var end_x := 205.0
@export var speed := 7.5
@export var radius := 4.0
@export var floor_y := 0.97

var active := false
var stopped := false
var ground := 0.0
var ball: Node3D
var roll: AudioStreamPlayer


func _ready() -> void:
	ground = floor_y
	ball = Node3D.new()
	add_child(ball)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.05
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.22, 0.2, 0.19), Color(0.42, 0.39, 0.36), Color(0.5, 0.47, 0.43)])
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.seamless = true
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = tex
	rock.roughness = 0.95
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.material = rock
	sphere.mesh = mesh
	ball.add_child(sphere)
	# bandes sculptées pour bien voir la boule tourner
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.3, 0.27, 0.24)
	for angle in [0.0, PI / 2]:
		var band := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.15
		torus.outer_radius = radius + 0.12
		torus.material = band_mat
		band.mesh = torus
		band.rotation = Vector3(PI / 2, angle, 0)
		ball.add_child(band)
	roll = AudioStreamPlayer.new()
	roll.stream = Sfx.stream("rocher_roule")
	roll.bus = Sfx.BUS
	roll.volume_db = -40.0
	roll.finished.connect(func(): if active: roll.play())
	add_child(roll)
	reset()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.respawned.connect(reset)


func reset() -> void:
	active = false
	stopped = false
	visible = false
	ground = floor_y
	position = Vector3(start_x, floor_y + radius, 0)
	ball.rotation = Vector3.ZERO
	roll.stop()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if not active:
		if not stopped and player.global_position.x > trigger_x:
			release()
		return

	position.x = minf(position.x + speed * delta, end_x)
	ball.rotation.z -= speed * delta / radius
	# elle suit le sol (et monte sur les blocs) mais passe par-dessus les trous
	var hit := ground_below()
	if hit > floor_y - 1.0:
		ground = hit
	position.y = move_toward(position.y, ground + radius, 10.0 * delta)
	var d := absf(player.global_position.x - position.x)
	roll.volume_db = lerpf(0.0, -24.0, clampf(d / 40.0, 0.0, 1.0))

	var feet := player.global_position.y - 3.75
	if d < radius + 1.4 and feet < position.y + radius - 0.8:
		player.kill()
	if position.x >= end_x:
		crash()


func release() -> void:
	active = true
	visible = true
	Sfx.play("rocher_chute")
	roll.play()
	var rules := get_tree().get_first_node_in_group("level_rules")
	if rules:
		rules.show_message("La boule arrive ! Cours !")


# arrivée au bout : elle s'écrase contre le mur et reste là
func crash() -> void:
	active = false
	stopped = true
	roll.stop()
	Sfx.play("meule_choc")


func ground_below() -> float:
	var from := Vector3(position.x, 30, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40)
	var space := get_world_3d().direct_space_state
	var ignore: Array[RID] = []
	var hit := space.intersect_ray(q)
	while hit and hit.collider is CharacterBody3D:
		ignore.append(hit.rid)
		q.exclude = ignore
		hit = space.intersect_ray(q)
	return hit.position.y if hit else -100.0
