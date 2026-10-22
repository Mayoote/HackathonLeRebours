# Fientes de pigeons : 5-6 tombent au hasard autour du joueur.
# Une ombre prévient 1 s avant l'impact : un joueur attentif a le temps de s'écarter.

extends Node3D

@export var count := Vector2i(5, 6)
@export var radius := 9.0
@export var warning_time := 1.0
@export var hit_radius := 2.2
@export var slow_time := 2.5
@export var cooldown := 6.0
@export var ground_y := 0.97

var cooldown_left := 0.0
var shadow_mat: StandardMaterial3D
var drop_mat: StandardMaterial3D


func _ready() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 0.8, 0.9, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.6), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	shadow_mat = StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_texture = tex
	drop_mat = StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.95, 0.95, 0.88)
	drop_mat.roughness = 0.3


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func trigger() -> void:
	if cooldown_left > 0.0:
		Sfx.play("refus", -6.0)
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	cooldown_left = cooldown
	Sfx.play("pigeons")
	var n := randi_range(count.x, count.y)
	for i in n:
		var offset := Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		var spot := Vector3(player.global_position.x + offset.x, ground_y, player.global_position.z + offset.y)
		drop(spot, randf_range(0.0, 0.4))


func drop(spot: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(hit_radius * 2.2, hit_radius * 2.2)
	plane.material = shadow_mat
	shadow.mesh = plane
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	shadow.global_position = spot + Vector3.UP * 0.5
	shadow.scale = Vector3(0.2, 1, 0.2)
	create_tween().tween_property(shadow, "scale", Vector3.ONE, warning_time)

	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.8
	sphere.material = drop_mat
	blob.mesh = sphere
	add_child(blob)
	blob.global_position = spot + Vector3.UP * 30.0
	var fall := create_tween()
	fall.tween_interval(warning_time * 0.6)
	fall.tween_callback(Sfx.play.bind("fiente_chute", -14.0, randf_range(0.9, 1.1)))
	fall.tween_property(blob, "global_position", spot + Vector3.UP * 0.5, warning_time * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fall.finished

	blob.queue_free()
	Sfx.play("fiente_splat", -8.0, randf_range(0.85, 1.15))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var flat := Vector2(player.global_position.x - spot.x, player.global_position.z - spot.z)
		if flat.length() < hit_radius and player.global_position.y - spot.y < 6.0:
			player.slow_down(slow_time)

	# la tache reste un moment au sol
	var splat := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.05
	disc.material = drop_mat
	splat.mesh = disc
	add_child(splat)
	splat.global_position = spot + Vector3.UP * 0.55
	splat.scale = Vector3(randf_range(0.8, 1.3), 1, randf_range(0.8, 1.3))
	shadow.queue_free()
	await get_tree().create_timer(4.0).timeout
	var fade := create_tween()
	fade.tween_property(splat, "scale", Vector3(0.01, 1, 0.01), 0.6)
	await fade.finished
	splat.queue_free()
