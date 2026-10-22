extends Node

signal piezo_hit(force: float)
signal joy_btn_pressed
signal enc_btn_pressed
signal enc_tourne(delta: int)

const PORT_SERIE := "COM4"        # <-- ton port, trouvé à l'étape 2
const BAUDS := 115200
const JOY_CENTRE := 512.0
const ZONE_MORTE := 0.15
const PIEZO_SEUIL := 150
const PIEZO_COOLDOWN := 0.15
const CLES := ["JoyX", "JoyY", "JoyBtn", "EncPos", "EncRPM", "EncBtn", "PiezoA"]

var serial: GdSerial
var joy := Vector2.ZERO
var enc_pos := 0
var enc_rpm := 0.0
var _enc_pos_prec := 0
var _joy_btn_prec := false
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

	joy = Vector2(
		(v["JoyX"] - JOY_CENTRE) / JOY_CENTRE,
		(v["JoyY"] - JOY_CENTRE) / JOY_CENTRE)
	for axe in [0, 1]:
		joy[axe] = 0.0 if absf(joy[axe]) < ZONE_MORTE else clampf(joy[axe], -1.0, 1.0)

	var jb: bool = v["JoyBtn"] == 1.0
	if jb and not _joy_btn_prec: joy_btn_pressed.emit()
	_joy_btn_prec = jb
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
