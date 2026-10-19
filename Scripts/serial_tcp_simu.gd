# serial_tcp_simu.gd
# Remplaçant de GdSerial pour les TESTS SANS CARTE : parle au simulateur Python
# (simulateur_arduino.py --tcp 5555) par TCP local, avec les mêmes fonctions que GdSerial.
# Utilisé automatiquement par arduino_manager.gd quand ARDUINO_PORT commence par "tcp://".
# Pourquoi : sur macOS, GdSerial ne sait pas ouvrir un pseudo-terminal (erreur "Not a typewriter"),
# donc un faux port série ne marche pas. Ce fichier ne sert à rien avec une vraie carte.
class_name SerialTcpSimu
extends RefCounted

var _peer := StreamPeerTCP.new()
var _host := "127.0.0.1"
var _port := 5555

func list_ports() -> Dictionary:
	return {}

func set_baud_rate(_baud: int) -> void:
	pass

func set_timeout(_ms: int) -> void:
	pass

func set_port(port_name: String) -> void:
	# format attendu : tcp://127.0.0.1:5555
	var adresse := port_name.trim_prefix("tcp://")
	_host = adresse.get_slice(":", 0)
	_port = adresse.get_slice(":", 1).to_int()

func open() -> bool:
	_peer = StreamPeerTCP.new()
	if _peer.connect_to_host(_host, _port) != OK:
		return false
	var debut := Time.get_ticks_msec()
	while Time.get_ticks_msec() - debut < 1000:
		_peer.poll()
		match _peer.get_status():
			StreamPeerTCP.STATUS_CONNECTED:
				return true
			StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
				return false
		OS.delay_msec(10)
	return false

func close() -> void:
	_peer.disconnect_from_host()

func is_open() -> bool:
	_peer.poll()
	return _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED

func clear_buffer() -> bool:
	var n := bytes_available()
	if n > 0:
		_peer.get_data(n)
	return true

func writeline(texte: String) -> bool:
	return _peer.put_data((texte + "\n").to_utf8_buffer()) == OK

func bytes_available() -> int:
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return 0
	return _peer.get_available_bytes()

func read_string(taille: int) -> String:
	var res: Array = _peer.get_data(taille)
	if res[0] != OK:
		return ""
	return (res[1] as PackedByteArray).get_string_from_utf8()
