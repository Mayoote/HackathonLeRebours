# tests/sonde_ports.gd — liste les ports vus par GdSerial (n'ouvre rien, n'envoie rien).
# "<Godot>" --headless --path <projet> --script res://tests/sonde_ports.gd
extends SceneTree
func _init() -> void:
	var s := GdSerial.new()
	var ports: Dictionary = s.list_ports()
	print("[PORTS] ", ports.size(), " port(s)")
	for p in ports.values():
		print("[PORTS] ", p["port_name"], "  type=", p.get("port_type", "?"), "  nom=", p.get("device_name", "?"))
	quit()
