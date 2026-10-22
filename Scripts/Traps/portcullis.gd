# Grille de sortie que le piégeur fait descendre à la manivelle (encodeur rotatif, ou K/L).
# Il faut mouliner longtemps (réglable) ; si on lâche, un contrepoids la remonte doucement.
# Fermée avant que le joueur soit passé : le piégeur gagne.

extends Node3D

signal trapped  # fermée avec le joueur encore du mauvais côté

@export var width := 10.0
@export var open_height := 9.5
@export var ticks_to_close := 1800      # crans d'encodeur pour la fermer complètement
@export var key_close_time := 75.0      # secondes de K/L maintenu pour la fermer
@export var lift_back := 0.01           # remontée par seconde quand personne ne mouline
@export var lift_delay := 0.6

var progress := 0.0
var closed := false
var cooldown_left := 0.0  # pour le HUD du piégeur
var idle := 0.0
var cran_timer := 0.0
var bars: Node3D
var shape: CollisionShape3D
var grind: AudioStreamPlayer


func _ready() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.19, 0.18)
	iron.metallic = 0.8
	iron.roughness = 0.45
	bars = Node3D.new()
	add_child(bars)
	var h := open_height + 1.0
	var n := int(width / 0.9)
	for i in n + 1:
		var z := -width / 2 + i * width / n
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.14
		cyl.height = h
		cyl.radial_segments = 6
		cyl.material = iron
		bar.mesh = cyl
		bar.position = Vector3(0, h / 2, z)
		bars.add_child(bar)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2
		cone.bottom_radius = 0.0
		cone.height = 0.6
		cone.radial_segments = 6
		cone.material = iron
		tip.mesh = cone
		tip.position = Vector3(0, -0.3, z)
		bars.add_child(tip)
	var y := 1.0
	while y < h:
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.22, width)
		box.material = iron
		rail.mesh = box
		rail.position.y = y
		bars.add_child(rail)
		y += 1.6

	var body := StaticBody3D.new()
	add_child(body)
	shape = CollisionShape3D.new()
	var wall := BoxShape3D.new()
	wall.size = Vector3(1.0, 12.0, width)
	shape.shape = wall
	shape.position.y = 6.0
	shape.disabled = true
	body.add_child(shape)

	grind = AudioStreamPlayer.new()
	grind.stream = Sfx.stream("grille_descend")
	grind.volume_db = -8.0
	grind.finished.connect(func(): if idle < 0.2 and not closed: grind.play())
	add_child(grind)
	update_bars()


# un cran d'encodeur
func add_ticks(n: int) -> void:
	add(float(n) / ticks_to_close)
	cran_timer -= 1.0
	if cran_timer <= 0.0:
		Sfx.play("manivelle_cran", -6.0, randf_range(0.95, 1.05))
		cran_timer = 3.0  # un clic tous les trois crans suffit


# touche maintenue (K/L) : appelé chaque frame avec delta
func crank_keys(delta: float) -> void:
	add(delta / key_close_time)
	cran_timer -= delta * 8.0
	if cran_timer <= 0.0:
		Sfx.play("manivelle_cran", -6.0, randf_range(0.95, 1.05))
		cran_timer = 1.0


func add(amount: float) -> void:
	if closed or amount <= 0.0:
		return
	progress = minf(progress + amount, 1.0)
	idle = 0.0
	if not grind.playing:
		grind.play()
	if progress >= 1.0:
		close()


func _process(delta: float) -> void:
	idle += delta
	if idle > 0.2 and grind.playing:
		grind.stop()
	if not closed and idle > lift_delay:
		progress = maxf(progress - lift_back * delta, 0.0)
	update_bars()


func update_bars() -> void:
	bars.position.y = open_height * (1.0 - progress)


func close() -> void:
	closed = true
	shape.disabled = false
	grind.stop()
	Sfx.play("grille_fermee")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.x < global_position.x:
		trapped.emit()
