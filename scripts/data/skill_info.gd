extends RefCounted
## Довідник вмінь для картки: живі цифри за рангом. Формули тут повторюють ті, що в player.gd:
## якщо міняєш одне — міняй і друге. Решта того, що картка знає про вміння, — у самому вузлі
## (data/skills.json): kind — панель ("attack" — праворуч біля удару, "buff" — знизу), scales — від чого
## росте сила, what — що робить, heals — чи лікує героя.
##
## stats(rank, p): словник «назва → значення» для таблиці картки (рядки з %d/%s уже готові).

const Classes := preload("res://scripts/data/classes.gd")
const Status := preload("res://scripts/game/status.gd")


## Панель умінь: "attack" чи "buff". Вузол без «kind» (не активне) — до атак, а вміння за даними без
## нього — за шаблоном дії (підсилення й помічник — знизу).
static func kind(id: String) -> String:
	var n: Dictionary = Classes.find_node(id)
	if n.has("kind"):
		return n["kind"]
	return "buff" if str(Classes.act(id).get("type", "")) in ["buff", "summon"] else "attack"


## Чи вертає вміння здоров'я героєві (поле «heals» вузла; у вміння за даними воно мусить збігатися з
## дією: "heal" — одразу, загоєння "regen_pct" — за час; перевіряє GameDB).
static func heals(id: String) -> bool:
	return bool(Classes.find_node(id).get("heals", false))


## Що робить уміння (для картки й довідника); fallback — коли вузол цього не каже.
static func what(id: String, fallback: String = "") -> String:
	return str(Classes.find_node(id).get("what", fallback))


## Від чого росте сила вміння; fallback — коли вузол цього не каже.
static func scales(id: String, fallback: String = "") -> String:
	return str(Classes.find_node(id).get("scales", fallback))


## Таблиця цифр для рангу r (r може бути 0 — «ще не вивчено», тоді показуємо ранг 1).
## p — герой (щоб перевести множники в шкоду/здоров'я). Повертає [["назва", "значення"], ...].
static func stats(id: String, r: int, p) -> Array:
	r = maxi(1, r)
	var d: float = p.damage
	var sp: float = p.skill_power
	var hp: float = p.max_hp
	var out := []
	match id:
		"vyly":
			out.append(["Шкода", _dmg(d * 2.0 * (1.0 + 0.15 * (r - 1)) * sp)])
			out.append(["Довжина лінії", "%d" % int(maxf(p.attack_range * 1.6, 200.0))])
		"first_aid":
			out.append(["Лікування", "%d%% здоров'я (%d)" % [roundi((0.15 + 0.05 * r) * 100), int(hp * (0.15 + 0.05 * r))]])
		"whirl":
			out.append(["Шкода", _dmg(d * 1.8 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Радіус", "%d" % int(p.attack_range * 1.8 * (1.0 + 0.08 * (r - 1)))])
			if p.sk("storm") > 0:
				out.append(["Буревій", "притягує і б'є вдруге"])
		"battle_cry":
			out.append(["Шкода", "+%d%%" % roundi((0.15 + 0.05 * (r - 1)) * 100)])
			out.append(["Швидкість бігу", "+20%"])
			out.append(["Тривалість", "8 с"])
		"musket":
			var n := 5 if p.sk("buckshot") > 0 else 1
			out.append(["Шкода кулі", _dmg(d * (2.2 + 0.4 * (r - 1)) * sp * (0.6 if n > 1 else 1.0))])
			out.append(["Куль", "%d" % n])
		"zemnyi":
			out.append(["Шкода", _dmg(d * 1.6 * (1.0 + 0.15 * (r - 1)) * sp)])
			out.append(["Радіус", "230"])
			out.append(["Приголомшення", "%.1f с" % (1.0 + 0.2 * r)])
		"bulava":
			out.append(["Шкода", _dmg(d * 3.0 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Дальність", "%d" % int(maxf(p.attack_range * 1.5, 190.0))])
		"stina":
			out.append(["Шкода по тобі", "−%d%%" % roundi((0.4 + 0.05 * (r - 1)) * 100)])
			out.append(["Тривалість", "6 с"])
		"pastka":
			out.append(["Шкода", _dmg(d * 2.2 * (1.0 + 0.2 * (r - 1)) * (1.0 + 0.2 * p.pk("trapper")) * sp)])
			out.append(["Пасток одночасно", "%d" % (2 + p.pk("trapper"))])
			out.append(["Приголомшення", "1.6 с + кровотеча"])
		"tin":
			out.append(["Удар із Тіні", "крит, +%d%%" % roundi((0.2 + 0.2 * r) * 100)])
			out.append(["Тривалість", "4 с"])
		"kydok":
			out.append(["Шкода", _dmg(d * 3.0 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Пробиває", "усіх на лінії"])
		"kartech":
			out.append(["Шкода кулі", _dmg(d * 0.65 * (1.0 + 0.15 * (r - 1)) * sp)])
			out.append(["Куль", "7"])
		"prytsil":
			out.append(["Шкода", _dmg(d * (3.8 + 0.9 * (r - 1)) * sp)])
			out.append(["Пробиває", "усіх на лінії"])
		"bochka":
			out.append(["Шкода", _dmg(d * 2.8 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Радіус вибуху", "150"])
			out.append(["Підпал", "так"])
		"vovk":
			out.append(["Тривалість", "%d с" % int(10 + 2 * (r - 1))])
			out.append(["Швидкість / шкода", "+40% / +25%"])
			out.append(["Лікування з удару", "8%"])
		"kulia":
			out.append(["Невразливість", "%.1f с" % (2.0 + 0.5 * (r - 1))])
		"zamova":
			out.append(["Шкода блискавки", "%d%% від удару" % roundi((0.35 + 0.05 * r) * 100)])
			out.append(["Цілей", "2"])
			out.append(["Тривалість", "10 с"])
		"vidvid":
			out.append(["Заціпеніння", "%.1f с" % (2.0 + 0.3 * (r - 1))])
			out.append(["Радіус", "300"])
		"fireball":
			out.append(["Шкода", _dmg(d * 2.4 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Радіус вибуху", "%d" % int(95.0 * (1.0 + 0.2 * p.sk("pyre")))])
			out.append(["Горіння", "3 с"])
		"shield":
			out.append(["Поглинає", "%d%% здоров'я (%d)" % [roundi((0.2 + 0.05 * (r - 1)) * sp * 100), int(hp * (0.2 + 0.05 * (r - 1)) * sp)]])
			out.append(["Тривалість", "8 с"])
		"herb":
			out.append(["Лікування", "%d%% здоров'я за 6 с" % roundi((0.2 + 0.06 * (r - 1)) * sp * 100)])
			out.append(["Загін", "+30% одразу"])
		"zhyvytsia":
			var hp_pct: float = (0.3 + 0.05 * (r - 1)) * sp * (1.0 + 0.12 * p.pk("travnyk"))
			out.append(["Лікування", "%d%% здоров'я (%d)" % [roundi(hp_pct * 100), int(hp * hp_pct)]])
			out.append(["Кого", "тебе й увесь загін"])
		"pidniaty":
			out.append(["Здоров'я побратима", "%d%%" % roundi((0.4 + 0.15 * (r - 1)) * 100)])
		"ochyshchennia":
			out.append(["Без станів", "%d с" % int(2 + (r - 1))])
		"oberih_zahonu":
			out.append(["Шкода по загону", "−%d%%" % roundi((0.25 + 0.05 * (r - 1)) * 100)])
			out.append(["Тривалість", "8 с"])
		"otruta":
			out.append(["Зараза", "%s/с" % _dmg(d * 0.5 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Радіус / час", "110 / 5 с"])
		"lightning":
			out.append(["Шкода", _dmg(d * (1.2 + 0.25 * r) * sp * (1.0 + 0.1 * p.pk("grim")))])
			out.append(["Цілей", "%d" % (2 + r + 2 * p.sk("chain"))])
		"molot":
			out.append(["Шкода", _dmg(d * 3.5 * (1.0 + 0.2 * (r - 1)) * (1.0 + 0.1 * p.pk("grim")) * sp)])
			out.append(["Радіус", "160"])
			out.append(["Приголомшення", "0.8 с"])
		"burya":
			out.append(["Шкода удару", _dmg(d * 1.3 * (1.0 + 0.15 * (r - 1)) * (1.0 + 0.1 * p.pk("grim")) * sp)])
			out.append(["Тривалість", "%d с" % int(6 + (r - 1))])
		"grad":
			var k: float = 1.0 + 0.2 * p.pk("khmara")
			out.append(["Шкода удару", _dmg(d * 0.45 * (1.0 + 0.2 * (r - 1)) * k * sp)])
			out.append(["Радіус / час", "%d / 3 с (10 ударів)" % int(140.0 * k)])
		"tuman":
			out.append(["Радіус / час", "230 / 6 с"])
			out.append(["Вороги в тумані", "повільні й слабкі"])
		"proklin":
			out.append(["Шкода по проклятих", "+35%"])
			out.append(["Радіус / час", "150 / 8 с"])
		"dukh":
			out.append(["Шкода вогника", _dmg(d * 0.8 * (1.0 + 0.2 * (r - 1)) * sp)])
			out.append(["Тривалість", "15 с (постріл кожні 0.8 с)"])
		_:
			out = _act_stats(id, r, p)
	return out


## Цифри вміння за даними ("act" у вузлі дерева).
static func _act_stats(id: String, r: int, p) -> Array:
	var A: Dictionary = Classes.act(id)
	var out := []
	if A.is_empty():
		return out
	var d: float = p.damage
	var sp: float = p.skill_power
	if A.has("pct") and Classes.val(A["pct"], r) > 0.0:
		var tick := " за удар" if str(A.get("type", "")) == "zone" else ""
		out.append(["Шкода" + tick, _dmg(d * Classes.val(A["pct"], r) * sp)])
	if A.has("count"):
		out.append(["Снарядів", "%d" % int(Classes.val(A["count"], r))])
	if A.has("radius"):
		out.append(["Радіус", "%d" % int(Classes.val(A["radius"], r))])
	if A.has("stun"):
		out.append(["Приголомшення", "%s с" % _sec(Classes.val(A["stun"], r))])
	if A.has("status"):
		out.append(["Стан", "%s на %s с" % [str(Status.INFO.get(str(A["status"][0]), {}).get("name", "")).to_lower(), _sec(float(A["status"][1]))]])
	if A.has("dur"):
		out.append(["Тривалість", "%s с" % _sec(Classes.val(A["dur"], r))])
	if A.has("heal"):
		out.append(["Лікування", "%s%% здоров'я" % _sec(Classes.val(A["heal"], r))])
	if A.has("fx"):
		out.append(["Дія", Classes.fx_text(A["fx"], r)])
	return out


static func _sec(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


static func _dmg(v: float) -> String:
	return "%d" % int(v)
