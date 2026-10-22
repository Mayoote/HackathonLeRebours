# Stalactites : le piégeur fait tomber celle qui est la plus proche du joueur.
# Elle craque et tremble avant de tomber : un joueur attentif a le temps de s'écarter.

extends Node3D

@export var spots := PackedVector2Array()
@export var ceiling_y := 11.0
@export var ceilings := PackedFloat32Array()  # hauteur du plafond par stalactite (sinon ceiling_y)
@export var anchors := true                  # bloc de roche au-dessus : elle ne flotte pas
@export var upper_height := 10.0   # au-dessus : stalactites de l'étage (cachées quand le joueur est en bas)
@export var reach := 12.0          # distance max au joueur pour pouvoir tomber
@export var warning_time := 0.8
@export var hit_radius := 2.3
@export var regrow_time := 6.0
@export var cooldown := 2.0

var cooldown_left := 0.0
var stalactites: Array[Node3D] = []
var ready_flags: Array[bool] = []
var grounds: Array[float] = []  # hauteur du sol sous chaque stalactite
var parts := []  # par stalactite : les nœuds à cacher avec l'étage
var upper_shown := false
var rock: StandardMaterial3D
var ring_mat: StandardMaterial3D


func _ready() -> void:
	rock = StandardMaterial3D.new()
	rock.albedo_color = Color(0.45, 0.4, 0.36)
	rock.roughness = 0.9
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 0.8, 0.9, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.45), Color(1, 0.4, 0.3, 0.9), Color(1, 0.4, 0.3, 0.9), Color(1, 0.4, 0.3, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	ring_mat = StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_texture = tex
	for i in spots.size():
		var s := spots[i]
		var y: float = ceilings[i] if i < ceilings.size() else ceiling_y
		var st := make_stalactite()
		parts.append([st])
		st.position = Vector3(s.x, y, s.y)
		add_child(st)
		stalactites.append(st)
		ready_flags.append(true)
	# une flaque sous chaque stalactite montre la zone dangereuse
	await get_tree().physics_frame
	for st in stalactites:
		var g := ground_below(st.global_position)
		grounds.append(g)
		parts[grounds.size() - 1].append(puddle(Vector3(st.global_position.x, g, st.global_position.z)))
		# sous un plafond : quelques roches qui la relient au plafond
		if anchors:
			var i := grounds.size() - 1
			if covered(st.global_position):
				parts[i].append_array(anchor(st.global_position))
	set_upper_visible(upper_shown)


func puddle(pos: Vector3) -> Node3D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.05, 0.07, 0.1, 0.75), Color(0.05, 0.07, 0.1, 0.5), Color(0.05, 0.07, 0.1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.roughness = 0.05
	mat.metallic = 0.4
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hit_radius * 1.6, hit_radius * 1.6)
	plane.material = mat
	m.mesh = plane
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos + Vector3.UP * 0.04
	return m


func anchor(pos: Vector3) -> Array:
	var nodes := []
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.27, 0.25)
	dark.roughness = 1.0
	for k in 3:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = randf_range(0.9, 1.3)
		s.height = s.radius * 1.2
		s.radial_segments = 7
		s.rings = 4
		s.material = dark
		m.mesh = s
		add_child(m)
		m.position = pos + Vector3(randf_range(-0.6, 0.6), 0.5 + k * 0.4, randf_range(-0.6, 0.6))
		nodes.append(m)
	return nodes


func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var ignore: Array[RID] = []
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	while hit and hit.collider is CharacterBody3D:
		ignore.append(hit.rid)
		q.exclude = ignore
		hit = space.intersect_ray(q)
	return hit


func covered(pos: Vector3) -> bool:
	return not ray(pos, pos + Vector3.UP * 3.0).is_empty()


func make_stalactite() -> Node3D:
	var root := Node3D.new()
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.0
	mesh.height = 3.2
	mesh.radial_segments = 7
	mesh.material = rock
	cone.mesh = mesh
	cone.position.y = -1.6
	root.add_child(cone)
	return root


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func trigger() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or cooldown_left > 0.0:
		Sfx.play("refus", -6.0)
		return
	var best := -1
	var best_d := reach
	for i in stalactites.size():
		var d := Vector2(stalactites[i].global_position.x - player.global_position.x, stalactites[i].global_position.z - player.global_position.z).length()
		# seulement celles du même étage que le joueur
		var same_floor := i < grounds.size() and absf(grounds[i] - (player.global_position.y - 3.75)) < 4.0
		if ready_flags[i] and same_floor and d < best_d:
			best = i
			best_d = d
	if best < 0:
		Sfx.play("refus", -6.0)
		return
	cooldown_left = cooldown
	fall(best)


func ground_below(pos: Vector3) -> float:
	# on ignore le joueur et le rocher : on veut le sol
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 40)
	var ignore: Array[RID] = []
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	while hit and hit.collider is CharacterBody3D:
		ignore.append(hit.rid)
		q.exclude = ignore
		hit = space.intersect_ray(q)
	return hit.position.y if hit else 0.97


func fall(i: int) -> void:
	ready_flags[i] = false
	var st := stalactites[i]
	var top := st.position
	var ground := ground_below(st.global_position)
	Sfx.play("stalactite_craque")

	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hit_radius * 2.2, hit_radius * 2.2)
	plane.material = ring_mat
	ring.mesh = plane
	add_child(ring)
	ring.global_position = Vector3(st.global_position.x, ground + 0.5, st.global_position.z)

	var t := 0.0
	while t < warning_time:
		st.position = top + Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
		await get_tree().process_frame
		t += get_process_delta_time()

	var drop := create_tween()
	drop.tween_property(st, "global_position:y", ground + 4.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await drop.finished
	ring.queue_free()
	Sfx.play("stalactite_impact")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var flat := Vector2(player.global_position.x - st.global_position.x, player.global_position.z - st.global_position.z)
		if flat.length() < hit_radius and absf(player.global_position.y - 3.75 - ground) < 3.0:
			player.kill()

	# elle se brise puis repousse au plafond
	var shrink := create_tween()
	shrink.tween_property(st, "scale", Vector3(1.6, 0.05, 1.6), 0.15)
	await get_tree().create_timer(1.5).timeout
	st.visible = false
	st.position = top
	st.scale = Vector3(1, 0.01, 1)
	await get_tree().create_timer(regrow_time).timeout
	st.visible = true
	await create_tween().tween_property(st, "scale", Vector3.ONE, 0.6).finished
	ready_flags[i] = true


# appelé par floor_visibility.gd : les stalactites de l'étage disparaissent avec lui
func set_upper_visible(up: bool) -> void:
	upper_shown = up
	for i in grounds.size():
		if grounds[i] > upper_height:
			for n in parts[i]:
				n.visible = up
