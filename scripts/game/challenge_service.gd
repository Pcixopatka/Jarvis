extends RefCounted
## Щоденні й тижневі виклики та досягнення. Усе живиться одним лічильником подій record().
## Стан: world.stats {лічильник: значення} і world.challenges:
##   {"day": "2026-11-09", "week": "2026-W45", "daily": [...], "weekly": [...], "ach": {id: true}}
## Виклик: {"stat", "text", "goal", "progress", "claimed", "group", "where"}.
## Частина викликів щодня й щотижня — про події й заняття (група "event"); випадає лише те,
## що гравцеві вже відкрито, а гра подбає, щоб таке було де виконати (див. pending і служби подій).

const A := preload("res://scripts/data/achievements.gd")
const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

## Версія складу викликів: змінилась — сьогоднішні й тижневі перескладаються (розпочаті лишаються).
const VERSION := 2

## Для тестів можна підмінити «сьогодні» (unix-час); 0 — справжній годинник.
static var now_override := 0


static func _now() -> int:
	return now_override if now_override > 0 else int(Time.get_unix_time_from_system())


static func day_key(t: int) -> String:
	var d := Time.get_date_dict_from_unix_time(t)
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


## Тиждень рахуємо від понеділка (номер тижня від 1970 року).
static func week_key(t: int) -> String:
	return "W%d" % int((t / 86400 + 3) / 7)


## player — герой, для якого складаємо виклики (щоб не випало ще закритого); без нього судимо за лічильниками роду.
static func state(world, player = null) -> Dictionary:
	var c: Dictionary = world.challenges
	var t := _now()
	var fresh: bool = int(c.get("v", 1)) != VERSION
	if c.get("day", "") != day_key(t) or fresh:
		var old: Array = c.get("daily", []) if c.get("day", "") == day_key(t) else []
		c["day"] = day_key(t)
		c["daily"] = _keep_started(old, _generate(A.DAILY, A.DAILY_COUNT, A.DAILY_EVENTS, hash(c["day"]), world, player), A.DAILY_COUNT)
	if c.get("week", "") != week_key(t) or fresh:
		var old_w: Array = c.get("weekly", []) if c.get("week", "") == week_key(t) else []
		c["week"] = week_key(t)
		c["weekly"] = _keep_started(old_w, _generate(A.WEEKLY, A.WEEKLY_COUNT, A.WEEKLY_EVENTS, hash(c["week"]), world, player), A.WEEKLY_COUNT)
	c["v"] = VERSION
	if not c.has("ach"):
		c["ach"] = {}
	return c


## Після оновлення гри склад викликів змінився посеред дня: розпочаті й виконані лишаються, решта — нові.
static func _keep_started(old: Array, fresh: Array, n: int) -> Array:
	var out := []
	for ch in old:
		if (int(ch.get("progress", 0)) > 0 or bool(ch.get("claimed", false))) and out.size() < n:
			out.append(ch)
	for ch in fresh:
		if out.size() >= n:
			break
		if not out.any(func(o): return o["stat"] == ch["stat"]):
			out.append(ch)
	return out


## Чи відкрите гравцеві те, чого просить виклик. need: "" — завжди; інакше назва заняття.
static func available(need: String, world, player = null) -> bool:
	if need == "":
		return true
	var Acts = load("res://scripts/data/activities.gd")
	var lvl: int = player.level if player != null else int(world.stats.get("level", 1))
	var chosen: bool = (not player.is_peasant()) if player != null else lvl >= 3
	match need:
		"vigil":
			return chosen and lvl >= int(Acts.SPOTS["varta"]["level"])
		"duel":
			return chosen and lvl >= int(load("res://scripts/game/duel_service.gd").MIN_LEVEL)
		"bounty":
			return lvl >= int(load("res://scripts/game/bounty_service.gd").MIN_LEVEL)
		"tower":
			return lvl >= int(load("res://scripts/game/tower_service.gd").OPEN_LEVEL)
		"depth":
			return load("res://scripts/game/depth_service.gd").unlocked(world)
		"hunt":
			return chosen and lvl >= int(Acts.SPOTS["hunt"]["level"])
		"fish":
			return chosen and lvl >= int(Acts.SPOTS["fish"]["level"])
		"tavern", "escort", "trail":
			return chosen
		"event":
			return chosen and int(load("res://scripts/game/story_service.gd").state(world)["chapter"]) >= 1
		"defense":
			# облягають міста, до яких підповзла зараза, або розбудований хутір
			if not chosen:
				return false
			if load("res://scripts/game/camp_service.gd").built_count(world) > 0:
				return true
			for loc in world.plague.get("levels", {}):
				if int(world.plague["levels"][loc]) > 0:
					return true
			return false
		"garden":
			return load("res://scripts/game/garden_service.gd").level(world) >= 1
		"party":
			return not world.companions.is_empty()
	return true


## n викликів із шаблонів; n_event із них — про події й заняття (якщо стільки відкрито).
static func _generate(templates: Array, n: int, n_event: int, seed_value: int, world = null, player = null) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var idx := range(templates.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var events := []
	var base := []
	for i in idx:
		var t: Dictionary = templates[i]
		if world != null and not available(str(t.get("need", "")), world, player):
			continue
		if t.get("group", "base") == "event":
			events.append(t)
		else:
			base.append(t)
	var picked: Array = events.slice(0, n_event)
	picked.append_array(base.slice(0, n - picked.size()))
	if picked.size() < n:  # звичайних забракло — добираємо подіями
		picked.append_array(events.slice(n_event, n_event + n - picked.size()))
	var out := []
	var seen := {}
	for t in picked:
		if seen.has(t["stat"]):
			continue
		seen[t["stat"]] = true
		var goal := rng.randi_range(int(t["goal"][0]), int(t["goal"][1]))
		out.append({"stat": t["stat"], "text": t["text"] % goal if "%d" in t["text"] else t["text"], "goal": goal, "progress": 0, "claimed": false,
			"group": t.get("group", "base"), "where": t.get("where", "")})
	# спершу бій і господарство, потім події
	out.sort_custom(func(x, y): return x["group"] == "base" and y["group"] != "base")
	return out


## Чи є невиконаний виклик (денний або тижневий) із таким лічильником: служби подій тоді
## подбають, щоб було де його виконати (подія на мапі, завдання на супровід, сліди).
static func pending(world, stat: String) -> bool:
	var c: Dictionary = world.challenges
	for list in [c.get("daily", []), c.get("weekly", [])]:
		for ch in list:
			if ch.get("stat", "") == stat and int(ch.get("progress", 0)) < int(ch.get("goal", 1)):
				return true
	return false


## Подія в грі: збільшує лічильники, просуває виклики, відкриває досягнення.
## stat "level" — це не сума, а найвищий рівень. Повертає повідомлення для банера.
static func record(world, player, stat: String, amount: int = 1) -> Array:
	var c := state(world, player)
	var msgs := []
	if stat in ["level", "depth", "tower", "vigil", "glory"]:  # найвище досягнуте, а не сума
		world.stats[stat] = maxi(int(world.stats.get(stat, 0)), amount)
	else:
		world.stats[stat] = int(world.stats.get(stat, 0)) + amount
		for list in [c["daily"], c["weekly"]]:
			for ch in list:
				if ch["stat"] == stat and int(ch["progress"]) < int(ch["goal"]):
					ch["progress"] = mini(int(ch["goal"]), int(ch["progress"]) + amount)
					if int(ch["progress"]) >= int(ch["goal"]):
						msgs.append("Виклик виконано: %s — забери нагороду!" % ch["text"])
	for a in A.ACHIEVEMENTS:
		if c["ach"].has(a["id"]) or a["stat"] != stat:
			continue
		if int(world.stats.get(stat, 0)) >= int(a["goal"]):
			c["ach"][a["id"]] = true
			player.gold += int(a["gold"])
			msgs.append("Досягнення: «%s»! +%d грн" % [a["name"], a["gold"]])
	return msgs


static func reward_text(weekly: bool, lvl: int) -> String:
	if weekly:
		return "%d грн, рідкісна річ, жетон безпечної заточки" % (150 + 60 * lvl)
	return "%d грн і ресурси" % (40 + 20 * lvl)


static func can_claim(ch: Dictionary) -> bool:
	return int(ch["progress"]) >= int(ch["goal"]) and not ch["claimed"]


## Забрати нагороду за виклик (weekly — тижневий). Повертає текст або "".
static func claim(world, player, weekly: bool, index: int) -> String:
	var list: Array = state(world)["weekly" if weekly else "daily"]
	if index < 0 or index >= list.size() or not can_claim(list[index]):
		return ""
	list[index]["claimed"] = true
	var lvl: int = player.level
	if weekly:
		player.gold += 150 + 60 * lvl
		var it := Data.gen_item(lvl, 2)
		if not player.add_item(it):
			player.inventory.append(it)
		world.boosts["safe_sharpen"] = int(world.boosts.get("safe_sharpen", 0)) + 1
		return "Нагорода тижня: %d грн, %s, жетон безпечної заточки" % [150 + 60 * lvl, it["name"]]
	player.gold += 40 + 20 * lvl
	for r in Camp.RESOURCES:
		player.resources[r] = int(player.resources.get(r, 0)) + 2
	return "Нагорода дня: %d грн і ресурси" % (40 + 20 * lvl)


static func ready_count(world) -> int:
	var n := 0
	var c := state(world)
	for ch in c["daily"] + c["weekly"]:
		if can_claim(ch):
			n += 1
	return n


## Скільки лишилось до нових щоденних викликів (секунд).
static func seconds_to_reset() -> int:
	var t := _now()
	var d := Time.get_datetime_dict_from_unix_time(t)
	return 86400 - (int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"]))
