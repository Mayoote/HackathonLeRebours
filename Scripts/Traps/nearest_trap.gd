# Groupe de pièges sur un seul bouton : le piégeur déclenche celui qui est le plus près du joueur,
# à son étage et prêt (les enfants ont trigger() et is_ready()).

extends Node3D

@export var reach := 14.0
@export var cooldown := 1.0  # entre deux déclenchements, quel que soit le piège

var cooldown_left := 0.0


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func trigger() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or cooldown_left > 0.0:
		Sfx.play("refus", -6.0)
		return
	var feet := player.global_position.y - 3.75
	var best: Node3D = null
	var best_d := reach
	for trap in get_children():
		if not trap.has_method("trigger") or not trap.is_ready():
			continue
		var p: Vector3 = trap.global_position
		var d := Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length()
		if absf(p.y - feet) < 4.5 and d < best_d:
			best = trap
			best_d = d
	if best == null:
		Sfx.play("refus", -6.0)
		return
	cooldown_left = cooldown
	best.trigger()
