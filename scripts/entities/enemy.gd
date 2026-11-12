class_name Enemy
extends Node2D
## Нечисть: мавка, упир, болотяник, вовкулака; боси — Змій або велетенські різновиди інших.

const Data := preload("res://scripts/data/data.gd")
const TelegraphScript := preload("res://scripts/world/telegraph.gd")
const Status := preload("res://scripts/game/status.gd")
const Peril := preload("res://scripts/data/peril.gd")
const Elites := preload("res://scripts/data/elites.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const Mechanic := preload("res://scripts/mechanics/mechanic.gd")
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
var _sep := Vector2.ZERO  # останнє пораховане розштовхування (оновлюється через кадр)
var _sep_slot := randi() % 2
var slow_timer := 0.0
var contact_cd := 0.0
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
var affixes := []  # властивості еліти (id із data/elite_affixes.json, див. Elites)
var title := ""  # ім'я еліти над головою
var dmg_taken_mult := 1.0
var base_scale := 1.0
var rams_gate := false  # в обороні: іде просто на браму, поки козак не стане поперек дороги
var phase2 := false  # бос лютішає на половині здоров'я (запис «boss.phase2», див. _enter_phase2)
var anim_moving := false  # для спрайтів: чи рухався цього кадру
var treasure_guard := false  # подія «Знахідка»: після смерті лишає скриню
var bounty_id := 0  # ціль із дошки розшуку (див. BountyService)
var style := ""  # суперник у герці: rubaka | spysnyk | strilets | kharakternyk | bulavnyk (див. Activities.RIVALS)
var sprite := ""  # лист спрайтів, якщо він не збігається з kind
var cast_time := 0.0  # стоїть і заносить удар (серія рубаки, удар булави)
var illusion := false  # мара відьми: зникає від першого ж удару й нічого не лишає
var life_left := 0.0  # скільки ще живе мара
var exposed := 0.0  # бос беззахисний (Вій осліп, пушкар після осічки, бенкет перебито): отримує більше шкоди
var dmg_cap := 0.0  # суперник тримає удар: за секунду втрачає не більше цієї частки здоров'я (0 — без межі)
var loot_gold := 0  # злидень: скільки гривень поцупив у героя (повертаються, коли його здолати)
var _dmg_window := 0.0  # скільки шкоди отримав за останню секунду
var _base_speed := 0.0  # швидкість до зміни зросту (Лісовий Дід, див. boss/lisovyi_did.gd; бій множить її разом зі speed)
var enrage_after := 0.0  # надважкий бос: через скільки секунд бою починає лютішати (0 — ніколи)
var enrage_n := 0  # скільки разів уже полютішав
var _fight_t := 0.0
## Механіка виду (scripts/mechanics/, див. Mechanic): прийоми боса, особливий прийом, власна стрільба...
## null — звичайна нечисть без особливостей.
var mechanic = null
var _mh := 0  # хуки, які механіка написала (біти Mechanic.SETUP...)
var _mech_boss := false  # механіка — бойова форма боса (запис «boss.mechanic»), а не звичайна
var _trick := false  # звичайна нечисть має свій прийом (механіка пише ability)


func setup(k: String, lvl: int, boss: bool = false) -> void:
	kind = k
	level = lvl
	var s := Data.enemy_hp_scale(lvl)  # мірка від еталонного героя цього рівня
	# Сталі числа виду — у data/mobs.json (див. GameDB); невідомий вид лишає типові значення
	var R: Dictionary = GameDB.mob(k)
	var at: Dictionary = R.get("attack", {})
	if not R.is_empty():
		var st: Dictionary = R["stats"]
		radius = st["radius"]
		max_hp = st["hp"]
		speed = st["speed"]
		damage = st["damage"]
		xp_value = st["xp"]
		color = R["color"]
		if at.has("ranged"):
			ranged = at["ranged"]
		if at.has("keep_distance"):
			keep_distance = at["keep_distance"]
		if at.has("shoot_cd"):
			shoot_cd = at["shoot_cd"]
		if st.has("scale"):
			base_scale = st["scale"]
			scale = Vector2.ONE * base_scale
	r_draw = radius
	max_hp *= s
	damage *= Data.enemy_dmg_scale(lvl)
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
	windup_max = at["windup"] if at.has("windup") else 0.35
	_attach_mechanic(k)
	if is_boss:
		windup_max = 0.55
		ability_timer = 3.0
		var ab: Dictionary = at.get("as_boss", {})
		if not ab.is_empty():
			if ab.has("ranged"):
				ranged = ab["ranged"]
			if ab.has("shoot_cd"):
				shoot_cd = ab["shoot_cd"]
			shoot_timer = randf_range(1.0, shoot_cd)
	hp = max_hp
	add_to_group("enemies")
	if combat != null:
		combat.enemies_dirty()


## Механіка виду: у бою як бос — з «boss.mechanic», інакше — з «mechanic» запису (її має й ватажок
## хвилі, що б'ється як бос, хоч запису боса в нього нема: тоді прийом у нього типовий босів).
func _attach_mechanic(k: String) -> void:
	var ref := GameDB.mechanic(k, true) if is_boss else ""
	_mech_boss = ref != ""
	if ref == "":
		ref = GameDB.mechanic(k)
	if ref == "":
		return
	mechanic = Mechanic.create(ref, self)
	if mechanic == null:
		return
	_mh = Mechanic.hooks_of(mechanic.get_script())
	_trick = not _mech_boss and _mh & Mechanic.ABILITY != 0
	if _trick:
		ability_timer = randf_range(2.0, 4.5)  # перший прийом — не одразу й не всі разом
	if _mh & Mechanic.SETUP:
		mechanic.setup()


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


## Тримає ворога в межах арени (відступ на його радіус).
func _clamp_to_arena() -> void:
	var pad := Vector2(radius, radius)
	position = position.clamp(combat.arena.position + pad, combat.arena.end - pad)


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
	if is_boss and enrage_after > 0.0 and combat.player != null and combat.player.alive:
		_tick_enrage(delta)  # час бою йде завжди: приголомшенням лють не відтягнеш
	if _mh & Mechanic.TICK:
		mechanic.tick(delta)
	# Вікно стелі шкоди спадає завжди, і поки ворог приголомшений: інакше приголомшений суперник
	# отримував менше шкоди, ніж притомний
	if dmg_cap > 0.0:
		_dmg_window = maxf(0.0, _dmg_window - max_hp * dmg_cap * delta)
	if stun > 0.0:
		stun -= delta * (2.5 if style != "" else 1.0)  # суперник у герці оговтується швидше
		windup = 0.0
		position += knockback * delta
		_clamp_to_arena()  # інакше удари по приголомшеному виштовхують його за край мапи
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
		if _mh & Mechanic.CHASE:
			mechanic.chase(p, dist, dir, delta)

	# Розштовхування, щоб нечисть не злипалась в одну купу. Рахується через кадр (половина нечисті
	# на парних кадрах, половина на непарних): сусіди за один кадр майже не зсуваються, а робота,
	# що росте як квадрат юрби, стає вдвічі меншою.
	if (Engine.get_process_frames() + _sep_slot) % 2 == 0:
		_sep = Vector2.ZERO
		var here := global_position
		for o in combat.enemies_now():
			if o == self or o.dead:
				continue
			var d: Vector2 = here - o.global_position
			var min_d: float = radius + o.radius
			var l2 := d.length_squared()
			if l2 < min_d * min_d and l2 > 0.0001:
				var l := sqrt(l2)
				_sep += d / l * (min_d - l) / min_d
	var sep := _sep

	cast_time = maxf(0.0, cast_time - delta)
	var spd := speed * (0.4 if slow_timer > 0.0 else 1.0) * (0.15 if windup > 0.0 else 1.0) * (0.05 if cast_time > 0.0 else 1.0) * Status.speed_mult(self)
	if style in ["rubaka", "kharakternyk", "bulavnyk"] and dist > 280.0:
		spd *= 1.7  # суперник ближнього бою рветься до стрільця
	var vel := desired * spd + sep * speed * 1.5 + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	anim_moving = vel.length() > 25.0
	position += vel * delta
	_clamp_to_arena()

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
	elif _trick and p != null and not illusion and cast_time <= 0.0:
		ability_timer -= delta
		if ability_timer <= 0.0:
			_minion_ability(p, dist)

	if ranged and p != null:
		shoot_timer -= delta * (0.5 if slow_timer > 0.0 else 1.0)
		if shoot_timer <= 0.0 and dist < 750.0:
			shoot_timer = shoot_cd
			if _mh & Mechanic.VOLLEY:
				mechanic.volley(dir)
			else:
				_default_volley(dir)
	queue_redraw()


## Типовий постріл: бос — три кулі віялом, інша нечисть — одна.
func _default_volley(dir: Vector2) -> void:
	if is_boss:
		for a in [-0.25, 0.0, 0.25]:
			_shoot(global_position, dir.rotated(a), 280.0, damage * 0.6, Color(0.55, 0.85, 0.2), 12.0)
	else:
		_shoot(global_position, dir, 220.0, damage, Color(0.55, 0.85, 0.2), 9.0)


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
	if _mh & Mechanic.ON_DAMAGE:
		mechanic.on_damage(amount)
	hp -= amount
	flash = 0.12
	knockback += kb * (0.15 if is_boss else (0.45 if style != "" else 1.0))
	var col := Color(1.0, 0.85, 0.2) if crit else Color.WHITE
	combat.float_text(global_position + Vector2(0, -radius - 14), str(int(amount)) + ("!" if crit else ""), col)
	var blood: Color = GameDB.mob(kind).get("blood", Color.WHITE)  # колір бризок виду (data/mobs.json)
	combat.fx.burst(global_position + Vector2(0, -radius * 0.5), blood, 7 if crit else 4, 240, 4.0, 0.35, 300, (-kb).angle() + PI if kb.length() > 1 else 0.0, TAU if kb.length() <= 1 else 1.6)
	if crit:
		combat.fx.burst(global_position + Vector2(0, -radius * 0.5), Color(1, 0.95, 0.6), 6, 320, 3.0, 0.2)
	if is_boss and GameDB.is_phase2_boss(kind) and not phase2 and hp < max_hp * 0.5 and hp > 0.0:
		_enter_phase2()
	if hp <= 0.0 and _mh & Mechanic.ON_LETHAL and mechanic.on_lethal():
		return
	if hp <= 0.0:
		dead = true
		dying = 0.35
		remove_from_group("enemies")
		combat.enemies_dirty()
		if _mh & Mechanic.ON_DEATH:
			mechanic.on_death()
		if "plague" in affixes:
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
	if _mh & Mechanic.ON_HIT:
		mechanic.on_hit(target)
	var st: String = GameDB.hit_status(kind)
	# Слабка нечисть перших місць станів не накладає — новачкові й так непросто
	if st != "" and level >= 4 and randf() < (HIT_STATUS_CHANCE * 0.5 if is_boss else HIT_STATUS_CHANCE):
		target.add_status(st, 3.0, damage * 0.1)
	for a in affixes:
		var info: Dictionary = Elites.affix(a)
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
	title = Elites.title(kind, GameDB.mob_name(kind), affs)


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


## Нечисть, прикликана надважким босом: досвіду й душі не дає, щоб її не було вигідно молоти.
func _summon_free(kinds: Array, count: int) -> void:
	for i in count:
		var pos: Vector2 = combat._clamp_in(global_position + Vector2.from_angle(randf() * TAU) * randf_range(100, 180), 50.0)
		combat.fx.burst(pos, Color(0.3, 0.25, 0.3), 14, 140, 8, 0.6)
		combat.spawn_enemy(kinds[randi() % kinds.size()], maxi(1, level - 2), false, pos)
		var m = combat._last_enemy()
		if m != null and m != self:
			m.xp_value = 0


## Лють надважкого боса: бій затягнувся довше за enrage_after секунд, і удар росте щокроку.
func _tick_enrage(delta: float) -> void:
	_fight_t += delta
	if _fight_t < enrage_after:
		return
	var want: int = 1 + int((_fight_t - enrage_after) / Peril.ENRAGE_EVERY)
	while enrage_n < want:
		enrage_n += 1
		damage *= 1.0 + Peril.ENRAGE_DMG
		if enrage_n == 1:
			Events.banner.emit("%s лютішає!\nЩо довше бій, то важчий удар" % GameDB.mob_name(kind, "Бос"), Color(1.0, 0.35, 0.25))
			Events.hint.emit("enrage", "Надважкий бос лютішає, коли бій затягнувся: його удар росте кожні %d с. Довгий обережний бій тут не рятує." % int(Peril.ENRAGE_EVERY))
			Audio.play("roar", 0.0)
			combat.shake(10.0)


## Черговий прийом боса: його обертання пише механіка боса (scripts/mechanics/boss/). Ватажок без
## запису боса б'є типово: коло-удар там, де стоїть ціль.
func _boss_ability(target) -> void:
	ability_step += 1
	if _mech_boss:
		mechanic.ability(target, global_position.distance_to(target.global_position))
		return
	ability_timer = 6.0
	var t = _telegraph("circle", target.global_position, 1.0, damage * 1.3)
	t.radius = 110.0


## Особливий прийом звичайної нечисті: його пише механіка виду (scripts/mechanics/mob/).
func _minion_ability(target, dist: float) -> void:
	if _trick:
		mechanic.ability(target, dist)


# --- Мари (див. Mechanic.cast_illusions) ---

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
	combat.enemies_dirty()
	combat.fx.burst(global_position, Color(0.6, 0.3, 0.9, 0.8), 18, 200, 7, 0.5)
	Audio.play("die_spirit", 0.2, -4.0)
	queue_free()


# --- Герць: суперники-козаки ---

## Перетворює ворога на суперника: стиль бою, лист спрайтів, ім'я; здоров'я й удар задає турнір
## (їхня сила — від рівня героя, див. DuelService.loc_for).
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


## Бос лютішає на половині здоров'я (у записі «boss.phase2»): швидший, частіше стріляє, одразу
## береться до прийому. Гасло й підмогу дає механіка боса.
func _enter_phase2() -> void:
	phase2 = true
	speed *= 1.2
	shoot_cd *= 0.75
	ability_timer = 1.0
	combat.shake(12.0)
	Audio.play("roar", 0.0)
	if _mh & Mechanic.PHASE2:
		mechanic.phase2()
	else:
		_default_phase2()


## Типова лють: загальне гасло й троє з підмоги.
func _default_phase2() -> void:
	Events.banner.emit("Бос лютує!", Color(1.0, 0.4, 0.3))
	_summon(["zarazhenyi", "pishchalnyk", "chort"], 3)


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
		var ac: Color = Elites.affix(affixes[0])["color"]
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
