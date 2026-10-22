# Génère le décor de la Grotte -> Scenes/Levels/Grotte.tscn
# godot --headless --path . --script res://tools/generer_grotte.gd
#
# Quatre galeries en serpentin (z croissant = vers la caméra) :
#  G1 ouest -> est : corniche du rocher, gouffre (plateformes, trappe 1), escalade vers la clé 1
#  G2 est -> ouest : gouffre avec rochers à sauter, pilier de la clé 2
#  G3 ouest -> est : trappes 2 et 3, éboulis à sauter
#  G4 est -> ouest : clé 3 dans un recoin, clé 4 en haut d'un tas de rochers, sortie à l'ouest
# Les trous font au moins 6 de large (le joueur fait 3,3) : il faut vraiment sauter.
# Vue isométrique : tout ce qui est haut est contre le mur du fond (nord / ouest).

extends SceneTree

const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Grotte.tscn"
const SOL_Y := 0.97
const MIN := Vector2(-41.0, -18.0)
const MAX := Vector2(21.5, 19.2)

const SOLS := [
	# G1 (z -18..-9)
	Rect2(-41, -18, 17, 9),
	Rect2(-18, -15.5, 4, 5),      # plateforme 1 (la 2 est la trappe 1)
	Rect2(2, -15.5, 4, 5),        # plateforme 3
	Rect2(12, -18, 9.5, 9),
	# séparation 1 + passage à l'est
	Rect2(-41, -9, 62.5, 2),
	# G2 (z -7..0)
	Rect2(8, -7, 13.5, 7),
	Rect2(-41, -7, 27, 7),
	# séparation 2 + passage à l'ouest
	Rect2(-41, 0, 62.5, 2),
	# G3 (z 2..9), trous des trappes 2 et 3
	Rect2(-41, 2, 21, 7),
	Rect2(-15, 2, 11, 7),
	Rect2(1, 2, 20.5, 7),
	Rect2(-20, 2, 5, 1), Rect2(-20, 8, 5, 1),
	Rect2(-4, 2, 5, 1), Rect2(-4, 8, 5, 1),
	# séparation 3 + passage à l'est
	Rect2(-41, 9, 62.5, 2),
	# G4 (z 11..19.2)
	Rect2(-41, 11, 62.5, 8.2),
]
# blocs de roche : [rect, hauteur]
const BLOCS := [
	[Rect2(-35, -18, 9, 3), 9.0],          # corniche du rocher (plus haute que le joueur)
	[Rect2(12.5, -18, 2.5, 3.5), 2.0],     # escalade : bloc
	[Rect2(15.6, -16.6, 1.6, 1.6), 4.0],   # escalade : prise
	[Rect2(18, -18, 3.5, 3.5), 6.0],       # escalade : corniche de la clé 1
	[Rect2(-12, 15.5, 3, 3.7), 2.0],       # tas de rochers de la clé 4
	[Rect2(-9, 16.5, 3, 2.7), 4.0],
]
# rochers à sauter dans le gouffre de G2 : [centre, rayon, hauteur]
const ROCHERS_SAUT := [
	[Vector2(4, -3), 1.8, 1.5], [Vector2(-3, -2.5), 1.8, 2.5], [Vector2(-10, -3), 1.8, 1.5],
	[Vector2(-3, -6.3), 1.2, 4.5],        # pilier de la clé 2 (contre le mur nord)
]
# séparations infranchissables (visuellement basses)
const SEPARATIONS := [[Vector2(-41, -8), Vector2(14, -8)], [Vector2(-33, 1), Vector2(21.5, 1)], [Vector2(-41, 10), Vector2(14, 10)]]
# éboulis bas à sauter
# hauteur des murs de séparation : nettement plus que le saut du joueur (3,7),
# sinon le bas arrondi du personnage accroche l'arête et il grimpe dessus
const HAUT_MUR := 5.0
const EBOULIS := [[Vector2(-10, 2), Vector2(-10, 9)], [Vector2(6, 11), Vector2(6, 15)]]

var rng := RandomNumberGenerator.new()
var decor: Node3D
var cache := {}
var mat_cote: StandardMaterial3D
var mat_dessus: StandardMaterial3D
var mat_paroi: StandardMaterial3D
var mat_bloc: StandardMaterial3D


func _init() -> void:
	rng.seed = 33
	decor = Node3D.new()
	decor.name = "Grotte"
	mat_cote = roche(Color(0.24, 0.21, 0.19), 0.35)
	mat_dessus = roche(Color(0.46, 0.41, 0.36), 0.25)
	mat_paroi = roche(Color(0.2, 0.19, 0.18), 0.12)
	mat_bloc = roche(Color(0.38, 0.35, 0.33), 0.3)

	sols()
	blocs()
	rochers_saut()
	murs()
	separations()
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
	var g := groupe("Escalade")
	for b in BLOCS:
		var rect: Rect2 = b[0]
		var h: float = b[1]
		dalle(g, rect, SOL_Y + h, h)


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


func murs() -> void:
	var g := groupe("Murs")
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
	plan.size = Vector2(300, 300)
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.01, 0.01, 0.015)
	plan.material = noir
	fond.mesh = plan
	fond.position = Vector3(-10, -14, 0)
	ajouter(g, fond)


func separations() -> void:
	# vrais murs de roche : la collision a exactement la taille du visuel.
	# Ils deviennent transparents quand le joueur passe derrière (vue isométrique).
	var g := groupe("Separations")
	for s in SEPARATIONS:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var longueur := a.distance_to(b)
		var mid := (a + b) / 2
		collision(g, Vector3(longueur, HAUT_MUR, 1.2), Vector3(mid.x, SOL_Y + HAUT_MUR / 2, a.y))
		var mat := roche(Color(0.33, 0.3, 0.28), 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mur := Node3D.new()
		mur.set_script(load("res://Scripts/fade_wall.gd"))
		mur.set("material", mat)
		mur.set("wall_z", a.y)
		mur.set("x_range", Vector2(a.x, b.x))
		ajouter(g, mur)
		boite(mur, Vector3(longueur, HAUT_MUR, 1.2), Vector3(mid.x, SOL_Y + HAUT_MUR / 2, a.y), mat)
		# sommet irrégulier
		var x := a.x
		while x < b.x:
			var w := r(1.5, 3.5)
			boite(mur, Vector3(w, r(0.2, 0.7), r(1.0, 1.3)), Vector3(minf(x + w / 2, b.x - 0.5), SOL_Y + HAUT_MUR, a.y + r(-0.1, 0.1)), mat)
			x += w + r(0.5, 2.0)
		# quelques cailloux au pied
		for i in int(longueur / 4.0):
			var p := Vector2(r(a.x, b.x), a.y + (0.9 if rng.randf() < 0.5 else -0.9))
			rocher(g, Vector3(p.x, SOL_Y - 0.2, p.y), r(0.18, 0.25))


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
	var spots := [Vector2(-23.5, -17), Vector2(11.5, -10), Vector2(-14.5, -6.5), Vector2(8.5, -0.6), Vector2(-40, -1), Vector2(20.5, 3), Vector2(-40.3, 18.5), Vector2(-12.5, 12)]
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
			m.position = Vector3(s.x + r(-0.6, 0.6), SOL_Y + p.size.y / 2 - 0.2, s.y + r(-0.6, 0.6))
			m.rotation = Vector3(r(-0.4, 0.4), r(0, TAU), r(-0.4, 0.4))
			ajouter(g, m)
		var light := OmniLight3D.new()
		light.light_color = c
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.position = Vector3(s.x, SOL_Y + 2, s.y)
		ajouter(g, light)


func torches() -> void:
	# contre le mur du fond et sur les séparations
	var g := groupe("Torches")
	var spots := [Vector2(-39, -17.4), Vector2(-20, -17.4), Vector2(9, -17.4), Vector2(-40.4, -4), Vector2(-25, -8), Vector2(0, -8), Vector2(-40.4, 6), Vector2(-15, 1), Vector2(10, 1), Vector2(-40.4, 15), Vector2(-25, 10), Vector2(0, 10)]
	var flamme := StandardMaterial3D.new()
	flamme.albedo_color = Color(1, 0.6, 0.15)
	flamme.emission_enabled = true
	flamme.emission = Color(1, 0.5, 0.1)
	flamme.emission_energy_multiplier = 4.0
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.35, 0.22, 0.12)
	for s in spots:
		boite(g, Vector3(0.3, 2.4, 0.3), Vector3(s.x, SOL_Y + 1.2, s.y), bois)
		var f := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.35
		sp.height = 0.9
		sp.material = flamme
		f.mesh = sp
		f.position = Vector3(s.x, SOL_Y + 2.7, s.y)
		ajouter(g, f)
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.65, 0.3)
		light.light_energy = 2.4
		light.omni_range = 13.0
		light.position = Vector3(s.x, SOL_Y + 3.2, s.y)
		light.set_script(load("res://Scripts/torch.gd"))
		ajouter(g, light)


func details() -> void:
	# quelques détails dans les coins, loin du passage
	var g := groupe("Details")
	var coins := [Vector2(-39.5, -10.5), Vector2(20, -10.5), Vector2(20, -1), Vector2(-39.5, 7.5), Vector2(20, 7.5), Vector2(-39.5, 12.5)]
	for c in coins:
		for i in rng.randi_range(1, 2):
			stalagmite(g, Vector3(c.x + r(-0.8, 0.8), SOL_Y, c.y + r(-0.5, 0.5)), r(1.5, 2.8))
		poser(g, "Mushroom", Vector3(c.x + r(-1, 1), SOL_Y, c.y + r(-0.6, 0.6)), r(0.7, 1.0))
	# recoin de la clé 3 : quelques rochers devant
	for p in [Vector2(16.5, 17.5), Vector2(17.5, 15.5)]:
		rocher(g, Vector3(p.x, SOL_Y - 0.3, p.y), r(0.45, 0.6))
