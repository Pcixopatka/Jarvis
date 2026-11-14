extends RefCounted
## Показники героя для вкладки «Герой» (UiCharacter._hero) і довідника: що саме бій зараз робить із цим героєм.
## Лише читає: кожне число зібране з тих самих джерел і в тому самому порядку, що й у Player (recalc, hit,
## _roll, take_damage, _parry, _skill_on_hit, add_status, heal) та в механіці зброї (наснага за удар).
## Тести (tests/run_tests.gd, «Екран героя: усі показники») звіряють їх із самим боєм.

const Data := preload("res://scripts/data/data.gd")
const Status := preload("res://scripts/game/status.gd")
const PlayerScript := preload("res://scripts/entities/player.gd")

## Назви груп під чотирнадцятьма давніми рядками
const ATTACK := "Напад"
const PROCS := "Стани від удару"
const DEFENSE := "Захист"
const MANA := "Наснага"
const OTHER := "Інше"
## Стани, які удар героя може накласти: [ключ fx, стан]; оглушення — окремо (не стан)
const PROC_KEYS := [["bleed_hit", "bleed"], ["burn_hit", "burn"], ["chill_hit", "chill"], ["weak_hit", "weak"], ["curse_hit", "curse"], ["stun_hit", ""]]
const STUN_LABEL := "Оглушення"
const SHOT_LABEL := "Сила пострілу"


# ---------------- Числа ----------------

## Чи сила пострілу (shot_mult) щось важить: стрілецька зброя, що стріляє з неї (лук, пістолі, пищаль).
static func uses_shot_mult(p) -> bool:
	return Data.is_agi(p.weapon_type)


## Надбавка до всіх ударів, якої нема в «Шкоді удару» (артефакт «Уламок чорного сонця», Player.hit): множник.
static func all_hits_mult(p) -> float:
	return 1.0 + float(p.art.get("dmg", 0.0))


## Шкода по босах: артефакт, душі, набори, уміння (Player.hit) і свято (Enemy.take_damage). festive — combat.festive.
static func boss_mult(p, festive: Dictionary = {}) -> float:
	return (1.0 + float(p.art.get("boss_dmg", 0.0))) * _big(p) * (1.0 + float(festive.get("boss", 0.0)))


## Шкода по еліті (і цілях розшуку — вони теж еліта): артефакт, душі, набори, уміння (Player.hit).
static func elite_mult(p) -> float:
	return (1.0 + float(p.art.get("elite_dmg", 0.0))) * _big(p)


static func _big(p) -> float:
	return (1.0 + float(p.soul_fx.get("big_dmg", 0.0))) * (1.0 + float(p.set_fx.get("big_dmg", 0.0)) / 100.0) * (1.0 + p.fx("big_dmg") / 100.0)


## Добивання (ворог слабший за Player.LOW_HP здоров'я): Загартування, душі, уміння.
static func execute_mult(p) -> float:
	return (PlayerScript.EXECUTE_PERK if p.pk("h_execute") > 0 else 1.0) * (1.0 + float(p.soul_fx.get("execute", 0.0))) * (1.0 + p.fx("execute") / 100.0)


## Перший удар (ворог здоровіший за Player.HIGH_HP).
static func opener_mult(p) -> float:
	return 1.0 + p.fx("opener") / 100.0


## По ворогах зі станом.
static func status_mult(p) -> float:
	return 1.0 + p.fx("status_dmg") / 100.0


## По оглушених.
static func stun_mult(p) -> float:
	return 1.0 + p.fx("stun_dmg") / 100.0


## Удари протягом Player.AFTER_DODGE_T с після перекиду (Player._roll).
static func after_dodge_mult(p) -> float:
	return 1.0 + p.fx("dodge_dmg") / 100.0


## Удар у відповідь на парирування як множник «Шкоди удару» (Player._parry). Парирування спершу приголомшує
## ворога, тож Player.hit завжди додає й надбавку по оглушених; решта надбавок hit — як у звичайного удару.
static func parry_mult(p) -> float:
	return PlayerScript.PARRY_HIT * p.crit_mult * (1.0 + p.fx("parry_dmg") / 100.0) * stun_mult(p)


## Шанс вибуху вбитого (душа): частка.
static func kill_blast(p) -> float:
	return float(p.soul_fx.get("kill_blast", 0.0))


## Шанс накласти стан одним ударом (уміння й душі кидають окремо): частка. key — ключ fx («burn_hit»).
static func proc_chance(p, key: String) -> float:
	var a: float = clampf(p.fx(key) / 100.0, 0.0, 1.0)
	var b: float = clampf(float(p.soul_fx.get(key, 0.0)), 0.0, 1.0) if key != "bleed_hit" else 0.0  # душі кровотечі не кладуть
	return 1.0 - (1.0 - a) * (1.0 - b)


## Яка частка удару проходить крізь блок (Player.take_damage).
static func block_pass(p) -> float:
	return PlayerScript.BLOCK_MULT * (1.0 - float(p.soul_fx.get("block", 0.0))) * (1.0 - minf(PlayerScript.BLOCK_FX_CAP, p.fx("block")) / 100.0)


## Яка частка удару проходить крізь оберіг після захисту: звитяга, уміння, зілля від зарази (Player.take_damage).
static func ward_pass(p) -> float:
	var m: float = (1.0 - float(p.valor_fx.get("ward", 0.0)) / 100.0) * (1.0 - minf(PlayerScript.WARD_FX_CAP, p.fx("ward")) / 100.0)
	if p.trip_buffs.has("antiplague"):
		m *= PlayerScript.ANTIPLAGUE_MULT
	return m


## Лікування за парирування: частка здоров'я (Загартування й уміння лікують окремо, тож частки складаються).
static func parry_heal(p) -> float:
	return PlayerScript.PARRY_HEAL_PERK * p.pk("h_parry") + maxf(0.0, p.fx("parry_heal")) / 100.0


## Лікування за вбивство: частка здоров'я.
static func kill_heal(p) -> float:
	return maxf(0.0, p.fx("kill_heal")) / 100.0


## Наснага за вбивство.
static func kill_mana(p) -> float:
	return maxf(0.0, p.fx("kill_mana"))


## Наснага за звичайний удар (зблизька — коли влучив) чи постріл стрільця (WeaponMechanic); посох її не дає.
static func mana_per_hit(p) -> float:
	var base: float = Data.MANA_ON_HIT * minf(1.0, p.attack_cooldown / Data.MANA_ON_HIT_CD)
	if not Data.is_ranged(p.weapon_type):
		return base
	if Data.is_agi(p.weapon_type):
		return Data.MANA_ON_HIT * Data.MANA_ON_SHOT * minf(1.0, p.attack_cooldown / Data.MANA_ON_HIT_CD)
	return 0.0


## На скільки коротші стани на герої (Player.add_status), без артефактів проти одного стану.
static func status_res(p) -> float:
	return minf(PlayerScript.STATUS_RES_CAP, float(p.festive.get("status", 0.0)) + float(p.art.get("status", 0.0)) + float(p.soul_fx.get("status_res", 0.0)))


## Яка частка зарази проходить (Player.add_status): 0 — під зіллям від зарази не чіпляється.
static func plague_pass(p) -> float:
	if p.plague_immune:
		return 0.0
	return (1.0 - p.plague_resist) * (1.0 - float(p.art.get("plague", 0.0)))


## Яка частка лікування доходить до героя від душ (Player.heal).
static func heal_taken(p) -> float:
	return 1.0 - float(p.soul_fx.get("heal_taken", 0.0))


# ---------------- Рядки екрана ----------------

## Групи нових рядків: [[назва групи, [[напис, значення], ...]], ...]. festive — combat.festive (свято проти босів).
static func groups(p, festive: Dictionary = {}) -> Array:
	var atk := [["Замах", "%d°" % roundi(rad_to_deg(p.attack_arc))]]
	if uses_shot_mult(p):
		atk.append([SHOT_LABEL, "x" + _trim(p.shot_mult)])
	atk.append_array([
		["Шкода всіх ударів", _bonus(all_hits_mult(p))],
		["По босах", _bonus(boss_mult(p, festive))],
		["По елітах", _bonus(elite_mult(p))],
		["Добивання", _bonus(execute_mult(p))],
		["Перший удар", _bonus(opener_mult(p))],
		["По ворогах зі станом", _bonus(status_mult(p))],
		["По оглушених", _bonus(stun_mult(p))],
		["Після перекиду", _bonus(after_dodge_mult(p))],
		["Удар парирування", "%.1f" % (p.damage * parry_mult(p))],
		["Вибух убитого", _share(kill_blast(p))],
	])
	var procs := []
	for pk in PROC_KEYS:
		procs.append([Status.name_of(pk[1]) if pk[1] != "" else STUN_LABEL, _share(proc_chance(p, pk[0]))])
	var dfn := [
		["Блок гасить", _share(1.0 - block_pass(p))],
		["Оберіг", _share(1.0 - ward_pass(p))],
		["Шипи", _share(p.thorns)],
		["Вампіризм лікує до", "%s / с" % _share(Data.LIFESTEAL_MAX_HPS)],
		["Парирування лікує", _share(parry_heal(p))],
		["За вбивство: здоров'я", _share(kill_heal(p))],
		["Перекид раз на", "%.2f с" % p.dodge_cooldown],
		["Стани коротші", _share(status_res(p))],
		["Зараза слабша", _share(1.0 - plague_pass(p))],
		["Лікування героя", _share(heal_taken(p))],
	]
	var mana := [
		["Наснага за удар", "+%s" % _trim(mana_per_hit(p))],
		["За вбивство: наснага", "+%s" % _trim(kill_mana(p))],
	]
	var other := [["Радіус збору", "%d" % int(p.pickup_radius)]]
	return [[ATTACK, atk], [PROCS, procs], [DEFENSE, dfn], [MANA, mana], [OTHER, other]]


## Множник як надбавка: 1.12 → «+12%», 0.92 → «−8%».
static func _bonus(m: float) -> String:
	var v := (m - 1.0) * 100.0
	return ("+" if v >= -0.05 else "−") + _num(absf(v)) + "%"


## Частка як відсотки: 0.35 → «35%», 0.012 → «1.2%».
static func _share(f: float) -> String:
	return ("−" if f * 100.0 < -0.05 else "") + _num(absf(f * 100.0)) + "%"


## Ціле без дробу, інакше один знак після крапки.
static func _num(v: float) -> String:
	var r := snappedf(v, 0.1)
	return str(roundi(r)) if is_equal_approx(r, roundf(r)) else "%.1f" % r


## Число до двох знаків без зайвих нулів: 2.50 → «2.5», 3.00 → «3».
static func _trim(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")
