# Ascenseur du Temple : il monte d'un étage quand le joueur monte dessus.
# À chaque étage il attend : si le joueur reste dessus, il continue (et redescend une fois en haut).
# Vide, il revient chercher le joueur à son étage (après un respawn par exemple).

extends AnimatableBody3D

@export var stops := PackedFloat32Array([0.97, 8.97, 16.97])
@export var size := Vector3(7.9, 0.5, 6.4)
@export var speed := 2.4
@export var board_delay := 0.6
@export var stop_wait := 2.0
@export var call_delay := 1.2
@export var top_y := 28.0  # poulie

var stop := 0
var target := 0
var dir := 1
var moving := false
var wait_left := 0.0
var call_left := 0.0
var was_on := false
var hum: AudioStreamPlayer
var ropes: Array[MeshInstance3D] = []


func _ready() -> void:
	position.y = stops[0]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = -size.y / 2
	add_child(shape)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.15)
	wood.roughness = 0.85
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.7, 0.5, 0.2)
	bronze.metallic = 0.8
	bronze.roughness = 0.35
	# plancher de planches, cadre de bronze
	var n := 7
	for i in n:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(size.x - 0.4, size.y - 0.05, size.z / n - 0.06)
		pm.material = wood
		plank.mesh = pm
		plank.position = Vector3(0, -size.y / 2 - 0.03, (i + 0.5) / n * size.z - size.z / 2)
		add_child(plank)
	for side in [[Vector3(size.x, 0.25, 0.3), Vector3(0, 0, size.z / 2 - 0.15)], [Vector3(size.x, 0.25, 0.3), Vector3(0, 0, -size.z / 2 + 0.15)],
			[Vector3(0.3, 0.25, size.z), Vector3(size.x / 2 - 0.15, 0, 0)], [Vector3(0.3, 0.25, size.z), Vector3(-size.x / 2 + 0.15, 0, 0)]]:
		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = side[0]
		fm.material = bronze
		frame.mesh = fm
		frame.position = side[1] + Vector3(0, -0.1, 0)
		add_child(frame)
	# cordes jusqu'à la poulie
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.55, 0.45, 0.3)
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.09
	rope_mesh.bottom_radius = 0.09
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 5
	rope_mesh.material = rope_mat
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var rope := MeshInstance3D.new()
		rope.mesh = rope_mesh
		rope.position = Vector3(c.x * (size.x / 2 - 0.3), 0, c.y * (size.z / 2 - 0.3))
		add_child(rope)
		ropes.append(rope)

	hum = AudioStreamPlayer.new()
	hum.stream = Sfx.stream("ascenseur")
	hum.volume_db = -8.0
	hum.finished.connect(func(): if moving: hum.play())
	add_child(hum)
	update_ropes()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var on := player != null and is_on(player)
	if moving:
		var goal := stops[target]
		var y := move_toward(position.y, goal, speed * delta)
		# ne jamais écraser le joueur qui est dessous
		if player and y < position.y and is_below(player):
			y = maxf(y, player.global_position.y + 3.75 + size.y + 0.2)
		position.y = y
		if is_equal_approx(y, goal):
			arrive()
	elif on:
		if not was_on:
			wait_left = board_delay
		wait_left -= delta
		if wait_left <= 0.0:
			go(next_stop())
	else:
		if was_on and stop < stops.size() - 1:
			dir = 1  # descendu à un étage : la prochaine fois on monte (la sortie est en haut)
		call_left -= delta
		var f := floor_of(player) if player else -1
		if call_left <= 0.0 and f >= 0 and f != stop:
			go(f)
	if on or moving:
		call_left = call_delay
	was_on = on
	update_ropes()


func is_on(player: CharacterBody3D) -> bool:
	var p := player.global_position
	var feet := p.y - 3.75
	return absf(p.x - position.x) < size.x / 2 and absf(p.z - position.z) < size.z / 2 and absf(feet - position.y) < 0.7


func is_below(player: CharacterBody3D) -> bool:
	var p := player.global_position
	return absf(p.x - position.x) < size.x / 2 + 1.65 and absf(p.z - position.z) < size.z / 2 + 1.65 and p.y + 3.75 < position.y - size.y + 0.5


# étage où se tient le joueur (-1 en l'air)
func floor_of(player: CharacterBody3D) -> int:
	var feet := player.global_position.y - 3.75
	for i in stops.size():
		if absf(feet - stops[i]) < 1.0:
			return i
	return -1


func next_stop() -> int:
	if stop + dir < 0 or stop + dir >= stops.size():
		dir = -dir
	return stop + dir


func go(i: int) -> void:
	if i == stop:
		return
	target = i
	dir = signi(i - stop)
	moving = true
	hum.play()


func arrive() -> void:
	moving = false
	stop = target
	hum.stop()
	Sfx.play("ascenseur_arret", -2.0)
	wait_left = stop_wait


func update_ropes() -> void:
	var h := top_y - position.y
	for rope in ropes:
		rope.scale.y = h
		rope.position.y = h / 2
