# Le piégeur : vent (encodeur), fientes (bouton), meule (joystick)
# Clavier pour tester : K/L = vent, Entrée = fientes, flèches = meule

extends Node

@export var wind: Node3D
@export var pigeons: Node3D
@export var hay: CharacterBody3D
@export var wind_key_speed := 1.2  # par seconde, touche maintenue
@export var wind_encoder_step := 0.1

@onready var label: Label = %TrapperLabel

var enabled := true


func _ready() -> void:
	ArduinoManager.encoder_changed.connect(_on_encoder_changed)
	ArduinoManager.button_changed.connect(_on_arduino_button)


func _process(delta: float) -> void:
	if not enabled:
		if hay:
			hay.input = Vector2.ZERO
		return
	if wind:
		var w := Input.get_axis("wind_left", "wind_right")
		if w != 0.0:
			wind.add(w * wind_key_speed * delta)
	if hay:
		hay.input = Input.get_vector("hay_left", "hay_right", "hay_up", "hay_down")
	update_label()


func _unhandled_input(event: InputEvent) -> void:
	if enabled and pigeons and event.is_action_pressed("admin_trigger"):
		pigeons.trigger()


func _on_encoder_changed(_pos: int, delta: int) -> void:
	if enabled and wind:
		wind.add(delta * wind_encoder_step)


func _on_arduino_button(pressed: bool) -> void:
	if enabled and pressed and pigeons:
		pigeons.trigger()


func update_label() -> void:
	var lines := ["PIÉGEUR"]
	if wind:
		var n := roundi(absf(wind.strength) * 5)
		var arrows := ("◄".repeat(n) if wind.strength < 0 else "►".repeat(n)) if n > 0 else "—"
		lines.append("Vent : %s" % arrows)
	if pigeons:
		var cd: float = pigeons.cooldown_left
		lines.append("Pigeons : %s" % ("PRÊT" if cd <= 0.0 else "%.1f s" % cd))
	label.text = "\n".join(lines)
