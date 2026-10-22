# Autoload "Sfx" : Sfx.play("saut") joue Sons/saut.wav
# Les volumes généraux se règlent dans l'onglet Audio (default_bus_layout.tres) :
# bus "Effets" pour les bruitages, "Cles" pour le bip qui guide vers les clés, "Musique".

extends Node

const BUS := "Effets"
const BUS_CLES := "Cles"
const SONS_CLES := ["cle_bip"]
const REGLAGES := "user://reglages.cfg"
const BUS_REGLABLES := ["Musique", "Effets", "Cles"]

var players: Array[AudioStreamPlayer] = []
var cache := {}
var volumes := {}  # bus -> volume de 0 à 1 choisi dans les options
var base_db := {}  # bus -> dB du default_bus_layout : 100 % garde le mixage d'origine


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	for bus: String in BUS_REGLABLES:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			base_db[bus] = AudioServer.get_bus_volume_db(idx)
	var cfg := ConfigFile.new()
	if cfg.load(REGLAGES) == OK:
		for bus: String in BUS_REGLABLES:
			apply_volume(bus, cfg.get_value("audio", bus, 1.0))


func get_volume(bus: String) -> float:
	return volumes.get(bus, 1.0)


# 0 coupe le bus, 1 remet le volume d'origine
func apply_volume(bus: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	value = clampf(value, 0.0, 1.0)
	volumes[bus] = value
	AudioServer.set_bus_mute(idx, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(idx, base_db.get(bus, 0.0) + linear_to_db(value))


func save_volumes() -> void:
	var cfg := ConfigFile.new()
	for bus: String in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.save(REGLAGES)


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
