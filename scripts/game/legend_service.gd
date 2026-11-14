extends RefCounted
## Перекази (див. Legends, data/quest_lines.json і data/legend_steps.json): квестові лінійки за легендами земель.
## Що відкрито й що пройдено, вирішує QuestEngine (стан — world.missions). Кожен переказ — ланка сюжетного
## ланцюжка («story» лінії, зірка): його перший крок чекає на останній крок попередньої ланки («after») і
## рівня героя («min_level»), наступні — на попередній крок лінійки, а на останній чекає наступна ланка.
## Ця служба веде розмови, нагороди й тексти кроків ліній виду «legend». Розмови показує Game._legend_dialogue.

const Legends := preload("res://scripts/data/legends.gd")
const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")
const QuestEngine := preload("res://scripts/game/quest_engine.gd")

## Види ліній, які журнал, ратуша й мапа показують як перекази.
const KINDS := ["legend"]


## Відкриті місії переказів у порядку рушія (лінійки в порядку показу).
static func missions(world) -> Array:
	return QuestEngine.missions_of(world, KINDS)


static func started(world, line: String) -> bool:
	return Legends.has_line(line) and QuestEngine.line_started(world, line)


## Чи лінійка вже доступна героєві: рівень дозволяє або її вже почато.
static func unlocked(world, line: String) -> bool:
	return Legends.has_line(line) and QuestEngine.line_open(world, line)


static func finished(world, line: String) -> bool:
	return Legends.has_line(line) and QuestEngine.line_finished(world, line)


## Нинішній крок лінійки ({} — лінійку пройдено).
static func current(world, line: String) -> Dictionary:
	var id := QuestEngine.line_next(world, line) if Legends.has_line(line) else ""
	return QuestEngine.step(id) if id != "" else {}


## Етап нинішнього кроку лінійки: offer / active / turnin; "done" — пройдено.
static func stage(world, line: String) -> String:
	var st := current(world, line)
	if st.is_empty():
		return "done"
	var s := QuestEngine.stage(world, str(st["id"]))
	return s if s in ["active", "turnin"] else "offer"


static func _count(st: Dictionary) -> int:
	return int(st["objective"].get("count", 1))


## Усі розмови переказів, що чекають у цьому місті: [{"kind": "legend_start"/"legend_end", "line", "lines", "id"}].
## Спершу кінцеві (нагорода чекає), потім нові. Самі вони не починаються: герой підходить у ратуші.
static func city_dialogues(world, city: String) -> Array:
	var out := []
	for want in ["turnin", "offer"]:
		for id in missions(world):
			if QuestEngine.stage(world, id) != want:
				continue
			var d := dialogue_of(world, id, city)
			if not d.is_empty():
				out.append({"kind": d["kind"], "line": QuestEngine.line_of(id), "lines": d["lines"], "id": id})
	return out


## Розмова кроку переказу id у цьому місті ({"kind", "lines"} або {}).
static func dialogue_of(world, id: String, city: String) -> Dictionary:
	var st := QuestEngine.step(id)
	if str(st.get("city", "")) != city:
		return {}
	match QuestEngine.stage(world, id):
		"offer":
			return {"kind": "legend_start", "lines": st["start"]}
		"turnin":
			return {"kind": "legend_end", "lines": st["end"]}
	return {}


## Розмова в цьому місті: перша з усіх або саме лінійки line ({} — нема).
static func city_dialogue(world, city: String, line: String = "") -> Dictionary:
	for d in city_dialogues(world, city):
		if line == "" or str(d["line"]) == line:
			return d
	return {}


## Розмову дочитано. Повертає повідомлення [{"text", "big"}]. id — крок розмови ("" — нинішній крок лінійки).
static func on_dialogue_done(world, player, kind: String, line: String, id: String = "") -> Array:
	if not Legends.has_line(line):
		return []
	if id == "":
		id = str(current(world, line).get("id", ""))
	if id == "" or QuestEngine.line_of(id) != line:
		return []
	var st := QuestEngine.step(id)
	var s := QuestEngine.stage(world, id)
	if kind == "legend_start" and s in ["offer", "level"]:
		QuestEngine.start(world, id)
		return [{"text": "✦ %s\n%s" % [Legends.line(line)["title"], st["objective"]["text"]], "big": true}]
	if kind == "legend_end" and s == "turnin":
		return _complete(world, player, id)
	return []


## Подія гри для переказів. Усі лінії разом — QuestEngine.on_event.
## type — clear / dungeon (arg = id місця) або kill (arg = вид ворога).
static func on_event(world, player, type: String, arg: String) -> Array:
	return QuestEngine.on_event(world, player, type, arg, KINDS)


## Мету «принести» поповнено (QuestEngine.on_event).
static func fetch_msg(world, id: String) -> Dictionary:
	var st := QuestEngine.step(id)
	return {"text": "✦ %s %d/%d" % [st["objective"]["item"], mini(QuestEngine.progress(world, id), _count(st)), _count(st)], "big": false}


## Мету кроку виконано: повернутися до оповідача.
static func objective_met(world, _player, id: String) -> Array:
	QuestEngine.set_stage(world, id, "turnin")
	return [{"text": "✦ Переказ: мету виконано!\nПовертайся: %s" % Data.place_name(str(QuestEngine.step(id)["city"])), "big": true}]


## Нагорода кроку словами (для довідника й журналу). player — герой: гривні й досвід числами, які він дістане
## зараз (без героя — за рівень і частка смуги).
static func reward_text(st: Dictionary, player = null) -> String:
	var r: Dictionary = st.get("reward", {})
	var parts := []
	if r.has("gold_lvl"):
		parts.append(("%d грн" % (int(r["gold_lvl"]) * int(player.level))) if player != null else ("%d грн за рівень героя" % int(r["gold_lvl"])))
	if r.has("xp"):
		parts.append(QuestEngine.xp_text(r, player))
	if r.has("trophy"):
		parts.append("%d трофеїв" % int(r["trophy"]))
	if r.has("item"):
		parts.append("«%s»" % str(r["item"]["name"]))
	return ", ".join(parts)


static func _complete(world, player, id: String) -> Array:
	var st := QuestEngine.step(id)
	var line := QuestEngine.line_of(id)
	var L: Dictionary = Legends.line(line)
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
	if r.has("xp"):  # частка смуги нинішнього рівня й майстерності, без надбавок
		parts.append("+%d досвіду" % QuestEngine.pay_xp(player, r))
	msgs.append({"text": "Переказ «%s»: «%s» завершено!" % [L["title"], st["title"]], "big": true})
	if not parts.is_empty():
		msgs.append({"text": ", ".join(parts), "big": false})
	if r.has("item"):
		var d: Dictionary = r["item"]
		var it := Data.gen_item(int(d["ilvl"]), int(d["rarity"]), d["slot"], d.get("type", ""))  # рівень місця кроку + 1, як у сюжеті
		it["name"] = d["name"]
		it["up"] = int(d.get("up", 0))
		if not player.add_item(it):
			player.inventory.append(it)  # нагороду переказу не губимо навіть із повною торбою
		msgs.append({"text": "Отримано: %s" % Data.item_title(it), "big": false})
	QuestEngine.complete(world, id)
	if QuestEngine.line_finished(world, line):
		msgs.append({"text": "Переказ «%s» розказано до кінця!" % L["title"], "big": true})
	return msgs


## Куди веде крок лінійки: id міста чи місця ("" — нікуди).
static func target(world, line: String) -> String:
	for id in missions(world):
		if QuestEngine.line_of(id) == line:
			return mission_target(world, id)
	return ""


## Куди веде місія переказу id: до мети, коли вона виконується, інакше до оповідача.
static func mission_target(world, id: String) -> String:
	var st := QuestEngine.step(id)
	return str(st["objective"].get("loc", "")) if QuestEngine.stage(world, id) == "active" else str(st["city"])


## Усі місця, куди зараз ведуть перекази (для позначок на мапі).
static func targets(world) -> Array:
	var out := []
	for id in missions(world):
		var t := mission_target(world, id)
		if t != "" and not t in out:
			out.append(t)
	return out


## Рядок мети лінійки словами.
static func objective_text(world, line: String) -> String:
	var st := current(world, line)
	return mission_line(world, str(st["id"])) if not st.is_empty() else ""


## Рядок мети місії переказу id словами.
static func mission_line(world, id: String) -> String:
	var st := QuestEngine.step(id)
	match QuestEngine.stage(world, id):
		"active":
			var text: String = str(st["objective"]["text"])
			if _count(st) > 1:
				text += " %d/%d" % [QuestEngine.progress(world, id), _count(st)]
			return text
		"turnin":
			return "Повертайся: %s" % Data.place_name(str(st["city"]))
	return "Поговори: %s (%s)" % [Story.npc_name(st["giver"]), Data.place_name(str(st["city"]))]


## Рядки для журналу: [{"line", "title", "text", "target", "back": чи час повертатися, "reward"}]. player — для
## гривень і досвіду числами (reward_text).
static func rows(world, player = null) -> Array:
	var out := []
	for id in missions(world):
		var st := QuestEngine.step(id)
		var line := QuestEngine.line_of(id)
		out.append({"line": line, "title": "%s. %s" % [Legends.line(line)["title"], st["title"]], "text": mission_line(world, id),
			"target": mission_target(world, id), "back": QuestEngine.stage(world, id) == "turnin", "reward": reward_text(st, player)})
	return out


## Скільки лінійок пройдено до кінця.
static func done_count(world) -> int:
	var n := 0
	for line in Legends.order():
		if finished(world, line):
			n += 1
	return n


## Бій у місці, куди зараз веде переказ, іде не нижче за рівень місії (QuestEngine.mission_level).
## Загальне правило для всіх місій — QuestEngine.fight_mods (гра бере його); тут — лише місії переказів.
static func mods_for(world, player, loc_id: String) -> Dictionary:
	return QuestEngine.fight_mods(world, player, loc_id, KINDS)
