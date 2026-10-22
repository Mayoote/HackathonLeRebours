# Trappe : un morceau de sol qui s'ouvre sur le vide quelques secondes.
# Elle clignote et tremble avant de s'ouvrir pour laisser le joueur réagir.

extends Node3D

@export var size := Vector2(5, 5)
@export var warning_time := 0.8
@export var open_time := 2.5
@export var cooldown := 5.0

var cooldown_left := 0.0
var busy := false
var shape: CollisionShape3D
var pivots: Array[Node3D] = []
var mat: StandardMaterial3D


func _ready() -> void:
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.3, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0.1)
	mat.emission_energy_multiplier = 0.0

	var body := StaticBody3D.new()
	add_child(body)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 0.4, size.y)
	shape.shape = box
	shape.position.y = -0.2
	body.add_child(shape)

	# deux battants qui pivotent sur les bords
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * size.x / 2, 0, 0)
		add_child(pivot)
		var half := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x / 2 - 0.05, 0.3, size.y - 0.1)
		mesh.material = mat
		half.mesh = mesh
		half.position = Vector3(-side * size.x / 4, -0.15, 0)
		pivot.add_child(half)
		pivots.append(pivot)
	# fente au milieu pour qu'on devine la trappe
	var line := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.12, 0.31, size.y - 0.1)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.07, 0.06)
	lm.material = dark
	line.mesh = lm
	line.position.y = -0.14
	add_child(line)


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_ready() -> bool:
	return not busy and cooldown_left <= 0.0


func trigger() -> void:
	if busy or cooldown_left > 0.0:
		Sfx.play("refus", -6.0)
		return
	busy = true
	cooldown_left = warning_time + open_time + cooldown

	var t := 0.0
	while t < warning_time:
		mat.emission_energy_multiplier = 1.5 if int(t * 10) % 2 == 0 else 0.3
		for p in pivots:
			p.rotation.z = randf_range(-0.03, 0.03)
		await get_tree().process_frame
		t += get_process_delta_time()
	mat.emission_energy_multiplier = 0.0

	Sfx.play("trappe_ouverture")
	shape.disabled = true
	var open := create_tween().set_parallel()
	open.tween_property(pivots[0], "rotation:z", -PI / 2, 0.25)
	open.tween_property(pivots[1], "rotation:z", PI / 2, 0.25)
	await get_tree().create_timer(open_time).timeout

	var close := create_tween().set_parallel()
	close.tween_property(pivots[0], "rotation:z", 0.0, 0.4)
	close.tween_property(pivots[1], "rotation:z", 0.0, 0.4)
	await close.finished
	shape.disabled = false
	busy = false
