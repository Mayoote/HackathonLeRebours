class_name Trap
extends Area3D

enum State { READY, WARNING, ACTIVE, COOLDOWN }

@export var trap_name := "Pics"
@export var warning_time := 0.7
@export var active_time := 1.0
@export var cooldown := 4.0

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

var hidden_y: float
var time := 0.0
var mat := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("traps")
	hidden_y = spikes.position.y
	plate.material_override = mat
	marker.visible = selected
	body_entered.connect(_on_body_entered)


func trigger() -> void:
	if state != State.READY:
		return
	# la plaque clignote d'abord pour laisser le joueur esquiver
	state = State.WARNING
	await get_tree().create_timer(warning_time).timeout

	state = State.ACTIVE
	create_tween().tween_property(spikes, "position:y", 0.0, 0.08)
	for body in get_overlapping_bodies():
		hit(body)
	await get_tree().create_timer(active_time).timeout

	create_tween().tween_property(spikes, "position:y", hidden_y, 0.3)
	state = State.COOLDOWN
	cooldown_left = cooldown


func _process(delta: float) -> void:
	time += delta
	if state == State.COOLDOWN:
		cooldown_left -= delta
		if cooldown_left <= 0.0:
			state = State.READY

	match state:
		State.READY:
			mat.albedo_color = Color(0.45, 0.42, 0.38)
		State.WARNING:
			mat.albedo_color = Color(1, 0.55, 0.1) if int(time * 10) % 2 == 0 else Color(0.45, 0.42, 0.38)
		State.ACTIVE:
			mat.albedo_color = Color(1, 0.55, 0.1)
		State.COOLDOWN:
			mat.albedo_color = Color(0.2, 0.19, 0.18)

	marker.position.y = 11.0 + sin(time * 4.0) * 0.3


func _on_body_entered(body: Node3D) -> void:
	if state == State.ACTIVE:
		hit(body)


func hit(body: Node3D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(global_position)
