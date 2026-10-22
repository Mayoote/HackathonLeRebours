# Vérifie le décor d'un niveau : objets qui flottent, objets qui traversent une collision,
# surfaces superposées (z-fighting), collisions sans visuel.
# godot --headless --path . res://tools/verifier_decor.tscn
# Exceptions voulues : limites extérieures du terrain (groupe "Bords"), stalactites
# des galeries à ciel ouvert, grands plans (fond noir, voile, eau), plafond fantôme
# (jamais affiché en même temps que le sol de l'étage qu'il double).

extends Node

const NIVEAU := "res://Scenes/Levels/GrotteScene.tscn"

var problemes := []


func _ready() -> void:
	var scene: Node3D = load(NIVEAU).instantiate()
	add_child(scene)
	scene.get_node("Trapper").set_process(false)
	scene.get_node("Player").set_physics_process(false)
	scene.get_node("Player").global_position = Vector3(0, -200, 0)
	for i in 5:
		await get_tree().physics_frame
	var meshes := decor_meshes(scene)
	flottants(meshes, structure(scene))
	traversants(meshes)
	superposes(scene)
	collisions_sans_visuel(scene)
	print("VERIF %d problème(s)" % problemes.size())
	for p in problemes:
		print("VERIF  - ", p)
	get_tree().quit()


func ignore(n: Node) -> bool:
	var path := str(n.get_path())
	for mot in ["Player", "Keys", "Goal", "Bords", "Voile", "PlafondBas", "Eau/", "Traps/Stalactites", "Traps/Boulder", "Trapdoor"]:
		if mot in path:
			return true
	return false


# meshes de décor posés (pas les dalles / murs, qui sont dans un StaticBody ou leurs voisins)
func decor_meshes(root: Node) -> Array:
	var out := []
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if ignore(m) or not m.is_visible_in_tree() and not "Etage2" in str(m.get_path()):
			continue
		if m.mesh is PlaneMesh:
			continue
		if m.get_parent() is StaticBody3D or m.mesh is BoxMesh or "/Murs/" in str(m.get_path()):
			continue  # structure (sols, murs, blocs) : vérifiée à part
		out.append(m)
	return out


func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.hit_from_inside = true
	return get_viewport().world_3d.direct_space_state.intersect_ray(q)


# visuels de structure (dalles, murs, piliers, poteaux) : un objet qui les touche est soutenu
func structure(root: Node) -> Array:
	var out := []
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if m.get_parent() is StaticBody3D or m.mesh is BoxMesh or "/Murs/" in str(m.get_path()):
			out.append(m.global_transform * m.get_aabb())
	return out


func flottants(meshes: Array, appuis: Array) -> void:
	for m in meshes:
		var b: AABB = m.global_transform * m.get_aabb()
		var c := b.get_center()
		var bas := ray(Vector3(c.x, b.position.y + 0.3, c.z), Vector3(c.x, b.position.y - 0.8, c.z))
		var haut := ray(Vector3(c.x, b.end.y - 0.3, c.z), Vector3(c.x, b.end.y + 0.8, c.z))
		var touche := false
		for a in appuis:
			if a.grow(0.05).intersects(b):
				touche = true
				break
		if bas.is_empty() and haut.is_empty() and not touche:
			problemes.append("flotte : %s (bas à y=%.2f)" % [nom(m), b.position.y])


func traversants(meshes: Array) -> void:
	var space := get_viewport().world_3d.direct_space_state
	for m in meshes:
		var b: AABB = m.global_transform * m.get_aabb()
		var q := PhysicsPointQueryParameters3D.new()
		q.position = b.get_center()
		var hits := space.intersect_point(q)
		for h in hits:
			if h.collider is StaticBody3D and not ignore(h.collider) and not str(h.collider.get_parent().get_path()) in str(m.get_path()):
				problemes.append("traverse : %s est dans %s" % [nom(m), nom(h.collider)])
				break


func superposes(root: Node) -> void:
	# surfaces horizontales à la même hauteur qui se recouvrent
	var surfaces := []
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if ignore(m) and not "Eau/" in str(m.get_path()):
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		var plat := m.mesh is PlaneMesh or (m.mesh is BoxMesh and b.size.y <= 0.2)
		if plat:
			surfaces.append([m, b.end.y, Rect2(b.position.x, b.position.z, b.size.x, b.size.z)])
	for i in surfaces.size():
		for j in range(i + 1, surfaces.size()):
			var a = surfaces[i]
			var c = surfaces[j]
			if absf(a[1] - c[1]) < 0.015:
				var inter: Rect2 = a[2].intersection(c[2])
				if inter.get_area() > 0.05:
					problemes.append("z-fighting : %s et %s à y=%.2f" % [nom(a[0]), nom(c[0]), a[1]])


func collisions_sans_visuel(root: Node) -> void:
	var visuels := []
	for m in root.find_children("*", "MeshInstance3D", true, false):
		visuels.append(m.global_transform * m.get_aabb())
	for body in root.find_children("*", "StaticBody3D", true, false):
		if ignore(body):
			continue
		for s in body.get_children():
			if not (s is CollisionShape3D and s.shape is BoxShape3D):
				continue
			var forme := AABB(-s.shape.size / 2, s.shape.size)
			var box: AABB = s.global_transform * forme
			# union des visuels qui touchent la collision
			var union := AABB()
			var vide := true
			for v in visuels:
				if v.intersects(box):
					var part: AABB = v.intersection(box)
					union = part if vide else union.merge(part)
					vide = false
			if vide or union.size.x < box.size.x * 0.8 or union.size.y < box.size.y * 0.8 or union.size.z < box.size.z * 0.8:
				problemes.append("collision sans visuel : %s (%s)" % [nom(body), box.size.snapped(Vector3(0.1, 0.1, 0.1))])


func nom(n: Node) -> String:
	var path := str(n.get_path())
	return path.substr(path.find("GrotteScene"))
