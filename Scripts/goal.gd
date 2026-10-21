# goal.gd — sortie du niveau : le joueur gagne en l'atteignant

extends Area3D

signal player_reached

var _time := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	$Beacon.rotation.y = _time * 1.5


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_reached.emit()
