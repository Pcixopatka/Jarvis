extends RefCounted
## Перекази (див. Legends): квестові лінійки за легендами земель. Стан у героя свій —
## world.legends = {id лінійки: {"step": номер кроку, "stage": "offer" (піти до оповідача) /
## "active" (виконати мету) / "turnin" (повернутися) / "done", "progress": скільки вже здобуто}}.
## Лінійки незалежні: герой веде кілька одразу. Розмови показує Game._legend_dialogue.

const Legends := preload("res://scripts/data/legends.gd")
const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")


static func state(world, line: String) -> Dictionary:
	if not world.legends.has(line):
		world.legends[line] = {"step": 0, "stage": "offer", "progress": 0}
	return world.legends[line]


static func started(world, line: String) -> bool:
	if not world.legends.has(line):
		return false
	var s: Dictionary = world.legends[line]
	return int(s["step"]) > 0 or str(s["stage"]) != "offer"


## Чи лінійка вже доступна героєві: рівень дозволяє або її вже почато.
static func unlocked(world, line: String) -> bool:
	return Legends.LINES.has(line) and (int(world.hero_level) >= int(Legends.LINES[line]["min_level"]) or started(world, line))


static func finished(world, line: String) -> bool:
	return world.legends.has(line) and str(world.legends[line]["stage"]) == "done"


## Нинішній крок лінійки ({} — лінійку пройдено).
static func current(world, line: String) -> Dictionary:
	var s := state(world, line)
	var steps: Array = Legends.LINES[line]["steps"]
	if s["stage"] == "done" or int(s["step"]) >= steps.size():
		return {}
	return steps[int(s["step"])]


static func _count(st: Dictionary) -> int:
	return int(st["objective"].get("count", 1))


## Усі розмови переказів, що чекають у цьому місті: [{"kind": "legend_start"/"legend_end", "line", "lines"}].
## Спершу кінцеві (нагорода чекає), потім нові. Самі вони не починаються: герой підходить у ратуші.
static func city_dialogues(world, city: String) -> Array:
	var out := []
	for want in ["turnin", "offer"]:
		for line in Legends.ORDER:
			if not unlocked(world, line) or finished(world, line):
				continue
			var s := state(world, line)
			var st := current(world, line)
			if st.is_empty() or str(st["city"]) != city or str(s["stage"]) != want:
				continue
			out.append({"kind": "legend_end" if want == "turnin" else "legend_start", "line": line, "lines": st["end"] if want == "turnin" else st["start"]})
	return out


## Розмова в цьому місті: перша з усіх або саме лінійки line ({} — нема).
static func city_dialogue(world, city: String, line: String = "") -> Dictionary:
	for d in city_dialogues(world, city):
		if line == "" or str(d["line"]) == line:
			return d
	return {}


## Розмову дочитано. Повертає повідомлення [{"text", "big"}].
static func on_dialogue_done(world, player, kind: String, line: String) -> Array:
	if not Legends.LINES.has(line):
		return []
	var s := state(world, line)
	var st := current(world, line)
	if st.is_empty():
		return []
	if kind == "legend_start" and s["stage"] == "offer":
		s["stage"] = "active"
		s["progress"] = 0
		return [{"text": "✦ %s\n%s" % [Legends.LINES[line]["title"], st["objective"]["text"]], "big": true}]
	if kind == "legend_end" and s["stage"] == "turnin":
		return _complete(world, player, line)
	return []


## Подія гри: type — clear / dungeon (arg = id місця) або kill (arg = вид ворога).
static func on_event(world, _player, type: String, arg: String) -> Array:
	var msgs := []
	for line in Legends.ORDER:
		if not world.legends.has(line):
			continue
		var s: Dictionary = world.legends[line]
		if str(s["stage"]) != "active":
			continue
		var st := current(world, line)
		if st.is_empty():
			continue
		var obj: Dictionary = st["objective"]
		var done := false
		match type:
			"clear", "dungeon":
				done = str(obj["type"]) == type and str(obj["loc"]) == arg
			"kill":
				if str(obj.get("enemy", "")) == arg:
					if str(obj["type"]) == "kill":
						s["progress"] = int(s["progress"]) + 1
					elif str(obj["type"]) == "fetch" and randf() < float(obj.get("chance", 0.5)):
						s["progress"] = int(s["progress"]) + 1
						msgs.append({"text": "✦ %s %d/%d" % [obj["item"], mini(int(s["progress"]), _count(st)), _count(st)], "big": false})
					done = str(obj["type"]) in ["kill", "fetch"] and int(s["progress"]) >= _count(st)
		if done:
			s["progress"] = _count(st)
			s["stage"] = "turnin"
			msgs.append({"text": "✦ Переказ: мету виконано!\nПовертайся: %s" % Data.place_name(str(st["city"])), "big": true})
	return msgs


## Нагорода кроку словами (для довідника й журналу).
static func reward_text(st: Dictionary, level: int = 0) -> String:
	var r: Dictionary = st.get("reward", {})
	var parts := []
	if r.has("gold_lvl"):
		parts.append(("%d грн" % (int(r["gold_lvl"]) * level)) if level > 0 else ("%d грн за рівень героя" % int(r["gold_lvl"])))
	if r.has("trophy"):
		parts.append("%d трофеїв" % int(r["trophy"]))
	if r.has("item"):
		parts.append("«%s»" % str(r["item"]["name"]))
	return ", ".join(parts)


static func _complete(world, player, line: String) -> Array:
	var s := state(world, line)
	var st := current(world, line)
	var L: Dictionary = Legends.LINES[line]
	var msgs := []
	var r: Dictionary = st.get("reward", {})
	var parts := []
	if r.has("gold_lvl"):
		var g: int = int(r["gold_lvl"]) * int(player.level)
		player.gold += g
		parts.append("+%d грн" % g)
	if r.has("trophy"):
		player.resources["trophy"] = int(player.resources.get("trophy", 0)) + int(r["trophy"])
		parts.append("+%d трофеїв" % int(r["trophy"]))
	msgs.append({"text": "Переказ «%s»: «%s» завершено!" % [L["title"], st["title"]], "big": true})
	if not parts.is_empty():
		msgs.append({"text": ", ".join(parts), "big": false})
	if r.has("item"):
		var d: Dictionary = r["item"]
		var it := Data.gen_item(int(player.level), int(d["rarity"]), d["slot"], d.get("type", ""))
		it["name"] = d["name"]
		it["up"] = int(d.get("up", 0))
		if not player.add_item(it):
			player.inventory.append(it)  # нагороду переказу не губимо навіть із повною торбою
		msgs.append({"text": "Отримано: %s" % Data.item_title(it), "big": false})
	s["step"] = int(s["step"]) + 1
	s["stage"] = "offer"
	s["progress"] = 0
	if int(s["step"]) >= L["steps"].size():
		s["stage"] = "done"
		msgs.append({"text": "Переказ «%s» розказано до кінця!" % L["title"], "big": true})
	return msgs


## Куди веде крок: id міста чи місця ("" — нікуди).
static func target(world, line: String) -> String:
	if not unlocked(world, line) or finished(world, line):
		return ""
	var s := state(world, line)
	var st := current(world, line)
	if st.is_empty():
		return ""
	return str(st["objective"].get("loc", "")) if s["stage"] == "active" else str(st["city"])


## Усі місця, куди зараз ведуть перекази (для позначок на мапі).
static func targets(world) -> Array:
	var out := []
	for line in Legends.ORDER:
		var t := target(world, line)
		if t != "" and not t in out:
			out.append(t)
	return out


## Рядок мети лінійки словами.
static func objective_text(world, line: String) -> String:
	var s := state(world, line)
	var st := current(world, line)
	if st.is_empty():
		return ""
	match str(s["stage"]):
		"offer":
			return "Поговори: %s (%s)" % [Story.NPCS[st["giver"]]["name"], Data.place_name(str(st["city"]))]
		"turnin":
			return "Повертайся: %s" % Data.place_name(str(st["city"]))
	var text: String = str(st["objective"]["text"])
	if _count(st) > 1:
		text += " %d/%d" % [int(s["progress"]), _count(st)]
	return text


## Рядки для журналу: [{"line", "title", "text", "target", "back": чи час повертатися, "reward"}].
static func rows(world) -> Array:
	var out := []
	for line in Legends.ORDER:
		if not unlocked(world, line) or finished(world, line):
			continue
		var st := current(world, line)
		if st.is_empty():
			continue
		out.append({"line": line, "title": "%s. %s" % [Legends.LINES[line]["title"], st["title"]], "text": objective_text(world, line),
			"target": target(world, line), "back": str(state(world, line)["stage"]) == "turnin", "reward": reward_text(st, int(world.hero_level))})
	return out


## Скільки лінійок пройдено до кінця.
static func done_count(world) -> int:
	var n := 0
	for line in Legends.ORDER:
		if finished(world, line):
			n += 1
	return n


## Нечисть у місці, куди зараз веде переказ, міряється рівнем із героєм: стара печера не стає прогулянкою.
static func mods_for(world, player, loc_id: String) -> Dictionary:
	if not Data.LOCATIONS.has(loc_id):
		return {}
	var base: int = int(Data.LOCATIONS[loc_id]["level"])
	if int(player.level) <= base:
		return {}
	for line in Legends.ORDER:
		if not world.legends.has(line) or str(world.legends[line]["stage"]) != "active":
			continue
		var st := current(world, line)
		if not st.is_empty() and str(st["objective"].get("loc", "")) == loc_id:
			return {"level": int(player.level), "hero_level": int(player.level), "base_level": base, "legend": line}
	return {}
