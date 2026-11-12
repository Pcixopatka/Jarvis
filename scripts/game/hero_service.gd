extends RefCounted
## Побратими без інтерфейсу. Стан — world.heroes:
##   {id: {"met": bool, "bond": int, "quest": "none"/"offer"/"active"/"turnin"/"done", "progress": int}}
## Запис у загоні (world.companions) має поле "hero": id — так побратим відрізняється від найманця.
## Самі побратими (ім'я, сила, розмови, особисте завдання) — у data/heroes.json (див. docs/data.md).

const GameDB := preload("res://scripts/core/game_db.gd")
const StoryService := preload("res://scripts/game/story_service.gd")


## Запис побратима (лише для читання); для невідомого id — порожній.
static func info(id: String) -> Dictionary:
	return GameDB.hero(id)


static func st(world, id: String) -> Dictionary:
	if not world.heroes.has(id):
		world.heroes[id] = {"met": false, "bond": 0, "quest": "none", "progress": 0}
	return world.heroes[id]


static func in_party(world, id: String) -> bool:
	for c in world.companions:
		if c.get("hero", "") == id:
			return true
	return false


## Ім'я учасника загону: побратима — на ймення, найманця — за родом служби.
static func member_name(c: Dictionary) -> String:
	var h := info(c.get("hero", ""))
	return h["name"] if not h.is_empty() else GameDB.companion(c["type"])["name"]


## Наскільки побратим сильніший за звичайного найманця того ж типу.
static func power(world, id: String) -> float:
	var h := info(id)
	if h.is_empty():
		return 1.0
	return float(h["bonded"]) if st(world, id)["quest"] == "done" else float(h["mult"])


static func _step_done(world, step_id: String) -> bool:
	var s := StoryService.state(world)
	if s["stage"] == "done":
		return true
	var Story = StoryService.Story
	for ci in Story.CHAPTERS.size():
		var steps: Array = Story.CHAPTERS[ci]["steps"]
		for si in steps.size():
			if steps[si]["id"] == step_id:
				return ci < int(s["chapter"]) or (ci == int(s["chapter"]) and si < int(s["step"]))
	return false


## Хто чекає на зустріч у цьому місті.
static func can_meet(world, id: String, city: String) -> bool:
	var h := info(id)
	var j: Dictionary = h["join"]
	if st(world, id)["met"] or j["city"] != city or not _step_done(world, j["after"]):
		return false
	return not j.has("if") or StoryService.chose(world, j["if"])


## Розмова, яка чекає в місті: {"hero", "kind": "meet"/"quest"/"end", "lines", "choices"} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	for id in GameDB.hero_ids():
		var h: Dictionary = info(id)
		var s := st(world, id)
		if can_meet(world, id, city):
			return {"hero": id, "kind": "meet", "lines": h["meet"], "choices": [
				{"text": "Ходімо разом!", "reply": "Не пошкодуєш, козаче."},
				{"text": "Поки що чекай у корчмі.", "reply": "Знайдеш мене в будь-якій корчмі. Тільки довго не барись."},
			]}
		if not in_party(world, id):
			continue
		if s["quest"] == "none" and s["bond"] >= int(h["quest_bond"]):
			s["quest"] = "offer"
		if s["quest"] == "offer":
			return {"hero": id, "kind": "quest", "lines": h["quest"]["start"], "choices": []}
		if s["quest"] == "turnin":
			return {"hero": id, "kind": "end", "lines": h["quest"]["end"], "choices": []}
	return {}


## Козак дочитав розмову з побратимом. Повертає повідомлення.
static func on_dialogue_done(world, player, d: Dictionary, choice: int) -> Array:
	var id: String = d["hero"]
	var h := info(id)
	var s := st(world, id)
	match d["kind"]:
		"meet":
			s["met"] = true
			if choice == 0:
				return join(world, player, id)
			return [{"text": "%s чекає в корчмі" % h["name"], "big": false}]
		"quest":
			s["quest"] = "active"
			s["progress"] = 0
			return [{"text": "✦ " + h["quest"]["objective"]["text"], "big": true}]
		"end":
			s["quest"] = "done"
			return [{"text": "%s — побратим навіки! Сили побратима зросли" % h["name"], "big": true}]
	return []


## Узяти в загін (з корчми чи одразу при зустрічі). Безкоштовно — побратими йдуть не за гроші.
static func join(world, player, id: String) -> Array:
	var h := info(id)
	if in_party(world, id):
		return []
	if world.companions.size() >= load("res://scripts/game/camp_service.gd").party_size(world):
		return [{"text": "Загін повний — %s чекає в корчмі" % h["name"], "big": false}]
	var m: Dictionary = load("res://scripts/game/party.gd").new_member(h["base"], player.level)
	m["hero"] = id
	m["level"] = maxi(1, player.level - 1)
	world.companions.append(m)
	return [{"text": "%s приєднується до загону!" % h["name"], "big": true}]


## Побратими, яких уже зустріли, але вони не в загоні (для корчми).
static func waiting(world) -> Array:
	var out := []
	for id in GameDB.hero_ids():
		if st(world, id)["met"] and not in_party(world, id):
			out.append(id)
	return out


## Перемога над ворогом: дружба росте з кожним, хто був поруч; і прогрес особистих завдань.
static func on_event(world, type: String, arg: String) -> Array:
	var msgs := []
	for c in world.companions:
		var id: String = c.get("hero", "")
		if id == "":
			continue
		var s := st(world, id)
		if type == "kill" and not c.get("downed", false) and c.get("away", {}).is_empty():
			s["bond"] = int(s["bond"]) + 1  # дружба росте лише в спільному бою, не у власному поході побратима
		if s["quest"] != "active":
			continue
		var obj: Dictionary = info(id)["quest"]["objective"]
		var cnt := int(obj.get("count", 1))
		var done := false
		match type:
			"clear", "dungeon":
				done = obj["type"] == type and obj["loc"] == arg
			"kill":
				if obj.get("enemy", "") == arg:
					if obj["type"] == "kill":
						s["progress"] = int(s["progress"]) + 1
					elif obj["type"] == "fetch" and randf() < float(obj.get("chance", 0.5)):
						s["progress"] = int(s["progress"]) + 1
						msgs.append({"text": "✦ %s %d/%d" % [obj["item"], s["progress"], cnt], "big": false})
					done = int(s["progress"]) >= cnt
		if done:
			s["progress"] = cnt
			s["quest"] = "turnin"
			msgs.append({"text": "✦ %s: мету виконано!\nПоговоріть у будь-якому місті" % info(id)["name"], "big": true})
	return msgs


## Рядки особистих завдань для списку цілей.
static func objective_lines(world) -> Array:
	var out := []
	for id in GameDB.hero_ids():
		var s := st(world, id)
		if not in_party(world, id):
			continue
		var h: Dictionary = info(id)
		match s["quest"]:
			"active":
				var obj: Dictionary = h["quest"]["objective"]
				var line: String = "✦ " + obj["text"]
				if int(obj.get("count", 1)) > 1:
					line += " %d/%d" % [s["progress"], obj["count"]]
				out.append(line)
			"turnin":
				out.append("✦ %s: поговори в місті" % h["name"])
	return out


## Куди веде особисте завдання (для позначки на мапі) — перша активна мета.
static func targets(world) -> Array:
	var out := []
	for id in GameDB.hero_ids():
		if in_party(world, id) and st(world, id)["quest"] == "active":
			out.append(info(id)["quest"]["objective"]["loc"])
	return out
