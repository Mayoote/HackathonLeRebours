# Génère le décor du run final -> Scenes/Levels/Sortie.tscn
# godot --headless --path . --script res://tools/generer_sortie.gd
#
# Un couloir de donjon en ligne droite le long de x (vue de côté, la caméra suit le joueur) :
#  départ (la boule sort du tunnel derrière), trappe 1, trou, pics en rythme, bloc à sauter, trou,
#  trappe 2, pics décalés, trou, escalier de blocs, trappe 3, trou, dernière ligne droite,
#  grille de sortie (manivelle du piégeur) puis l'extérieur, au soleil.
# Les pièges sont dans SortieScene.tscn ; ici seulement le décor et les collisions.

extends SceneTree

const TEMPLE := preload("res://tools/generer_temple.gd")  # on reprend son shader de pierre
const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Sortie.tscn"
const SOL := 0.97
const BAS := -3.0
const LARGEUR := 10.0       # z de -5 à 5
const HAUT_MUR := 14.0
const GRILLE_X := 212.0
const FIN_X := 244.0

# tronçons de sol [x0, x1] ; entre eux : trous (vide) et emplacements des trappes
const SOLS := [
	[-6, 17.5], [22.5, 34], [40, 72], [78, 89.5], [94.5, 120],
	[126.5, 155.5], [160.5, 170], [176, FIN_X],
]
const TROUS := [[34, 40], [72, 78], [120, 126.5], [170, 176]]
# blocs pleins sur toute la largeur : [x0, x1, hauteur]
const BLOCS := [[66, 69, 2.0], [132, 136, 2.0], [136, 148, 4.0]]

var rng := RandomNumberGenerator.new()
var decor: Node3D
var cache := {}
var shader: Shader
var mat_sol: ShaderMaterial
var mat_mur: ShaderMaterial
var mat_ornement: ShaderMaterial
var mat_herbe: ShaderMaterial
var mat_bois: StandardMaterial3D
var mat_fer: StandardMaterial3D
var mat_noir: StandardMaterial3D
var mat_os: StandardMaterial3D


func _init() -> void:
	rng.seed = 71
	decor = Node3D.new()
	decor.name = "Sortie"
	shader = Shader.new()
	shader.code = TEMPLE.PIERRE
	mat_sol = pierre(Color(0.42, 0.4, 0.38), 0.18, Vector2(2.4, 1.2))
	mat_mur = pierre(Color(0.34, 0.33, 0.33), 0.12, Vector2(2.6, 1.3))
	mat_ornement = pierre(Color(0.48, 0.45, 0.41), 0.08, Vector2(1.2, 0.6))
	mat_herbe = pierre(Color(0.5, 0.46, 0.36), 0.9, Vector2(2.4, 1.2))
	mat_bois = StandardMaterial3D.new()
	mat_bois.albedo_color = Color(0.35, 0.22, 0.12)
	mat_fer = StandardMaterial3D.new()
	mat_fer.albedo_color = Color(0.22, 0.21, 0.2)
	mat_fer.metallic = 0.8
	mat_fer.roughness = 0.45
	mat_noir = StandardMaterial3D.new()
	mat_noir.albedo_color = Color(0.02, 0.02, 0.02)
	mat_os = StandardMaterial3D.new()
	mat_os.albedo_color = Color(0.86, 0.83, 0.74)

	sols()
	murs()
	trous()
	depart()
	porte_grille()
	exterieur()
	torches()
	details()

	var packed := PackedScene.new()
	packed.pack(decor)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE.get_base_dir()))
	print("Sortie : ", ResourceSaver.save(packed, SORTIE))
	quit()


# ── outils (mêmes que generer_temple.gd) ─────────────

func pierre(c: Color, mousse: float, bloc: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("couleur", c)
	m.set_shader_parameter("mousse_quantite", mousse)
	m.set_shader_parameter("bloc", bloc)
	return m


func emissif(c: Color, force: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = force
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


func cylindre(parent: Node, rayon: float, hauteur: float, pos: Vector3, mat: Material, segments := 10) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon
	c.bottom_radius = rayon
	c.height = hauteur
	c.radial_segments = segments
	c.material = mat
	m.mesh = c
	m.position = pos
	return ajouter(parent, m)


func collision(parent: Node, taille: Vector3, centre: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	ajouter(parent, body)
	var forme := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = taille
	forme.shape = box
	ajouter(body, forme)


func massif(parent: Node, x0: float, x1: float, haut: float, bas: float, mat: Material) -> void:
	var taille := Vector3(x1 - x0, haut - bas, LARGEUR)
	var centre := Vector3((x0 + x1) / 2, (haut + bas) / 2, 0)
	collision(parent, taille, centre)
	boite(parent, taille, centre, mat)


func poser(parent: Node3D, modele: String, pos: Vector3, taille := 1.0) -> Node3D:
	if not cache.has(modele):
		cache[modele] = load(KIT + modele + ".glb")
	var inst: Node3D = cache[modele].instantiate()
	inst.scale = Vector3.ONE * 2.5 * taille
	inst.rotation.y = rng.randf() * TAU
	inst.position = pos
	return ajouter(parent, inst)


func r(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func au_hasard(liste: Array):
	return liste[rng.randi() % liste.size()]


# ── structure ────────────────────────────────────────

func sols() -> void:
	var g := groupe("Sols")
	for s in SOLS:
		var x1: float = minf(s[1], GRILLE_X)
		massif(g, s[0], x1, SOL, BAS, mat_sol)
		if s[1] > GRILLE_X:
			massif(g, GRILLE_X, s[1], SOL, BAS, mat_herbe)  # dehors : dalles moussues
	for b in BLOCS:
		massif(g, b[0], b[1], SOL + b[2], SOL - 0.5, mat_ornement)


func murs() -> void:
	var g := groupe("Murs")
	var long := GRILLE_X + 6.0
	# mur du fond (nord), haut : il ne cache rien. Il s'arrête au sol pour que les trous paraissent noirs
	boite(g, Vector3(long, HAUT_MUR + 10 - SOL, 3), Vector3(long / 2 - 6, (HAUT_MUR + 10 + SOL) / 2, -LARGEUR / 2 - 1.5), mat_mur)
	# pilastres et poutres de plafond sur le mur du fond
	var x := -2.0
	while x < GRILLE_X - 2:
		boite(g, Vector3(1.4, HAUT_MUR - SOL, 0.4), Vector3(x, (SOL + HAUT_MUR) / 2, -LARGEUR / 2 + 0.2), mat_ornement)
		boite(g, Vector3(1.0, 0.9, LARGEUR + 1), Vector3(x, HAUT_MUR + 0.45, 0), mat_bois)
		x += 12.0
	boite(g, Vector3(long, 0.8, 0.7), Vector3(long / 2 - 6, HAUT_MUR - 0.4, -LARGEUR / 2 + 0.35), mat_ornement)
	# devant (sud) : muret bas pour ne rien cacher, la collision est haute
	x = -6.0
	for s in SOLS:
		var x0: float = s[0]
		var x1: float = minf(s[1], GRILLE_X)
		boite(g, Vector3(x1 - x0, 1.0, 0.8), Vector3((x0 + x1) / 2, SOL + 0.5, LARGEUR / 2 + 0.4), mat_ornement)
	# limites invisibles (aussi au-dessus des trous)
	for z in [-LARGEUR / 2 - 0.5, LARGEUR / 2 + 0.5]:
		collision(g, Vector3(FIN_X + 12, 60, 1), Vector3(FIN_X / 2 - 6, 10, z))
	collision(g, Vector3(1, 60, LARGEUR + 2), Vector3(-6.5, 10, 0))
	collision(g, Vector3(1, 60, LARGEUR + 2), Vector3(FIN_X + 0.5, 10, 0))


func trous() -> void:
	# le vide : on voit les bords des dalles et du noir tout au fond
	var g := groupe("Trous")
	var fond := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(400, 60)
	plan.material = mat_noir
	fond.mesh = plan
	fond.position = Vector3(100, -16, 0)
	ajouter(g, fond)
	for t in TROUS:
		# quelques pierres cassées au bord
		for x in [t[0] - 0.6, t[1] + 0.6]:
			for i in 3:
				boite(g, Vector3(r(0.5, 1.0), r(0.2, 0.5), r(0.5, 1.0)), Vector3(x + r(-0.3, 0.3), SOL + 0.1, r(-4, 4)), mat_sol, Vector3(0, r(0, TAU), 0))


func depart() -> void:
	# tunnel d'où sort la boule, derrière le joueur
	var g := groupe("Depart")
	boite(g, Vector3(1, 11, LARGEUR + 2), Vector3(-6.5, SOL + 5.5 + 3, 0), mat_mur)
	boite(g, Vector3(0.3, 9.5, 9), Vector3(-5.9, SOL + 4.75, 0), mat_noir)
	for z in [-4.8, 4.8]:
		boite(g, Vector3(1.2, 10, 0.8), Vector3(-5.6, SOL + 5, z), mat_ornement)
	boite(g, Vector3(1.4, 1.2, LARGEUR + 0.5), Vector3(-5.6, SOL + 10.3, 0), mat_ornement)
	var lbl := Label3D.new()
	lbl.text = "SORTIE  ►"
	lbl.font_size = 96
	lbl.pixel_size = 0.02
	lbl.outline_size = 16
	lbl.modulate = Color(1, 0.85, 0.5)
	lbl.position = Vector3(8, SOL + 9, -LARGEUR / 2 + 0.5)
	ajouter(g, lbl)


func porte_grille() -> void:
	# encadrement de la grille + treuil (le piégeur tourne la manivelle)
	var g := groupe("PorteGrille")
	# pilier du fond haut, pilier de devant bas (sinon il cache la grille)
	boite(g, Vector3(2.2, HAUT_MUR, 1.2), Vector3(GRILLE_X, SOL + HAUT_MUR / 2, -LARGEUR / 2 - 0.2), mat_ornement)
	boite(g, Vector3(2.2, 2.0, 1.2), Vector3(GRILLE_X, SOL + 1.0, LARGEUR / 2 + 0.2), mat_ornement)
	boite(g, Vector3(2.4, 3.5, LARGEUR + 3), Vector3(GRILLE_X, SOL + 11.6, 0), mat_ornement)
	boite(g, Vector3(0.6, 0.6, LARGEUR + 1), Vector3(GRILLE_X - 1.2, SOL + 10.5, 0), mat_bois)
	var roue := cylindre(g, 1.6, 0.4, Vector3(GRILLE_X - 1.5, SOL + 11.5, -LARGEUR / 2 + 0.6), mat_bois, 14)
	roue.rotation.x = PI / 2
	for i in 4:
		boite(g, Vector3(0.2, 3.6, 0.2), Vector3(GRILLE_X - 1.5, SOL + 11.5, -LARGEUR / 2 + 0.8), mat_fer, Vector3(0, 0, i * PI / 4))
	# chaînes
	for z in [-3.5, 3.5]:
		cylindre(g, 0.08, 4, Vector3(GRILLE_X - 0.6, SOL + 12, z), mat_fer, 5)


func exterieur() -> void:
	# derrière la grille : la lumière du jour, l'herbe et des arbres
	var g := groupe("Exterieur")
	var ciel := MeshInstance3D.new()
	var plan := QuadMesh.new()
	plan.size = Vector2(60, 40)
	plan.material = emissif(Color(0.62, 0.8, 1.0), 1.2)
	ciel.mesh = plan
	ciel.position = Vector3(GRILLE_X + 30, SOL + 12, -LARGEUR / 2 - 6)
	ajouter(g, ciel)
	var herbe := MeshInstance3D.new()
	var sol := PlaneMesh.new()
	sol.size = Vector2(40, 30)
	var vert := StandardMaterial3D.new()
	vert.albedo_color = Color(0.3, 0.5, 0.18)
	sol.material = vert
	herbe.mesh = sol
	herbe.position = Vector3(GRILLE_X + 22, SOL - 0.3, -12)
	ajouter(g, herbe)
	for i in 7:
		poser(g, au_hasard(["Tree", "Tree-QVOop92WmG", "Pine", "Twisted Tree"]), Vector3(GRILLE_X + 5 + i * 4.5 + r(-1, 1), SOL - 0.3, r(-16, -8)), r(0.7, 1.0))
	for i in 25:
		poser(g, au_hasard(["Grass Wispy", "Grass", "Flower Group", "Clover"]), Vector3(r(GRILLE_X + 2, FIN_X - 1), SOL, r(-4.5, 4.5)), r(0.3, 0.5))
	var soleil := OmniLight3D.new()
	soleil.light_color = Color(1, 0.95, 0.8)
	soleil.light_energy = 4.0
	soleil.omni_range = 30.0
	soleil.position = Vector3(GRILLE_X + 14, SOL + 14, 4)
	ajouter(g, soleil)


func torches() -> void:
	var g := groupe("Torches")
	var flamme := emissif(Color(1, 0.6, 0.15), 4.0)
	var x := 4.0
	while x < GRILLE_X - 4:
		var p := Vector3(x, SOL + 6.5, -LARGEUR / 2 + 0.5)
		boite(g, Vector3(0.3, 1.4, 0.3), p, mat_fer, Vector3(0.4, 0, 0))
		var f := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.32
		sp.height = 0.85
		sp.material = flamme
		f.mesh = sp
		f.position = p + Vector3(0, 0.95, 0.25)
		ajouter(g, f)
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.65, 0.3)
		light.light_energy = 2.4
		light.omni_range = 13.0
		light.position = p + Vector3(0, 1.4, 1.2)
		light.set_script(load("res://Scripts/torch.gd"))
		ajouter(g, light)
		x += 12.0


func details() -> void:
	# chaînes qui pendent, os, toiles, gravats contre le mur du fond (jamais dans le passage)
	var g := groupe("Details")
	var x := 9.0
	while x < GRILLE_X - 6:
		var long := r(2.5, 5.5)
		cylindre(g, 0.07, long, Vector3(x + r(-2, 2), HAUT_MUR - long / 2, -LARGEUR / 2 + 0.8), mat_fer, 5)
		x += r(9, 15)
	for i in 30:
		var px := r(0, GRILLE_X - 4)
		if not sur_le_sol(px):
			continue
		var z := -LARGEUR / 2 + r(0.5, 1.4)
		if rng.randf() < 0.4:
			var crane := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.35
			s.height = 0.6
			s.material = mat_os
			crane.mesh = s
			crane.position = Vector3(px, SOL + 0.28, z)
			ajouter(g, crane)
		else:
			boite(g, Vector3(r(0.4, 1.1), r(0.3, 0.7), r(0.4, 1.0)), Vector3(px, SOL + 0.2, z), mat_mur, Vector3(0, r(0, TAU), 0))
	for i in 12:
		var px := r(0, GRILLE_X - 4)
		boite(g, Vector3(1.0, 0.1, 0.1), Vector3(px, SOL + 0.05, -LARGEUR / 2 + r(0.6, 2)), mat_os, Vector3(0, r(0, TAU), 0))


func sur_le_sol(x: float) -> bool:
	for s in SOLS:
		if x > s[0] + 0.5 and x < s[1] - 0.5:
			return true
	return false
