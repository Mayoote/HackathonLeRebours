# Génère le décor du Temple -> Scenes/Levels/Temple.tscn
# godot --headless --path . --script res://tools/generer_temple.gd
#
# Trois étages en gradins (le plus haut au fond : vue isométrique), reliés par un ascenseur à l'est :
#  RDC     (y 0,97)  : galerie des lance-flammes, pics au sol en rythme, clé 1 au pied de l'ascenseur
#  Étage 1 (y 8,97)  : couloir sud (trappe à pics), passage à l'ouest, couloir nord jusqu'à la clé 2.
#                      La salle à l'est est un cul-de-sac : le bip y est fort mais la balustrade bloque.
#  Étage 2 (y 16,97) : salle du trésor, clé 3 au sommet du tas d'or, sortie à l'est
# Les pièges sont dans TempleScene.tscn ; ici seulement le décor et les collisions.

extends SceneTree

const KIT := "res://Meshes/Prairie/Stylized Nature MegaKit.undefined-glb/"
const SORTIE := "res://Scenes/Levels/Temple.tscn"
const RDC := 0.97
const E1 := 8.97
const E2 := 16.97
const BAS := -2.0
const MIN := Vector2(-41.0, -18.0)
const MAX := Vector2(21.5, 19.0)
const HAUT_FOND := E2 + 12.0

# massifs pleins : [rect, dessus] (ils descendent jusqu'à BAS)
const MASSIFS := [
	[Rect2(-41, 10, 62.5, 9), RDC],
	[Rect2(13, 3, 8.5, 7), RDC],      # pied de l'ascenseur
	[Rect2(-41, -5, 54, 15), E1],
	[Rect2(-41, -18, 62.5, 13), E2],
	[Rect2(13, -5, 8.5, 8), E2],      # palier de l'ascenseur
]
# tas d'or de la clé 3 : [rect, hauteur au-dessus de E2]
const TAS_OR := [[Rect2(-37, -17, 10, 8), 2.0], [Rect2(-34, -15, 4, 4), 4.0]]
# socles de part et d'autre de la trappe à pics (étage 1) : on ne la contourne pas
const SOCLES := [Rect2(-14.5, 3.0, 5, 1.05), Rect2(-14.5, 9.05, 5, 0.95)]
# balustrades : visuel bas, collision haute (on ne saute pas par-dessus) : [a, b, sol]
const BALUSTRADES := [
	[Vector2(-33, 2.5), Vector2(5, 2.5), E1], [Vector2(9, 2.5), Vector2(13, 2.5), E1],
	[Vector2(3, -5), Vector2(3, 2.5), E1],
	[Vector2(13.3, -5), Vector2(13.3, 3), E2],  # bord ouest du palier de l'ascenseur
]
const HAUT_COLLISION := 6.0
const COULOIRS := [14.6, 17.25, 19.9]  # colonnes des flèches dans la cage

const PIERRE := """
shader_type spatial;

uniform vec3 couleur : source_color = vec3(0.66, 0.56, 0.4);
uniform vec3 joint : source_color = vec3(0.28, 0.24, 0.19);
uniform vec3 mousse : source_color = vec3(0.24, 0.38, 0.14);
uniform float mousse_quantite = 0.35;
uniform vec2 bloc = vec2(2.4, 1.2);

varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 n = abs(wnor);
	bool dessus = n.y > 0.7;
	vec2 uv = dessus ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	vec2 taille = dessus ? vec2(bloc.x * 0.9) : bloc;
	// appareil de blocs décalés une rangée sur deux
	vec2 p = uv / taille;
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 id = floor(p);
	vec2 bord = min(fract(p), 1.0 - fract(p)) * taille;
	float b = min(bord.x, bord.y);
	float plein = smoothstep(0.04, 0.11, b);
	float g = bruit(uv * 1.3) * 0.5 + bruit(uv * 4.1) * 0.3 + bruit(uv * 11.0) * 0.2;
	vec3 c = couleur * (0.78 + 0.32 * hash(id)) * (0.82 + 0.3 * g);
	c *= 0.78 + 0.22 * smoothstep(0.0, 0.4, b);
	c = mix(joint, c, plein);
	// mousse : par plaques sur les sols, dans les joints sur les murs
	float m = bruit(wpos.xz * 0.35 + wpos.y * 0.2) * 0.7 + g * 0.3;
	float mo = smoothstep(1.0 - mousse_quantite, 1.15 - mousse_quantite, m);
	mo *= dessus ? 1.0 : (1.0 - plein) * 0.9 + 0.1;
	c = mix(c, mousse * (0.75 + 0.5 * g), mo);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	AO = mix(0.55, 1.0, plein);
	AO_LIGHT_AFFECT = 0.4;
}
"""

var rng := RandomNumberGenerator.new()
var decor: Node3D
var cache := {}
var shader: Shader
var mat_pierre: ShaderMaterial
var mat_fond: ShaderMaterial
var mat_ornement: ShaderMaterial
var mat_or: StandardMaterial3D
var mat_bois: StandardMaterial3D
var mat_bronze: StandardMaterial3D
var mat_noir: StandardMaterial3D


func _init() -> void:
	rng.seed = 47
	decor = Node3D.new()
	decor.name = "Temple"
	shader = Shader.new()
	shader.code = PIERRE
	mat_pierre = pierre(Color(0.66, 0.56, 0.4), 0.35, Vector2(2.4, 1.2))
	mat_fond = pierre(Color(0.5, 0.43, 0.33), 0.22, Vector2(3.0, 1.5))
	mat_ornement = pierre(Color(0.74, 0.64, 0.46), 0.15, Vector2(1.2, 0.6))
	mat_or = StandardMaterial3D.new()
	mat_or.albedo_color = Color(1, 0.78, 0.25)
	mat_or.metallic = 0.95
	mat_or.roughness = 0.3
	mat_or.emission_enabled = true
	mat_or.emission = Color(1, 0.65, 0.1)
	mat_or.emission_energy_multiplier = 0.35
	mat_bois = StandardMaterial3D.new()
	mat_bois.albedo_color = Color(0.38, 0.24, 0.13)
	mat_bois.roughness = 0.85
	mat_bronze = StandardMaterial3D.new()
	mat_bronze.albedo_color = Color(0.55, 0.38, 0.18)
	mat_bronze.metallic = 0.75
	mat_bronze.roughness = 0.4
	mat_noir = StandardMaterial3D.new()
	mat_noir.albedo_color = Color(0.03, 0.025, 0.02)

	massifs()
	balustrades()
	murs()
	facades()
	cage_ascenseur()
	salle_tresor()
	cul_de_sac()
	jungle()
	vegetation()
	torches()

	var packed := PackedScene.new()
	packed.pack(decor)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE.get_base_dir()))
	print("Temple : ", ResourceSaver.save(packed, SORTIE))
	quit()


# ── matériaux ────────────────────────────────────────

# pierre du temple : blocs taillés + mousse, dessinés par un petit shader (rien à importer)
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


func cylindre(parent: Node, rayon: float, hauteur: float, pos: Vector3, mat: Material, haut := -1.0, segments := 12) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rayon if haut < 0 else haut
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


# bloc plein praticable : la collision a exactement la taille du visuel
func massif(parent: Node, rect: Rect2, haut: float, bas: float, mat: Material) -> void:
	var c := rect.get_center()
	var taille := Vector3(rect.size.x, haut - bas, rect.size.y)
	var centre := Vector3(c.x, (haut + bas) / 2, c.y)
	collision(parent, taille, centre)
	boite(parent, taille, centre, mat)


func mur_invisible(parent: Node, a: Vector2, b: Vector2, bas: float, hauteur: float, epaisseur: float) -> void:
	var body := StaticBody3D.new()
	var mid := (a + b) / 2
	body.position = Vector3(mid.x, bas + hauteur / 2, mid.y)
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


func r(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func au_hasard(liste: Array):
	return liste[rng.randi() % liste.size()]


# ── structure ────────────────────────────────────────

func massifs() -> void:
	var g := groupe("Etages")
	for m in MASSIFS:
		massif(g, m[0], m[1], BAS, mat_pierre)
	for s in SOCLES:
		massif(g, s, E1 + 3.0, E1 - 0.5, mat_ornement)
		# une jarre sur chaque socle
		var c: Vector2 = s.get_center()
		jarre(g, Vector3(c.x - 1.4, E1 + 3.0, c.y))
		jarre(g, Vector3(c.x + 1.4, E1 + 3.0, c.y))


func jarre(parent: Node3D, pos: Vector3) -> void:
	var terre := StandardMaterial3D.new()
	terre.albedo_color = Color(0.6, 0.35, 0.2).lerp(Color(0.5, 0.3, 0.18), rng.randf())
	terre.roughness = 0.9
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.3
	s.material = terre
	m.mesh = s
	m.position = pos + Vector3.UP * 0.6
	ajouter(parent, m)
	cylindre(parent, 0.3, 0.4, pos + Vector3.UP * 1.3, terre, 0.38)


func balustrades() -> void:
	var g := groupe("Balustrades")
	for b in BALUSTRADES:
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		var sol: float = b[2]
		var mid := (a + c) / 2
		var longueur := a.distance_to(c)
		var rot := Vector3(0, -(c - a).angle(), 0)
		mur_invisible(g, a, c, sol, HAUT_COLLISION, 0.6)
		boite(g, Vector3(longueur, 0.35, 0.7), Vector3(mid.x, sol + 0.17, mid.y), mat_ornement, rot)
		boite(g, Vector3(longueur, 0.3, 0.75), Vector3(mid.x, sol + 2.45, mid.y), mat_ornement, rot)
		var n := int(longueur / 0.9)
		for i in n + 1:
			var p := a.lerp(c, float(i) / n)
			cylindre(g, 0.18, 2.1, Vector3(p.x, sol + 1.3, p.y), mat_ornement, 0.13, 8)


func murs() -> void:
	var g := groupe("Murs")
	# limites invisibles du niveau
	mur_invisible(g, Vector2(MIN.x - 1, MIN.y - 2), Vector2(MIN.x - 1, MAX.y + 2), BAS, 45, 2)
	mur_invisible(g, Vector2(MAX.x + 1, MIN.y - 2), Vector2(MAX.x + 1, MAX.y + 2), BAS, 45, 2)
	mur_invisible(g, Vector2(MIN.x - 2, MIN.y - 1), Vector2(MAX.x + 2, MIN.y - 1), BAS, 45, 2)
	mur_invisible(g, Vector2(MIN.x - 2, MAX.y + 1), Vector2(MAX.x + 2, MAX.y + 1), BAS, 45, 2)
	# fond (nord et ouest) : hauts murs du temple, ils ne cachent rien
	boite(g, Vector3(MAX.x - MIN.x + 30, HAUT_FOND - BAS, 8), Vector3((MIN.x + MAX.x) / 2 + 5, (HAUT_FOND + BAS) / 2, MIN.y - 4), mat_fond)
	boite(g, Vector3(8, HAUT_FOND - BAS, MAX.y - MIN.y + 30), Vector3(MIN.x - 4, (HAUT_FOND + BAS) / 2, (MIN.y + MAX.y) / 2 + 5), mat_fond)
	# créneaux en haut des murs du fond
	var x := MIN.x
	while x < MAX.x + 8:
		boite(g, Vector3(1.6, 1.2, 1.2), Vector3(x, HAUT_FOND + 0.6, MIN.y - 0.6), mat_fond)
		x += 3.2
	var z := MIN.y
	while z < MAX.y + 8:
		boite(g, Vector3(1.2, 1.2, 1.6), Vector3(MIN.x - 0.6, HAUT_FOND + 0.6, z), mat_fond)
		z += 3.2
	# porte d'entrée (on arrive de la Grotte) à l'ouest du RDC
	boite(g, Vector3(0.2, 6.5, 5.5), Vector3(MIN.x + 0.05, RDC + 3.25, 14.5), mat_noir)
	boite(g, Vector3(0.6, 1.2, 7.5), Vector3(MIN.x + 0.3, RDC + 7.1, 14.5), mat_ornement)
	for dz in [-3.3, 3.3]:
		boite(g, Vector3(0.6, 6.5, 1.0), Vector3(MIN.x + 0.3, RDC + 3.25, 14.5 + dz), mat_ornement)


# pilastres, corniche et frise sur une façade tournée vers la caméra (+z)
func facade(g: Node3D, z: float, x0: float, x1: float, bas: float, haut: float, pilastres: Array) -> void:
	var mid := (x0 + x1) / 2
	for px in pilastres:
		boite(g, Vector3(1.4, haut - bas, 0.35), Vector3(px, (bas + haut) / 2, z + 0.17), mat_ornement)
		boite(g, Vector3(1.8, 0.5, 0.55), Vector3(px, bas + 0.25, z + 0.27), mat_ornement)
	boite(g, Vector3(x1 - x0, 0.6, 0.7), Vector3(mid, haut - 0.4, z + 0.35), mat_ornement)
	boite(g, Vector3(x1 - x0, 0.25, 0.5), Vector3(mid, haut - 0.85, z + 0.25), mat_ornement)
	boite(g, Vector3(x1 - x0, 0.45, 0.25), Vector3(mid, bas + 0.22, z + 0.12), mat_ornement)


func facades() -> void:
	var g := groupe("Facades")
	facade(g, 10, MIN.x, 13, RDC, E1, [-36, -24, -12, 0, 10])
	facade(g, -5, MIN.x, 13, E1, E2, [-36, -23.5, -11.5, 0, 8])
	facade(g, MIN.y, MIN.x, MAX.x, E2, HAUT_FOND - 1.5, [-38, -26, -11, 3, 13, 19])
	# mur ouest : pilastres tournés vers +x
	for z in [-12.0, -1.0, 6.0, 17.5]:
		boite(g, Vector3(0.35, HAUT_FOND - RDC - 1.5, 1.4), Vector3(MIN.x + 0.17, (RDC + HAUT_FOND - 1.5) / 2, z), mat_ornement)
	# frise de glyphes sous la corniche du fond
	var x := MIN.x + 2.0
	while x < MAX.x - 1:
		boite(g, Vector3(0.9, 0.9, 0.12), Vector3(x, HAUT_FOND - 3.0, MIN.y + 0.06), mat_bronze if int(x) % 3 == 0 else mat_ornement, Vector3(0, 0, PI / 4))
		x += 2.4


func cage_ascenseur() -> void:
	var g := groupe("CageAscenseur")
	# encadrement et meurtrières sur la face sud du palier
	boite(g, Vector3(0.5, E2 - RDC, 0.4), Vector3(13.25, (RDC + E2) / 2, 3.2), mat_ornement)
	boite(g, Vector3(0.5, E2 - RDC, 0.4), Vector3(21.25, (RDC + E2) / 2, 3.2), mat_ornement)
	boite(g, Vector3(8.5, 0.6, 0.6), Vector3(17.25, E2 - 0.4, 3.3), mat_ornement)
	for x in COULOIRS:
		var y := RDC + 2.0
		while y < E2 - 1.0:
			boite(g, Vector3(0.3, 1.0, 0.1), Vector3(x, y, 3.04), mat_noir)
			y += 2.2
	# poulie au-dessus de la cage, sur deux poteaux à l'avant
	var top := E2 + 11.0
	for x in [13.1, 21.4]:
		cylindre(g, 0.3, top - RDC, Vector3(x, (RDC + top) / 2, 9.9), mat_bois, -1, 8)
		cylindre(g, 0.3, top - E2, Vector3(x, (E2 + top) / 2, 3.1), mat_bois, -1, 8)
		boite(g, Vector3(0.5, 0.5, 7.2), Vector3(x, top, 6.5), mat_bois)
	for z in [3.3, 9.7]:
		boite(g, Vector3(8.8, 0.6, 0.6), Vector3(17.25, top + 0.3, z), mat_bois)
	var roue := cylindre(g, 1.2, 0.4, Vector3(17.25, top + 1.4, 6.5), mat_bronze, -1, 16)
	roue.rotation.z = PI / 2
	boite(g, Vector3(8.0, 0.5, 0.5), Vector3(17.25, top + 0.2, 6.5), mat_bois)
	# un petit panneau au pied de la cage
	var lbl := Label3D.new()
	lbl.text = "ASCENSEUR"
	lbl.font_size = 64
	lbl.pixel_size = 0.02
	lbl.outline_size = 12
	lbl.modulate = Color(1, 0.85, 0.5)
	lbl.position = Vector3(17.25, RDC + 7.0, 3.1)
	ajouter(g, lbl)


func salle_tresor() -> void:
	var g := groupe("SalleTresor")
	# tas d'or (praticable) : marche puis sommet
	for t in TAS_OR:
		massif(g, t[0], E2 + t[1], E2 - 0.5, mat_or)
	for i in 26:
		var p := Vector2(r(-38, -26), r(-17.5, -8.5))
		if Rect2(-37, -17, 10, 8).has_point(p):
			continue
		tas_pieces(g, Vector3(p.x, E2, p.y), r(0.6, 1.3))
	for i in 10:
		tas_pieces(g, Vector3(r(-36.5, -27.5), E2 + 2.0, r(-16.5, -9.5)), r(0.4, 0.8))
	# coffres, gemmes, colonnes, idole
	coffre(g, Vector3(-24, E2, -16.3), 0.2, true)
	coffre(g, Vector3(-39, E2, -7.5), PI / 2, true)
	coffre(g, Vector3(-20, E2, -6.5), -0.4, false)
	coffre(g, Vector3(-28.5, E2 + 2.0, -10), 0.6, true)
	var couleurs := [Color(0.9, 0.1, 0.2), Color(0.2, 0.9, 0.4), Color(0.3, 0.5, 1.0), Color(0.8, 0.3, 1.0)]
	for i in 18:
		var m := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3.ONE * r(0.35, 0.6)
		pm.material = emissif(au_hasard(couleurs), 1.5)
		m.mesh = pm
		var p := Vector2(r(-39, -18), r(-17.5, -6))
		var y := E2 + (2.0 if Rect2(-37, -17, 10, 8).has_point(p) else 0.0)
		if Rect2(-34, -15, 4, 4).has_point(p):
			y = E2 + 4.0
		m.position = Vector3(p.x, y + 0.2, p.y)
		m.rotation = Vector3(r(0, TAU), r(0, TAU), r(0, TAU))
		ajouter(g, m)
	for x in [-39.5, -26.5]:
		colonne(g, Vector3(x, E2, -16.8), 10.0)
	# pilastres d'entrée de la salle + braseros
	for z in [-17.0, -6.0]:
		colonne(g, Vector3(-12.5, E2, z), 6.0)
		brasero(g, Vector3(-12.5, E2 + 6.4, z))
	idole(g, Vector3(-32, E2 + 6.5, MIN.y))
	var lbl := Label3D.new()
	lbl.text = "SALLE DU TRÉSOR"
	lbl.font_size = 128
	lbl.pixel_size = 0.012
	lbl.outline_size = 24
	lbl.modulate = Color(1, 0.82, 0.35)
	lbl.outline_modulate = Color(0.15, 0.08, 0.02)
	lbl.position = Vector3(-18.5, E2 + 9.0, MIN.y + 0.15)
	ajouter(g, lbl)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.75, 0.35)
	light.light_energy = 2.5
	light.omni_range = 16.0
	light.position = Vector3(-32, E2 + 8, -10)
	ajouter(g, light)


func tas_pieces(parent: Node3D, pos: Vector3, taille: float) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = taille
	s.height = taille * 0.9
	s.radial_segments = 10
	s.rings = 5
	s.material = mat_or
	m.mesh = s
	m.position = pos
	ajouter(parent, m)
	for i in 3:
		var piece := cylindre(parent, 0.22, 0.06, pos + Vector3(r(-1, 1) * taille, taille * 0.35, r(-1, 1) * taille), mat_or, -1, 10)
		piece.rotation = Vector3(r(-0.6, 0.6), 0, r(-0.6, 0.6))


func coffre(parent: Node3D, pos: Vector3, rot: float, ouvert: bool) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot
	ajouter(parent, c)
	boite(c, Vector3(2.2, 1.2, 1.4), Vector3(0, 0.6, 0), mat_bois)
	for x in [-0.8, 0.8]:
		boite(c, Vector3(0.18, 1.25, 1.45), Vector3(x, 0.6, 0), mat_or)
	if ouvert:
		boite(c, Vector3(2.2, 0.15, 1.4), Vector3(0, 1.5, -0.75), mat_bois, Vector3(-1.3, 0, 0))
		var tas := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 0.7
		s.material = mat_or
		tas.mesh = s
		tas.scale = Vector3(1.0, 1.0, 0.65)
		tas.position = Vector3(0, 1.2, 0)
		ajouter(c, tas)
	else:
		boite(c, Vector3(2.25, 0.35, 1.45), Vector3(0, 1.35, 0), mat_bois)


func colonne(parent: Node3D, pos: Vector3, h: float) -> void:
	boite(parent, Vector3(2.0, 0.6, 2.0), pos + Vector3.UP * 0.3, mat_ornement)
	cylindre(parent, 0.75, h - 1.2, pos + Vector3.UP * (h / 2), mat_ornement, 0.65, 12)
	boite(parent, Vector3(2.0, 0.6, 2.0), pos + Vector3.UP * (h - 0.3), mat_ornement)


func brasero(parent: Node3D, pos: Vector3) -> void:
	cylindre(parent, 0.5, 0.6, pos + Vector3.UP * 0.3, mat_bronze, 0.9)
	var f := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.55
	sp.height = 1.3
	sp.material = emissif(Color(1, 0.55, 0.15), 4.0)
	f.mesh = sp
	f.position = pos + Vector3.UP * 1.0
	ajouter(parent, f)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.25)
	light.light_energy = 2.2
	light.omni_range = 12.0
	light.position = pos + Vector3.UP * 1.6
	light.set_script(load("res://Scripts/torch.gd"))
	ajouter(parent, light)


# grande tête de pierre dans le mur du fond, les yeux rougeoient
func idole(parent: Node3D, pos: Vector3) -> void:
	boite(parent, Vector3(6, 7, 1.2), pos + Vector3(0, 0, 0.6), mat_ornement)
	boite(parent, Vector3(7.5, 1.4, 1.6), pos + Vector3(0, 4.0, 0.8), mat_or)
	boite(parent, Vector3(1.4, 2.6, 1.0), pos + Vector3(0, 0.2, 1.5), mat_ornement)
	boite(parent, Vector3(3.2, 0.7, 0.4), pos + Vector3(0, -2.0, 1.25), mat_noir)
	for x in [-1.5, 1.5]:
		boite(parent, Vector3(1.3, 0.6, 0.3), pos + Vector3(x, 1.6, 1.25), emissif(Color(1, 0.15, 0.05), 3.0))
		boite(parent, Vector3(0.6, 3.5, 0.9), pos + Vector3(x * 2.4, -1.5, 1.0), mat_or)


func cul_de_sac() -> void:
	# salle de l'étage 1 sans issue : un coffre vide et un squelette pour faire croire qu'il y a quelque chose
	var g := groupe("CulDeSac")
	coffre(g, Vector3(9.5, E1, -3.2), -0.3, false)
	var os := StandardMaterial3D.new()
	os.albedo_color = Color(0.88, 0.85, 0.75)
	var crane := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.8
	s.material = os
	crane.mesh = s
	crane.position = Vector3(6.5, E1 + 0.35, -1.0)
	ajouter(g, crane)
	for i in 5:
		boite(g, Vector3(1.2, 0.15, 0.15), Vector3(6.5 + r(-1.2, 1.4), E1 + 0.08, -1.0 + r(-1, 1.2)), os, Vector3(0, r(0, TAU), 0))
	for p in [Vector2(4.2, -4.2), Vector2(12.3, 1.8)]:
		poser(g, "Mushroom", Vector3(p.x, E1, p.y), 0.5)


func jungle() -> void:
	# sol de jungle devant le temple (au sud et à l'est), uniquement des plantes basses
	var g := groupe("Jungle")
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(320, 320)
	var vert := StandardMaterial3D.new()
	vert.albedo_color = Color(0.13, 0.2, 0.08)
	vert.roughness = 1.0
	plan.material = vert
	sol.mesh = plan
	sol.position = Vector3(0, RDC - 0.1, 0)
	ajouter(g, sol)
	var basses := ["Grass Wispy", "Grass Wispy-Msr9zx66VU", "Grass", "Clover", "Plant", "Fern"]
	for i in 90:
		var p := Vector2(r(-48, 34), r(MAX.y + 2.0, MAX.y + 14))
		poser(g, au_hasard(basses), Vector3(p.x, RDC - 0.1, p.y), r(0.3, 0.55))
	for i in 50:
		var p := Vector2(r(MAX.x + 2.0, MAX.x + 14), r(MIN.y - 4, MAX.y + 2))
		poser(g, au_hasard(basses), Vector3(p.x, RDC - 0.1, p.y), r(0.3, 0.55))


func vegetation() -> void:
	# fougères et herbes le long des murs, jamais au milieu du passage
	var g := groupe("Vegetation")
	var petites := ["Grass Wispy", "Grass Wispy-Msr9zx66VU", "Plant", "Clover", "Fern"]
	var bords := [
		[Vector2(-40, 10.8), Vector2(12, 10.8), RDC], [Vector2(-34, 18.6), Vector2(12, 18.6), RDC],
		[Vector2(-40, -4.2), Vector2(2, -4.2), E1], [Vector2(-40, 9.4), Vector2(-16, 9.4), E1],
		[Vector2(-40, -17.2), Vector2(12, -17.2), E2],
	]
	for b in bords:
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		var n := int(a.distance_to(c) / 2.6)
		for i in n:
			var p := a.lerp(c, (i + r(0, 1)) / n)
			poser(g, au_hasard(petites), Vector3(p.x, b[2], p.y), r(0.25, 0.4))
	for p in [Vector3(-40, RDC, 11), Vector3(12.2, E1, -4.2), Vector3(-40, E1, -4.2), Vector3(-40, E2, -17.2), Vector3(11, E2, -17.2)]:
		poser(g, au_hasard(["Plant Big", "Plant Big-MbhbP7JrTI", "Bush"]), p, r(0.45, 0.6))


func torches() -> void:
	var g := groupe("Torches")
	var spots := [
		Vector3(-36, RDC + 5.2, 10.6), Vector3(-12, RDC + 5.2, 10.6), Vector3(10, RDC + 5.2, 10.6),
		Vector3(-36, E1 + 5.2, -4.4), Vector3(-11.5, E1 + 5.2, -4.4), Vector3(8, E1 + 5.2, -4.4),
		Vector3(3, E2 + 5.2, MIN.y + 0.6), Vector3(13, E2 + 5.2, MIN.y + 0.6),
	]
	var flamme := emissif(Color(1, 0.6, 0.15), 4.0)
	for s in spots:
		boite(g, Vector3(0.3, 1.4, 0.3), s, mat_bronze, Vector3(0.4, 0, 0))
		var f := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.32
		sp.height = 0.85
		sp.material = flamme
		f.mesh = sp
		f.position = s + Vector3(0, 0.95, 0.25)
		ajouter(g, f)
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.65, 0.3)
		light.light_energy = 2.0
		light.omni_range = 12.0
		light.position = s + Vector3(0, 1.4, 0.8)
		light.set_script(load("res://Scripts/torch.gd"))
		ajouter(g, light)
