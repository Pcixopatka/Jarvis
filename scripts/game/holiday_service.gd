extends RefCounted
## Сезонні свята за справжнім календарем: двадцять вісім свят від Маланки до Різдва (перелік — Acts.HOLIDAYS).
## Дев'ять великих (Різдво, Великдень, Зелені свята, Купала, Спас, День Незалежності, Покрова, Андрія, Миколая)
## і дев'ятнадцять малих. Коли два свята припадають на один день, велике перебиває мале, а серед рівних
## коротше перебиває довше.
## Поки свято триває: діє святковий бонус, а з нечисті падають жетони свята.
## Жетони спільні для всіх персонажів (акаунт) і рахуються окремо на кожне свято кожного року;
## за них дають три нагороди. Стан — world.holidays (посилання на account.holidays):
##   {"<свято>:<рік>": {"tokens": n, "claimed": [bool, bool, bool]}, "seen": "<свято>:<рік>"}
## Дні рахуються за місцевим часом пристрою. Параметр t у функціях — секунди місцевого часу (−1 — зараз).
## Для тестів і перевірок: forced = "none" вимикає свята, forced = "<id>" вмикає потрібне.

const Acts := preload("res://scripts/data/activities.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")

static var forced := ""
static var _memo := {}  # свято дня рахується один раз: current() кличуть на кожного вбитого ворога


## «Зараз» за місцевим часом гравця: свято має починатись опівночі в нього, а не за Гринвічем.
## У тестах (now_override) час уже заданий як місцевий.
static func _now() -> int:
	var t := ChallengeService._now()
	if ChallengeService.now_override > 0:
		return t
	return t + int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _day(t: int) -> int:
	return int(t / 86400)


static func _day_of(year: int, month: int, day: int) -> int:
	return _day(int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0})))


static func _year(t: int) -> int:
	return int(Time.get_date_dict_from_unix_time(t)["year"])


## Великдень за східним обрядом (юліанська пасхалія, дата за новим стилем) — номер дня від 1970 року.
static func easter_day(year: int) -> int:
	var a := year % 4
	var b := year % 7
	var c := year % 19
	var d := (19 * c + 15) % 30
	var e := (2 * a + 4 * b - d + 34) % 7
	var month := (d + e + 114) / 31
	var day := (d + e + 114) % 31 + 1
	return _day_of(year, month, day) + 13  # різниця календарів у 1900–2099 роках


## Номер дня: n-й за ліком день тижня wd (0 — неділя) у місяці.
static func nth_weekday(year: int, month: int, n: int, wd: int) -> int:
	var first := _day_of(year, month, 1)
	var first_wd := int(Time.get_date_dict_from_unix_time(first * 86400)["weekday"])
	return first + (wd - first_wd + 7) % 7 + 7 * (n - 1)


static func rank(id: String) -> String:
	return str(Acts.HOLIDAYS[id].get("rank", "great"))


## Скільки днів триває свято.
static func length(id: String) -> int:
	var w := window(id, 2026)
	return int(w[1]) - int(w[0]) + 1


## Проміжок свята, що починається в цьому році: [перший день, останній день] (номери днів).
static func window(id: String, year: int) -> Array:
	var H: Dictionary = Acts.HOLIDAYS[id]
	if H.has("easter"):
		var e := easter_day(year)
		return [e + int(H["easter"][0]), e + int(H["easter"][1])]
	if H.has("nth"):
		var first := nth_weekday(year, int(H["nth"][0]), int(H["nth"][1]), int(H["nth"][2]))
		return [first, first + int(H.get("days", 1)) - 1]
	var a := _day_of(year, int(H["from"][0]), int(H["from"][1]))
	var end_year := year + 1 if int(H["to"][0]) < int(H["from"][0]) else year  # свято переходить через Новий рік
	return [a, _day_of(end_year, int(H["to"][0]), int(H["to"][1]))]


## Яке свято йде і якого року воно почалося: {"id", "year"} або {}.
static func current(t: int = -1) -> Dictionary:
	if t < 0:
		t = _now()
	if forced == "none":
		return {}
	if forced != "" and Acts.HOLIDAYS.has(forced):
		return {"id": forced, "year": _year(t)}
	var today := _day(t)
	if int(_memo.get("day", -1)) == today:
		return _memo["value"]
	var y := _year(t)
	var best := {}
	var best_score := -1
	for id in Acts.HOLIDAY_ORDER:
		for yy in [y - 1, y]:
			var w := window(id, yy)
			if today >= int(w[0]) and today <= int(w[1]):
				# велике свято перебиває мале, серед рівних коротше перебиває довше
				var score := (100000 if rank(id) == "great" else 0) + 1000 - (int(w[1]) - int(w[0]))
				if score > best_score:
					best_score = score
					best = {"id": id, "year": yy}
	_memo = {"day": today, "value": best}
	return best


static func active(t: int = -1) -> String:
	return str(current(t).get("id", ""))


## Ключ свята цього року для підрахунку жетонів ("" — свята нема).
static func season(t: int = -1) -> String:
	var c := current(t)
	return "%s:%d" % [c["id"], int(c["year"])] if not c.is_empty() else ""


static func days_left(t: int = -1) -> int:
	if t < 0:
		t = _now()
	var c := current(t)
	if c.is_empty():
		return 0
	if forced == c["id"]:
		return 1
	return int(window(c["id"], int(c["year"]))[1]) - _day(t) + 1


## Найближче свято попереду: {"id", "in_days"}.
static func upcoming(t: int = -1) -> Dictionary:
	if t < 0:
		t = _now()
	var today := _day(t)
	var y := _year(t)
	var best := {}
	for id in Acts.HOLIDAY_ORDER:
		for yy in [y, y + 1]:
			var start := int(window(id, yy)[0])
			if start > today and (best.is_empty() or start - today < int(best["in_days"])):
				best = {"id": id, "in_days": start - today}
	return best


## Святковий бонус за ключем (0 — нема свята або воно дає інше).
static func bonus(key: String, t: int = -1) -> float:
	var id := active(t)
	if id == "":
		return 0.0
	return float(Acts.HOLIDAYS[id]["bonus"].get(key, 0.0))


## Надбавки до показників героя (див. player.recalc: festive).
static func player_mods(t: int = -1) -> Dictionary:
	var out := {}
	for k in Acts.HOLIDAY_PLAYER_KEYS:
		var v := bonus(k, t)
		if v != 0.0:
			out[k] = v
	return out


## Надбавки до здобичі в бою (див. combat.festive).
static func combat_mods(t: int = -1) -> Dictionary:
	var out := {}
	for k in Acts.HOLIDAY_COMBAT_KEYS:
		var v := bonus(k, t)
		if v != 0.0:
			out[k] = v
	return out


static func _date_text(day_num: int) -> String:
	var d := Time.get_date_dict_from_unix_time(day_num * 86400)
	return "%d %s" % [int(d["day"]), Acts.MONTHS_GEN[int(d["month"]) - 1]]


## Коли свято цього разу: «24 грудня – 14 січня».
static func dates_text(id: String, year: int) -> String:
	var w := window(id, year)
	return "%s – %s" % [_date_text(int(w[0])), _date_text(int(w[1]))]


## Календар для вкладки «Свята»: найближча поява кожного свята.
static func calendar(t: int = -1) -> Array:
	if t < 0:
		t = _now()
	var today := _day(t)
	var y := _year(t)
	var cur := current(t)
	var out := []
	for id in Acts.HOLIDAY_ORDER:
		var H: Dictionary = Acts.HOLIDAYS[id]
		var yy := y - 1
		# перша поява, що ще не скінчилась
		while int(window(id, yy)[1]) < today:
			yy += 1
		var w := window(id, yy)
		var on: bool = cur.get("id", "") == id
		out.append({"id": id, "name": H["name"], "dates": dates_text(id, yy), "bonus": H["bonus_text"], "great": rank(id) == "great",
			"active": on, "in_days": 0 if on else maxi(0, int(w[0]) - today), "start": int(w[0])})
	out.sort_custom(func(a, b): return int(a["start"]) < int(b["start"]))
	return out


# ======================= Жетони й нагороди =======================

## Пороги жетонів: що більше й довше свято, то вищі.
static func tiers(id: String) -> Array:
	var long := length(id) > 3
	if rank(id) == "great":
		return Acts.TOKEN_TIERS if long else Acts.TOKEN_TIERS_SHORT
	return Acts.TOKEN_TIERS_SHORT if long else Acts.TOKEN_TIERS_TINY


## Запис цього свята в акаунті ({} — свята нема).
static func progress(world, t: int = -1) -> Dictionary:
	var key := season(t)
	if key == "":
		return {}
	if not world.holidays.has(key):
		world.holidays[key] = {"tokens": 0, "claimed": [false, false, false]}
	return world.holidays[key]


static func tokens(world, t: int = -1) -> int:
	return int(progress(world, t).get("tokens", 0))


## Скільки жетонів падає з ворога (roll — випадкове 0..1).
static func token_roll(boss: bool, elite: bool, roll: float) -> int:
	if boss:
		return Acts.TOKEN_BOSS
	if elite:
		return Acts.TOKEN_ELITE
	return 1 if roll < Acts.TOKEN_CHANCE else 0


static func add_tokens(world, n: int, t: int = -1) -> int:
	var p := progress(world, t)
	if p.is_empty() or n <= 0:
		return 0
	p["tokens"] = int(p["tokens"]) + n
	return int(p["tokens"])


static func can_claim(world, i: int, t: int = -1) -> bool:
	var id := active(t)
	if id == "" or i < 0 or i > 2:
		return false
	var p := progress(world, t)
	return not p["claimed"][i] and int(p["tokens"]) >= int(tiers(id)[i])


## Що дають за поріг i (0..2). id — свято ("" — те, що йде зараз); велике щедріше за мале.
static func reward_text(i: int, level: int, id: String = "") -> String:
	if id == "":
		id = active()
	var great := id == "" or rank(id) == "great"
	match i:
		0:
			return "%d грн і по %d кожного ресурсу" % [reward_gold(0, level, great), 5 if great else 3]
		1:
			return "рідкісна річ і 3 трофеї" if great else "добротна річ і 2 трофеї"
	if great:
		return "Алатир-камінь, %d слави й %d грн" % [Acts.TOKEN_GLORY, reward_gold(2, level, great)]
	return "рідкісна річ, %d слави й %d грн" % [Acts.TOKEN_GLORY_SMALL, reward_gold(2, level, great)]


static func reward_gold(i: int, level: int, great: bool) -> int:
	if i == 0:
		return 200 + 40 * level if great else 150 + 30 * level
	return 500 + 100 * level if great else 300 + 60 * level


## Забрати нагороду свята. Повертає повідомлення (порожньо — не можна).
static func claim(world, player, i: int, t: int = -1) -> Array:
	if not can_claim(world, i, t):
		return []
	var Data = load("res://scripts/data/data.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var id := active(t)
	var great := rank(id) == "great"
	progress(world, t)["claimed"][i] = true
	var name: String = Acts.HOLIDAYS[id]["name"]
	var msgs := []
	match i:
		0:
			player.gold += reward_gold(0, player.level, great)
			for r in Camp.RESOURCES:
				player.resources[r] = int(player.resources.get(r, 0)) + (5 if great else 3)
			msgs.append("%s: %s" % [name, reward_text(0, player.level, id)])
		1:
			var floor_rarity := 2 if great else 1
			var it: Dictionary = Data.gen_item(player.level, maxi(floor_rarity, Data.roll_rarity(player.level, floor_rarity)))
			if not player.add_item(it):
				player.inventory.append(it)
			var trophies := 3 if great else 2
			player.resources[Camp.TROPHY] = int(player.resources.get(Camp.TROPHY, 0)) + trophies
			msgs.append("%s: %s і %d трофеї" % [name, Data.item_title(it), trophies])
		_:
			var GloryService = load("res://scripts/game/glory_service.gd")
			player.gold += reward_gold(2, player.level, great)
			if great:
				load("res://scripts/game/stone_service.gd").grant(player, "alatyr")
				msgs.append("%s: %s" % [name, reward_text(2, player.level, id)])
			else:
				var it2: Dictionary = Data.gen_item(player.level, maxi(2, Data.roll_rarity(player.level, 2)))
				if not player.add_item(it2):
					player.inventory.append(it2)
				msgs.append("%s: %s, %d слави й %d грн" % [name, Data.item_title(it2), Acts.TOKEN_GLORY_SMALL, reward_gold(2, player.level, great)])
			# слава без святкового подвоєння — це вже сама нагорода свята
			msgs.append_array(GloryService.add_plain(world, player, Acts.TOKEN_GLORY if great else Acts.TOKEN_GLORY_SMALL))
	return msgs


## Привітання зі святом — один раз на кожне свято кожного року. "" — уже вітали або свята нема.
static func greeting(world, t: int = -1) -> String:
	var key := season(t)
	if key == "" or str(world.holidays.get("seen", "")) == key:
		return ""
	world.holidays["seen"] = key
	var H: Dictionary = Acts.HOLIDAYS[active(t)]
	return "Свято: %s!\n%s. З нечисті падають жетони: %s." % [H["name"], _cap(H["bonus_text"]), str(H["token"]).to_lower()]


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s
