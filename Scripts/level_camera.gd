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
@export var follow_height := false  # niveau à étages : la caméra monte avec le joueur
@export var follow_ground := 0.97
@export var follow_x := false  # couloir en ligne droite : la caméra suit le joueur en x
@export var lead_x := 7.0      # on voit plus loin devant que derrière

var base_y := 0.0


func _ready() -> void:
	base_y = target.y
	update_camera()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and follow_x:
		var goal_x := player.global_position.x + lead_x
		# respawn : on recale tout de suite au lieu de traverser tout le couloir
		target.x = goal_x if absf(goal_x - target.x) > 40.0 else lerpf(target.x, goal_x, 1.0 - exp(-4.0 * delta))
	if not follow_height:
		return
	if player and player.is_on_floor():
		var goal := base_y + maxf(player.global_position.y - 3.75 - follow_ground, 0.0)
		target.y = lerpf(target.y, goal, 1.0 - exp(-3.0 * delta))


func update_camera() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = view_size
	far = 300
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 100.0
	transform = Transform3D(Basis(), target + offset).looking_at(target, Vector3.UP)
