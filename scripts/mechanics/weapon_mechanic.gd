extends "res://scripts/mechanics/hero_mechanic.gd"
## Механіка виду зброї: як герой б'є тим, що в руках. Множники удару, підказка й прапорці лежать у
## data/weapons.json, запис називає свій скрипт («mechanic»: "weapon/sabre"), а удар — код у
## scripts/mechanics/weapon/<вид>.gd.
##
## Типово зброя б'є зблизька: серія з трьох ударів дугою (третій — завершальний, ширший і дальший) і
## заряджений удар (повний — довкола, з приголомшенням). Так б'ють шабля й спис, а булава ще й оглушує
## завершальним. Хто стріляє (посох, пищаль, лук, пістолі), переписує attack і charged.
##
## Рушій (Player) бере один об'єкт на вид зброї (без стану) і кличе його з attack(), charged_strike() і
## recalc(). Яка характеристика дає силу удару, чи б'є зброя снарядами і як далеко — це дані запису
## («stat», «agi», «ranged», «shot_range»), а не код.

const BASE_PATH := "res://scripts/mechanics/weapon_mechanic.gd"

## Вид зброї (weapons.json).
var type := ""


func order() -> int:
	return 0


## Звичайний удар: step — крок серії (0..2), finisher — завершальний. Рушій уже поставив перезарядку удару
## (після завершального — довшу) і скинув серію, якщо вікно минуло.
func attack(step: int, finisher: bool) -> void:
	var arc: float = p.attack_arc * (1.5 if finisher else 1.0)
	# Автонаведення — на телефоні цілитися пальцем незручно.
	var target: Node2D = nearest(p.attack_range * 1.8)
	if target:
		p.facing = (target.global_position - p.global_position).normalized()
	p.swing_time = 0.18
	p.swing_duration = 0.18
	p.swing_full = false
	Audio.play("swing", 0.15, -4.0 if not finisher else 0.0)
	var hits := 0
	var crit_any := false
	var reach: float = p.attack_range * (1.15 if finisher else 1.0)
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		var dist := to.length()
		if dist > reach + e.radius:
			continue
		if dist < 1.0 or absf(p.facing.angle_to(to)) <= arc * 0.5:
			var r := roll(p.COMBO_MULT[step])
			hit(e, r[0], to.normalized() * 280.0 * p.weapon["kb"] * (2.2 if finisher else 1.0), r[1])
			if finisher:
				finisher_hit(e)
			hits += 1
			crit_any = crit_any or r[1]
	if hits > 0:
		# влучний удар трохи поповнює наснагу; швидші удари дають стільки ж за секунду, а не більше
		p.mana = minf(p.max_mana, p.mana + p.Data.MANA_ON_HIT * minf(1.0, p.attack_cooldown / p.Data.MANA_ON_HIT_CD))
		p.combo_step = (step + 1) % p.COMBO_MULT.size()
		p.combo_timer = p.COMBO_WINDOW
		if finisher:
			combat.fx.ring(p.global_position + p.facing * 40.0, Color(1.0, 0.8, 0.4), 16, reach, 4, 0.25)
			combat.shake(4.0)
			p.finisher_blow()
	else:
		p.combo_step = 0
	if hits > 0:
		Audio.play("crit" if crit_any else "hit", 0.12)
		combat.shake(2.5 * p.weapon["kb"])
		if crit_any:
			combat.hitstop(0.05)


## Завершальний удар зблизька влучив у живу ціль e (булава оглушує).
func finisher_hit(_e) -> void:
	pass


## Заряджений удар (відпустив Блок, утримавши його): power — сила заряду 0..1. Повний заряд б'є довкола
## і приголомшує нечисть.
func charged(power: float) -> void:
	var mult := 1.6 + 1.6 * power
	var reach: float = p.attack_range * (1.2 + 0.6 * power)
	var full := power >= 0.99
	var arc: float = TAU if full else minf(TAU, p.attack_arc * 1.6)
	var target: Node2D = nearest(reach * 1.5)
	if target:
		p.facing = (target.global_position - p.global_position).normalized()
	p.swing_time = 0.3
	p.swing_duration = 0.3
	p.swing_full = full
	p.swing_reach = reach
	var hits := 0
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() > reach + e.radius:
			continue
		if full or to.length() < 1.0 or absf(p.facing.angle_to(to)) <= arc * 0.5:
			var r := roll(mult)
			hit(e, r[0], to.normalized() * 600.0 * (1.0 + power) * p.weapon["kb"], r[1])
			if not e.dead and not e.is_boss:
				e.stun = maxf(e.stun, 0.4 + 0.8 * power)
			hits += 1
	p.combo_step = 0
	p.attack_timer = p.attack_cooldown
	Audio.play("slash", 0.05)
	combat.shake(6.0 + 6.0 * power)
	combat.fx.ring(p.global_position, Color(1.0, 0.85, 0.35), 30, reach, 6, 0.35)
	if hits > 0:
		combat.hitstop(0.06 + 0.05 * power)
		Events.charged_hit.emit()
	if full:
		combat.float_text(p.global_position + Vector2(0, -70), "Козацький удар!", Color(1.0, 0.85, 0.3))
		if hits > 0:
			p.finisher_blow()


## Множник шкоди героя з цією зброєю (Player.recalc, одразу після основи шкоди).
func damage_mult() -> float:
	return 1.0


## Дільник перезарядки удару з цією зброєю (Player.recalc, після спритності й люті).
func cd_mult() -> float:
	return 1.0


# ---------- Цеглини стрільців ----------

## Ціль пострілу: найближча нечисть у межах 1,3 дальності. Нема — серія скидається, повертає null.
func shot_target():
	var target: Node2D = nearest(p.attack_range * 1.3)
	if target == null:
		p.combo_step = 0
	return target


## Наступний крок серії після пострілу.
func next_step(step: int) -> void:
	p.combo_step = (step + 1) % p.COMBO_MULT.size()
	p.combo_timer = p.COMBO_WINDOW


## Постріл у ціль трохи поповнює наснагу: стрілець не б'є зблизька, тож отримує половину козацького.
func shot_mana() -> void:
	p.mana = minf(p.max_mana, p.mana + p.Data.MANA_ON_HIT * p.Data.MANA_ON_SHOT * minf(1.0, p.attack_cooldown / p.Data.MANA_ON_HIT_CD))


# ---------- Завантаження ----------

## Скрипт механіки зброї за посиланням ("weapon/sabre"); null — нема файлу чи не та основа.
static func script_of(ref: String) -> Script:
	return Loader.script_of(ref, BASE_PATH)


## Новий об'єкт механіки зброї для героя player. Без посилання чи з хибним — типова (б'є зблизька), у
## другому разі з гучною помилкою.
static func create(ref: String, weapon_type: String, weapon_num: int, player):
	var s: Script = script_of(ref) if ref != "" else null
	if s == null:
		if ref != "":
			push_error("Механіка зброї «%s» не знайдена (%s)" % [ref, Loader.path_of(ref)])
		s = load(BASE_PATH)
	var m = s.new()
	m.p = player
	m.type = weapon_type
	m.num = weapon_num
	m.bits = hooks_of(s, BASE_PATH)
	return m
