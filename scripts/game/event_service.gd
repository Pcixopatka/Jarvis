extends RefCounted
## Події світу — те, що трапляється між походами й кличе козака на поміч:
##   бойові (одна за раз, з'являються на мапі значком і мають строк):
##     village_raid — набіг на село біля місцевості: 3 хвилі, треба вберегти хати; не встиг — місцевість спалена;
##     caravan      — чумацька валка між містами: вози їдуть ареною, 4 хвилі; нагорода за вцілілі вози;
##     sich_siege   — велика облога Січі (з розділу III): 6 хвиль і ватажок; програв — Січ зачинена, поки не відіб'єш;
##     captives     — полон: конвой веде бранців у Московію, значок рухається мапою; наздогнав — 3 хвилі;
##     wounded      — поранений козак у полі: вберегти 3 хвилі; вижив — наступний найм безкоштовний;
##   модифікатори місцевостей (можуть бути разом із бойовими):
##     night    — нічний похід: темно, нечисть сильніша, здобич щедріша;
##     treasure — знахідка: сторож скарбу з двома властивостями, після нього — скриня з рідкісною річчю;
##   місто: fair — ярмарок на кілька походів: продаж удвічі дорожчий, у крамниці більше рідкісного;
##   хутір: theft — нічна крадіжка меду між заходами в гру (Курінь 2 захищає).
## Стан — world.events: {"active": {}, "calm": n, "burned": {loc: походів}, "night": {loc: походів},
##   "treasure": {loc: true}, "fair": {"city", "left"}, "free_hire": n, "trips": n, "sich_done": розділ, "freed": n}

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const StoryService := preload("res://scripts/game/story_service.gd")
const DefenseService := preload("res://scripts/game/defense_service.gd")
const GameDB := preload("res://scripts/core/game_db.gd")

const CHANCE := 0.3  # шанс нової бойової події після походу (коли спокійно)
const CALM := 2
## Бойові події, які вміє цей код (start, win, lose). Назва, значок, строк, хвилі, вигляд оборони й
## здоров'я того, що боронять, — запис події в data/events.json («battle»; перевіряє GameDB.problems()).
const BATTLE_KINDS := ["village_raid", "caravan", "sich_siege", "captives", "wounded"]
const BURN_TRIPS := 4
const NIGHT_CHANCE := 0.2
const NIGHT_TRIPS := 2
const TREASURE_CHANCE := 0.15
const FAIR_EVERY := 10
const FAIR_TRIPS := 4
const THEFT_HOURS := 8.0
const THEFT_CHANCE := 0.35
const THEFT_CHANCE_KURIN := 0.1
const THEFT_PART := 0.3
const KREMLIN_LL := Vector2(37.62, 55.75)


## Бойова частина запису події: {"deadline", "waves", "variant", "gate_hp"}.
static func battle_of(kind: String) -> Dictionary:
	return GameDB.row("events", kind).get("battle", {})


static func state(world) -> Dictionary:
	if world.events.is_empty():
		world.events = {"active": {}, "calm": CALM, "burned": {}, "night": {}, "treasure": {}, "fair": {}, "free_hire": 0, "trips": 0, "sich_done": 0, "freed": 0}
	return world.events


static func active(world) -> Dictionary:
	return state(world)["active"]


## Бойова подія, що чекає в цьому місці (порожньо — нема).
static func battle_at(world, id: String) -> Dictionary:
	var a := active(world)
	if a.is_empty() or a.get("target", "") != id:
		return {}
	return a


static func name_of(kind: String) -> String:
	return str(GameDB.row("events", kind).get("name", kind)) if kind in BATTLE_KINDS else kind


static func place(id: String) -> String:
	return Data.place_name(id)


# ---------- Похід скінчився ----------

static func tick(world, player) -> Array:
	var s := state(world)
	var msgs := []
	s["trips"] = int(s["trips"]) + 1
	for d in ["burned", "night"]:
		for loc in s[d].keys():
			s[d][loc] = int(s[d][loc]) - 1
			if int(s[d][loc]) <= 0:
				s[d].erase(loc)
	if not s["fair"].is_empty():
		s["fair"]["left"] = int(s["fair"]["left"]) - 1
		if int(s["fair"]["left"]) <= 0:
			msgs.append("Ярмарок у місті %s закінчився." % place(s["fair"]["city"]))
			s["fair"] = {}
	var a: Dictionary = s["active"]
	if not a.is_empty():
		a["left"] = int(a["left"]) - 1
		if int(a["left"]) <= 0:
			msgs.append(lose(world, player, a, true))
	if player.is_peasant() or int(StoryService.state(world)["chapter"]) < 1:
		return msgs
	# Ярмарок
	if s["fair"].is_empty() and int(s["trips"]) % FAIR_EVERY == 0:
		var cities := Data.city_ids().filter(func(c): return int(Data.city(c)["level"]) <= player.level + 2)
		if not cities.is_empty():
			var city: String = cities[randi() % cities.size()]
			s["fair"] = {"city": city, "left": FAIR_TRIPS}
			msgs.append("Ярмарок у місті %s! Продаж удвічі дорожчий, купці привезли рідкісне. Триватиме %d походи." % [place(city), FAIR_TRIPS])
	# Модифікатори місцевостей
	var locs := reachable_locs(world, player)
	if not locs.is_empty() and randf() < NIGHT_CHANCE:
		var loc: String = locs[randi() % locs.size()]
		if not s["night"].has(loc):
			s["night"][loc] = NIGHT_TRIPS
			msgs.append("Ніч над %s: нечисть лютіша, здобич щедріша (%d походи)." % [place(loc), NIGHT_TRIPS])
	if not locs.is_empty() and s["treasure"].is_empty() and randf() < TREASURE_CHANCE:
		var loc: String = locs[randi() % locs.size()]
		s["treasure"][loc] = true
		msgs.append("Чутка: у місцевості %s закопано скарб, а стереже його люта нечисть." % place(loc))
	# Бойова подія
	if not s["active"].is_empty():
		return msgs
	# Виклик дня чи тижня просить відбити подію: вона приходить одразу, без перепочинку й жеребу
	var wanted: bool = load("res://scripts/game/challenge_service.gd").pending(world, "event")
	if int(s["calm"]) > 0 and not wanted:
		s["calm"] = int(s["calm"]) - 1
		return msgs
	if randf() >= CHANCE and not wanted:
		return msgs
	var kind := pick_kind(world, player)
	if kind == "":
		return msgs
	var m := start(world, player, kind)
	if m == "" and wanted:
		# для цього героя така подія неможлива (нема місцевостей по силі) — валка між містами є завжди
		m = start(world, player, "caravan")
	if m != "":
		msgs.append(m)
	return msgs


## Місцевості (не печери, не безкінечні) по силі герою.
static func reachable_locs(world, player) -> Array:
	var out := []
	for id in Data.place_ids():
		var L: Dictionary = Data.place(id)
		if L["type"] != "field" or L.get("endless", false):
			continue
		var lvl := Data.loc_level(L, player.level)  # далекі краї ростуть із героєм, тож події є й для бувалих
		if lvl <= player.level + 2 and lvl >= player.level - 6:
			out.append(id)
	return out


static func pick_kind(world, player) -> String:
	var s := state(world)
	var chapter := int(StoryService.state(world)["chapter"])
	var pool := ["village_raid", "village_raid", "caravan", "caravan", "wounded"]
	if chapter >= 2:
		pool.append("captives")
	if chapter >= 3 and int(s["sich_done"]) < chapter and not DefenseService.is_besieged(world, "sich"):
		pool.append("sich_siege")
		pool.append("sich_siege")
	return pool[randi() % pool.size()]


## Почати подію (повертає повідомлення; "" — не вийшло).
static func start(world, player, kind: String, target: String = "") -> String:
	var s := state(world)
	var ev := {"kind": kind, "left": int(battle_of(kind)["deadline"])}
	match kind:
		"village_raid", "wounded", "captives":
			if target == "":
				var locs := reachable_locs(world, player)
				if locs.is_empty():
					return ""
				target = locs[randi() % locs.size()]
			ev["target"] = target
			if kind == "captives":
				ev["from"] = target
		"caravan":
			var cities := Data.city_ids().filter(func(c): return int(Data.city(c)["level"]) <= player.level + 2)
			if cities.size() < 2:
				return ""
			var from: String = target if target != "" else cities[randi() % cities.size()]
			var to: String = from
			while to == from:
				to = cities[randi() % cities.size()]
			ev["target"] = from
			ev["to"] = to
		"sich_siege":
			ev["target"] = "sich"
	s["active"] = ev
	s["calm"] = CALM
	match kind:
		"village_raid":
			return "Набіг! Заражені палять село біля %s. Устигни за %d походи, інакше село згорить." % [place(target), ev["left"]]
		"caravan":
			return "Чумаки з міста %s просять супроводу до міста %s. Валка чекає %d походи." % [place(ev["target"]), place(ev["to"]), ev["left"]]
		"sich_siege":
			return "Зараза підступає до Січі! Велика облога: шість хвиль і ватажок. Кошовий кличе всіх козаків."
		"captives":
			return "Нечисть веде бранців із %s у Московію! Наздожени конвой, поки не дійшов до кордону (%d походи)." % [place(target), ev["left"]]
		"wounded":
			return "Поранений козак лежить у місцевості %s. Вбережи його від нечисті (%d походи)." % [place(target), ev["left"]]
	return ""


# ---------- Бій ----------

## Опис бою для події (тип "defense" з варіантом; див. combat.enter_defense і gate.gd).
static func battle_loc(world, ev: Dictionary, player) -> Dictionary:
	var kind: String = ev["kind"]
	var target: String = ev["target"]
	var base_lvl: int = int(Data.city(target)["level"]) if Data.is_city(target) else int(Data.place(target)["level"])
	var lvl := maxi(base_lvl, player.level - 1)
	var enemies := ["zarazhenyi", "zarazhenyi", "upyr", "vovkulaka"]
	if lvl >= 8:
		enemies = ["zarazhenyi", "pishchalnyk", "vovkulaka", "upyr"]
	if lvl >= 13:
		enemies = ["zarazhenyi", "pishchalnyk", "chort", "vovkulaka"]
	var biome := "steppe"
	if Data.is_place(target):
		biome = Data.place(target)["biome"]
		if biome in ["cave", "plague"]:
			biome = "steppe"
	var B := battle_of(kind)
	var variant: String = B["variant"]
	var hp := float(B["gate_hp"][0]) + float(B["gate_hp"][1]) * lvl
	# нечисть не слабша за мірку для рівня героя; те, що він боронить, міцнішає разом із нею
	var Far = load("res://scripts/game/far_service.gd")
	var lift: Dictionary = Far.event_mods(player)
	var out := {"name": name_of(kind) + (": " + place(target) if kind != "sich_siege" else ""), "type": "defense", "biome": biome,
		"level": lvl, "enemies": enemies, "waves": int(B["waves"]), "target": target, "camp": false, "variant": variant,
		"event": kind, "gate_hp": hp * Far.guard_mult(lvl, lift), "desc": ""}
	out.merge(lift)
	return out


static func win(world, player, ev: Dictionary, gate_part: float = 1.0) -> String:
	var s := state(world)
	s["active"] = {}
	var kind: String = ev["kind"]
	var target: String = ev["target"]
	var g: int = 40 * player.level
	match kind:
		"village_raid":
			player.gold += g
			for r in Camp.resources():
				player.resources[r] = int(player.resources.get(r, 0)) + 4 + player.level / 3
			player.resources["trophy"] = int(player.resources.get("trophy", 0)) + 2
			return "Село врятовано! Селяни дякують: +%d грн, дерево, залізо й трави, 2 трофеї." % g
		"caravan":
			var part := clampf(gate_part, 0.3, 1.0)
			var gold := int(80 * player.level * part)
			player.gold += gold
			world.add_loyalty(ev["to"], 40)
			var it := Data.gen_item(maxi(1, player.level), 2 if part >= 0.99 else 1)
			player.add_item(it, true)  # нагорода: за повної торби лягає понад місце, а не зникає
			if part >= 0.99:
				return "Валку довезено цілою! +%d грн, рідкісна річ із краму, +40 лояльності в місті %s." % [gold, place(ev["to"])]
			return "Валку довезено, хоч і побиту: +%d грн, річ із краму, +40 лояльності в місті %s." % [gold, place(ev["to"])]
		"sich_siege":
			s["sich_done"] = int(StoryService.state(world)["chapter"])
			player.gold += g * 2
			player.resources["trophy"] = int(player.resources.get("trophy", 0)) + 5
			world.add_loyalty("sich", 120)
			load("res://scripts/game/stone_service.gd").grant(player, "zabuttia")
			return "Січ відстояно! +%d грн, 5 трофеїв, +120 лояльності й Камінь забуття від кошового." % (g * 2)
		"captives":
			s["freed"] = int(s["freed"]) + 1
			s["free_hire"] = int(s["free_hire"]) + 1
			player.gold += g
			return "Бранців звільнено! Вдячні люди: +%d грн, а один із них стане до тебе на службу задарма (наступний найм безкоштовний)." % g
		"wounded":
			s["free_hire"] = int(s["free_hire"]) + 1
			player.add_item(Data.gen_item(maxi(1, player.level), 1), true)  # дарунок не зникає за повної торби
			return "Козак вижив! Він дарує тобі річ зі своєї торби, а його побратим стане до тебе задарма (наступний найм безкоштовний)."
	return "Перемога!"


static func lose(world, player, ev: Dictionary, late: bool = false) -> String:
	var s := state(world)
	s["active"] = {}
	var kind: String = ev["kind"]
	var target: String = ev["target"]
	var why := "Не встиг" if late else "Не вберіг"
	match kind:
		"village_raid":
			s["burned"][target] = BURN_TRIPS
			return "%s — село біля %s згоріло. Місцевість спалена ще %d походи: менше здобичі, більше нечисті." % [why, place(target), BURN_TRIPS]
		"caravan":
			world.loyalty[ev["to"]] = maxi(0, world.loyalty_points(ev["to"]) - 30)
			return "%s — валку розграбовано. Купці міста %s затаїли образу: −30 лояльності." % [why, place(ev["to"])]
		"sich_siege":
			DefenseService.state(world)["sieges"]["sich"] = 99  # Січ зачинена, поки не відіб'єш
			return "%s — Січ в облозі! Крамниця й наставники зачинені, поки не відіб'єш браму." % why
		"captives":
			return "%s — конвой дійшов до кордону, бранців не повернути." % why
		"wounded":
			return "%s — поранений козак загинув." % why
	return why


## Частка пройденого шляху для конвою з бранцями (значок рухається до Кремля).
static func captives_ll(ev: Dictionary) -> Vector2:
	var from_ll: Vector2 = Data.place(ev["from"])["pos"]
	var t := 1.0 - float(ev["left"]) / float(int(battle_of("captives")["deadline"]) + 1)
	return from_ll.lerp(KREMLIN_LL, t * 0.8)


## Значки подій для мапи: [{"id", "ll", "icon", "label"}].
static func map_marks(world) -> Array:
	var s := state(world)
	var out := []
	var a: Dictionary = s["active"]
	if not a.is_empty():
		var ll: Vector2
		if a["kind"] == "captives":
			ll = captives_ll(a)
		else:
			ll = Data.city(a["target"])["pos"] if Data.is_city(a["target"]) else Data.place(a["target"])["pos"]
		out.append({"id": a["target"], "ll": ll, "icon": str(GameDB.row("events", a["kind"])["icon"]), "label": "%s (%d)" % [name_of(a["kind"]), int(a["left"])], "kind": a["kind"]})
	if not s["fair"].is_empty():
		out.append({"id": s["fair"]["city"], "ll": Data.city(s["fair"]["city"])["pos"], "icon": "tent", "label": "Ярмарок (%d)" % int(s["fair"]["left"]), "kind": "fair"})
	for loc in s["night"]:
		out.append({"id": loc, "ll": Data.place(loc)["pos"], "icon": "moon", "label": "", "kind": "night"})
	for loc in s["treasure"]:
		out.append({"id": loc, "ll": Data.place(loc)["pos"], "icon": "chest", "label": "", "kind": "treasure"})
	for loc in s["burned"]:
		out.append({"id": loc, "ll": Data.place(loc)["pos"], "icon": "raid", "label": "", "kind": "burned"})
	return out


# ---------- Модифікатори місцевостей ----------

static func is_night(world, loc: String) -> bool:
	return state(world)["night"].has(loc)


static func has_treasure(world, loc: String) -> bool:
	return state(world)["treasure"].has(loc)


static func is_burned(world, loc: String) -> bool:
	return state(world)["burned"].has(loc)


## Додаткові поля до опису місцевості для бою (hp_mult, dmg_mult, xp_mult, night, treasure, burned).
static func mods_for(world, loc: String) -> Dictionary:
	var m := {}
	var hp := 1.0
	var dmg := 1.0
	var xp := 1.0
	if is_night(world, loc):
		m["night"] = true
		hp *= 1.3
		dmg *= 1.3
		xp *= 1.5
	if is_burned(world, loc):
		m["burned"] = true
		hp *= 1.2
		xp *= 0.7
	if has_treasure(world, loc):
		m["treasure"] = true
	if hp != 1.0 or dmg != 1.0 or xp != 1.0:
		m["hp_mult"] = hp
		m["dmg_mult"] = dmg
		m["xp_mult"] = xp
	return m


## Скарб знайдено (сторож убитий): знімаємо мітку.
static func treasure_found(world, loc: String) -> void:
	state(world)["treasure"].erase(loc)


## Пояснення для панелі мапи.
static func notes_for(world, loc: String) -> Array:
	var out := []
	if is_night(world, loc):
		out.append(["Ніч: темно, нечисть підтягується до твого рівня й на 30% лютіша, досвід і гривні на 50% щедріші.", "night"])
	if has_treasure(world, loc):
		out.append(["Чутка про скарб: десь тут сторож із двома властивостями, рівня з тобою, а за ним — скриня з рідкісною річчю.", "treasure"])
	if is_burned(world, loc):
		out.append(["Спалене село: менше здобичі й більше нечисті ще %d походи." % int(state(world)["burned"][loc]), "burned"])
	return out


# ---------- Ярмарок і найм ----------

static func fair_city(world) -> String:
	return str(state(world)["fair"].get("city", ""))


static func sell_mult(world, city: String) -> float:
	return 2.0 if fair_city(world) == city else 1.0


static func free_hire(world) -> bool:
	return int(state(world)["free_hire"]) > 0


static func use_free_hire(world) -> void:
	var s := state(world)
	s["free_hire"] = maxi(0, int(s["free_hire"]) - 1)


# ---------- Крадіжка на хуторі ----------

## Викликається при завантаженні: якщо гравця довго не було, мед могли вкрасти. Повертає повідомлення або "".
static func check_theft(world, now: float, kurin_level: int, roll: float = -1.0) -> String:
	if world.camp.is_empty() or int(world.camp.get("buildings", {}).get("pasika", 0)) <= 0:
		return ""
	var ts := float(world.camp.get("pasika_ts", now))
	var hours := (now - ts) / 3600.0
	if hours < THEFT_HOURS:
		return ""
	var chance := THEFT_CHANCE_KURIN if kurin_level >= 2 else THEFT_CHANCE
	if roll < 0.0:
		# злодії приходять щонайбільше раз на добу: раніше кидок ішов при кожному вході в гру,
		# і хто часто заходив, того частіше обкрадали
		var day := int(now / 86400.0)
		if int(world.camp.get("theft_day", -1)) == day:
			return ""
		world.camp["theft_day"] = day
	var r := roll if roll >= 0.0 else randf()
	if r >= chance:
		return ""
	# Крадії забрали частину меду: зсуваємо час останнього збору вперед
	world.camp["pasika_ts"] = ts + (now - ts) * THEFT_PART
	if kurin_level >= 2:
		return "Уночі на пасіку залізли злодії, та курінна варта їх сполохала — пропала лише дещиця меду."
	return "Уночі хутір обікрали: з пасіки зникла третина меду. Курінь 2-го рівня виставить варту."
