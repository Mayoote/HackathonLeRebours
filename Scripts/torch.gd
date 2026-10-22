# Lumière de torche qui vacille

extends OmniLight3D

var base := 0.0
var time := 0.0


func _ready() -> void:
	base = light_energy
	time = randf() * 10.0


func _process(delta: float) -> void:
	time += delta
	light_energy = base * (0.85 + 0.1 * sin(time * 9.0) + 0.06 * sin(time * 23.0 + 1.3))
