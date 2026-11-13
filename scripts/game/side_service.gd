extends RefCounted
## Доручення (data/side.json, лінії виду «side» у quest_lines.json): місії поза історією, переказами й сагою.
## Крок має той самий вигляд, що й крок історії: хто дає й де, розмови на початку й наприкінці, мета, куди
## повертатися, нагорода, «after» і «min_level». Що відкрито й що пройдено, вирішує QuestEngine (стан —
## world.missions); ця служба веде розмови, нагороди й тексти кроків. Позначка — QuestEngine.mark (сьогодні «!»).
## Розмови показує Game._side_dialogue, ратуша — Game.hall_rows.

const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")
const QuestEngine := preload("res://scripts/game/quest_engine.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

## Види ліній, які журнал, ратуша й мапа показують як доручення.
const KINDS := ["side"]


## Відкриті доручення в порядку рушія.
static func missions(world) -> Array:
	return QuestEngine.missions_of(world, KINDS)


static func _count(st: Dictionary) -> int:
	return int(st["objective"].get("count", 1))


## Усі розмови доручень, що чекають у цьому місті: [{"kind": "side_start"/"side_end", "lines", "id"}].
## Спершу кінцеві (нагорода чекає), потім нові.
static func city_dialogues(world, city: String) -> Array:
	var out := []
	for want in ["turnin", "offer"]:
		for id in missions(world):
			if QuestEngine.stage(world, id) != want:
				continue
			var d := dialogue_of(world, id, city)
			if not d.is_empty():
				out.append({"kind": d["kind"], "lines": d["lines"], "id": id})
	return out


## Розмова доручення id у цьому місті ({"kind", "lines"} або {}).
static func dialogue_of(world, id: String, city: String) -> Dictionary:
	var st := QuestEngine.step(id)
	match QuestEngine.stage(world, id):
		"offer":
			if str(st.get("city", "")) == city:
				return {"kind": "side_start", "lines": st["start"]}
		"turnin":
			if str(st.get("turn_in", "")) == city:
				return {"kind": "side_end", "lines": st["end"]}
	return {}


## Розмова в цьому місті: перша з усіх або саме доручення id ({} — нема).
static func city_dialogue(world, city: String, id: String = "") -> Dictionary:
	for d in city_dialogues(world, city):
		if id == "" or str(d["id"]) == id:
			return d
	return {}


## Розмову дочитано. Повертає повідомлення [{"text", "big"}].
static func on_dialogue_done(world, player, kind: String, id: String) -> Array:
	if QuestEngine.kind_of(id) != "side":
		return []
	var st := QuestEngine.step(id)
	var s := QuestEngine.stage(world, id)
	if kind == "side_start" and s == "offer":
		QuestEngine.start(world, id)
		var msgs := [{"text": "%s %s" % [QuestEngine.mark(id), st["objective"]["text"]], "big": true}]
		msgs.append_array(QuestEngine.check_stat(world, player, id))  # «найвищого» міг досягти ще до доручення
		return msgs
	if kind == "side_end" and s == "turnin":
		return _complete(world, player, id)
	return []


## Мету «принести» поповнено (QuestEngine.on_event).
static func fetch_msg(world, id: String) -> Dictionary:
	var st := QuestEngine.step(id)
	return {"text": "%s %s %d/%d" % [QuestEngine.mark(id), st["objective"]["item"], mini(QuestEngine.progress(world, id), _count(st)), _count(st)], "big": false}


## Мету виконано: повернутися до того, хто дав, або (без «turn_in») здати одразу.
static func objective_met(world, player, id: String) -> Array:
	var st := QuestEngine.step(id)
	if str(st.get("turn_in", "")) == "":
		var msgs := [{"text": "%s Виконано: %s" % [QuestEngine.mark(id), st["objective"]["text"]], "big": true}]
		msgs.append_array(_complete(world, player, id))
		return msgs
	QuestEngine.set_stage(world, id, "turnin")
	return [{"text": "%s Доручення: мету виконано!\nПовертайся: %s" % [QuestEngine.mark(id), Data.place_name(str(st["turn_in"]))], "big": true}]


## Нагорода словами (журнал).
static func reward_text(st: Dictionary) -> String:
	var r: Dictionary = st.get("reward", {})
	var parts := []
	if r.has("gold"):
		parts.append("%d грн" % int(r["gold"]))
	if r.has("xp"):
		parts.append("досвіду %d" % int(r["xp"]))
	if r.has("trophy"):
		parts.append("%d трофеїв" % int(r["trophy"]))
	for res in r.get("res", {}):
		parts.append("%s: %d" % [Camp.res_name(res).to_lower(), int(r["res"][res])])
	if r.has("item"):
		parts.append("«%s»" % str(r["item"]["name"]))
	return ", ".join(parts)


static func _complete(world, player, id: String) -> Array:
	var st := QuestEngine.step(id)
	var r: Dictionary = st.get("reward", {})
	var msgs := [{"text": "Доручення «%s» виконано!" % QuestEngine.title(id), "big": true}]
	var parts := []
	if r.has("gold"):
		player.gold += int(r["gold"])
		parts.append("+%d грн" % int(r["gold"]))
	if r.has("trophy"):
		player.resources["trophy"] = int(player.resources.get("trophy", 0)) + int(r["trophy"])
		parts.append("+%d трофеїв" % int(r["trophy"]))
	for res in r.get("res", {}):  # ресурси й провіант: дерево, трави, м'ясо, риба...
		player.resources[res] = int(player.resources.get(res, 0)) + int(r["res"][res])
		parts.append("%s +%d" % [Camp.res_name(res).to_lower(), int(r["res"][res])])
	if not parts.is_empty():
		msgs.append({"text": ", ".join(parts), "big": false})
	if r.has("loyalty"):
		for city in r["loyalty"]:
			world.add_loyalty(city, int(r["loyalty"][city]))
	if r.has("item"):
		var d: Dictionary = r["item"]
		var it := Data.gen_item(int(d["ilvl"]), int(d["rarity"]), d["slot"], d.get("type", ""))
		it["name"] = d["name"]
		it["up"] = int(d.get("up", 0))
		if not player.add_item(it):
			player.inventory.append(it)  # нагороду доручення не губимо навіть із повною торбою
		msgs.append({"text": "Отримано: %s" % Data.item_title(it), "big": false})
	QuestEngine.complete(world, id)
	if r.has("xp"):
		player.add_xp(int(r["xp"]))  # досвід — останнім: новий рівень може відкрити наступну місію
	return msgs


## Рядок мети доручення id (з позначкою).
static func mission_line(world, id: String) -> String:
	var st := QuestEngine.step(id)
	var m := QuestEngine.mark(id)
	match QuestEngine.stage(world, id):
		"offer":
			return "%s Поговори: %s (%s)" % [m, Story.npc_name(st["giver"]), Data.place_name(str(st["city"]))]
		"turnin":
			return "%s Повертайся: %s" % [m, Data.place_name(str(st["turn_in"]))]
	var text: String = "%s %s" % [m, st["objective"]["text"]]
	if _count(st) > 1:
		text += " %d/%d" % [QuestEngine.progress(world, id), _count(st)]
	return text


## Куди веде доручення id: до того, хто дає, до мети (місце «loc», якщо є) чи туди, де здати.
static func mission_target(world, id: String) -> String:
	var st := QuestEngine.step(id)
	match QuestEngine.stage(world, id):
		"offer":
			return str(st["city"])
		"turnin":
			return str(st["turn_in"])
	return str(st["objective"].get("loc", ""))


## Рядки для журналу: [{"id", "title", "text", "target", "back", "reward"}].
static func rows(world) -> Array:
	var out := []
	for id in missions(world):
		var st := QuestEngine.step(id)
		out.append({"id": id, "title": QuestEngine.title(id), "text": mission_line(world, id), "target": mission_target(world, id),
			"back": QuestEngine.stage(world, id) == "turnin", "reward": reward_text(st)})
	return out
