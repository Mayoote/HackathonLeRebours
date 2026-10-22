# Lance-flammes cachés dans les lianes des murs : le piégeur allume celui qui est le plus proche du joueur.
# Les lianes s'agitent et la buse rougeoie avant le jet : un joueur attentif a le temps de passer.
# D'autres rideaux de lianes ne cachent rien (decoys) : on ne sait pas lesquels sont dangereux.

extends Node3D

@export var spots := PackedVector3Array()    # pied du mur (x, sol, z du mur) ; le jet part vers +z
@export var decoys := PackedVector3Array()   # lianes sans lance-flammes
@export var vine_height := 7.5
@export var length := 5.5
@export var width := 3.0
@export var reach := 14.0
@export var warning_time := 0.8
@export var fire_time := 1.4
@export var cooldown := 3.0

var cooldown_left := 0.0
var units: Array[Dictionary] = []
var vines: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var leaf_mat: StandardMaterial3D
var stem_mat: StandardMaterial3D
var time := 0.0
var roar: AudioStreamPlayer
var roaring := 0


func _ready() -> void:
	rng.seed = 5
	leaf_mat = StandardMaterial3D.new()
	leaf_mat.vertex_color_use_as_albedo = true
	leaf_mat.roughness = 0.8
	stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.22, 0.3, 0.12)
	roar = AudioStreamPlayer.new()
	roar.stream = Sfx.stream("lance_flammes")
	roar.volume_db = -3.0
	roar.finished.connect(func(): if roaring > 0: roar.play())
	add_child(roar)
	for s in spots:
		units.append(make_unit(s))
	for d in decoys:
		vines.append(make_vines(d, 5))


func make_unit(s: Vector3) -> Dictionary:
	# gueule de pierre dans le mur, buse de bronze qui rougeoie avant le jet
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.37, 0.3)
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.3, 0.5)
	box.material = stone
	head.mesh = box
	head.position = s + Vector3(0, 2.4, 0.25)
	add_child(head)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.45, 0.3, 0.15)
	bronze.metallic = 0.7
	bronze.roughness = 0.4
	bronze.emission_enabled = true
	bronze.emission = Color(1, 0.3, 0.05)
	bronze.emission_energy_multiplier = 0.0
	var nozzle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.42
	cyl.height = 0.7
	cyl.material = bronze
	nozzle.mesh = cyl
	nozzle.rotation.x = PI / 2
	nozzle.position = s + Vector3(0, 2.4, 0.75)
	add_child(nozzle)

	var fire := CPUParticles3D.new()
	fire.emitting = false
	fire.amount = 110
	fire.lifetime = 0.45
	fire.mesh = flame_mesh()
	fire.direction = Vector3(0, 0, 1)
	fire.spread = 13.0
	fire.initial_velocity_min = length / fire.lifetime * 0.9
	fire.initial_velocity_max = length / fire.lifetime * 1.05
	fire.gravity = Vector3(0, 2.5, 0)
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.8))
	fire.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.6, 0.15, 1), Color(0.9, 0.2, 0.05, 0.7), Color(0.2, 0.05, 0.02, 0)])
	fire.color_ramp = ramp
	fire.position = s + Vector3(0, 2.4, 1.1)
	add_child(fire)

	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.55, 0.2)
	light.light_energy = 0.0
	light.omni_range = 9.0
	light.position = s + Vector3(0, 2.6, length * 0.5)
	add_child(light)

	return {"spot": s, "bronze": bronze, "fire": fire, "light": light, "vines": make_vines(s, 7), "busy": false}


func flame_mesh() -> QuadMesh:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 1.7)
	quad.material = mat
	return quad


# rideau de lianes qui pend de la corniche (deux MultiMesh : tiges et feuilles)
func make_vines(s: Vector3, strands: int) -> Node3D:
	var root := Node3D.new()
	root.position = s + Vector3(0, vine_height, 0.75)
	add_child(root)
	var stem_mm := MultiMesh.new()
	stem_mm.transform_format = MultiMesh.TRANSFORM_3D
	var stem := BoxMesh.new()
	stem.size = Vector3(0.1, 0.8, 0.1)
	stem.material = stem_mat
	stem_mm.mesh = stem
	var leaf_mm := MultiMesh.new()
	leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
	leaf_mm.use_colors = true
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.6, 0.06, 0.38)
	leaf.material = leaf_mat
	leaf_mm.mesh = leaf
	var stems: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in strands:
		var x := (float(i) / maxf(strands - 1, 1) - 0.5) * 2.2 + rng.randf_range(-0.2, 0.2)
		var z := rng.randf_range(-0.15, 0.25)
		var drop := rng.randf_range(vine_height - 2.8, vine_height - 0.6)
		var y := 0.0
		while y > -drop:
			x += rng.randf_range(-0.08, 0.08)
			stems.append(Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15)), Vector3(x, y - 0.4, z)))
			for side in [-1, 1]:
				if rng.randf() < 0.8:
					var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.9, 0.9))
					leaves.append(Transform3D(b, Vector3(x + side * 0.25, y - rng.randf_range(0.1, 0.7), z + rng.randf_range(0.0, 0.25))))
					colors.append(Color(0.2, 0.42, 0.12).lerp(Color(0.38, 0.55, 0.16), rng.randf()))
			y -= 0.75
	stem_mm.instance_count = stems.size()
	for i in stems.size():
		stem_mm.set_instance_transform(i, stems[i])
	leaf_mm.instance_count = leaves.size()
	for i in leaves.size():
		leaf_mm.set_instance_transform(i, leaves[i])
		leaf_mm.set_instance_color(i, colors[i])
	for mm in [stem_mm, leaf_mm]:
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		root.add_child(inst)
	root.set_meta("offset", rng.randf() * TAU)
	vines.append(root)
	return root


func _process(delta: float) -> void:
	time += delta
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	# les lianes se balancent doucement
	for v in vines:
		if not v.has_meta("shaking"):
			v.rotation.z = sin(time * 1.3 + v.get_meta("offset")) * 0.025


func trigger() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or cooldown_left > 0.0:
		Sfx.play("refus", -6.0)
		return
	var feet := player.global_position.y - 3.75
	var best := -1
	var best_d := reach
	for i in units.size():
		var s: Vector3 = units[i].spot
		var d := Vector2(s.x - player.global_position.x, s.z + length * 0.5 - player.global_position.z).length()
		if not units[i].busy and absf(s.y - feet) < 4.5 and d < best_d:
			best = i
			best_d = d
	if best < 0:
		Sfx.play("refus", -6.0)
		return
	cooldown_left = cooldown
	fire(units[best])


func fire(u: Dictionary) -> void:
	u.busy = true
	var v: Node3D = u.vines
	var bronze: StandardMaterial3D = u.bronze
	v.set_meta("shaking", true)
	Sfx.play("lianes")
	var t := 0.0
	while t < warning_time:
		v.rotation.z = randf_range(-0.07, 0.07)
		v.rotation.x = randf_range(-0.04, 0.04)
		bronze.emission_energy_multiplier = (t / warning_time) * (3.0 if int(t * 12) % 2 == 0 else 1.5)
		await get_tree().process_frame
		t += get_process_delta_time()

	Sfx.play("flamme_allumage")
	roaring += 1
	if not roar.playing:
		roar.play()
	var fire_fx: CPUParticles3D = u.fire
	var light: OmniLight3D = u.light
	fire_fx.emitting = true
	t = 0.0
	while t < fire_time:
		light.light_energy = 3.5 + randf_range(-0.8, 0.8)
		v.rotation.z = randf_range(-0.12, 0.12)
		bronze.emission_energy_multiplier = 4.0
		burn(u.spot)
		await get_tree().process_frame
		t += get_process_delta_time()

	fire_fx.emitting = false
	roaring -= 1
	if roaring == 0:
		roar.stop()
	create_tween().tween_property(light, "light_energy", 0.0, 0.3)
	create_tween().tween_property(bronze, "emission_energy_multiplier", 0.0, 1.0)
	v.rotation = Vector3.ZERO
	v.remove_meta("shaking")
	u.busy = false


# le joueur est dans le jet ? (rayon du joueur compris)
func burn(s: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var p := player.global_position - s
	var feet := p.y - 3.75
	if absf(p.x) < width / 2 + 1.0 and p.z > 0.0 and p.z < length + 1.2 and feet > -1.0 and feet < 3.6:
		player.kill()
