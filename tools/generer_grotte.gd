# Génère le décor de la Grotte -> Scenes/Levels/Grotte.tscn
# godot --headless --path . --script res://tools/generer_grotte.gd
#
# Rez-de-chaussée : cinq galeries en serpentin (z croissant = vers la caméra)
#  G1 ouest -> est : corniche du rocher, gouffre (plateformes, trappe 1), escalade -> clé 1,
#                    puis les prises continuent jusqu'à l'étage (G1 n'a plus d'autre sortie)
#  G2 est -> ouest : on y retombe par le puits de l'étage ; rochers à sauter, pilier de la clé 2
#  G3 ouest -> est : trappes 2 et 3, éboulis, plateformes à différentes hauteurs
#  G4 est -> ouest : tas de rochers (clé 4), petit gouffre
#  G5 ouest -> est : deux éboulis, sortie à l'est
# Étage (au-dessus de G1 et G2, son sol est leur plafond) :
#  E1 est -> ouest : zone d'eau peu profonde avec un îlot (clé 3), trou à sauter
#  E2 ouest -> est : éboulis, trou à sauter, puits de descente vers G2
# Trous : entre 4,5 et 7 de large (le joueur fait 3,3, son saut porte à 8,4).
# Vue isométrique : ce qui est haut est contre un mur du fond (nord / ouest).
# L'étage est caché quand le joueur est en bas (Scripts/floor_visibility.gd).

extends SceneTree

const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Grotte.tscn"
const SOL_Y := 0.97
const ETAGE_Y := SOL_Y + 16.0      # sol de l'étage (le plafond de G1/G2 est 1,5 plus bas)
const ETAGE_EP := 1.5
const MIN := Vector2(-41.0, -18.0)
const MAX := Vector2(43.0, 28.0)
# murs infranchissables : nettement plus hauts que le saut (3,7), sinon le bas
# arrondi du personnage accroche l'arête et il grimpe dessus
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
const SOLS_ETAGE := [
	# E1 (z -18..-10) : trou de x -22 à -16, colonne d'escalade ouverte de x 17 à 39.5 côté nord
	Rect2(-41, -18, 19, 8),
	Rect2(-16, -18, 33, 8),
	Rect2(17, -14, 22.5, 4),
	Rect2(39.5, -18, 3.5, 8),       # arrivée de l'escalade
	Rect2(-41, -10, 84, 1.2),       # sous le mur E1/E2
	# E2 (z -8.8..-0.8) : trou de x 12 à 18, puits de descente de x 34 à 43 (z -8.8..-3)
	Rect2(-41, -8.8, 53, 8),
	Rect2(18, -8.8, 16, 8),
	Rect2(34, -3, 9, 2.2),
	Rect2(-41, -0.8, 84, 1.2),      # sous le garde-fou sud
]
# blocs de roche : [rect, hauteur du dessus au-dessus du sol du RDC]
const BLOCS := [
	[Rect2(-33, -18, 9, 3), 9.0],           # corniche du rocher (plus haute que le joueur)
	[Rect2(18, -18, 2.5, 3.5), 2.0],        # escalade : bloc
	[Rect2(21.1, -16.6, 1.6, 1.6), 4.0],    # escalade : prise
	[Rect2(23.5, -18, 4.5, 3.5), 6.0],      # escalade : corniche de la clé 1
	[Rect2(28.8, -17.2, 1.6, 1.6), 8.0],    # prises vers l'étage (contre le mur du fond)
	[Rect2(31.6, -17.2, 1.6, 1.6), 10.0],
	[Rect2(34.4, -17.2, 1.6, 1.6), 12.0],
	[Rect2(37.2, -17.2, 1.6, 1.6), 14.0],
	[Rect2(19, 2.4, 4, 4), 1.0],            # G3 : plateformes à différentes hauteurs
	[Rect2(27, 2.4, 4, 4), 2.0],
	[Rect2(2, 14.6, 3, 3), 2.0],            # G4 : tas de rochers de la clé 4 (contre le mur 4)
	[Rect2(5, 15.6, 3, 2), 4.0],
]
# plateaux rocheux de l'étage à franchir : [rect, hauteur au-dessus du sol de l'étage]
const BLOCS_ETAGE := [[Rect2(-31, -18, 4, 8), 2.0], [Rect2(22, -8.8, 4, 8), 2.0]]
# rochers à sauter dans le gouffre de G2 : [centre, rayon, hauteur]
const ROCHERS_SAUT := [
	[Vector2(25.5, -4.8), 1.8, 1.5], [Vector2(18.5, -4.3), 1.8, 2.5], [Vector2(11.5, -4.8), 1.8, 1.5],
	[Vector2(18.5, -7.4), 1.2, 4.5],        # pilier de la clé 2 (contre le mur 1)
]
# murs : [z, x début, x fin, hauteur du sol]
const MURS := [
	[-9.4, -41, 43, SOL_Y],      # G1 / G2 fermé : on passe par l'étage
	[-0.2, -33, 43, SOL_Y],
	[9.0, -41, 35, SOL_Y],
	[18.2, -33, 43, SOL_Y],
	[-9.4, -33, 43, ETAGE_Y],    # E1 / E2
	[-0.2, -41, 43, ETAGE_Y],    # garde-fou sud de l'étage
]
# éboulis bas à sauter : [début, fin, hauteur du sol]
const EBOULIS := [
	[Vector2(-15, -8.8), Vector2(-15, -0.8), SOL_Y], [Vector2(-8, 0.4), Vector2(-8, 8.4), SOL_Y],
	[Vector2(-10, 18.8), Vector2(-10, 28), SOL_Y], [Vector2(15, 18.8), Vector2(15, 28), SOL_Y],
	[Vector2(-20, -8.8), Vector2(-20, -0.8), ETAGE_Y], [Vector2(3, -8.8), Vector2(3, -0.8), ETAGE_Y],
]
# zone d'eau peu profonde de l'étage et son îlot (clé 3)
# surplomb de roche contre le mur du fond de l'étage : les stalactites de l'étage y sont accrochées
const SURPLOMB := Rect2(-41, -18, 84, 4.5)
const SURPLOMB_Y := ETAGE_Y + 12.0
const EAU := Rect2(-14, -17.5, 30, 7)
const ILOT := Rect2(1.5, -15.5, 4, 4)

var rng := RandomNumberGenerator.new()
var decor: Node3D
var etage: Node3D
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
	etage = groupe("Etage2")

	sols()
	blocs()
	rochers_saut()
	bords()
	murs()
	eboulis()
	eau()
	surplomb()
	plafond_bas()
	voile()
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

func groupe(nom: String, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.name = nom
	(parent if parent else decor).add_child(g)
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


func mur_invisible(parent: Node, a: Vector2, b: Vector2, hauteur: float, epaisseur: float, base := SOL_Y) -> void:
	var body := StaticBody3D.new()
	var mid := (a + b) / 2
	body.position = Vector3(mid.x, base + hauteur / 2, mid.y)
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
	var ge := groupe("Sols", etage)
	for s in SOLS_ETAGE:
		dalle(ge, s, ETAGE_Y, ETAGE_EP)


func blocs() -> void:
	# piliers qui descendent sous le sol : ils ne flottent pas au-dessus du vide
	var g := groupe("Escalade")
	for b in BLOCS:
		var rect: Rect2 = b[0]
		var h: float = b[1]
		dalle(g, rect, SOL_Y + h, h + 3.0)
	var ge := groupe("Plateaux", etage)
	for b in BLOCS_ETAGE:
		dalle(ge, b[0], ETAGE_Y + b[1], b[1] + ETAGE_EP)
	# îlot de la clé 3, dans l'eau de l'étage
	dalle(groupe("Ilot", etage), ILOT, ETAGE_Y + 1.0, 1.0 + ETAGE_EP)


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
	mur_invisible(g, Vector2(MIN.x - 1, MIN.y - 2), Vector2(MIN.x - 1, MAX.y + 2), 40, 2)
	mur_invisible(g, Vector2(MAX.x + 1, MIN.y - 2), Vector2(MAX.x + 1, MAX.y + 2), 40, 2)
	mur_invisible(g, Vector2(MIN.x - 2, MIN.y - 1), Vector2(MAX.x + 2, MIN.y - 1), 40, 2)
	mur_invisible(g, Vector2(MIN.x - 2, MAX.y + 1), Vector2(MAX.x + 2, MAX.y + 1), 40, 2)
	# fond (nord et ouest) : paroi rocheuse haute (jusqu'au-dessus de l'étage), elle ne cache rien
	boite(g, Vector3(MAX.x - MIN.x + 20, 34, 8), Vector3((MIN.x + MAX.x) / 2, SOL_Y + 14, MIN.y - 5.5), mat_paroi)
	boite(g, Vector3(8, 34, MAX.y - MIN.y + 20), Vector3(MIN.x - 5.5, SOL_Y + 14, (MIN.y + MAX.y) / 2), mat_paroi)
	for base in [SOL_Y, ETAGE_Y]:
		var parent: Node3D = g if base == SOL_Y else groupe("Parois", etage)
		var x := MIN.x - 2
		while x < MAX.x + 4:
			rocher(parent, Vector3(x, base - 0.5, MIN.y - r(1.2, 2.2)), r(0.9, 1.5))
			x += r(3.0, 4.5)
		var z := MIN.y
		while z < (MAX.y + 4 if base == SOL_Y else 0.0):
			rocher(parent, Vector3(MIN.x - r(1.2, 2.2), base - 0.5, z), r(0.9, 1.5))
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
	var pilier := CylinderMesh.new()
	pilier.top_radius = 0.16
	pilier.bottom_radius = 0.24
	pilier.height = HAUT_MUR - 1.4
	pilier.radial_segments = 6
	pilier.material = mat_bloc
	var g := groupe("Murs")
	var ge := groupe("Murs", etage)
	for m in MURS:
		var z: float = m[0]
		var x0: float = m[1]
		var x1: float = m[2]
		var base: float = m[3]
		var parent: Node3D = g if base == SOL_Y else ge
		var longueur := x1 - x0
		var mid := (x0 + x1) / 2
		collision(parent, Vector3(longueur, HAUT_MUR, EP_MUR), Vector3(mid, base + HAUT_MUR / 2, z))
		boite(parent, Vector3(longueur, 1.4, EP_MUR), Vector3(mid, base + 0.7, z), mat_bloc)
		var x := x0 + 0.4
		while x <= x1 - 0.3:
			var p := MeshInstance3D.new()
			p.mesh = pilier
			p.position = Vector3(x + r(-0.1, 0.1), base + 1.4 + (HAUT_MUR - 1.4) / 2, z + r(-0.15, 0.15))
			p.rotation = Vector3(r(-0.04, 0.04), r(0, TAU), r(-0.04, 0.04))
			ajouter(parent, p)
			x += 1.5


func eboulis() -> void:
	# murets d'éboulis assez bas pour être sautés
	var g := groupe("Eboulis")
	var ge := groupe("Eboulis", etage)
	for s in EBOULIS:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var base: float = s[2]
		var parent: Node3D = g if base == SOL_Y else ge
		mur_invisible(parent, a, b, 2.0, 1.4, base)
		var a2 := a.move_toward(b, 0.6)
		var b2 := b.move_toward(a, 0.6)
		var n := int(a2.distance_to(b2) / 1.3)
		for i in n + 1:
			var p := a2.lerp(b2, float(i) / n)
			rocher(parent, Vector3(p.x + r(-0.3, 0.3), base - 0.3, p.y), r(0.32, 0.42))


func eau() -> void:
	# eau peu profonde de l'étage : on marche dedans, plus lentement
	var g := groupe("Eau", etage)
	var surface := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = EAU.size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/eau.gdshader")
	plan.material = mat
	surface.mesh = plan
	surface.position = Vector3(EAU.get_center().x, ETAGE_Y + 0.3, EAU.get_center().y)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ajouter(g, surface)
	var zone := Area3D.new()
	zone.name = "ZoneEau"
	zone.set_script(load("res://Scripts/Traps/shallow_water.gd"))
	# jusqu'à 0,9 de haut : debout sur l'îlot (1,0) on n'est plus dans l'eau
	zone.position = Vector3(EAU.get_center().x, ETAGE_Y + 0.45, EAU.get_center().y)
	ajouter(g, zone)
	var forme := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(EAU.size.x, 0.9, EAU.size.y)
	forme.shape = box
	ajouter(zone, forme)
	# bord de galets, côté sud et côtés est/ouest (le nord est contre la paroi)
	var bord := [[Vector2(EAU.position.x, EAU.end.y), Vector2(EAU.end.x, EAU.end.y)], [Vector2(EAU.position.x, EAU.position.y), Vector2(EAU.position.x, EAU.end.y)], [Vector2(EAU.end.x, EAU.position.y), Vector2(EAU.end.x, EAU.end.y)]]
	for b in bord:
		var n := int(b[0].distance_to(b[1]) / 1.6)
		for i in n + 1:
			var p: Vector2 = b[0].lerp(b[1], float(i) / n)
			poser(g, "Pebble Round" if rng.randf() < 0.5 else "Pebble Square", Vector3(p.x + r(-0.3, 0.3), ETAGE_Y, p.y + r(-0.3, 0.3)), r(1.4, 2.0))


func surplomb() -> void:
	var g := groupe("Surplomb", etage)
	dalle(g, SURPLOMB, SURPLOMB_Y, 2.5)
	# bord avant irrégulier
	var bx := SURPLOMB.position.x + 0.5
	while bx < SURPLOMB.end.x:
		rocher(g, Vector3(bx, SURPLOMB_Y - 2.0, SURPLOMB.end.y - 0.6), r(0.3, 0.42))
		bx += r(2.0, 3.5)
	# dessous irrégulier : quelques roches accrochées
	var x := SURPLOMB.position.x + 1
	while x < SURPLOMB.end.x:
		rocher(g, Vector3(x, SURPLOMB_Y - 2.5 - 1.3, r(SURPLOMB.position.y + 0.5, SURPLOMB.end.y - 1.0)), r(0.3, 0.45))
		x += r(4.0, 7.0)


# vu d'en bas, l'étage est caché : on garde son plafond en ombre transparente
# (on comprend qu'il y a un plafond, les stalactites y sont accrochées, et on voit à travers)
func plafond_bas() -> void:
	var g := groupe("PlafondBas")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.14, 0.13, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in SOLS_ETAGE:
		var rect: Rect2 = s
		var m := boite(g, Vector3(rect.size.x, ETAGE_EP, rect.size.y), Vector3(rect.get_center().x, ETAGE_Y - ETAGE_EP / 2, rect.get_center().y), mat)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func voile() -> void:
	# assombrit le rez-de-chaussée visible quand le joueur est à l'étage
	var m := MeshInstance3D.new()
	m.name = "Voile"
	var plan := PlaneMesh.new()
	plan.size = Vector2(MAX.x - MIN.x + 30, MAX.y + 2.0 + 15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.55)
	plan.material = mat
	m.mesh = plan
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3((MIN.x + MAX.x) / 2, ETAGE_Y - 1.0, (MAX.y - 0.8) / 2 + 7.5)
	ajouter(decor, m)


# ── ambiance ─────────────────────────────────────────

func cristaux() -> void:
	# au bord des gouffres et contre les murs, jamais au milieu du passage ni au-dessus du vide
	var couleurs := [Color(0.3, 0.8, 1.0), Color(0.75, 0.4, 1.0)]
	var spots := [
		[Vector2(-20.6, -17.3), SOL_Y], [Vector2(16.6, -10.8), SOL_Y], [Vector2(30.6, -1.6), SOL_Y], [Vector2(7.4, -8.1), SOL_Y],
		[Vector2(13.4, 7.6), SOL_Y], [Vector2(37.6, 1.2), SOL_Y], [Vector2(-25.6, 10.4), SOL_Y], [Vector2(-11.4, 16.8), SOL_Y],
		[Vector2(42.2, 27.2), SOL_Y], [Vector2(-40.2, 27.2), SOL_Y],
		[Vector2(-9, -17.3), ETAGE_Y], [Vector2(15, -17.3), ETAGE_Y], [Vector2(-40.2, -6), ETAGE_Y], [Vector2(11.4, -1.6), ETAGE_Y],
	]
	var g := groupe("Cristaux")
	var ge := groupe("Cristaux", etage)
	for spot in spots:
		var s: Vector2 = spot[0]
		var base: float = spot[1]
		var parent: Node3D = g if base == SOL_Y else ge
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
			m.position = Vector3(s.x + r(-0.4, 0.4), base + p.size.y / 2 - 0.2, s.y + r(-0.4, 0.4))
			m.rotation = Vector3(r(-0.3, 0.3), r(0, TAU), r(-0.3, 0.3))
			ajouter(parent, m)
		var light := OmniLight3D.new()
		light.light_color = c
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.shadow_enabled = base > SOL_Y
		light.position = Vector3(s.x, base + 2, s.y)
		ajouter(parent, light)


func torche(parent: Node3D, pos: Vector3, portee: float) -> void:
	var flamme := StandardMaterial3D.new()
	flamme.albedo_color = Color(1, 0.6, 0.15)
	flamme.emission_enabled = true
	flamme.emission = Color(1, 0.5, 0.1)
	flamme.emission_energy_multiplier = 4.0
	var fer := StandardMaterial3D.new()
	fer.albedo_color = Color(0.15, 0.13, 0.12)
	boite(parent, Vector3(0.25, 1.0, 0.25), pos + Vector3.UP * 0.5, fer)
	collision(parent, Vector3(0.25, 1.0, 0.25), pos + Vector3.UP * 0.5)
	var f := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.3
	sp.height = 0.8
	sp.material = flamme
	f.mesh = sp
	f.position = pos + Vector3.UP * 1.3
	ajouter(parent, f)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.65, 0.3)
	light.light_energy = 2.4
	light.omni_range = portee
	light.position = pos + Vector3.UP * 1.8
	light.shadow_enabled = pos.y > ETAGE_Y - 1.0  # à l'étage : la lumière ne traverse pas le sol
	light.set_script(load("res://Scripts/torch.gd"))
	ajouter(parent, light)


func torches() -> void:
	# sur les murets (entre deux piliers) et contre la paroi du fond, jamais dans un mur.
	# Portée limitée : la lumière ne traverse pas le plafond / le sol de l'étage.
	var g := groupe("Torches")
	var ge := groupe("Torches", etage)
	for m in MURS:
		for x in [-25, 0, 25]:
			if x > m[1] + 2 and x < m[2] - 2:
				# au pied du muret côté galerie (pas dans le volume du mur), sur un poteau
				var p := Vector3(x + 0.75, m[3], m[0] + EP_MUR / 2 + 0.2)
				var parent: Node3D = g if m[3] == SOL_Y else ge
				boite(parent, Vector3(0.25, 1.4, 0.25), p + Vector3.UP * 0.7, mat_bloc)
				collision(parent, Vector3(0.25, 1.4, 0.25), p + Vector3.UP * 0.7)
				torche(parent, p + Vector3.UP * 1.4, 10.0)
	for p in [Vector2(-37, MIN.y + 0.4), Vector2(-12, MIN.y + 0.4), Vector2(14, MIN.y + 0.4)]:
		torche(g, Vector3(p.x, SOL_Y + 2.0, p.y), 10.0)
		torche(ge, Vector3(p.x + 6, ETAGE_Y + 2.0, p.y), 9.0)
	for z in [4.4, 13.6, 23.4]:
		torche(g, Vector3(MIN.x + 0.4, SOL_Y + 2.0, z), 10.0)


func details() -> void:
	# quelques détails dans les coins, loin du passage
	var g := groupe("Details")
	var coins := [Vector2(-39.5, -11.2), Vector2(41.5, -11.2), Vector2(41.5, -2), Vector2(-39.5, 7.2), Vector2(41.5, 7.2), Vector2(-39.5, 16.5), Vector2(-39.5, 26.5), Vector2(41.5, 19.8)]
	for c in coins:
		for i in rng.randi_range(1, 2):
			stalagmite(g, Vector3(c.x + r(-0.8, 0.8), SOL_Y, c.y + r(-0.4, 0.4)), r(1.5, 2.8))
		poser(g, "Mushroom", Vector3(c.x + r(-1, 1), SOL_Y, c.y + r(-0.5, 0.5)), r(0.7, 1.0))
	var ge := groupe("Details", etage)
	for c in [Vector2(-39.5, -16.5), Vector2(-39.5, -2), Vector2(32, -2)]:
		stalagmite(ge, Vector3(c.x, ETAGE_Y, c.y), r(1.5, 2.5))
		poser(ge, "Mushroom", Vector3(c.x + r(-1, 1), ETAGE_Y, c.y + r(-0.4, 0.4)), r(0.7, 1.0))
