extends Area3D

signal player_reached

@export var hop_height := 0.5
@export var hop_speed := 2.5  # sauts par seconde

@onready var pad: MeshInstance3D = $Pad

var locked := true
var base_y: float
var time := 0.0
var mat: StandardMaterial3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_y = pad.position.y
	mat = (pad.mesh.material as StandardMaterial3D).duplicate()
	pad.material_override = mat


func unlock() -> void:
	locked = false


func _process(delta: float) -> void:
	if locked:
		# fermée : plaque grise et immobile
		mat.albedo_color = Color(0.5, 0.5, 0.5, 0.5)
		mat.emission_energy_multiplier = 0.0
		pad.position.y = base_y
		pad.scale = Vector3.ONE
		return
	# ouverte : petits sauts pour montrer la sortie, avec un léger écrasement à la retombée
	time += delta
	var hop := absf(sin(time * hop_speed * PI))
	pad.position.y = base_y + hop * hop_height
	var squash := 1.0 + (1.0 - hop) * 0.12
	pad.scale = Vector3(squash, 1.0, squash)
	mat.albedo_color = Color(0.3, 1, 0.5, 0.6)
	mat.emission_energy_multiplier = 0.9 + hop * 0.8


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_reached.emit()
