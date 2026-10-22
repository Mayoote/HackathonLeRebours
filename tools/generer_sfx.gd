# Génère tous les SFX du jeu par synthèse -> Sons/*.wav
# godot --headless --path . --script res://tools/generer_sfx.gd

extends SceneTree

const RATE := 22050
const DOSSIER := "res://Sons/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 12
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))

	# communs
	save("ui_click", blip(1800, 0.035, 0.5))
	save("refus", mix([square_sweep(160, 140, 0.18, 0.25)]))
	save("saut", sweep(220, 560, 0.16, 0.5, "sine"))
	save("atterrissage", mix([sweep(110, 45, 0.14, 0.7, "sine"), noise_burst(0.08, 0.4, 900)]))
	save("pas_herbe_1", noise_burst(0.07, 0.35, 2500, 600))
	save("pas_herbe_2", noise_burst(0.06, 0.3, 3200, 800))
	save("respawn", tremolo(sweep(900, 180, 0.55, 0.45, "triangle"), 14))
	save("cle_bip", mix([tone(1320, 0.07, 0.6, "sine"), tone(2640, 0.07, 0.15, "sine")]))
	save("cle_ramassee", arpeggio([1047, 1319, 1568, 2093], 0.065, 0.45, "square"))
	save("porte_deverrouillee", concat([noise_burst(0.03, 0.6, 6000, 1500), silence(0.07), noise_burst(0.03, 0.6, 5000, 1500), silence(0.05), mix([sweep(140, 70, 0.25, 0.7, "sine"), noise_burst(0.12, 0.3, 700)])]))
	save("niveau_termine", arpeggio([523, 659, 784, 1047, 1319], 0.11, 0.4, "triangle"))
	save("victoire", concat([arpeggio([523, 659, 784], 0.12, 0.4, "square"), tone(1047, 0.5, 0.4, "square")]))
	save("temps_ecoule", concat([tone(392, 0.18, 0.4, "square"), tone(330, 0.18, 0.4, "square"), mix([tone(262, 0.6, 0.4, "square"), tone(131, 0.6, 0.3, "triangle")])]))
	save("tic", blip(1000, 0.02, 0.4))

	# plaine
	save("vent", loop_noise(3.0, 0.5, 700, 0.35))
	save("pigeons", flutter(0.6))
	save("fiente_chute", sweep(1900, 650, 0.55, 0.25, "sine"))
	save("fiente_splat", mix([noise_burst(0.2, 0.7, 1800, 200), sweep(320, 70, 0.2, 0.5, "sine")]))
	save("meule_glisse", loop_noise(1.0, 0.45, 300, 0.1, true))
	save("meule_choc", mix([sweep(90, 40, 0.3, 0.9, "sine"), noise_burst(0.2, 0.5, 600)]))

	# grotte
	save("stalactite_craque", concat([noise_burst(0.04, 0.6, 7000, 2000), silence(0.05), noise_burst(0.05, 0.6, 6000, 2000)]))
	save("stalactite_impact", mix([noise_burst(0.35, 0.8, 4000, 300), sweep(200, 60, 0.3, 0.6, "sine")]))
	save("trappe_ouverture", mix([square_sweep(300, 120, 0.3, 0.2), noise_burst(0.3, 0.4, 1200, 200)]))
	save("rocher_roule", loop_noise(1.5, 0.6, 220, 0.25, true))
	save("rocher_chute", mix([sweep(70, 30, 0.6, 1.0, "sine"), noise_burst(0.5, 0.6, 500)]))
	save("goutte", sweep(1400, 2600, 0.05, 0.4, "sine"))

	# temple
	save("lance_flammes", loop_noise(1.0, 0.6, 3500, 0.15, false, 300))
	save("fleche_tir", mix([noise_burst(0.08, 0.5, 8000, 3000), sweep(900, 400, 0.12, 0.3, "triangle")]))
	save("fleche_impact", mix([noise_burst(0.04, 0.6, 5000, 800), tone(180, 0.1, 0.4, "triangle")]))
	save("pics_sortent", concat([noise_burst(0.04, 0.6, 6000, 1000), mix([square_sweep(600, 900, 0.08, 0.25), noise_burst(0.06, 0.4, 4000, 1500)])]))
	save("ascenseur", loop_hum(2.0, 55, 0.4))
	save("ascenseur_arret", mix([sweep(120, 50, 0.3, 0.7, "sine"), noise_burst(0.1, 0.4, 1500, 300)]))

	# run final
	save("manivelle_cran", concat([noise_burst(0.015, 0.7, 7000, 2500), tone(1600, 0.03, 0.3, "square")]))
	save("grille_descend", loop_noise(1.0, 0.5, 900, 0.3, true, 200))
	save("grille_fermee", mix([sweep(160, 50, 0.5, 1.0, "square"), noise_burst(0.3, 0.7, 3000, 200)]))

	# eau
	save("plouf", mix([sweep(500, 140, 0.25, 0.5, "sine"), noise_burst(0.45, 0.6, 2500, 300)]))

	# temple (suite) : ajoutés à la fin pour ne pas changer les sons déjà générés
	save("lianes", froissement(0.7))
	save("flamme_allumage", mix([noise_burst(0.45, 0.8, 1800, 120), sweep(60, 160, 0.4, 0.5, "triangle")]))
	save("mecanisme", concat([noise_burst(0.02, 0.6, 6000, 2000), silence(0.06), noise_burst(0.02, 0.5, 5000, 2000), silence(0.05), tone(900, 0.03, 0.3, "square")]))
	save("pics_rentrent", mix([square_sweep(700, 380, 0.12, 0.15), noise_burst(0.1, 0.3, 3000, 800)]))
	save("tresor", concat([arpeggio([1568, 2093, 2637, 3136], 0.07, 0.25, "sine"), arpeggio([2637, 3136, 4186], 0.09, 0.18, "sine")]))
	quit()


# ── synthèse ─────────────────────────────────────────

func osc(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
		_:
			return sin(phase * TAU)


func env(i: int, n: int, attack := 0.01) -> float:
	var t := float(i) / RATE
	var a := minf(t / attack, 1.0)
	return a * pow(1.0 - float(i) / n, 2.0)


func tone(freq: float, dur: float, vol: float, kind: String) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = osc(kind, freq * i / RATE) * env(i, n) * vol
	return out


func blip(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	return tone(freq, dur, vol, "square")


func sweep(f0: float, f1: float, dur: float, vol: float, kind: String) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		phase += lerpf(f0, f1, float(i) / n) / RATE
		out[i] = osc(kind, phase) * env(i, n) * vol
	return out


func square_sweep(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	return sweep(f0, f1, dur, vol, "square")


# bruit filtré : lowpass (et highpass si hp > 0)
func noise_burst(dur: float, vol: float, lp: float, hp := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * lp / RATE)
	var b := exp(-TAU * hp / RATE) if hp > 0 else 0.0
	var low := 0.0
	var prev := 0.0
	var high := 0.0
	for i in n:
		low += a * (rng.randf_range(-1, 1) - low)
		high = b * (high + low - prev) if hp > 0 else low
		prev = low
		out[i] = high * env(i, n, 0.003) * vol * 2.0
	return out


# boucle de bruit qui ondule (vent, frottements...)
func loop_noise(dur: float, vol: float, lp: float, wobble: float, brown := false, hp := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * lp / RATE)
	var b := exp(-TAU * hp / RATE) if hp > 0 else 0.0
	var low := 0.0
	var prev := 0.0
	var high := 0.0
	var walk := 0.0
	for i in n:
		var w := rng.randf_range(-1, 1)
		if brown:
			walk = clampf(walk + w * 0.08, -1, 1)
			w = walk
		low += a * (w - low)
		high = b * (high + low - prev) if hp > 0 else low
		prev = low
		var t := float(i) / n
		var mod := 1.0 - wobble + wobble * (0.5 + 0.5 * sin(t * TAU * 2.0))
		out[i] = high * mod * vol * (3.0 if not brown else 1.5)
	# fondu croisé pour que la boucle ne claque pas
	var fade := int(0.05 * RATE)
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	out.resize(n - fade)
	return out


func loop_hum(dur: float, freq: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(t * freq * TAU) * 0.6 + sin(t * freq * 2 * TAU) * 0.3 + rng.randf_range(-0.1, 0.1)) * vol
	return out


func flutter(dur: float) -> PackedFloat32Array:
	var parts := []
	var t := 0.0
	while t < dur:
		var d := rng.randf_range(0.03, 0.05)
		parts.append(noise_burst(d, rng.randf_range(0.4, 0.7), 2500, 400))
		var gap := rng.randf_range(0.02, 0.05)
		parts.append(silence(gap))
		t += d + gap
	return concat(parts)


# frottement de feuillage : petits craquements serrés
func froissement(dur: float) -> PackedFloat32Array:
	var parts := []
	var t := 0.0
	while t < dur:
		var d := rng.randf_range(0.02, 0.06)
		parts.append(noise_burst(d, rng.randf_range(0.2, 0.5), 6000, 1500))
		var gap := rng.randf_range(0.0, 0.03)
		parts.append(silence(gap))
		t += d + gap
	return concat(parts)


func arpeggio(notes: Array, step: float, vol: float, kind: String) -> PackedFloat32Array:
	var parts := []
	for f in notes:
		parts.append(tone(f, step * 1.6, vol, kind))
	# les notes se chevauchent un peu
	var n := int(step * RATE)
	var total: int = n * (notes.size() - 1) + parts[-1].size()
	var out := PackedFloat32Array()
	out.resize(total)
	for k in parts.size():
		var p: PackedFloat32Array = parts[k]
		for i in p.size():
			out[k * n + i] += p[i]
	return out


func tremolo(s: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	for i in s.size():
		s[i] *= 0.6 + 0.4 * sin(float(i) / RATE * hz * TAU)
	return s


func silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func save(nom: String, s: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	var loop := nom in ["vent", "meule_glisse", "rocher_roule", "lance_flammes", "ascenseur", "grille_descend"]
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = s.size()
	wav.save_to_wav(ProjectSettings.globalize_path(DOSSIER + nom + ".wav"))
	print("son : ", nom)
