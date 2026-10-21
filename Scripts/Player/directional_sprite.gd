# directional_sprite.gd — personnage 2D animé, vu sous 8 directions
# Choisit l'image selon la direction où regarde le personnage PAR RAPPORT À LA CAMÉRA
# (de face, de dos, de profil...) et fait défiler les images de l'animation.
#
# Format attendu des images (comme le pack « mixamo dummy ») :
#   <sprites_folder>/<Dossier>/<Dossier>_<direction>.png
#   avec direction = s (de face), se, e, ne, n (de dos), nw, w, sw
#   et toutes les images de l'animation côte à côte sur une seule ligne.
#
# Le script du joueur règle seulement deux choses :
#   - facing    : direction (dans le monde 3D) vers laquelle regarde le personnage
#   - animation : "idle", "walk", "run" ou "jump"

class_name DirectionalSprite3D
extends Sprite3D

## Dossier qui contient un sous-dossier par animation
@export_dir var sprites_folder := "res://Images and ressources/Personnage":
	set(value):
		sprites_folder = value
		if is_node_ready():
			_load_textures()
## Nom du sous-dossier de chaque animation
@export var animation_folders := {
	"idle": "Idle",
	"walk": "Walking",
	"run": "Running",
	"jump": "Jumping Up",
}
## Animations jouées une seule fois (elles restent sur leur dernière image)
@export var play_once: Array[String] = ["jump"]
## Image de départ de certaines animations (le saut Mixamo commence par 15 images d'appel au sol)
@export var start_frames := {"jump": 15}
## Largeur d'une image de l'animation, en pixels
@export var frame_width := 256
## Images par seconde
@export var fps := 30.0

const DIRECTIONS := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

var facing := Vector3.ZERO  # ZERO = face à la caméra (avant le premier déplacement)
var animation := "idle":
	set(value):
		if value != animation:
			animation = value
			_time = 0.0

var _textures := {}  # { "idle": [image s, image se, ...], ... }
var _time := 0.0


func _ready() -> void:
	_load_textures()


func _load_textures() -> void:
	_textures.clear()
	for anim in animation_folders:
		var folder: String = animation_folders[anim]
		var list: Array[Texture2D] = []
		for d in DIRECTIONS:
			list.append(load("%s/%s/%s_%s.png" % [sprites_folder, folder, folder, d]))
		_textures[anim] = list


func _process(delta: float) -> void:
	_time += delta

	# Direction du personnage vue depuis la caméra : 0 = de face (s), 4 = de dos (n)
	var dir_index := 0
	var camera := get_viewport().get_camera_3d()
	if camera and facing != Vector3.ZERO:
		var local := facing.rotated(Vector3.UP, -camera.global_rotation.y)
		dir_index = wrapi(roundi(atan2(local.x, local.z) / (PI / 4)), 0, 8)

	var tex: Texture2D = _textures[animation][dir_index]
	if texture != tex:
		frame = 0
		texture = tex
		hframes = tex.get_width() / frame_width

	var start: int = mini(start_frames.get(animation, 0), hframes - 1)
	var f := int(_time * fps)
	if animation in play_once:
		frame = mini(start + f, hframes - 1)
	else:
		frame = start + f % (hframes - start)
