# Autoload "MenuNiveaux" : Tab ouvre un menu pour aller directement à un niveau
# (pratique pour tester ou faire une démo). Le jeu est en pause tant qu'il est ouvert.
# Réservé au mode développeur : TOUCHE_DEV (F2) l'active ou le désactive.

extends CanvasLayer

const NOMS := ["1 · La Plaine", "2 · La Grotte", "3 · Le Temple", "4 · La Sortie"]
const TOUCHE_DEV := KEY_F2

var panel: Control
var buttons: Array[Button] = []
var dev_mode := false
var notice: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.75)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Choisir un niveau"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)

	for i in Partie.LEVELS.size():
		var b := Button.new()
		b.text = NOMS[i] if i < NOMS.size() else "Niveau %d" % (i + 1)
		b.custom_minimum_size = Vector2(0, 90)
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(_on_level_chosen.bind(i))
		box.add_child(b)
		buttons.append(b)

	var hint := Label.new()
	hint.text = "Tab : fermer      Le chrono repart à 5:00"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 32)
	box.add_child(hint)

	# hors du panel : visible même menu fermé
	notice = Label.new()
	notice.set_anchors_preset(Control.PRESET_TOP_WIDE)
	notice.offset_top = 24.0
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 40)
	notice.add_theme_color_override("font_color", Color(0.45, 1, 0.55))
	notice.add_theme_color_override("font_outline_color", Color.BLACK)
	notice.add_theme_constant_override("outline_size", 10)
	notice.modulate.a = 0.0
	add_child(notice)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == TOUCHE_DEV:
		toggle_dev_mode()
		get_viewport().set_input_as_handled()
	elif dev_mode and event.is_action_pressed("menu_niveaux"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle_dev_mode() -> void:
	dev_mode = not dev_mode
	if not dev_mode and panel.visible:
		toggle()
	notice.text = "Mode développeur activé" if dev_mode else "Mode développeur désactivé"
	notice.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notice, "modulate:a", 0.0, 0.5)


func toggle() -> void:
	panel.visible = not panel.visible
	get_tree().paused = panel.visible
	if panel.visible:
		buttons[maxi(Partie.level, 0)].grab_focus()


func _on_level_chosen(index: int) -> void:
	Sfx.play("ui_click")
	panel.visible = false
	get_tree().paused = false
	Partie.start_level(index)
