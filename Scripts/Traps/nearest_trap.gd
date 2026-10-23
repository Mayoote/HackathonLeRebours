# Groupe de pièges sur un seul bouton : le piégeur déclenche celui qui est le plus près du joueur,
# à son étage et prêt (les enfants ont trigger() et is_ready()).
# Avec auto_random, un piège proche du joueur, pris au hasard, part aussi tout seul de temps en temps.

extends Node3D

@export var reach := 14.0
@export var cooldown := 1.0  # entre deux déclenchements, quel que soit le piège
@export var auto_random := false
@export var auto_delay := Vector2(2.5, 6.0)  # attente min et max entre deux départs automatiques

var cooldown_left := 0.0
var auto_left := 0.0


func _ready() -> void:
	auto_left = randf_range(auto_delay.x, auto_delay.y)


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if auto_random and Partie.running:
		auto_left -= delta
		if auto_left <= 0.0:
			auto_left = randf_range(auto_delay.x, auto_delay.y)
			var traps := nearby()
			if not traps.is_empty():
				traps.pick_random().trigger()


func trigger() -> void:
	var traps := nearby()
	if traps.is_empty() or cooldown_left > 0.0:
		Sfx.play("refus", -6.0)
		return
	cooldown_left = cooldown
	traps[0].trigger()


# pièges prêts à portée, à l'étage du joueur, du plus proche au plus loin
func nearby() -> Array[Node3D]:
	var traps: Array[Node3D] = []
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return traps
	var feet := player.global_position.y - 3.75
	var flat := func(trap: Node3D) -> float:
		return Vector2(trap.global_position.x - player.global_position.x, trap.global_position.z - player.global_position.z).length()
	for trap in get_children():
		if trap.has_method("trigger") and trap.is_ready() and absf(trap.global_position.y - feet) < 4.5 and flat.call(trap) < reach:
			traps.append(trap)
	traps.sort_custom(func(a: Node3D, b: Node3D) -> bool: return flat.call(a) < flat.call(b))
	return traps
