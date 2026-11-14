extends RefCounted
## Журнал завдань: усе, що герой зараз має зробити, зібране з різних служб в одне місце.
## Розділ — {"title", "rows", "empty"}; рядок — {"text", "where", "from", "reward", "ready", "ready_text"}.

const Data := preload("res://scripts/data/data.gd")
const StoryService := preload("res://scripts/game/story_service.gd")
const HeroService := preload("res://scripts/game/hero_service.gd")
const SpecService := preload("res://scripts/game/spec_service.gd")


## Що журнал каже про історію, коли її пройдено: гілка лишається на видноті, а герой знає, куди далі.
## Що журнал каже в розділі історії, коли нинішня ланка — переказ (%s — його назва).
const LINK_TEXT := "Історія веде через переказ «%s»: його крок — у розділі «Перекази» нижче."
const DONE_TEXT := "Історію пройдено: Путіноїда здолано, зараза відступила. Далі чекають Глибини зарази під Кремлем, Башта Кощія, далекі краї, Московія, розшук і події."


## Рядок завдання без позначки на початку («★ », «!», «✦ », «◆ »): у журналі їх замінює заголовок розділу,
## а місіям рушія — їхня позначка (marked).
static func _clean(line: String) -> String:
	for mark in ["★ ", "! ", "✦ ", "◆ "]:
		if line.begins_with(mark):
			return line.substr(mark.length())
	return line


## place — id місця на мапі, куди зараз іти із цим завданням: мета, а для виконаного — місто, де здати ("" — нема).
static func _row(text: String, where: String = "", from: String = "", reward: String = "", ready: bool = false, ready_text: String = "", place: String = "") -> Dictionary:
	return {"text": text, "where": where, "from": from, "reward": reward, "ready": ready, "ready_text": ready_text, "place": place}


## Рядок місії рушія з її позначкою (QuestEngine.mark: «★» — сюжетна, «!» — решта).
static func marked(id: String, text: String) -> String:
	return "%s %s" % [StoryService.QuestEngine.mark(id), _clean(text)]


## Що сказати про місію, якій бракує лише рівня: з ким і де говорити (крок без розмови — його мета).
static func waiting_text(id: String) -> String:
	var Q = StoryService.QuestEngine
	var R: Dictionary = Q.step(id)
	if str(R.get("city", "")) == "":
		return str(R.get("objective", {}).get("text", ""))
	return "Поговори: %s (%s)" % [StoryService.Story.npc_name(str(R["giver"])), Data.place_name(str(R["city"]))]


## Рядок журналу для місії, якій бракує рівня: «★ Поговори: … — потрібен рівень 90». head — назва перед текстом.
static func _wait_row(id: String, head: String = "") -> Dictionary:
	var Q = StoryService.QuestEngine
	var at: String = Q.giver_place(id)
	var text := "%s%s — потрібен рівень %d" % [("%s: " % head) if head != "" else "", waiting_text(id), Q.level_needed(id)]
	var r := _row(marked(id, text), Data.place_name(at) if at != "" else "", "", "", false, "", at)
	r["wait"] = Q.level_needed(id)
	return r


static func sections(world, player) -> Array:
	var out := []
	# Історія: уся гілка розділами. Розділ є завжди, і коли історію вже пройдено:
	# "chapters" — [{"title", "state"}], state: done (пройдено), now (нинішній), ahead (попереду).
	var Story = StoryService.Story
	var finished: bool = StoryService.finished(world)
	var at: int = StoryService.chapter_index(world)
	var chapters := []
	for i in Story.chapter_count():
		chapters.append({"title": Story.chapter_title(i),
			"state": "done" if finished or i < at else ("now" if i == at else "ahead")})
	# Після Кремля історія триває: кроки «Попелу за вітром» ідуть у тому самому списку розділів
	var SagaS = StoryService.SagaService
	if finished:
		for st in SagaS.Saga.steps():
			var sid := str(st["id"])
			chapters.append({"title": "%s. %s" % [SagaS.Saga.title(), st["title"]],
				"state": "done" if StoryService.QuestEngine.is_finished(world, sid) else ("now" if StoryService.QuestEngine.is_open(world, sid) else "ahead")})
	# Рядок на кожну відкриту сюжетну місію рушія (сьогодні вона одна: нинішній крок історії чи саги)
	var story_rows := []
	for id in StoryService.missions(world):
		var target: String = StoryService.QuestEngine.target(world, id)
		var back: bool = StoryService.QuestEngine.stage(world, id) == "turnin"
		var xp_reward: String = StoryService.QuestEngine.xp_text(StoryService.QuestEngine.step(id).get("reward", {}), player)  # досвід, який герой дістане зараз
		story_rows.append(_row(marked(id, StoryService.mission_line(world, id)), Data.place_name(target) if target != "" else "", "", xp_reward, back, "Повертайся по нагороду", target))
	# Наступна сюжетна місія, якій бракує лише рівня: видно, що далі й чому ще закрито (вона замінює примітку саги)
	var waits := {"story": [], "legend": [], "side": []}
	for id in StoryService.QuestEngine.waiting(world):
		var k: String = StoryService.QuestEngine.kind_of(id)
		k = "story" if k in StoryService.KINDS else k
		if waits.has(k):
			waits[k].append(id)
	for id in waits["story"]:
		# крок історії — з назвою, як рядок переказу (у саги назви тут нема: «Попіл за вітром» — у заголовку)
		story_rows.append(_wait_row(id, str(StoryService.QuestEngine.step(id).get("title", "")) if StoryService.QuestEngine.kind_of(id) == "story" else ""))
	var ch_title: String = str(StoryService.chapter_title(world))
	var teaser: String = SagaS.teaser(world) if waits["story"].is_empty() else ""
	var story_sec := {"title": "Історія" + ("" if ch_title == "" else ". " + ch_title), "rows": story_rows, "chapters": chapters,
		"empty": (DONE_TEXT if finished and (SagaS.finished(world) or not SagaS.unlocked(world)) else "") + ((" " + teaser) if finished and teaser != "" else "")}
	if finished and not story_rows.is_empty() and story_rows.all(func(r): return r.has("wait")):
		story_sec["note"] = DONE_TEXT  # лише місії, що чекають рівня: підсумок історії лишається на видноті
	if story_rows.is_empty() and not finished:
		# Ланка історії зараз — переказ: його рядок стоїть у «Переказах», а тут — куди дивитися
		var links: Array = StoryService.chain(world) + StoryService.chain_waiting(world)
		if not links.is_empty() and StoryService.QuestEngine.kind_of(str(links[0])) == "legend":
			story_sec["empty"] = LINK_TEXT % StoryService.QuestEngine.line_title(StoryService.QuestEngine.line_of(str(links[0])))
	out.append(story_sec)
	# Побратими й посвята в спеціалізацію
	var rows := []
	for line in HeroService.objective_lines(world):
		rows.append(_row(_clean(str(line))))
	var trial: String = SpecService.objective_line(world)
	if trial != "":
		rows.append(_row(_clean(trial), "", "", "", trial.contains("Повертайся"), "Повертайся на посвяту", str(SpecService.target(world))))
	if not rows.is_empty():
		out.append({"title": "Побратими й посвята", "rows": rows, "empty": ""})
	# Перекази: квестові лінійки за легендами земель (ланки історії між розділами, із зіркою)
	var LegendS = load("res://scripts/game/legend_service.gd")  # рядки — відкриті місії переказів рушія
	rows = []
	var lms: Array = LegendS.missions(world)
	var lrs: Array = LegendS.rows(world, player)
	for i in lrs.size():
		var lr: Dictionary = lrs[i]
		var lplace: String = str(lr["target"])
		rows.append(_row(marked(str(lms[i]), "%s: %s" % [lr["title"], lr["text"]]), Data.place_name(lplace) if lplace != "" else "", "", str(lr["reward"]),
			bool(lr["back"]), "Оповідач чекає з нагородою", lplace))
	for id in waits["legend"]:
		rows.append(_wait_row(id, "%s. %s" % [StoryService.QuestEngine.line_title(StoryService.QuestEngine.line_of(id)), StoryService.QuestEngine.title(id)]))
	if not rows.is_empty():
		out.append({"title": "Перекази (%d із %d розказано)" % [LegendS.done_count(world), LegendS.Legends.order().size()], "rows": rows, "empty": ""})
	# Доручення: місії поза історією й переказами (SideService)
	var SideS = load("res://scripts/game/side_service.gd")
	rows = []
	for sr in SideS.rows(world, player):
		var splace: String = str(sr["target"])
		rows.append(_row(marked(str(sr["id"]), "%s: %s" % [sr["title"], _clean(str(sr["text"]))]), Data.place_name(splace) if splace != "" else "", "", str(sr["reward"]),
			bool(sr["back"]), "Повертайся по нагороду", splace))
	for id in waits["side"]:
		rows.append(_wait_row(id, StoryService.QuestEngine.title(id)))
	if not rows.is_empty():
		out.append({"title": "Доручення", "rows": rows, "empty": ""})
	# Завдання міст
	rows = []
	for q in world.quests:
		var reward := []
		if int(q.get("gold", 0)) > 0:
			reward.append("%d грн" % int(q["gold"]))
		reward.append(StoryService.QuestEngine.share_text(world.quest_xp_share(q), player))
		if int(q.get("loyalty", 0)) > 0:
			reward.append("лояльності %d" % int(q["loyalty"]))
		var city: String = Data.place_name(str(q["city"]))
		rows.append(_row("%s  %d/%d" % [str(q["text"]), int(q.get("progress", 0)), int(q.get("count", 1))], Data.place_name(str(q.get("loc", ""))) if str(q.get("loc", "")) != "" else "",
			city, ", ".join(reward), world.is_done(q), "Готово: здай у місті %s" % city, str(q["city"]) if world.is_done(q) else str(q.get("loc", ""))))
	out.append({"title": "Завдання міст (%d/%d)" % [world.quests.size(), Data.MAX_ACTIVE_QUESTS], "rows": rows,
		"empty": "Нема. Завдання беруть на дошці оголошень у місті."})
	# Розшук
	var Bounty = load("res://scripts/game/bounty_service.gd")
	rows = []
	for b in Bounty.state(world)["active"]:
		var bcity: String = Data.place_name(str(b["city"]))
		rows.append(_row("Розшук: %s" % str(b["name"]), Data.place_name(str(b["loc"])), bcity, "%d грн, слави %d" % [int(b["gold"]), int(b["glory"])],
			bool(b["killed"]), "Голова твоя: неси в місто %s" % bcity, str(b["city"]) if bool(b["killed"]) else str(b["loc"])))
	if Bounty.unlocked(player) or not rows.is_empty():
		out.append({"title": "Розшук", "rows": rows, "empty": "Нема. Цілі розшуку беруть у місті на вкладці «Розшук»."})
	# Події, що тривають просто зараз
	rows = []
	for line in load("res://scripts/game/events_board.gd").now_lines(world, player):
		rows.append(_row(str(line)))
	if not rows.is_empty():
		out.append({"title": "Події зараз", "rows": rows, "empty": ""})
	return out


## Де зараз можна здати виконане: місто -> {"quests": завдань міста, "heads": голів із розшуку}.
## Для позначки на мапі й рядка в панелі міста: мета після виконання зникає, а куди нести нагороду, має бути видно.
static func turn_in_places(world) -> Dictionary:
	var out := {}
	for q in world.quests:
		if world.is_done(q):
			var c := str(q["city"])
			if not out.has(c):
				out[c] = {"quests": 0, "heads": 0}
			out[c]["quests"] += 1
	for b in load("res://scripts/game/bounty_service.gd").state(world)["active"]:
		if bool(b["killed"]):
			var c := str(b["city"])
			if not out.has(c):
				out[c] = {"quests": 0, "heads": 0}
			out[c]["heads"] += 1
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
		for r in sec["rows"]:
			n += 0 if r.has("wait") else 1  # місія, що чекає рівня, — ще не справа
	return n
