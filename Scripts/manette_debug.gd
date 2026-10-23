# Débogueur visuel de la manette (F3) : valeurs brutes et corrigées, pour régler le montage.
# Point gris = valeur brute de l'Arduino (0..1023), point vert = valeur utilisée par le jeu.

extends CanvasLayer

const COTE := 220.0  # côté d'un carré de joystick, en pixels
const MARGE := 24.0
const GRIS := Color(0.7, 0.7, 0.7)
const VERT := Color(0.4, 1, 0.5)
const BOUTONS := ["JoyBtn", "Joy2Btn", "EncBtn"]

var manette: Node
var texte: Label
var dessin: Control
var clics := {"JoyBtn": 0, "Joy2Btn": 0, "EncBtn": 0}


func _ready() -> void:
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	manette = get_parent()
	manette.joy_btn_pressed.connect(func() -> void: clics["JoyBtn"] += 1)
	manette.joy2_btn_pressed.connect(func() -> void: clics["Joy2Btn"] += 1)
	manette.enc_btn_pressed.connect(func() -> void: clics["EncBtn"] += 1)
	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0, 0.75)
	fond.position = Vector2(MARGE, MARGE)
	fond.size = Vector2(COTE * 2 + MARGE * 3, COTE + 420)
	add_child(fond)
	dessin = Control.new()
	dessin.position = fond.position
	dessin.draw.connect(_dessiner)
	add_child(dessin)
	texte = Label.new()
	texte.position = fond.position + Vector2(MARGE, COTE + MARGE * 2 + 30)
	texte.add_theme_font_size_override("font_size", 22)
	add_child(texte)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible


func _process(_dt: float) -> void:
	if not visible:
		return
	var b: Dictionary = manette.brut
	var lignes: PackedStringArray = ["Manette : " + (manette.port if manette.connecte else "non connectée")]
	lignes.append("Joy1  brut X %4d  Y %4d   jeu %+.2f %+.2f" % [b.get("JoyX", 0), b.get("JoyY", 0), manette.joy.x, manette.joy.y])
	lignes.append("Joy2  brut X %4d  Y %4d   jeu %+.2f %+.2f" % [b.get("Joy2X", 0), b.get("Joy2Y", 0), manette.joy2.x, manette.joy2.y])
	for nom in BOUTONS:
		lignes.append("%-8s %s   clics : %d" % [nom, "ENFONCÉ" if b.get(nom, 0.0) == 1.0 else "relâché", clics[nom]])
	lignes.append("Encodeur  pos %d   rpm %.1f" % [manette.enc_pos, manette.enc_rpm])
	lignes.append("Piezo  %d" % b.get("PiezoA", 0))
	texte.text = "\n".join(lignes)
	dessin.queue_redraw()


func _dessiner() -> void:
	var b: Dictionary = manette.brut
	_carre(Vector2(MARGE, MARGE), "Joy1 (joueur)", Vector2(b.get("JoyX", 512), b.get("JoyY", 512)), manette.joy, b.get("JoyBtn", 0.0) == 1.0)
	_carre(Vector2(COTE + MARGE * 2, MARGE), "Joy2 (piégeur)", Vector2(b.get("Joy2X", 512), b.get("Joy2Y", 512)), manette.joy2, b.get("Joy2Btn", 0.0) == 1.0)


# un carré : point gris brut, point vert jeu, cadre jaune quand le bouton est enfoncé
func _carre(origine: Vector2, titre: String, brut: Vector2, jeu: Vector2, bouton: bool) -> void:
	var police := ThemeDB.fallback_font
	dessin.draw_string(police, origine + Vector2(0, -4), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var cadre := Rect2(origine + Vector2(0, 8), Vector2(COTE, COTE))
	dessin.draw_rect(cadre, Color.YELLOW if bouton else Color.WHITE, false, 4.0 if bouton else 2.0)
	var centre := cadre.get_center()
	dessin.draw_line(centre - Vector2(COTE / 2, 0), centre + Vector2(COTE / 2, 0), Color(1, 1, 1, 0.2))
	dessin.draw_line(centre - Vector2(0, COTE / 2), centre + Vector2(0, COTE / 2), Color(1, 1, 1, 0.2))
	dessin.draw_circle(cadre.position + brut / 1023.0 * COTE, 10.0, GRIS)
	dessin.draw_circle(centre + jeu * COTE / 2, 7.0, VERT)
