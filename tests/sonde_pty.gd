# tests/sonde_pty.gd — vérifie si GdSerial sait ouvrir un pseudo-terminal (pty), à plusieurs vitesses.
# ARDUINO_PORT=/dev/ttysXXX "<Godot>" --headless --path <projet> --script res://tests/sonde_pty.gd
extends SceneTree
func _init() -> void:
	var port := OS.get_environment("ARDUINO_PORT")
	for baud in [115200, 9600, 19200, 38400, 57600]:
		var s := GdSerial.new()
		s.set_port(port)
		s.set_baud_rate(baud)
		s.set_timeout(10)
		print("[SONDE] ", port, " @", baud, " open() -> ", s.open())
		s.close()
	quit()
