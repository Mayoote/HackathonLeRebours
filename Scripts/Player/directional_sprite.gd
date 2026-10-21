# Sprite 8 directions. Images rangées comme ça : <dossier>/<Anim>/<Anim>_<dir>.png
# (dir = s, se, e, ne, n, nw, w, sw), toutes les frames sur une ligne.

class_name DirectionalSprite3D
extends Sprite3D

@export_dir var sprites_folder := "res://Images and ressources/Personnage":
	set(value):
		sprites_folder = value
		if is_node_ready():
			load_textures()
@export var animation_folders := {
	"idle": "Idle",
	"walk": "Walking",
	"run": "Running",
	"jump": "Jumping Up",
}
@export var play_once: Array[String] = ["jump"]
@export var start_frames := {"jump": 15}  # le saut commence accroupi, on saute ces frames
@export var frame_width := 256
@export var fps := 30.0

const DIRECTIONS := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

var facing := Vector3.ZERO
var animation := "idle":
	set(value):
		if value != animation:
			animation = value
			time = 0.0

var textures := {}
var time := 0.0


func _ready() -> void:
	load_textures()


func load_textures() -> void:
	textures.clear()
	for anim in animation_folders:
		var folder: String = animation_folders[anim]
		var list: Array[Texture2D] = []
		for d in DIRECTIONS:
			list.append(load("%s/%s/%s_%s.png" % [sprites_folder, folder, folder, d]))
		textures[anim] = list


func _process(delta: float) -> void:
	time += delta

	var dir := 0
	var cam := get_viewport().get_camera_3d()
	if cam and facing != Vector3.ZERO:
		var local := facing.rotated(Vector3.UP, -cam.global_rotation.y)
		dir = wrapi(roundi(atan2(local.x, local.z) / (PI / 4)), 0, 8)

	var tex: Texture2D = textures[animation][dir]
	if texture != tex:
		frame = 0
		texture = tex
		hframes = tex.get_width() / frame_width

	var start: int = mini(start_frames.get(animation, 0), hframes - 1)
	var f := int(time * fps)
	if animation in play_once:
		frame = mini(start + f, hframes - 1)
	else:
		frame = start + f % (hframes - start)
