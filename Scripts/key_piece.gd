# Morceau de clé : invisible de loin, on le trouve au son (bip de plus en plus rapide)

extends Area3D

signal collected

@export var reveal_distance := 9.0

@onready var visual: Node3D = $Visual

var time := 0.0


func _ready() -> void:
	add_to_group("keys")
	body_entered.connect(_on_body_entered)
	visual.visible = false


func _process(delta: float) -> void:
	time += delta
	visual.rotation.y = time * 2.0
	visual.position.y = 3.0 + sin(time * 3.0) * 0.3
	var player := get_tree().get_first_node_in_group("player") as Node3D
	visual.visible = player != null and player.global_position.distance_to(global_position) < reveal_distance


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
