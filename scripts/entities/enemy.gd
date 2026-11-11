class_name Enemy
extends Node2D
## Нечисть: мавка, упир, болотяник, вовкулака; боси — Змій або велетенські різновиди інших.

const Data := preload("res://scripts/data/data.gd")
const TelegraphScript := preload("res://scripts/world/telegraph.gd")
const Status := preload("res://scripts/game/status.gd")
const Elites := preload("res://scripts/data/elites.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
## Який стан може накласти удар цього ворога (шанс HIT_STATUS_CHANCE)
const HIT_STATUS := {"zarazhenyi": "plague", "pishchalnyk": "plague", "bolotianyk": "plague", "chaklun": "plague", "putinoid": "plague",
	"vovkulaka": "bleed", "upyr": "bleed", "chort": "burn", "zmii": "burn", "mavka": "chill", "koshchii": "chill",
	"potopelnyk": "chill", "pesyholovets": "bleed", "kamiana_baba": "weak", "mara": "weak",
	"morskyi_tsar": "chill", "shubin": "burn", "bila_pani": "chill",
	"vedmid": "bleed", "kikimora": "chill", "mertvyi_strilets": "burn", "kromeshnyk": "weak", "boyaryn": "plague", "lisovyk": "chill",
	"pushkar": "burn", "lisovyi_did": "bleed", "idolyshche": "weak", "karachun": "chill"}
## Нечисть далеких країв зі своїм прийомом (див. _minion_ability)
const MINION_ABILITIES := ["pesyholovets", "kamiana_baba", "mara", "vedmid", "kikimora", "mertvyi_strilets", "kromeshnyk", "boyaryn", "lisovyk"]
const HIT_STATUS_CHANCE := 0.3

var combat: Combat
var kind := "mavka"
var level := 1
var raw_hp := 0.0  # здоров'я й удар одразу після setup, до множників бою (для мірки героя)
var raw_dmg := 0.0
var radius := 16.0
var r_draw := 16.0  # радіус для малювання (без урахування масштабу боса)
var max_hp := 30.0
var hp := 30.0
var speed := 150.0
var damage := 8.0
var xp_value := 3
var color := Color.WHITE
var infected := 0  # рівень зарази місцевості: зелена аура, сильніший
var ranged := false
var is_boss := false
var keep_distance := 0.0
var shoot_cd := 2.0
var shoot_timer := 1.5
var knockback := Vector2.ZERO
var flash := 0.0
var slow_timer := 0.0
var contact_cd := 0.0
var lunge_timer := 0.0
var phase := randf() * TAU
var facing := Vector2.LEFT
var dead := false
var dying := 0.0  # анімація смерті
var windup := 0.0  # замах перед ударом: червоніє — час ухилятися
var windup_max := 0.35
var ability_timer := 4.0
var ability_step := 0
var stun := 0.0  # приголомшений: не рухається й не б'є
var statuses := {}  # стани (див. Status)
var elite := false
var affixes := []  # властивості еліти (див. Elites.AFFIXES)
var title := ""  # ім'я еліти над головою
var dmg_taken_mult := 1.0
var base_scale := 1.0
var rams_gate := false  # в обороні: іде просто на браму, поки козак не стане поперек дороги
var blink_timer := 2.5  # чорт: телепорт до цілі
var phase2 := false  # боси Кощій і Путіноїд лютішають на половині здоров'я
var anim_moving := false  # для спрайтів: чи рухався цього кадру
var treasure_guard := false  # подія «Знахідка»: після смерті лишає скриню
var bounty_id := 0  # ціль із дошки розшуку (див. BountyService)
var style := ""  # суперник у герці: rubaka | spysnyk | strilets | kharakternyk | bulavnyk (див. Activities.RIVALS)
var sprite := ""  # лист спрайтів, якщо він не збігається з kind
var cast_time := 0.0  # стоїть і заносить удар (серія рубаки, удар булави)
var illusion := false  # мара відьми: зникає від першого ж удару й нічого не лишає
var life_left := 0.0  # скільки ще живе мара
var exposed := 0.0  # Вій без повік осліп: стоїть і отримує більше шкоди
var _gaze = null  # Вій: попередження погляду, що зараз наростає
var _lid_bearers: Array = []  # чорти, які піднімають Вієві повіки
var _rock_timer := 2.5  # Вій: церква двигтить, зі стелі падає каміння
var dmg_cap := 0.0  # суперник тримає удар: за секунду втрачає не більше цієї частки здоров'я (0 — без межі)
var loot_gold := 0  # злидень: скільки гривень поцупив у героя (повертаються, коли його здолати)
var _dmg_window := 0.0  # скільки шкоди отримав за останню секунду
var _cannon_shots := 0  # Пушкар: кожен третій постріл Цар-гармати — осічка
var _base_speed := 0.0  # Лісовий Дід: швидкість до зміни зросту
var _small := false
var _feast := 0.0  # Ідолище: скільки ще бенкетує
var _feast_dmg := 0.0
var _spin := 0.0  # Карачун: поворот снігової спіралі
var _wind_t := 0.0  # Карачун: скільки ще дме хуртовина
var _wind_dir := Vector2.ZERO


func setup(k: String, lvl: int, boss: bool = false) -> void:
	kind = k
	level = lvl
	var s := Data.ENEMY_HP_MULT * (1.0 + Data.ENEMY_HP_PER_LEVEL * (lvl - 1))
	match k:
		"mavka":
			radius = 16.0; max_hp = 30.0; speed = 150.0; damage = 8.0; xp_value = 3
			color = Color(0.6, 0.92, 0.65)
		"upyr":
			radius = 22.0; max_hp = 85.0; speed = 92.0; damage = 15.0; xp_value = 6
			color = Color(0.5, 0.1, 0.14)
		"bolotianyk":
			radius = 20.0; max_hp = 45.0; speed = 85.0; damage = 7.0; xp_value = 5
			color = Color(0.33, 0.45, 0.2)
			ranged = true; keep_distance = 320.0; shoot_cd = 2.8
		"vovkulaka":
			radius = 19.0; max_hp = 55.0; speed = 175.0; damage = 12.0; xp_value = 5
			color = Color(0.45, 0.43, 0.42)
		"zarazhenyi":
			radius = 20.0; max_hp = 70.0; speed = 100.0; damage = 13.0; xp_value = 6
			color = Color(0.45, 0.16, 0.13)
		"chaklun":
			radius = 24.0; max_hp = 90.0; speed = 95.0; damage = 22.0; xp_value = 7
			color = Color(0.12, 0.1, 0.14)
			ranged = true; keep_distance = 300.0; shoot_cd = 2.2
		"chort":
			radius = 17.0; max_hp = 50.0; speed = 185.0; damage = 13.0; xp_value = 6
			color = Color(0.42, 0.12, 0.08)
		"pishchalnyk":
			radius = 19.0; max_hp = 55.0; speed = 90.0; damage = 15.0; xp_value = 7
			color = Color(0.4, 0.14, 0.12)
			ranged = true; keep_distance = 340.0; shoot_cd = 2.6
		"koshchii":
			radius = 24.0; max_hp = 170.0; speed = 100.0; damage = 26.0; xp_value = 8
			color = Color(0.1, 0.08, 0.1)
			ranged = true; keep_distance = 220.0; shoot_cd = 2.4
		"putinoid":
			radius = 26.0; max_hp = 260.0; speed = 105.0; damage = 30.0; xp_value = 10
			color = Color(0.45, 0.06, 0.1)
			ranged = true; keep_distance = 260.0; shoot_cd = 2.0
		"zmii":
			radius = 52.0; max_hp = 60.0; speed = 70.0; damage = 17.0; xp_value = 6
			color = Color(0.2, 0.55, 0.25)
			ranged = true; shoot_cd = 2.6
		"rival":
			# Козак-суперник у герці; стиль і сила — у make_rival()
			radius = 20.0; max_hp = 120.0; speed = 160.0; damage = 14.0; xp_value = 0
			color = Color(0.7, 0.2, 0.2)
		# ---- Супербоси Башти ----
		"baba_yaha":
			radius = 22.0; max_hp = 150.0; speed = 125.0; damage = 24.0; xp_value = 9
			color = Color(0.35, 0.28, 0.22)
			ranged = true; keep_distance = 280.0; shoot_cd = 2.3
		"solovei":
			radius = 23.0; max_hp = 170.0; speed = 110.0; damage = 22.0; xp_value = 9
			color = Color(0.3, 0.35, 0.2)
			ranged = true; keep_distance = 240.0; shoot_cd = 3.0
		"lykho":
			radius = 30.0; max_hp = 260.0; speed = 80.0; damage = 32.0; xp_value = 10
			color = Color(0.25, 0.22, 0.28)
		"oprychnyk":
			radius = 24.0; max_hp = 200.0; speed = 120.0; damage = 28.0; xp_value = 10
			color = Color(0.12, 0.1, 0.1)
		# ---- Нечисть далеких країв ----
		"potopelnyk":
			radius = 21.0; max_hp = 95.0; speed = 80.0; damage = 14.0; xp_value = 7
			color = Color(0.35, 0.6, 0.62)
		"pesyholovets":
			radius = 21.0; max_hp = 70.0; speed = 160.0; damage = 15.0; xp_value = 8
			color = Color(0.6, 0.4, 0.22)
		"kamiana_baba":
			radius = 26.0; max_hp = 170.0; speed = 55.0; damage = 20.0; xp_value = 10
			color = Color(0.6, 0.6, 0.57)
		"mara":
			radius = 17.0; max_hp = 38.0; speed = 150.0; damage = 12.0; xp_value = 7
			color = Color(0.85, 0.88, 0.98)
		"zlyden":
			radius = 12.0; max_hp = 22.0; speed = 215.0; damage = 6.0; xp_value = 3
			color = Color(0.55, 0.5, 0.3)
			base_scale = 0.75
			scale = Vector2.ONE * base_scale
		# ---- Боси далеких країв ----
		"morskyi_tsar":
			radius = 25.0; max_hp = 230.0; speed = 90.0; damage = 28.0; xp_value = 11
			color = Color(0.2, 0.55, 0.65)
			ranged = true; keep_distance = 280.0; shoot_cd = 2.3
		"shubin":
			radius = 29.0; max_hp = 300.0; speed = 85.0; damage = 31.0; xp_value = 11
			color = Color(0.25, 0.22, 0.2)
		"bila_pani":
			radius = 21.0; max_hp = 160.0; speed = 140.0; damage = 21.0; xp_value = 10
			color = Color(0.92, 0.94, 1.0)
			ranged = true; keep_distance = 260.0; shoot_cd = 2.0
		# ---- Боси печер поза сюжетом ----
		"vidma":
			radius = 21.0; max_hp = 140.0; speed = 135.0; damage = 21.0; xp_value = 9
			color = Color(0.45, 0.2, 0.6)
			ranged = true; keep_distance = 300.0; shoot_cd = 2.2
		"vii":
			radius = 30.0; max_hp = 380.0; speed = 62.0; damage = 32.0; xp_value = 11
			color = Color(0.4, 0.42, 0.45)
		# ---- Московія ----
		"vedmid":
			radius = 25.0; max_hp = 140.0; speed = 115.0; damage = 19.0; xp_value = 9
			color = Color(0.42, 0.27, 0.16)
		"kikimora":
			radius = 15.0; max_hp = 40.0; speed = 125.0; damage = 9.0; xp_value = 7
			color = Color(0.4, 0.45, 0.33)
			keep_distance = 280.0
			base_scale = 0.85
			scale = Vector2.ONE * base_scale
		"mertvyi_strilets":
			radius = 19.0; max_hp = 60.0; speed = 85.0; damage = 16.0; xp_value = 8
			color = Color(0.69, 0.16, 0.12)
			keep_distance = 360.0
		"kromeshnyk":
			radius = 18.0; max_hp = 65.0; speed = 150.0; damage = 14.0; xp_value = 8
			color = Color(0.12, 0.09, 0.09)
		"boyaryn":
			radius = 24.0; max_hp = 150.0; speed = 60.0; damage = 18.0; xp_value = 10
			color = Color(0.48, 0.12, 0.2)
		"lisovyk":
			radius = 22.0; max_hp = 100.0; speed = 105.0; damage = 14.0; xp_value = 8
			color = Color(0.35, 0.3, 0.2)
		"pushkar":
			radius = 27.0; max_hp = 290.0; speed = 75.0; damage = 30.0; xp_value = 11
			color = Color(0.35, 0.25, 0.19)
			ranged = true; keep_distance = 300.0; shoot_cd = 2.6
		"lisovyi_did":
			radius = 24.0; max_hp = 260.0; speed = 100.0; damage = 27.0; xp_value = 11
			color = Color(0.29, 0.23, 0.14)
		"idolyshche":
			radius = 32.0; max_hp = 330.0; speed = 60.0; damage = 33.0; xp_value = 12
			color = Color(0.48, 0.35, 0.23)
			ranged = true; keep_distance = 0.0; shoot_cd = 3.2
		"karachun":
			radius = 24.0; max_hp = 300.0; speed = 90.0; damage = 30.0; xp_value = 12
			color = Color(0.17, 0.2, 0.28)
			ranged = true; keep_distance = 280.0; shoot_cd = 2.2
	r_draw = radius
	max_hp *= s
	damage *= 1.0 + Data.ENEMY_DMG_PER_LEVEL * (lvl - 1)
	xp_value = int(xp_value * (1.0 + Data.ENEMY_XP_PER_LEVEL * (lvl - 1)))
	speed *= minf(1.3, 1.0 + 0.02 * (lvl - 1))
	if boss or k == "zmii":
		is_boss = true
		max_hp *= Data.BOSS_HP_MULT
		damage *= Data.BOSS_DMG_MULT
		xp_value *= Data.BOSS_XP_MULT
		if k != "zmii":
			base_scale = 2.0
			scale = Vector2.ONE * base_scale
			radius *= 2.0
			speed *= 0.85
	shoot_timer = randf_range(1.0, shoot_cd)
	windup_max = {"mavka": 0.3, "upyr": 0.45, "bolotianyk": 0.4, "vovkulaka": 0.25, "zarazhenyi": 0.5, "chaklun": 0.5, "zmii": 0.5,
		"chort": 0.28, "pishchalnyk": 0.45, "potopelnyk": 0.5, "pesyholovets": 0.3, "kamiana_baba": 0.6, "mara": 0.3, "zlyden": 0.22,
		"vedmid": 0.5, "kikimora": 0.3, "mertvyi_strilets": 0.45, "kromeshnyk": 0.3, "boyaryn": 0.6, "lisovyk": 0.4}.get(k, 0.35)
	if k in MINION_ABILITIES:
		ability_timer = randf_range(2.0, 4.5)
	if is_boss:
		windup_max = 0.55
		ability_timer = 3.0
		if k in ["kikimora", "mertvyi_strilets"]:
			ranged = true
			shoot_cd = 2.4
			shoot_timer = randf_range(1.0, shoot_cd)
	hp = max_hp
	if k == "lisovyi_did":
		_base_speed = speed
	add_to_group("enemies")


## Найближчий союзник (козак або супутник).
func _pick_target():
	var pl = combat.player
	# Козацька стіна: усі довкола б'ють лише запорожця
	if pl.alive and pl.stina_timer > 0.0 and global_position.distance_to(pl.global_position) < 520.0:
		return pl
	if rams_gate and combat.gate != null and is_instance_valid(combat.gate) and combat.gate.alive:
		if not (pl.alive and global_position.distance_to(pl.global_position) < 110.0):
			return combat.gate
	var best = null
	var best_d := INF
	for a in combat.allies():
		if a == pl and pl.tin_timer > 0.0:
			continue  # пластуна в Тіні не видно
		var d: float = global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _process(delta: float) -> void:
	if dead:
		dying -= delta
		var k := clampf(dying / 0.35, 0.0, 1.0)
		modulate = Color(1.6, 1.6, 1.6, k)
		scale = Vector2.ONE * base_scale * (0.6 + 0.4 * k)
		if dying <= 0.0:
			queue_free()
		return
	var p = _pick_target()
	flash = maxf(0.0, flash - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	contact_cd = maxf(0.0, contact_cd - delta)
	lunge_timer = maxf(0.0, lunge_timer - delta)
	phase += delta * 6.0
	var dot := Status.tick(self, delta)
	if dot > 0.0:
		take_damage(dot, Vector2.ZERO)
		if dead:
			return
	if illusion:
		life_left -= delta
		if life_left <= 0.0:
			vanish()
			return
	exposed = maxf(0.0, exposed - delta)
	if _feast > 0.0:
		_feast -= delta
		hp = minf(max_hp, hp + max_hp * (0.05 if phase2 else 0.04) * delta)
		if randf() < delta * 6.0:
			combat.fx.burst(global_position + Vector2(0, -radius), Color(0.9, 0.7, 0.3), 5, 120, 4, 0.4)
		if _feast <= 0.0:
			cast_time = 0.0
			Events.banner.emit("Ідолище наїлося й набралося сил.", Color(1.0, 0.6, 0.3))
	if _wind_t > 0.0:
		_wind_t -= delta
		var pl = combat.player
		if pl != null and pl.alive:
			var wind: float = minf(200.0, pl.speed * Status.speed_mult(pl) * 0.7)
			if pl.push.length() < wind:
				pl.push = _wind_dir * wind
			if randf() < delta * 10.0:
				combat.fx.burst(pl.global_position - _wind_dir * 200.0, Color(0.95, 0.97, 1.0), 6, 220, 4, 0.5)
	if _gaze != null:
		_watch_gaze()
	if (kind == "vii" or (kind == "shubin" and phase2)) and is_boss and stun <= 0.0 and cast_time <= 0.0:
		_rock_timer -= delta
		if _rock_timer <= 0.0:
			_rock_timer = 1.6 if phase2 else 2.3
			_drop_rock()
	if stun > 0.0:
		stun -= delta * (2.5 if style != "" else 1.0)  # суперник у герці оговтується швидше
		windup = 0.0
		position += knockback * delta
		knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
		queue_redraw()
		return

	var desired := Vector2.ZERO
	var dist := INF
	var dir := facing
	if p != null:
		var to: Vector2 = p.global_position - global_position
		dist = to.length()
		dir = to / maxf(dist, 0.001)
		facing = dir
		desired = dir
		if keep_distance > 0.0:
			if dist < keep_distance * 0.8:
				desired = -dir
			elif dist < keep_distance * 1.15:
				desired = dir.orthogonal() * sin(phase * 0.15)
		# Вовкулака робить стрибок, коли близько
		if kind == "vovkulaka" and dist < 220.0 and lunge_timer <= 0.0:
			lunge_timer = 2.5
			knockback += dir * 520.0
		# Чорт зникає в клубі диму й вигулькує просто біля цілі
		if kind == "chort":
			blink_timer -= delta
			if blink_timer <= 0.0 and dist > 160.0 and dist < 900.0:
				blink_timer = randf_range(3.5, 5.0)
				combat.fx.burst(global_position, Color(0.3, 0.1, 0.05), 14, 160, 6, 0.4)
				global_position = p.global_position + Vector2.from_angle(randf() * TAU) * 80.0
				combat.fx.burst(global_position, Color(0.9, 0.35, 0.1), 14, 160, 6, 0.4)
				windup = windup_max * 1.6  # даємо мить, щоб ухилитися

	# Розштовхування, щоб нечисть не злипалась в одну купу
	var sep := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or o.dead:
			continue
		var d: Vector2 = global_position - o.global_position
		var min_d: float = radius + o.radius
		var l := d.length()
		if l < min_d and l > 0.01:
			sep += d / l * (min_d - l) / min_d

	cast_time = maxf(0.0, cast_time - delta)
	if dmg_cap > 0.0:
		_dmg_window = maxf(0.0, _dmg_window - max_hp * dmg_cap * delta)
	var spd := speed * (0.4 if slow_timer > 0.0 else 1.0) * (0.15 if windup > 0.0 else 1.0) * (0.05 if cast_time > 0.0 else 1.0) * Status.speed_mult(self)
	if style in ["rubaka", "kharakternyk", "bulavnyk"] and dist > 280.0:
		spd *= 1.7  # суперник ближнього бою рветься до стрільця
	var vel := desired * spd + sep * speed * 1.5 + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	anim_moving = vel.length() > 25.0
	position += vel * delta
	var pad := Vector2(radius, radius)
	position = position.clamp(combat.arena.position + pad, combat.arena.end - pad)

	# Ближня атака із замахом: ворог червоніє, і за мить б'є, якщо ціль досі поруч
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			contact_cd = 1.0
			if p != null and dist < radius + p.radius + 24.0:
				if p.take_damage(damage * Status.damage_mult(self), self) == true:
					on_hit(p)
	elif p != null and dist < radius + p.radius + 10.0 and contact_cd <= 0.0:
		windup = windup_max

	if is_boss and p != null:
		ability_timer -= delta
		if ability_timer <= 0.0:
			_boss_ability(p)
	elif style != "" and p != null:
		ability_timer -= delta
		if ability_timer <= 0.0:
			_rival_ability(p)
	elif kind in MINION_ABILITIES and p != null and not illusion and cast_time <= 0.0:
		ability_timer -= delta
		if ability_timer <= 0.0:
			_minion_ability(p, dist)

	if ranged and p != null:
		shoot_timer -= delta * (0.5 if slow_timer > 0.0 else 1.0)
		if shoot_timer <= 0.0 and dist < 750.0:
			shoot_timer = shoot_cd
			if kind == "zmii":
				for a in [-0.35, 0.0, 0.35]:
					_shoot(global_position + dir * 40.0, dir.rotated(a), 300.0, damage * 0.6, Color(1.0, 0.5, 0.1), 13.0)
			elif kind == "pishchalnyk":
				_shoot(global_position + dir * 24.0, dir, 420.0, damage, Color(1.0, 0.75, 0.3), 7.0)
			elif kind == "koshchii":
				for a in [-0.2, 0.0, 0.2]:
					_shoot(global_position, dir.rotated(a), 300.0, damage * 0.55, Color(0.9, 0.9, 0.8), 10.0)
			elif kind == "putinoid":
				var n := 7 if phase2 else 5
				for i in n:
					_shoot(global_position, dir.rotated((i - (n - 1) / 2.0) * 0.18), 270.0, damage * 0.5, Color(0.5, 1.0, 0.2), 11.0)
			elif kind == "chaklun":
				for a in [-0.3, -0.1, 0.1, 0.3]:
					_shoot(global_position, dir.rotated(a), 250.0, damage * 0.5, Color(0.45, 0.95, 0.2), 11.0)
			elif kind == "baba_yaha":
				# Жар із печі: дві повільні вогняні кулі, що підпалюють
				for a in [-0.15, 0.15]:
					_shoot(global_position, dir.rotated(a), 240.0, damage * 0.55, Color(1.0, 0.5, 0.1), 12.0)
			elif kind == "solovei":
				# Посвист: кільце звукових хвиль
				var n := 10 if phase2 else 8
				for i in n:
					_shoot(global_position, Vector2.from_angle(TAU * i / n + phase * 0.1), 200.0, damage * 0.4, Color(0.8, 0.9, 1.0), 9.0)
			elif kind == "morskyi_tsar":
				# Бризки з тризуба: віяло водяних куль
				var nw := 7 if phase2 else 5
				for i in nw:
					_shoot(global_position, dir.rotated((i - (nw - 1) / 2.0) * 0.2), 260.0, damage * 0.5, Color(0.35, 0.75, 1.0), 11.0)
			elif kind == "bila_pani":
				# Крижані сльози: три швидкі бурульки
				for a in [-0.16, 0.0, 0.16]:
					_shoot(global_position, dir.rotated(a), 330.0, damage * 0.55, Color(0.85, 0.93, 1.0), 9.0)
			elif kind == "pushkar":
				# Картеч: віяло дрібних куль
				var np := 8 if phase2 else 6
				for i in np:
					_shoot(global_position + dir * 30.0, dir.rotated(lerpf(-0.5, 0.5, i / float(np - 1))), 340.0, damage * 0.35, Color(1.0, 0.7, 0.3), 7.0)
				Audio.play("musket", 0.1, -6.0)
			elif kind == "idolyshche":
				# Обгризені кістки (поки бенкетує — не кидає)
				if _feast <= 0.0:
					for a in [-0.25, 0.0, 0.25]:
						_shoot(global_position, dir.rotated(a), 260.0, damage * 0.5, Color(0.92, 0.88, 0.78), 11.0)
			elif kind == "karachun":
				# Сніжна спіраль: кільце щоразу трохи повертається
				var nk := 8 if phase2 else 6
				_spin += 0.26
				for i in nk:
					_shoot(global_position, Vector2.from_angle(TAU * i / nk + _spin), 190.0, damage * 0.4, Color(0.85, 0.93, 1.0), 10.0)
			elif kind == "rival":
				_shoot(global_position + dir * 26.0, dir, 520.0, damage * 0.8, Color(1.0, 0.8, 0.4), 6.0)  # куля з пищалі
				Audio.play("musket", 0.15, -8.0)
			elif is_boss:
				for a in [-0.25, 0.0, 0.25]:
					_shoot(global_position, dir.rotated(a), 280.0, damage * 0.6, Color(0.55, 0.85, 0.2), 12.0)
			else:
				_shoot(global_position, dir, 220.0, damage, Color(0.55, 0.85, 0.2), 9.0)
	queue_redraw()


func take_damage(amount: float, kb: Vector2, crit: bool = false) -> void:
	if dead:
		return
	if illusion:
		vanish()  # мара розвіюється від першого ж удару
		return
	amount *= dmg_taken_mult
	if is_boss:
		amount *= 1.0 + float(combat.festive.get("boss", 0.0))  # на Юрія змієборцеві легше
	if exposed > 0.0:
		amount *= 1.5  # осліплий Вій беззахисний
	if statuses.has("curse"):
		amount *= 1.35  # прокляття мольфара
	if dmg_cap > 0.0:
		# Досвідчений боєць не дає себе зарубати однією серією: понад межу проходить лише дещиця
		var allowed := maxf(0.0, max_hp * dmg_cap - _dmg_window)
		amount = maxf(minf(amount, allowed), amount * 0.15)
		_dmg_window += amount
	if "iron" in affixes:
		kb *= 0.2
	if _feast > 0.0:
		_feast_dmg += amount
		if _feast_dmg >= max_hp * 0.05:
			_feast = 0.0
			cast_time = 0.0
			stun = 3.5
			exposed = 3.5
			Events.banner.emit("Ідолище вдавилося! Бий!", Color(0.6, 1.0, 0.6))
	hp -= amount
	flash = 0.12
	knockback += kb * (0.15 if is_boss else (0.45 if style != "" else 1.0))
	var col := Color(1.0, 0.85, 0.2) if crit else Color.WHITE
	combat.float_text(global_position + Vector2(0, -radius - 14), str(int(amount)) + ("!" if crit else ""), col)
	var blood: Color = {"mavka": Color(0.75, 1.0, 0.75), "upyr": Color(0.55, 0.05, 0.08), "bolotianyk": Color(0.45, 0.55, 0.2),
		"vovkulaka": Color(0.7, 0.1, 0.1), "zarazhenyi": Color(0.25, 0.4, 0.1), "zmii": Color(0.3, 0.8, 0.3), "rival": Color(0.75, 0.1, 0.1)}.get(kind, Color.WHITE)
	combat.fx.burst(global_position + Vector2(0, -radius * 0.5), blood, 7 if crit else 4, 240, 4.0, 0.35, 300, (-kb).angle() + PI if kb.length() > 1 else 0.0, TAU if kb.length() <= 1 else 1.6)
	if crit:
		combat.fx.burst(global_position + Vector2(0, -radius * 0.5), Color(1, 0.95, 0.6), 6, 320, 3.0, 0.2)
	if is_boss and kind in ["koshchii", "putinoid", "baba_yaha", "solovei", "lykho", "oprychnyk", "vidma", "vii", "morskyi_tsar", "shubin", "bila_pani", "pushkar", "lisovyi_did", "idolyshche", "karachun"] and not phase2 and hp < max_hp * 0.5 and hp > 0.0:
		_enter_phase2()
	if hp <= 0.0 and kind == "koshchii" and combat.boss_revives > 0:
		# Кощієва смерть схована в голці — поки голка ціла, він встає знову
		combat.boss_revives -= 1
		hp = max_hp * 0.5
		Events.banner.emit("Кощій встає знову!\nЙого смерть — не тут...", Color(0.75, 1.0, 0.6))
		combat.fx.burst(global_position, Color(0.6, 1.0, 0.3), 40, 300, 8, 0.8)
		Audio.play("roar", 0.0)
		return
	if hp <= 0.0:
		dead = true
		dying = 0.35
		remove_from_group("enemies")
		if kind == "zarazhenyi" or "plague" in affixes:
			combat.spawn_plague(global_position, damage * 0.6)
		if "explosive" in affixes:
			combat.spawn_blast(global_position, 140.0, 0.9, damage * 1.6, Color(1.0, 0.35, 0.1))
		Events.enemy_killed.emit(self)


## Снаряд цього ворога (через нього удар може накласти стан).
func _shoot(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float) -> void:
	combat.spawn_projectile(pos, dir, spd, dmg * Status.damage_mult(self), col, r, self)


## Удар ворога влучив і поранив ціль: стани, вампіризм еліти.
func on_hit(target) -> void:
	if dead or not is_instance_valid(target) or not target.has_method("add_status"):
		return
	if kind == "zlyden" and "gold" in target and int(target.gold) > 0:
		# Злидні тягнуть гроші: що поцупив, те й носить при собі, доки його не здолати
		var g: int = mini(int(target.gold), 3 * level)
		target.gold -= g
		loot_gold += g
		combat.float_text(target.global_position + Vector2(0, -80), "Злидень поцупив %d грн" % g, Color(1.0, 0.8, 0.3))
	var st: String = HIT_STATUS.get(kind, "")
	# Слабка нечисть перших місць станів не накладає — новачкові й так непросто
	if st != "" and level >= 4 and randf() < (HIT_STATUS_CHANCE * 0.5 if is_boss else HIT_STATUS_CHANCE):
		target.add_status(st, 3.0, damage * 0.1)
	for a in affixes:
		var info: Dictionary = Elites.AFFIXES[a]
		if info.has("status"):
			target.add_status(info["status"], 3.5, damage * 0.15)
		if a == "vampire":
			hp = minf(max_hp, hp + damage * 0.8)
			combat.fx.burst(global_position, Color(0.85, 0.1, 0.2), 6, 90, 4, 0.4)


## Перетворює на еліту з властивостями.
func make_elite(affs: Array) -> void:
	elite = true
	affixes = affs
	max_hp *= Elites.HP_MULT
	hp = max_hp
	damage *= Elites.DMG_MULT
	xp_value *= Elites.XP_MULT
	base_scale = 1.25
	scale = Vector2.ONE * base_scale
	radius *= 1.25
	if "swift" in affs:
		speed *= 1.35
		windup_max *= 0.8
	if "iron" in affs:
		dmg_taken_mult = 0.55
	title = Elites.title(kind, Data.ENEMY_NAMES[kind], affs)


# --- Особливі атаки босів ---

func _telegraph(shape: String, pos: Vector2, dur: float, dmg: float):
	var t = TelegraphScript.new()
	t.combat = combat
	t.source = self
	t.shape = shape
	t.position = pos
	t.duration = dur
	t.damage = dmg
	combat.effects.add_child(t)
	return t


func _summon(kinds: Array, count: int) -> void:
	for i in count:
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(90, 160)
		combat.fx.burst(pos, Color(0.3, 0.25, 0.3), 14, 140, 8, 0.6)
		combat.spawn_enemy(kinds[randi() % kinds.size()], maxi(1, level - 1), false, pos)


func _boss_ability(target) -> void:
	var to_t: Vector2 = (target.global_position - global_position).normalized()
	ability_step += 1
	match kind:
		"zmii":
			# Вогняний подих конусом
			ability_timer = 5.5
			var t = _telegraph("cone", global_position, 1.0, damage * 1.3)
			t.dir = to_t
			t.length = 420.0
			t.half_angle = 0.42
			t.color = Color(1.0, 0.45, 0.1)
			Audio.play("roar", 0.05, -3.0)
		"upyr":
			ability_timer = 6.0
			if ability_step % 2 == 1:
				# Стрибок-удар у місце, де стоїть ціль
				var t = _telegraph("circle", target.global_position, 1.0, damage * 1.4)
				t.radius = 120.0
				t.on_fire = func():
					if not dead:
						global_position = t.global_position
			else:
				Audio.play("roar", 0.05, -4.0)
				_summon(["upyr", "mavka"], 3)
		"vovkulaka":
			ability_timer = 5.0
			if ability_step % 2 == 1:
				# Ривок по прямій
				var t = _telegraph("line", global_position, 0.75, damage * 1.3)
				t.dir = to_t
				t.length = 480.0
				t.width = 90.0
				t.on_fire = func():
					if not dead:
						knockback = to_t * 1900.0
			else:
				Audio.play("roar", 0.05, -2.0)
				_summon(["vovkulaka"], 2)
		"chaklun":
			ability_timer = 4.5
			match ability_step % 3:
				1:
					# Дощ зарази: три зони навколо цілі, після удару лишаються хмари
					Audio.play("lightning", 0.1, -6.0)
					for i in 3:
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 130.0)
						var t = _telegraph("circle", pos, 1.1, damage * 0.9)
						t.radius = 85.0
						t.color = Color(0.45, 0.9, 0.15)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.5)
				2:
					_summon_infected()
				0:
					# Зникає в зеленому димі й з'являється подалі, розкидаючи кільце снарядів
					combat.fx.burst(global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
					var best := global_position
					for i in 8:
						var cand := Vector2(randf_range(combat.arena.position.x + 120, combat.arena.end.x - 120), randf_range(combat.arena.position.y + 120, combat.arena.end.y - 120))
						if cand.distance_to(target.global_position) > best.distance_to(target.global_position):
							best = cand
					global_position = best
					combat.fx.burst(global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
					for i in 10:
						_shoot(global_position, Vector2.from_angle(TAU * i / 10.0), 220.0, damage * 0.45, Color(0.45, 0.95, 0.2), 10.0)
		"koshchii":
			ability_timer = 3.8 if phase2 else 5.0
			match ability_step % 3:
				1:
					# Кістяні списи: три лінії віялом до цілі
					Audio.play("roar", 0.05, -4.0)
					for a in [-0.45, 0.0, 0.45]:
						var t = _telegraph("line", global_position, 1.0, damage * 1.2)
						t.dir = to_t.rotated(a)
						t.length = 540.0
						t.width = 70.0
						t.color = Color(0.9, 0.9, 0.75)
				2:
					Audio.play("roar", 0.15, -4.0)
					_summon(["pishchalnyk", "zarazhenyi"], 3)
				0:
					# Смертний холод довкола себе — тікай подалі
					var t = _telegraph("circle", global_position, 1.3, damage * 1.6)
					t.radius = 230.0
					t.color = Color(0.55, 0.85, 1.0)
		"putinoid":
			ability_timer = 3.2 if phase2 else 4.5
			match ability_step % 4:
				1:
					# Дощ зарази
					Audio.play("lightning", 0.1, -6.0)
					for i in (5 if phase2 else 4):
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 150.0)
						var t = _telegraph("circle", pos, 1.1, damage * 0.9)
						t.radius = 90.0
						t.color = Color(0.45, 0.9, 0.15)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.5)
				2:
					Audio.play("roar", 0.15, -4.0)
					_summon(["zarazhenyi", "pishchalnyk", "chort"], 4 if phase2 else 3)
				3:
					# Ривок трону — по прямій через усю залу
					var t = _telegraph("line", global_position, 0.85, damage * 1.4)
					t.dir = to_t
					t.length = 620.0
					t.width = 110.0
					t.on_fire = func():
						if not dead:
							knockback = to_t * 2000.0
				0:
					# Кільце зарази з-під трону
					combat.fx.burst(global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
					for i in 14:
						_shoot(global_position, Vector2.from_angle(TAU * i / 14.0), 230.0, damage * 0.45, Color(0.45, 0.95, 0.2), 10.0)
		"baba_yaha":
			# Баба Яга: літає в ступі — переліт у місце цілі з ударом; мітла мете конусом; кличе мавок
			ability_timer = 3.6 if phase2 else 4.8
			match ability_step % 3:
				1:
					var t = _telegraph("circle", target.global_position, 1.0, damage * 1.3)
					t.radius = 130.0
					t.color = Color(1.0, 0.6, 0.2)
					t.on_fire = func():
						if not dead:
							combat.fx.burst(global_position, Color(0.5, 0.4, 0.3), 20, 200, 7, 0.5)
							global_position = t.global_position
							combat.fx.burst(global_position, Color(1.0, 0.6, 0.2), 24, 240, 8, 0.5)
					Audio.play("roar", 0.1, -5.0)
				2:
					var t = _telegraph("cone", global_position, 0.9, damage * 1.1)
					t.dir = to_t
					t.length = 380.0
					t.half_angle = 0.6
					t.color = Color(0.8, 0.6, 0.3)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 380.0:
							target.push = to_t * 900.0
				0:
					Audio.play("roar", 0.05, -4.0)
					_summon(["mavka", "upyr"], 3 if phase2 else 2)
		"solovei":
			# Соловей-розбійник: посвист валить хвилею від себе; свистить з дуба — стріли дощем
			ability_timer = 3.4 if phase2 else 5.0
			match ability_step % 2:
				1:
					var t = _telegraph("circle", global_position, 1.2, damage * 1.5)
					t.radius = 260.0
					t.color = Color(0.75, 0.9, 1.0)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 320.0:
							target.push = (target.global_position - global_position).normalized() * 1400.0
					Audio.play("roar", 0.3, -3.0)
				0:
					for i in (6 if phase2 else 4):
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 160.0)
						var t = _telegraph("circle", pos, 1.0, damage * 0.9)
						t.radius = 80.0
						t.color = Color(0.6, 0.75, 0.5)
		"lykho":
			# Лихо Однооке: топче землю — хвиля по всій залі з вузькими безпечними щілинами; хапає й кидає; злий погляд
			ability_timer = 4.0 if phase2 else 5.5
			match ability_step % 3:
				1:
					Audio.play("boom", 0.0, -4.0)
					for a in [-0.9, -0.3, 0.3, 0.9]:
						var t = _telegraph("line", global_position, 1.2, damage * 1.4)
						t.dir = to_t.rotated(a)
						t.length = 700.0
						t.width = 120.0
						t.color = Color(0.55, 0.4, 0.6)
				2:
					var t = _telegraph("circle", target.global_position, 0.8, damage * 1.2)
					t.radius = 110.0
					t.color = Color(0.7, 0.3, 0.6)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(t.global_position) < 110.0:
							target.push = (target.global_position - global_position).normalized() * 1600.0
				0:
					# Злий погляд: накладає слабкість на всіх у смузі
					var t = _telegraph("cone", global_position, 1.0, damage * 0.8)
					t.dir = to_t
					t.length = 520.0
					t.half_angle = 0.35
					t.color = Color(0.9, 0.2, 0.3)
					t.on_fire = func():
						if is_instance_valid(target) and target.global_position.distance_to(global_position) < 520.0 and "statuses" in target:
							Status.apply(target, "weak", 5.0)
		"oprychnyk":
			# Опричник-кат: мітла та собача голова — ривок із сокирою; кидає ланцюг, що тягне до себе; кличе опричників
			ability_timer = 3.2 if phase2 else 4.5
			match ability_step % 3:
				1:
					var t = _telegraph("line", global_position, 0.7, damage * 1.5)
					t.dir = to_t
					t.length = 460.0
					t.width = 100.0
					t.color = Color(0.9, 0.2, 0.15)
					t.on_fire = func():
						if not dead:
							knockback = to_t * 1800.0
				2:
					# Ланцюг: тягне ціль до ката
					var t = _telegraph("line", global_position, 0.9, damage * 0.7)
					t.dir = to_t
					t.length = 560.0
					t.width = 60.0
					t.color = Color(0.7, 0.7, 0.75)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 560.0:
							target.push = (global_position - target.global_position).normalized() * 1500.0
				0:
					Audio.play("roar", 0.15, -4.0)
					_summon(["kromeshnyk", "mertvyi_strilets"], 3 if phase2 else 2)
		"vidma":
			# Відьма з Лисої гори: зілля, що знесилює; мари — дві примари поруч зі справжньою; віяло проклять; у люті кличе шабаш
			ability_timer = 3.4 if phase2 else 4.6
			match ability_step % (4 if phase2 else 3):
				1:
					Audio.play("spell", 0.1, 2.0)
					for i in 3:
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 140.0)
						var t = _telegraph("circle", pos, 1.0, damage * 0.9)
						t.radius = 80.0
						t.color = Color(0.65, 0.3, 0.95)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.35, "weak", Color(0.5, 0.2, 0.75), 4.0)
				2:
					_cast_illusions(target)
				3:
					Audio.play("roar", 0.15, -4.0)
					_summon(["chort", "mavka"], 3)
				0:
					# Віяло проклять: п'ять повільних згустків, між якими треба прослизнути
					Audio.play("spell", 0.1, 2.0)
					for i in 5:
						_shoot(global_position, to_t.rotated((i - 2) * 0.28), 210.0, damage * 0.55, Color(0.75, 0.4, 1.0), 12.0)
		"vii":
			# Вій: «Підніміть мені повіки!» — погляд скам'янює всіх перед ним, якщо не здолати чортів-повікарів;
			# тупіт — коло довкола й тріщини променями; кличе упирів із трун
			ability_timer = 6.0 if phase2 else 7.5
			match ability_step % 3:
				1:
					_start_gaze(target, to_t)
				2:
					Audio.play("boom", 0.0, -4.0)
					var ring = _telegraph("circle", global_position, 1.1, damage * 1.3)
					ring.radius = 210.0
					ring.color = Color(0.6, 0.5, 0.4)
					var spin := randf() * TAU
					for i in (8 if phase2 else 6):
						var t = _telegraph("line", global_position, 1.9, damage * 1.1)
						t.dir = Vector2.from_angle(spin + TAU * i / (8.0 if phase2 else 6.0))
						t.length = 720.0
						t.width = 70.0
						t.color = Color(0.55, 0.45, 0.35)
					cast_time = 1.9
				0:
					Audio.play("roar", 0.15, -4.0)
					_summon(["upyr", "upyr", "mavka"], 4 if phase2 else 3)
		"morskyi_tsar":
			# Морський цар: хвилі, що змивають усе на шляху; вир, який лишає крижану воду; кличе потопельників
			ability_timer = 3.6 if phase2 else 5.0
			match ability_step % 3:
				1:
					Audio.play("boom", 0.2, -5.0)
					for a in ([-0.55, 0.0, 0.55] if phase2 else [-0.3, 0.3]):
						var t = _telegraph("line", global_position, 1.1, damage * 1.3)
						t.dir = to_t.rotated(a)
						t.length = 760.0
						t.width = 130.0
						t.color = Color(0.3, 0.7, 0.9)
						t.on_fire = func():
							if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 760.0 and absf((target.global_position - global_position).angle_to(t.dir)) < 0.22:
								target.push = t.dir * 1300.0
								if "statuses" in target:
									Status.apply(target, "chill", 3.0)
				2:
					var pos: Vector2 = target.global_position
					var t = _telegraph("circle", pos, 1.2, damage * 1.1)
					t.radius = 150.0
					t.color = Color(0.2, 0.55, 0.85)
					t.on_fire = func(): combat.spawn_plague(pos, damage * 0.3, "chill", Color(0.25, 0.6, 0.9), 5.0)
				0:
					Audio.play("roar", 0.15, -4.0)
					_summon(["potopelnyk"], 3 if phase2 else 2)
		"shubin":
			# Шубін: обвал — каміння сиплеться довкола; гримучий газ — великі кола, що вибухають і палять; ривок із кайлом
			ability_timer = 3.4 if phase2 else 4.8
			match ability_step % 3:
				1:
					Audio.play("boom", 0.0, -4.0)
					for i in (8 if phase2 else 6):
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(90.0, 260.0))
						var t = _telegraph("circle", pos, 0.9 + 0.08 * i, damage * 0.9)
						t.radius = 78.0
						t.color = Color(0.6, 0.55, 0.5)
				2:
					var spin := randf() * TAU
					for i in 3:
						var pos: Vector2 = target.global_position + Vector2.from_angle(spin + TAU * i / 3.0) * 150.0
						var t = _telegraph("circle", pos, 1.6, damage * 1.2)
						t.radius = 125.0
						t.color = Color(1.0, 0.6, 0.15)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.3, "burn", Color(1.0, 0.5, 0.1), 3.5)
				0:
					var t = _telegraph("line", global_position, 0.8, damage * 1.5)
					t.dir = to_t
					t.length = 480.0
					t.width = 110.0
					t.color = Color(0.9, 0.5, 0.15)
					t.on_fire = func():
						if not dead:
							knockback = to_t * 1700.0
		"bila_pani":
			# Біла Пані: зникає й постає поруч із криком, що відкидає й знесилює; мари; крижаний хрест через увесь зал
			ability_timer = 3.4 if phase2 else 4.6
			match ability_step % 3:
				1:
					combat.fx.burst(global_position, Color(0.85, 0.9, 1.0), 24, 240, 7, 0.5)
					global_position = combat._clamp_in(target.global_position + Vector2.from_angle(randf() * TAU) * 150.0, 80.0)
					Audio.play("portal", 0.1, -2.0)
					var t = _telegraph("circle", global_position, 1.0, damage * 1.3)
					t.radius = 230.0
					t.color = Color(0.8, 0.88, 1.0)
					t.on_fire = func():
						if is_instance_valid(target) and target.global_position.distance_to(global_position) < 280.0:
							if "push" in target:
								target.push = (target.global_position - global_position).normalized() * 1300.0
							if "statuses" in target:
								Status.apply(target, "weak", 4.0)
					cast_time = 1.0
				2:
					_cast_illusions(target)
				0:
					Audio.play("spell", 0.1, 2.0)
					var spin := randf() * TAU
					var n_lines := 6 if phase2 else 4
					for i in n_lines:
						var d := Vector2.from_angle(spin + PI * i / float(n_lines))
						var t = _telegraph("line", target.global_position - d * 520.0, 1.2, damage * 1.1)
						t.dir = d
						t.length = 1040.0
						t.width = 64.0
						t.color = Color(0.6, 0.85, 1.0)
		"pushkar":
			# Пушкар: Цар-гармата (кожен третій постріл — осічка), ядра, що лишають вогонь, запал довкола себе
			ability_timer = 3.6 if phase2 else 5.0
			match ability_step % 4:
				1, 3:
					_cannon_shots += 1
					if _cannon_shots % 3 == 0:
						var t = _telegraph("circle", global_position, 1.2, damage * 1.0)
						t.radius = 190.0
						t.color = Color(0.5, 0.5, 0.5)
						t.on_fire = func():
							if not dead:
								stun = 3.5
								exposed = 3.5
								combat.fx.burst(global_position, Color(0.45, 0.45, 0.45), 30, 260, 9, 0.8)
								Events.banner.emit("Цар-гармата знову не вистрілила!\nБий пушкаря!", Color(0.6, 1.0, 0.6))
								Events.hint.emit("pushkar_misfire", "Кожен третій постріл Цар-гармати — осічка. Вийди із сірого кола, а тоді бий приголомшеного пушкаря.")
						cast_time = 1.2
					else:
						for a in ([-0.28, 0.28] if phase2 else [0.0]):
							var t = _telegraph("line", global_position, 1.6, damage * 1.8)
							t.dir = to_t.rotated(a)
							t.length = 900.0
							t.width = 170.0
							t.color = Color(1.0, 0.45, 0.1)
							t.on_fire = func(): combat.shake(12.0)
						cast_time = 1.6
				2:
					for i in (6 if phase2 else 4):
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(100, 220))
						var t = _telegraph("circle", pos, 0.9 + 0.25 * i, damage * 1.0)
						t.radius = 100.0
						t.color = Color(1.0, 0.55, 0.15)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.25, "burn", Color(1.0, 0.5, 0.1), 3.0)
				0:
					var t = _telegraph("circle", global_position, 1.0, damage * 1.4)
					t.radius = 210.0
					t.color = Color(1.0, 0.6, 0.2)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 250.0:
							target.push = (target.global_position - global_position).normalized() * 1100.0
					cast_time = 1.0
		"lisovyi_did":
			# Лісовий Дід: вищий за ліс (тупіт, дерева) і нижчий за траву (ривки)
			ability_timer = 3.4 if phase2 else 4.6
			match ability_step % 4:
				1:
					_set_size(false)
					Events.banner.emit("Лісовий Дід став вищий за ліс!", Color(1.0, 0.7, 0.4))
					var t = _telegraph("circle", global_position, 1.2, damage * 1.4)
					t.radius = 280.0
					t.color = Color(0.55, 0.42, 0.25)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 330.0:
							target.push = (target.global_position - global_position).normalized() * 1200.0
					cast_time = 1.2
				2:
					var spin := randf() * TAU
					for i in 4:
						var d := Vector2.from_angle(spin + PI * i / 4.0)
						var t = _telegraph("line", target.global_position - d * 450.0, 1.4 + 0.15 * i, damage * 1.2)
						t.dir = d
						t.length = 900.0
						t.width = 80.0
						t.color = Color(0.45, 0.32, 0.2)
					if phase2:
						for i in 2:
							var pos: Vector2 = target.global_position + Vector2.from_angle(randf() * TAU) * 140.0
							var t = _telegraph("circle", pos, 1.0, damage * 0.9)
							t.radius = 90.0
							t.color = Color(0.4, 0.6, 0.3)
							t.on_fire = func(): combat.spawn_plague(pos, damage * 0.25, "chill", Color(0.4, 0.6, 0.3), 4.0)
					cast_time = 1.0
				3, 0:
					if ability_step % 4 == 3:
						_set_size(true)
						Events.banner.emit("Лісовий Дід став нижчий за траву!", Color(1.0, 0.7, 0.4))
					var t = _telegraph("line", global_position, 0.5, damage * 1.3)
					t.dir = to_t
					t.length = 400.0
					t.width = 64.0
					t.color = Color(0.5, 0.75, 0.35)
					t.on_fire = func():
						if not dead:
							knockback = to_t * 1700.0
					cast_time = 0.5
		"idolyshche":
			# Ідолище: ківш браги, ковтає й гупає черевом, бенкет (перевірка шкодою)
			ability_timer = 4.0 if phase2 else 5.5
			match ability_step % 4:
				1:
					for i in (2 if phase2 else 1):
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 200.0)
						var t = _telegraph("circle", pos, 1.2, damage * 1.2)
						t.radius = 150.0
						t.color = Color(0.75, 0.55, 0.25)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.25, "weak", Color(0.75, 0.55, 0.25), 5.0)
				2:
					var t = _telegraph("cone", global_position, 1.1, damage * 0.6)
					t.dir = to_t
					t.length = 480.0
					t.half_angle = 0.5
					t.color = Color(0.6, 0.45, 0.35)
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
							target.push = (global_position - target.global_position).normalized() * 1500.0
					cast_time = 1.1
					ability_timer = 2.1
				3:
					var t = _telegraph("circle", global_position, 1.0, damage * 1.5)
					t.radius = 220.0
					t.color = Color(0.8, 0.6, 0.4)
					t.on_fire = func():
						combat.shake(10.0)
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 270.0:
							target.push = (target.global_position - global_position).normalized() * 1000.0
					cast_time = 1.0
				0:
					_feast = 4.0
					_feast_dmg = 0.0
					cast_time = 4.0
					ability_timer = 5.0
					Events.banner.emit("Ідолище сіло бенкетувати!\nЗавдай шкоди, поки не вдавиться", Color(1.0, 0.7, 0.4))
					Events.hint.emit("idol_feast", "Ідолище бенкетує й відновлює здоров'я. Завдай йому багато шкоди за ці чотири секунди, і воно вдавиться й стане беззахисним.")
		"karachun":
			# Карачун: хуртовина зносить до крижаних кіл, крижаний острог довкола героя, подих морозу
			match ability_step % 3:
				1:
					_wind_dir = to_t
					_wind_t = 4.0 if phase2 else 3.0
					cast_time = _wind_t
					ability_timer = _wind_t + 1.5
					Events.banner.emit("Хуртовина! Іди проти вітру", Color(0.75, 0.9, 1.0))
					Events.hint.emit("karachun_wind", "Хуртовина зносить тебе до крижаних кіл. Іди проти вітру: Карачун тоді стоїть на місці. Під час перекиду вітер тебе не зносить, а в Блоці не встоїш.")
					for i in (7 if phase2 else 5):
						var pos: Vector2 = combat._clamp_in(target.global_position + _wind_dir * randf_range(120, 420) + Vector2.from_angle(randf() * TAU) * randf_range(0, 80), 60.0)
						var t = _telegraph("circle", pos, 1.0 + 0.3 * i, damage * 0.9)
						t.radius = 85.0
						t.color = Color(0.75, 0.88, 1.0)
				2:
					ability_timer = 3.6 if phase2 else 5.0
					var c: Vector2 = target.global_position
					var spin := randf() * TAU
					for i in 7:
						var pos: Vector2 = c if i == 6 else c + Vector2.from_angle(spin + TAU * i / 6.0) * 190.0
						var t = _telegraph("circle", pos, 1.1 if phase2 else 1.4, damage * 1.1)
						t.radius = 70.0
						t.color = Color(0.7, 0.85, 1.0)
						if i == 6:
							t.on_fire = func(): combat.spawn_plague(c, damage * 0.25, "chill", Color(0.7, 0.85, 1.0), 4.0)
				0:
					ability_timer = 3.6 if phase2 else 5.0
					var t = _telegraph("cone", global_position, 1.0, damage * 1.2)
					t.dir = to_t
					t.length = 460.0
					t.half_angle = 0.5
					t.color = Color(0.6, 0.85, 1.0)
					t.on_fire = func():
						for a in combat.allies():
							if is_instance_valid(a) and t.contains(a.global_position) and "statuses" in a:
								Status.apply(a, "chill", 4.0)
					cast_time = 1.0
		_:
			ability_timer = 6.0
			var t = _telegraph("circle", target.global_position, 1.0, damage * 1.3)
			t.radius = 110.0


# --- Нечисть далеких країв ---

## Прийоми звичайної нечисті нових країв: ривок песиголовця, гуп кам'яної баби, мара за спиною.
func _minion_ability(target, dist: float) -> void:
	var to_t: Vector2 = (target.global_position - global_position).normalized()
	match kind:
		"pesyholovets":
			ability_timer = randf_range(4.5, 6.5)
			if dist < 140.0 or dist > 460.0:
				ability_timer = 1.0
				return
			var t = _telegraph("line", global_position, 0.5, damage * 1.2)
			t.dir = to_t
			t.length = 330.0
			t.width = 56.0
			t.color = Color(0.85, 0.5, 0.2)
			t.on_fire = func():
				if not dead:
					knockback = to_t * 1300.0
			cast_time = 0.5
		"kamiana_baba":
			ability_timer = randf_range(5.0, 7.0)
			if dist > 240.0:
				ability_timer = 1.0
				return
			var t = _telegraph("circle", global_position, 1.0, damage * 1.3)
			t.radius = 135.0
			t.color = Color(0.65, 0.62, 0.55)
			cast_time = 1.0
		"mara":
			ability_timer = randf_range(4.0, 6.0)
			if dist > 520.0 or dist < 90.0:
				ability_timer = 1.5
				return
			combat.fx.burst(global_position, Color(0.8, 0.85, 1.0), 12, 160, 5, 0.4)
			global_position = combat._clamp_in(target.global_position + to_t.rotated(randf_range(-0.8, 0.8)) * 115.0, 50.0)
			combat.fx.burst(global_position, Color(0.8, 0.85, 1.0), 12, 160, 5, 0.4)
			contact_cd = maxf(contact_cd, 0.6)
		"vedmid":
			# Ведмідь-шатун: стрибок просто на героя, після якого мить стоїть
			ability_timer = randf_range(5.5, 7.5)
			if dist < 150.0 or dist > 430.0:
				ability_timer = 1.0
				return
			var t = _telegraph("circle", target.global_position, 0.9, damage * 1.3)
			t.radius = 105.0
			t.color = Color(0.6, 0.4, 0.25)
			t.on_fire = func():
				if not dead:
					global_position = t.global_position
					cast_time = 0.6
					contact_cd = 1.0
			cast_time = 0.9
		"kikimora":
			# Кікімора: пряжа з туману під ногами героя, що студить
			ability_timer = randf_range(6.0, 8.0)
			if dist > 600.0:
				ability_timer = 1.0
				return
			var pos: Vector2 = target.global_position
			var t = _telegraph("circle", pos, 1.1, damage * 0.8)
			t.radius = 80.0
			t.color = Color(0.6, 0.66, 0.72)
			t.on_fire = func(): combat.spawn_plague(pos, damage * 0.25, "chill", Color(0.6, 0.66, 0.72), 3.0)
			cast_time = 0.6
		"mertvyi_strilets":
			# Стрілець-мрець: прицільний постріл уздовж смуги
			ability_timer = randf_range(4.5, 6.0)
			if dist > 720.0:
				ability_timer = 1.0
				return
			var t = _telegraph("line", global_position, 1.0, damage * 1.4)
			t.dir = to_t
			t.length = 700.0
			t.width = 48.0
			t.color = Color(1.0, 0.7, 0.3)
			t.on_fire = func():
				Audio.play("musket", 0.1, -6.0)
				if is_instance_valid(target) and t.contains(target.global_position) and target.has_method("add_status"):
					target.add_status("burn", 3.0, damage * 0.1)
			cast_time = 1.0
		"kromeshnyk":
			# Кромішник: аркан, що тягне до нього
			ability_timer = randf_range(5.0, 7.0)
			if dist < 170.0 or dist > 480.0:
				ability_timer = 1.0
				return
			var t = _telegraph("line", global_position, 0.7, damage * 0.6)
			t.dir = to_t
			t.length = 480.0
			t.width = 48.0
			t.color = Color(0.7, 0.7, 0.75)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
					target.push = (global_position - target.global_position).normalized() * 1200.0
					contact_cd = 0.0
			cast_time = 0.7
		"boyaryn":
			# Боярин-упир: кличе злиднів (не більше трьох поруч); прикликані досвіду не дають
			ability_timer = 2.0
			if dist > 700.0:
				return
			var near := 0
			for o in get_tree().get_nodes_in_group("enemies"):
				if o.kind == "zlyden" and not o.dead and o.global_position.distance_to(global_position) < 700.0:
					near += 1
			if near >= 3:
				return
			ability_timer = randf_range(7.0, 9.0)
			cast_time = 0.8
			combat.fx.burst(global_position, Color(1.0, 0.8, 0.3), 18, 180, 6, 0.5)
			combat.float_text(global_position + Vector2(0, -radius - 30), "Злидні, до роботи!", Color(1.0, 0.8, 0.3))
			for i in 2:
				combat.spawn_enemy("zlyden", maxi(1, level - 1), false, global_position + Vector2.from_angle(randf() * TAU) * randf_range(90, 160))
				var z = combat._last_enemy()
				if z != null and z != self:
					z.xp_value = 0
		"lisovyk":
			# Лісовик: дме з гущавини й відкидає
			ability_timer = randf_range(7.0, 10.0)
			if dist > 300.0:
				ability_timer = 1.0
				return
			var t = _telegraph("cone", global_position, 0.8, damage * 0.9)
			t.dir = to_t
			t.length = 300.0
			t.half_angle = 0.55
			t.color = Color(0.55, 0.75, 0.4)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
					target.push = to_t * 900.0
			cast_time = 0.8


# --- Відьма: мари ---

## Відьма зникає в диму й з'являється деінде, а поруч постають дві мари: з виду такі самі, лише трохи прозоріші.
func _cast_illusions(target) -> void:
	Audio.play("portal", 0.1, -2.0)
	combat.fx.burst(global_position, Color(0.6, 0.3, 0.9), 30, 260, 8, 0.6)
	var spots := []
	for i in 3:
		var best := global_position
		for attempt in 8:
			var cand := Vector2(randf_range(combat.arena.position.x + 140, combat.arena.end.x - 140), randf_range(combat.arena.position.y + 140, combat.arena.end.y - 140))
			var ok: bool = cand.distance_to(target.global_position) > 240.0
			for s in spots:
				ok = ok and cand.distance_to(s) > 200.0
			if ok:
				best = cand
				break
		spots.append(best)
	global_position = spots[0]
	combat.fx.burst(global_position, Color(0.6, 0.3, 0.9), 24, 240, 8, 0.5)
	for i in range(1, 3):
		combat.spawn_enemy("vidma", level, false, spots[i])
		var m = combat._last_enemy()
		if m != null and m != self:
			m.make_illusion(self)
			combat.fx.burst(spots[i], Color(0.6, 0.3, 0.9), 24, 240, 8, 0.5)


## Перетворює ворога на мару: вигляд господині, один удар — і її нема; здобичі й досвіду не дає.
func make_illusion(owner_boss) -> void:
	illusion = true
	life_left = 9.0
	is_boss = false
	elite = false
	title = "Мара"
	max_hp = 1.0
	hp = 1.0
	damage = owner_boss.damage * 0.35
	xp_value = 0
	shoot_cd = 2.6
	base_scale = owner_boss.base_scale
	scale = Vector2.ONE * base_scale
	modulate.a = 0.78


## Зникнути без сліду (мара): ні здобичі, ні зарахованого вбивства.
func vanish() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	combat.fx.burst(global_position, Color(0.6, 0.3, 0.9, 0.8), 18, 200, 7, 0.5)
	Audio.play("die_spirit", 0.2, -4.0)
	queue_free()


# --- Вій: погляд ---

## «Підніміть мені повіки!» Два чорти беруться за повіки; три секунди — і погляд скам'янить усіх перед Вієм.
## Устигнеш здолати обох чортів — повіки впадуть, Вій осліпне й стане беззахисним.
func _start_gaze(target, to_t: Vector2) -> void:
	Audio.play("roar", 0.0, 2.0)
	Events.banner.emit("«Підніміть мені повіки!»\nЗдолай чортів-повікарів або тікай з-перед очей", Color(1.0, 0.5, 0.35))
	Events.hint.emit("vii_gaze", "Погляд Вія скам'янює. Поки чорти піднімають йому повіки, є три секунди: убий обох чортів, і Вій осліпне, або забіжи йому за спину.")
	cast_time = 3.0
	var t = _telegraph("cone", global_position, 3.0, damage * 1.6)
	t.dir = to_t
	t.length = 760.0
	t.half_angle = 0.62
	t.color = Color(1.0, 0.3, 0.15)
	t.on_fire = func():
		for a in combat.allies():
			if is_instance_valid(a) and t.contains(a.global_position) and a.has_method("petrify"):
				a.petrify(2.2)
	_gaze = t
	_lid_bearers = []
	for side_k in [-1.0, 1.0]:
		var pos: Vector2 = combat._clamp_in(global_position + to_t.orthogonal() * side_k * (radius * base_scale + 46.0), 60.0)
		combat.spawn_enemy("chort", level, false, pos)
		var b = combat._last_enemy()
		if b != null and b != self:
			b.title = "Повікар"
			b.max_hp *= 1.5
			b.hp = b.max_hp
			b.speed *= 0.35  # тримають повіки, далеко не відходять
			_lid_bearers.append(b)


## Каміння зі стелі: коло під ногами цілі. Вій повільний, тож стояти на місці не дає сама церква.
func _drop_rock() -> void:
	var target = combat.player
	if target == null or not target.alive:
		return
	var t = _telegraph("circle", target.global_position, 0.9, damage * 0.7)
	t.radius = 85.0
	t.color = Color(0.6, 0.55, 0.5)


func _watch_gaze() -> void:
	if not is_instance_valid(_gaze) or _gaze.is_queued_for_deletion():
		_gaze = null  # погляд уже вдарив
		return
	for b in _lid_bearers:
		if is_instance_valid(b) and not b.dead:
			return
	# Обидва повікарі впали: повіки падають, погляду не буде
	_gaze.queue_free()
	_gaze = null
	cast_time = 0.0
	stun = 3.5
	exposed = 3.5
	Events.banner.emit("Повіки впали! Вій осліп — бий!", Color(0.6, 1.0, 0.6))
	Events.vii_blinded.emit()
	Audio.play("sharpen_ok", 0.05)
	combat.fx.ring(global_position, Color(0.7, 1.0, 0.7), 26, 320, 6, 0.5)


# --- Герць: суперники-козаки ---

## Перетворює ворога на суперника: стиль бою, лист спрайтів, ім'я; здоров'я й удар задає турнір
## (вони міряються від сили героя — див. DuelService.loc_for).
func make_rival(info: Dictionary, hp_abs: float, dmg_abs: float, cap: float = 0.0) -> void:
	dmg_cap = cap
	style = info["style"]
	sprite = info["sprite"]
	title = info["name"]
	max_hp = hp_abs
	damage = dmg_abs
	ability_timer = 2.2
	match style:
		"rubaka":
			speed *= 1.1
			windup_max = 0.3
		"spysnyk":
			keep_distance = 170.0
		"strilets":
			ranged = true
			keep_distance = 330.0
			shoot_cd = 1.7
			shoot_timer = 1.2
			speed *= 0.9
		"kharakternyk":
			windup_max = 0.3
		"bulavnyk":
			speed *= 0.75
			max_hp *= 1.25
			damage *= 1.15
			windup_max = 0.5
	hp = max_hp


func _rival_ability(target) -> void:
	var to_t: Vector2 = (target.global_position - global_position).normalized()
	var dist: float = global_position.distance_to(target.global_position)
	ability_step += 1
	match style:
		"rubaka":
			if ability_step % 3 == 0:
				# Ривок по прямій
				ability_timer = 3.0
				var t = _telegraph("line", global_position, 0.6, damage * 1.4)
				t.dir = to_t
				t.length = 420.0
				t.width = 80.0
				cast_time = 0.6
				t.on_fire = func():
					if not dead:
						knockback = to_t * 1700.0
			else:
				# Серія з трьох рубких ударів віялом: стоїть на місці й рубає
				ability_timer = 2.8
				cast_time = 1.1
				for i in 3:
					var t = _telegraph("cone", global_position, 0.5 + 0.28 * i, damage * 0.9)
					t.dir = to_t.rotated((i - 1) * 0.55)
					t.length = 160.0
					t.half_angle = 0.6
					t.color = Color(1.0, 0.85, 0.5)
		"spysnyk":
			ability_timer = 2.1
			if ability_step % 2 == 1:
				# Укол по прямій із випадом уперед
				var t = _telegraph("line", global_position, 0.55, damage * 1.3)
				t.dir = to_t
				t.length = 310.0
				t.width = 56.0
				cast_time = 0.55
				t.on_fire = func():
					if not dead:
						knockback = to_t * 700.0
			else:
				# Широкий замах древком і відскок назад
				var t = _telegraph("cone", global_position, 0.7, damage * 1.0)
				t.dir = to_t
				t.length = 220.0
				t.half_angle = 1.0
				t.color = Color(0.9, 0.8, 0.6)
				cast_time = 0.7
				t.on_fire = func():
					if not dead:
						knockback = -to_t * 900.0
		"strilets":
			ability_timer = 3.6
			match ability_step % 3:
				1:
					# Картеч: конус перед собою
					var t = _telegraph("cone", global_position, 0.8, damage * 1.2)
					t.dir = to_t
					t.length = 390.0
					t.half_angle = 0.45
					t.color = Color(1.0, 0.75, 0.3)
					cast_time = 0.8
					t.on_fire = func():
						Audio.play("musket", 0.05, 0.0)
				2:
					# Порохова бочка туди, де стоїть ціль
					var t = _telegraph("circle", target.global_position, 1.3, damage * 1.5)
					t.radius = 125.0
					t.color = Color(1.0, 0.5, 0.15)
				0:
					# Відскок від ворога, що підійшов надто близько
					if dist < 230.0:
						knockback = -to_t * 1300.0
					shoot_timer = minf(shoot_timer, 0.4)
		"kharakternyk":
			ability_timer = 3.3
			match ability_step % 3:
				1:
					# Зникає в диму й вигулькує за спиною
					combat.spawn_fx("smoke", global_position - Vector2(0, 10), 1.4)
					var behind: Vector2 = target.global_position + to_t * 80.0
					global_position = behind.clamp(combat.arena.position + Vector2(40, 40), combat.arena.end - Vector2(40, 40))
					combat.spawn_fx("smoke", global_position - Vector2(0, 10), 1.4, 0.0, Color(0.7, 0.6, 1.0))
					windup = windup_max * 1.6  # мить, щоб обернутись і ухилитись
				2:
					# Три блискавки: одна в ціль, дві поруч, одна за одною
					Audio.play("lightning", 0.1, -6.0)
					for i in 3:
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 140.0)
						var t = _telegraph("circle", pos, 0.8 + 0.3 * i, damage * 1.0)
						t.radius = 82.0
						t.color = Color(0.6, 0.8, 1.0)
						t.on_fire = func():
							combat.spawn_bolt(PackedVector2Array([pos + Vector2(12, -420), pos + Vector2(-16, -180), pos]))
				0:
					# Відвід очей: перестрибує вбік і б'є ривком
					combat.spawn_fx("smoke", global_position - Vector2(0, 10), 1.2, 0.0, Color(0.7, 0.6, 1.0))
					var side_pos: Vector2 = target.global_position + to_t.orthogonal() * (220.0 if randf() < 0.5 else -220.0)
					global_position = side_pos.clamp(combat.arena.position + Vector2(40, 40), combat.arena.end - Vector2(40, 40))
					var d2: Vector2 = (target.global_position - global_position).normalized()
					var t = _telegraph("line", global_position, 0.6, damage * 1.3)
					t.dir = d2
					t.length = 380.0
					t.width = 70.0
					t.color = Color(0.7, 0.6, 1.0)
					cast_time = 0.6
					t.on_fire = func():
						if not dead:
							knockback = d2 * 1500.0
		"bulavnyk":
			ability_timer = 3.6
			match ability_step % 3:
				1:
					# Удар булавою об землю довкола себе
					var t = _telegraph("circle", global_position, 1.1, damage * 1.6)
					t.radius = 195.0
					cast_time = 1.1
					t.on_fire = func():
						if is_instance_valid(target) and "push" in target and target.global_position.distance_to(global_position) < 240.0:
							target.push = (target.global_position - global_position).normalized() * 900.0
				2:
					# Стрибок із ударом у місце, де стоїть ціль
					var t = _telegraph("circle", target.global_position, 1.0, damage * 1.5)
					t.radius = 130.0
					cast_time = 1.0
					t.on_fire = func():
						if not dead:
							global_position = t.global_position
				0:
					# Розгін по прямій
					var t = _telegraph("line", global_position, 0.8, damage * 1.4)
					t.dir = to_t
					t.length = 470.0
					t.width = 110.0
					cast_time = 0.8
					t.on_fire = func():
						if not dead:
							knockback = to_t * 1800.0


func _enter_phase2() -> void:
	phase2 = true
	speed *= 1.2
	shoot_cd *= 0.75
	ability_timer = 1.0
	combat.shake(12.0)
	Audio.play("roar", 0.0)
	var text: String = {"putinoid": "Путіноїд скидає личину!", "koshchii": "Кощій лютує!", "baba_yaha": "Яга розпалює піч!",
		"solovei": "Соловей свище на повну!", "lykho": "Лихо шаленіє!", "oprychnyk": "Кат спускає псів!",
		"vidma": "Відьма скликає шабаш!", "vii": "Вій тупоче: церква ходить ходором!",
		"morskyi_tsar": "Морський цар здіймає бурю!", "shubin": "Шубін валить копальню!", "bila_pani": "Біла Пані кричить на весь замок!",
		"pushkar": "Пушкар засипає подвійний заряд!", "lisovyi_did": "Лісовий Дід кличе весь ліс!",
		"idolyshche": "Ідолище реве: «Ще їсти!»", "karachun": "Карачун кличе найдовшу ніч!"}.get(kind, "Бос лютує!")
	Events.banner.emit(text, Color(1.0, 0.4, 0.3))
	var kinds: Array = ["zarazhenyi", "pishchalnyk", "chort"]
	match kind:
		"koshchii": kinds = ["zarazhenyi", "pishchalnyk"]
		"baba_yaha": kinds = ["mavka", "upyr"]
		"solovei": kinds = ["vovkulaka", "chort"]
		"lykho": kinds = ["upyr", "bolotianyk"]
		"oprychnyk": kinds = ["kromeshnyk", "mertvyi_strilets", "vovkulaka"]
		"vidma": kinds = ["chort", "mavka"]
		"vii": kinds = ["upyr", "chort"]
		"morskyi_tsar": kinds = ["potopelnyk", "mara"]
		"shubin": kinds = ["kamiana_baba", "zlyden", "zlyden"]
		"bila_pani": kinds = ["mara", "upyr"]
		"pushkar": kinds = ["mertvyi_strilets", "chort"]
		"lisovyi_did": kinds = ["lisovyk", "vedmid"]
		"idolyshche": kinds = ["boyaryn", "zlyden", "zlyden"]
		"karachun": kinds = ["vedmid", "lisovyk"]
	if _feast > 0.0:
		_feast = 0.0
		cast_time = 0.0
	_summon(kinds, 3)


## Лісовий Дід міняє зріст: малий — швидкий і крихкий, великий — повільний і товстошкірий.
func _set_size(small: bool) -> void:
	_small = small
	base_scale = 1.1 if small else 2.0
	scale = Vector2.ONE * base_scale
	radius = r_draw * base_scale
	speed = _base_speed * (1.9 if small else 0.6) * (1.2 if phase2 else 1.0)
	dmg_taken_mult = 1.4 if small else 0.6
	combat.fx.burst(global_position, Color(0.5, 0.8, 0.35), 30, 260, 8, 0.6)


func _summon_infected() -> void:
	Audio.play("roar", 0.15, -4.0)
	_summon(["zarazhenyi"], 3)


# --- Малювання ---

func _c(c: Color) -> Color:
	if flash > 0.0:
		return Color(1, 1, 1, c.a)
	if not statuses.is_empty():
		c = c.lerp(Color(Status.tint(self), c.a), 0.3)
	if windup > 0.0:
		return c.lerp(Color(1.0, 0.25, 0.2, c.a), 0.55 * (1.0 - windup / windup_max))
	return c


func _draw() -> void:
	draw_set_transform(Vector2(0, r_draw * 0.9), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, r_draw * 1.1, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	if rams_gate:
		draw_line(Vector2(-r_draw, -r_draw * 2.2), Vector2(r_draw, -r_draw * 2.2), Color(1.0, 0.4, 0.2, 0.8), 3.0)  # мітка тараньщика
	if infected > 0:
		var pulse := 0.5 + 0.5 * sin(phase * 1.3)
		draw_circle(Vector2(0, -r_draw * 0.4), r_draw * (1.15 + 0.1 * pulse), Color(0.45, 0.85, 0.15, 0.07 + 0.05 * infected))
	if windup > 0.0:
		var w := 1.0 - windup / windup_max
		draw_circle(Vector2(0, -r_draw * 0.4), r_draw * (1.3 + 0.4 * w), Color(1.0, 0.15, 0.1, 0.18 + 0.3 * w))
	if Gfx.has(sprite_id()):
		_draw_sprite()
	else:
		_draw_vector(side)
	_draw_overlays(side)


func _draw_sprite() -> void:
	var frame := Gfx.IDLE
	if dead:
		frame = Gfx.DEAD
	elif flash > 0.0 or stun > 0.0:
		frame = Gfx.HURT
	elif cast_time > 0.0:
		frame = Gfx.ATK0 + (int(phase * 1.5) % 3)
	elif windup > 0.0:
		frame = Gfx.attack_frame(1.0 - windup / windup_max)
	elif contact_cd > 0.85:
		frame = Gfx.ATK0 + 2
	elif anim_moving:
		frame = Gfx.walk_frame(phase * 0.5)
	var tint := Color.WHITE
	if flash > 0.0:
		tint = Color(1.8, 1.8, 1.8)
	elif not statuses.is_empty():
		tint = Color.WHITE.lerp(Status.tint(self), 0.35)
	if phase2:
		draw_arc(Vector2(0, -10), 30.0, 0.0, TAU, 24, Color(1.0, 0.5, 0.3, 0.35 + 0.15 * sin(phase)), 2.0)
	if is_boss and kind == "putinoid":
		draw_circle(Vector2(0, -12), 34.0 + sin(phase) * 2.0, Color(0.4, 0.9, 0.15, 0.12 if not phase2 else 0.22))
	Gfx.draw(self, sprite_id(), facing, frame, Vector2(-24, -30), tint)


func sprite_id() -> String:
	return sprite if sprite != "" else kind


func _draw_vector(side: float) -> void:
	match kind:
		"mavka":
			_draw_mavka(side)
		"upyr":
			_draw_upyr(side)
		"bolotianyk":
			_draw_bolotianyk(side)
		"vovkulaka":
			_draw_vovkulaka(side)
		"zarazhenyi":
			_draw_zarazhenyi(side)
		"pishchalnyk":
			_draw_zarazhenyi(side, true)
		"chort":
			_draw_chort(side)
		"koshchii":
			_draw_koshchii(side)
		"putinoid":
			_draw_putinoid(side)
		"chaklun":
			_draw_chaklun(side)
		"zmii":
			_draw_zmii()
		"baba_yaha":
			_draw_baba_yaha(side)
		"solovei":
			_draw_solovei(side)
		"lykho":
			_draw_lykho(side)
		"oprychnyk":
			_draw_oprychnyk(side)


func _draw_overlays(side: float) -> void:
	if slow_timer > 0.0:
		draw_arc(Vector2(0, -r_draw * 0.5), r_draw * 1.4, 0.0, TAU, 32, Color(0.55, 0.8, 1.0, 0.7), 3.0)
	if elite:
		var ac: Color = Elites.AFFIXES[affixes[0]]["color"]
		draw_arc(Vector2(0, r_draw * 0.6), r_draw * 1.25, 0.0, TAU, 32, Color(1.0, 0.8, 0.2, 0.8), 2.5)
		draw_arc(Vector2(0, r_draw * 0.6), r_draw * 1.05, 0.0, TAU, 32, Color(ac, 0.6), 2.0)
		var font := ThemeDB.fallback_font
		var ty := -r_draw * 2.0 - 22.0
		draw_string_outline(font, Vector2(-130, ty), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-130, ty), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 11, Color(1.0, 0.85, 0.35))
	if style != "" and title != "":
		# Ім'я суперника над головою
		var rf := ThemeDB.fallback_font
		var ry := -r_draw * 2.0 - 24.0
		draw_string_outline(rf, Vector2(-130, ry), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 12, 3, Color(0, 0, 0, 0.8))
		draw_string(rf, Vector2(-130, ry), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 12, Color(1.0, 0.92, 0.7))
	if not statuses.is_empty():
		Status.draw_icons(self, -r_draw * 2.0 - 4.0)
	if stun > 0.0:
		# Зірочки довкола голови
		for i in 3:
			var a := phase * 0.6 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * r_draw * 0.9, -r_draw * 2.0 + sin(a) * 4.0), 3.0, Color(1.0, 0.9, 0.3))
	if hp < max_hp and kind != "zmii":
		var w := r_draw * 2.2
		var y := -r_draw * 2.0 - 14.0
		draw_rect(Rect2(-w / 2, y, w, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, y, w * hp / max_hp, 5), Color(0.9, 0.2, 0.2))


func _draw_mavka(side: float) -> void:
	var sway := sin(phase) * 3.0
	# Сукня
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(15 + sway, 14), Vector2(-15 + sway, 14)
	]), _c(Color(0.85, 0.95, 0.85, 0.9)))
	# Довге зелене волосся
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -22), Vector2(10, -22), Vector2(9 - side * 4 + sway, 4), Vector2(-9 - side * 4 + sway, 4)
	]), _c(Color(0.2, 0.5, 0.3)))
	draw_circle(Vector2(0, -20), 8.0, _c(color))
	draw_circle(Vector2(side * 3, -21), 1.6, Color(0.1, 0.3, 0.2))
	# Вінок
	for i in 5:
		var a := PI + i * PI / 4.0
		var fc: Color = [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.5, 0.6, 1.0)][i % 3]
		draw_circle(Vector2(0, -22) + Vector2.from_angle(a) * 9.0, 2.6, _c(fc))


func _draw_upyr(side: float) -> void:
	# Темний плащ
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -16), Vector2(14, -16), Vector2(22, 16), Vector2(0, 10), Vector2(-22, 16)
	]), _c(Color(0.15, 0.05, 0.08)))
	draw_circle(Vector2(0, -2), 15.0, _c(color))
	draw_circle(Vector2(side * 4, -24), 11.0, _c(Color(0.75, 0.75, 0.72)))
	draw_circle(Vector2(side * 8, -26), 2.4, Color(1, 0.1, 0.1))
	draw_circle(Vector2(side * 1, -26), 2.4, Color(1, 0.1, 0.1))
	draw_line(Vector2(side * 3, -17), Vector2(side * 3, -13), Color.WHITE, 2.0)
	draw_line(Vector2(side * 7, -17), Vector2(side * 7, -13), Color.WHITE, 2.0)


func _draw_bolotianyk(side: float) -> void:
	var squash := 1.0 + sin(phase * 0.8) * 0.06
	draw_set_transform(Vector2(0, -6), 0.0, Vector2(squash, 2.0 - squash))
	draw_circle(Vector2.ZERO, r_draw, _c(color))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Мох і багнюка
	draw_circle(Vector2(-9, -16), 6.0, _c(Color(0.25, 0.38, 0.12)))
	draw_circle(Vector2(8, -18), 5.0, _c(Color(0.42, 0.55, 0.2)))
	draw_line(Vector2(-12, 6), Vector2(-13, 16 + sin(phase) * 3.0), _c(Color(0.3, 0.4, 0.15)), 3.0)
	draw_line(Vector2(10, 6), Vector2(11, 15 + cos(phase) * 3.0), _c(Color(0.3, 0.4, 0.15)), 3.0)
	draw_circle(Vector2(side * 6 - 4, -8), 4.0, Color(1, 0.95, 0.4))
	draw_circle(Vector2(side * 6 + 5, -8), 4.0, Color(1, 0.95, 0.4))
	draw_circle(Vector2(side * 7 - 4, -8), 1.8, Color.BLACK)
	draw_circle(Vector2(side * 7 + 5, -8), 1.8, Color.BLACK)


func _draw_chaklun(side: float) -> void:
	var hover := sin(phase * 0.6) * 3.0 - 4.0
	draw_set_transform(Vector2(0, hover), 0.0, Vector2.ONE)
	# Чорна ряса з червоною облямівкою
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -18), Vector2(10, -18), Vector2(18, 16), Vector2(-18, 16)]), _c(color))
	draw_polyline(PackedVector2Array([Vector2(-18, 16), Vector2(18, 16)]), _c(Color(0.6, 0.05, 0.08)), 3.0)
	draw_line(Vector2(0, -18), Vector2(0, 16), _c(Color(0.6, 0.05, 0.08)), 2.0)
	# Каптур і обличчя
	draw_circle(Vector2(0, -24), 11.0, _c(color.lightened(0.05)))
	draw_circle(Vector2(side * 2, -22), 7.0, _c(Color(0.75, 0.78, 0.72)))
	var glow := 0.6 + 0.4 * sin(phase * 2.5)
	draw_circle(Vector2(side * 2 - 3, -23), 1.8, Color(0.5, 1.0, 0.2, glow))
	draw_circle(Vector2(side * 2 + 3, -23), 1.8, Color(0.5, 1.0, 0.2, glow))
	# Палиця з зеленою кулею
	var hand := Vector2(side * 14, -6)
	draw_line(hand + Vector2(0, 20), hand + Vector2(0, -26), _c(Color(0.3, 0.2, 0.15)), 3.0)
	draw_circle(hand + Vector2(0, -30), 9.0, Color(0.45, 0.95, 0.2, 0.25 * glow))
	draw_circle(hand + Vector2(0, -30), 5.0, Color(0.6, 1.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-side * 10, -36 + sin(phase) * 4.0), 3.0, Color(0.45, 0.95, 0.2, 0.4))


func _draw_chort(side: float) -> void:
	var hop := absf(sin(phase * 1.4)) * 3.0
	var body := Vector2(0, -6 - hop)
	# Хвіст із китицею
	draw_polyline(PackedVector2Array([body + Vector2(-side * 10, 6), body + Vector2(-side * 22, 2), body + Vector2(-side * 26, -10 + sin(phase) * 3)]), _c(color.darkened(0.2)), 3.0)
	draw_circle(body + Vector2(-side * 26, -12 + sin(phase) * 3), 4.0, _c(Color(0.1, 0.05, 0.05)))
	# Ноги з копитцями
	draw_line(body + Vector2(-5, 8), Vector2(-6, 14), _c(color.darkened(0.3)), 4.0)
	draw_line(body + Vector2(5, 8), Vector2(6, 14), _c(color.darkened(0.3)), 4.0)
	draw_rect(Rect2(Vector2(-9, 13), Vector2(6, 3)), _c(Color.BLACK))
	draw_rect(Rect2(Vector2(3, 13), Vector2(6, 3)), _c(Color.BLACK))
	# Тулуб і голова
	draw_circle(body, 12.0, _c(color))
	var h := body + Vector2(side * 3, -14)
	draw_circle(h, 9.0, _c(color.lightened(0.1)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-7, -5), h + Vector2(-11, -16), h + Vector2(-3, -8)]), _c(Color(0.9, 0.85, 0.7)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(7, -5), h + Vector2(11, -16), h + Vector2(3, -8)]), _c(Color(0.9, 0.85, 0.7)))
	draw_circle(h + Vector2(side * 6, 3), 3.5, _c(Color(0.65, 0.3, 0.3)))  # п'ятачок
	draw_circle(h + Vector2(side * 2 - 3, -3), 1.8, Color(1.0, 0.85, 0.1))
	draw_circle(h + Vector2(side * 2 + 3, -3), 1.8, Color(1.0, 0.85, 0.1))


func _draw_koshchii(side: float) -> void:
	var sway := sin(phase * 0.6) * 2.0
	# Чорна мантія
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -20), Vector2(10, -20), Vector2(18 + sway, 16), Vector2(-18 + sway, 16)]), _c(color))
	draw_line(Vector2(-10, -20), Vector2(-18 + sway, 16), _c(Color(0.35, 0.3, 0.1)), 2.0)
	draw_line(Vector2(10, -20), Vector2(18 + sway, 16), _c(Color(0.35, 0.3, 0.1)), 2.0)
	# Кістлява рука з мечем
	var hand := Vector2(side * 13, -8)
	draw_line(Vector2(side * 6, -16), hand, _c(Color(0.9, 0.88, 0.8)), 2.5)
	draw_line(hand, hand + facing * 30.0, _c(Color(0.7, 0.75, 0.8)), 3.0)
	# Череп із зеленим вогнем в очницях
	var h := Vector2(0, -30)
	draw_circle(h, 10.0, _c(Color(0.92, 0.9, 0.82)))
	draw_rect(Rect2(h + Vector2(-5, 6), Vector2(10, 5)), _c(Color(0.92, 0.9, 0.82)))
	var glow := 0.6 + 0.4 * sin(phase * 2.0)
	draw_circle(h + Vector2(-4, -1), 2.8, Color(0.05, 0.05, 0.05))
	draw_circle(h + Vector2(4, -1), 2.8, Color(0.05, 0.05, 0.05))
	draw_circle(h + Vector2(-4, -1), 1.6, Color(0.5, 1.0, 0.3, glow))
	draw_circle(h + Vector2(4, -1), 1.6, Color(0.5, 1.0, 0.3, glow))
	# Зубчаста корона
	for i in 5:
		var x := -8.0 + i * 4.0
		draw_colored_polygon(PackedVector2Array([h + Vector2(x - 2, -8), h + Vector2(x + 2, -8), h + Vector2(x, -15)]), _c(Color(0.85, 0.7, 0.2)))
	if phase2:
		draw_arc(Vector2(0, -10), 30.0, 0.0, TAU, 24, Color(0.6, 1.0, 0.3, 0.5), 2.0)


func _draw_putinoid(side: float) -> void:
	var sway := sin(phase * 0.5) * 1.5
	# Зелена аура зарази
	draw_circle(Vector2(0, -12), 34.0 + sin(phase) * 2.0, Color(0.4, 0.9, 0.15, 0.12 if not phase2 else 0.22))
	# Царська мантія з хутряною облямівкою
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -18), Vector2(12, -18), Vector2(20 + sway, 16), Vector2(-20 + sway, 16)]), _c(color))
	draw_rect(Rect2(Vector2(-21 + sway, 12), Vector2(42, 5)), _c(Color(0.92, 0.9, 0.85)))
	draw_line(Vector2(0, -18), Vector2(0, 12), _c(Color(0.85, 0.65, 0.2)), 2.0)
	# Скіпетр
	var hand := Vector2(side * 15, -6)
	draw_line(hand + Vector2(0, 12), hand + Vector2(0, -22), _c(Color(0.85, 0.65, 0.2)), 3.0)
	draw_circle(hand + Vector2(0, -24), 4.5, Color(0.5, 1.0, 0.2, 0.9))
	# Мертвотно-бліде обличчя, червоні очі
	var h := Vector2(0, -28)
	draw_circle(h, 10.0, _c(Color(0.78, 0.8, 0.76)))
	draw_circle(h + Vector2(-4, -1), 1.8, Color(0.95, 0.05, 0.05))
	draw_circle(h + Vector2(4, -1), 1.8, Color(0.95, 0.05, 0.05))
	draw_line(h + Vector2(-3, 5), h + Vector2(3, 5), Color(0.4, 0.3, 0.3), 1.5)
	# Шапка Мономаха
	draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -6), h + Vector2(10, -6), h + Vector2(7, -16), h + Vector2(0, -20), h + Vector2(-7, -16)]), _c(Color(0.85, 0.65, 0.2)))
	draw_rect(Rect2(h + Vector2(-11, -8), Vector2(22, 4)), _c(Color(0.35, 0.25, 0.2)))
	draw_line(h + Vector2(0, -20), h + Vector2(0, -27), _c(Color(0.85, 0.65, 0.2)), 2.0)
	draw_line(h + Vector2(-3, -24), h + Vector2(3, -24), _c(Color(0.85, 0.65, 0.2)), 2.0)


func _draw_zarazhenyi(side: float, musket: bool = false) -> void:
	var step := sin(phase) * 2.0
	var skin := Color(0.55, 0.62, 0.5)
	# Ноги в чоботях
	draw_rect(Rect2(Vector2(-8, 8 + step), Vector2(6, 10)), _c(Color(0.15, 0.12, 0.1)))
	draw_rect(Rect2(Vector2(2, 8 - step), Vector2(6, 10)), _c(Color(0.15, 0.12, 0.1)))
	# Довгий каптан стрільця
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -16), Vector2(11, -16), Vector2(15, 12), Vector2(-15, 12)]), _c(color))
	draw_line(Vector2(0, -16), Vector2(0, 12), _c(color.darkened(0.4)), 2.0)
	draw_line(Vector2(-13, 2), Vector2(13, 2), _c(Color(0.3, 0.25, 0.1)), 3.0)
	var hand := Vector2(side * 13, -4)
	if musket:
		# Пищаль, наведена на ціль
		draw_line(hand - facing * 10.0, hand + facing * 34.0, _c(Color(0.35, 0.22, 0.1)), 4.0)
		draw_line(hand + facing * 14.0, hand + facing * 36.0, _c(Color(0.55, 0.55, 0.58)), 2.5)
	else:
		# Бердиш
		draw_line(hand + Vector2(0, 16), hand + Vector2(0, -30), _c(Color(0.4, 0.28, 0.15)), 3.0)
		draw_colored_polygon(PackedVector2Array([hand + Vector2(0, -30), hand + Vector2(side * 12, -24), hand + Vector2(side * 10, -8), hand + Vector2(0, -12)]), _c(Color(0.6, 0.62, 0.6)))
	# Голова: сіро-зелена шкіра, чорні жили, світлі очі
	var h := Vector2(0, -24)
	draw_circle(h, 9.0, _c(skin))
	draw_line(h + Vector2(-6, 2), h + Vector2(-2, 8), Color(0.1, 0.15, 0.05), 1.5)
	draw_line(h + Vector2(5, -4), h + Vector2(7, 4), Color(0.1, 0.15, 0.05), 1.5)
	var glow := 0.6 + 0.4 * sin(phase * 2.0)
	draw_circle(h + Vector2(side * 3 - 3, -1), 2.2, Color(0.6, 1.0, 0.2, glow))
	draw_circle(h + Vector2(side * 3 + 3, -1), 2.2, Color(0.6, 1.0, 0.2, glow))
	# Висока шапка
	draw_colored_polygon(PackedVector2Array([h + Vector2(-9, -5), h + Vector2(9, -5), h + Vector2(7, -18), h + Vector2(-7, -18)]), _c(Color(0.35, 0.12, 0.1)))
	draw_rect(Rect2(h + Vector2(-10, -7), Vector2(20, 4)), _c(Color(0.25, 0.2, 0.15)))
	# Зелений сморід зарази
	draw_circle(Vector2(sin(phase * 0.7) * 6.0, -38), 5.0, Color(0.4, 0.8, 0.2, 0.25))


func _draw_vovkulaka(side: float) -> void:
	var run := sin(phase * 1.5) * 3.0
	# Задні лапи та хвіст
	draw_line(Vector2(-6, 8), Vector2(-8, 16 + run), _c(color.darkened(0.3)), 5.0)
	draw_line(Vector2(6, 8), Vector2(8, 16 - run), _c(color.darkened(0.3)), 5.0)
	draw_line(Vector2(-side * 14, 2), Vector2(-side * 26, -6 + run), _c(color.darkened(0.15)), 6.0)
	# Тулуб
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.15, 1.0))
	draw_circle(Vector2.ZERO, 15.0, _c(color))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 2), 9.0, _c(color.lightened(0.25)))
	# Голова з вухами і пащею
	var h := Vector2(side * 10, -20)
	draw_colored_polygon(PackedVector2Array([h + Vector2(-8, -6), h + Vector2(-5, -18), h + Vector2(-1, -7)]), _c(color.darkened(0.2)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(1, -7), h + Vector2(5, -18), h + Vector2(8, -6)]), _c(color.darkened(0.2)))
	draw_circle(h, 10.0, _c(color))
	draw_colored_polygon(PackedVector2Array([h + Vector2(side * 4, -4), h + Vector2(side * 17, 2), h + Vector2(side * 4, 6)]), _c(color.lightened(0.1)))
	draw_circle(h + Vector2(side * 17, 2), 2.2, Color.BLACK)
	draw_circle(h + Vector2(side * 3, -3), 2.2, Color(1, 0.85, 0.1))
	# Пазурі
	draw_line(Vector2(side * 12, 0), Vector2(side * 20, 6), _c(Color(0.9, 0.9, 0.85)), 2.0)


func _draw_zmii() -> void:
	# Крила
	var flap := sin(phase * 0.7) * 10.0
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(s * 30, -20), Vector2(s * 100, -60 - flap), Vector2(s * 90, 0), Vector2(s * 40, 10)
		]), _c(Color(0.15, 0.4, 0.2, 0.9)))
	# Тіло
	draw_circle(Vector2(0, 0), radius, _c(color))
	draw_circle(Vector2(0, 8), radius * 0.6, _c(Color(0.75, 0.7, 0.35)))
	# Три голови на шиях, що тягнуться до козака
	for i in 3:
		var a := facing.angle() + (i - 1) * 0.6
		var sway := sin(phase * 0.5 + i) * 6.0
		var neck_end := Vector2.from_angle(a) * 70.0 + Vector2(0, -30 + sway)
		draw_line(Vector2(0, -20), neck_end, _c(color.darkened(0.15)), 16.0)
		draw_circle(neck_end, 17.0, _c(color.lightened(0.1)))
		var eye := neck_end + Vector2.from_angle(a) * 8.0
		draw_circle(eye + Vector2(0, -5), 3.5, Color(1, 0.85, 0.1))
		draw_circle(eye + Vector2(0, -5), 1.5, Color.BLACK)
	# Смуга здоров'я боса
	var w := 160.0
	draw_rect(Rect2(-w / 2, -radius - 70, w, 9), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -radius - 70, w * hp / max_hp, 9), Color(0.95, 0.35, 0.1))


# --- Супербоси Башти ---

func _draw_baba_yaha(side: float) -> void:
	var bob := sin(phase * 1.2) * 3.0
	# Ступа
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -4 + bob), Vector2(16, -4 + bob), Vector2(12, 18 + bob), Vector2(-12, 18 + bob)]), _c(Color(0.45, 0.3, 0.15)))
	draw_line(Vector2(-16, -4 + bob), Vector2(16, -4 + bob), _c(Color(0.6, 0.45, 0.25)), 3.0)
	# Мітла позаду
	draw_line(Vector2(-side * 10, 2 + bob), Vector2(-side * 30, -14 + bob), _c(Color(0.55, 0.4, 0.2)), 2.5)
	for i in 4:
		draw_line(Vector2(-side * 30, -14 + bob), Vector2(-side * (36 + i * 2), -8 + i * 3 + bob), _c(Color(0.8, 0.65, 0.3)), 1.5)
	# Баба: хустка, гачкуватий ніс
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -6 + bob), Vector2(9, -6 + bob), Vector2(7, -22 + bob), Vector2(-7, -22 + bob)]), _c(color))
	var h := Vector2(0, -30 + bob)
	draw_circle(h, 9.0, _c(Color(0.8, 0.7, 0.55)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -2), h + Vector2(10, -2), h + Vector2(0, -14)]), _c(Color(0.6, 0.15, 0.15)))
	draw_line(h + Vector2(side * 4, 0), h + Vector2(side * 11, 4), _c(Color(0.75, 0.6, 0.45)), 2.5)
	draw_circle(h + Vector2(side * 3, -2), 1.8, Color(1.0, 0.6, 0.1))
	# Іскри з печі
	for i in 3:
		var a := phase * 0.9 + i * TAU / 3.0
		draw_circle(Vector2(cos(a) * 20.0, 8 + sin(a) * 6.0 + bob), 2.2, Color(1.0, 0.55, 0.1, 0.8))
	if phase2:
		draw_arc(Vector2(0, -8), 32.0, 0.0, TAU, 24, Color(1.0, 0.5, 0.1, 0.5), 2.0)


func _draw_solovei(side: float) -> void:
	var sway := sin(phase * 0.7) * 2.0
	# Дубова гілка-пень під ним
	draw_rect(Rect2(Vector2(-14, 8), Vector2(28, 10)), _c(Color(0.35, 0.25, 0.12)))
	# Пір'яний плащ
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -16), Vector2(14, -16), Vector2(20 + sway, 10), Vector2(-20 + sway, 10)]), _c(color))
	for i in 5:
		var x := -16.0 + i * 8.0
		draw_line(Vector2(x, -10), Vector2(x + sway, 10), _c(Color(0.2, 0.25, 0.12)), 1.5)
	# Голова: шапка, борода, роздуті щоки
	var h := Vector2(0, -26)
	draw_circle(h, 10.0, _c(Color(0.85, 0.7, 0.55)))
	draw_circle(h + Vector2(side * 6, 2), 4.0, _c(Color(0.95, 0.75, 0.6)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-6, 6), h + Vector2(6, 6), h + Vector2(0, 16)]), _c(Color(0.3, 0.2, 0.1)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-11, -4), h + Vector2(11, -4), h + Vector2(8, -14), h + Vector2(-8, -14)]), _c(Color(0.4, 0.3, 0.2)))
	draw_circle(h + Vector2(side * 3, -1), 1.8, Color(0.1, 0.1, 0.1))
	# Звукові хвилі з рота
	for i in 3:
		var r := 8.0 + fmod(phase * 6.0 + i * 7.0, 20.0)
		draw_arc(h + Vector2(side * 10, 3), r, -0.6 if side > 0 else PI - 0.6, 0.6 if side > 0 else PI + 0.6, 8, Color(0.8, 0.9, 1.0, 0.7 - r / 40.0), 1.5)
	if phase2:
		draw_arc(Vector2(0, -8), 32.0, 0.0, TAU, 24, Color(0.7, 0.85, 1.0, 0.5), 2.0)


func _draw_lykho(side: float) -> void:
	var sway := sin(phase * 0.5) * 2.5
	# Велетенське кощаве тіло в лахмітті
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -28), Vector2(18, -28), Vector2(26 + sway, 20), Vector2(-26 + sway, 20)]), _c(color))
	for i in 4:
		var x := -20.0 + i * 13.0
		draw_line(Vector2(x, 20), Vector2(x + sway, 28), _c(Color(0.18, 0.15, 0.2)), 2.0)
	# Довгі руки до землі
	draw_line(Vector2(-18, -20), Vector2(-34 + sway, 22), _c(Color(0.5, 0.45, 0.5)), 4.0)
	draw_line(Vector2(18, -20), Vector2(34 + sway, 22), _c(Color(0.5, 0.45, 0.5)), 4.0)
	# Голова з одним оком
	var h := Vector2(0, -40)
	draw_circle(h, 14.0, _c(Color(0.55, 0.5, 0.55)))
	draw_circle(h + Vector2(side * 2, -1), 6.5, Color(0.95, 0.95, 0.9))
	var glow := 0.7 + 0.3 * sin(phase * 2.5)
	draw_circle(h + Vector2(side * 3, -1), 3.5, Color(0.9, 0.15, 0.2, glow))
	draw_circle(h + Vector2(side * 3, -1), 1.5, Color(0.05, 0.0, 0.0))
	# Зуби
	for i in 4:
		draw_colored_polygon(PackedVector2Array([h + Vector2(-7 + i * 4, 8), h + Vector2(-4 + i * 4, 8), h + Vector2(-5.5 + i * 4, 13)]), Color(0.9, 0.9, 0.8))
	if phase2:
		draw_arc(Vector2(0, -12), 40.0, 0.0, TAU, 24, Color(0.9, 0.2, 0.3, 0.5), 2.0)


func _draw_oprychnyk(side: float) -> void:
	var sway := sin(phase * 0.8) * 1.5
	# Чорний каптан
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -18), Vector2(11, -18), Vector2(16 + sway, 16), Vector2(-16 + sway, 16)]), _c(color))
	draw_line(Vector2(0, -18), Vector2(0 + sway, 16), _c(Color(0.5, 0.1, 0.1)), 1.5)
	# Сокира в руці
	var hand := Vector2(side * 14, -6)
	draw_line(Vector2(side * 6, -14), hand, _c(Color(0.3, 0.25, 0.25)), 2.5)
	draw_line(hand + Vector2(0, 14), hand + Vector2(0, -24), _c(Color(0.45, 0.3, 0.15)), 2.5)
	draw_colored_polygon(PackedVector2Array([hand + Vector2(0, -24), hand + Vector2(side * 14, -20), hand + Vector2(side * 12, -8), hand + Vector2(0, -12)]), _c(Color(0.7, 0.72, 0.78)))
	# Собача голова на сідлі (на поясі) й мітла
	draw_circle(Vector2(-side * 12, 6), 4.5, _c(Color(0.4, 0.3, 0.2)))
	draw_line(Vector2(-side * 8, -4), Vector2(-side * 22, 20), _c(Color(0.5, 0.4, 0.2)), 2.0)
	# Голова в гостроверхій шапці, червоні очі
	var h := Vector2(0, -28)
	draw_circle(h, 9.0, _c(Color(0.75, 0.65, 0.55)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -3), h + Vector2(10, -3), h + Vector2(0, -22)]), _c(Color(0.1, 0.08, 0.08)))
	draw_rect(Rect2(h + Vector2(-10, -5), Vector2(20, 4)), _c(Color(0.5, 0.1, 0.1)))
	draw_circle(h + Vector2(-3, 0), 1.6, Color(0.95, 0.1, 0.1))
	draw_circle(h + Vector2(3, 0), 1.6, Color(0.95, 0.1, 0.1))
	draw_line(h + Vector2(-4, 6), h + Vector2(4, 6), Color(0.3, 0.2, 0.2), 1.5)
	if phase2:
		draw_arc(Vector2(0, -10), 30.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, 0.5), 2.0)
