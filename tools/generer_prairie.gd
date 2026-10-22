# Génère le décor de la Prairie -> Scenes/Levels/Prairie.tscn
# Relancer écrase les retouches faites à la main dans la scène.
# godot --headless --path . --script res://tools/generer_prairie.gd
#
# Parcours : départ à l'ouest, labyrinthe de haies (clé 1) au sud-ouest,
# rivière à traverser (gué de pierres risqué ou pont au nord), enclos (clé 2)
# au nord-est (portail ou muret à sauter), sortie au sud-est.

extends SceneTree

const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Prairie.tscn"
const ECHELLE := 2.5
const SOL_Y := 0.97
const ARENE_MIN := Vector2(-41.0, -18.0)
const ARENE_MAX := Vector2(21.5, 19.2)

const DEPART := Vector2(-36, -1)
const CLE_1 := Vector2(-25, 16)
const CLE_2 := Vector2(15, -14)
const SORTIE_POS := Vector2(17, 13)

const RIVIERE := Rect2(-21, -20, 14, 41)  # x de -21 à -7
const PONT := Rect2(-23, -16, 18, 6)       # au nord
const GUE := [Vector2(-17.5, 1), Vector2(-12.5, 1.5)]
const PIERRE_RAYON := 2.0

# segments [début, fin]
const HAIES := [[Vector2(-41, 5), Vector2(-27, 5)], [Vector2(-35, 12), Vector2(-21, 12)]]
const CLOTURES := [
	[Vector2(4, -18), Vector2(4, -15)], [Vector2(4, -10), Vector2(4, -7)],  # enclos, côté portail
	[Vector2(4, -7), Vector2(12, -7)], [Vector2(17, -7), Vector2(21.5, -7)],
	[Vector2(-7, 4), Vector2(10, 4)],                                       # barrière avant la sortie
]
const MURETS := [
	[Vector2(12, -7), Vector2(17, -7)],    # raccourci dans l'enclos
	[Vector2(-33, -9), Vector2(-24, -9)],  # sur la route du pont
	[Vector2(14, 8), Vector2(21.5, 8)],    # devant la sortie
]
const CHEMINS := [
	[Vector2(-33, -1), Vector2(-28, 0.5), Vector2(-23, 1)],
	[Vector2(-6, 1.5), Vector2(-2, -2), Vector2(0, -7), Vector2(2, -12.5), Vector2(6, -12.5)],
	[Vector2(13, -3), Vector2(14, 1), Vector2(12, 6), Vector2(13, 10), Vector2(15, 12)],
	[Vector2(-34, -4), Vector2(-35, -11), Vector2(-28, -13), Vector2(-24, -13)],
]

# on ne pose rien dessus (x, z, rayon)
const ZONES_LIBRES := [
	Vector3(-36, -1, 4.5), Vector3(-25, 16, 3.0), Vector3(15, -14, 3.0),
	Vector3(17, 13, 5.0), Vector3(20.6, 13, 3.0), Vector3(0, -6, 3.5),
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
var mat_bois: StandardMaterial3D
var mat_bois_clair: StandardMaterial3D
var mat_pierre: StandardMaterial3D


func _init() -> void:
	rng.seed = 7
	decor = Node3D.new()
	decor.name = "Prairie"
	mat_bois = couleur(Color(0.5, 0.33, 0.18))
	mat_bois_clair = couleur(Color(0.62, 0.43, 0.25))
	mat_pierre = couleur(Color(0.55, 0.55, 0.52))

	sol_exterieur()
	limites()
	riviere()
	pont()
	gue()
	haies()
	clotures()
	murets()
	chemins()
	massifs()
	rochers()
	foret()
	premier_plan()

	var packed := PackedScene.new()
	packed.pack(decor)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE.get_base_dir()))
	print("Prairie : ", ResourceSaver.save(packed, SORTIE))
	quit()


# ── outils ───────────────────────────────────────────

func couleur(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func groupe(nom: String) -> Node3D:
	var g := Node3D.new()
	g.name = nom
	decor.add_child(g)
	g.owner = decor
	return g


func ajouter(parent: Node, n: Node) -> Node:
	parent.add_child(n)
	n.owner = decor
	return n


func boite(parent: Node, taille: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	b.material = mat
	m.mesh = b
	m.position = pos
	m.rotation = rot
	return ajouter(parent, m)


func mur_invisible(parent: Node, a: Vector2, b: Vector2, hauteur: float, epaisseur: float) -> void:
	var body := StaticBody3D.new()
	var mid := (a + b) / 2
	body.position = Vector3(mid.x, SOL_Y + hauteur / 2, mid.y)
	body.rotation.y = -(b - a).angle()
	ajouter(parent, body)
	var forme := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(a.distance_to(b), hauteur, epaisseur)
	forme.shape = box
	ajouter(body, forme)


func poser(parent: Node3D, modele: String, pos: Vector2, taille := 1.0, collision := 0.0, y := SOL_Y) -> void:
	if not cache.has(modele):
		cache[modele] = load(KIT + modele + ".glb")
	var inst: Node3D = cache[modele].instantiate()
	inst.scale = Vector3.ONE * ECHELLE * taille
	inst.rotation.y = rng.randf() * TAU
	var support := parent
	if collision > 0.0:
		var body := StaticBody3D.new()
		body.position = Vector3(pos.x, y, pos.y)
		ajouter(parent, body)
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = collision
		cyl.height = 5.0
		forme.shape = cyl
		forme.position.y = 2.5
		ajouter(body, forme)
		support = body
	else:
		inst.position = Vector3(pos.x, y, pos.y)
	ajouter(support, inst)


func dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a + (b - a) * t)


func libre(p: Vector2, marge := 0.5) -> bool:
	for z in ZONES_LIBRES:
		if p.distance_to(Vector2(z.x, z.y)) < z.z + marge:
			return false
	if RIVIERE.grow(1.0).has_point(p) or PONT.grow(0.5).has_point(p):
		return false
	for s in HAIES + CLOTURES + MURETS:
		if dist_segment(p, s[0], s[1]) < 1.6 + marge:
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


# ── terrain ──────────────────────────────────────────

func sol_exterieur() -> void:
	var sol := MeshInstance3D.new()
	sol.name = "SolExterieur"
	var plan := PlaneMesh.new()
	plan.size = Vector2(400, 400)
	plan.material = couleur(Color(0.3, 0.55, 0.22))
	sol.mesh = plan
	sol.position = Vector3(-10, SOL_Y - 0.08, 0)
	ajouter(decor, sol)


func limites() -> void:
	var g := groupe("Limites")
	mur_invisible(g, Vector2(ARENE_MIN.x - 1, ARENE_MIN.y - 2), Vector2(ARENE_MIN.x - 1, ARENE_MAX.y + 2), 20, 2)
	mur_invisible(g, Vector2(ARENE_MAX.x + 1, ARENE_MIN.y - 2), Vector2(ARENE_MAX.x + 1, ARENE_MAX.y + 2), 20, 2)
	mur_invisible(g, Vector2(ARENE_MIN.x - 2, ARENE_MIN.y - 1), Vector2(ARENE_MAX.x + 2, ARENE_MIN.y - 1), 20, 2)
	mur_invisible(g, Vector2(ARENE_MIN.x - 2, ARENE_MAX.y + 1), Vector2(ARENE_MAX.x + 2, ARENE_MAX.y + 1), 20, 2)

	# une haie de buissons sur les murs invisibles pour qu'on voie la limite
	# (plus basse côté caméra, +X et +Z, pour ne pas cacher le jeu)
	var bords := [
		[Vector2(ARENE_MIN.x - 1, ARENE_MIN.y - 1), Vector2(ARENE_MAX.x + 1, ARENE_MIN.y - 1), 1.0],
		[Vector2(ARENE_MIN.x - 1, ARENE_MIN.y - 1), Vector2(ARENE_MIN.x - 1, ARENE_MAX.y + 1), 1.0],
		[Vector2(ARENE_MAX.x + 1, ARENE_MIN.y - 1), Vector2(ARENE_MAX.x + 1, ARENE_MAX.y + 1), 0.75],
		[Vector2(ARENE_MIN.x - 1, ARENE_MAX.y + 1), Vector2(ARENE_MAX.x + 1, ARENE_MAX.y + 1), 0.75],
	]
	for b in bords:
		var n := int(b[0].distance_to(b[1]) / 2.3)
		for i in n + 1:
			var p: Vector2 = b[0].lerp(b[1], float(i) / n) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
			poser(g, au_hasard(BUISSONS), p, b[2] * rng.randf_range(0.9, 1.2))


func riviere() -> void:
	var g := groupe("Riviere")
	var eau := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = RIVIERE.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.85, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.3
	plan.material = mat
	eau.mesh = plan
	eau.position = Vector3(RIVIERE.get_center().x, SOL_Y + 0.08, RIVIERE.get_center().y)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ajouter(g, eau)
	# zone mortelle juste au niveau du sol : les pierres et le pont sont au-dessus
	var zone := Area3D.new()
	zone.name = "Eau"
	zone.set_script(load("res://Scripts/Traps/water.gd"))
	zone.position = Vector3(RIVIERE.get_center().x, SOL_Y - 0.03, RIVIERE.get_center().y)
	ajouter(g, zone)
	var forme := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RIVIERE.size.x - 0.6, 0.3, RIVIERE.size.y)
	forme.shape = box
	ajouter(zone, forme)
	# roseaux et galets sur les berges, nénuphars sur l'eau
	for bord in [RIVIERE.position.x - 0.8, RIVIERE.end.x + 0.8]:
		var z := ARENE_MIN.y
		while z < ARENE_MAX.y:
			var p := Vector2(bord + rng.randf_range(-0.6, 0.6), z)
			if not PONT.grow(1.0).has_point(p) and absf(z - 1.2) > 3.0:
				poser(g, au_hasard(["Tall Grass", "Grass Wispy", "Grass"]) if rng.randf() < 0.7 else au_hasard(CAILLOUX), p, rng.randf_range(0.5, 0.9))
			z += rng.randf_range(1.5, 3.5)
	for i in 14:
		var p := Vector2(rng.randf_range(RIVIERE.position.x + 1, RIVIERE.end.x - 1), rng.randf_range(ARENE_MIN.y + 1, ARENE_MAX.y - 1))
		if not PONT.grow(1.0).has_point(p):
			poser(g, au_hasard(PETALES), p, rng.randf_range(0.8, 1.3), 0.0, SOL_Y + 0.1)


func pont() -> void:
	var g := groupe("Pont")
	var haut := SOL_Y + 0.25
	var body := StaticBody3D.new()
	body.position = Vector3(PONT.get_center().x, haut - 0.2, PONT.get_center().y)
	ajouter(g, body)
	var forme := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PONT.size.x, 0.4, PONT.size.y)
	forme.shape = box
	ajouter(body, forme)
	var x := PONT.position.x + 0.4
	while x < PONT.end.x:
		var c := mat_bois if rng.randf() < 0.5 else mat_bois_clair
		boite(g, Vector3(0.75, 0.3, PONT.size.y), Vector3(x, haut - 0.15, PONT.get_center().y + rng.randf_range(-0.1, 0.1)), c, Vector3(0, rng.randf_range(-0.03, 0.03), 0))
		x += 0.85
	# garde-corps (on ne tombe pas du pont par accident)
	for z in [PONT.position.y + 0.3, PONT.end.y - 0.3]:
		mur_invisible(g, Vector2(PONT.position.x + 2, z), Vector2(PONT.end.x - 2, z), 6, 0.6)
		boite(g, Vector3(PONT.size.x - 4, 0.25, 0.25), Vector3(PONT.get_center().x, haut + 1.6, z), mat_bois)
		var px := PONT.position.x + 2
		while px <= PONT.end.x - 2:
			boite(g, Vector3(0.35, 1.9, 0.35), Vector3(px, haut + 0.8, z), mat_bois)
			px += 3.5


func gue() -> void:
	var g := groupe("Gue")
	var mesh := CylinderMesh.new()
	mesh.top_radius = PIERRE_RAYON
	mesh.bottom_radius = PIERRE_RAYON * 1.15
	mesh.height = 0.8
	mesh.radial_segments = 9
	mesh.material = mat_pierre
	for c in GUE:
		var body := StaticBody3D.new()
		body.position = Vector3(c.x, SOL_Y - 0.05, c.y)
		ajouter(g, body)
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = PIERRE_RAYON
		cyl.height = 0.8
		forme.shape = cyl
		ajouter(body, forme)
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.rotation.y = rng.randf() * TAU
		ajouter(body, m)
		for i in 3:
			poser(g, au_hasard(CAILLOUX), c + Vector2.from_angle(rng.randf() * TAU) * (PIERRE_RAYON + 0.4), 1.2, 0.0, SOL_Y + 0.05)


func haies() -> void:
	# haies de buissons qu'on ne peut pas sauter
	var g := groupe("Haies")
	for s in HAIES:
		mur_invisible(g, s[0], s[1], 12, 2.4)
		var n := int(s[0].distance_to(s[1]) / 2.0)
		for i in n + 1:
			poser(g, au_hasard(BUISSONS), s[0].lerp(s[1], float(i) / n) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)), rng.randf_range(1.0, 1.25))


func clotures() -> void:
	var g := groupe("Clotures")
	for s in CLOTURES:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var angle := -(b - a).angle()
		mur_invisible(g, a, b, 12, 0.8)  # trop haut pour être sauté
		var n := maxi(int(a.distance_to(b) / 3.0), 1)
		var pas := (b - a) / n
		for i in n + 1:
			var p := a + pas * i
			boite(g, Vector3(0.5, 3.4, 0.5), Vector3(p.x, SOL_Y + 1.6, p.y), mat_bois, Vector3(rng.randf_range(-0.06, 0.06), angle + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.06, 0.06)))
			if i == n:
				continue
			var m := p + pas / 2
			for h in [1.2, 2.5]:
				boite(g, Vector3(pas.length() + 0.1, 0.3, 0.2), Vector3(m.x, SOL_Y + h + rng.randf_range(-0.08, 0.08), m.y), mat_bois_clair, Vector3(0, angle, rng.randf_range(-0.04, 0.04)))


func murets() -> void:
	# murets de pierre assez bas pour être sautés
	var g := groupe("Murets")
	for s in MURETS:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var angle := -(b - a).angle()
		mur_invisible(g, a, b, 2.0, 1.2)
		var n := maxi(int(a.distance_to(b) / 1.4), 1)
		for i in n:
			var p := a.lerp(b, (i + 0.5) / n)
			var c := couleur(Color(0.52, 0.52, 0.5).lerp(Color(0.62, 0.6, 0.55), rng.randf()))
			boite(g, Vector3(1.45, rng.randf_range(1.4, 1.8), 1.1), Vector3(p.x, SOL_Y + 0.8, p.y), c, Vector3(0, angle + rng.randf_range(-0.08, 0.08), 0))
		touffe(g, (a + b) / 2, a.distance_to(b) / 2, 5, HERBES + ["Clover"], Vector2(0.4, 0.7))


func chemins() -> void:
	var g := groupe("Chemins")
	var dalles := ["Rock Path Round Wide", "Rock Path Square Wide", "Rock Path Round Thin", "Rock Path Square Thin"]
	var petites := ["Rock Path Round Small", "Rock Path Square Smal", "Rock Path Round Small-GMttpOEFKT"]
	for chemin in CHEMINS:
		for i in chemin.size() - 1:
			var a: Vector2 = chemin[i]
			var b: Vector2 = chemin[i + 1]
			var pas := maxi(int(a.distance_to(b) / 2.6), 1)
			for k in pas:
				if rng.randf() < 0.12:
					continue  # une dalle manquante de temps en temps
				var p := a.lerp(b, float(k) / pas) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5))
				poser(g, au_hasard(dalles), p, rng.randf_range(0.85, 1.1))
				if rng.randf() < 0.35:
					poser(g, au_hasard(petites), p + Vector2.from_angle(rng.randf() * TAU) * 2.2, rng.randf_range(0.6, 0.9))


# ── végétation ───────────────────────────────────────

func massifs() -> void:
	var g := groupe("Massifs")
	# départ : cercle de fleurs
	for i in 7:
		var p := DEPART + Vector2.from_angle(TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)) * rng.randf_range(4.8, 5.6)
		if libre(p, 0.0):
			poser(g, au_hasard(PETALES + ["Clover", "Clover-u5SOgBFiut"]), p, rng.randf_range(0.7, 1.0))
	# hautes herbes autour des clés (on les entend avant de les voir)
	touffe(g, CLE_1, 5.0, 10, ["Tall Grass", "Grass Wispy"], Vector2(0.6, 0.9))
	touffe(g, CLE_2, 5.0, 10, ["Tall Grass", "Grass Wispy"], Vector2(0.6, 0.9))
	# labyrinthe de haies : fleurs dans les couloirs
	touffe(g, Vector2(-34, 8.5), 2.0, 5, PETALES, Vector2(0.6, 0.9))
	touffe(g, Vector2(-31, 16), 3.0, 6, PETALES, Vector2(0.7, 1.0))
	# enclos : herbe haute, trèfles
	touffe(g, Vector2(9, -13), 4.0, 8, ["Clover", "Clover-u5SOgBFiut", "Grass"], Vector2(0.6, 0.9))
	# est : massifs de fleurs
	touffe(g, Vector2(-1, 12), 3.5, 9, FLEURS, Vector2(0.5, 0.8))
	touffe(g, Vector2(5, 15), 3.0, 7, PETALES)
	touffe(g, Vector2(-3, -15), 3.0, 7, FLEURS + PETALES, Vector2(0.5, 0.8))
	# ouest : prairie
	touffe(g, Vector2(-38, -15), 3.0, 8, HERBES, Vector2(0.5, 0.8))
	touffe(g, Vector2(-27, -4), 2.5, 5, FLEURS, Vector2(0.5, 0.75))
	# quelques touffes isolées
	for i in 24:
		var p := Vector2(rng.randf_range(ARENE_MIN.x + 2, ARENE_MAX.x - 2), rng.randf_range(ARENE_MIN.y + 2, ARENE_MAX.y - 2))
		if libre(p, 1.0):
			poser(g, au_hasard(HERBES), p, rng.randf_range(0.5, 0.75))


func rochers() -> void:
	var g := groupe("Rochers")
	# un gros, un moyen, un petit : ça fait plus naturel qu'un rocher seul
	var formations := [
		[Vector2(-39, -16), Vector2(1.6, 0.3)],
		[Vector2(19, 17), Vector2(-1.4, -0.4)],
		[Vector2(-3, 9), Vector2(1.5, 1.2)],
	]
	for f in formations:
		var c: Vector2 = f[0]
		var d: Vector2 = f[1]
		poser(g, au_hasard(ROCHERS), c, 1.0, 3.2)
		poser(g, au_hasard(ROCHERS), c + d * 1.6, 0.65, 2.0)
		poser(g, au_hasard(ROCHERS), c - d.orthogonal() * 1.5, 0.4)
		touffe(g, c + d, 3.0, 5, CAILLOUX, Vector2(1.0, 1.5))


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
