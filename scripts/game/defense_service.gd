extends RefCounted
## Оборона міст і хутора. Коли зараза підповзає до міста (або до розбудованого хутора),
## його беруть в облогу. Козак має кілька походів, щоб прийти на поміч: бій біля брами
## хвилями ворогів. Перемога — лояльність, гривні, ресурси; поразка чи запізнення — місто
## пограбоване (усе дорожче на кілька походів), хутір утрачає частину запасів.
##
## Стан — world.defense: {"sieges": {ціль: походів_лишилось}, "ruined": {місто: походів},
##                         "won": n, "lost": n, "calm": походів_без_облог}

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const PlagueService := preload("res://scripts/game/plague_service.gd")
const StoryService := preload("res://scripts/game/story_service.gd")

static var CHANCE: float  # шанс нової облоги після походу
static var CHANCE_WANTED: float  # шанс облоги, коли її просить виклик тижня
static var CALM: int  # походів спокою після кожної облоги
static var DEADLINE: int  # скільки походів місто протримається саме
static var THREAT_RANGE: float  # градусів мапи: заражена місцевість ближче — місту загрожує облога
static var WAVES: int  # хвиль у бою біля брами
static var RUIN_TRIPS: int  # стільки походів місто лишається пограбованим
static var RUIN_MARKUP: float  # у пограбованому місті все дорожче на цю частку


## Числа-правила вище лежать у data/settings.json (запис «defense»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("defense")
	CHANCE = S["chance"]
	CHANCE_WANTED = S["chance_wanted"]
	CALM = S["calm"]
	DEADLINE = S["deadline"]
	THREAT_RANGE = S["threat_range"]
	WAVES = S["waves"]
	RUIN_TRIPS = S["ruin_trips"]
	RUIN_MARKUP = S["ruin_markup"]


static func state(world) -> Dictionary:
	if world.defense.is_empty():
		world.defense = {"sieges": {}, "ruined": {}, "won": 0, "lost": 0, "calm": CALM}
	return world.defense


static func is_besieged(world, target: String) -> bool:
	return state(world)["sieges"].has(target)


static func trips_left(world, target: String) -> int:
	return int(state(world)["sieges"].get(target, 0))


static func name_of(target: String) -> String:
	if target == Camp.CAMP_ID:
		return Camp.camp()["name"]
	return Data.city(target)["name"]


## Міста, яким зараз загрожує облога (поруч заражені місцевості).
static func threatened(world, player) -> Array:
	var out := []
	var levels: Dictionary = PlagueService.state(world)["levels"]
	for city in Data.city_ids():
		if int(Data.city(city)["level"]) > player.level + 2:
			continue
		var pos: Vector2 = Data.city(city)["pos"]
		for loc in levels:
			if int(levels[loc]) > 0 and Data.is_place(loc) and pos.distance_to(Data.place(loc)["pos"]) < THREAT_RANGE:
				out.append(city)
				break
	return out


## Похід скінчився: облоги наближаються, можливо, починається нова. Повертає повідомлення.
static func tick(world, player) -> Array:
	var s := state(world)
	var msgs := []
	for city in s["ruined"].keys():
		s["ruined"][city] = int(s["ruined"][city]) - 1
		if int(s["ruined"][city]) <= 0:
			s["ruined"].erase(city)
	for target in s["sieges"].keys():
		s["sieges"][target] = int(s["sieges"][target]) - 1
		if int(s["sieges"][target]) <= 0:
			msgs.append(lose(world, player, target, true))
	if player.is_peasant() or int(StoryService.state(world)["chapter"]) < 1:
		return msgs
	if not s["sieges"].is_empty():
		return msgs
	if int(s["calm"]) > 0:
		s["calm"] = int(s["calm"]) - 1
		return msgs
	# Виклик тижня просить відстояти облогу: нечисть не бариться
	var wanted: bool = load("res://scripts/game/challenge_service.gd").pending(world, "defense")
	if randf() >= (CHANCE_WANTED if wanted else CHANCE):
		return msgs
	var options := threatened(world, player)
	if load("res://scripts/game/camp_service.gd").built_count(world) > 0:
		options.append(Camp.CAMP_ID)
	if options.is_empty():
		return msgs
	var target: String = options[randi() % options.size()]
	s["sieges"][target] = DEADLINE
	s["calm"] = CALM
	msgs.append("Заражені облягають: %s!\nПоспіши на оборону — протримаються %d походи." % [name_of(target), DEADLINE])
	return msgs


## Опис бою біля брами (як місцевість, але з хвилями).
static func battle_loc(world, target: String, player) -> Dictionary:
	var base_lvl: int = 2 if target == Camp.CAMP_ID else int(Data.city(target)["level"])
	var lvl := maxi(base_lvl, player.level - 1)
	var enemies := ["zarazhenyi", "zarazhenyi", "upyr", "vovkulaka"]
	if lvl >= 8:
		enemies = ["zarazhenyi", "pishchalnyk", "vovkulaka", "upyr"]
	if lvl >= 13:
		enemies = ["zarazhenyi", "pishchalnyk", "chort", "vovkulaka"]
	var camp := target == Camp.CAMP_ID
	# нечисть не слабша за мірку для рівня героя; брама міцнішає разом із нею
	var Far = load("res://scripts/game/far_service.gd")
	var lift: Dictionary = Far.event_mods(player)
	var out := {"name": ("Оборона хутора" if camp else "Оборона: " + name_of(target)), "type": "defense", "biome": "steppe",
		"level": lvl, "enemies": enemies, "waves": WAVES, "target": target, "camp": camp,
		"gate_hp": (600.0 + 120.0 * lvl) * Far.guard_mult(lvl, lift), "desc": ""}
	out.merge(lift)
	return out


static func win(world, player, target: String) -> String:
	var s := state(world)
	s["sieges"].erase(target)
	s["won"] = int(s["won"]) + 1
	var g: int = 40 * player.level
	player.gold += g
	player.resources["trophy"] = int(player.resources.get("trophy", 0)) + 2
	if target == Camp.CAMP_ID:
		for r in Camp.resources():
			player.resources[r] = int(player.resources.get(r, 0)) + 3 + player.level / 3
		return "Хутір відстояно! +%d грн і трофейні ресурси" % g
	world.add_loyalty(target, 80)
	return "%s відстояно! +%d грн, +80 лояльності" % [name_of(target), g]


## Поразка (брама впала або козак не встиг).
static func lose(world, player, target: String, late: bool = false) -> String:
	var s := state(world)
	s["sieges"].erase(target)
	s["lost"] = int(s["lost"]) + 1
	var why := "Не встиг на поміч" if late else "Браму зламано"
	if target == Camp.CAMP_ID:
		for r in Camp.resources():
			player.resources[r] = int(int(player.resources.get(r, 0)) * 0.7)
		return "%s — хутір пограбовано, втрачено третину запасів." % why
	s["ruined"][target] = RUIN_TRIPS
	world.loyalty[target] = maxi(0, world.loyalty_points(target) - 60)
	return "%s — %s пограбовано: ціни вищі ще %d походи, лояльність −60." % [why, name_of(target), RUIN_TRIPS]


## Надбавка до цін у пограбованому місті (0 — як звичайно).
static func markup(world, city: String) -> float:
	return RUIN_MARKUP if state(world)["ruined"].has(city) else 0.0
