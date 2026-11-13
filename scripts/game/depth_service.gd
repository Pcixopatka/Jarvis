extends RefCounted
## «Глибини зарази» — гра після сюжету. Під Кремлем лишилися корені зарази: печера без дна.
## Кожна глибина — печера, сильніша за попередню (рівень, кімнати, еліти, боси); пройшов —
## відкривається наступна. Стан — world.depths: {"max": найглибша відкрита, "best": найглибша пройдена}.

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")
const StoryService := preload("res://scripts/game/story_service.gd")

const LOC_ID := "hlybyny"
static var BASE_LEVEL: int  # рівень нечисті на першій глибині


# Числа з формул цього скрипта (налаштування, як і решта вище).
static var LEVEL_STEP: int  # рівнів нечисті за кожну наступну глибину
static var ROOMS_BASE: int  # кімнат: base + глибина / rooms_every, не більше rooms_max
static var ROOMS_EVERY: int  # ще одна кімната за кожні стільки глибин
static var ROOMS_MAX: int  # найбільше кімнат
static var ELITE_BASE: float  # надбавка до шансу еліти: основа + elite_per_depth × глибина, не більше elite_max
static var ELITE_PER_DEPTH: float  # приріст шансу еліти за глибину
static var ELITE_MAX: float  # найбільша надбавка до шансу еліти
static var HP_BASE: float  # множник здоров'я нечисті: base + hp_per_depth × глибина
static var HP_PER_DEPTH: float  # приріст множника здоров'я за глибину
static var DMG_BASE: float  # множник удару: base + dmg_per_depth × глибина
static var DMG_PER_DEPTH: float  # приріст множника удару за глибину
static var XP_PER_DEPTH: float  # досвіду більше на цю частку за кожну глибину


## Числа-правила вище лежать у data/settings.json (запис «depths»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("depths")
	BASE_LEVEL = S["base_level"]
	LEVEL_STEP = S["level_step"]
	ROOMS_BASE = S["rooms_base"]
	ROOMS_EVERY = S["rooms_every"]
	ROOMS_MAX = S["rooms_max"]
	ELITE_BASE = S["elite_base"]
	ELITE_PER_DEPTH = S["elite_per_depth"]
	ELITE_MAX = S["elite_max"]
	HP_BASE = S["hp_base"]
	HP_PER_DEPTH = S["hp_per_depth"]
	DMG_BASE = S["dmg_base"]
	DMG_PER_DEPTH = S["dmg_per_depth"]
	XP_PER_DEPTH = S["xp_per_depth"]


## З кого складаються глибини — у записі Глибин (data/places.json, «floors»): рядова нечисть і боси по черзі.
static func pool() -> Array:
	return Data.place(LOC_ID)["floors"]["pool"]


static func bosses() -> Array:
	return Data.place(LOC_ID)["floors"]["bosses"]


static func state(world) -> Dictionary:
	if world.depths.is_empty():
		world.depths = {"max": 1, "best": 0}
	return world.depths


## Глибини відкриваються після перемоги над Путіноїдом.
static func unlocked(world) -> bool:
	return StoryService.finished(world)


## Рівень нечисті на глибині: росте без межі, по два рівні на глибину.
static func level_of(depth: int) -> int:
	return BASE_LEVEL + LEVEL_STEP * (depth - 1)


## Рівень здобичі на глибині: не вище за Data.ENDLESS_SOFT.
static func loot_level(depth: int) -> int:
	return mini(Data.ENDLESS_SOFT, level_of(depth))


## Опис печери на цій глибині (як місце в data/places.json).
static func loc_for(depth: int) -> Dictionary:
	var lvl := level_of(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = depth * 7919
	var mix := pool().duplicate()
	for i in range(mix.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = mix[i]
		mix[i] = mix[j]
		mix[j] = t
	return {"name": "Глибина %d" % depth, "type": "dungeon", "biome": "plague" if depth % 3 != 0 else "cave",
		"level": lvl, "loot_level": loot_level(depth), "rooms": mini(ROOMS_MAX, ROOMS_BASE + depth / ROOMS_EVERY), "enemies": mix.slice(0, 3),
		"boss": bosses()[(depth - 1) % bosses().size()], "depth": depth,
		"elite_bonus": minf(ELITE_MAX, ELITE_BASE + ELITE_PER_DEPTH * depth),
		# Глибше — нечисть лютіша понад свій рівень (і щедріша на досвід). Надбавки малі: сама мірка нечисті
		# тепер росте разом із рівнем глибини (Data.enemy_std_*), а не лінійно, як раніше.
		# Понад 99-й рівень здоров'я й удар ще й множаться за кожен рівень (Data.endless_hp, endless_dmg): дна нема.
		"hp_mult": (HP_BASE + HP_PER_DEPTH * depth) * Data.endless_hp(lvl), "dmg_mult": (DMG_BASE + DMG_PER_DEPTH * depth) * Data.endless_dmg(lvl), "xp_mult": 1.0 + XP_PER_DEPTH * depth,
		"desc": "Корені зарази під Кремлем. Що глибше — то лютіше."}


## Глибину пройдено: відкривається наступна. Повертає повідомлення.
static func on_clear(world, depth: int) -> String:
	var s := state(world)
	s["best"] = maxi(int(s["best"]), depth)
	if depth >= int(s["max"]):
		s["max"] = depth + 1
		return "Глибину %d пройдено! Відкрито глибину %d" % [depth, depth + 1]
	return "Глибину %d пройдено!" % depth
