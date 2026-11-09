extends RefCounted
## Оборона міст і хутора. Коли зараза підповзає до міста (або до розбудованого хутора),
## його беруть в облогу. Козак має кілька походів, щоб прийти на поміч: бій біля брами
## хвилями ворогів. Перемога — лояльність, гривні, ресурси; поразка чи запізнення — місто
## пограбоване (усе дорожче на кілька походів), хутір утрачає частину запасів.
##
## Стан — world.defense: {"sieges": {ціль: походів_лишилось}, "ruined": {місто: походів},
##                         "won": n, "lost": n, "calm": походів_без_облог}

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const PlagueService := preload("res://scripts/game/plague_service.gd")
const StoryService := preload("res://scripts/game/story_service.gd")

const CHANCE := 0.22  # шанс нової облоги після походу
const CALM := 3  # походів спокою після кожної облоги
const DEADLINE := 3  # скільки походів місто протримається саме
const THREAT_RANGE := 4.0  # градусів: заражена місцевість ближче — місту загрожує облога
const WAVES := 4
const RUIN_TRIPS := 3
const RUIN_MARKUP := 0.3  # пограбоване місто: усе дорожче


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
		return Camp.CAMP["name"]
	return Data.CITIES[target]["name"]


## Міста, яким зараз загрожує облога (поруч заражені місцевості).
static func threatened(world, player) -> Array:
	var out := []
	var levels: Dictionary = PlagueService.state(world)["levels"]
	for city in Data.CITIES:
		if int(Data.CITIES[city]["level"]) > player.level + 2:
			continue
		var pos: Vector2 = Data.CITIES[city]["pos"]
		for loc in levels:
			if int(levels[loc]) > 0 and Data.LOCATIONS.has(loc) and pos.distance_to(Data.LOCATIONS[loc]["pos"]) < THREAT_RANGE:
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
	if randf() >= CHANCE:
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
	var base_lvl: int = 2 if target == Camp.CAMP_ID else int(Data.CITIES[target]["level"])
	var lvl := maxi(base_lvl, player.level - 1)
	var enemies := ["zarazhenyi", "zarazhenyi", "upyr", "vovkulaka"]
	if lvl >= 8:
		enemies = ["zarazhenyi", "pishchalnyk", "vovkulaka", "upyr"]
	if lvl >= 13:
		enemies = ["zarazhenyi", "pishchalnyk", "chort", "vovkulaka"]
	var camp := target == Camp.CAMP_ID
	return {"name": ("Оборона хутора" if camp else "Оборона: " + name_of(target)), "type": "defense", "biome": "steppe",
		"level": lvl, "enemies": enemies, "waves": WAVES, "target": target, "camp": camp,
		"gate_hp": 600.0 + 120.0 * lvl, "desc": ""}


static func win(world, player, target: String) -> String:
	var s := state(world)
	s["sieges"].erase(target)
	s["won"] = int(s["won"]) + 1
	var g: int = 40 * player.level
	player.gold += g
	if target == Camp.CAMP_ID:
		for r in Camp.RESOURCES:
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
		for r in Camp.RESOURCES:
			player.resources[r] = int(int(player.resources.get(r, 0)) * 0.7)
		return "%s — хутір пограбовано, втрачено третину запасів." % why
	s["ruined"][target] = RUIN_TRIPS
	world.loyalty[target] = maxi(0, world.loyalty_points(target) - 60)
	return "%s — %s пограбовано: ціни вищі ще %d походи, лояльність −60." % [why, name_of(target), RUIN_TRIPS]


## Надбавка до цін у пограбованому місті (0 — як звичайно).
static func markup(world, city: String) -> float:
	return RUIN_MARKUP if state(world)["ruined"].has(city) else 0.0
