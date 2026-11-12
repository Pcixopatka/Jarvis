extends "res://scripts/mechanics/parts/rocks.gd"
## Вій: «Підніміть мені повіки!» — два чорти-повікарі піднімають йому повіки, і за три секунди погляд
## скам'янить усіх перед ним; устигнеш здолати обох чортів — повіки впадуть, Вій осліпне й стане
## беззахисним. Тупіт — коло довкола й тріщини променями; кличе упирів із трун. Церква двигтить:
## зі стелі весь бій падає каміння (parts/rocks.gd).

## Попередження погляду, що зараз наростає (null — погляду нема)
var gaze = null
## Чорти, які піднімають Вієві повіки
var lid_bearers: Array = []


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 6.0 if e.phase2 else 7.5
	match e.ability_step % 3:
		1:
			start_gaze(target, to_t)
		2:
			Audio.play("boom", 0.0, -4.0)
			var ring = telegraph("circle", e.global_position, 1.1, e.damage * 1.3)
			ring.radius = 210.0
			ring.color = Color(0.6, 0.5, 0.4)
			var spin := randf() * TAU
			for i in (8 if e.phase2 else 6):
				var t = telegraph("line", e.global_position, 1.9, e.damage * 1.1)
				t.dir = Vector2.from_angle(spin + TAU * i / (8.0 if e.phase2 else 6.0))
				t.length = 720.0
				t.width = 70.0
				t.color = Color(0.55, 0.45, 0.35)
			e.cast_time = 1.9
		0:
			Audio.play("roar", 0.15, -4.0)
			summon(["upyr", "upyr", "mavka"], 4 if e.phase2 else 3)


func tick(delta: float) -> void:
	if gaze != null:
		watch_gaze()
	super(delta)


func phase2() -> void:
	rage("Вій тупоче: церква ходить ходором!", ["upyr", "chort"])


## «Підніміть мені повіки!» Два чорти беруться за повіки; три секунди — і погляд скам'янить усіх перед Вієм.
func start_gaze(target, to_t: Vector2) -> void:
	Audio.play("roar", 0.0, 2.0)
	Events.banner.emit("«Підніміть мені повіки!»\nЗдолай чортів-повікарів або тікай з-перед очей", Color(1.0, 0.5, 0.35))
	Events.hint.emit("vii_gaze", "Погляд Вія скам'янює. Поки чорти піднімають йому повіки, є три секунди: убий обох чортів, і Вій осліпне, або забіжи йому за спину.")
	e.cast_time = 3.0
	var t = telegraph("cone", e.global_position, 3.0, e.damage * 1.6)
	t.dir = to_t
	t.length = 760.0
	t.half_angle = 0.62
	t.color = Color(1.0, 0.3, 0.15)
	t.on_fire = func():
		for a in combat.allies():
			if is_instance_valid(a) and t.contains(a.global_position) and a.has_method("petrify"):
				a.petrify(2.2)
	gaze = t
	lid_bearers = []
	for side_k in [-1.0, 1.0]:
		var pos: Vector2 = combat._clamp_in(e.global_position + to_t.orthogonal() * side_k * (e.radius * e.base_scale + 46.0), 60.0)
		combat.spawn_enemy("chort", e.level, false, pos)
		var b = combat._last_enemy()
		if b != null and b != e:
			b.title = "Повікар"
			b.max_hp *= 1.5
			b.hp = b.max_hp
			b.speed *= 0.35  # тримають повіки, далеко не відходять
			lid_bearers.append(b)


## Устигли здолати обох повікарів — повіки падають, погляду не буде.
func watch_gaze() -> void:
	if not is_instance_valid(gaze) or gaze.is_queued_for_deletion():
		gaze = null  # погляд уже вдарив
		return
	for b in lid_bearers:
		if is_instance_valid(b) and not b.dead:
			return
	# Обидва повікарі впали: повіки падають, погляду не буде
	gaze.queue_free()
	gaze = null
	e.cast_time = 0.0
	e.stun = 3.5
	e.exposed = 3.5
	Events.banner.emit("Повіки впали! Вій осліп — бий!", Color(0.6, 1.0, 0.6))
	Events.vii_blinded.emit()
	Audio.play("sharpen_ok", 0.05)
	combat.fx.ring(e.global_position, Color(0.7, 1.0, 0.7), 26, 320, 6, 0.5)
