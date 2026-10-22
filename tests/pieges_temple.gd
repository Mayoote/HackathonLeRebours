# Vérifie chaque piège du Temple : le joueur placé dedans doit mourir (retour au départ)
# godot --path . --script res://tests/pieges_temple.gd
extends SceneTree

const OUT := "C:/Users/Alexa/AppData/Local/Temp/claude/C--Users-Alexa-Documents-HackathonLeRebours/899fe8d0-bea1-4e92-83b8-cf6200f1db89/scratchpad/shots/"

var player: CharacterBody3D
var traps: Node
var deaths := 0


func _init() -> void:
	change_scene_to_file.call_deferred("res://Scenes/Levels/TempleScene.tscn")
	for i in 20:
		await process_frame
	player = current_scene.get_node("Player")
	traps = current_scene.get_node("Traps")
	player.respawned.connect(func(): deaths += 1)
	for n in traps.get_children():
		if n.get_script() and n.get_script().resource_path.ends_with("spike_floor.gd"):
			n.set_physics_process(false)

	await test("lance-flammes RDC", Vector3(-18, 5, 13), func(): traps.get_node("LanceFlammes").trigger(), 2.5, "flammes")
	await test("lance-flammes étage 2", Vector3(-2, 21, -14), func(): traps.get_node("LanceFlammes").trigger(), 2.5)
	await test("stalactite", Vector3(-15, 5, 13), func(): traps.get_node("Stalactites").trigger(), 2.0)
	await test("trappe à pics", Vector3(-12, 13, 6.5), func(): traps.get_node("TrappeAPics").trigger(), 2.0)
	var pics: Node = traps.get_node("PicsRDC1")
	await test("pics en rythme", Vector3(-24, 5, 14.5), func(): pics.set_physics_process(true), 3.5)
	pics.set_physics_process(false)
	# flèches pendant la montée
	var lift: Node3D = current_scene.get_node("Ascenseur")
	await test("flèches dans l'ascenseur", Vector3(17.25, 5, 6.5), func():
		await create_timer(1.5).timeout
		print("   hauteur ascenseur au tir : %.1f" % lift.position.y)
		traps.get_node("Fleches").trigger(), 4.0, "fleches")
	# après la mort l'ascenseur redescend chercher le joueur
	for i in 60 * 8:
		await physics_frame
	print("ascenseur revenu au RDC : %s (y=%.2f)" % [is_equal_approx(lift.position.y, 0.97), lift.position.y])
	quit()


func test(nom: String, pos: Vector3, action: Callable, delai: float, shot := "") -> void:
	player.spawn = Vector3(-37, 6, 14.5)
	player.global_position = pos
	player.invincible = 0.0
	for i in 30:
		await physics_frame
	for n in traps.get_children():
		if "cooldown_left" in n:
			n.cooldown_left = 0.0
	var before := deaths
	action.call()
	var t := 0.0
	var shot_done := false
	while t < delai and deaths == before:
		if shot != "" and not shot_done and t > 1.1:
			get_root().get_viewport().get_texture().get_image().save_png(OUT + shot + ".png")
			shot_done = true
		await physics_frame
		t += 1.0 / 60.0
	print("%s : %s (%.1f s)" % [nom, "OK, joueur tué" if deaths > before else "ÉCHEC, rien", t])
	for i in 70:
		await physics_frame
