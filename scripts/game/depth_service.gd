extends RefCounted
## «Глибини зарази» — гра після сюжету. Під Кремлем лишилися корені зарази: печера без дна.
## Кожна глибина — печера, сильніша за попередню (рівень, кімнати, еліти, боси); пройшов —
## відкривається наступна. Стан — world.depths: {"max": найглибша відкрита, "best": найглибша пройдена}.

const Data := preload("res://scripts/data/data.gd")
const StoryService := preload("res://scripts/game/story_service.gd")

const LOC_ID := "hlybyny"
const BOSSES := ["zmii", "upyr", "vovkulaka", "chaklun", "koshchii", "putinoid"]
const POOL := ["zarazhenyi", "pishchalnyk", "chort", "upyr", "vovkulaka", "bolotianyk", "mavka"]
const BASE_LEVEL := 22


static func state(world) -> Dictionary:
	if world.depths.is_empty():
		world.depths = {"max": 1, "best": 0}
	return world.depths


## Глибини відкриваються після перемоги над Путіноїдом.
static func unlocked(world) -> bool:
	return StoryService.state(world)["stage"] == "done"


static func level_of(depth: int) -> int:
	return mini(Data.Classes.BASE_LEVEL_MAX, BASE_LEVEL + 2 * (depth - 1))


## Опис печери на цій глибині (як місцевість у Data.LOCATIONS).
static func loc_for(depth: int) -> Dictionary:
	var lvl := level_of(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = depth * 7919
	var pool := POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return {"name": "Глибина %d" % depth, "type": "dungeon", "biome": "plague" if depth % 3 != 0 else "cave",
		"level": lvl, "rooms": mini(8, 4 + depth / 5), "enemies": pool.slice(0, 3),
		"boss": BOSSES[(depth - 1) % BOSSES.size()], "depth": depth,
		"elite_bonus": minf(0.25, 0.04 + 0.01 * depth),
		# Глибше — нечисть лютіша понад свій рівень (і щедріша на досвід). Надбавки малі: сама мірка нечисті
		# тепер росте разом із рівнем глибини (Data.enemy_std_*), а не лінійно, як раніше.
		"hp_mult": 1.1 + 0.02 * depth, "dmg_mult": 1.05 + 0.01 * depth, "xp_mult": 1.0 + 0.05 * depth,
		"desc": "Корені зарази під Кремлем. Що глибше — то лютіше."}


## Глибину пройдено: відкривається наступна. Повертає повідомлення.
static func on_clear(world, depth: int) -> String:
	var s := state(world)
	s["best"] = maxi(int(s["best"]), depth)
	if depth >= int(s["max"]):
		s["max"] = depth + 1
		return "Глибину %d пройдено! Відкрито глибину %d" % [depth, depth + 1]
	return "Глибину %d пройдено!" % depth
