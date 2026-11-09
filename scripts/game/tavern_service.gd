extends RefCounted
## Шинок: гра в кості «дванадцять» і чутки за частування.
## Кості: кидаєш по одній і додаєш очки; понад 12 — перебір і програш. Зупинився — кидає суперник.
## У кого більше (без перебору) — того й ставка; порівну — ставки назад. Рівно 12 — виграш у півтора раза.
## Чутки: раз на похід за гривні — скарб, нічний похід, вигідний торг або багаті угіддя.
## Стан — world.tavern: {"day", "games", "wins", "losses", "streak", "best_streak", "net", "twelves",
##   "sotnyk_day", "game": {}, "rumor_done", "rumor_text", "rumors", "tip": {"good", "city", "left"}}
## Партія: {"rival", "stake", "mine": [кості], "theirs": [кості], "over", "result": win|lose|draw, "gold": чистий виграш}

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const EventService := preload("res://scripts/game/event_service.gd")
const TradeService := preload("res://scripts/game/trade_service.gd")
const OutdoorService := preload("res://scripts/game/outdoor_service.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")


static func state(world) -> Dictionary:
	var s: Dictionary = world.tavern
	if s.is_empty():
		s["day"] = ""
		s["games"] = 0
		s["wins"] = 0
		s["losses"] = 0
		s["streak"] = 0
		s["best_streak"] = 0
		s["net"] = 0
		s["twelves"] = 0
		s["sotnyk_day"] = ""
		s["game"] = {}
		s["rumor_done"] = false
		s["rumor_text"] = ""
		s["rumors"] = 0
		s["tip"] = {}
	var day := ChallengeService.day_key(ChallengeService._now())
	if s["day"] != day:
		s["day"] = day
		s["games"] = 0
	return s


# ======================= Кості =======================

static func stake(rival: String, level: int) -> int:
	return int(Acts.DICE_RIVALS[rival]["stake"]) * (20 + 10 * level)


static func games_left(world) -> int:
	return maxi(0, Acts.DICE_GAMES - int(state(world)["games"]))


static func game(world) -> Dictionary:
	return state(world)["game"]


static func playing(world) -> bool:
	var g := game(world)
	return not g.is_empty() and not g["over"]


static func can_start(world, player, rival: String) -> bool:
	return game(world).is_empty() and games_left(world) > 0 and player.gold >= stake(rival, player.level)


static func total(rolls: Array) -> int:
	var t := 0
	for r in rolls:
		t += int(r)
	return t


static func _die(forced: int) -> int:
	return forced if forced >= 1 and forced <= 6 else randi_range(1, 6)


## Сісти до столу: ставка одразу йде на кін, перша кість кинута.
static func start(world, player, rival: String, forced: int = 0) -> bool:
	if not can_start(world, player, rival):
		return false
	var s := state(world)
	var st := stake(rival, player.level)
	player.gold -= st
	s["games"] = int(s["games"]) + 1
	s["game"] = {"rival": rival, "stake": st, "mine": [_die(forced)], "theirs": [], "over": false, "result": "", "gold": 0}
	return true


## Кинути ще кість. Повертає "ok", "bust" (перебір) або "" (нема партії).
static func roll(world, player, forced: int = 0) -> String:
	if not playing(world):
		return ""
	var g := game(world)
	g["mine"].append(_die(forced))
	if total(g["mine"]) > Acts.DICE_LIMIT:
		_finish(world, player, "lose")
		return "bust"
	return "ok"


## Чи кидатиме суперник далі: theirs — його очки, mine — очки гравця.
static func rival_goes(style: String, theirs: int, mine: int) -> bool:
	match style:
		"cautious":
			return theirs < 9
		"reckless":
			return theirs < 10
	return theirs < mine or (theirs == mine and theirs <= 8)  # steady: перебити, а на малій нічиїй ризикнути


## Зупинитись: суперник кидає свої кості, партію розсуджено. Повертає "win" | "lose" | "draw" | "".
static func stand(world, player, forced: Array = []) -> String:
	if not playing(world):
		return ""
	var g := game(world)
	var mine := total(g["mine"])
	var style: String = Acts.DICE_RIVALS[g["rival"]]["style"]
	var i := 0
	while rival_goes(style, total(g["theirs"]), mine):
		g["theirs"].append(_die(int(forced[i]) if i < forced.size() else 0))
		i += 1
	var theirs := total(g["theirs"])
	var result := "draw"
	if theirs > Acts.DICE_LIMIT or mine > theirs:
		result = "win"
	elif theirs > mine:
		result = "lose"
	_finish(world, player, result)
	return result


static func _finish(world, player, result: String) -> void:
	var s := state(world)
	var g := game(world)
	var st := int(g["stake"])
	g["over"] = true
	g["result"] = result
	g["msgs"] = []
	match result:
		"win":
			var twelve := total(g["mine"]) == Acts.DICE_LIMIT
			var prize := int(st * (Acts.DICE_TWELVE if twelve else 1.0))
			player.gold += st + prize
			g["gold"] = prize
			g["twelve"] = twelve
			s["wins"] = int(s["wins"]) + 1
			s["streak"] = int(s["streak"]) + 1
			s["best_streak"] = maxi(int(s["best_streak"]), int(s["streak"]))
			if twelve:
				s["twelves"] = int(s["twelves"]) + 1
			if g["rival"] == "sotnyk" and s["sotnyk_day"] != s["day"]:
				s["sotnyk_day"] = s["day"]
				g["msgs"].append("Сотника обіграно: +%d слави" % Acts.DICE_GLORY)
				g["msgs"].append_array(GloryService.add(world, player, Acts.DICE_GLORY))
		"draw":
			player.gold += st
			g["gold"] = 0
		_:
			g["gold"] = -st
			s["losses"] = int(s["losses"]) + 1
			s["streak"] = 0
	s["net"] = int(s["net"]) + int(g["gold"])


## Прибрати зіграну партію зі столу.
static func clear(world) -> void:
	var g := game(world)
	if not g.is_empty() and g["over"]:
		state(world)["game"] = {}


static func result_text(g: Dictionary) -> String:
	var name: String = Acts.DICE_RIVALS[g["rival"]]["name"]
	match str(g["result"]):
		"win":
			if total(g["theirs"]) > Acts.DICE_LIMIT:
				return "%s перебрав! Твій виграш: +%d грн" % [name, int(g["gold"])]
			if g.get("twelve", false):
				return "Дванадцять! Виграш у півтора раза: +%d грн" % int(g["gold"])
			return "Твоя взяла! +%d грн" % int(g["gold"])
		"draw":
			return "Порівну. Ставки повернуто"
		"lose":
			if total(g["mine"]) > Acts.DICE_LIMIT:
				return "Перебір! Ставка пропала: −%d грн" % int(g["stake"])
			return "%s переміг: −%d грн" % [name, int(g["stake"])]
	return ""


# ======================= Чутки =======================

static func rumor_cost(level: int) -> int:
	return 20 + 10 * level


## Які чутки зараз мають сенс у цьому місті.
static func rumor_kinds(world, player, city: String) -> Array:
	var out := []
	var es := EventService.state(world)
	var locs := EventService.reachable_locs(world, player)
	if not locs.is_empty() and es["treasure"].is_empty():
		out.append("treasure")
	for loc in locs:
		if not es["night"].has(loc):
			out.append("night")
			break
	if not player.is_peasant() and TradeService.has_market(city) and tip(world).is_empty():
		out.append("trade")
	var os := OutdoorService.state(world)
	if player.level >= int(Acts.SPOTS["hunt"]["level"]) and not os.get("rich_hunt", false):
		out.append("outdoor")
	return out


static func can_rumor(world, player, city: String) -> bool:
	return not state(world)["rumor_done"] and player.gold >= rumor_cost(player.level) and not rumor_kinds(world, player, city).is_empty()


## Пригостити шинок і почути чутку. Повертає її текст ("" — не вийшло).
static func buy_rumor(world, player, city: String, forced_kind: String = "") -> String:
	if not can_rumor(world, player, city):
		return ""
	var kinds := rumor_kinds(world, player, city)
	var kind: String = forced_kind if forced_kind in kinds else kinds[randi() % kinds.size()]
	var s := state(world)
	var es := EventService.state(world)
	var text := ""
	match kind:
		"treasure":
			var locs := EventService.reachable_locs(world, player)
			var loc: String = locs[randi() % locs.size()]
			es["treasure"][loc] = true
			text = "Старий чумак шепоче: у місцевості %s закопано скарб. Стереже його люта нечисть, та скриня того варта." % EventService.place(loc)
		"night":
			var free := EventService.reachable_locs(world, player).filter(func(l): return not es["night"].has(l))
			var loc2: String = free[randi() % free.size()]
			es["night"][loc2] = EventService.NIGHT_TRIPS
			text = "Кажуть, над місцевістю %s стоїть глупа ніч: нечисть лютує, та й здобич там удвічі щедріша. Ніч триматиметься %d походи." % [EventService.place(loc2), EventService.NIGHT_TRIPS]
		"trade":
			var best_good := ""
			var best_city := ""
			var best_ratio := 0.0
			for good in Acts.TRADE_ORDER:
				var c := TradeService.best_city(good, city)
				if c == "":
					continue
				var ratio: float = float(Acts.TRADE_CITIES[c][good]) / maxf(0.01, float(Acts.TRADE_CITIES[city][good]))
				if ratio > best_ratio:
					best_ratio = ratio
					best_good = good
					best_city = c
			s["tip"] = {"good": best_good, "city": best_city, "left": Acts.RUMOR_TIP_TRIPS}
			text = "Купець за чаркою прохопився: у місті %s зараз добре платять за %s. Довезеш за %d походи — дадуть на %d%% більше." % [
				Data.place_name(best_city), str(Acts.TRADE_GOODS[best_good]["name"]).to_lower(), Acts.RUMOR_TIP_TRIPS, roundi((Acts.RUMOR_TIP_BONUS - 1.0) * 100.0)]
		"outdoor":
			var os := OutdoorService.state(world)
			os["rich_hunt"] = true
			os["rich_fish"] = true
			os["hunt_ready"] = true
			os["fish_ready"] = true
			text = "Мисливці хваляться: на угіддях повно оленів і вепрів, а на тоні вийшов сом. Наступне полювання й рибалка будуть багатими."
	player.gold -= rumor_cost(player.level)
	s["rumor_done"] = true
	s["rumor_text"] = text
	s["rumors"] = int(s["rumors"]) + 1
	return text


static func tip(world) -> Dictionary:
	return state(world)["tip"]


## Похід минув: у шинку нові язики, торгова порада старіє.
static func tick(world) -> void:
	var s := state(world)
	s["rumor_done"] = false
	var t: Dictionary = s["tip"]
	if not t.is_empty():
		t["left"] = int(t["left"]) - 1
		if int(t["left"]) <= 0:
			s["tip"] = {}
