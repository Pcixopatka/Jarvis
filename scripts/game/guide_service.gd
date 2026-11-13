extends RefCounted
## Порадник: що герой може зробити просто зараз, від найважливішого до запасного.
## Відповідає на питання «що робити й куди йти» одним списком: кожна порада має назву, пояснення
## і або місце на мапі (place), або вкладку екрана героя (tab). Мапа показує першу пораду кнопкою,
## журнал — перші MAX. Нове заняття чи служба додає сюди свою пораду, а не власну підказку деінде.
##
## Порада: {"kind", "text", "sub", "place", "tab"}; place — id для мапи ("" — нема), tab — номер вкладки (-1 — нема).

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")

const MAX := 5  # скільки порад показує журнал
static var WEAK_FROM: int  # порадник: з цього рівня героя стежить, чи під силу йому нечисть свого рівня
static var WEAK_GRADE: int  # порадник: з цієї оцінки Power.threat (3 — смертельно) радить зміцнити спорядження


## Числа-правила вище лежать у data/settings.json (запис «power»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("power")
	WEAK_FROM = S["weak_from"]
	WEAK_GRADE = S["weak_grade"]


const TAB_HERO := 0
const TAB_JOURNAL := 1
const TAB_SKILLS := 2
const TAB_PERKS := 3
const TAB_CHALLENGES := 8
const MAX_ACTIVITIES := 2  # справ дня й тижня в списку не більше стількох, щоб не забивали решту


static func _svc(name: String):
	return load("res://scripts/game/%s.gd" % name)


static func _it(kind: String, text: String, sub: String = "", place: String = "", tab: int = -1) -> Dictionary:
	return {"kind": kind, "text": text, "sub": sub, "place": place, "tab": tab}


static func _clean(line: String) -> String:
	for mark in ["★ ", "! ", "✦ ", "◆ "]:
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
	# 3. «Шлях козака»: виконаний крок чекає нагороди
	var Way = _svc("way_service")
	var way_ready: int = int(Way.ready_count(world, player))
	if way_ready > 0:
		out.append(_it("way_claim", "Шлях козака: забери нагороду", "Виконано кроків: %d" % way_ready, "", TAB_JOURNAL))
	# 4. Історія: кожна відкрита ланка сюжетного ланцюжка (крок історії, саги чи переказу; сьогодні вона одна),
	# далі доручення. Позначка — QuestEngine.mark
	var Q = Story.QuestEngine
	for id in Story.chain(world):
		var target: String = Q.target(world, id)
		var head: String = "" if Q.kind_of(id) == "legend" else "Історія: "  # рядок переказу сам каже «Переказ «…»»
		out.append(_it("story", "%s %s%s" % [Q.mark(id), head, _clean(Story.mission_line(world, id))], ("Де: %s" % Data.place_name(target)) if target != "" else "", target))
	var Side = _svc("side_service")
	for id in Side.missions(world):
		var target: String = Q.target(world, id)
		out.append(_it("side", "%s Доручення: %s" % [Q.mark(id), _clean(Side.mission_line(world, id))], ("Де: %s" % Data.place_name(target)) if target != "" else "", target))

	# 5. «Шлях козака»: нинішній крок, якщо він ще не виконаний
	if way_ready == 0 and not Way.finished(world):
		var step: Dictionary = Way.current(world)
		var g: Dictionary = Way.go(step, world, player, here)
		out.append(_it("way", "Шлях козака: %s" % str(step["title"]), "Нагорода: %s" % Way.reward_text(step), str(g["place"]), int(g["tab"])))
	# 6. Вільні очки: герой сильнішає за хвилину
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
	# 6а. У торбі лежить річ, сильніша за вдягнену
	var ups: int = player.best_upgrades().size()
	if ups > 0:
		out.append(_it("gear", "Вдягни кращі речі з торби", "Сильніших за вдягнене: %d. Кнопка «Вдягнути найкраще»" % ups, "", TAB_HERO))
	# 6б. Нечисть свого рівня смертельна для героя: час зміцнити спорядження
	if int(player.level) >= WEAK_FROM:
		var th: Dictionary = _svc("power").threat(player, int(player.level))
		if int(th["grade"]) >= WEAK_GRADE:
			out.append(_it("weak", "Зміцни спорядження", "Нечисть твого рівня тобі зараз: %s. Заточи й онови речі в коваля, вклади очки, встав душі" % str(th["name"]), "", TAB_HERO))
	# 7. Нагороди за виклики
	var claims: int = int(_svc("challenge_service").ready_count(world, player))
	if claims > 0:
		out.append(_it("claim", "Забери нагороду за виклики", "Готових викликів: %d" % claims, "", TAB_CHALLENGES))
	# 8. Розшук: ціль ще жива
	for b in _svc("bounty_service").state(world)["active"]:
		if not bool(b["killed"]):
			out.append(_it("bounty", "Розшук: %s" % str(b["name"]), "Де: %s. Нагорода: %d грн" % [Data.place_name(str(b["loc"])), int(b["gold"])], str(b["loc"])))
	# 9. Завдання міст у роботі
	for q in world.quests:
		if not world.is_done(q):
			out.append(_it("quest", "%s  %d/%d" % [str(q["text"]), int(q.get("progress", 0)), int(q.get("count", 1))], "Завдання від міста %s" % Data.place_name(str(q["city"])), str(q.get("loc", ""))))
	# 9а. Місії, яким бракує лише рівня: набирай рівні. Кожна сюжетна (зокрема переказ — ланка історії) і кожне
	# доручення, а з решти — лише найближча
	var near := ""
	for id in Q.waiting(world):
		if int(player.level) >= Q.level_needed(id):
			continue  # рівень уже є (рушій ще не бачив нового рівня героя): радити нема чого
		if Q.is_story(id) or Q.kind_of(id) == "side":
			out.append(_level_tip(world, player, id))
		elif near == "" or Q.level_needed(id) < Q.level_needed(near):
			near = id
	if near != "":
		out.append(_level_tip(world, player, near))
	# 10. Справи тижня й дня, де ще є що взяти
	var acts := 0
	for r in _svc("events_board").rows(world, player, here):
		if acts >= MAX_ACTIVITIES:
			break
		if r["kind"] in ["weekly", "daily"] and r["ready"] and str(r["place"]) != "" and str(r["id"]) != "challenges":
			out.append(_it("activity", str(r["name"]), str(r["status"]), str(r["place"])))
			acts += 1
	# 11. Запасні поради, щоб список ніколи не був порожній: похід за досвідом і нові завдання
	var spot := best_place(world, player, here)
	if spot != "":
		out.append(_it("explore", "Вирушай: %s" % Data.place_name(spot), "Місце твого рівня: досвід і здобич", spot))
	if world.quests.size() < Data.MAX_ACTIVE_QUESTS:
		var city: String = _svc("events_board")._near_city(here)
		out.append(_it("board", "Візьми завдання: %s" % Data.place_name(city), "Дошка оголошень у місті: гривні, досвід і лояльність", city))
	return out


## Порада набрати рівні для місії id, якій бракує лише рівня: скільки бракує й до якої місії.
static func _level_tip(_world, player, id: String) -> Dictionary:
	var Q = _svc("quest_engine")
	var need: int = Q.level_needed(id)
	var miss: int = need - int(player.level)
	var C = load("res://scripts/data/classes.gd")
	var where: String = Q.giver_place(id)
	if not Data.place_open(where, int(player.level)):
		where = ""  # крок без того, хто дає, чекає в своєму місці, а воно ще закрите: туди «Далі» не веде
	return _it("level", "%s Набери рівні: бракує %d %s" % [Q.mark(id), miss, C.plural(miss, "рівня", "рівнів", "рівнів")],
		"Місія %s чекає з %d-го рівня" % [load("res://scripts/game/unlock_rule.gd").mission_name(id), need], where)


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
		var d: float = _ll(here).distance_to(Data.place(id)["pos"])
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
