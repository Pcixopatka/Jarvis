extends RefCounted
## Список подій і занять із живим станом — як календар свят, тільки для всього, чим можна зайнятися.
## Описи — у data/events.json (WikiData.events); тут лише те, що змінюється: чи відкрито, що вже взято цього тижня й сьогодні,
## що діє на мапі просто зараз. Вкладка «Події» на екрані героя (UiCharacter) і довідник беруть дані звідси.

const Wiki := preload("res://scripts/data/wiki_data.gd")
const Data := preload("res://scripts/data/data.gd")
const Acts := preload("res://scripts/data/activities.gd")
const Camp := preload("res://scripts/data/camp_data.gd")


static func _svc(name: String):
	return load("res://scripts/game/%s.gd" % name)


static func info(id: String) -> Dictionary:
	return Wiki.event(id)


static func _chapter(world) -> int:
	return int(_svc("story_service").chapter_index(world))


## Чи відкрито заняття цьому героєві. Повертає "" (відкрито) або що для цього треба (ціле речення).
static func locked_reason(id: String, world, player) -> String:
	var E := info(id)
	var peasant: bool = player.is_peasant()
	var lvl: int = int(player.level)
	match id:
		"duel", "duel_free":
			if not _svc("duel_service").unlocked(player):
				return "Відкриється з %d-го рівня, після вибору дороги" % int(_svc("duel_service").MIN_LEVEL)
		"muster":
			if not _svc("muster_service").unlocked(player):
				return "Відкриється з %d-го рівня, після вибору дороги" % int(Acts.MUSTER_MIN_LEVEL)
		"ring":
			if not _svc("ring_service").unlocked(player):
				return "Відкриється з %d-го рівня, після вибору дороги" % int(Acts.spot("kolo")["level"])
		"vigil":
			if not _svc("vigil_service").unlocked(player):
				return "Відкриється з %d-го рівня, після вибору дороги" % int(Acts.spot("varta")["level"])
		"hunt", "fish":
			var need := int(Acts.spot(id)["level"])
			if lvl < need:
				return "Відкриється з %d-го рівня" % need
		"bounty":
			if not _svc("bounty_service").unlocked(player):
				return "Відкриється з %d-го рівня" % int(_svc("bounty_service").MIN_LEVEL)
		"trade":
			if peasant:
				return "Відкриється після вибору дороги"
		"trail":
			if lvl < int(E.get("level", 0)):
				return "Відкриється з %d-го рівня" % int(E["level"])
		"garden":
			if _svc("garden_service").level(world) < 1:
				return "Збудуй город на хуторі"
		"expedition":
			if world.companions.is_empty():
				return "Найми супутника в корчмі"
		"tower":
			if not _svc("tower_service").unlocked(player, world):
				return _svc("tower_service").lock_text(world, lvl, "Відкриється", true).trim_suffix(".")
		"depths":
			if not _svc("depth_service").unlocked(world, lvl):
				return _svc("depth_service").lock_text(world, lvl, "Відкриється", true).trim_suffix(".")
		"far":
			if lvl < int(E.get("level", 0)):
				return "Відкриється з %d-го рівня" % int(E["level"])
		"village_raid", "caravan", "wounded", "night", "treasure", "fair", "siege":
			if peasant or _chapter(world) < 1:
				return "Відкриється з першого розділу"
		"captives":
			if peasant or _chapter(world) < 2:
				return "Відкриється з другого розділу"
		"sich_siege":
			if peasant or _chapter(world) < 3:
				return "Відкриється з третього розділу"
		"theft":
			if _svc("camp_service").level(world, "pasika") < 1:
				return "Буває, коли на хуторі є пасіка"
	return ""


## Стан одного заняття: {"text": що зараз, "ready": чи є що робити просто зараз}.
static func status(id: String, world, player) -> Dictionary:
	var why := locked_reason(id, world, player)
	if why != "":
		return {"text": why, "ready": false, "locked": true}
	var ES = _svc("event_service")
	var active: Dictionary = ES.active(world)
	match id:
		"duel":
			var DS = _svc("duel_service")
			var s: Dictionary = DS.state(world)
			if DS.is_champion(world):
				return _st("Ти чемпіон цього тижня. Новий турнір за %d дн." % DS.days_to_reset(), false)
			if int(s["tries"]) <= 0:
				return _st("Спроб цього тижня нема. Новий турнір за %d дн." % DS.days_to_reset(), false)
			return _st("Виграно кіл: %d/%d • спроб: %d • новий турнір за %d дн." % [int(s["round"]), DS.ROUNDS, int(s["tries"]), DS.days_to_reset()], true)
		"duel_free":
			var DS = _svc("duel_service")
			var s: Dictionary = DS.state(world)
			var left: int = DS.free_paid_left(world)
			return _st("Серія: %d • найдовша: %d • гаманців сьогодні: %d" % [int(s["streak"]), int(s["best_streak"]), left], left > 0)
		"muster":
			var MS = _svc("muster_service")
			var s: Dictionary = MS.state(world)
			if MS.is_winner(world):
				return _st("Огляд цього тижня за тобою. Новий за %d дн." % MS.days_to_reset(), false)
			if int(s["tries"]) <= 0:
				return _st("Спроб цього тижня нема. Новий огляд за %d дн." % MS.days_to_reset(), false)
			return _st("Виграно сутичок: %d/%d • спроб: %d • побратимів: %d" % [int(s["round"]), MS.ROUNDS, int(s["tries"]), MS.allies(world)], true)
		"ring":
			var RS = _svc("ring_service")
			var s: Dictionary = RS.state(world)
			var stages := int(Acts.RING_STAGES)
			var day_left := maxi(0, int(Acts.RING_REPEAT_PAID) - int(s["day_paid"]))
			if int(s["paid"]) < stages:
				return _st("Тижневих кіл: %d/%d • новий склад за %d дн." % [int(s["paid"]), stages, RS.days_to_reset()], true)
			return _st("Тижневу нагороду взято • малих гаманців сьогодні: %d" % day_left, day_left > 0)
		"vigil":
			var VS = _svc("vigil_service")
			var s: Dictionary = VS.state(world)
			var goal := int(Acts.VIGIL_GOAL / 60.0)
			var best: float = float(s["best_time"])
			var rec := ("рекорд %s" % VS.time_text(best)) if best > 0.0 else "рекорду ще нема"
			return _st("Оплачено сьогодні хвилин: %d/%d • %s" % [mini(int(s["paid"]), goal), goal, rec], int(s["paid"]) < goal)
		"dice":
			var TS = _svc("tavern_service")
			var left: int = TS.games_left(world)
			return _st("Партій сьогодні: %d із %d" % [left, TS.games_max()], left > 0)
		"challenges":
			var CS = _svc("challenge_service")
			var n: int = CS.ready_count(world, player)
			return _st(("Готових нагород: %d" % n) if n > 0 else "Нагород поки нема: виконуй виклики", n > 0)
		"hunt", "fish":
			var OS = _svc("outdoor_service")
			if not OS.ready(world, id):
				return _st("Звір сполоханий: повернеться після походу" if id == "hunt" else "Риба не клює: повернеться після походу", false)
			var rich: bool = OS.rich(world, id)
			return _st(("Сьогодні тут багато великого звіра" if id == "hunt" else "Сьогодні добре клює велика риба") if rich else "Чекає на тебе", true)
		"rumor":
			var done: bool = bool(_svc("tavern_service").state(world).get("rumor_done", false))
			return _st("Чутку цього походу вже почуто" if done else "Можна почути чутку", not done)
		"trail":
			var pct := roundi(_svc("trail_service").chance(player) * 100.0)
			return _st("Трапляються у %d%% походів" % pct, false)
		"bounty":
			var n: int = _svc("bounty_service").state(world)["active"].size()
			var killed := 0
			for b in _svc("bounty_service").state(world)["active"]:
				if b["killed"]:
					killed += 1
			if killed > 0:
				return _st("Голів, які можна здати: %d" % killed, true)
			return _st("Шукаєш голів: %d із %d" % [n, int(Acts.BOUNTY_ACTIVE)], n > 0)
		"escort":
			var n := 0
			for q in world.quests:
				if _svc("escort_service").is_open(q):
					n += 1
			return _st(("Узято супроводів: %d" % n) if n > 0 else "Шукай на дошці завдань у місті", n > 0)
		"trade":
			var TS = _svc("trade_service")
			var n: int = TS.cargo_count(world)
			return _st(("На возі: %d/%d" % [n, TS.capacity(world)]) if n > 0 else "Віз порожній", n > 0)
		"garden":
			var GS = _svc("garden_service")
			var ripe: int = GS.ready_count(world)
			return _st(("Достигло грядок: %d" % ripe) if ripe > 0 else "Грядок: %d" % GS.beds_count(world), ripe > 0)
		"expedition":
			var ExS = _svc("expedition_service")
			var away := 0
			var back := 0
			for c in world.companions:
				if ExS.back(c):
					back += 1
				elif ExS.away(c):
					away += 1
			if back > 0:
				return _st("Повернулись із походу: %d" % back, true)
			return _st(("У поході: %d" % away) if away > 0 else "Усі вдома", false)
		"far":
			var open := []
			var FS = _svc("far_service")
			for r in Data.region_ids():
				if player.level >= FS.open_level(r):
					open.append(str(Data.region(r)["name"]))
			return _st("Відкрито: " + ", ".join(open), true)
		"tower":
			var s: Dictionary = _svc("tower_service").state(world)
			return _st("Найвищий пройдений поверх: %d" % int(s["best"]), true)
		"depths":
			var s: Dictionary = _svc("depth_service").state(world)
			return _st("Найглибша пройдена глибина: %d" % int(s["best"]), true)
		"village_raid", "caravan", "captives", "wounded", "sich_siege":
			if active.get("kind", "") == id:
				return _st("%s, лишилось походів: %d" % [ES.place(str(active.get("target", ""))), int(active.get("left", 0))], true)
			return _st("Трапляється після походу", false)
		"siege":
			var sieges: Dictionary = _svc("defense_service").state(world)["sieges"]
			if not sieges.is_empty():
				var parts := []
				for t in sieges:
					parts.append("%s, лишилось походів: %d" % [_svc("defense_service").name_of(t), int(sieges[t])])
				return _st("; ".join(parts), true)
			return _st("Трапляється, коли зараза підповзає", false)
		"night":
			var nights: Dictionary = ES.state(world)["night"]
			if not nights.is_empty():
				var names := []
				for loc in nights:
					names.append(Data.place_name(loc))
				return _st(", ".join(names), true)
			return _st("Трапляється після походу", false)
		"treasure":
			var tr: Dictionary = ES.state(world)["treasure"]
			if not tr.is_empty():
				return _st("скарб чекає: " + Data.place_name(str(tr.keys()[0])), true)
			return _st("Трапляється після походу", false)
		"fair":
			var fair: Dictionary = ES.state(world)["fair"]
			if not fair.is_empty():
				return _st("%s, ще походів: %d" % [Data.place_name(str(fair["city"])), int(fair["left"])], true)
			var trips := int(ES.state(world)["trips"])
			var every := int(ES.FAIR_EVERY)
			return _st("Наступний за %d походів" % (every - trips % every), false)
		"theft":
			var safe: bool = _svc("camp_service").level(world, "kurin") >= 2
			return _st("Курінь стереже мед" if safe else "Курінь 2-го рівня зменшить ризик", false)
		"holidays":
			var HS = _svc("holiday_service")
			var hid: String = HS.active()
			if hid != "":
				return _st("сьогодні %s, %s" % [Acts.holiday(hid)["name"], Acts.holiday(hid)["bonus_text"]], true)
			var nx: Dictionary = HS.upcoming()
			if not nx.is_empty():
				return _st("Найближче: %s, за %d дн." % [Acts.holiday(nx["id"])["name"], int(nx["in_days"])], false)
	return _st("", false)


static func _st(text: String, ready: bool) -> Dictionary:
	return {"text": text, "ready": ready, "locked": false}


## Усі події з описом і станом: [{"id", "name", "kind", "icon", "where", "level", "text", "reward", "status", "ready", "locked"}].
static func rows(world, player, here: String = "") -> Array:
	var out := []
	for e in Wiki.events():
		var r: Dictionary = e.duplicate()
		var st := status(e["id"], world, player)
		r["status"] = st["text"]
		r["ready"] = st["ready"]
		r["locked"] = st["locked"]
		r["place"] = "" if st["locked"] else place(e["id"], world, here)
		out.append(r)
	return out


static func _ll(id: String) -> Vector2:
	if Data.is_city(id):
		return Data.city(id)["pos"]
	if Data.is_place(id):
		return Data.place(id)["pos"]
	if Acts.is_spot(id):
		return Acts.spot(id)["pos"]
	return Camp.camp()["pos"] if id == Camp.CAMP_ID else Data.city("sich")["pos"]


## Найближче до героя місто (саме місто, якщо він у ньому).
static func _near_city(here: String) -> String:
	if Data.is_city(here):
		return here
	var best := "sich"
	var best_d := INF
	for c in Data.city_ids():
		var d: float = _ll(here).distance_to(Data.city(c)["pos"])
		if d < best_d:
			best_d = d
			best = c
	return best


## Місце події на мапі: id міста, місцевості, хутора чи місця занять. "" — показати нема чого:
## подія не має свого місця або зараз не діє. here — де герой: для «у будь-якому місті» береться найближче.
static func place(id: String, world, here: String = "") -> String:
	var ES = _svc("event_service")
	if id in ES.BATTLE_KINDS:
		var a: Dictionary = ES.active(world)
		return str(a["target"]) if not a.is_empty() and str(a["kind"]) == id else ""
	match id:
		"duel", "duel_free":
			return "sich"
		"muster":
			return "chyhyryn"
		"garden", "theft":
			return Camp.CAMP_ID
		"tower":
			return str(_svc("tower_service").LOC_ID)
		"depths":
			return str(_svc("depth_service").LOC_ID)
		"siege":
			for c in _svc("defense_service").state(world)["sieges"]:
				return str(c)
			return ""
		"night", "treasure":
			for loc in ES.state(world)[id]:
				return str(loc)
			return ""
		"fair":
			var fair: Dictionary = ES.state(world)["fair"]
			return str(fair["city"]) if not fair.is_empty() else ""
		"bounty":
			# узята ціль веде до свого лігва, вбита — до міста з нагородою
			for b in _svc("bounty_service").state(world)["active"]:
				return str(b["city"]) if bool(b["killed"]) else str(b["loc"])
			return _near_city(here)
		"escort":
			for q in world.quests:
				if str(q.get("type", "")) == "escort":
					return str(q["city"]) if world.is_done(q) else str(q["loc"])
			return _near_city(here)
		"dice", "rumor", "trade", "expedition":
			return _near_city(here)
		"far":
			var best := ""
			var best_d := INF
			for loc in Data.place_ids():
				if Data.place(loc).get("scale", false):
					var d: float = _ll(here).distance_to(Data.place(loc)["pos"])
					if d < best_d:
						best_d = d
						best = loc
			return best
	for sid in Acts.spot_ids():
		if str(Acts.spot(sid)["kind"]) == id:
			return sid
	return ""


## Скільки занять можна взяти просто зараз (для позначки на вкладці).
static func ready_count(world, player) -> int:
	var n := 0
	for e in Wiki.events():
		if e["kind"] in ["weekly", "world"] and status(e["id"], world, player)["ready"]:
			n += 1
	return n


## Що діє на мапі просто зараз: [{"id", "text", "place"}] (place — де це на мапі, "" — ніде).
static func now_items(world, player, here: String = "") -> Array:
	var out := []
	for e in Wiki.events():
		if e["kind"] != "world":
			continue
		var st := status(e["id"], world, player)
		if st["ready"]:
			out.append({"id": e["id"], "text": "%s: %s" % [e["name"], st["text"]], "place": place(e["id"], world, here)})
	if _svc("event_service").free_hire(world):
		out.append({"id": "", "text": "Наступний найм у корчмі безкоштовний", "place": ""})
	return out


## Те саме рядками (для журналу).
static func now_lines(world, player) -> Array:
	var out := []
	for it in now_items(world, player):
		out.append(it["text"])
	return out
