# Meurtrières dans la cage de l'ascenseur : le piégeur tire une volée de flèches
# dans la colonne où se trouve le joueur. La meurtrière rougeoie avant le tir : il faut changer de colonne.

extends Node3D

@export var lanes := PackedFloat32Array([14.6, 17.25, 19.9])
@export var wall_z := 3.0
@export var end_z := 20.0
@export var zone := Rect2(13, 3, 8.5, 7)   # la cage : le joueur doit y être
@export var warning_time := 0.6
@export var arrow_speed := 32.0
@export var cooldown := 3.0

var cooldown_left := 0.0
var slit: MeshInstance3D
var wood: StandardMaterial3D
var iron: StandardMaterial3D


func _ready() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.2, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.15, 0.05)
	glow.emission_energy_multiplier = 3.0
	slit = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.35, 0.12)
	box.material = glow
	slit.mesh = box
	slit.visible = false
	add_child(slit)
	wood = StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.16)
	iron = StandardMaterial3D.new()
	iron.albedo_color = Color(0.3, 0.3, 0.32)
	iron.metallic = 0.8


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func trigger() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or cooldown_left > 0.0 or not zone.grow(0.5).has_point(Vector2(player.global_position.x, player.global_position.z)):
		Sfx.play("refus", -6.0)
		return
	cooldown_left = cooldown
	var lane := lanes[0]
	for l in lanes:
		if absf(l - player.global_position.x) < absf(lane - player.global_position.x):
			lane = l
	volley(lane)


func volley(lane: float) -> void:
	# la meurtrière suit le joueur qui monte, puis tire à sa hauteur
	Sfx.play("mecanisme")
	slit.visible = true
	var t := 0.0
	var y := 0.0
	while t < warning_time:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			y = player.global_position.y - 3.75 + 2.6
		slit.position = Vector3(lane, y, wall_z + 0.07)
		slit.visible = int(t * 14) % 2 == 0
		await get_tree().process_frame
		t += get_process_delta_time()
	slit.visible = false
	Sfx.play("fleche_tir")
	for offset in [Vector2(-0.7, 0.0), Vector2(0.0, 0.8), Vector2(0.7, 0.0)]:
		shoot(Vector3(lane + offset.x, y + offset.y, wall_z + 0.5))


func shoot(start: Vector3) -> void:
	var arrow := Node3D.new()
	var shaft := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.1, 0.1, 1.8)
	sm.material = wood
	shaft.mesh = sm
	arrow.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.3, 0.4, 0.1)
	tm.material = iron
	tip.mesh = tm
	tip.rotation.x = PI / 2
	tip.position.z = 1.0
	arrow.add_child(tip)
	add_child(arrow)
	arrow.position = start
	while arrow.position.z < end_z:
		arrow.position.z += arrow_speed * get_process_delta_time()
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			var p := player.global_position
			if absf(p.x - arrow.position.x) < 1.8 and absf(p.z - arrow.position.z) < 1.0 and arrow.position.y > p.y - 3.75 and arrow.position.y < p.y + 3.75:
				Sfx.play("fleche_impact")
				player.kill()
				break
		await get_tree().process_frame
	arrow.queue_free()
