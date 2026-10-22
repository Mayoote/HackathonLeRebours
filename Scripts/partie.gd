# Autoload "Partie" : chrono global et enchaînement des niveaux

extends Node

signal time_up

const TOTAL_TIME := 300.0
const LEVELS := [
	"res://Scenes/GameScene.tscn",
	"res://Scenes/Levels/GrotteScene.tscn",
	"res://Scenes/Levels/TempleScene.tscn",
]
const MENU := "res://Scenes/Start.tscn"

var time_left := TOTAL_TIME
var running := false
var level := 0


func new_game() -> void:
	time_left = TOTAL_TIME
	level = 0
	running = true
	get_tree().change_scene_to_file(LEVELS[0])


func next_level() -> bool:
	if level + 1 >= LEVELS.size():
		running = false
		return false
	level += 1
	get_tree().change_scene_to_file(LEVELS[level])
	return true


func back_to_menu() -> void:
	running = false
	get_tree().change_scene_to_file(MENU)


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		running = false
		time_up.emit()
