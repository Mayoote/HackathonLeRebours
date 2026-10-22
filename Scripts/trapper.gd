# Le piégeur. Chaque niveau branche les pièges qu'il veut :
#  - wind : vent réglé en tournant le codeur (ou K/L, LB/RB)
#  - button_trap : piège du piézo (ou Entrée, A) : pigeons, stalactites
#  - mover : objet déplacé au joystick 2 (ou flèches, stick gauche) : meule, rocher
#  - numbered_traps : pièges sur les boutons 1, 2, 3 (touches 1/2/3, B/X/Y)
#  - crank : grille de sortie qu'on ferme en tournant le codeur (ou K/L maintenu)
#  - encoder_button_trap : piège du bouton du codeur : lance-flammes
#  - joy2_button_traps : bouton du joystick 2, le plus proche du joueur : trappes, pics

extends Node

@export var wind: Node3D
@export var button_trap: Node
@export var button_trap_name := "Pigeons"
@export var mover: Node3D
@export var mover_name := ""
@export var numbered_traps: Array[Node] = []
@export var numbered_names: Array[String] = []  # vide : "Trappe 1", "Trappe 2"...
@export var crank: Node3D
@export var encoder_button_trap: Node
@export var joy2_button_traps: Array[Node] = []
@export var inverser_joy2_x := false
@export var inverser_joy2_y := false
@export var wind_key_speed := 1.2  # par seconde, touche maintenue
@export var wind_encoder_step := 0.1

@onready var label: Label = get_tree().get_first_node_in_group("trapper_label")

var enabled := true


func _ready() -> void:
	# manette Arduino (Scripts/manette.gd)
	Manette.enc_tourne.connect(_on_encoder_changed)
	Manette.piezo_hit.connect(_on_piezo)
	Manette.enc_btn_pressed.connect(_on_encoder_button)
	Manette.joy2_btn_pressed.connect(_on_joy2_button)


func _process(delta: float) -> void:
	if not enabled:
		if mover:
			mover.input = Vector2.ZERO
		return
	if wind:
		var w := Input.get_axis("wind_left", "wind_right")
		if w != 0.0:
			wind.add(w * wind_key_speed * delta)
	if mover:
		var joy2: Vector2 = Manette.joy2
		if inverser_joy2_x:
			joy2.x = -joy2.x
		if inverser_joy2_y:
			joy2.y = -joy2.y
		mover.input = (Input.get_vector("hay_left", "hay_right", "hay_up", "hay_down") + joy2).limit_length(1.0)
	if crank:
		var c := absf(Input.get_axis("wind_left", "wind_right"))
		if c > 0.0:
			crank.crank_keys(c * delta)
	update_label()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if button_trap and event.is_action_pressed("admin_trigger"):
		button_trap.trigger()
	for i in numbered_traps.size():
		if event.is_action_pressed("trap_%d" % (i + 1)):
			numbered_traps[i].trigger()


func _on_encoder_changed(delta: int) -> void:
	if enabled and wind:
		wind.add(delta * wind_encoder_step)
	if enabled and crank:
		crank.add_ticks(absi(delta))  # on peut mouliner dans les deux sens


func _on_piezo(_force: float) -> void:
	if enabled and button_trap:
		button_trap.trigger()


func _on_encoder_button() -> void:
	if enabled and encoder_button_trap:
		encoder_button_trap.trigger()


func _on_joy2_button() -> void:
	if enabled and not joy2_button_traps.is_empty():
		trigger_nearest(joy2_button_traps)


# plusieurs pièges sur un seul bouton : celui qui est prêt et le plus près du joueur
func trigger_nearest(traps: Array[Node]) -> void:
	if traps.size() == 1:
		traps[0].trigger()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var best: Node = null
	var best_d := INF
	for trap in traps:
		if player == null or (trap.has_method("is_ready") and not trap.is_ready()):
			continue
		var p: Vector3 = trap.global_position - player.global_position
		var d := Vector2(p.x, p.z).length()
		if d < best_d:
			best = trap
			best_d = d
	if best:
		best.trigger()
	else:
		Sfx.play("refus", -6.0)


func status(trap: Node) -> String:
	var cd: float = trap.cooldown_left
	return "PRÊT" if cd <= 0.0 else "%.1f s" % cd


func update_label() -> void:
	var lines := ["PIÉGEUR"]
	if wind:
		var n := roundi(absf(wind.strength) * 5)
		var arrows := ("◄".repeat(n) if wind.strength < 0 else "►".repeat(n)) if n > 0 else "—"
		lines.append("Vent : %s" % arrows)
	if button_trap:
		lines.append("%s : %s" % [button_trap_name, status(button_trap)])
	if mover and mover_name != "" and "cooldown_left" in mover:
		lines.append("%s : %s" % [mover_name, status(mover)])
	for i in numbered_traps.size():
		var trap_name := "%s (%d)" % [numbered_names[i], i + 1] if i < numbered_names.size() else "Trappe %d" % (i + 1)
		lines.append("%s : %s" % [trap_name, status(numbered_traps[i])])
	if crank:
		var n := roundi(crank.progress * 10)
		lines.append("Grille : %s %d %%" % ["█".repeat(n) + "░".repeat(10 - n), roundi(crank.progress * 100)])
	label.text = "\n".join(lines)
