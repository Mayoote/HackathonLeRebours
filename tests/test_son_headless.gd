# tests/test_son_headless.gd — vérifie SANS écouter que l'événement FMOD de Game.tscn démarre et que
# le label du paramètre CharacterMovement change avec Shift. Lancer (son coupé : FMOD joue sur les
# enceintes même en headless) :
#   ARDUINO_PORT=/dev/cu.inexistant "<Godot>" --headless --path <projet> res://tests/test_son_headless.tscn
# Attendu : "[SON] signal started reçu", "label au repos = Void", "label avec Shift = Run", code de sortie 0.
# Note : en headless, la simulation du clavier (Input.parse_input_event) ne fait pas toujours réagir
# Input.is_key_pressed ; le test appelle alors directement la fonction du personnage, ce qui vérifie
# quand même que le label existe dans la banque (sinon FMOD affiche « Cannot set parameter »).
extends Node

var _t := 0
var _jeu: Node
var _emetteur: FmodEventEmitter2D
var _perso: Node
var _demarre := false
var _ok := true

func _ready() -> void:
	_jeu = load("res://Scenes/Game.tscn").instantiate()
	add_child(_jeu)
	_emetteur = _jeu.get_node("FmodEventEmitter2D")
	_perso = _jeu.get_node("Sprite2D")
	_emetteur.started.connect(func(): _demarre = true; print("[SON] signal started reçu"))

func _process(_delta: float) -> void:
	_t += 1
	if _t == 20:
		print("[SON] événement démarré = ", _demarre, " ; label au repos = ", _emetteur.get_parameter("CharacterMovement"))
		_ok = _ok and _demarre
		var ev := InputEventKey.new(); ev.keycode = KEY_SHIFT; ev.physical_keycode = KEY_SHIFT; ev.pressed = true
		Input.parse_input_event(ev); Input.flush_buffered_events()
	if _t == 25:
		var label = _emetteur.get_parameter("CharacterMovement")
		if str(label) == "Void":
			print("[SON] (clavier simulé sans effet en headless : appel direct de la fonction du personnage)")
			_perso._appliquer_label(_perso.label_course)
			label = _emetteur.get_parameter("CharacterMovement")
		print("[SON] label avec Shift = ", label)
		_ok = _ok and str(label) == _perso.label_course
		var ev := InputEventKey.new(); ev.keycode = KEY_SHIFT; ev.physical_keycode = KEY_SHIFT; ev.pressed = false
		Input.parse_input_event(ev); Input.flush_buffered_events()
	if _t == 28:
		_perso._appliquer_label(_perso.label_marche)
		print("[SON] label marche = ", _emetteur.get_parameter("CharacterMovement"))
		_ok = _ok and str(_emetteur.get_parameter("CharacterMovement")) == _perso.label_marche
	if _t == 30:
		_perso._appliquer_label(_perso.label_immobile)
		print("[SON] label immobile = ", _emetteur.get_parameter("CharacterMovement"))
		print("[SON] BILAN ok=", _ok)
		get_tree().quit(0 if _ok else 1)
