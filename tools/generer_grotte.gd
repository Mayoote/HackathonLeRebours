# Génère le décor de la Grotte -> Scenes/Levels/Grotte.tscn
# godot --headless --path . --script res://tools/generer_grotte.gd
#
# Cinq galeries en serpentin (z croissant = vers la caméra), séparées par des murs :
#  G1 ouest -> est : corniche du rocher, gouffre (plateformes, trappe 1), escalade -> clé 1
#  G2 est -> ouest : gouffre avec rochers à sauter, pilier de la clé 2, éboulis
#  G3 ouest -> est : trappes 2 et 3, éboulis, plateformes à différentes hauteurs
#  G4 est -> ouest : clé 3 dans un recoin, tas de rochers (clé 4), petit gouffre
#  G5 ouest -> est : deux éboulis, sortie à l'est
# Les trous font au moins 4,5 de large (le joueur fait 3,3) : il faut sauter.
# Vue isométrique : ce qui est haut est contre un mur, jamais au milieu d'une galerie.

extends SceneTree

const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Grotte.tscn"
const SOL_Y := 0.97
const MIN := Vector2(-41.0, -18.0)
const MAX := Vector2(43.0, 28.0)
# hauteur des murs de séparation : nettement plus que le saut du joueur (3,7),
# sinon le bas arrondi du personnage accroche l'arête et il grimpe dessus
const HAUT_MUR := 5.0
const EP_MUR := 1.2

const SOLS := [
	# G1 (z -18..-10)
	Rect2(-41, -18, 21, 8),
	Rect2(-14, -15, 4, 4.5),        # plateforme 1 (la trappe 1 est entre les deux)
	Rect2(6, -15, 4, 4.5),          # plateforme 2
	Rect2(16, -18, 27, 8),
	Rect2(-41, -10, 84, 1.2),       # sous le mur 1
	# G2 (z -8.8..-0.8)
	Rect2(30, -8.8, 13, 8),
	Rect2(-41, -8.8, 49, 8),
	Rect2(-41, -0.8, 84, 1.2),      # sous le mur 2
	# G3 (z 0.4..8.4), trous des trappes 2 et 3, gouffre à l'est
	Rect2(-41, 0.4, 21, 8),
	Rect2(-15, 0.4, 15, 8),
	Rect2(5, 0.4, 9, 8),
	Rect2(-20, 0.4, 5, 1.5), Rect2(-20, 6.9, 5, 1.5),
	Rect2(0, 0.4, 5, 1.5), Rect2(0, 6.9, 5, 1.5),
	Rect2(37, 0.4, 6, 8),
	Rect2(-41, 8.4, 84, 1.2),       # sous le mur 3
	# G4 (z 9.6..17.6), petit gouffre à l'ouest
	Rect2(-12, 9.6, 55, 8),
	Rect2(-20.5, 11.6, 4, 4),
	Rect2(-41, 9.6, 16, 8),
	Rect2(-41, 17.6, 84, 1.2),      # sous le mur 4
	# G5 (z 18.8..28)
	Rect2(-41, 18.8, 84, 9.2),
]
# blocs de roche : [rect, hauteur du dessus]
const BLOCS := [
	[Rect2(-33, -18, 9, 3), 9.0],           # corniche du rocher (plus haute que le joueur)
	[Rect2(18, -18, 2.5, 3.5), 2.0],        # escalade : bloc
	[Rect2(21.1, -16.6, 1.6, 1.6), 4.0],    # escalade : prise
	[Rect2(23.5, -18, 4.5, 3.5), 6.0],      # escalade : corniche de la clé 1
	[Rect2(19, 2.4, 4, 4), 1.0],            # G3 : plateformes à différentes hauteurs
	[Rect2(27, 2.4, 4, 4), 2.0],
	[Rect2(2, 14.6, 3, 3), 2.0],            # G4 : tas de rochers de la clé 4 (contre le mur 4)
	[Rect2(5, 15.6, 3, 2), 4.0],
]
# rochers à sauter dans le gouffre de G2 : [centre, rayon, hauteur]
const ROCHERS_SAUT := [
	[Vector2(25.5, -4.8), 1.8, 1.5], [Vector2(18.5, -4.3), 1.8, 2.5], [Vector2(11.5, -4.8), 1.8, 1.5],
	[Vector2(18.5, -7.4), 1.2, 4.5],        # pilier de la clé 2 (contre le mur 1)
]
# murs entre les galeries : [z, x début, x fin] (ouvertures en serpentin)
const MURS := [[-9.4, -41, 35], [-0.2, -33, 43], [9.0, -41, 35], [18.2, -33, 43]]
# éboulis bas à sauter
const EBOULIS := [
	[Vector2(-15, -8.8), Vector2(-15, -0.8)], [Vector2(-8, 0.4), Vector2(-8, 8.4)],
	[Vector2(-10, 18.8), Vector2(-10, 28)], [Vector2(15, 18.8), Vector2(15, 28)],
]

var rng := RandomNumberGenerator.new()
var decor: Node3D
var cache := {}
var mat_cote: StandardMaterial3D
var mat_dessus: StandardMaterial3D
var mat_paroi: StandardMaterial3D
var mat_bloc: StandardMaterial3D


func _init() -> void:
	rng.seed = 45
	decor = Node3D.new()
	decor.name = "Grotte"
	mat_cote = roche(Color(0.24, 0.21, 0.19), 0.35)
	mat_dessus = roche(Color(0.46, 0.41, 0.36), 0.25)
	mat_paroi = roche(Color(0.2, 0.19, 0.18), 0.12)
	mat_bloc = roche(Color(0.38, 0.35, 0.33), 0.3)

	sols()
	blocs()
	rochers_saut()
	bords()
	murs()
	eboulis()
	cristaux()
	torches()
	details()

	var packed := PackedScene.new()
	packed.pack(decor)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE.get_base_dir()))
	print("Grotte : ", ResourceSaver.save(packed, SORTIE))
	quit()


# ── matériaux ────────────────────────────────────────

# texture de roche procédurale (bruit + relief), plaquée en triplanaire
func roche(c: Color, echelle: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	noise.seed = rng.randi()
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([c.darkened(0.35), c, c.lightened(0.15)])
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.seamless = true
	var relief := NoiseTexture2D.new()
	relief.noise = noise
	relief.seamless = true
	relief.as_normal_map = true
	relief.bump_strength = 6.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = relief
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * echelle
	return m


# ── outils ───────────────────────────────────────────

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


func collision(parent: Node, taille: Vector3, centre: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	ajouter(parent, body)
	var forme := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = taille
	forme.shape = box
	ajouter(body, forme)


# dalle praticable : côtés sombres + dessus plus clair (on voit bien où marcher)
func dalle(parent: Node, rect: Rect2, haut: float, epaisseur: float) -> void:
	var c := rect.get_center()
	collision(parent, Vector3(rect.size.x, epaisseur, rect.size.y), Vector3(c.x, haut - epaisseur / 2, c.y))
	boite(parent, Vector3(rect.size.x, epaisseur - 0.15, rect.size.y), Vector3(c.x, haut - 0.15 - (epaisseur - 0.15) / 2, c.y), mat_cote)
	boite(parent, Vector3(rect.size.x, 0.15, rect.size.y), Vector3(c.x, haut - 0.075, c.y), mat_dessus)


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


func poser(parent: Node3D, modele: String, pos: Vector3, taille := 1.0) -> Node3D:
	if not cache.has(modele):
		cache[modele] = load(KIT + modele + ".glb")
	var inst: Node3D = cache[modele].instantiate()
	inst.scale = Vector3.ONE * 2.5 * taille
	inst.rotation.y = rng.randf() * TAU
	inst.position = pos
	return ajouter(parent, inst)


func rocher(parent: Node3D, pos: Vector3, taille: float) -> void:
	poser(parent, ["Rock Medium", "Rock Medium-JQxF95498B", "Rock Medium-s1OJ3bBzqc"][rng.randi() % 3], pos, taille)


func stalagmite(parent: Node3D, pos: Vector3, hauteur: float) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = hauteur * 0.2
	c.height = hauteur
	c.radial_segments = 7
	c.material = mat_bloc
	m.mesh = c
	m.position = pos + Vector3.UP * hauteur / 2
	m.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
	ajouter(parent, m)


func r(a: float, b: float) -> float:
	return rng.randf_range(a, b)


# ── structure ────────────────────────────────────────

func sols() -> void:
	var g := groupe("Sols")
	for s in SOLS:
		dalle(g, s, SOL_Y, 3.0)


func blocs() -> void:
	# piliers qui descendent sous le sol : ils ne flottent pas au-dessus du vide
	var g := groupe("Escalade")
	for b in BLOCS:
		var rect: Rect2 = b[0]
		var h: float = b[1]
		dalle(g, rect, SOL_Y + h, h + 3.0)


func rochers_saut() -> void:
	var g := groupe("RochersSaut")
	for rs in ROCHERS_SAUT:
		var c: Vector2 = rs[0]
		var ray: float = rs[1]
		var h: float = rs[2]
		var body := StaticBody3D.new()
		body.position = Vector3(c.x, SOL_Y + h - 3.0, c.y)
		ajouter(g, body)
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = ray
		cyl.height = 6.0
		forme.shape = cyl
		ajouter(body, forme)
		var cote := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = ray
		mesh.bottom_radius = ray * 0.6
		mesh.height = 5.85
		mesh.radial_segments = 9
		mesh.material = mat_cote
		cote.mesh = mesh
		cote.position.y = -0.075
		ajouter(body, cote)
		var dessus := MeshInstance3D.new()
		var disque := CylinderMesh.new()
		disque.top_radius = ray
		disque.bottom_radius = ray
		disque.height = 0.15
		disque.radial_segments = 9
		disque.material = mat_dessus
		dessus.mesh = disque
		dessus.position.y = 2.925
		ajouter(body, dessus)


func bords() -> void:
	var g := groupe("Bords")
	mur_invisible(g, Vector2(MIN.x - 1, MIN.y - 2), Vector2(MIN.x - 1, MAX.y + 2), 30, 2)
	mur_invisible(g, Vector2(MAX.x + 1, MIN.y - 2), Vector2(MAX.x + 1, MAX.y + 2), 30, 2)
	mur_invisible(g, Vector2(MIN.x - 2, MIN.y - 1), Vector2(MAX.x + 2, MIN.y - 1), 30, 2)
	mur_invisible(g, Vector2(MIN.x - 2, MAX.y + 1), Vector2(MAX.x + 2, MAX.y + 1), 30, 2)
	# fond (nord et ouest) : paroi rocheuse haute, elle ne cache rien
	boite(g, Vector3(MAX.x - MIN.x + 20, 26, 8), Vector3((MIN.x + MAX.x) / 2, SOL_Y + 10, MIN.y - 5.5), mat_paroi)
	boite(g, Vector3(8, 26, MAX.y - MIN.y + 20), Vector3(MIN.x - 5.5, SOL_Y + 10, (MIN.y + MAX.y) / 2), mat_paroi)
	var x := MIN.x - 2
	while x < MAX.x + 4:
		rocher(g, Vector3(x, SOL_Y - 0.5, MIN.y - r(1.2, 2.2)), r(0.9, 1.5))
		if rng.randf() < 0.5:
			rocher(g, Vector3(x + r(-1, 1), SOL_Y + r(3, 7), MIN.y - r(1.8, 2.8)), r(0.8, 1.3))
		x += r(3.0, 4.5)
	var z := MIN.y
	while z < MAX.y + 4:
		rocher(g, Vector3(MIN.x - r(1.2, 2.2), SOL_Y - 0.5, z), r(0.9, 1.5))
		if rng.randf() < 0.5:
			rocher(g, Vector3(MIN.x - r(1.8, 2.8), SOL_Y + r(3, 7), z + r(-1, 1)), r(0.8, 1.3))
		z += r(3.0, 4.5)
	# devant (sud et est) : rien de haut, juste des rochers bas
	for bord in [[Vector2(MIN.x, MAX.y + 1.3), Vector2(MAX.x + 1.3, MAX.y + 1.3)], [Vector2(MAX.x + 1.3, MIN.y), Vector2(MAX.x + 1.3, MAX.y + 1.3)]]:
		var a: Vector2 = bord[0]
		var b: Vector2 = bord[1]
		var n := int(a.distance_to(b) / 2.4)
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			rocher(g, Vector3(p.x + r(-0.4, 0.4), SOL_Y - 0.6, p.y + r(-0.4, 0.4)), r(0.35, 0.5))
	# le vide sous les gouffres
	var fond := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(400, 400)
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.01, 0.01, 0.015)
	plan.material = noir
	fond.mesh = plan
	fond.position = Vector3(0, -14, 5)
	ajouter(g, fond)


func murs() -> void:
	# muret de roche bas + piliers de pierre fins : infranchissable (collision = silhouette)
	# mais on voit à travers, donc rien n'est caché en vue isométrique
	var g := groupe("Murs")
	var pilier := CylinderMesh.new()
	pilier.top_radius = 0.16
	pilier.bottom_radius = 0.24
	pilier.height = HAUT_MUR - 1.4
	pilier.radial_segments = 6
	pilier.material = mat_bloc
	for m in MURS:
		var z: float = m[0]
		var x0: float = m[1]
		var x1: float = m[2]
		var longueur := x1 - x0
		var mid := (x0 + x1) / 2
		collision(g, Vector3(longueur, HAUT_MUR, EP_MUR), Vector3(mid, SOL_Y + HAUT_MUR / 2, z))
		boite(g, Vector3(longueur, 1.4, EP_MUR), Vector3(mid, SOL_Y + 0.7, z), mat_bloc)
		var x := x0 + 0.4
		while x <= x1 - 0.3:
			var p := MeshInstance3D.new()
			p.mesh = pilier
			p.position = Vector3(x + r(-0.1, 0.1), SOL_Y + 1.4 + (HAUT_MUR - 1.4) / 2, z + r(-0.15, 0.15))
			p.rotation = Vector3(r(-0.04, 0.04), r(0, TAU), r(-0.04, 0.04))
			ajouter(g, p)
			x += 1.5
		# quelques cailloux au pied
		for i in int(longueur / 5.0):
			rocher(g, Vector3(r(x0 + 1, x1 - 1), SOL_Y - 0.25, z + (1.0 if rng.randf() < 0.5 else -1.0)), r(0.16, 0.22))


func eboulis() -> void:
	# murets d'éboulis assez bas pour être sautés
	var g := groupe("Eboulis")
	for s in EBOULIS:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		mur_invisible(g, a, b, 2.0, 1.4)
		var n := int(a.distance_to(b) / 1.3)
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			rocher(g, Vector3(p.x + r(-0.3, 0.3), SOL_Y - 0.3, p.y), r(0.32, 0.42))


# ── ambiance ─────────────────────────────────────────

func cristaux() -> void:
	# au bord des gouffres et contre les murs, jamais au milieu du passage
	var g := groupe("Cristaux")
	var couleurs := [Color(0.3, 0.8, 1.0), Color(0.75, 0.4, 1.0)]
	var spots := [Vector2(-20.6, -17.3), Vector2(16.6, -10.8), Vector2(30.6, -1.6), Vector2(7.4, -8.1), Vector2(14.4, 7.6), Vector2(37.6, 1.2), Vector2(-25.6, 10.4), Vector2(-11.4, 16.8), Vector2(42.2, 27.2), Vector2(-40.2, 27.2)]
	for s in spots:
		var c: Color = couleurs[rng.randi() % 2]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.0
		for i in rng.randi_range(3, 5):
			var m := MeshInstance3D.new()
			var p := PrismMesh.new()
			p.size = Vector3(r(0.4, 0.8), r(1.2, 2.4), r(0.4, 0.8))
			p.material = mat
			m.mesh = p
			m.position = Vector3(s.x + r(-0.4, 0.4), SOL_Y + p.size.y / 2 - 0.2, s.y + r(-0.4, 0.4))
			m.rotation = Vector3(r(-0.4, 0.4), r(0, TAU), r(-0.4, 0.4))
			ajouter(g, m)
		var light := OmniLight3D.new()
		light.light_color = c
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.position = Vector3(s.x, SOL_Y + 2, s.y)
		ajouter(g, light)


func torches() -> void:
	# sur les parois du fond et posées sur les murets (jamais dans un mur)
	var g := groupe("Torches")
	var flamme := StandardMaterial3D.new()
	flamme.albedo_color = Color(1, 0.6, 0.15)
	flamme.emission_enabled = true
	flamme.emission = Color(1, 0.5, 0.1)
	flamme.emission_energy_multiplier = 4.0
	var fer := StandardMaterial3D.new()
	fer.albedo_color = Color(0.15, 0.13, 0.12)
	var spots := []
	for x in [-37, -12, 14, 34]:
		spots.append(Vector2(x, MIN.y + 0.25))         # paroi du fond
	for z in [-4.8, 4.4, 13.6, 23.4]:
		spots.append(Vector2(MIN.x + 0.25, z))         # paroi ouest
	var sur_murets := []
	for m in MURS:
		for x in [-25, 0, 25]:
			if x > m[1] + 2 and x < m[2] - 2:
				sur_murets.append(Vector2(x + 0.75, m[0]))   # sur le muret, entre deux piliers
	for s in sur_murets:
		boite(g, Vector3(0.25, 1.0, 0.25), Vector3(s.x, SOL_Y + 1.9, s.y), fer)
		var fm := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.3
		fs.height = 0.8
		fs.material = flamme
		fm.mesh = fs
		fm.position = Vector3(s.x, SOL_Y + 2.7, s.y)
		ajouter(g, fm)
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.65, 0.3)
		l.light_energy = 2.4
		l.omni_range = 13.0
		l.position = Vector3(s.x, SOL_Y + 3.2, s.y)
		l.set_script(load("res://Scripts/torch.gd"))
		ajouter(g, l)
	for s in spots:
		boite(g, Vector3(0.25, 0.9, 0.25), Vector3(s.x, SOL_Y + 3.0, s.y), fer)
		var f := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.3
		sp.height = 0.8
		sp.material = flamme
		f.mesh = sp
		f.position = Vector3(s.x, SOL_Y + 3.7, s.y)
		ajouter(g, f)
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.65, 0.3)
		light.light_energy = 2.4
		light.omni_range = 13.0
		light.position = Vector3(s.x, SOL_Y + 4.0, s.y + (0.6 if s.y > MIN.y + 1 else 0.8))
		light.set_script(load("res://Scripts/torch.gd"))
		ajouter(g, light)


func details() -> void:
	# quelques détails dans les coins, loin du passage
	var g := groupe("Details")
	var coins := [Vector2(-39.5, -11.2), Vector2(41.5, -11.2), Vector2(41.5, -2), Vector2(-39.5, 7.2), Vector2(41.5, 7.2), Vector2(-39.5, 16.5), Vector2(-39.5, 26.5), Vector2(41.5, 19.8)]
	for c in coins:
		for i in rng.randi_range(1, 2):
			stalagmite(g, Vector3(c.x + r(-0.8, 0.8), SOL_Y, c.y + r(-0.4, 0.4)), r(1.5, 2.8))
		poser(g, "Mushroom", Vector3(c.x + r(-1, 1), SOL_Y, c.y + r(-0.5, 0.5)), r(0.7, 1.0))
	# recoin de la clé 3 : quelques rochers devant
	for p in [Vector2(38, 16.8), Vector2(39, 14.2)]:
		rocher(g, Vector3(p.x, SOL_Y - 0.3, p.y), r(0.4, 0.5))
