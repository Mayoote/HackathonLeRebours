# admin.gd — le joueur « admin » : choisit un piège du niveau et le déclenche
# Commandes :
#   - manette n°1 : croix gauche/droite ou LB/RB pour choisir, A pour déclencher
#   - clavier : flèches gauche/droite pour choisir, Entrée pour déclencher
#   - manette Arduino : molette (encodeur) pour choisir, bouton pour déclencher
# Les pièges sont tous les nœuds Trap du niveau, dans l'ordre de l'arbre de la scène.

extends Node

signal selection_changed(trap: Trap)

var traps: Array[Trap] = []
var index := 0
var enabled := true


func _ready() -> void:
	for node in get_tree().get_nodes_in_group("traps"):
		traps.append(node as Trap)
	ArduinoManager.encoder_changed.connect(_on_encoder_changed)
	ArduinoManager.button_changed.connect(_on_arduino_button)
	_select(0)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("admin_next"):
		_select(index + 1)
	elif event.is_action_pressed("admin_prev"):
		_select(index - 1)
	elif event.is_action_pressed("admin_trigger"):
		trigger_selected()


func selected_trap() -> Trap:
	return traps[index] if not traps.is_empty() else null


func trigger_selected() -> void:
	if enabled and selected_trap():
		selected_trap().trigger()


func _select(new_index: int) -> void:
	if traps.is_empty():
		return
	traps[index].selected = false
	index = wrapi(new_index, 0, traps.size())
	traps[index].selected = true
	selection_changed.emit(traps[index])


func _on_encoder_changed(_position: int, delta: int) -> void:
	if enabled and delta != 0:
		_select(index + signi(delta))


func _on_arduino_button(pressed: bool) -> void:
	if pressed:
		trigger_selected()
