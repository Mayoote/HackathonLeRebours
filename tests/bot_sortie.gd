# Joueur automatique : run final d'une traite (pics en rythme coupés, boule active), affiche le temps
# godot --path . --script res://tests/bot_sortie.gd
extends SceneTree

const SAUTS := [31.5, 63.0, 69.2, 117.5, 129.5, 134.5, 167.0]  # x où sauter (trous, blocs, marches)

var deaths := 0


func _init() -> void:
	change_scene_to_file.call_deferred("res://Scenes/Levels/SortieScene.tscn")
	for i in 10:
		await process_frame
	var scene := current_scene
	var player: CharacterBody3D = scene.get_node("Player")
	var gm := scene.get_node("GameManager")
	var boule: Node3D = scene.get_node("Traps/Boule")
	for n in scene.get_node("Traps").get_children():
		if n.get_script().resource_path.ends_with("spike_floor.gd"):
			n.set_physics_process(false)
	player.respawned.connect(func(): deaths += 1; print("!! MORT à x=%.1f" % player.global_position.x))
	var t := 0.0
	var next := 0
	var ecart := INF
	# avancer droit le long du couloir (+x), quelle que soit l'orientation de la caméra
	var yaw := player.get_viewport().get_camera_3d().global_rotation.y
	var dir := Vector3.RIGHT.rotated(Vector3.UP, -yaw)
	Input.action_press("p1_right", maxf(dir.x, 0.0))
	if dir.z > 0.0:
		Input.action_press("p1_down", dir.z)
	else:
		Input.action_press("p1_up", -dir.z)
	while not gm.finished and t < 60.0:
		var x := player.global_position.x
		if next < SAUTS.size() and x > SAUTS[next] and player.is_on_floor():
			Input.action_press("p1_jump")
			next += 1
		else:
			Input.action_release("p1_jump")
		if boule.active:
			ecart = minf(ecart, x - boule.position.x)
		await physics_frame
		t += 1.0 / 60.0
	for a in ["p1_right", "p1_up", "p1_down"]:
		Input.action_release(a)
	print("FIN  fini=%s  temps=%.1f s  morts=%d  x=%.1f  écart mini avec la boule=%.1f" % [gm.finished, t, deaths, player.global_position.x, ecart])
	quit()
