# repeindre_personnage.gd — crée une nouvelle apparence en repeignant le mannequin Mixamo
#
# Lit les sprites de SOURCE (mannequin bleu), repeint chaque image et écrit le résultat
# dans DESTINATION, avec les mêmes noms de fichiers. Les ombres d'origine sont gardées.
# Pour une autre apparence : changer les couleurs et DESTINATION, puis relancer.
#
# Lancer depuis le dossier du projet (Godot fermé ou non, peu importe) :
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/repeindre_personnage.gd
# Puis, dans le nœud Visual/Sprite du joueur, mettre « Sprites Folder » sur DESTINATION.

extends SceneTree

const SOURCE := "res://Images and ressources/Personnage"
const DESTINATION := "res://Images and ressources/Aventurier"
const ANIMATIONS := ["Idle", "Walking", "Running", "Jumping Up"]
const DIRECTIONS := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const FRAME_WIDTH := 256

# Couleurs de l'aventurier
const CHEVEUX := Color(0.36, 0.21, 0.1)
const PEAU := Color(0.93, 0.72, 0.56)
const TUNIQUE := Color(0.22, 0.46, 0.26)
const CUIR := Color(0.52, 0.32, 0.16)      # ceinture et protections (les zones rouges du mannequin)
const PANTALON := Color(0.6, 0.48, 0.32)
const BOTTES := Color(0.3, 0.18, 0.1)
const CONTOUR := Color(0.12, 0.08, 0.06)

# Zones du corps, en part de la hauteur du personnage (0 = haut de la tête, 1 = pieds)
const FIN_CHEVEUX := 0.06
const FIN_TETE := 0.155
const FIN_TUNIQUE := 0.45
const DEBUT_BOTTES := 0.86
# Au niveau des mains, ce qui est loin du centre du corps est une main
const ZONE_MAINS := Vector2(0.35, 0.65)
const ECART_MAINS := 0.15


func _init() -> void:
	for anim in ANIMATIONS:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [DESTINATION, anim]))
		for d in DIRECTIONS:
			var file := "%s/%s_%s.png" % [anim, anim, d]
			var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [SOURCE, file]))
			img.convert(Image.FORMAT_RGBA8)
			for i in img.get_width() / FRAME_WIDTH:
				_repaint_frame(img, Rect2i(i * FRAME_WIDTH, 0, FRAME_WIDTH, img.get_height()))
			img.save_png(ProjectSettings.globalize_path("%s/%s" % [DESTINATION, file]))
			print("repeint : ", file)
	quit()


func _repaint_frame(img: Image, frame: Rect2i) -> void:
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
				target = CUIR  # zones rouges : ceinture, coudes, genoux
			elif t < FIN_CHEVEUX:
				target = CHEVEUX
			elif t < FIN_TETE:
				target = PEAU
			elif t > ZONE_MAINS.x and t < ZONE_MAINS.y and abs(x - center_x) > ECART_MAINS * height:
				target = PEAU
			elif t < FIN_TUNIQUE:
				target = TUNIQUE
			elif t < DEBUT_BOTTES:
				target = PANTALON
			else:
				target = BOTTES
			# Garde l'ombrage d'origine : plus le bleu était sombre, plus la nouvelle couleur l'est
			var shade := clampf(0.45 + 0.65 * c.v, 0.0, 1.2) if target != CONTOUR else 1.0
			img.set_pixel(x, y, Color(target.r * shade, target.g * shade, target.b * shade, c.a))
