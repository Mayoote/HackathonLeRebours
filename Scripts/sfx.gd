# Autoload "Sfx" : Sfx.play("saut") joue Sons/saut.wav
# Les volumes généraux se règlent dans l'onglet Audio (default_bus_layout.tres) :
# bus "Effets" pour les bruitages, "Cles" pour le bip qui guide vers les clés, "Musique".

extends Node

const BUS := "Effets"
const BUS_CLES := "Cles"
const SONS_CLES := ["cle_bip"]

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
			p.bus = BUS_CLES if nom in SONS_CLES else BUS
			p.play()
			return
