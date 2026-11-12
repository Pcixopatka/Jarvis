extends RefCounted
## «Попіл за вітром» (див. Saga, data/saga.json): продовження сюжету після Кремля. Стан — world.saga:
## {"step": номер кроку, "stage": "offer" (піти до оповідача) / "active" (іти на боса) /
## "turnin" (повернутися) / "done"}. Розмови, зірку на мапі й рядок у журналі показує StoryService:
## коли головний сюжет завершено, він питає цю службу.

const Saga := preload("res://scripts/data/saga.gd")
const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")


static func state(world) -> Dictionary:
	if world.saga.is_empty():
		world.saga = {"step": 0, "stage": "offer"}
	return world.saga


## Чи відкрите продовження: рівень героя досить високий («min_level» лінії «saga» в quest_lines.json).
## Що головну історію пройдено («after» лінії), перевіряє StoryService: до її кінця він сюди не питає.
static func unlocked(world) -> bool:
	return int(world.hero_level) >= Saga.min_level() or int(state(world)["step"]) > 0 or str(state(world)["stage"]) != "offer"


static func finished(world) -> bool:
	return str(state(world)["stage"]) == "done"


static func current(world) -> Dictionary:
	var s := state(world)
	if s["stage"] == "done" or int(s["step"]) >= Saga.steps().size():
		return {}
	return Saga.steps()[int(s["step"])]


static func title(world) -> String:
	var st := current(world)
	if st.is_empty():
		return ""
	return "%s. %s" % [Saga.title(), st["title"]]


## Що сказати в цьому місті: {"kind": "saga_start"/"saga_end", "lines": сирі репліки} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	if not unlocked(world):
		return {}
	var s := state(world)
	var st := current(world)
	if st.is_empty() or str(st["city"]) != city:
		return {}
	if s["stage"] == "offer":
		return {"kind": "saga_start", "lines": st["start"]}
	if s["stage"] == "turnin":
		return {"kind": "saga_end", "lines": st["end"]}
	return {}


## Розмову дочитано. Повертає повідомлення [{"text", "big"}].
static func on_dialogue_done(world, player, kind: String) -> Array:
	var s := state(world)
	var st := current(world)
	if st.is_empty():
		return []
	if kind == "saga_start" and s["stage"] == "offer":
		if int(world.cleared.get(str(st["objective"]["loc"]), 0)) > 0:
			# цього боса герой уже здолав: оповідач про це знає
			s["stage"] = "turnin"
			return [{"text": "★ Цього ворога ти вже здолав.\nПоговори ще раз: %s" % Data.place_name(str(st["city"])), "big": true}]
		s["stage"] = "active"
		return [{"text": "★ " + str(st["objective"]["text"]), "big": true}]
	if kind == "saga_end" and s["stage"] == "turnin":
		return _complete(world, player)
	return []


## Подія гри: пройдено печеру loc.
static func on_event(world, type: String, arg: String) -> Array:
	var s := state(world)
	var st := current(world)
	if st.is_empty() or s["stage"] != "active" or type != "dungeon" or str(st["objective"]["loc"]) != arg:
		return []
	s["stage"] = "turnin"
	return [{"text": "★ Мету виконано!\nПовертайся: %s" % Data.place_name(str(st["city"])), "big": true}]


static func _complete(world, player) -> Array:
	var s := state(world)
	var st := current(world)
	var msgs := []
	var r: Dictionary = st.get("reward", {})
	var parts := []
	if r.has("gold"):
		player.gold += int(r["gold"])
		parts.append("+%d грн" % int(r["gold"]))
	if r.has("trophy"):
		player.resources["trophy"] = int(player.resources.get("trophy", 0)) + int(r["trophy"])
		parts.append("+%d трофеїв" % int(r["trophy"]))
	if r.has("xp"):
		player.add_xp(int(r["xp"]))
	if not parts.is_empty():
		msgs.append({"text": ", ".join(parts), "big": false})
	if r.has("item"):
		var d: Dictionary = r["item"]
		var it := Data.gen_item(int(d["ilvl"]), int(d["rarity"]), d["slot"], d.get("type", ""))
		it["name"] = d["name"]
		it["up"] = int(d.get("up", 0))
		if not player.add_item(it):
			player.inventory.append(it)  # сюжетну нагороду не губимо навіть із повною торбою
		msgs.append({"text": "Отримано: %s" % Data.item_title(it), "big": false})
	msgs.push_front({"text": "%s: «%s» завершено!" % [Saga.title(), st["title"]], "big": true})
	s["step"] = int(s["step"]) + 1
	s["stage"] = "offer"
	if int(s["step"]) >= Saga.steps().size():
		s["stage"] = "done"
		msgs.append({"text": "Попіл розвіяно. Вітер над світом чистий!", "big": true})
	return msgs


## Рядок мети для журналу й мапи (із зіркою) або "".
static func objective_line(world) -> String:
	if finished(world) or not unlocked(world):
		return ""
	var s := state(world)
	var st := current(world)
	match str(s["stage"]):
		"offer":
			return "★ Поговори: %s (%s)" % [Story.npc_name(st["giver"]), Data.place_name(str(st["city"]))]
		"turnin":
			return "★ Повертайся: %s" % Data.place_name(str(st["city"]))
	return "★ " + str(st["objective"]["text"])


## Примітка для журналу, поки продовження ще закрите ("" — уже відкрите чи пройдене).
static func teaser(world) -> String:
	if finished(world) or unlocked(world):
		return ""
	return "Історія триває: «%s» відкриється з %d-го рівня героя." % [Saga.title(), Saga.min_level()]


## Куди веде продовження (id міста чи печери) — для зірки на мапі.
static func target(world) -> String:
	if finished(world) or not unlocked(world):
		return ""
	var s := state(world)
	var st := current(world)
	return str(st["objective"]["loc"]) if s["stage"] == "active" else str(st["city"])


## Скільки кроків пройдено.
static func done_count(world) -> int:
	return Saga.steps().size() if finished(world) else int(state(world)["step"])
