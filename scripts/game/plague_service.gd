extends RefCounted
## Живий світ: зараза повзе з Московії по мапі. Стан — world.plague:
##   {"levels": {id місцевості: 0..3}, "day": номер походу}
## Після кожного походу зараза може перекинутися на сусідні місцевості. Заражена місцевість
## небезпечніша (сильніші вороги, хмари зарази), але й щедріша. Зачистка відкидає заразу,
## а сюжетні перемоги очищають цілі краї.

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")
const Story := preload("res://scripts/data/story.gd")

const MAX_LEVEL := 3
const NAMES := ["", "слабка", "сильна", "чорна"]
## Звідки повзе зараза (довгота, широта): Москва, Брянськ, Бєлгород
const SOURCES := [Vector2(37.6, 55.75), Vector2(34.4, 53.25), Vector2(36.6, 50.6)]
static var SOURCE_RANGE: float  # градусів мапи: місцевості ближче до джерела зарази заражаються самі
static var NEIGHBOR_RANGE: float  # градусів мапи: з якої відстані зараза перекидається від сусіда
static var SPREAD_CHANCE: float  # шанс, що зараза перекинеться на сусіда після походу
static var MAX_SPREAD_PER_TRIP: int  # не більше стількох нових чи посилених місцевостей за похід


# Числа з формул цього скрипта (налаштування, як і решта вище).
static var PRESSURE_DROP: float  # після кожного розділу історії тиск зарази слабшає на стільки…
static var PRESSURE_MIN: float  # …але не нижче цього
static var HP_PER_LEVEL: float  # нечисть здоровіша на цю частку за кожен рівень зарази місцевості
static var DMG_PER_LEVEL: float  # і б'є сильніше на цю частку за кожен рівень зарази
static var REWARD_PER_LEVEL: float  # нагорода більша на цю частку за кожен рівень зарази
static var INFECTED_PER_LEVEL: float  # шанс, що нечисть заражена, за кожен рівень зарази
static var CLOUD_FROM: int  # з цього рівня зарази на арені з'являються хмари зарази
static var CLOUD_BASE: float  # хмара раз на (cloud_base − cloud_step × рівень зарази) секунд
static var CLOUD_STEP: float  # на стільки секунд частіше хмари за кожен рівень зарази


## Числа-правила вище лежать у data/settings.json (запис «plague»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("plague")
	SOURCE_RANGE = S["source_range"]
	NEIGHBOR_RANGE = S["neighbor_range"]
	SPREAD_CHANCE = S["spread_chance"]
	MAX_SPREAD_PER_TRIP = S["max_spread_per_trip"]
	PRESSURE_DROP = S["pressure_drop"]
	PRESSURE_MIN = S["pressure_min"]
	HP_PER_LEVEL = S["hp_per_level"]
	DMG_PER_LEVEL = S["dmg_per_level"]
	REWARD_PER_LEVEL = S["reward_per_level"]
	INFECTED_PER_LEVEL = S["infected_per_level"]
	CLOUD_FROM = S["cloud_from"]
	CLOUD_BASE = S["cloud_base"]
	CLOUD_STEP = S["cloud_step"]


static func state(world) -> Dictionary:
	if world.plague.is_empty():
		world.plague = {"levels": start_levels(), "day": 0, "pressure": 1.0}
	return world.plague


## Зараза на початку гри: {id місця: рівень} з «plague_start» у data/places.json (порядок файлу).
static func start_levels() -> Dictionary:
	var out := {}
	for id in Data.place_ids():
		if Data.place(id).has("plague_start"):
			out[id] = int(Data.place(id)["plague_start"])
	return out


static func level(world, loc: String) -> int:
	if Data.place(loc).get("endless", false):
		return 0  # старі збереження: зараза на Башті й Глибинах більше не діє (вона ще й сильнішала босів дня)
	return int(state(world)["levels"].get(loc, 0))


static func set_level(world, loc: String, lvl: int) -> void:
	state(world)["levels"][loc] = clampi(lvl, 0, MAX_LEVEL)


## Як зараза змінює місцевість: множники здоров'я/шкоди ворогів і нагороди, шанс зараженого.
static func mods(lvl: int) -> Dictionary:
	return {"hp": 1.0 + HP_PER_LEVEL * lvl, "dmg": 1.0 + DMG_PER_LEVEL * lvl, "reward": 1.0 + REWARD_PER_LEVEL * lvl,
		"infected": INFECTED_PER_LEVEL * lvl, "cloud_every": 0.0 if lvl < CLOUD_FROM else (CLOUD_BASE - CLOUD_STEP * lvl)}


## Похід завершено — зараза повзе далі. Повертає список назв нових/посилених місць.
static func tick(world) -> Array:
	var s := state(world)
	s["day"] = int(s["day"]) + 1
	var pressure: float = float(s.get("pressure", 1.0))
	if pressure <= 0.0:
		return []
	var levels: Dictionary = s["levels"]
	var spread := []
	var ids := Data.place_ids().duplicate()
	ids.shuffle()
	for id in ids:
		if spread.size() >= MAX_SPREAD_PER_TRIP:
			break
		var lvl := int(levels.get(id, 0))
		var L: Dictionary = Data.place(id)
		if lvl >= MAX_LEVEL or L.has("peril") or L.get("endless", false):
			continue  # надважкі печери за краєм мапи; Башту й Глибини зачистити не можна, тож зараза там не осідає
		var pos: Vector2 = L["pos"]
		var chance := 0.0
		for src in SOURCES:
			if pos.distance_to(src) < SOURCE_RANGE:
				chance += SPREAD_CHANCE
		for other in levels:
			if other != id and int(levels[other]) > lvl and Data.is_place(other) \
					and pos.distance_to(Data.place(other)["pos"]) < NEIGHBOR_RANGE:
				chance += SPREAD_CHANCE * 0.5 * (int(levels[other]) - lvl)
		if randf() < minf(0.6, chance * pressure):
			levels[id] = lvl + 1
			spread.append(L["name"])
	return spread


## Зачистка відкидає заразу. Повертає новий рівень.
static func cleanse(world, loc: String, amount: int = 1) -> int:
	var lvl := maxi(0, level(world, loc) - amount)
	set_level(world, loc, lvl)
	return lvl


## Розділ сюжету (номер у data/story_chapters.json) завершено: цілий край очищено («cleanse» розділу),
## а тиск зарази слабшає; після розділу з «cleanse_all» (Путіноїд повалений) зараза зникає всюди.
static func on_chapter_done(world, chapter: int) -> void:
	var s := state(world)
	var ch: Dictionary = Story.chapter(chapter)
	if ch.get("cleanse_all", false):
		s["levels"] = {}
		s["pressure"] = 0.0
		return
	for id in ch.get("cleanse", []):
		set_level(world, id, 0)
	s["pressure"] = maxf(PRESSURE_MIN, float(s.get("pressure", 1.0)) - PRESSURE_DROP)


## Скільки місцевостей зараз заражено (для інтерфейсу).
static func infected_count(world) -> int:
	var n := 0
	for id in state(world)["levels"]:
		if int(state(world)["levels"][id]) > 0:
			n += 1
	return n
