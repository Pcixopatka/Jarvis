extends RefCounted
## Щоденні й тижневі виклики та досягнення. Усе живиться одним лічильником подій record().
## Стан: world.stats {лічильник: значення} і world.challenges:
##   {"day": "2026-11-09", "week": "2026-W45", "daily": [...], "weekly": [...], "ach": {id: true}}
## Виклик: {"stat", "text", "goal", "progress", "claimed", "group", "where"}. Шаблони викликів і досягнення —
## data/daily.json, data/weekly.json, data/achievements.json (Achievements).
## Частина викликів щодня й щотижня — про події й заняття (група "event"); випадає лише те,
## що гравцеві вже відкрито, а гра подбає, щоб таке було де виконати (див. pending і служби подій).

const A := preload("res://scripts/data/achievements.gd")
const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

## Версія складу викликів: змінилась — сьогоднішні й тижневі перескладаються (розпочаті лишаються).
const Clock := preload("res://scripts/core/clock.gd")
const VERSION := 2

## Лічильники world.stats, які гра рахує (усі виклики record() у коді). Лише на них можуть посилатися
## виклики, досягнення й «Шлях козака» (перевіряє GameDB). Новий лічильник — виклик record() у коді й рядок тут.
const STATS := ["ambush", "bond", "boss", "boss_day", "boss_week", "bounty", "bounty_kill", "charged", "cook", "craft",
	"defense", "depth", "depth_clear", "dice", "dice_12", "dice_win", "duel", "duel_champion", "duel_free", "duel_streak", "dungeon",
	"elite", "enchant", "escort", "escort_clean", "event", "expedition", "expedition_sent", "fair", "field", "fishing",
	"glory", "harvest", "hetman", "holiday_reward", "holiday_token", "holiday_top", "hunt", "kill", "kleinod", "legend",
	"legend_step", "level", "meat", "muster", "muster_champion", "parry", "peril", "peril_bosses", "pet_level", "plant",
	"ring", "ring_clear", "ring_fast", "rumor", "ryba", "saga", "set_full", "sharpen", "som", "spec", "tower",
	"tower_floor", "trade_profit", "trade_sold", "trail", "travel", "valor", "vigil", "vigil_min", "vii_blind"]
## Лічильники «префікс:id»: kill:<нечисть>, boss:<бос>, trail:<вид сліду>, cook:<страва>, event:<подія>.
const STAT_PREFIXES := ["kill", "boss", "trail", "cook", "event"]
## Що може просити виклик («need»): заняття, яке available() уміє перевірити.
const NEEDS := ["vigil", "duel", "bounty", "ring", "muster", "tower", "depth", "hunt", "fish", "tavern", "escort", "trail", "event", "defense", "garden", "party"]

## Для тестів можна підмінити «сьогодні» (unix-час); 0 — справжній годинник.
static var now_override := 0


static func _now() -> int:
	return now_override if now_override > 0 else int(Clock.now())


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
		c["daily"] = _keep_started(old, _generate(A.daily(), A.DAILY_COUNT, A.DAILY_EVENTS, hash(c["day"]), world, player), A.DAILY_COUNT)
	if c.get("week", "") != week_key(t) or fresh:
		var old_w: Array = c.get("weekly", []) if c.get("week", "") == week_key(t) else []
		c["week"] = week_key(t)
		c["weekly"] = _keep_started(old_w, _generate(A.weekly(), A.WEEKLY_COUNT, A.WEEKLY_EVENTS, hash(c["week"]), world, player), A.WEEKLY_COUNT)
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
	# вільні місця спершу віддаємо викликам про події: заради них склад і міняли
	var order: Array = fresh.filter(func(x): return x.get("group", "base") == "event")
	order.append_array(fresh.filter(func(x): return x.get("group", "base") != "event"))
	for ch in order:
		if out.size() >= n:
			break
		if not out.any(func(o): return o["stat"] == ch["stat"]):
			out.append(ch)
	var base: Array = out.filter(func(x): return x.get("group", "base") != "event")
	base.append_array(out.filter(func(x): return x.get("group", "base") == "event"))
	return base


## Чи лічильник з тих, що гра рахує (STATS чи «префікс:id» з відомим id).
static func is_stat(key: String) -> bool:
	if key in STATS:
		return true
	var parts := key.split(":")
	if parts.size() != 2 or not parts[0] in STAT_PREFIXES:
		return false
	var GameDB = load("res://scripts/core/game_db.gd")
	var Acts = load("res://scripts/data/activities.gd")
	match parts[0]:
		"kill":
			return GameDB.has_mob(parts[1])
		"boss":
			return GameDB.has_boss(parts[1])
		"trail":
			return Acts.trail_kinds().has(parts[1])
		"cook":
			return Acts.is_recipe(parts[1])
		"event":
			return parts[1] in load("res://scripts/game/event_service.gd").BATTLE_KINDS
	return false


## Чи відкрите гравцеві те, чого просить виклик. need: "" — завжди; інакше назва заняття (NEEDS).
static func available(need: String, world, player = null) -> bool:
	if need == "":
		return true
	var Acts = load("res://scripts/data/activities.gd")
	var lvl: int = player.level if player != null else int(world.stats.get("level", 1))
	var chosen: bool = (not player.is_peasant()) if player != null else lvl >= 3
	match need:
		"vigil":
			return chosen and lvl >= int(Acts.spot("varta")["level"])
		"duel":
			return chosen and lvl >= int(load("res://scripts/game/duel_service.gd").MIN_LEVEL)
		"bounty":
			return lvl >= int(load("res://scripts/game/bounty_service.gd").MIN_LEVEL)
		"ring":
			return chosen and lvl >= int(Acts.spot("kolo")["level"])
		"muster":
			return chosen and lvl >= int(Acts.MUSTER_MIN_LEVEL)
		"tower":
			return lvl >= int(load("res://scripts/game/tower_service.gd").OPEN_LEVEL)
		"depth":
			return load("res://scripts/game/depth_service.gd").unlocked(world)
		"hunt":
			return chosen and lvl >= int(Acts.spot("hunt")["level"])
		"fish":
			return chosen and lvl >= int(Acts.spot("fish")["level"])
		"tavern", "escort", "trail":
			return chosen
		"event":
			return chosen and int(load("res://scripts/game/story_service.gd").chapter_index(world)) >= 1
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
	var sorted: Array = out.filter(func(x): return x["group"] != "event")
	sorted.append_array(out.filter(func(x): return x["group"] == "event"))
	return sorted


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
	if stat in ["level", "depth", "tower", "vigil", "glory", "duel_streak", "peril_bosses", "valor", "set_full", "saga", "legend"]:  # найвище досягнуте, а не сума
		world.stats[stat] = maxi(int(world.stats.get(stat, 0)), amount)
	else:
		world.stats[stat] = int(world.stats.get(stat, 0)) + amount
		for list in [c["daily"], c["weekly"]]:
			for ch in list:
				if ch["stat"] == stat and int(ch["progress"]) < int(ch["goal"]):
					ch["progress"] = mini(int(ch["goal"]), int(ch["progress"]) + amount)
					if int(ch["progress"]) >= int(ch["goal"]):
						msgs.append("Виклик виконано: %s — забери нагороду!" % ch["text"])
	for a in A.achievements():
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
	var list: Array = state(world, player)["weekly" if weekly else "daily"]
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
	for r in Camp.resources():
		player.resources[r] = int(player.resources.get(r, 0)) + 2
	return "Нагорода дня: %d грн і ресурси" % (40 + 20 * lvl)


## player — поточний герой: якщо виклики саме складаються, вони мають бути під нього, а не навмання.
static func ready_count(world, player = null) -> int:
	var n := 0
	var c := state(world, player)
	for ch in c["daily"] + c["weekly"]:
		if can_claim(ch):
			n += 1
	return n


## Скільки лишилось до нових щоденних викликів (секунд).
static func seconds_to_reset() -> int:
	var t := _now()
	var d := Time.get_datetime_dict_from_unix_time(t)
	return 86400 - (int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"]))
