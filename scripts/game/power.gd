extends RefCounted
## Мірило сили героя: шкода за секунду й запас живучості. Ним порівнюють спорядження (score) і його
## показує екран героя. Сила нечисті від нього більше не залежить: її мірка — еталон рівня (Data.ref_dps, ref_ehp).

const Data := preload("res://scripts/data/data.gd")


## З посохом майже вся шкода йде від чарів, а не від іскор: справжня шкода волхва за секунду
## у стільки разів більша за оцінку від удару (виміряно tools/dps_probe.gd на 20–75-му рівнях).
const STAFF_SPELLS := 2.2
## Стрільці (лук, пістолі, пищаль): постріли пробивають кількох і не знають промаху по дорозі до цілі,
## тож справжня шкода більша за оцінку від одного пострілу (tools/dps_probe.gd, 45–99-й рівні).
const RANGED_SHOTS := 1.6


## Приблизна шкода героя за секунду по одній цілі (удари з критами, серії та вміння).
static func dps(player) -> float:
	var crit: float = 1.0 + player.crit_chance * (player.crit_mult - 1.0)
	# вміння додають до ударів тим більше, що вища сила вмінь (але не безмежно)
	var skills: float = maxf(1.6, 1.3 + 0.15 * minf(float(player.skill_power), 4.0))
	if str(player.weapon_type) == "staff":
		skills *= STAFF_SPELLS
	elif Data.is_agi(str(player.weapon_type)):
		skills *= RANGED_SHOTS
	var shot: float = float(player.shot_mult) if "shot_mult" in player else 1.0  # стрільці: надлишок швидкості в силі пострілу
	return player.damage * shot / maxf(player.attack_cooldown, 0.1) * crit * skills


## Скільки варта сила золотої речі в порівнянні спорядження: шкода й здоров'я її не показують.
const UNIQUE_WORTH := 0.1
## На скільки річ має підняти силу героя, щоб вважатись кращою (менше — шум, а не покращення).
const MIN_GAIN := 0.01


## Одне число сили героя для порівняння спорядження: шкода за секунду на запас живучості
## (здоров'я з поправкою на захист). Що більше, то сильніший герой загалом.
static func score(player) -> float:
	return dps(player) * ehp(player)


## Запас живучості героя: здоров'я з поправкою на захист.
static func ehp(player) -> float:
	var ward: float = float(player.valor_fx.get("ward", 0.0)) / 100.0 if "valor_fx" in player else 0.0
	return player.max_hp / maxf(1.0 - Data.ARMOR_CAP, 1.0 - player.armor) / maxf(0.5, 1.0 - ward)


## Оцінки «чи під силу»: найбільше секунд на звичайну нечисть і найменше її ударів, які герой має витримати.
## Легко — найкраще спорядження, під силу — добре, важко — середнє; гірше за «важко» — смертельно.
const THREAT := [
	{"name": "легко", "ttk": 0.7, "hits": 20.0},
	{"name": "під силу", "ttk": 1.5, "hits": 12.0},
	{"name": "важко", "ttk": 3.0, "hits": 8.0},
]
const THREAT_WORST := "смертельно"


## Наскільки нечисть рівня level під силу цьому героєві в його спорядженні. Міряємо звичайним зараженим:
## скільки секунд герой його рубає й скільки його ударів витримає. hp_mult і dmg_mult — надбавки місця
## (глибина, поверх), floor_share — підлога сили від рівня героя (FarService.*_FLOOR).
## Повертає {"grade": 0..3, "name", "ttk", "hits"}.
static func threat(player, level: int, hp_mult: float = 1.0, dmg_mult: float = 1.0, floor_share: float = 0.0) -> Dictionary:
	var hero_lvl := int(player.level)
	var e_hp: float = maxf(Data.enemy_std_hp(level) * hp_mult, Data.enemy_std_hp(hero_lvl) * floor_share)
	var e_dmg: float = maxf(Data.enemy_std_dmg(level) * dmg_mult, Data.enemy_std_dmg(hero_lvl) * floor_share)
	var ttk: float = e_hp / maxf(dps(player), 1.0)
	var hits: float = ehp(player) / maxf(e_dmg, 1.0)
	var grade := THREAT.size()
	for i in THREAT.size():
		if ttk <= float(THREAT[i]["ttk"]) and hits >= float(THREAT[i]["hits"]):
			grade = i
			break
	return {"grade": grade, "name": str(THREAT[grade]["name"]) if grade < THREAT.size() else THREAT_WORST, "ttk": ttk, "hits": hits}


## Еталонна шкода за секунду для рівня (герой у середньому спорядженні): від неї рахуються варта, Коло,
## герць і огляд. Колись вони мірялись зі справжньою силою героя, тож спорядження там нічого не давало.
static func ref_dps(level: int) -> float:
	return Data.ref_dps(level)


## Удар, що забирає в еталонного героя цього рівня частку frac запасу живучості.
static func ref_hit(level: int, frac: float) -> float:
	return Data.ref_ehp(level) * frac


## Удар, що забирає в героя частку frac здоров'я вже після його захисту.
static func hit(player, frac: float) -> float:
	return player.max_hp * frac / maxf(1.0 - Data.ARMOR_CAP, 1.0 - player.armor)
