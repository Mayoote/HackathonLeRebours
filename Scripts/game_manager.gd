extends Node

@export var player: CharacterBody3D
@export var admin: Node
@export var goal: Area3D
@export_file("*.tscn") var menu_scene := "res://Scenes/Start.tscn"

@onready var player_label: Label = %PlayerLabel
@onready var admin_label: Label = %AdminLabel
@onready var end_screen: Control = %EndScreen
@onready var end_title: Label = %EndTitle

var finished := false


func _ready() -> void:
	end_screen.visible = false
	player.lives_changed.connect(_on_lives_changed)
	player.died.connect(end_game.bind("L'admin a gagné !", Color(1, 0.45, 0.35)))
	goal.player_reached.connect(end_game.bind("Le joueur a gagné !", Color(0.5, 1, 0.55)))
	_on_lives_changed(player.lives)


func _process(_delta: float) -> void:
	var trap: Trap = admin.selected_trap()
	if trap == null:
		admin_label.text = "ADMIN — pas de piège"
		return
	var status := "PRÊT"
	if trap.state == Trap.State.WARNING or trap.state == Trap.State.ACTIVE:
		status = "DÉCLENCHÉ !"
	elif trap.state == Trap.State.COOLDOWN:
		status = "recharge %.1f s" % maxf(trap.cooldown_left, 0.0)
	admin_label.text = "ADMIN — %s (%d/%d) : %s" % [trap.trap_name, admin.index + 1, admin.traps.size(), status]


func _on_lives_changed(lives: int) -> void:
	player_label.text = "JOUEUR — Vies : %d" % maxi(lives, 0)


func end_game(message: String, color: Color) -> void:
	if finished:
		return
	finished = true
	admin.enabled = false
	player.set_physics_process(false)
	end_title.text = message
	end_title.add_theme_color_override("font_color", color)
	end_screen.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not finished:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("admin_trigger") or event.is_action_pressed("p1_jump"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(menu_scene)
