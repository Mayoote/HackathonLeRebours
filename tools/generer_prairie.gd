# Génère le décor de la Prairie -> Scenes/Levels/Prairie.tscn
# Relancer écrase les retouches faites à la main dans la scène.
# godot --headless --path . --script res://tools/generer_prairie.gd

extends SceneTree

const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Prairie.tscn"
const ECHELLE := 2.5
const SOL_Y := 0.97
const ARENE_MIN := Vector2(-41.0, -18.0)
const ARENE_MAX := Vector2(21.5, 19.2)

# pièges, départ, sortie : on ne pose rien dessus
const ZONES_LIBRES := [
	Vector3(-24, -6, 3.8), Vector3(-24, 6, 3.8), Vector3(-13, 0, 3.8),
	Vector3(-2, -7, 3.8), Vector3(-2, 7, 3.8),
	Vector3(-35, 0, 4.0), Vector3(15, 0, 5.0),
]

const CHEMIN := [
	Vector2(-32, 0.5), Vector2(-28, 2), Vector2(-23, 0.5), Vector2(-18, -1),
	Vector2(-13, 0), Vector2(-8, 1.5), Vector2(-3, 0), Vector2(3, -1), Vector2(8, 0.5), Vector2(11.5, 0.5),
]

const ARBRES := ["Tree", "Tree-QVOop92WmG", "Tree-aVOxaHRPWe", "Tree-qZtx0AHhcy", "Tree-t9KbsfYdXz"]
const PINS := ["Pine", "Pine-699sFuLCN2", "Pine-79gmlLnweB", "Pine-Zt62gceKXZ", "Pine-rfnxJv0Rqa"]
const ROCHERS := ["Rock Medium", "Rock Medium-JQxF95498B", "Rock Medium-s1OJ3bBzqc"]
const FLEURS := ["Flower Group", "Flower Group-LqTljN6Wg2", "Flower Single", "Flower Single-GvfHo0roi3"]
const PETALES := ["Flower Petal", "Flower Petal-LqvxG9OBOU", "Flower Petal-eVE0j49ux9", "Flower Petal-tzG4JcqYWs"]
const HERBES := ["Grass", "Grass Wispy", "Grass Wispy-Msr9zx66VU", "Tall Grass"]
const CAILLOUX := ["Pebble Round", "Pebble Round-KYtJ6JNXh2", "Pebble Square", "Pebble Square-6juX57sLHe", "Pebble Square-s71L3q1nXN"]
const BUISSONS := ["Bush", "Bush with Flowers"]

var rng := RandomNumberGenerator.new()
var decor: Node3D
var cache := {}


func _init() -> void:
	rng.seed = 7
	decor = Node3D.new()
	decor.name = "Prairie"

	sol_exterieur()
	limites()
	chemin()
	clairiere_depart()
	massifs()
	rochers()
	haie_vers_la_porte()
	foret()
	premier_plan()

	var packed := PackedScene.new()
	packed.pack(decor)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE.get_base_dir()))
	print("Prairie : ", ResourceSaver.save(packed, SORTIE))
	quit()


func groupe(nom: String) -> Node3D:
	var g := Node3D.new()
	g.name = nom
	decor.add_child(g)
	g.owner = decor
	return g


func poser(parent: Node3D, modele: String, pos: Vector2, taille := 1.0, collision := 0.0) -> void:
	if not cache.has(modele):
		cache[modele] = load(KIT + modele + ".glb")
	var inst: Node3D = cache[modele].instantiate()
	inst.scale = Vector3.ONE * ECHELLE * taille
	inst.rotation.y = rng.randf() * TAU
	var support := parent
	if collision > 0.0:
		var body := StaticBody3D.new()
		body.position = Vector3(pos.x, SOL_Y, pos.y)
		parent.add_child(body)
		body.owner = decor
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = collision
		cyl.height = 5.0
		forme.shape = cyl
		forme.position.y = 2.5
		body.add_child(forme)
		forme.owner = decor
		support = body
	else:
		inst.position = Vector3(pos.x, SOL_Y, pos.y)
	support.add_child(inst)
	inst.owner = decor


func libre(p: Vector2, marge := 0.5) -> bool:
	for z in ZONES_LIBRES:
		if p.distance_to(Vector2(z.x, z.y)) < z.z + marge:
			return false
	return true


func au_hasard(liste: Array) -> String:
	return liste[rng.randi() % liste.size()]


# n éléments autour d'un point, plus serrés au centre
func touffe(parent: Node3D, centre: Vector2, rayon: float, n: int, modeles: Array, taille := Vector2(0.6, 1.0)) -> void:
	for i in n:
		var p := centre + Vector2.from_angle(rng.randf() * TAU) * rayon * sqrt(rng.randf()) * rng.randf_range(0.4, 1.0)
		if libre(p):
			poser(parent, au_hasard(modeles), p, rng.randf_range(taille.x, taille.y))


func sol_exterieur() -> void:
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


func limites() -> void:
	var g := groupe("Limites")
	var c := (ARENE_MIN + ARENE_MAX) / 2.0
	var t := ARENE_MAX - ARENE_MIN
	var murs := [
		[Vector3(ARENE_MIN.x - 1, 0, c.y), Vector3(2, 20, t.y + 4)],
		[Vector3(ARENE_MAX.x + 1, 0, c.y), Vector3(2, 20, t.y + 4)],
		[Vector3(c.x, 0, ARENE_MIN.y - 1), Vector3(t.x + 4, 20, 2)],
		[Vector3(c.x, 0, ARENE_MAX.y + 1), Vector3(t.x + 4, 20, 2)],
	]
	for m in murs:
		var body := StaticBody3D.new()
		body.position = m[0] + Vector3(0, SOL_Y + 10, 0)
		g.add_child(body)
		body.owner = decor
		var forme := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = m[1]
		forme.shape = box
		body.add_child(forme)
		forme.owner = decor


func chemin() -> void:
	var g := groupe("Chemin")
	var dalles := ["Rock Path Round Wide", "Rock Path Square Wide", "Rock Path Round Thin", "Rock Path Square Thin"]
	var petites := ["Rock Path Round Small", "Rock Path Square Smal", "Rock Path Round Small-GMttpOEFKT"]
	for i in CHEMIN.size() - 1:
		var a: Vector2 = CHEMIN[i]
		var b: Vector2 = CHEMIN[i + 1]
		var pas := int(a.distance_to(b) / 2.6)
		for k in pas:
			if rng.randf() < 0.12:
				continue  # une dalle manquante de temps en temps
			var p := a.lerp(b, float(k) / pas) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6))
			poser(g, au_hasard(dalles), p, rng.randf_range(0.85, 1.1))
			if rng.randf() < 0.35:
				var cote := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 2.2
				poser(g, au_hasard(petites), p + cote, rng.randf_range(0.6, 0.9))
			if rng.randf() < 0.3:
				var bord := p + Vector2(rng.randf_range(-1, 1), 1).normalized() * rng.randf_range(2.5, 3.5) * (1 if rng.randf() < 0.5 else -1)
				if libre(bord):
					poser(g, au_hasard(HERBES), bord, rng.randf_range(0.5, 0.8))


func clairiere_depart() -> void:
	var g := groupe("ClairiereDepart")
	for i in 7:
		var p := Vector2(-35, 0) + Vector2.from_angle(TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)) * rng.randf_range(4.5, 5.5)
		poser(g, au_hasard(PETALES + ["Clover", "Clover-u5SOgBFiut"]), p, rng.randf_range(0.7, 1.0))
	touffe(g, Vector2(-38, -5), 2.0, 5, CAILLOUX, Vector2(0.8, 1.2))
	poser(g, "Mushroom", Vector2(-39, 4.5), 0.9)
	poser(g, "Mushroom", Vector2(-38.2, 5.4), 0.6)


func massifs() -> void:
	var g := groupe("Massifs")
	# fleurs
	touffe(g, Vector2(-31, 12), 3.5, 9, FLEURS, Vector2(0.5, 0.8))
	touffe(g, Vector2(-31, 12), 4.0, 8, PETALES)
	touffe(g, Vector2(-9, 13.5), 3.0, 8, FLEURS, Vector2(0.5, 0.75))
	touffe(g, Vector2(5, -12.5), 3.0, 7, FLEURS, Vector2(0.5, 0.8))
	touffe(g, Vector2(-20, -14), 2.5, 6, PETALES)
	# hautes herbes dans les coins
	touffe(g, Vector2(-38, 14), 4.0, 12, HERBES, Vector2(0.5, 0.9))
	touffe(g, Vector2(17, 14), 4.0, 11, HERBES, Vector2(0.5, 0.9))
	touffe(g, Vector2(-6, -15), 3.5, 9, HERBES, Vector2(0.5, 0.8))
	touffe(g, Vector2(-17, 11), 2.5, 6, HERBES, Vector2(0.5, 0.7))
	# trèfles à l'ombre du fond
	touffe(g, Vector2(-37, -14), 3.0, 7, ["Clover", "Clover-u5SOgBFiut", "Plant", "Plant-xH5gNlQxAZ"])
	touffe(g, Vector2(10, -15.5), 2.5, 5, ["Clover", "Plant", "Fern"], Vector2(0.4, 0.6))
	# quelques touffes isolées
	for i in 18:
		var p := Vector2(rng.randf_range(ARENE_MIN.x + 2, ARENE_MAX.x - 2), rng.randf_range(ARENE_MIN.y + 2, ARENE_MAX.y - 2))
		if libre(p, 1.0):
			poser(g, au_hasard(HERBES), p, rng.randf_range(0.5, 0.75))


func rochers() -> void:
	var g := groupe("Rochers")
	# un gros, un moyen, un petit : ça fait plus naturel qu'un rocher seul
	var formations := [
		[Vector2(-18, -12.5), Vector2(1.6, 1.2)],
		[Vector2(-31, -10), Vector2(-1.4, 1.5)],
		[Vector2(7, 15), Vector2(1.6, -1.0)],
		[Vector2(-12, 9), Vector2(1.5, 1.3)],
	]
	for f in formations:
		var c: Vector2 = f[0]
		var d: Vector2 = f[1]
		poser(g, au_hasard(ROCHERS), c, 1.1, 3.4)
		poser(g, au_hasard(ROCHERS), c + d * 1.6, 0.7, 2.2)
		poser(g, au_hasard(ROCHERS), c - d.orthogonal() * 1.5, 0.4)
		touffe(g, c + d, 3.0, 5, CAILLOUX, Vector2(1.0, 1.5))
		touffe(g, c - d, 2.0, 3, HERBES, Vector2(0.5, 0.7))


func haie_vers_la_porte() -> void:
	var g := groupe("Haie")
	for cote in [-1, 1]:
		var a := Vector2(1.5, 11.5 * cote)
		var b := Vector2(10, 6 * cote)
		for i in 5:
			var p := a.lerp(b, i / 4.0) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
			poser(g, au_hasard(BUISSONS), p, rng.randf_range(0.9, 1.2), 2.0)
		touffe(g, a.lerp(b, 0.5) + Vector2(0, 2.5 * cote), 2.0, 4, PETALES)


func foret() -> void:
	var g := groupe("Foret")
	# bosquets le long du fond (côtés -Z puis -X), avec des trouées
	var centres: Array[Vector2] = []
	var x := ARENE_MIN.x - 8.0
	while x < ARENE_MAX.x + 12:
		if rng.randf() > 0.15:
			centres.append(Vector2(x, ARENE_MIN.y - rng.randf_range(6, 14)))
		x += rng.randf_range(8, 13)
	var z := ARENE_MIN.y
	while z < ARENE_MAX.y + 10:
		if rng.randf() > 0.15:
			centres.append(Vector2(ARENE_MIN.x - rng.randf_range(6, 14), z))
		z += rng.randf_range(8, 13)
	for c in centres:
		var famille := PINS if rng.randf() < 0.45 else ARBRES
		for i in rng.randi_range(3, 6):
			poser(g, au_hasard(famille), c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), rng.randf_range(0.8, 1.25))
		touffe(g, c + Vector2(4, 4), 4.0, 4, BUISSONS + ["Fern", "Mushroom"], Vector2(0.7, 1.0))
	# deuxième rang, plus loin, pour boucher le fond
	for i in 45:
		var p := Vector2(rng.randf_range(ARENE_MIN.x - 50, ARENE_MAX.x + 15), rng.randf_range(ARENE_MIN.y - 45, ARENE_MIN.y - 18))
		if rng.randf() < 0.4:
			p = Vector2(rng.randf_range(ARENE_MIN.x - 50, ARENE_MIN.x - 18), rng.randf_range(ARENE_MIN.y - 20, ARENE_MAX.y + 15))
		poser(g, au_hasard(ARBRES + PINS), p, rng.randf_range(0.9, 1.3))
	poser(g, "Twisted Tree-8oraKn9m0x", Vector2(-50, -28), 0.9)
	poser(g, "Twisted Tree", Vector2(-14, -31), 0.85)
	poser(g, "Dead Tree-MlmK5488ou", Vector2(4, -25), 0.8)
	poser(g, "Twisted Tree-GVTsMmuzv7", Vector2(-56, 6), 0.9)


func premier_plan() -> void:
	# devant (côtés +X et +Z) : que des choses basses, en petits groupes
	var g := groupe("PremierPlan")
	var centres: Array[Vector2] = []
	var x := ARENE_MIN.x - 5.0
	while x < ARENE_MAX.x + 25:
		centres.append(Vector2(x, ARENE_MAX.y + rng.randf_range(4, 16)))
		x += rng.randf_range(7, 12)
	var z := ARENE_MIN.y - 5.0
	while z < ARENE_MAX.y + 5:
		centres.append(Vector2(ARENE_MAX.x + rng.randf_range(4, 16), z))
		z += rng.randf_range(7, 12)
	for c in centres:
		match rng.randi() % 3:
			0:
				touffe(g, c, 3.0, 3, BUISSONS, Vector2(0.8, 1.1))
				touffe(g, c, 4.0, 4, FLEURS, Vector2(0.5, 0.8))
			1:
				poser(g, au_hasard(ROCHERS), c, 0.6)
				touffe(g, c, 3.0, 6, HERBES + CAILLOUX, Vector2(0.6, 1.0))
			2:
				touffe(g, c, 4.0, 9, HERBES + PETALES, Vector2(0.5, 0.9))
