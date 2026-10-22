extends Node

signal piezo_hit(force: float)
signal joy_btn_pressed
signal joy2_btn_pressed
signal enc_btn_pressed
signal enc_tourne(delta: int)

const PORT_SERIE := "COM5"        # <-- ton port, trouvé à l'étape 2
const BAUDS := 115200
const JOY_CENTRE := 512.0
const ZONE_MORTE := 0.15
const PIEZO_SEUIL := 150
const PIEZO_COOLDOWN := 0.15
const CLES := ["JoyX", "JoyY", "JoyBtn", "Joy2X", "Joy2Y", "Joy2Btn", "EncPos", "EncRPM", "EncBtn", "PiezoA"]

var serial: GdSerial
var joy := Vector2.ZERO    # joystick 1 : le joueur
var joy2 := Vector2.ZERO   # joystick 2 : le piégeur (meule, rocher)
var enc_pos := 0
var enc_rpm := 0.0
var _enc_pos_prec := 0
var _joy_btn_prec := false
var _joy2_btn_prec := false
var _enc_btn_prec := false
var _piezo_pret_a := 0.0

func _ready() -> void:
	serial = GdSerial.new()
	serial.set_port(PORT_SERIE)
	serial.set_baud_rate(BAUDS)
	if serial.open():
		print("Manette connectée sur ", PORT_SERIE)
	else:
		push_error("Impossible d'ouvrir ", PORT_SERIE, " (moniteur série fermé ? bon port ?)")

func _exit_tree() -> void:
	if serial:
		serial.close()

func _process(_dt: float) -> void:
	if serial == null:
		return
	# On vide tout ce qui est arrivé depuis la dernière frame
	while serial.bytes_available() > 0:
		_traiter(str(serial.readline()).strip_edges())

func _traiter(ligne: String) -> void:
	var v := {}
	for champ in ligne.split("\t"):
		var kv := champ.split(":")
		if kv.size() == 2:
			v[kv[0]] = kv[1].to_float()
	# Ligne incomplète ou message de démarrage : on ignore
	for c in CLES:
		if not v.has(c):
			return

	joy = _joystick(v["JoyX"], v["JoyY"])
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

	var maintenant := Time.get_ticks_msec() / 1000.0
	if v["PiezoA"] > PIEZO_SEUIL and maintenant >= _piezo_pret_a:
		piezo_hit.emit(v["PiezoA"] / 1023.0)
		_piezo_pret_a = maintenant + PIEZO_COOLDOWN


# valeurs 0..1023 de l'Arduino -> -1..1, avec une zone morte au centre
func _joystick(x: float, y: float) -> Vector2:
	var j := Vector2((x - JOY_CENTRE) / JOY_CENTRE, (y - JOY_CENTRE) / JOY_CENTRE)
	for axe in [0, 1]:
		j[axe] = 0.0 if absf(j[axe]) < ZONE_MORTE else clampf(j[axe], -1.0, 1.0)
	return j
