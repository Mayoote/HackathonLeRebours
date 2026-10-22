# Eau peu profonde : on y marche, mais plus lentement

extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if "in_water" in body:
		body.in_water += 1
		get_node("/root/Sfx").play("eclaboussure", -6.0)


func _on_body_exited(body: Node3D) -> void:
	if "in_water" in body:
		body.in_water = maxi(body.in_water - 1, 0)
