# generer_prairie.gd — génère le décor du niveau Prairie dans Scenes/Levels/Prairie.tscn
#
# Utilise le pack « Stylized Nature MegaKit » (Meshes/Prairie). Le placement est aléatoire
# mais reproductible (même GRAINE = même décor). Une fois généré, chaque élément peut être
# déplacé ou supprimé à la main dans Godot. ATTENTION : relancer l'outil écrase ces retouches.
#
# Règle de la vue isométrique : la caméra regarde depuis +X/+Z. Les grands arbres vont donc
# au fond (côtés -X et -Z) et seuls des éléments bas vont au premier plan (côtés +X et +Z).
#
# Lancer depuis le dossier du projet :
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/generer_prairie.gd

extends SceneTree

const GRAINE := 2026
const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Prairie.tscn"
const ECHELLE := 2.5  # le kit est à taille humaine, nos personnages sont 2,7 fois plus grands

# Terrain de jeu (le sol existant de GameScene) et hauteur de sa surface
const ARENE_MIN := Vector2(-41.0, -18.0)
const ARENE_MAX := Vector2(21.5, 19.2)
const SOL_Y := 0.97
# Zones à garder dégagées : pièges, départ et sortie (x, z, rayon)
const ZONES_LIBRES := [
	Vector3(-24, -6, 3.8), Vector3(-24, 6, 3.8), Vector3(-13, 0, 3.8),
	Vector3(-2, -7, 3.8), Vector3(-2, 7, 3.8),
	Vector3(-35, 0, 5.0), Vector3(15, 0, 5.0),
]

var rng := RandomNumberGenerator.new()
var decor: Node3D
var _cache := {}
var _occupe: Array[Vector3] = []  # obstacles déjà posés (x, z, rayon)


func _init() -> void:
	rng.seed = GRAINE
	decor = Node3D.new()
	decor.name = "Prairie"

	_sol_exterieur()
	_limites()
	_chemin()
	_foret_du_fond()
	_bordure_avant()
	_obstacles()
	_vegetation()

	var packed := PackedScene.new()
	packed.pack(decor)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE.get_base_dir()))
	var err := ResourceSaver.save(packed, SORTIE)
	print("Prairie générée : ", SORTIE, " (", decor.get_child_count(), " groupes, erreur=", err, ")")
	quit()


# ── Briques ────────────────────────────────────────────────

func _modele(nom: String) -> PackedScene:
	if not _cache.has(nom):
		_cache[nom] = load(KIT + nom + ".glb")
	return _cache[nom]


func _groupe(nom: String) -> Node3D:
	var g := Node3D.new()
	g.name = nom
	decor.add_child(g)
	g.owner = decor
	return g


## Pose un modèle du kit. rayon_collision > 0 : obstacle sur lequel on bute.
func _poser(parent: Node3D, modele: String, x: float, z: float, taille := 1.0, rayon_collision := 0.0, hauteur_collision := 4.0) -> void:
	var inst: Node3D = _modele(modele).instantiate()
	var s := ECHELLE * taille
	inst.scale = Vector3(s, s, s)
	inst.rotation.y = rng.randf() * TAU
	var support: Node3D = parent
	if rayon_collision > 0.0:
		var body := StaticBody3D.new()
		body.name = modele.get_slice("-", 0).replace(" ", "")
		body.position = Vector3(x, SOL_Y, z)
		parent.add_child(body)
		body.owner = decor
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = rayon_collision
		cyl.height = hauteur_collision
		shape.shape = cyl
		shape.position.y = hauteur_collision / 2.0
		body.add_child(shape)
		shape.owner = decor
		support = body
		_occupe.append(Vector3(x, z, rayon_collision))
	else:
		inst.position = Vector3(x, SOL_Y, z)
	support.add_child(inst)
	inst.owner = decor


func _libre(x: float, z: float, marge: float) -> bool:
	for zone in ZONES_LIBRES:
		if Vector2(x, z).distance_to(Vector2(zone.x, zone.y)) < zone.z + marge:
			return false
	for o in _occupe:
		if Vector2(x, z).distance_to(Vector2(o.x, o.y)) < o.z + marge:
			return false
	return true


func _dans_arene(x: float, z: float, marge := 1.5) -> bool:
	return x > ARENE_MIN.x + marge and x < ARENE_MAX.x - marge and z > ARENE_MIN.y + marge and z < ARENE_MAX.y - marge


func _un_parmi(liste: Array) -> String:
	return liste[rng.randi() % liste.size()]


# ── Décor ──────────────────────────────────────────────────

func _sol_exterieur() -> void:
	var sol := MeshInstance3D.new()
	sol.name = "SolExterieur"
	var plan := PlaneMesh.new()
	plan.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 0.22)
	plan.material = mat
	sol.mesh = plan
	sol.position = Vector3(-10, SOL_Y - 0.08, 0)
	decor.add_child(sol)
	sol.owner = decor


func _limites() -> void:
	# Murs invisibles autour du terrain (remplacent les grilles)
	var g := _groupe("Limites")
	var centre := (ARENE_MIN + ARENE_MAX) / 2.0
	var taille := ARENE_MAX - ARENE_MIN
	var murs := [
		[Vector3(ARENE_MIN.x - 1, 0, centre.y), Vector3(2, 20, taille.y + 4)],
		[Vector3(ARENE_MAX.x + 1, 0, centre.y), Vector3(2, 20, taille.y + 4)],
		[Vector3(centre.x, 0, ARENE_MIN.y - 1), Vector3(taille.x + 4, 20, 2)],
		[Vector3(centre.x, 0, ARENE_MAX.y + 1), Vector3(taille.x + 4, 20, 2)],
	]
	for i in murs.size():
		var body := StaticBody3D.new()
		body.name = "Mur%d" % (i + 1)
		body.position = murs[i][0] + Vector3(0, SOL_Y + 10, 0)
		g.add_child(body)
		body.owner = decor
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = murs[i][1]
		shape.shape = box
		body.add_child(shape)
		shape.owner = decor


func _chemin() -> void:
	# Chemin de pierres sinueux du départ à la sortie
	var g := _groupe("Chemin")
	var pierres := ["Rock Path Round Wide", "Rock Path Square Wide", "Rock Path Round Thin",
		"Rock Path Square Thin", "Rock Path Round Small", "Rock Path Square Smal"]
	var x := -31.0
	while x < 11.0:
		var z := 3.0 * sin((x + 35.0) / 7.0)
		_poser(g, _un_parmi(pierres), x + rng.randf_range(-0.3, 0.3), z + rng.randf_range(-0.6, 0.6), rng.randf_range(0.9, 1.1))
		x += rng.randf_range(2.4, 3.0)


func _foret_du_fond() -> void:
	# Grands arbres derrière le terrain (côtés -X et -Z) : ils ne cachent rien en vue isométrique
	var g := _groupe("ForetDuFond")
	var arbres := ["Tree", "Tree-QVOop92WmG", "Tree-aVOxaHRPWe", "Tree-qZtx0AHhcy", "Tree-t9KbsfYdXz",
		"Pine", "Pine-699sFuLCN2", "Pine-79gmlLnweB", "Pine-Zt62gceKXZ", "Pine-rfnxJv0Rqa"]
	for i in 110:
		var x: float
		var z: float
		if rng.randf() < 0.5:
			x = rng.randf_range(ARENE_MIN.x - 45, ARENE_MAX.x + 10)
			z = rng.randf_range(ARENE_MIN.y - 40, ARENE_MIN.y - 3)
		else:
			x = rng.randf_range(ARENE_MIN.x - 45, ARENE_MIN.x - 3)
			z = rng.randf_range(ARENE_MIN.y - 40, ARENE_MAX.y + 10)
		_poser(g, _un_parmi(arbres), x, z, rng.randf_range(0.85, 1.25))
	# Quelques arbres remarquables
	for p in [Vector2(-52, -30), Vector2(-20, -32), Vector2(-56, 8)]:
		_poser(g, _un_parmi(["Twisted Tree", "Twisted Tree-8oraKn9m0x", "Twisted Tree-GVTsMmuzv7"]), p.x, p.y, 0.9)
	for p in [Vector2(5, -26), Vector2(-48, -10)]:
		_poser(g, _un_parmi(["Dead Tree", "Dead Tree-MlmK5488ou"]), p.x, p.y, 0.8)
	# Sous-bois
	for i in 70:
		var x := rng.randf_range(ARENE_MIN.x - 30, ARENE_MAX.x + 5)
		var z := rng.randf_range(ARENE_MIN.y - 25, ARENE_MIN.y - 2)
		if rng.randf() < 0.4:
			z = rng.randf_range(ARENE_MIN.y - 25, ARENE_MAX.y + 5)
			x = rng.randf_range(ARENE_MIN.x - 30, ARENE_MIN.x - 2)
		_poser(g, _un_parmi(["Bush", "Bush with Flowers", "Fern", "Plant Big-MbhbP7JrTI", "Mushroom"]), x, z, rng.randf_range(0.7, 1.1))


func _bordure_avant() -> void:
	# Premier plan (côtés +X et +Z) : uniquement des éléments bas pour ne pas cacher le jeu
	var g := _groupe("BordureAvant")
	var bas := ["Bush", "Bush with Flowers", "Rock Medium", "Bush", "Grass Wispy-Msr9zx66VU",
		"Tall Grass", "Grass Wispy", "Flower Group", "Flower Group-LqTljN6Wg2", "Plant", "Clover"]
	for i in 150:
		var x: float
		var z: float
		if rng.randf() < 0.5:
			x = rng.randf_range(ARENE_MIN.x - 10, ARENE_MAX.x + 30)
			z = rng.randf_range(ARENE_MAX.y + 1.5, ARENE_MAX.y + 30)
		else:
			x = rng.randf_range(ARENE_MAX.x + 1.5, ARENE_MAX.x + 30)
			z = rng.randf_range(ARENE_MIN.y - 10, ARENE_MAX.y + 30)
		var modele := _un_parmi(bas)
		var taille := rng.randf_range(0.7, 1.2)
		if modele.begins_with("Rock"):
			taille *= 0.65  # rochers plus discrets au premier plan
		_poser(g, modele, x, z, taille)


func _obstacles() -> void:
	# Quelques rochers et buissons sur le terrain, sur lesquels on bute
	var g := _groupe("Obstacles")
	var poses := 0
	var essais := 0
	while poses < 9 and essais < 500:
		essais += 1
		var x := rng.randf_range(ARENE_MIN.x + 4, ARENE_MAX.x - 4)
		var z := rng.randf_range(ARENE_MIN.y + 4, ARENE_MAX.y - 4)
		if abs(z - 3.0 * sin((x + 35.0) / 7.0)) < 4.0 or not _libre(x, z, 4.0):
			continue  # on ne bloque pas le chemin ni les pièges
		if rng.randf() < 0.55:
			_poser(g, _un_parmi(["Rock Medium", "Rock Medium-JQxF95498B", "Rock Medium-s1OJ3bBzqc"]), x, z, rng.randf_range(0.8, 1.1), 3.3, 5.0)
		else:
			_poser(g, _un_parmi(["Bush", "Bush with Flowers"]), x, z, rng.randf_range(1.0, 1.3), 2.3, 4.0)
		poses += 1


func _vegetation() -> void:
	# Herbes, fleurs et cailloux sur le terrain (sans collision), hors pièges
	var g := _groupe("Vegetation")
	var familles := [
		[["Grass", "Grass Wispy", "Grass Wispy-Msr9zx66VU", "Tall Grass"], 110],
		[["Flower Single", "Flower Single-GvfHo0roi3", "Flower Group", "Flower Group-LqTljN6Wg2"], 35],
		[["Clover", "Clover-u5SOgBFiut", "Plant", "Plant-xH5gNlQxAZ", "Plant Big"], 35],
		[["Flower Petal", "Flower Petal-LqvxG9OBOU", "Flower Petal-eVE0j49ux9", "Flower Petal-niuBUEJdvM", "Flower Petal-tzG4JcqYWs"], 40],
		[["Pebble Round", "Pebble Round-KYtJ6JNXh2", "Pebble Square", "Pebble Square-6juX57sLHe", "Pebble Square-s71L3q1nXN"], 35],
		[["Mushroom"], 12],
	]
	for famille in familles:
		var poses := 0
		var essais := 0
		while poses < famille[1] and essais < 3000:
			essais += 1
			var x := rng.randf_range(ARENE_MIN.x, ARENE_MAX.x)
			var z := rng.randf_range(ARENE_MIN.y, ARENE_MAX.y)
			if not _dans_arene(x, z) or not _libre(x, z, 0.5):
				continue
			_poser(g, _un_parmi(famille[0]), x, z, rng.randf_range(0.5, 0.9))  # plus petit que le personnage
			poses += 1
