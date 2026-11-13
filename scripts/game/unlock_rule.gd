extends RefCounted
## Умова відкриття місця, що лежить у налаштуваннях (Башта, Глибини): рівень героя «open_level» і місія
## «open_after» (id кроку завдань, "" — без місії). Відкрито, коли рівень досить високий і місію здано.
## Текст для гравця називає, чого бракує: місію (назва, хто дає й де) і/або рівень.

const QuestEngine := preload("res://scripts/game/quest_engine.gd")


static func open(world, lvl: int, need_level: int, after: String) -> bool:
	if lvl < need_level:
		return false
	return after == "" or (world != null and QuestEngine.is_done(world, after))


## «<verb> після місії «…» (Мирон, кошовий отаман, Січ) і з 38-го рівня героя.» ("" — відкрито).
## verb — «Відкриється» чи «Відкриються»; short — «з 15-го рівня» без слова «героя» (дошка подій).
static func text(world, lvl: int, need_level: int, after: String, verb: String, short: bool = false) -> String:
	var parts := []
	if after != "" and not (world != null and QuestEngine.is_done(world, after)):
		parts.append("після місії %s" % mission_name(after))
	if lvl < need_level:
		parts.append(("з %d-го рівня" if short else "з %d-го рівня героя") % need_level)
	if parts.is_empty():
		return ""
	return "%s %s." % [verb, " і ".join(parts)]


## Місія словами: «назва» (хто дає, де).
static func mission_name(id: String) -> String:
	var R := QuestEngine.step(id)
	if R.is_empty():
		return "«%s»" % id
	var Story = load("res://scripts/data/story.gd")
	var Data = load("res://scripts/data/data.gd")
	var who := [Story.npc_name(str(R.get("giver", "")))]
	if str(R.get("city", "")) != "":
		who.append(Data.place_name(str(R["city"])))
	return "«%s» (%s)" % [QuestEngine.title(id), ", ".join(who)]
