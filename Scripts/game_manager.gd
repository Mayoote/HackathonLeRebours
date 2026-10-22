# Règles d'un niveau : clés à ramasser, sortie, chrono global (autoload Partie)

extends Node

@export var player: CharacterBody3D
@export var goal: Area3D
@export var trapper: Node

@onready var timer_label: Label = %TimerLabel
@onready var keys_label: Label = %KeysLabel
@onready var message: Label = %Message
@onready var end_screen: Control = %EndScreen
@onready var end_title: Label = %EndTitle

var keys_total := 0
var keys_got := 0
var finished := false
var beep_timer := 0.0
var last_second := -1
var locked_msg_cooldown := 0.0


func _ready() -> void:
	end_screen.visible = false
	message.modulate.a = 0.0
	if not Partie.running and Partie.time_left > 0.0:
		Partie.running = true  # lancé directement depuis l'éditeur (F6)
	var index := Partie.LEVELS.find(owner.scene_file_path if owner else "")
	if index >= 0:
		Partie.level = index  # F6 sur un niveau : la suite est bien le niveau d'après
	Partie.time_up.connect(_on_time_up)
	goal.player_reached.connect(_on_goal_reached)
	for key in get_tree().get_nodes_in_group("keys"):
		key.collected.connect(_on_key_collected)
		keys_total += 1
	if keys_total == 0:
		goal.unlock()
	update_keys()


func _process(delta: float) -> void:
	var t := ceili(Partie.time_left)
	timer_label.text = "%d:%02d" % [t / 60, t % 60]
	timer_label.modulate = Color(1, 0.35, 0.3) if t <= 30 else Color.WHITE
	if t <= 10 and t != last_second and Partie.running:
		Sfx.play("tic", -4.0)
	last_second = t
	locked_msg_cooldown -= delta
	if not finished:
		sonar(delta)


# bip de plus en plus rapide et fort quand on s'approche de la clé la plus proche
func sonar(delta: float) -> void:
	var nearest := INF
	for key in get_tree().get_nodes_in_group("keys"):
		if not key.is_queued_for_deletion():
			nearest = minf(nearest, player.global_position.distance_to(key.global_position))
	if nearest == INF:
		return
	var k := clampf(nearest / 55.0, 0.0, 1.0)
	beep_timer -= delta
	if beep_timer <= 0.0:
		beep_timer = lerpf(0.12, 1.4, k)
		Sfx.play("cle_bip", lerpf(0.0, -26.0, k), lerpf(1.25, 0.9, k))


func _on_key_collected() -> void:
	keys_got += 1
	Sfx.play("cle_ramassee")
	update_keys()
	if keys_got >= keys_total:
		goal.unlock()
		Sfx.play("porte_deverrouillee")
		show_message("La sortie est ouverte !")
	else:
		show_message("Morceau de clé trouvé !")


func update_keys() -> void:
	keys_label.text = "Clés : %d/%d" % [keys_got, keys_total]


func _on_goal_reached() -> void:
	if finished:
		return
	if goal.locked:
		if locked_msg_cooldown <= 0.0:
			Sfx.play("refus")
			show_message("Il manque des morceaux de clé !")
			locked_msg_cooldown = 2.0
		return
	finished = true
	player.set_physics_process(false)
	if trapper:
		trapper.enabled = false
	Sfx.play("niveau_termine")
	await get_tree().create_timer(1.2).timeout
	if not Partie.next_level():
		Sfx.play("victoire")
		end_game("Le joueur s'est échappé !", Color(0.5, 1, 0.55))


func _on_time_up() -> void:
	if finished:
		return
	finished = true
	player.set_physics_process(false)
	if trapper:
		trapper.enabled = false
	Sfx.play("temps_ecoule")
	end_game("Temps écoulé : le piégeur gagne !", Color(1, 0.45, 0.35))


func show_message(text: String) -> void:
	message.text = text
	var tween := create_tween()
	tween.tween_property(message, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.6)
	tween.tween_property(message, "modulate:a", 0.0, 0.4)


func end_game(text: String, color: Color) -> void:
	finished = true
	Partie.running = false
	end_title.text = text
	end_title.add_theme_color_override("font_color", color)
	end_screen.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not end_screen.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("admin_trigger") or event.is_action_pressed("p1_jump"):
		Partie.new_game()
	elif event.is_action_pressed("ui_cancel"):
		Partie.back_to_menu()
