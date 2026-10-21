# goal.gd — sortie du niveau : le joueur gagne en atteignant la plaque verte devant la porte

extends Area3D

signal player_reached


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_reached.emit()
