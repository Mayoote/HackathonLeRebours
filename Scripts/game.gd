# game.gd — exemple d'utilisation

extends Node2D

@onready var arduino = ArduinoManager  # le script en autoload

func _ready() -> void:
	# Connexion aux signaux
	arduino.button_changed.connect(_on_button)
	arduino.arduino_disconnected.connect(_on_disconnected)
	arduino.arduino_connected.connect(_on_connected)
	
func _on_arduino_ready() -> void:
	print("Arduino en ligne, envoi d'un ping...")
	arduino.send_ping()

func _on_button(pressed: bool) -> void:
	if pressed:
		$Label.add_theme_color_override("font_color", Color.RED)
	else:
		$Label.add_theme_color_override("font_color", Color.BLUE)

func _on_button_button_down() -> void:
	arduino.send_led(true)
	
func _on_disconnected() -> void:
		$Label2.visible = true

func _on_connected() -> void:
		$Label2.visible = false
