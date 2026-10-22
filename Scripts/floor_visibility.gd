# Étages en vue isométrique : l'étage du dessus cacherait le rez-de-chaussée.
# Joueur en bas : l'étage est caché. Joueur en haut : l'étage s'affiche,
# la caméra monte et un voile sombre atténue le rez-de-chaussée.

extends Node

@export var upper_nodes: Array[Node3D] = []
@export var lower_nodes: Array[Node3D] = []   # visibles seulement quand le joueur est en bas
@export var veil: Node3D
@export var extra: Array[Node] = []   # nœuds qui gèrent eux-mêmes leurs parties d'étage (set_upper_visible)
@export var camera: Camera3D
@export var switch_height := 12.0   # hauteur des pieds à partir de laquelle on est « en haut »
@export var camera_rise := 16.0

var base_target: Vector3
var upstairs := false


func _ready() -> void:
	base_target = camera.target
	apply(false)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var up: bool = player.global_position.y - 3.75 > switch_height
		if up != upstairs:
			apply(up)
	var goal := base_target + Vector3.UP * (camera_rise if upstairs else 0.0)
	if camera.target.distance_to(goal) > 0.01:
		camera.target = camera.target.lerp(goal, minf(delta * 3.0, 1.0))


func apply(up: bool) -> void:
	upstairs = up
	for n in lower_nodes:
		n.visible = not up
	for n in upper_nodes:
		n.visible = up
	for n in extra:
		if n.has_method("set_upper_visible"):
			n.set_upper_visible(up)
	if veil:
		veil.visible = up
