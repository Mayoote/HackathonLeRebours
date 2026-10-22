# Vérifie les pièges du run final : boule, trappe, grille à manivelle
# godot --path . --script res://tests/pieges_sortie.gd [-- dossier_captures]
extends SceneTree

var player: CharacterBody3D
var deaths := 0
var shots := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	change_scene_to_file.call_deferred("res://Scenes/Levels/SortieScene.tscn")
	for i in 10:
		await process_frame
	var scene := current_scene
	player = scene.get_node("Player")
	var traps := scene.get_node("Traps")
	var gm := scene.get_node("GameManager")
	for n in traps.get_children():
		if n.get_script().resource_path.ends_with("spike_floor.gd"):
			n.set_physics_process(false)
	player.respawned.connect(func(): deaths += 1)
	await create_timer(0.5).timeout
	capture("depart")

	# la boule écrase un joueur qui reste planté
	player.global_position = Vector3(27, 5, 0)
	await create_timer(1.6).timeout
	capture("boule")
	var before := deaths
	var t := 0.0
	while deaths == before and t < 8.0:
		await physics_frame
		t += 1.0 / 60.0
	print("boule : %s (%.1f s)" % ["OK, joueur écrasé" if deaths > before else "ÉCHEC", t])
	print("boule remise au départ après la mort : %s" % (not traps.get_node("Boule").visible))

	# trappe 2 sous le joueur
	player.global_position = Vector3(92, 5, 0)
	await create_timer(0.5).timeout
	before = deaths
	traps.get_node("Trappes/Trapdoor2").trigger()
	t = 0.0
	while deaths == before and t < 5.0:
		await physics_frame
		t += 1.0 / 60.0
	print("trappe : %s (%.1f s)" % ["OK, joueur tombé" if deaths > before else "ÉCHEC", t])

	# la grille : on mouline (crans d'encodeur) pendant que le joueur est encore loin
	player.global_position = Vector3(195, 5, 0)
	var gate := traps.get_node("Grille")
	for i in 30:
		scene.get_node("Trapper")._on_encoder_changed(i, 10)
		await physics_frame
	print("grille après 300 crans : %d %%" % roundi(gate.progress * 100))
	await create_timer(0.3).timeout
	capture("grille")
	for i in 30:
		scene.get_node("Trapper")._on_encoder_changed(i, 10)
		await physics_frame
	await create_timer(0.3).timeout
	print("grille fermée=%s  partie finie=%s  titre=\"%s\"" % [gate.closed, gm.finished, gm.end_title.text])
	quit()


func capture(nom: String) -> void:
	if shots != "":
		get_root().get_viewport().get_texture().get_image().save_png(shots + "/" + nom + ".png")
