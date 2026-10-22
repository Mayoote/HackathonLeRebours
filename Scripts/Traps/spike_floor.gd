# Pics qui sortent du sol. Deux modes :
#  - automatic : à intervalle régulier, tout seuls ; plusieurs bandes avec des phases décalées font une vague
#  - sinon : quand le piégeur appelle trigger(), puis temps de recharge
# Juste avant, ils pointent le bout du nez avec un cliquetis : on a le temps de s'écarter.

extends Node3D

@export var size := Vector2(4, 9)
@export var automatic := true
@export var cooldown := 3.0  # mode manuel
@export var period := 3.0
@export var up_time := 1.1
@export var warning_time := 0.5
@export_range(0, 1) var phase := 0.0
@export var spacing := 1.1
@export var sound_distance := 20.0

const HIDDEN := -1.7
const PEEK := -1.0

var spikes: Node3D
var plate_mat: StandardMaterial3D
var state := 0  # 0 rentrés, 1 alerte, 2 sortis
var time := 0.0
var cooldown_left := 0.0


func _ready() -> void:
	plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.3, 0.26, 0.22)
	plate_mat.metallic = 0.5
	plate_mat.roughness = 0.6
	plate_mat.emission_enabled = true
	plate_mat.emission = Color(1, 0.35, 0.1)
	plate_mat.emission_energy_multiplier = 0.0
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.08, size.y)
	box.material = plate_mat
	plate.mesh = box
	plate.position.y = 0.04
	add_child(plate)

	# trous dans la plaque, puis les pointes (MultiMesh)
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color(0.05, 0.04, 0.03)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.22
	hole.bottom_radius = 0.22
	hole.height = 0.02
	hole.material = hole_mat
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.3
	spike.height = 1.5
	spike.radial_segments = 6
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.72, 0.75)
	steel.metallic = 0.85
	steel.roughness = 0.3
	spike.material = steel
	var points: Array[Vector3] = []
	var nx := maxi(int(size.x / spacing), 1)
	var nz := maxi(int(size.y / spacing), 1)
	for i in nx:
		for j in nz:
			points.append(Vector3((i + 0.5) / nx * size.x - size.x / 2, 0, (j + 0.5) / nz * size.y - size.y / 2))
	spikes = Node3D.new()
	spikes.position.y = HIDDEN
	add_child(spikes)
	for pair in [[hole, self, 0.09], [spike, spikes, 0.75]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		mm.instance_count = points.size()
		for k in points.size():
			mm.set_instance_transform(k, Transform3D(Basis(), points[k] + Vector3.UP * pair[2]))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		pair[1].add_child(inst)


func _physics_process(delta: float) -> void:
	time += delta
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if automatic:
		var t := fmod(time + phase * period, period)
		set_state(1 if t < warning_time else (2 if t < warning_time + up_time else 0))
	if state == 2:
		hit()


func is_ready() -> bool:
	return state == 0 and cooldown_left <= 0.0


# mode manuel : alerte, sortie, puis on rentre et on recharge
func trigger() -> void:
	if not is_ready():
		Sfx.play("refus", -6.0)
		return
	set_state(1)
	await get_tree().create_timer(warning_time, false, true).timeout
	set_state(2)
	await get_tree().create_timer(up_time, false, true).timeout
	set_state(0)
	cooldown_left = cooldown


func set_state(new_state: int) -> void:
	if new_state == state:
		return
	state = new_state
	match state:
		1:
			create_tween().tween_property(spikes, "position:y", PEEK, 0.1)
			plate_mat.emission_energy_multiplier = 0.8
			sound("mecanisme", -8.0)
		2:
			create_tween().tween_property(spikes, "position:y", 0.0, 0.06)
			plate_mat.emission_energy_multiplier = 0.0
			sound("pics_sortent", 0.0)
		0:
			create_tween().tween_property(spikes, "position:y", HIDDEN, 0.3)
			sound("pics_rentrent", -8.0)


func sound(nom: String, volume: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or absf(player.global_position.y - 3.75 - global_position.y) > 4.0:
		return
	var d := player.global_position.distance_to(global_position)
	if d < sound_distance:
		Sfx.play(nom, volume + lerpf(0.0, -20.0, d / sound_distance), randf_range(0.95, 1.05))


func hit() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var p := player.global_position - global_position
	var feet := p.y - 3.75
	if absf(p.x) < size.x / 2 + 0.6 and absf(p.z) < size.y / 2 + 0.6 and feet > -0.5 and feet < 1.4:
		player.kill()
