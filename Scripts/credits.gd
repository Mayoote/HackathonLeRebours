# Générique de fin : après les scores, tout monte et les crédits arrivent par le bas

class_name Credits
extends VBoxContainer

const LOGO := preload("res://Images and ressources/logo_escape_temple.webp")
const TEAM := [
	["Chefs de projet", ["Adrien FALCOZ", "David HUANG"]],
	["Développeurs Godot", ["Anis DJEBAILI", "Alexandre MARESCAUX", "Jalis SOUIBER", "Maïtson PIERRE"]],
	["Sound design", ["Florian KLETHI"]],
	["Modélisation 3D", ["Walid HAMIDOUCHE"]],
]
const GOLD := Color(1, 0.85, 0.6)

@export var scores: Control  # bloc des scores qui sort par le haut
@export var hint: Control  # aide rejouer / menu, replacée sous les crédits à la fin
@export var delay := 10.0  # temps d'affichage des scores avant le défilement
@export var speed := 90.0  # pixels par seconde
@export var end_ratio := 0.7  # hauteur d'écran où s'arrête le bas des crédits


func _ready() -> void:
	visible = false
	build()


func build() -> void:
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 260)
	add_child(logo)
	add_label("Escape the Temple", 90, Color.WHITE)
	for section in TEAM:
		add_gap(40)
		add_label(section[0], 44, GOLD)
		for member in section[1]:
			add_label(member, 56, Color.WHITE)
	add_gap(60)
	add_label("Hackathon Le Rebours, octobre 2026", 40, GOLD)


func add_label(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	add_child(label)


func add_gap(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	add_child(spacer)


func start() -> void:
	await get_tree().create_timer(delay).timeout
	var screen_h := get_viewport_rect().size.y
	hint.visible = false
	position.y = screen_h
	visible = true
	# scores et crédits montent de la même distance : un seul générique continu
	var distance := screen_h - (screen_h * end_ratio - size.y)
	var duration := distance / speed
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", -distance, duration).as_relative()
	tween.tween_property(scores, "position:y", -distance, duration).as_relative()
	await tween.finished
	hint.reparent(self, false)
	hint.visible = true
