# trap.gd — piège à pics déclenché par l'admin
# Cycle : PRÊT → ALERTE (la plaque clignote, le joueur peut esquiver) → ACTIF (les pics
# sortent, le joueur touché perd une vie) → RECHARGE → PRÊT.
# Pour ajouter un piège : instancier Scenes/Traps/SpikeTrap.tscn dans le niveau.
# L'ordre de sélection par l'admin suit l'ordre des pièges dans l'arbre de la scène.

class_name Trap
extends Area3D

enum State { READY, WARNING, ACTIVE, COOLDOWN }

## Nom affiché à l'admin
@export var trap_name := "Pics"
## Durée du clignotement avant que les pics sortent (temps laissé au joueur pour esquiver)
@export var warning_time := 0.7
## Durée pendant laquelle les pics restent sortis
@export var active_time := 1.0
## Temps de recharge avant de pouvoir réutiliser ce piège
@export var cooldown := 4.0

const COLOR_READY := Color(0.45, 0.42, 0.38)
const COLOR_WARNING := Color(1.0, 0.55, 0.1)
const COLOR_COOLDOWN := Color(0.2, 0.19, 0.18)

@onready var plate: MeshInstance3D = $Plate
@onready var spikes: Node3D = $Spikes
@onready var marker: Node3D = $SelectionMarker

var state := State.READY
var cooldown_left := 0.0
var selected := false:
	set(value):
		selected = value
		if is_node_ready():
			marker.visible = value

var _spikes_hidden_y: float
var _time := 0.0


func _ready() -> void:
	add_to_group("traps")
	_spikes_hidden_y = spikes.position.y
	plate.material_override = StandardMaterial3D.new()
	marker.visible = selected
	body_entered.connect(_on_body_entered)


func trigger() -> bool:
	if state != State.READY:
		return false
	state = State.WARNING
	await get_tree().create_timer(warning_time).timeout

	state = State.ACTIVE
	var up := create_tween()
	up.tween_property(spikes, "position:y", 0.0, 0.08)
	for body in get_overlapping_bodies():
		_hit(body)
	await get_tree().create_timer(active_time).timeout

	var down := create_tween()
	down.tween_property(spikes, "position:y", _spikes_hidden_y, 0.3)
	state = State.COOLDOWN
	cooldown_left = cooldown
	return true


func _process(delta: float) -> void:
	_time += delta
	if state == State.COOLDOWN:
		cooldown_left -= delta
		if cooldown_left <= 0.0:
			state = State.READY

	# Couleur de la plaque selon l'état
	var mat := plate.material_override as StandardMaterial3D
	match state:
		State.READY:
			mat.albedo_color = COLOR_READY
		State.WARNING:
			mat.albedo_color = COLOR_WARNING if int(_time * 10) % 2 == 0 else COLOR_READY
		State.ACTIVE:
			mat.albedo_color = COLOR_WARNING
		State.COOLDOWN:
			mat.albedo_color = COLOR_COOLDOWN

	# Le marqueur de sélection flotte au-dessus du piège
	marker.position.y = 8.5 + sin(_time * 4.0) * 0.3


func _on_body_entered(body: Node3D) -> void:
	if state == State.ACTIVE:
		_hit(body)


func _hit(body: Node3D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(global_position)
