# level_camera.gd — caméra isométrique fixe qui montre tout le niveau
# Vue en diagonale, sans perspective (projection orthogonale), partagée par les deux joueurs.
# Tous les réglages sont dans l'inspecteur et se voient en direct dans l'éditeur.

@tool
extends Camera3D

## Point du niveau au centre de l'écran
@export var target := Vector3.ZERO:
	set(value):
		target = value
		_update()
## Rotation autour du niveau (45° = vue en diagonale)
@export_range(-180, 180) var yaw_degrees := 45.0:
	set(value):
		yaw_degrees = value
		_update()
## Inclinaison vers le bas (30° = isométrique classique, comme les sprites)
@export_range(5, 90) var pitch_degrees := 30.0:
	set(value):
		pitch_degrees = value
		_update()
## Zoom : hauteur du monde visible à l'écran (plus grand = on voit plus loin)
@export var view_size := 40.0:
	set(value):
		view_size = value
		_update()

const DISTANCE := 100.0  # recul de la caméra (sans effet sur l'image en vue orthogonale)


func _ready() -> void:
	_update()


func _update() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = view_size
	far = DISTANCE * 3
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * DISTANCE
	transform = Transform3D(Basis(), target + offset).looking_at(target, Vector3.UP)
