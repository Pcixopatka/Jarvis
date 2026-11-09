extends RefCounted
## Щоденні й тижневі виклики та досягнення. Усе живиться одним лічильником подій record().
## Стан: world.stats {лічильник: значення} і world.challenges:
##   {"day": "2026-11-09", "week": "2026-W45", "daily": [...], "weekly": [...], "ach": {id: true}}
## Виклик: {"stat", "text", "goal", "progress", "claimed"}.

const A := preload("res://scripts/data/achievements.gd")
const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

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


static func state(world) -> Dictionary:
	var c: Dictionary = world.challenges
	var t := _now()
	if c.get("day", "") != day_key(t):
		c["day"] = day_key(t)
		c["daily"] = _generate(A.DAILY, A.DAILY_COUNT, hash(c["day"]))
	if c.get("week", "") != week_key(t):
		c["week"] = week_key(t)
		c["weekly"] = _generate(A.WEEKLY, A.WEEKLY_COUNT, hash(c["week"]))
	if not c.has("ach"):
		c["ach"] = {}
	return c


static func _generate(templates: Array, n: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var idx := range(templates.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var out := []
	for i in mini(n, idx.size()):
		var t: Dictionary = templates[idx[i]]
		var goal := rng.randi_range(int(t["goal"][0]), int(t["goal"][1]))
		out.append({"stat": t["stat"], "text": t["text"] % goal if "%d" in t["text"] else t["text"], "goal": goal, "progress": 0, "claimed": false})
	return out


## Подія в грі: збільшує лічильники, просуває виклики, відкриває досягнення.
## stat "level" — це не сума, а найвищий рівень. Повертає повідомлення для банера.
static func record(world, player, stat: String, amount: int = 1) -> Array:
	var c := state(world)
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
