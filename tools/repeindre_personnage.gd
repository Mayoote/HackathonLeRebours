# Repeint le mannequin Mixamo (Personnage/) avec les couleurs de APPARENCES.
# godot --headless --path . --script res://tools/repeindre_personnage.gd

extends SceneTree

const SOURCE := "res://Images and ressources/Personnage"
const ANIMATIONS := ["Idle", "Walking", "Running", "Jumping Up"]
const DIRECTIONS := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const FRAME_WIDTH := 256

# nom du dossier -> couleurs (cuir = les zones rouges du mannequin)
const APPARENCES := {
	"Aventurier": {
		"cheveux": Color(0.36, 0.21, 0.1),
		"peau": Color(0.93, 0.72, 0.56),
		"tunique": Color(0.22, 0.46, 0.26),
		"cuir": Color(0.52, 0.32, 0.16),
		"pantalon": Color(0.6, 0.48, 0.32),
		"bottes": Color(0.3, 0.18, 0.1),
	},
	"Aventurier Rouge": {
		"cheveux": Color(0.85, 0.66, 0.32),
		"peau": Color(0.82, 0.6, 0.45),
		"tunique": Color(0.66, 0.17, 0.15),
		"cuir": Color(0.4, 0.26, 0.14),
		"pantalon": Color(0.33, 0.35, 0.44),
		"bottes": Color(0.22, 0.15, 0.1),
	},
}
const CONTOUR := Color(0.12, 0.08, 0.06)

# zones en fraction de la hauteur (0 = tête, 1 = pieds)
const FIN_CHEVEUX := 0.06
const FIN_TETE := 0.155
const FIN_TUNIQUE := 0.45
const DEBUT_BOTTES := 0.86
# loin du centre à hauteur des mains = une main
const ZONE_MAINS := Vector2(0.35, 0.65)
const ECART_MAINS := 0.15


func _init() -> void:
	for nom in APPARENCES:
		var destination: String = "res://Images and ressources/" + nom
		for anim in ANIMATIONS:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [destination, anim]))
			for d in DIRECTIONS:
				var file := "%s/%s_%s.png" % [anim, anim, d]
				var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [SOURCE, file]))
				img.convert(Image.FORMAT_RGBA8)
				for i in img.get_width() / FRAME_WIDTH:
					_repaint_frame(img, Rect2i(i * FRAME_WIDTH, 0, FRAME_WIDTH, img.get_height()), APPARENCES[nom])
				img.save_png(ProjectSettings.globalize_path("%s/%s" % [destination, file]))
		print("apparence créée : ", nom)
	quit()


func _repaint_frame(img: Image, frame: Rect2i, couleurs: Dictionary) -> void:
	var used := img.get_region(frame).get_used_rect()
	if used.size.y == 0:
		return
	used.position += frame.position
	var height := float(used.size.y)
	var center_x := used.position.x + used.size.x / 2.0

	for y in range(used.position.y, used.end.y):
		var t := (y - used.position.y) / height
		for x in range(used.position.x, used.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var target: Color
			if c.v < 0.25:
				target = CONTOUR
			elif c.s > 0.35 and (c.h > 0.8 or c.h < 0.08):
				target = couleurs.cuir  # zones rouges : ceinture, coudes, genoux
			elif t < FIN_CHEVEUX:
				target = couleurs.cheveux
			elif t < FIN_TETE:
				target = couleurs.peau
			elif t > ZONE_MAINS.x and t < ZONE_MAINS.y and abs(x - center_x) > ECART_MAINS * height:
				target = couleurs.peau
			elif t < FIN_TUNIQUE:
				target = couleurs.tunique
			elif t < DEBUT_BOTTES:
				target = couleurs.pantalon
			else:
				target = couleurs.bottes
			# on garde les ombres du bleu d'origine
			var shade := clampf(0.45 + 0.65 * c.v, 0.0, 1.2) if target != CONTOUR else 1.0
			img.set_pixel(x, y, Color(target.r * shade, target.g * shade, target.b * shade, c.a))
