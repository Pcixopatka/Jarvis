extends RefCounted
## Порадник: що герой може зробити просто зараз, від найважливішого до запасного.
## Відповідає на питання «що робити й куди йти» одним списком: кожна порада має назву, пояснення
## і або місце на мапі (place), або вкладку екрана героя (tab). Мапа показує першу пораду кнопкою,
## журнал — перші MAX. Нове заняття чи служба додає сюди свою пораду, а не власну підказку деінде.
##
## Порада: {"kind", "text", "sub", "place", "tab"}; place — id для мапи ("" — нема), tab — номер вкладки (-1 — нема).

const Data := preload("res://scripts/data/data.gd")

const MAX := 5  # скільки порад показує журнал
const TAB_HERO := 0
const TAB_SKILLS := 2
const TAB_PERKS := 3
const TAB_CHALLENGES := 8
const MAX_ACTIVITIES := 2  # справ дня й тижня в списку не більше стількох, щоб не забивали решту


static func _svc(name: String):
	return load("res://scripts/game/%s.gd" % name)


static func _it(kind: String, text: String, sub: String = "", place: String = "", tab: int = -1) -> Dictionary:
	return {"kind": kind, "text": text, "sub": sub, "place": place, "tab": tab}


static func _clean(line: String) -> String:
	for mark in ["★ ", "✦ ", "◆ "]:
		if line.begins_with(mark):
			return line.substr(mark.length())
	return line


static func _ll(id: String) -> Vector2:
	return _svc("events_board")._ll(id)


## Усі поради за порядком важливості.
static func items(world, player, here: String = "") -> Array:
	var out := []
	var ES = _svc("event_service")
	var Story = _svc("story_service")
	# 1. Виконане чекає нагороди: найкоротший шлях до користі
	var places: Dictionary = _svc("journal_service").turn_in_places(world)
	for c in places:
		var parts := []
		if int(places[c]["quests"]) > 0:
			parts.append("завдань: %d" % int(places[c]["quests"]))
		if int(places[c]["heads"]) > 0:
			parts.append("нагород за розшук: %d" % int(places[c]["heads"]))
		out.append(_it("turn_in", "Здай виконане, місто %s" % Data.place_name(str(c)), "Чекає нагорода, " + ", ".join(parts), str(c)))
	# 2. Те, що згорить: облоги й бойова подія з лічильником походів
	var sieges: Dictionary = _svc("defense_service").state(world)["sieges"]
	for c in sieges:
		out.append(_it("siege", "Облога: %s" % Data.place_name(str(c)), "Протримаються ще походів: %d. Поспіши на оборону" % int(sieges[c]), str(c)))
	var a: Dictionary = ES.active(world)
	if not a.is_empty():
		out.append(_it("event", "%s: %s" % [ES.name_of(str(a["kind"])), Data.place_name(str(a["target"]))], "Чекає ще походів: %d" % int(a["left"]), str(a["target"])))
	# 3. Історія
	var line: String = Story.objective_line(world)
	if line != "":
		var target: String = Story.target(world)
		out.append(_it("story", "Історія: %s" % _clean(line), ("Де: %s" % Data.place_name(target)) if target != "" else "", target))
	# 4. Вільні очки: герой сильнішає за хвилину
	var pts := []
	var tab := -1
	if int(player.perk_points) > 0:
		pts.append("Загартування: %d" % int(player.perk_points))
		tab = TAB_PERKS
	if int(player.skill_points) > 0 and _can_spend_skill(player):
		pts.append("вмінь: %d" % int(player.skill_points))
		tab = TAB_SKILLS
	if int(player.stat_points) > 0:
		pts.append("характеристик: %d" % int(player.stat_points))
		tab = TAB_HERO
	if not pts.is_empty():
		out.append(_it("points", "Розподіли вільні очки", "Є очки " + ", ".join(pts), "", tab))
	# 5. Нагороди за виклики
	var claims: int = int(_svc("challenge_service").ready_count(world, player))
	if claims > 0:
		out.append(_it("claim", "Забери нагороду за виклики", "Готових викликів: %d" % claims, "", TAB_CHALLENGES))
	# 6. Розшук: ціль ще жива
	for b in _svc("bounty_service").state(world)["active"]:
		if not bool(b["killed"]):
			out.append(_it("bounty", "Розшук: %s" % str(b["name"]), "Де: %s. Нагорода: %d грн" % [Data.place_name(str(b["loc"])), int(b["gold"])], str(b["loc"])))
	# 7. Завдання міст у роботі
	for q in world.quests:
		if not world.is_done(q):
			out.append(_it("quest", "%s  %d/%d" % [str(q["text"]), int(q.get("progress", 0)), int(q.get("count", 1))], "Завдання від міста %s" % Data.place_name(str(q["city"])), str(q.get("loc", ""))))
	# 8. Справи тижня й дня, де ще є що взяти
	var acts := 0
	for r in _svc("events_board").rows(world, player, here):
		if acts >= MAX_ACTIVITIES:
			break
		if r["kind"] in ["weekly", "daily"] and r["ready"] and str(r["place"]) != "" and str(r["id"]) != "challenges":
			out.append(_it("activity", str(r["name"]), str(r["status"]), str(r["place"])))
			acts += 1
	# 9. Запасні поради, щоб список ніколи не був порожній: похід за досвідом і нові завдання
	var spot := best_place(world, player, here)
	if spot != "":
		out.append(_it("explore", "Вирушай: %s" % Data.place_name(spot), "Місце твого рівня: досвід і здобич", spot))
	if world.quests.size() < Data.MAX_ACTIVE_QUESTS:
		var city: String = _svc("events_board")._near_city(here)
		out.append(_it("board", "Візьми завдання: %s" % Data.place_name(city), "Дошка оголошень у місті: гривні, досвід і лояльність", city))
	return out


## Чи є куди вкласти очко вмінь (на дорозі героя лишились невивчені ранги).
static func _can_spend_skill(player) -> bool:
	for c in player.Classes.lineage(player.job):
		var pr: Array = player.tree_progress(c)
		if pr[0] < pr[1]:
			return true
	return false


## Найближча місцевість, що під силу герою й дає досвід його рівня ("" — такої нема).
static func best_place(world, player, here: String = "") -> String:
	var best := ""
	var best_d := INF
	for id in _svc("event_service").reachable_locs(world, player):
		var d: float = _ll(here).distance_to(Data.LOCATIONS[id]["pos"])
		if d < best_d:
			best_d = d
			best = id
	return best


## Перші MAX порад (для журналу).
static func top(world, player, here: String = "") -> Array:
	return items(world, player, here).slice(0, MAX)


## Головна порада одним рядком (для кнопки на мапі) або порожній словник.
static func first(world, player, here: String = "") -> Dictionary:
	var all := items(world, player, here)
	return all[0] if not all.is_empty() else {}
