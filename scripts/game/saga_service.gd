extends RefCounted
## «Попіл за вітром» (див. Saga, data/saga.json): продовження сюжету після Кремля. Що відкрито й що
## пройдено, вирішує QuestEngine (стан — world.missions): перший крок чекає на Кремль («after») і рівень
## лінії («min_level» у quest_lines.json), кожен наступний — на попередній. Ця служба веде розмови,
## нагороди й тексти кроків ліній виду «saga»; ратуша, журнал і мапа питають її через StoryService.

const Saga := preload("res://scripts/data/saga.gd")
const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")
const QuestEngine := preload("res://scripts/game/quest_engine.gd")


## Чи продовження вже пускає героя: рівень героя досить високий («min_level» лінії «saga») або його почато.
## Що головну історію пройдено, перевіряє рушій («after» першого кроку).
static func unlocked(world) -> bool:
	return QuestEngine.line_open(world, Saga.LINE)


static func finished(world) -> bool:
	return QuestEngine.line_finished(world, Saga.LINE)


## Нинішній крок ({} — продовження пройдено).
static func current(world) -> Dictionary:
	var id := QuestEngine.line_next(world, Saga.LINE)
	return QuestEngine.step(id) if id != "" else {}


## Етап нинішнього кроку: offer / active / turnin; "done" — пройдено.
static func stage(world) -> String:
	var st := current(world)
	if st.is_empty():
		return "done"
	var s := QuestEngine.stage(world, str(st["id"]))
	return s if s in ["active", "turnin"] else "offer"


static func title(world) -> String:
	var st := current(world)
	if st.is_empty():
		return ""
	return "%s. %s" % [Saga.title(), st["title"]]


## Що сказати в цьому місті: {"kind": "saga_start"/"saga_end", "lines": сирі репліки, "id"} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	for id in QuestEngine.missions_of(world, ["saga"]):
		var d := dialogue_of(world, id, city)
		if not d.is_empty():
			d["id"] = id
			return d
	return {}


## Розмова кроку саги id у цьому місті ({"kind", "lines"} або {}).
static func dialogue_of(world, id: String, city: String) -> Dictionary:
	var st := QuestEngine.step(id)
	if str(st.get("city", "")) != city:
		return {}
	match QuestEngine.stage(world, id):
		"offer":
			return {"kind": "saga_start", "lines": st["start"]}
		"turnin":
			return {"kind": "saga_end", "lines": st["end"]}
	return {}


## Розмову дочитано. Повертає повідомлення [{"text", "big"}]. id — крок розмови ("" — нинішній).
static func on_dialogue_done(world, player, kind: String, id: String = "") -> Array:
	if id == "":
		id = str(current(world).get("id", ""))
	if id == "" or QuestEngine.kind_of(id) != "saga":
		return []
	var st := QuestEngine.step(id)
	var s := QuestEngine.stage(world, id)
	if kind == "saga_start" and s == "offer":
		if int(world.cleared.get(str(st["objective"]["loc"]), 0)) > 0:
			# цього боса герой уже здолав: оповідач про це знає
			QuestEngine.set_stage(world, id, "turnin")
			return [{"text": "★ Цього ворога ти вже здолав.\nПоговори ще раз: %s" % Data.place_name(str(st["city"])), "big": true}]
		QuestEngine.start(world, id)
		return [{"text": "★ " + str(st["objective"]["text"]), "big": true}]
	if kind == "saga_end" and s == "turnin":
		return _complete(world, player, id)
	return []


## Мету кроку виконано (QuestEngine.on_event): повернутися до оповідача.
static func objective_met(world, _player, id: String) -> Array:
	QuestEngine.set_stage(world, id, "turnin")
	return [{"text": "★ Мету виконано!\nПовертайся: %s" % Data.place_name(str(QuestEngine.step(id)["city"])), "big": true}]


## Мета саги — бос, «принести» в неї не буває (GameDB.QUEST_OBJECTIVES); для повноти.
static func fetch_msg(_world, id: String) -> Dictionary:
	return {"text": "★ %s" % str(QuestEngine.step(id)["objective"]["text"]), "big": false}


static func _complete(world, player, id: String) -> Array:
	var st := QuestEngine.step(id)
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
	QuestEngine.complete(world, id)
	if QuestEngine.line_finished(world, Saga.LINE):
		msgs.append({"text": "Попіл розвіяно. Вітер над світом чистий!", "big": true})
	return msgs


## Рядок мети для журналу й мапи (із зіркою) або "": перша відкрита місія саги.
static func objective_line(world) -> String:
	for id in QuestEngine.missions_of(world, ["saga"]):
		return mission_line(world, id)
	return ""


## Рядок мети місії саги id (із зіркою).
static func mission_line(world, id: String) -> String:
	var st := QuestEngine.step(id)
	match QuestEngine.stage(world, id):
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
	for id in QuestEngine.missions_of(world, ["saga"]):
		return mission_target(world, id)
	return ""


## Куди веде місія саги id: до боса, коли мету почато, інакше до оповідача.
static func mission_target(world, id: String) -> String:
	var st := QuestEngine.step(id)
	return str(st["objective"]["loc"]) if QuestEngine.stage(world, id) == "active" else str(st["city"])


## Скільки кроків здано.
static func done_count(world) -> int:
	var n := 0
	for id in QuestEngine.line_steps(Saga.LINE):
		if QuestEngine.is_finished(world, id):
			n += 1
	return n
