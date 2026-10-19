# arduino_manager.gd
extends Node2D

# ── Signaux ────────────────────────────────────────────
signal arduino_disconnected()
signal arduino_connected()
signal pairing_success(port: String)
signal pairing_failed()
signal button_changed(pressed: bool)
signal sensor_changed(value: int)                 # trame "sensor:<0..1023>" (potentiomètre / capteur A0)
signal encoder_changed(position: int, delta: int) # trame "enc:<position>" (encodeur rotatif, manette de Tom)
signal message_received(key: String, value: String) # TOUTE trame "clé:valeur" reçue (pour vos propres capteurs)

# ── Constantes de pairing ──────────────────────────────
const DISCOVER_MSG  := "DISCOVER"
const ACK_PREFIX    := "GDSERIAL_ACK"
const PAIR_TIMEOUT  := 0.35   # secondes d'attente par port
const BAUD_RATE     := 115200
# Only try ports whose name contains one of these hints. Avoids opening
# tty.Bluetooth-Incoming-Port / tty.debug-console on macOS (which hang the scan).
# "COM" covers Windows (COM3, COM7, ...).
const PORT_NAME_HINTS: PackedStringArray = ["usbmodem", "usbserial", "ttyACM", "ttyUSB", "COM"]
const SCAN_RETRY_COOLDOWN := 2.0  # secondes avant de retenter un scan après échec
# Port forcé par la variable d'environnement ARDUINO_PORT (ex. ARDUINO_PORT=COM7, /dev/cu.usbmodem1101,
# ou tcp://127.0.0.1:5555 pour le simulateur). S'il est défini, c'est le SEUL port essayé, même s'il
# n'apparaît pas dans list_ports(). Pas de fichier de configuration : un fichier oublié empêcherait
# de retrouver la vraie carte. Même code que dans le projet Godot_Blocks (hackathon oct. 2026).
const PORT_OVERRIDE_ENV := "ARDUINO_PORT"

# ── État interne ───────────────────────────────────────
var serial  # un GdSerial (vraie carte) ou un SerialTcpSimu (simulateur, si ARDUINO_PORT=tcp://...)
var _paired: bool   = false
var _wasPaired: bool = false
var _buffer: String = ""
var paired_port: String = ""
var timerHeartBeat: float = 0.0
var timerHeartBeatMax: float = 2.0
var lastPortNameUsed
var _is_pairing: bool = false  # garde contre ré-entrance (process tourne à 60 Hz)
var _pairing_cooldown: float = 0.0
# Dernières valeurs reçues (pour qui préfère lire une variable plutôt qu'écouter un signal)
var sensor_value: int = 0
var encoder_position: int = 0
var button_pressed: bool = false
var _debug: bool = OS.get_environment("ARDUINO_DEBUG") == "1"  # ARDUINO_DEBUG=1 : affiche le détail du pairing

func _ready() -> void:
	if _get_port_override().begins_with("tcp://"):
		serial = SerialTcpSimu.new()  # test sans carte : voir Scripts/serial_tcp_simu.gd
	else:
		serial = GdSerial.new()
	serial.set_baud_rate(BAUD_RATE)
	serial.set_timeout(10)
	start_pairing()

# ══ PAIRING ═══════════════════════════════════════════

func start_pairing() -> void:
	if _is_pairing:
		return  # scan déjà en cours, évite d'empiler des coroutines
	_is_pairing = true
	_paired = false
	_wasPaired = false
	paired_port = ""
	encoder_position = 0  # l'Arduino repart de 0 à chaque reset (ouverture du port)
	_buffer = ""          # oublie les morceaux de trame de l'ancienne connexion
	##print("[Pairing] Démarrage du scan des ports...")
	var ports: Dictionary = serial.list_ports()
	# Filtrer: ne tenter que les ports dont le nom contient un hint connu.
	var candidates: Array = []
	var override := _get_port_override()
	if override != "":
		# Port forcé : on n'essaie QUE lui (on n'envoie pas DISCOVER aux autres appareils).
		_dbg("[Pairing] Port forcé : " + override)
		candidates.append({"port_name": override})
	for port_info in ports.values():
		if override != "":
			break
		var port_name: String = port_info["port_name"]
		for hint in PORT_NAME_HINTS:
			if hint in port_name:
				candidates.append(port_info)
				break
	if candidates.is_empty():
		##print("[Pairing] Aucun port compatible détecté.")
		_pairing_cooldown = SCAN_RETRY_COOLDOWN
		_is_pairing = false
		emit_signal("pairing_failed")
		return

	# Lance le scan asynchrone sans bloquer Godot
	_scan_ports(candidates)

func _scan_ports(port_list: Array) -> void:
	for port_info in port_list:
		var port_name: String = port_info["port_name"]
		_dbg("[Pairing] Test de : " + port_name)
		serial.set_port(port_name)

		if not serial.open():
			_dbg("[Pairing]   → impossible d'ouvrir")
			continue

		serial.clear_buffer()

		# Attend que l'Arduino finisse son boot après l'ouverture du port
		await get_tree().create_timer(.5).timeout

		# Envoie DISCOVER plusieurs fois au cas où le premier serait perdu
		for i in range(3):
			serial.writeline(DISCOVER_MSG)
			await get_tree().create_timer(0.1).timeout
			var response := _read_all_available()
			_dbg("[Pairing]   tentative %d → '%s'" % [i + 1, response.strip_edges()])
			if ACK_PREFIX in response:
				# Garde ce qui suit la ligne d'ACK (premières trames capteur déjà arrivées)
				var fin_ack := response.find("\n", response.find(ACK_PREFIX))
				_buffer = response.substr(fin_ack + 1) if fin_ack != -1 else ""
				paired_port = port_name
				_paired = true
				_wasPaired = true
				lastPortNameUsed = port_name
				print("[Pairing]   → CONNECTÉ sur ", port_name)
				_is_pairing = false
				emit_signal("pairing_success", port_name)
				emit_signal("arduino_connected")
				return

		_dbg("[Pairing]   → pas de réponse")
		serial.close()

	##print("[Pairing] Aucun Arduino trouvé.")
	_pairing_cooldown = SCAN_RETRY_COOLDOWN
	_is_pairing = false
	emit_signal("pairing_failed")


func _get_port_override() -> String:
	return OS.get_environment(PORT_OVERRIDE_ENV).strip_edges()


func _dbg(msg: String) -> void:
	if _debug:
		print(msg)


func _read_all_available() -> String:
	var result := ""
	if serial.bytes_available() > 0:
		result = serial.read_string(serial.bytes_available())
	return result


# ══ COMMUNICATION EN TEMPS RÉEL ════════════════════════

func _process(_delta: float) -> void:
	timerHeartBeat -= _delta
	if _pairing_cooldown > 0.0:
		_pairing_cooldown -= _delta
	if _paired :
		if timerHeartBeat < 0 :
			timerHeartBeat = timerHeartBeatMax
			if not serial.is_open() :
				emit_signal("arduino_disconnected")
				_paired = false

	if not _paired:
		if not _is_pairing and _pairing_cooldown <= 0.0:
			start_pairing()
		return

	while serial.bytes_available() > 0:
		_buffer += serial.read_string(serial.bytes_available())

	while "\n" in _buffer:
		var idx  := _buffer.find("\n")
		var line := _buffer.substr(0, idx).strip_edges()
		_buffer   = _buffer.substr(idx + 1)
		if line.length() > 0:
			_parse_message(line)

func _parse_message(msg: String) -> void:
	var parts := msg.split(":", false, 1)
	if parts.size() < 2:
		return

	var key := parts[0].to_lower()  # "ENC:3" et "enc:3" sont acceptés
	var value := parts[1]
	emit_signal("message_received", key, value)

	match key:
		"button":
			button_pressed = value == "1"
			emit_signal("button_changed", button_pressed)
		"sensor":
			sensor_value = value.to_int()
			emit_signal("sensor_changed", sensor_value)
		"enc":
			var new_position := value.to_int()
			var delta := new_position - encoder_position
			encoder_position = new_position
			if delta != 0:
				emit_signal("encoder_changed", encoder_position, delta)
		"pong":
			print("[Arduino] Latence mesurée : ", Time.get_ticks_msec() - parts[1].to_int(), " ms")
		"ack":
			print("[Arduino] Ack : ", parts[1])
		_:
			pass
			#print("[Arduino] Message inconnu : ", msg)

# ══ API PUBLIQUE ══════════════════════════════════════

func send_led(on: bool) -> void:
	_send("led:" + ("1" if on else "0"))

func send_blink(times: int) -> void:
	_send("blink:" + str(times))

func send_ping() -> void:
	_send("ping:" + str(Time.get_ticks_msec()))

var _warned_unpaired: bool = false  # un seul avertissement par période « non appairé » (sinon 60 lignes/s)

func _send(cmd: String) -> void:
	if not _paired:
		if not _warned_unpaired:
			_warned_unpaired = true
			push_warning("[Arduino] Non pairé, commandes ignorées (première : " + cmd + ")")
		return
	_warned_unpaired = false
	serial.writeline(cmd)


func _exit_tree() -> void:
	if serial and serial.is_open():
		serial.close()
