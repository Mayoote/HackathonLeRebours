# start_screen.gd — menu principal (première scène du jeu)
# Boutons : Jouer (lance la scène du jeu) et Commandes (affiche les touches).
# La musique du menu est jouée par le nœud MenuMusic de Start.tscn.

extends Node

# Scène lancée par le bouton Jouer (modifiable dans l'inspecteur)
@export_file("*.tscn") var game_scene: String = "res://Scenes/GameScene.tscn"
# Durée du fondu au noir quand on clique sur Jouer (en secondes)
@export var fade_duration: float = 1.0

@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var main_menu: Control = %MainMenu
@onready var commands_panel: Control = %CommandsPanel
@onready var play_button: Button = %PlayButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel
@onready var music: AudioStreamPlayer = %MenuMusic


func _ready() -> void:
	ArduinoManager.arduino_connected.connect(_on_arduino_connected)
	ArduinoManager.arduino_disconnected.connect(_on_arduino_disconnected)
	_on_arduino_disconnected()

	fade_overlay.color.a = 0.0
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_main_menu()


func _show_main_menu() -> void:
	commands_panel.visible = false
	main_menu.visible = true
	play_button.grab_focus()  # permet de naviguer au clavier / à la manette


func _on_play_button_pressed() -> void:
	play_button.disabled = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # bloque les clics pendant le fondu
	var tween := create_tween().set_parallel()
	tween.tween_property(fade_overlay, "color:a", 1.0, fade_duration)
	tween.tween_property(music, "volume_db", -40.0, fade_duration)
	await tween.finished
	get_tree().change_scene_to_file(game_scene)


func _on_commands_button_pressed() -> void:
	main_menu.visible = false
	commands_panel.visible = true
	back_button.grab_focus()


func _on_back_button_pressed() -> void:
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	# Échap (ou bouton retour de la manette) ferme le panneau des commandes
	if commands_panel.visible and event.is_action_pressed("ui_cancel"):
		_show_main_menu()


func _on_arduino_connected() -> void:
	status_label.text = "● Manette connectée"
	status_label.modulate = Color.GREEN


func _on_arduino_disconnected() -> void:
	status_label.text = "● Manette non connectée"
	status_label.modulate = Color(1, 0.4, 0.4)
