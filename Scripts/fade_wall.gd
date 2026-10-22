# Mur qui devient transparent quand le joueur passe derrière (vue isométrique)

extends Node3D

@export var material: StandardMaterial3D
@export var wall_z := 0.0
@export var x_range := Vector2(-100, 100)
@export var depth := 10.0      # jusqu'où derrière le mur on le rend transparent
@export var faded_alpha := 0.25


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target := 1.0
	if player:
		var p := player.global_position
		if p.z < wall_z and p.z > wall_z - depth and p.x > x_range.x - 3 and p.x < x_range.y + 3:
			target = faded_alpha
	material.albedo_color.a = move_toward(material.albedo_color.a, target, delta * 4.0)
