# Autoload "Sfx" : Sfx.play("saut") joue Sons/saut.wav

extends Node

var players: Array[AudioStreamPlayer] = []
var cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func stream(nom: String) -> AudioStream:
	if not cache.has(nom):
		cache[nom] = load("res://Sons/%s.wav" % nom)
	return cache[nom]


func play(nom: String, volume_db := 0.0, pitch := 1.0) -> void:
	for p in players:
		if not p.playing:
			p.stream = stream(nom)
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
