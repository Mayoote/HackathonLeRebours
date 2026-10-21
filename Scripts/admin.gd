extends Node

var traps: Array[Trap] = []
var index := 0
var enabled := true


func _ready() -> void:
	for node in get_tree().get_nodes_in_group("traps"):
		traps.append(node)
	# manette arduino : molette = choisir, bouton = déclencher
	ArduinoManager.encoder_changed.connect(_on_encoder_changed)
	ArduinoManager.button_changed.connect(_on_arduino_button)
	select(0)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("admin_next"):
		select(index + 1)
	elif event.is_action_pressed("admin_prev"):
		select(index - 1)
	elif event.is_action_pressed("admin_trigger"):
		trigger_selected()


func selected_trap() -> Trap:
	if traps.is_empty():
		return null
	return traps[index]


func trigger_selected() -> void:
	if enabled and selected_trap():
		selected_trap().trigger()


func select(i: int) -> void:
	if traps.is_empty():
		return
	traps[index].selected = false
	index = wrapi(i, 0, traps.size())
	traps[index].selected = true


func _on_encoder_changed(_pos: int, delta: int) -> void:
	if enabled and delta != 0:
		select(index + signi(delta))


func _on_arduino_button(pressed: bool) -> void:
	if pressed:
		trigger_selected()
