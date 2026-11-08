extends Node
## Звук (автозавантаження «Audio»). Жодного файлу: усі ефекти та музика синтезуються кодом під час запуску.
## Музика — «бандура» (синтез щипкової струни Карплуса-Стронга) у гармонічному мінорі.

const RATE := 22050

var sfx := {}  # назва -> AudioStreamWAV
var music := {}  # "calm" / "battle" -> AudioStreamWAV
var sound_on := true
var music_on := true
var _players := []
var _next := 0
var _music_player: AudioStreamPlayer
var _wanted_music := ""
var _thread: Thread
var _last_play := {}  # щоб один звук не «тріщав» десятки разів за кадр


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -9.0
	add_child(_music_player)
	_build_sfx()
	# Клацання для всіх кнопок інтерфейсу
	get_tree().node_added.connect(func(n):
		if n is BaseButton:
			n.pressed.connect(func(): play("click", 0.05, -6.0)))
	_thread = Thread.new()
	_thread.start(_build_music_thread)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ================= Відтворення =================

func play(name: String, pitch_var: float = 0.08, volume_db: float = 0.0) -> void:
	if not sound_on or not sfx.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - _last_play.get(name, -1000) < 40:
		return
	_last_play[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = sfx[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func play_music(name: String) -> void:
	_wanted_music = name
	if not music_on:
		_music_player.stop()
		return
	if not music.has(name):
		return  # ще генерується — увімкнеться, щойно буде готова
	if _music_player.stream == music[name] and _music_player.playing:
		return
	_music_player.stream = music[name]
	_music_player.play()


func set_sound(on: bool) -> void:
	sound_on = on


func set_music(on: bool) -> void:
	music_on = on
	if on:
		play_music(_wanted_music)
	else:
		_music_player.stop()


# ================= Синтез =================

static func _to_wav(s: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


## Тон із ковзанням частоти. wave: sine / square / saw / tri.
static func _tone(f0: float, f1: float, dur: float, vol: float, wave: String = "sine", attack: float = 0.005) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += f / RATE
		var x := fmod(ph, 1.0)
		var v := 0.0
		match wave:
			"square": v = 1.0 if x < 0.5 else -1.0
			"saw": v = x * 2.0 - 1.0
			"tri": v = 1.0 - 4.0 * absf(x - 0.5)
			_: v = sin(ph * TAU)
		var env := minf(1.0, float(i) / (attack * RATE + 1.0)) * pow(1.0 - t, 2.0)
		out[i] = v * env * vol
	return out


## Шум із фільтром нижніх частот (cut: 0..1, менше — глухіше) і власною огинаючою.
static func _noise(dur: float, vol: float, cut: float = 0.5, shape: String = "decay", rng: RandomNumberGenerator = null) -> PackedFloat32Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += (rng.randf_range(-1, 1) - y) * cut
		var env := 1.0
		match shape:
			"decay": env = pow(1.0 - t, 3.0)
			"swell": env = sin(t * PI)
			"crackle": env = (1.0 - t) * (1.0 if rng.randf() < 0.3 else 0.15)
		out[i] = y * env * vol
	return out


## Щипкова струна (Карплус-Стронг).
static func _pluck(freq: float, dur: float, vol: float, damp: float = 0.996, rng: RandomNumberGenerator = null) -> PackedFloat32Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var period := maxi(2, int(RATE / freq))
	var buf := PackedFloat32Array()
	buf.resize(period)
	for i in period:
		buf[i] = rng.randf_range(-1, 1)
	var idx := 0
	for i in n:
		var a := buf[idx]
		var b := buf[(idx + 1) % period]
		buf[idx] = (a + b) * 0.5 * damp
		out[i] = a * vol
		idx = (idx + 1) % period
	return out


static func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at: int) -> void:
	for i in src.size():
		var j := at + i
		if j >= dst.size():
			break
		dst[j] += src[i]


static func _seq(parts: Array) -> PackedFloat32Array:
	# parts: [[семпли, затримка_в_секундах], ...]
	var total := 0
	for p in parts:
		total = maxi(total, int(p[1] * RATE) + p[0].size())
	var out := PackedFloat32Array()
	out.resize(total)
	for p in parts:
		_mix_into(out, p[0], int(p[1] * RATE))
	return out


static func _metal(dur: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in [1180.0, 1870.0, 2730.0, 3520.0]:
		var t := _tone(f, f * 0.995, dur, vol / 4.0)
		if out.is_empty():
			out = t
		else:
			_mix_into(out, t, 0)
	return out


static func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _build_sfx() -> void:
	sfx["swing"] = _to_wav(_noise(0.14, 0.35, 0.35, "swell"))
	sfx["hit"] = _to_wav(_seq([[_tone(150, 55, 0.11, 0.7), 0.0], [_noise(0.06, 0.35, 0.6), 0.0]]))
	sfx["crit"] = _to_wav(_seq([[_tone(170, 50, 0.13, 0.75), 0.0], [_noise(0.07, 0.4, 0.7), 0.0], [_tone(1500, 1100, 0.14, 0.25, "tri"), 0.0]]))
	sfx["enemy_die"] = _to_wav(_seq([[_tone(320, 70, 0.28, 0.25, "square"), 0.0], [_noise(0.2, 0.25, 0.3), 0.02]]))
	sfx["coin"] = _to_wav(_seq([[_tone(1318, 1318, 0.07, 0.22, "tri"), 0.0], [_tone(1760, 1760, 0.1, 0.22, "tri"), 0.05]]))
	sfx["item"] = _to_wav(_seq([[_pluck(523, 0.4, 0.4), 0.0], [_pluck(659, 0.4, 0.4), 0.07], [_pluck(784, 0.4, 0.4), 0.14], [_pluck(1046, 0.6, 0.4), 0.21]]))
	sfx["hurt"] = _to_wav(_seq([[_tone(120, 65, 0.2, 0.45, "saw"), 0.0], [_noise(0.08, 0.3, 0.4), 0.0]]))
	sfx["dodge"] = _to_wav(_noise(0.2, 0.3, 0.2, "swell"))
	sfx["whirl"] = _to_wav(_seq([[_noise(0.45, 0.4, 0.25, "swell"), 0.0], [_tone(300, 700, 0.4, 0.12, "tri"), 0.0]]))
	sfx["lightning"] = _to_wav(_seq([[_noise(0.4, 0.6, 0.9, "crackle"), 0.0], [_tone(90, 40, 0.35, 0.4, "saw"), 0.0]]))
	sfx["musket"] = _to_wav(_seq([[_noise(0.45, 0.8, 0.5), 0.0], [_tone(90, 35, 0.35, 0.6), 0.0]]))
	sfx["boom"] = _to_wav(_seq([[_noise(0.5, 0.7, 0.25), 0.0], [_tone(70, 30, 0.45, 0.7), 0.0]]))
	sfx["levelup"] = _to_wav(_seq([[_pluck(523, 0.6, 0.35), 0.0], [_pluck(659, 0.6, 0.35), 0.08], [_pluck(784, 0.6, 0.35), 0.16], [_pluck(1046, 0.8, 0.35), 0.24], [_pluck(1318, 1.0, 0.35), 0.32]]))
	sfx["quest"] = _to_wav(_seq([[_pluck(392, 0.5, 0.35), 0.0], [_pluck(523, 0.5, 0.35), 0.12], [_pluck(659, 0.5, 0.35), 0.24], [_pluck(784, 1.2, 0.4), 0.36]]))
	sfx["heal"] = _to_wav(_seq([[_pluck(784, 0.5, 0.25), 0.0], [_pluck(988, 0.5, 0.25), 0.06], [_pluck(1175, 0.7, 0.25), 0.12]]))
	sfx["click"] = _to_wav(_tone(900, 700, 0.035, 0.18, "tri"))
	sfx["sharpen_ok"] = _to_wav(_metal(0.8, 0.45))
	sfx["sharpen_fail"] = _to_wav(_seq([[_tone(200, 110, 0.28, 0.35, "square"), 0.0], [_noise(0.15, 0.3, 0.3), 0.0]]))
	sfx["roar"] = _to_wav(_seq([[_tone(85, 50, 1.0, 0.5, "saw", 0.08), 0.0], [_noise(0.9, 0.25, 0.08, "swell"), 0.0]]))
	sfx["shoot"] = _to_wav(_tone(500, 200, 0.12, 0.2, "tri"))
	sfx["portal"] = _to_wav(_seq([[_tone(300, 900, 0.5, 0.2, "tri", 0.05), 0.0], [_tone(450, 1350, 0.5, 0.12), 0.05]]))


# ================= Музика =================

func _build_music_thread() -> void:
	var calm := _compose(76.0, false, 1648)
	var battle := _compose(128.0, true, 2023)
	call_deferred("_music_ready", calm, battle)


func _music_ready(calm: AudioStreamWAV, battle: AudioStreamWAV) -> void:
	music["calm"] = calm
	music["battle"] = battle
	if _wanted_music != "":
		play_music(_wanted_music)


## Мелодія на бандурі: Dm – Gm – A – Dm, 8 тактів, гармонічний мінор ре.
func _compose(bpm: float, battle: bool, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var beat := 60.0 / bpm
	var bars := 8
	var total := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var chords := [[50, 53, 57], [55, 58, 62], [57, 61, 64], [50, 53, 57], [50, 53, 57], [55, 58, 62], [57, 61, 64], [50, 53, 57]]
	var scale := [62, 64, 65, 67, 69, 70, 73, 74, 76, 77, 79, 81]  # ре гармонічний мінор
	var mel_idx := 4
	for bar in bars:
		var ch: Array = chords[bar]
		var t0 := bar * 4 * beat
		# Бас
		for b in [0, 2]:
			_mix_into(out, _pluck(_midi(ch[0] - 12), beat * 2.2, 0.32, 0.997, rng), int((t0 + b * beat) * RATE))
		# Перебір акордом (вісімки)
		for e in 8:
			var note: int = ch[[0, 1, 2, 1][e % 4]] + (12 if e % 4 == 2 else 0)
			_mix_into(out, _pluck(_midi(note), beat * 1.2, 0.13, 0.995, rng), int((t0 + e * beat * 0.5) * RATE))
		# Мелодія: рух сходинками з тяжінням до звуків акорду
		var rhythm: Array = [1.0, 0.5, 0.5, 1.0, 1.0] if bar % 2 == 0 else [1.5, 0.5, 1.0, 1.0]
		if battle:
			rhythm = [0.5, 0.5, 0.5, 0.5, 1.0, 0.5, 0.5]
		var t := t0
		for d in rhythm:
			mel_idx = clampi(mel_idx + [-2, -1, -1, 1, 1, 2, 0][rng.randi() % 7], 0, scale.size() - 1)
			var m: int = scale[mel_idx]
			if d >= 1.0 and not ((m - ch[0]) % 12 in [0, 3, 4, 7]):
				m = ch[2] + 12  # на довгих нотах — звук акорду
			_mix_into(out, _pluck(_midi(m), d * beat * 1.8, 0.3, 0.998, rng), int(t * RATE))
			t += d * beat
		# Ударні для бойової теми
		if battle:
			for q in 4:
				_mix_into(out, _tone(110, 40, 0.16, 0.5), int((t0 + q * beat) * RATE))
				_mix_into(out, _noise(0.04, 0.12, 0.9, "decay", rng), int((t0 + (q + 0.5) * beat) * RATE))
	# Нормалізація
	var peak := 0.001
	for v in out:
		peak = maxf(peak, absf(v))
	var k := 0.8 / peak
	for i in out.size():
		out[i] *= k
	return _to_wav(out, true)
