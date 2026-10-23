# Autoload "Manette" : lit la manette Arduino (programme_arduino_de_test.ino).
# Le port est trouvé tout seul : on essaie chaque port série USB et on garde celui qui envoie
# des lignes "JoyX:...". Si plus rien n'arrive (débranchée), on recherche.
# Les ports Bluetooth de Windows sont ignorés : les ouvrir bloque le jeu plusieurs secondes.

extends Node

signal connected(port: String)
signal disconnected
signal piezo_hit(force: float)
signal joy_btn_pressed
signal joy2_btn_pressed
signal enc_btn_pressed
signal enc_tourne(delta: int)

const BAUDS := 115200
const ATTENTE_PORT := 2.5      # s : l'Arduino redémarre à l'ouverture du port avant d'envoyer
const SILENCE_MAX := 1.5       # s sans ligne valide : manette considérée débranchée
const PAUSE_RECHERCHE := 2.0   # s entre deux tours de recherche
const JOY_CENTRE := 512.0
const ZONE_MORTE := 0.15
const PIEZO_SEUIL := 25
const PIEZO_COOLDOWN := 0.15
const CLES := ["JoyX", "JoyY", "JoyBtn", "Joy2X", "Joy2Y", "Joy2Btn", "EncPos", "EncRPM", "EncBtn", "PiezoA"]

var serial: GdSerial
var port := ""             # port de la manette, vide tant qu'elle n'est pas trouvée
var connecte := false
var _ouvert := false
var _derniere_trame := 0.0
var joy := Vector2.ZERO    # joystick 1 : le joueur
var joy2 := Vector2.ZERO   # joystick 2 : le piégeur (meule, rocher)
var enc_pos := 0
var enc_rpm := 0.0
var brut := {}             # dernière trame complète, lue par le débogueur F3
var _enc_pos_prec := 0
var _joy_btn_prec := false
var _joy2_btn_prec := false
var _enc_btn_prec := false
var _piezo_pret_a := 0.0

func _ready() -> void:
	serial = GdSerial.new()
	serial.set_baud_rate(BAUDS)
	serial.set_timeout(10)
	add_child(preload("res://Scripts/manette_debug.gd").new())
	_chercher()

func _exit_tree() -> void:
	if serial and _ouvert:
		serial.close()

func _process(_dt: float) -> void:
	if serial == null or not _ouvert:
		return
	# On vide tout ce qui est arrivé depuis la dernière frame
	while serial.bytes_available() > 0:
		if _traiter(str(serial.readline()).strip_edges()):
			_derniere_trame = _maintenant()
			if not connecte:
				connecte = true
				print("Manette connectée sur ", port)
				connected.emit(port)
	if connecte and _maintenant() - _derniere_trame > SILENCE_MAX:
		_perdue()

# essaie les ports un par un jusqu'à trouver celui qui envoie des lignes de la manette
func _chercher() -> void:
	while not connecte:
		for info in serial.list_ports().values():
			var nom: String = info["port_name"]
			if not str(info.get("port_type", "")).begins_with("USB"):
				continue
			serial.set_port(nom)
			if not serial.open():
				continue  # pris par un autre programme (moniteur série ?) ou absent
			port = nom
			_ouvert = true
			serial.clear_buffer()
			var fin := _maintenant() + ATTENTE_PORT
			while not connecte and _maintenant() < fin:
				await get_tree().create_timer(0.1).timeout
			if connecte:
				return
			serial.close()
			_ouvert = false
			port = ""
		await get_tree().create_timer(PAUSE_RECHERCHE).timeout

func _perdue() -> void:
	serial.close()
	_ouvert = false
	connecte = false
	port = ""
	joy = Vector2.ZERO
	joy2 = Vector2.ZERO
	disconnected.emit()
	_chercher()

func _maintenant() -> float:
	return Time.get_ticks_msec() / 1000.0

# true si la ligne est une trame complète de la manette
func _traiter(ligne: String) -> bool:
	var v := {}
	for champ in ligne.split("\t"):
		var kv := champ.split(":")
		if kv.size() == 2:
			v[kv[0]] = kv[1].to_float()
	# Ligne incomplète ou message de démarrage : on ignore
	for c in CLES:
		if not v.has(c):
			return false
	brut = v

	joy =_joystick(v["JoyX"], v["JoyY"])
	joy2 = _joystick(v["Joy2X"], v["Joy2Y"])

	var jb: bool = v["JoyBtn"] == 1.0
	if jb and not _joy_btn_prec: joy_btn_pressed.emit()
	_joy_btn_prec = jb
	var jb2: bool = v["Joy2Btn"] == 1.0
	if jb2 and not _joy2_btn_prec: joy2_btn_pressed.emit()
	_joy2_btn_prec = jb2
	var eb: bool = v["EncBtn"] == 1.0
	if eb and not _enc_btn_prec: enc_btn_pressed.emit()
	_enc_btn_prec = eb

	enc_pos = int(v["EncPos"])
	var d := enc_pos - _enc_pos_prec
	if d != 0: enc_tourne.emit(d)
	_enc_pos_prec = enc_pos
	enc_rpm = v["EncRPM"]

	var maintenant := _maintenant()
	if v["PiezoA"] > PIEZO_SEUIL and maintenant >= _piezo_pret_a:
		piezo_hit.emit(v["PiezoA"] / 1023.0)
		_piezo_pret_a = maintenant + PIEZO_COOLDOWN
	return true


# valeurs 0..1023 de l'Arduino -> -1..1, avec une zone morte au centre
func _joystick(x: float, y: float) -> Vector2:
	var j := Vector2((x - JOY_CENTRE) / JOY_CENTRE, (y - JOY_CENTRE) / JOY_CENTRE)
	for axe in [0, 1]:
		j[axe] = 0.0 if absf(j[axe]) < ZONE_MORTE else clampf(j[axe], -1.0, 1.0)
	return j
