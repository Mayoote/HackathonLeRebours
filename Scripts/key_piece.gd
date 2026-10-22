# Morceau de clé : invisible de loin, on le trouve au son (bip de plus en plus rapide)

extends Area3D

signal collected

@export var reveal_distance := 9.0

@onready var visual: Node3D = $Visual

var time := 0.0
var taken := false


func _ready() -> void:
	add_to_group("keys")
	visual.visible = false


func _process(delta: float) -> void:
	time += delta
	visual.rotation.y = time * 2.0
	visual.position.y = 3.0 + sin(time * 3.0) * 0.3
	var player := get_tree().get_first_node_in_group("player") as Node3D
	visual.visible = player != null and player.global_position.distance_to(global_position) < reveal_distance
	if taken or player == null:
		return
	# il faut avoir les pieds au niveau de la clé : une clé en hauteur ne se prend pas d'en bas
	var feet: float = player.global_position.y - 3.75
	if overlaps_body(player) and absf(feet - global_position.y) < 0.8:
		taken = true
		collected.emit()
		queue_free()
