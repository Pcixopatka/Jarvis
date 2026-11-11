extends RefCounted
## Довідник вмінь для картки: тип (атака чи баф — куди ставиться на панелі), що підсилює,
## і живі цифри за рангом. Формули тут повторюють ті, що в player.gd: якщо міняєш одне — міняй і друге.
##
## kind: "attack" — панель праворуч (3 кнопки біля удару); "buff" — панель знизу (5 кнопок).
## scales: від чого росте сила ("damage" — шкода зброї, "hp" — здоров'я героя, "spell" — сила вмінь).
## stats(rank, p): словник «назва → значення» для таблиці картки (рядки з %d/%s уже готові).

const Classes := preload("res://scripts/data/classes.gd")
const Status := preload("res://scripts/game/status.gd")

const KIND := {
	"vyly": "attack", "first_aid": "buff",
	"whirl": "attack", "battle_cry": "buff", "musket": "attack",
	"zemnyi": "attack", "bulava": "attack", "stina": "buff",
	"pastka": "attack", "tin": "buff", "kydok": "attack",
	"kartech": "attack", "prytsil": "attack", "bochka": "attack",
	"vovk": "buff", "kulia": "buff", "zamova": "buff", "vidvid": "attack",
	"fireball": "attack", "shield": "buff", "herb": "buff",
	"zhyvytsia": "buff", "pidniaty": "buff", "ochyshchennia": "buff", "oberih_zahonu": "buff", "otruta": "attack",
	"lightning": "attack", "molot": "attack", "burya": "buff",
	"grad": "attack", "tuman": "buff", "proklin": "attack", "dukh": "buff",
}

const SCALES := {
	"vyly": "Сила зброї", "whirl": "Сила зброї й сила вмінь", "musket": "Сила зброї й сила вмінь",
	"zemnyi": "Сила зброї й сила вмінь", "bulava": "Сила зброї й сила вмінь", "pastka": "Сила зброї й сила вмінь",
	"kydok": "Сила зброї й сила вмінь", "kartech": "Сила зброї й сила вмінь", "prytsil": "Сила зброї й сила вмінь",
	"bochka": "Сила зброї й сила вмінь", "fireball": "Сила зброї (Характерництво) й сила вмінь",
	"lightning": "Сила зброї й сила вмінь", "molot": "Сила зброї й сила вмінь", "burya": "Сила зброї й сила вмінь",
	"grad": "Сила зброї й сила вмінь", "otruta": "Сила зброї й сила вмінь", "dukh": "Сила зброї й сила вмінь",
	"first_aid": "Здоров'я героя", "shield": "Здоров'я героя й сила вмінь", "herb": "Здоров'я героя й сила вмінь",
	"zhyvytsia": "Здоров'я (і Травник)", "pidniaty": "—", "ochyshchennia": "—", "oberih_zahonu": "—",
	"battle_cry": "—", "stina": "—", "tin": "—", "vovk": "—", "kulia": "—", "zamova": "—", "vidvid": "—",
	"tuman": "—", "proklin": "—",
}

## Короткий людський опис дії (що саме робить), без цифр — цифри в таблиці.
const WHAT := {
	"vyly": "Випад вилами вперед: б'є всіх на лінії перед собою й відкидає.",
	"first_aid": "Перев'язка травами: повертає частину здоров'я, знімає кровотечу.",
	"whirl": "Кругова атака: б'є всіх довкола й відкидає. На мить козак невразливий.",
	"battle_cry": "Бойовий клич: на 8 с сильніший удар і швидший біг.",
	"musket": "Постріл із самопала: куля летить у найближчого ворога й пробиває наскрізь.",
	"zemnyi": "Удар об землю: шкода й приголомшення всім довкола.",
	"bulava": "Страшний удар булавою перед собою: далеко відкидає.",
	"stina": "Козацька стіна: 6 с усі вороги поруч б'ють лише тебе, а ти отримуєш менше шкоди.",
	"pastka": "Капкан під ворогом: шкода, приголомшення й кровотеча. Стоїть, поки хтось не наступить.",
	"tin": "Тінь: 4 с вороги тебе не бачать; наступний удар — гарантований крит.",
	"kydok": "Кидок списа: летить крізь усіх ворогів на лінії.",
	"kartech": "Картеч: 7 куль віялом, кожна б'є одного ворога.",
	"prytsil": "Прицільний постріл: важка куля пробиває всіх на лінії.",
	"bochka": "Бочка пороху під ворогом: за мить великий вибух і підпал.",
	"vovk": "Вовча подоба: швидший, сильніший, кожен удар лікує.",
	"kulia": "Куля не бере: повна невразливість.",
	"zamova": "Замовляння шаблі: 10 с кожен удар перескакує блискавкою ще на 2 ворогів.",
	"vidvid": "Відвід очей: вороги довкола ціпеніють і слабшають.",
	"fireball": "Вогняна куля: летить у ворога, вибухає й підпалює всіх у колі.",
	"shield": "Щит-оберіг: 8 с поглинає шкоду.",
	"herb": "Цілюща трава: 6 с лікує тебе потроху; загін — одразу на 30%.",
	"zhyvytsia": "Живиця: одразу лікує тебе й увесь загін.",
	"pidniaty": "Підняти побратима: поранені побратими встають просто в бою.",
	"ochyshchennia": "Очищення: знімає всі стани й ненадовго не дає новим.",
	"oberih_zahonu": "Оберіг загону: 8 с ти й загін отримуєте менше шкоди.",
	"otruta": "Отруйне зілля: хмара 5 с заражає ворогів у колі.",
	"lightning": "Блискавка Перуна: б'є найближчих ворогів ланцюгом.",
	"molot": "Громовий молот: удар грому в ціль, шкода й приголомшення довкола неї.",
	"burya": "Буря: кілька секунд блискавки самі б'ють ворогів довкола (раз на пів секунди).",
	"grad": "Град: 3 с б'є ворогів у колі й морозить.",
	"tuman": "Туман: 6 с вороги в ньому сповільнені й ослаблені.",
	"proklin": "Прокляття: ціль і сусіди 8 с отримують +35% шкоди й слабшають.",
	"dukh": "Виклик духа: 15 с дух-помічник літає поруч і стріляє вогниками.",
}


static func kind(id: String) -> String:
	if KIND.has(id):
		return KIND[id]
	# вміння за даними: підсилення йдуть на нижню панель, решта — до атак
	return "buff" if str(Classes.act(id).get("type", "")) in ["buff", "summon"] else "attack"


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
