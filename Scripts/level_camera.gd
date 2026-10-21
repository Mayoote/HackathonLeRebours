@tool
extends Camera3D

@export var target := Vector3.ZERO:
	set(value):
		target = value
		update_camera()
@export_range(-180, 180) var yaw_degrees := 45.0:
	set(value):
		yaw_degrees = value
		update_camera()
@export_range(5, 90) var pitch_degrees := 30.0:  # 30 = même angle que les sprites
	set(value):
		pitch_degrees = value
		update_camera()
@export var view_size := 40.0:
	set(value):
		view_size = value
		update_camera()


func _ready() -> void:
	update_camera()


func update_camera() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = view_size
	far = 300
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 100.0
	transform = Transform3D(Basis(), target + offset).looking_at(target, Vector3.UP)
