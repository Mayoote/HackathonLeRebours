extends Node

@export var fade_duration: float = 1.0

@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var main_menu: Control = %MainMenu
@onready var commands_panel: Control = %CommandsPanel
@onready var play_button: Button = %PlayButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel
@onready var music: AudioStreamPlayer = %MenuMusic

# menu Options, créé en code pour ne pas toucher à Start.tscn
var options_button: Button
var options_panel: CenterContainer
var music_slider: HSlider
var sfx_slider: HSlider


func _ready() -> void:
	ArduinoManager.arduino_connected.connect(_on_arduino_connected)
	ArduinoManager.arduino_disconnected.connect(_on_arduino_disconnected)
	_on_arduino_disconnected()

	fade_overlay.color.a = 0.0
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_options()
	show_main_menu()


func show_main_menu() -> void:
	if options_panel.visible:
		Sfx.save_volumes()  # une seule écriture en quittant les options
	commands_panel.visible = false
	options_panel.visible = false
	main_menu.visible = true
	play_button.grab_focus()


func _on_play_button_pressed() -> void:
	play_button.disabled = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween().set_parallel()
	tween.tween_property(fade_overlay, "color:a", 1.0, fade_duration)
	tween.tween_property(music, "volume_db", -40.0, fade_duration)
	await tween.finished
	Partie.new_game()


func _on_commands_button_pressed() -> void:
	main_menu.visible = false
	commands_panel.visible = true
	back_button.grab_focus()


func _on_back_button_pressed() -> void:
	show_main_menu()


# même construction que CommandsPanel ; le thème de la racine donne le style des boutons et du panneau
func build_options() -> void:
	options_button = Button.new()
	options_button.text = "Options"
	options_button.pressed.connect(_on_options_button_pressed)
	main_menu.add_child(options_button)

	options_panel = CenterContainer.new()
	options_panel.visible = false
	options_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(options_panel)
	move_child(options_panel, commands_panel.get_index() + 1)  # sous le fondu au noir

	var panel := PanelContainer.new()
	options_panel.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.55, 1))
	title.add_theme_font_size_override("font_size", 80)
	box.add_child(title)

	music_slider = add_slider(box, "Musique")
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider = add_slider(box, "Effets")
	sfx_slider.value_changed.connect(_on_sfx_changed)

	var back := Button.new()
	back.text = "Retour"
	back.pressed.connect(show_main_menu)
	box.add_child(back)


func add_slider(parent: Control, text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(240, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(500, 48)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	return slider


func _on_options_button_pressed() -> void:
	music_slider.set_value_no_signal(Sfx.get_volume("Musique"))
	sfx_slider.set_value_no_signal(Sfx.get_volume("Effets"))
	main_menu.visible = false
	options_panel.visible = true
	music_slider.grab_focus()


func _on_music_changed(value: float) -> void:
	Sfx.apply_volume("Musique", value)


# Effets règle aussi le bip des clés
func _on_sfx_changed(value: float) -> void:
	Sfx.apply_volume("Effets", value)
	Sfx.apply_volume("Cles", value)


func _unhandled_input(event: InputEvent) -> void:
	if (commands_panel.visible or options_panel.visible) and event.is_action_pressed("ui_cancel"):
		show_main_menu()


func _on_arduino_connected() -> void:
	status_label.text = "● Manette connectée"
	status_label.modulate = Color.GREEN


func _on_arduino_disconnected() -> void:
	status_label.text = "● Manette non connectée"
	status_label.modulate = Color(1, 0.4, 0.4)
