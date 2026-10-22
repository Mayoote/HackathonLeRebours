# Salle du trésor : l'or scintille, et un petit carillon la première fois qu'on y entre.
# (Le trésor ne sert à rien dans les règles : c'est juste le décor de l'histoire.)

extends Node3D

@export var area := Rect2(-41, -18, 29, 13)
@export var floor_y := 16.97

var visited := false


func _ready() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 0.8, 0), Color(1, 0.9, 0.5, 1), Color(1, 0.8, 0.3, 0)])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mat
	var sparkles := CPUParticles3D.new()
	sparkles.mesh = quad
	sparkles.amount = 40
	sparkles.lifetime = 1.2
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkles.emission_box_extents = Vector3(5, 1.5, 4)
	sparkles.direction = Vector3.UP
	sparkles.spread = 20.0
	sparkles.initial_velocity_min = 0.3
	sparkles.initial_velocity_max = 1.0
	sparkles.gravity = Vector3.ZERO
	sparkles.color_ramp = grad
	sparkles.position = Vector3(-32, floor_y + 2.5, -13)
	add_child(sparkles)


func _process(_delta: float) -> void:
	if visited:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and absf(player.global_position.y - 3.75 - floor_y) < 1.0 and area.has_point(Vector2(player.global_position.x, player.global_position.z)):
		visited = true
		Sfx.play("tresor", -2.0)
