extends RefCounted
## Стан світу: лояльність міст, дошки завдань, активні завдання, загін, крамниці.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const StoryService := preload("res://scripts/game/story_service.gd")
const DefenseService := preload("res://scripts/game/defense_service.gd")
const Acts := preload("res://scripts/data/activities.gd")
const EscortService := preload("res://scripts/game/escort_service.gd")

var loyalty := {}  # місто -> очки
var boards := {}  # місто -> доступні завдання
var quests := []  # активні завдання
var companions := []  # [{"type": "dzhura", "downed": false}]
var cleared := {}  # печера -> скільки разів очищено
var last_city := "sich"
var next_quest_id := 1
var shops := {}  # місто -> товари; оновлюються після походів (shop_dirty)
var shop_dirty := {}  # зберігаються разом зі світом: вихід у головне меню товар не перекидає
var hints := {}  # які підказки вже показано
var missions := {}  # завдання всіх ліній: здані й початі кроки, вибори (див. QuestEngine)
var camp := {}  # хутір: будівлі, пасіка (див. CampService)
var boosts := {}  # нагороди за рекламу: xp2 (секунди), safe_sharpen (жетони)
var ads := {}  # денні ліміти реклами
var stats := {}  # лічильники подій для викликів і досягнень
var challenges := {}  # щоденні/тижневі виклики й відкриті досягнення (див. ChallengeService)
var defense := {}  # облоги міст і хутора (див. DefenseService)
var path_talks := {}  # з ким із представників доріг уже поговорив (див. PathService)
var depths := {}  # Глибини зарази після сюжету (див. DepthService)
var tower := {}  # Башта Кощія в Москві (див. TowerService)
var events := {}  # події світу: набіги, валки, полон, ніч, ярмарок (див. EventService)
var glory := 0  # слава героя (див. GloryService)
var duel := {}  # герць на майдані: тижневий турнір (див. DuelService)
var bounties := {}  # дошка розшуку: оголошення й узяті голови (див. BountyService)
var vigil := {}  # козацька варта: рекорди й оплачені сьогодні хвилини (див. VigilService)
var hero_level := 1  # рівень героя, що зараз грає (виставляє Game; для завдань у далекі краї, у збереження не йде)
var ring := {}  # Коло Кожум'яки: тижневі нагороди, проходження, найкращий час (див. RingService)
var muster := {}  # гетьманський огляд: тижневі сутички ватаг (див. MusterService)
var trade := {}  # чумацький крам: віз, торговий день, угоди (див. TradeService)
var cart_divine := 0  # одиниці краму на возі від божого дару героя, що зараз грає (виставляє DivineService, у збереження не йде)
var chest_divine := 0  # місця в скрині роду від божого дару героя, що зараз грає (так само)
var outdoors := {}  # полювання й рибалка: готовність, улов (див. OutdoorService)
var tavern := {}  # шинок: кості, чутки, торгова порада (див. TavernService)
var way := {}  # «Шлях козака»: на якому кроці герой (див. WayService)
var records := {}  # рекорди роду: посилання на словник акаунта (у збереження персонажа не йде)
var holidays := {}  # жетони свят: теж словник акаунта
var shop := {}  # крамниця за донат: червінці й покупки роду, теж словник акаунта (див. ShopService)
var spec_trial := {}  # випробування в наставника (див. SpecService)
var travel := {}  # події в дорозі: перерва між пригодами (див. TravelService)
var plague := {}  # живий світ: рівні зарази місцевостей (див. PlagueService)
var heroes := {}  # побратими: зустріч, дружба, особисті завдання (див. HeroService)
var fair := {}  # трофейний ярмарок: що взято цього тижня (див. FairService)
var boss_hunt := {}  # бос дня й бос тижня: кого вже переможено й найкращий час (див. BossService)
var peril := {}  # надважкі печери: пройдені, найкращий час, звання (див. PerilService)


# ---------- Лояльність ----------

func loyalty_points(city: String) -> int:
	return loyalty.get(city, 0)


func loyalty_level(city: String) -> int:
	return Data.loyalty_level(loyalty_points(city))


func add_loyalty(city: String, v: int) -> bool:
	var before := loyalty_level(city)
	if v > 0:
		# у День Соборності міста вдячніші; печатка роду діє завжди
		v = int(round(v * (1.0 + load("res://scripts/game/holiday_service.gd").bonus("loyalty") + load("res://scripts/game/kleinod_service.gd").bonus(self, "loyalty"))))
	loyalty[city] = loyalty_points(city) + v
	return loyalty_level(city) > before


func discount(city: String) -> float:
	# Лояльність міста + наслідки сюжетних виборів (напр. вдячний Чигирин)
	var d: float = Data.loyalty_discount(loyalty_level(city))
	# Пограбоване після облоги місто — навпаки, дорожче
	return clampf(d + StoryService.effect(self, "discount_" + city) - DefenseService.markup(self, city), -0.5, 0.6)


# ---------- Завдання ----------

func board(city: String) -> Array:
	if not boards.has(city):
		boards[city] = []
	var b: Array = boards[city]
	while b.size() < 3:
		var q := _gen_quest(city)
		for attempt in 6:
			if not _has_text(b, q["text"]) and not _has_text(quests, q["text"]):
				break
			q = _gen_quest(city)
		b.append(q)
	_ensure_escort(city, b)
	return b


## Виклик дня чи тижня просить супроводу, а його ніде нема (ні на дошках, ні серед узятих):
## одне оголошення цього міста стає супроводом, щоб виклик було де виконати.
func _ensure_escort(city: String, b: Array) -> void:
	if not load("res://scripts/game/challenge_service.gd").pending(self, "escort"):
		return
	for q in quests:
		if EscortService.is_open(q):
			return
	for c in boards:
		for q in boards[c]:
			if EscortService.is_open(q):
				return
	var q := _gen_quest(city, true)
	if q.get("type", "") != "escort":
		return
	for i in range(b.size() - 1, -1, -1):
		if b[i].get("type", "") != "dungeon" or i == 0:
			b[i] = q
			return


func _has_text(list: Array, text: String) -> bool:
	for q in list:
		if q["text"] == text:
			return true
	return false


## want_escort — потрібен саме супровід (його просить виклик): місцевість беремо лише дику.
func _gen_quest(city: String, want_escort: bool = false) -> Dictionary:
	var lvl: int = Data.city(city)["level"] + loyalty_level(city)
	var locs := []
	for id in Data.place_ids():
		if Data.place(id).get("endless", false) or Data.place(id).has("peril"):
			continue  # Глибини й надважкі печери — не для доручень
		if want_escort and (Data.place(id)["type"] == "dungeon" or not Data.place_open(id, hero_level)):
			continue  # супровід, якого просить виклик, — лише туди, куди героя вже пускають
		var l: int = Data.place(id)["level"]
		if l >= lvl - 2 and l <= lvl + 3:
			locs.append(id)
	if locs.is_empty() and want_escort:
		for id in Data.place_ids():
			if Data.place(id)["type"] != "dungeon" and not Data.place(id).get("endless", false) and int(Data.place(id)["level"]) <= lvl + 3 and Data.place_open(id, hero_level):
				locs.append(id)
	if locs.is_empty():
		for id in Data.place_ids():
			if not Data.place(id).has("peril"):
				locs.append(id)
	var loc_id: String = locs[randi() % locs.size()]
	var L: Dictionary = Data.place(loc_id)
	# Печера з босом росте з героєм: нагорода за завдання туди — за його рівнем, обсяг — за рівнем місця
	var eff: int = Data.loc_level(L, hero_level)
	var q := {"id": next_quest_id, "city": city, "loc": loc_id, "progress": 0, "lvl": eff}
	next_quest_id += 1
	var mult := 1.0
	var r := randf()
	if L["type"] == "dungeon" and r < 0.7:
		q["type"] = "dungeon"
		q["target"] = loc_id
		q["count"] = 1
		q["text"] = "Очисти: %s" % L["name"]
		mult = 2.0
	elif L["type"] != "dungeon" and (want_escort or r < Acts.ESCORT_CHANCE):
		EscortService.fill(q, randf())  # проведи мандрівника через цю місцевість
		mult = Acts.ESCORT_MULT
	else:
		var enemies: Array = L["enemies"]
		var e: String = enemies[randi() % enemies.size()]
		q["target"] = e
		if randf() < 0.5:
			q["type"] = "kill"
			q["count"] = 8 + L["level"] * 2
			q["text"] = "Знищ %d %s (%s)" % [q["count"], GameDB.mob_plural(e), L["name"]]
		else:
			q["type"] = "fetch"
			q["count"] = 4 + L["level"] / 2
			q["text"] = "Принеси: %s × %d (%s)" % [GameDB.quest_item(e), q["count"], L["name"]]
	q["gold"] = int((40 + 25 * eff) * mult)
	q["xp"] = int((30 + 20 * eff) * mult)
	q["loyalty"] = int((30 + 5 * L["level"]) * mult)
	return q


func can_take() -> bool:
	return quests.size() < Data.MAX_ACTIVE_QUESTS


## З якого рівня героя завдання можна взяти: з того, з якого пускають у його місце (Data.open_from).
func quest_open_from(q: Dictionary) -> int:
	return Data.open_from(str(q.get("loc", "")))


## Чи завдання з дошки можна взяти героєві рівня lvl: місце, куди воно веде, мусить бути відкрите. Закрите
## висить на дошці сірим із відмовою «Ще зарано» (UiCity), узяти його не можна.
func quest_open(q: Dictionary, lvl: int) -> bool:
	return Data.place_open(str(q.get("loc", "")), lvl)


func take(city: String, qid: int) -> bool:
	if not can_take():
		return false
	var b := board(city)
	for i in b.size():
		if b[i]["id"] == qid:
			if not quest_open(b[i], hero_level):
				return false  # веде в закрите місце: висить на дошці, та взяти ще зарано
			quests.append(b[i])
			b.remove_at(i)
			return true
	return false


func abandon(qid: int) -> void:
	for i in quests.size():
		if quests[i]["id"] == qid:
			quests.remove_at(i)
			return


func is_done(q: Dictionary) -> bool:
	return q["progress"] >= q["count"]


## Повертає завдання, якщо його здано, або порожній словник.
func turn_in(qid: int) -> Dictionary:
	for i in quests.size():
		var q: Dictionary = quests[i]
		if q["id"] == qid and is_done(q):
			quests.remove_at(i)
			return q
	return {}


## Повідомлення для гравця про прогрес завдань після вбивства ворога.
func on_kill(kind: String) -> Array:
	var msgs := []
	for q in quests:
		if is_done(q) or q["target"] != kind:
			continue
		if q["type"] == "kill":
			q["progress"] += 1
		elif q["type"] == "fetch" and randf() < 0.4:
			q["progress"] += 1
			if not is_done(q):
				msgs.append("%s %d/%d" % [GameDB.quest_item(kind), q["progress"], q["count"]])
		if is_done(q):
			msgs.append("Завдання виконано! Здай: %s" % Data.place_name(str(q["city"])))
	return msgs


## Печеру пройдено. Повертає повідомлення про завдання, які цим виконано.
func on_dungeon(loc_id: String) -> Array:
	var msgs := []
	cleared[loc_id] = cleared.get(loc_id, 0) + 1
	for q in quests:
		if q["type"] == "dungeon" and q["target"] == loc_id and not is_done(q):
			q["progress"] = q["count"]
			msgs.append("Завдання виконано! Здай: %s" % Data.place_name(str(q["city"])))
	return msgs


## Місця, куди веде те, що герой уже тримає: невиконане завдання міста (і супровід), жива ціль розшуку, особиста
## справа побратима, випробування наставника й активна мета місії. Таке місце пускає героя й тоді, коли за рівнем
## воно закрите (Data.place_open): узяте до цієї версії гри доводиться до кінця, старе збереження не застрягає.
func held_places() -> Dictionary:
	var out := {}
	for q in quests:
		if not is_done(q):
			out[str(q["loc"])] = true
	for b in bounties.get("active", []):
		if not bool(b.get("killed", false)):
			out[str(b["loc"])] = true
	for loc in load("res://scripts/game/hero_service.gd").targets(self):
		out[str(loc)] = true
	var trial: Dictionary = spec_trial
	if not trial.is_empty() and str(trial.get("stage", "")) == "active":
		out[str(load("res://scripts/game/spec_service.gd").target(self))] = true
	var Q = load("res://scripts/game/quest_engine.gd")
	for id in Q.missions(self):
		if Q.stage(self, id) == "active":
			out[str(Q.step(id).get("objective", {}).get("loc", ""))] = true
	out.erase("")
	return out


## Чи пустять героя рівня lvl у місце id: за рівнем (Data.place_open) або тому, що туди веде вже взяте (held_places).
func can_enter(id: String, lvl: int) -> bool:
	return Data.place_open(id, lvl) or held_places().has(id)


func quest_targets() -> Dictionary:
	var out := {}
	for q in quests:
		if not is_done(q):
			out[q["loc"]] = true
	return out


# ---------- Загін ----------

func revive_companions() -> void:
	for c in companions:
		c["downed"] = false


func has_companion(type: String) -> bool:
	for c in companions:
		if c["type"] == type and c.get("hero", "") == "":  # побратими не займають місце найманця
			return true
	return false


# ---------- Збереження ----------

func to_dict() -> Dictionary:
	return {"shops": shops, "shop_dirty": shop_dirty, "fair": fair, "boss_hunt": boss_hunt, "peril": peril, "loyalty": loyalty, "boards": boards, "quests": quests, "companions": companions,
		"cleared": cleared, "last_city": last_city, "next_quest_id": next_quest_id, "hints": hints, "missions": missions, "camp": camp, "boosts": boosts, "ads": ads, "heroes": heroes, "plague": plague, "travel": travel, "defense": defense, "stats": stats, "challenges": challenges, "spec_trial": spec_trial, "depths": depths, "path_talks": path_talks, "tower": tower, "events": events, "glory": glory, "duel": duel, "bounties": bounties, "vigil": vigil, "ring": ring, "muster": muster, "trade": trade, "outdoors": outdoors, "tavern": tavern, "way": way}


func from_dict(d: Dictionary) -> void:
	shops = d.get("shops", {})
	shop_dirty = d.get("shop_dirty", {})
	peril = d.get("peril", {})
	boss_hunt = d.get("boss_hunt", {})
	fair = d.get("fair", {})
	loyalty = d.get("loyalty", {})
	boards = d.get("boards", {})
	quests = d.get("quests", [])
	companions = d.get("companions", [])
	cleared = d.get("cleared", {})
	last_city = d.get("last_city", "sich")
	next_quest_id = d.get("next_quest_id", 1)
	hints = d.get("hints", {})
	missions = d.get("missions", {})
	camp = d.get("camp", {})
	boosts = d.get("boosts", {})
	ads = d.get("ads", {})
	heroes = d.get("heroes", {})
	plague = d.get("plague", {})
	travel = d.get("travel", {})
	defense = d.get("defense", {})
	stats = d.get("stats", {})
	challenges = d.get("challenges", {})
	spec_trial = d.get("spec_trial", {})
	depths = d.get("depths", {})
	tower = d.get("tower", {})
	events = d.get("events", {})
	glory = int(d.get("glory", 0))
	duel = d.get("duel", {})
	bounties = d.get("bounties", {})
	vigil = d.get("vigil", {})
	ring = d.get("ring", {})
	muster = d.get("muster", {})
	trade = d.get("trade", {})
	outdoors = d.get("outdoors", {})
	tavern = d.get("tavern", {})
	way = d.get("way", {})
	path_talks = d.get("path_talks", {})
