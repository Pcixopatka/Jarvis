extends RefCounted
## Логіка сюжету без інтерфейсу. Стан зберігається у world.story:
##   {"chapter", "step", "stage", "progress"}
## Етапи кроку: offer (чекає розмови в місті) → active (виконується мета) →
##             turnin (повернутися до того, хто дав) → наступний крок. "done" — сюжет завершено.

const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")


static func state(world) -> Dictionary:
	if world.story.is_empty():
		world.story = {"chapter": 0, "step": 0, "stage": "offer", "progress": 0}
		_skip_empty_start(world)
	return world.story


## Поточний крок або порожній словник, якщо сюжет завершено.
static func current(world) -> Dictionary:
	var s := state(world)
	if s["stage"] == "done":
		return {}
	return Story.CHAPTERS[s["chapter"]]["steps"][s["step"]]


static func chapter_title(world) -> String:
	var s := state(world)
	if s["stage"] == "done":
		return ""
	return Story.CHAPTERS[s["chapter"]]["title"]


static func _skip_empty_start(world) -> void:
	var st := current(world)
	if not st.is_empty() and world.story["stage"] == "offer" and st["start"].is_empty():
		world.story["stage"] = "active"


static func _count(st: Dictionary) -> int:
	return int(st["objective"].get("count", 1))


# ---------- Діалоги ----------

## Вступна розповідь поточного кроку (пролог): показується на початку нової гри.
static func intro(world) -> Array:
	return lines(world, current(world).get("intro", []))


## Чи гравець колись обрав такий варіант. cond: "id_кроку=номер_вибору".
static func chose(world, cond: String) -> bool:
	var parts := cond.split("=")
	if parts.size() != 2:
		return false
	return int(world.story.get("choices", {}).get(parts[0], -1)) == int(parts[1])


## Репліки, які має почути саме цей гравець (з урахуванням його минулих виборів).
static func lines(world, src: Array) -> Array:
	var out := []
	for l in src:
		if l.size() < 3 or chose(world, l[2]):
			out.append([l[0], l[1]])
	return out


static func _find_step(id: String) -> Dictionary:
	for ch in Story.CHAPTERS:
		for st in ch["steps"]:
			if st["id"] == id:
				return st
	return {}


## Постійні наслідки всіх зроблених виборів: {"discount_kyiv": 0.2, "potion_max": 1, ...}.
static func effects(world) -> Dictionary:
	var out := {}
	var made: Dictionary = world.story.get("choices", {})
	for id in made:
		var choices: Array = _find_step(id).get("choices", [])
		var ci := int(made[id])
		if ci < 0 or ci >= choices.size():
			continue
		var eff: Dictionary = choices[ci].get("effects", {})
		for k in eff:
			out[k] = out.get(k, 0.0) + float(eff[k])
	return out


static func effect(world, key: String) -> float:
	return float(effects(world).get(key, 0.0))


## «Літопис»: записи про зроблені вибори в порядку сюжету.
static func chronicle(world) -> Array:
	var out := []
	var made: Dictionary = world.story.get("choices", {})
	for ch in Story.CHAPTERS:
		for st in ch["steps"]:
			if not made.has(st["id"]):
				continue
			var choices: Array = st.get("choices", [])
			var ci := int(made[st["id"]])
			if ci >= 0 and ci < choices.size():
				out.append({"chapter": ch["title"], "text": choices[ci].get("memo", choices[ci]["text"])})
	return out


## Що сказати в цьому місті: {"kind": "start"/"end", "lines", "choices"} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	var s := state(world)
	var st := current(world)
	if st.is_empty():
		return {}
	if s["stage"] == "offer" and st["city"] == city:
		return {"kind": "start", "lines": lines(world, st["start"]), "choices": []}
	if s["stage"] == "turnin" and st["turn_in"] == city:
		return {"kind": "end", "lines": lines(world, st["end"]), "choices": st.get("choices", [])}
	return {}


## Викликається, коли гравець дочитав діалог. Повертає повідомлення для гравця.
static func on_dialogue_done(world, player, kind: String, choice: int = -1) -> Array:
	var s := state(world)
	if kind == "start":
		s["stage"] = "active"
		s["progress"] = 0
		return [{"text": "★ " + current(world)["objective"]["text"], "big": true}]
	if kind == "end" and s["stage"] == "turnin":
		return _complete(world, player, choice)
	return []


# ---------- Події гри ----------

## type: clear / dungeon / visit (arg = id місця) або kill (arg = вид ворога).
static func on_event(world, player, type: String, arg: String) -> Array:
	var s := state(world)
	if s["stage"] != "active":
		return []
	var st := current(world)
	var obj: Dictionary = st["objective"]
	var msgs := []
	var done := false
	match type:
		"clear", "dungeon", "visit":
			done = obj["type"] == type and obj["loc"] == arg
		"kill":
			if obj.get("enemy", "") == arg:
				if obj["type"] == "kill":
					s["progress"] += 1
				elif obj["type"] == "fetch" and randf() < float(obj.get("chance", 0.5)):
					s["progress"] += 1
					msgs.append({"text": "★ %s %d/%d" % [obj["item"], s["progress"], _count(st)], "big": false})
				done = s["progress"] >= _count(st)
	if not done:
		return msgs
	s["progress"] = _count(st)
	if st["turn_in"] == "":
		msgs.append({"text": "★ Виконано: %s" % obj["text"], "big": true})
		msgs.append_array(_complete(world, player, -1))
	else:
		s["stage"] = "turnin"
		msgs.append({"text": "★ Мету виконано!\nПовертайся: %s" % Data.place_name(st["turn_in"]), "big": true})
	return msgs


# ---------- Нагороди і перехід ----------

static func _complete(world, player, choice: int) -> Array:
	var st := current(world)
	var msgs := []
	_apply_reward(world, player, st.get("reward", {}), msgs)
	var choices: Array = st.get("choices", [])
	if choice >= 0 and choice < choices.size():
		_apply_reward(world, player, choices[choice].get("reward", {}), msgs)
		world.story["choices"] = world.story.get("choices", {})
		world.story["choices"][st["id"]] = choice
	for b in st.get("bonus", []):
		if chose(world, b["if"]):
			_apply_reward(world, player, b["reward"], msgs)
	_advance(world, msgs)
	return msgs


static func _advance(world, msgs: Array) -> void:
	var s: Dictionary = world.story
	var steps: Array = Story.CHAPTERS[s["chapter"]]["steps"]
	s["step"] += 1
	s["progress"] = 0
	s["stage"] = "offer"
	if s["step"] >= steps.size():
		msgs.append({"text": "%s — завершено!" % Story.CHAPTERS[s["chapter"]]["title"], "big": true})
		s["chapter"] += 1
		s["step"] = 0
		if s["chapter"] >= Story.CHAPTERS.size():
			s["stage"] = "done"
			return
	_skip_empty_start(world)


static func _apply_reward(world, player, r: Dictionary, msgs: Array) -> void:
	if r.has("rank"):
		player.rank = r["rank"]
		msgs.append({"text": "Ти — козак Запорозького війська!", "big": true})
	if r.has("skills"):
		for id in r["skills"]:
			player.skills[id] = maxi(player.sk(id), int(r["skills"][id]))
	if r.has("stats"):
		for id in r["stats"]:
			player.stats[id] = int(player.stats.get(id, 0)) + int(r["stats"][id])
		player.recalc()
	if r.has("gold"):
		player.gold += int(r["gold"])
	if r.has("xp"):
		player.add_xp(int(r["xp"]))
	if r.has("loyalty"):
		for city in r["loyalty"]:
			world.add_loyalty(city, int(r["loyalty"][city]))
	if r.has("item"):
		var d: Dictionary = r["item"]
		var it := Data.gen_item(int(d["ilvl"]), int(d["rarity"]), d["slot"], d.get("type", ""))
		it["name"] = d["name"]
		it["up"] = int(d.get("up", 0))
		if not player.add_item(it):
			player.inventory.append(it)  # сюжетну нагороду не губимо навіть із повною торбою
		msgs.append({"text": "Отримано: %s" % Data.item_title(it), "big": false})


# ---------- Для інтерфейсу ----------

## Рядок мети для списку завдань (із зіркою) або "".
static func objective_line(world) -> String:
	var s := state(world)
	var st := current(world)
	if st.is_empty():
		return ""
	match s["stage"]:
		"offer":
			return "★ Поговори: %s (%s)" % [Story.NPCS[st["giver"]]["name"], Data.place_name(st["city"])]
		"turnin":
			return "★ Повертайся: %s" % Data.place_name(st["turn_in"])
	var obj: Dictionary = st["objective"]
	var line: String = "★ " + obj["text"]
	if _count(st) > 1:
		line += " %d/%d" % [s["progress"], _count(st)]
	return line


## Куди зараз веде сюжет (id міста чи місцевості) — для зірки на мапі.
static func target(world) -> String:
	var s := state(world)
	var st := current(world)
	if st.is_empty():
		return ""
	match s["stage"]:
		"offer":
			return st["city"]
		"turnin":
			return st["turn_in"]
	return st["objective"]["loc"]
