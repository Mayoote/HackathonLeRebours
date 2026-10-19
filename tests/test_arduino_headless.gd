# tests/test_arduino_headless.gd
# Test automatique de la chaîne Arduino -> Godot, SANS fenêtre.
# Lancer (le simulateur ou la vraie carte doivent être branchés) :
#   Sur Mac avec le simulateur (GdSerial refuse les pty) : python3 simulateur_arduino.py --tcp 5555, puis
#   ARDUINO_PORT=tcp://127.0.0.1:5555 "<Godot>" --headless --path <projet> res://tests/test_arduino_headless.tscn
#   Avec une vraie carte : sans ARDUINO_PORT (ou ARDUINO_PORT=/dev/cu.usbmodemXXXX, COM3...).
# Le test s'arrête seul après 8 s (ou TEST_DUREE=30 pour 30 s) et affiche un bilan "[TEST] ...".
extends Node

var DUREE: float = OS.get_environment("TEST_DUREE").to_float() if OS.get_environment("TEST_DUREE") != "" else 8.0

var _t := 0.0
var _nb := {"sensor": 0, "button": 0, "enc": 0, "autres": 0}
var _connecte_a := -1.0
var _ping_envoye := false
var _fini := false

func _ready() -> void:
	print("[TEST] démarrage ; ARDUINO_PORT='", OS.get_environment("ARDUINO_PORT"), "'")
	ArduinoManager.pairing_success.connect(func(port): _connecte_a = _t; print("[TEST] pairing_success sur ", port, " après ", snappedf(_t, 0.01), " s"))
	ArduinoManager.arduino_disconnected.connect(func(): print("[TEST] arduino_disconnected à ", snappedf(_t, 0.01), " s"))
	ArduinoManager.button_changed.connect(func(p): _nb["button"] += 1; print("[TEST] button_changed ", p))
	ArduinoManager.sensor_changed.connect(func(v): _nb["sensor"] += 1; if _nb["sensor"] % 20 == 1: print("[TEST] sensor_changed ", v))
	ArduinoManager.encoder_changed.connect(func(pos, d): _nb["enc"] += 1; print("[TEST] encoder_changed position=", pos, " delta=", d))
	ArduinoManager.message_received.connect(func(k, v): if not k in ["sensor", "button", "enc"]: _nb["autres"] += 1; print("[TEST] message ", k, ":", v))

func _process(delta: float) -> void:
	_t += delta
	if _connecte_a >= 0.0 and not _ping_envoye and _t - _connecte_a > 0.5:
		_ping_envoye = true
		ArduinoManager.send_ping()
		ArduinoManager.send_led(true)
		ArduinoManager.send_blink(2)
	if _t >= DUREE and not _fini:
		_fini = true
		print("[TEST] BILAN apparie=", _connecte_a >= 0.0, " port=", ArduinoManager.paired_port,
			" sensor=", _nb["sensor"], " button=", _nb["button"], " enc=", _nb["enc"], " autres=", _nb["autres"],
			" derniere_valeur_sensor=", ArduinoManager.sensor_value, " position_enc=", ArduinoManager.encoder_position)
		get_tree().quit(0 if _connecte_a >= 0.0 else 1)
