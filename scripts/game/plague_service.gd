extends RefCounted
## Живий світ: зараза повзе з Московії по мапі. Стан — world.plague:
##   {"levels": {id місцевості: 0..3}, "day": номер походу}
## Після кожного походу зараза може перекинутися на сусідні місцевості. Заражена місцевість
## небезпечніша (сильніші вороги, хмари зарази), але й щедріша. Зачистка відкидає заразу,
## а сюжетні перемоги очищають цілі краї.

const Data := preload("res://scripts/data/data.gd")

const MAX_LEVEL := 3
const NAMES := ["", "слабка", "сильна", "чорна"]
## Звідки повзе зараза (довгота, широта): Москва, Брянськ, Бєлгород
const SOURCES := [Vector2(37.6, 55.75), Vector2(34.4, 53.25), Vector2(36.6, 50.6)]
const SOURCE_RANGE := 4.0  # градусів: місцевості ближче до джерела заражаються самі
const NEIGHBOR_RANGE := 3.6  # з якої відстані перекидається від сусіда
const SPREAD_CHANCE := 0.22
const MAX_SPREAD_PER_TRIP := 2
## Які краї очищає завершення розділу (номер розділу в Story.CHAPTERS)
const CHAPTER_CLEANSE := {
	1: ["wild_field", "rapids", "black_forest", "zmii_cave", "ridne_selo"],
	2: ["polissia", "bilovezha", "crypt", "bryansk_forest", "chaklun_lair"],
	3: ["kamianets_walls", "chornohora", "dovbush_cave", "koshchii_tower"],
	4: ["smolensk_road", "mozhaisk"],
}
const FINAL_CHAPTER := 5  # Путіноїд повалений — зараза зникає всюди


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
	return {"hp": 1.0 + 0.12 * lvl, "dmg": 1.0 + 0.08 * lvl, "reward": 1.0 + 0.25 * lvl,
		"infected": 0.12 * lvl, "cloud_every": 0.0 if lvl < 2 else (11.0 - 3.0 * lvl)}


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


## Розділ сюжету завершено: цілий край очищено, а тиск зарази слабшає.
static func on_chapter_done(world, chapter: int) -> void:
	var s := state(world)
	if chapter >= FINAL_CHAPTER:
		s["levels"] = {}
		s["pressure"] = 0.0
		return
	for id in CHAPTER_CLEANSE.get(chapter, []):
		set_level(world, id, 0)
	s["pressure"] = maxf(0.3, float(s.get("pressure", 1.0)) - 0.15)


## Скільки місцевостей зараз заражено (для інтерфейсу).
static func infected_count(world) -> int:
	var n := 0
	for id in state(world)["levels"]:
		if int(state(world)["levels"][id]) > 0:
			n += 1
	return n
