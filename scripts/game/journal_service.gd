extends RefCounted
## Журнал завдань: усе, що герой зараз має зробити, зібране з різних служб в одне місце.
## Розділ — {"title", "rows", "empty"}; рядок — {"text", "where", "from", "reward", "ready", "ready_text"}.

const Data := preload("res://scripts/data/data.gd")
const StoryService := preload("res://scripts/game/story_service.gd")
const HeroService := preload("res://scripts/game/hero_service.gd")
const SpecService := preload("res://scripts/game/spec_service.gd")


## Рядок завдання без позначки на початку («★ », «✦ », «◆ »): у журналі їх замінює заголовок розділу.
static func _clean(line: String) -> String:
	for mark in ["★ ", "✦ ", "◆ "]:
		if line.begins_with(mark):
			return line.substr(mark.length())
	return line


static func _row(text: String, where: String = "", from: String = "", reward: String = "", ready: bool = false, ready_text: String = "") -> Dictionary:
	return {"text": text, "where": where, "from": from, "reward": reward, "ready": ready, "ready_text": ready_text}


static func sections(world, player) -> Array:
	var out := []
	# Історія
	var story: String = StoryService.objective_line(world)
	if story != "":
		var target: String = StoryService.target(world)
		var back: bool = str(StoryService.state(world)["stage"]) == "turnin"
		out.append({"title": "Історія. " + str(StoryService.chapter_title(world)), "empty": "",
			"rows": [_row(_clean(story), Data.place_name(target) if target != "" else "", "", "", back, "Повертайся по нагороду")]})
	# Побратими й посвята в спеціалізацію
	var rows := []
	for line in HeroService.objective_lines(world):
		rows.append(_row(_clean(str(line))))
	var trial: String = SpecService.objective_line(world)
	if trial != "":
		rows.append(_row(_clean(trial), "", "", "", trial.contains("Повертайся"), "Повертайся на посвяту"))
	if not rows.is_empty():
		out.append({"title": "Побратими й посвята", "rows": rows, "empty": ""})
	# Завдання міст
	rows = []
	for q in world.quests:
		var reward := []
		if int(q.get("gold", 0)) > 0:
			reward.append("%d грн" % int(q["gold"]))
		if int(q.get("xp", 0)) > 0:
			reward.append("досвіду %d" % int(q["xp"]))
		if int(q.get("loyalty", 0)) > 0:
			reward.append("лояльності %d" % int(q["loyalty"]))
		var city: String = Data.place_name(str(q["city"]))
		rows.append(_row("%s  %d/%d" % [str(q["text"]), int(q.get("progress", 0)), int(q.get("count", 1))], Data.place_name(str(q.get("loc", ""))) if str(q.get("loc", "")) != "" else "",
			city, ", ".join(reward), world.is_done(q), "Готово: здай у місті %s" % city))
	out.append({"title": "Завдання міст (%d/%d)" % [world.quests.size(), Data.MAX_ACTIVE_QUESTS], "rows": rows,
		"empty": "Нема. Завдання беруть на дошці оголошень у місті."})
	# Розшук
	var Bounty = load("res://scripts/game/bounty_service.gd")
	rows = []
	for b in Bounty.state(world)["active"]:
		var bcity: String = Data.place_name(str(b["city"]))
		rows.append(_row("Розшук: %s" % str(b["name"]), Data.place_name(str(b["loc"])), bcity, "%d грн, слави %d" % [int(b["gold"]), int(b["glory"])],
			bool(b["killed"]), "Голова твоя: неси в місто %s" % bcity))
	if Bounty.unlocked(player) or not rows.is_empty():
		out.append({"title": "Розшук", "rows": rows, "empty": "Нема. Цілі розшуку беруть у місті на вкладці «Розшук»."})
	# Події, що тривають просто зараз
	rows = []
	for line in load("res://scripts/game/events_board.gd").now_lines(world, player):
		rows.append(_row(str(line)))
	if not rows.is_empty():
		out.append({"title": "Події зараз", "rows": rows, "empty": ""})
	return out


## Скільки завдань уже можна здати (для лічильника на вкладці).
static func ready_count(world, player) -> int:
	var n := 0
	for sec in sections(world, player):
		for r in sec["rows"]:
			if r["ready"]:
				n += 1
	return n


## Скільки всього активних завдань у журналі.
static func total(world, player) -> int:
	var n := 0
	for sec in sections(world, player):
		n += sec["rows"].size()
	return n
