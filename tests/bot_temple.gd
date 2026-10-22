# Joueur automatique : parcours complet du Temple (pièges automatiques coupés), affiche le temps
# godot --path . --script res://tests/bot_temple.gd
extends SceneTree

# [x, z, action] ; action : "" marcher, "lift" attendre l'ascenseur, "jump" sauter en avançant
const ROUTE := [
	[-30, 14.5, ""], [15, 14.5, ""], [18, 16.5, ""],
	[17.25, 6.5, "lift"], [8, 6.5, ""], [-37, 6.5, ""], [-37, -1.5, ""], [-1, -1.5, ""],
	[-37, -1.5, ""], [-37, 6.5, ""], [10, 6.5, ""], [17.25, 6.5, "lift"],
	[17.25, -2, ""], [17, -8, ""], [-22, -13, ""], [-29.5, -13, "jump"], [-32, -13, "jump"],
	[-20, -13, ""], [15, -12, ""], [17, -12, ""],
]

var player: CharacterBody3D
var t0 := 0.0


func _init() -> void:
	change_scene_to_file.call_deferred("res://Scenes/Levels/TempleScene.tscn")
	for i in 10:
		await process_frame
	var scene := current_scene
	player = scene.get_node("Player")
	for n in scene.get_node("Traps").get_children():
		if n.has_method("hit") and n.get_script().resource_path.ends_with("spike_floor.gd"):
			n.set_physics_process(false)
	player.respawned.connect(func(): print("!! MORT à ", Time.get_ticks_msec() / 1000.0 - t0))
	t0 = Time.get_ticks_msec() / 1000.0
	var gm := scene.get_node("GameManager")
	for i in ROUTE.size():
		var w: Array = ROUTE[i]
		var ok: bool = await walk_to(Vector2(w[0], w[1]), w[2])
		print("étape %d (%s, %s) %s  t=%.1f  pos=%s  clés=%d" % [i, w[0], w[1], w[2], Time.get_ticks_msec() / 1000.0 - t0, player.global_position.snapped(Vector3.ONE * 0.1), gm.keys_got])
		if not ok:
			print("BLOQUÉ")
			break
		if gm.finished:
			break
	print("FIN  fini=%s  clés=%d/%d  niveau=%d" % [gm.finished, gm.keys_got, gm.keys_total, root.get_node("Partie").level])
	quit()


func set_input(dir: Vector2) -> void:
	var cam := player.get_viewport().get_camera_3d()
	var v := Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, -cam.global_rotation.y)
	for a in ["p1_left", "p1_right", "p1_up", "p1_down"]:
		Input.action_release(a)
	if v.x > 0.01: Input.action_press("p1_right", v.x)
	if v.x < -0.01: Input.action_press("p1_left", -v.x)
	if v.z > 0.01: Input.action_press("p1_down", v.z)
	if v.z < -0.01: Input.action_press("p1_up", -v.z)


func walk_to(goal: Vector2, action: String) -> bool:
	var start_y := player.global_position.y
	var timer := 0.0
	var jumped := false
	while timer < 25.0:
		var p := Vector2(player.global_position.x, player.global_position.z)
		var d := goal - p
		if d.length() < 0.6:
			break
		set_input(d.normalized() if d.length() > 1.5 else d.normalized() * 0.5)
		if action == "jump" and not jumped and d.length() < 4.6 and player.is_on_floor():
			Input.action_press("p1_jump")
			jumped = true
		elif jumped:
			Input.action_release("p1_jump")
		await physics_frame
		timer += 1.0 / 60.0
	set_input(Vector2.ZERO)
	Input.action_release("p1_jump")
	if timer >= 25.0:
		return false
	if action == "lift":
		# attendre que l'ascenseur ait monté d'un étage
		var t := 0.0
		while player.global_position.y < start_y + 7.5 and t < 15.0:
			await physics_frame
			t += 1.0 / 60.0
		while not player.is_on_floor() or absf(player.get_platform_velocity().y) > 0.01:
			await physics_frame
		return t < 15.0
	return true
