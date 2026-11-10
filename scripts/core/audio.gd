extends Node
## Звук (автозавантаження «Audio»).
## Звукові ефекти, музика й фонові шуми — записані файли з assets/audio (вільні набори, CC0; див. LICENSE.md там само).
## Кожен звук має кілька варіантів, які чергуються, щоб удари не звучали однаково.
## Якщо якогось файлу нема, грає запасний звук, синтезований кодом (так гра звучала раніше).
##
## Три гучності: «Music», «SFX», «Ambient» (шини створюються тут). Музика переходить плавно;
## короткі мотиви перемоги й поразки (jingle) на час звучання притишують музику.

const Sounds := preload("res://scripts/data/sounds.gd")
const SoundIndex := preload("res://scripts/data/sound_index.gd")

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENT_DIR := "res://assets/audio/ambient/"
const BUS_VOLUME := {"Music": -5.0, "SFX": -6.0, "Ambient": -9.0}
const JINGLES := ["victory", "defeat"]
## Старі назви музики, які ще вживає гра.
const MUSIC_ALIAS := {"calm": "map"}
const FADE := 0.9  # секунд на плавний перехід музики й фону
const DUCK_DB := -16.0  # наскільки притишити музику під короткий мотив

var sfx := {}  # назва -> синтезований AudioStreamWAV (запасний)
var samples := {}  # назва -> [AudioStream, ...] записані варіанти
var music := {}  # назва -> AudioStream (файл або синтезований запасний)
var sound_on := true
var music_on := true
var current_music := ""  # що зараз має грати (для тестів і перемикань)
var current_ambient := ""
var _players := []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_live: AudioStreamPlayer  # той із двох, що зараз грає
var _jingle: AudioStreamPlayer
var _ambient_a: AudioStreamPlayer
var _ambient_b: AudioStreamPlayer
var _ambient_live: AudioStreamPlayer
var _ambient := {}  # назва -> AudioStream
var _wanted_music := ""
var _thread: Thread
var _last_play := {}  # щоб один звук не «тріщав» десятки разів за кадр
var _last_variant := {}
var _music_tween: Tween
var _ambient_tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUS_VOLUME:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), BUS_VOLUME[bus])
	# Обмежувач на виході: у гущі бою десяток звуків складається, і без нього вихід хрипів би
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(0, lim)
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_live = _music_a
	_jingle = _make_player("Music")
	_jingle.finished.connect(_on_jingle_finished)
	_ambient_a = _make_player("Ambient")
	_ambient_b = _make_player("Ambient")
	_ambient_live = _ambient_a
	_load_samples()
	_build_sfx()
	# Клацання для всіх кнопок інтерфейсу
	get_tree().node_added.connect(func(n):
		if n is BaseButton:
			n.pressed.connect(func(): play("click", 0.05, 0.0)))
	if not _has_music_files():
		# Файлів музики нема (обрізана збірка) — складаємо мелодії кодом, як раніше
		_thread = Thread.new()
		_thread.start(_build_music_thread)


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _load_samples() -> void:
	for name in SoundIndex.SFX:
		var list := []
		for i in range(1, int(SoundIndex.SFX[name]) + 1):
			var path := "%s%s_%d.ogg" % [SFX_DIR, name, i]
			if ResourceLoader.exists(path):
				list.append(load(path))
		if not list.is_empty():
			samples[name] = list


func _has_music_files() -> bool:
	return ResourceLoader.exists(MUSIC_DIR + "map.ogg")


## Чи є для звуку записані файли (а не лише синтезований запасний).
func has_sample(name: String) -> bool:
	return samples.has(name)


# ================= Звукові ефекти =================

func play(name: String, pitch_var: float = 0.08, volume_db: float = 0.0) -> void:
	if not sound_on:
		return
	var stream: AudioStream = null
	if samples.has(name):
		var list: Array = samples[name]
		var i := randi() % list.size()
		if list.size() > 1 and i == int(_last_variant.get(name, -1)):
			i = (i + 1) % list.size()  # не той самий варіант двічі поспіль
		_last_variant[name] = i
		stream = list[i]
	elif sfx.has(name):
		stream = sfx[name]
	else:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -1000)) < 40:
		return
	_last_play[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db + float(Sounds.VOLUME.get(name, 0.0))
	p.play()


# ================= Музика =================

func _music_stream(name: String) -> AudioStream:
	if music.has(name):
		return music[name]
	var path := MUSIC_DIR + name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = not (name in JINGLES)
	music[name] = st
	return st


## Увімкнути музику за назвою: menu, map, city, inn, camp, battle, boss, festive (стара назва calm = map).
func play_music(name: String) -> void:
	name = MUSIC_ALIAS.get(name, name)
	if _has_music_files() and not ResourceLoader.exists(MUSIC_DIR + name + ".ogg"):
		name = "map"
	_wanted_music = name
	current_music = name
	if not music_on:
		_music_a.stop()
		_music_b.stop()
		return
	var st := _music_stream(name)
	if st == null:
		st = music.get("battle" if name in ["battle", "boss"] else "calm")  # синтезовані запасні
		if st == null:
			return  # ще генерується — увімкнеться, щойно буде готова
	if _music_live.stream == st and _music_live.playing:
		return
	var old := _music_live
	_music_live = _music_b if old == _music_a else _music_a
	_music_live.stream = st
	_music_live.volume_db = -60.0
	_music_live.play()
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	# Перехід за силою звуку, а не за децибелами: посередині обидві мелодії чутно, і тиші між ними нема
	var top := db_to_linear(DUCK_DB) if _jingle.playing else 1.0
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_method(_set_gain.bind(_music_live), 0.0, top, FADE)
	_music_tween.tween_method(_set_gain.bind(old), db_to_linear(old.volume_db) if old.playing else 0.0, 0.0, FADE)
	_music_tween.chain().tween_callback(old.stop)


## Гучність гравця за силою звуку 0..1 (для плавних переходів).
func _set_gain(amp: float, p: AudioStreamPlayer) -> void:
	p.volume_db = linear_to_db(maxf(amp, 0.001))


## Короткий мотив поверх музики (victory / defeat): музика притихає й повертається, коли він догра.
func jingle(name: String) -> void:
	if not music_on:
		return
	var st := _music_stream(name)
	if st == null:
		return
	_jingle.stream = st
	_jingle.volume_db = 2.0
	_jingle.play()
	_duck(true, 0.25)


func _on_jingle_finished() -> void:
	_duck(false, 1.2)


## Притишити музику під мотив або повернути її. Міняємо гучність самого гравця, бо мотив грає на тій самій шині.
func _duck(on: bool, time: float) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_music_live, "volume_db", DUCK_DB if on else 0.0, time)


# ================= Фонові шуми =================

## Фон місцевості: forest, wind, night, cave, river, fire, crowd; "" — тиша.
func play_ambient(name: String) -> void:
	if name != "" and not _ambient.has(name):
		var path := AMBIENT_DIR + name + ".ogg"
		if ResourceLoader.exists(path):
			var st: AudioStream = load(path)
			if st is AudioStreamOggVorbis:
				st.loop = true
			_ambient[name] = st
		else:
			name = ""
	if name == current_ambient and (name == "" or _ambient_live.playing):
		return
	current_ambient = name
	var old := _ambient_live
	_ambient_live = _ambient_b if old == _ambient_a else _ambient_a
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween().set_parallel(true)
	_ambient_tween.tween_method(_set_gain.bind(old), db_to_linear(old.volume_db) if old.playing else 0.0, 0.0, FADE)
	if name != "" and sound_on:
		_ambient_live.stream = _ambient[name]
		_ambient_live.volume_db = -60.0
		_ambient_live.play()
		_ambient_tween.tween_method(_set_gain.bind(_ambient_live), 0.0, db_to_linear(float(Sounds.AMBIENT_VOLUME.get(name, 0.0))), FADE)
	_ambient_tween.chain().tween_callback(old.stop)


# ================= Налаштування =================

func set_sound(on: bool) -> void:
	sound_on = on
	if on:
		var want := current_ambient
		current_ambient = ""
		play_ambient(want)
	else:
		_ambient_a.stop()
		_ambient_b.stop()


func set_music(on: bool) -> void:
	music_on = on
	if on:
		play_music(_wanted_music)
	else:
		_music_a.stop()
		_music_b.stop()
		_jingle.stop()


# ================= Синтез (запасні звуки й мелодії) =================

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
	if not samples.is_empty() and samples.size() >= SoundIndex.SFX.size():
		return  # усі звуки є записані — синтезувати запасні нема потреби (це ще й пришвидшує запуск)
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


# ================= Синтезована музика (коли нема файлів) =================

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
