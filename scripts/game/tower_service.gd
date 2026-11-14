extends RefCounted
## «Башта Кощія» в Москві — безкінечний підйом. Поверх — одна арена: хвилі нечисті й міні-бос
## (іменована еліта з 2–3 властивостями); кожен п'ятий поверх — супербос. Вище — сильніше.
## Відкривається з рівня героя «open_level» і після місії «open_after» (налаштування «tower»; сьогодні — з
## 38-го рівня, після перемоги над Кощієм у його вежі, крок «tower»). Стан — world.tower: {"max": найвищий відкритий, "best": найвищий пройдений}.
## За перше проходження поверху — нагорода; за супербоса — легендарна річ.

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")

const LOC_ID := "bashta"
static var OPEN_LEVEL: int  # з якого рівня героя відкрита Башта
static var OPEN_AFTER: String  # після якої місії відкрита Башта ("" — без місії)
static var SUPER_EVERY: int  # кожен такий поверх — супербос
static var BASE_LEVEL: int  # рівень нечисті поверху = це + номер поверху


# Числа з формул цього скрипта (налаштування, як і решта вище).
static var WAVES_BASE: int  # хвиль на поверсі: base + поверх / waves_every, не більше waves_max
static var WAVES_EVERY: int  # ще одна хвиля за кожні стільки поверхів
static var WAVES_MAX: int  # найбільше хвиль на поверсі
static var MINI_AFFIXES: int  # властивостей міні-боса поверху
static var MINI_AFFIXES_FROM: int  # з цього поверху міні-бос має mini_affixes_top властивостей
static var MINI_AFFIXES_TOP: int  # властивостей міні-боса на високих поверхах
static var ELITE_BASE: float  # надбавка до шансу еліти: основа + elite_per_floor × поверх, не більше elite_max
static var ELITE_PER_FLOOR: float  # приріст шансу еліти за поверх
static var ELITE_MAX: float  # найбільша надбавка до шансу еліти
static var HP_PER_FLOOR: float  # нечисть здоровіша на цю частку за кожен поверх
static var DMG_PER_FLOOR: float  # і б'є сильніше на цю частку за кожен поверх
static var DMG_PER_RING: float  # і ще на стільки за кожні super_every пройдених поверхів
static var XP_PER_FLOOR: float  # досвіду більше на цю частку за кожен поверх
static var BOSS_HP_MULT: float  # бос поверху у стільки разів здоровіший
static var BOSS_DMG_MULT: float  # і б'є у стільки разів сильніше
static var GOLD_BASE: int  # гривні за перше проходження: (base + per_floor × поверх) × рівень / gold_level_div (супербос × gold_super)
static var GOLD_PER_FLOOR: int  # приріст нагороди за поверх
static var GOLD_LEVEL_DIV: int  # дільник рівня в нагороді
static var GOLD_SUPER: int  # супербос дає у стільки разів більше


## Числа-правила вище лежать у data/settings.json (запис «tower»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("tower")
	OPEN_LEVEL = S["open_level"]
	OPEN_AFTER = S["open_after"]
	SUPER_EVERY = S["super_every"]
	BASE_LEVEL = S["base_level"]
	WAVES_BASE = S["waves_base"]
	WAVES_EVERY = S["waves_every"]
	WAVES_MAX = S["waves_max"]
	MINI_AFFIXES = S["mini_affixes"]
	MINI_AFFIXES_FROM = S["mini_affixes_from"]
	MINI_AFFIXES_TOP = S["mini_affixes_top"]
	ELITE_BASE = S["elite_base"]
	ELITE_PER_FLOOR = S["elite_per_floor"]
	ELITE_MAX = S["elite_max"]
	HP_PER_FLOOR = S["hp_per_floor"]
	DMG_PER_FLOOR = S["dmg_per_floor"]
	DMG_PER_RING = S["dmg_per_ring"]
	XP_PER_FLOOR = S["xp_per_floor"]
	BOSS_HP_MULT = S["boss_hp_mult"]
	BOSS_DMG_MULT = S["boss_dmg_mult"]
	GOLD_BASE = S["gold_base"]
	GOLD_PER_FLOOR = S["gold_per_floor"]
	GOLD_LEVEL_DIV = S["gold_level_div"]
	GOLD_SUPER = S["gold_super"]


## З кого складаються поверхи — у записі Башти (data/places.json, «floors»): рядова нечисть,
## супербоси по черзі й прізвиська міні-босів (сотники Кощієвої раті).
static func pool() -> Array:
	return Data.place(LOC_ID)["floors"]["pool"]


static func super_bosses() -> Array:
	return Data.place(LOC_ID)["floors"]["bosses"]


static func mini_titles() -> Array:
	return Data.place(LOC_ID)["floors"]["titles"]


static func state(world) -> Dictionary:
	if world.tower.is_empty():
		world.tower = {"max": 1, "best": 0}
	return world.tower


## world = null — без світу: Башта з місією в умові тоді закрита.
static func unlocked(player, world = null) -> bool:
	return open_at(world, int(player.level))


## Чи Башта відкрита героєві цього рівня: рівень не менший за OPEN_LEVEL і місію OPEN_AFTER здано.
static func open_at(world, lvl: int) -> bool:
	return load("res://scripts/game/unlock_rule.gd").open(world, lvl, OPEN_LEVEL, OPEN_AFTER)


## Чого бракує, щоб Башта відкрилась, одним реченням ("" — відкрита). Наприклад, «Відкриється з 38-го рівня героя.»
static func lock_text(world, lvl: int, verb: String = "Відкриється", short: bool = false) -> String:
	return load("res://scripts/game/unlock_rule.gd").text(world, lvl, OPEN_LEVEL, OPEN_AFTER, verb, short)


static func is_super(floor_: int) -> bool:
	return floor_ % SUPER_EVERY == 0


## Рівень нечисті на поверсі: росте без межі, по рівню на поверх.
static func level_of(floor_: int) -> int:
	return BASE_LEVEL + floor_


## Рівень здобичі на поверсі: не вище за Data.ENDLESS_SOFT.
static func loot_level(floor_: int) -> int:
	return mini(Data.ENDLESS_SOFT, level_of(floor_))


static func waves_of(floor_: int) -> int:
	return mini(WAVES_MAX, WAVES_BASE + floor_ / WAVES_EVERY)


static func super_boss(floor_: int) -> String:
	var b := super_bosses()
	return b[(floor_ / SUPER_EVERY - 1) % b.size()]


## Опис поверху (як місце в data/places.json; бій — тип "tower").
static func loc_for(floor_: int) -> Dictionary:
	var lvl := level_of(floor_)
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_ * 104729
	var mix := pool().duplicate()
	for i in range(mix.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = mix[i]
		mix[i] = mix[j]
		mix[j] = t
	var sup := is_super(floor_)
	var ring := floor_ / SUPER_EVERY  # скільки кіл по 5 поверхів уже пройдено
	return {"name": "Башта, поверх %d" % floor_, "type": "tower", "biome": "plague" if sup else "cave",
		"level": lvl, "loot_level": loot_level(floor_), "floor": floor_, "waves": waves_of(floor_), "enemies": mix.slice(0, 3),
		"boss": super_boss(floor_) if sup else "", "mini": mix[3],
		"mini_title": mini_titles()[(floor_ - 1) % mini_titles().size()],
		"mini_affixes": MINI_AFFIXES if floor_ < MINI_AFFIXES_FROM else MINI_AFFIXES_TOP,
		"elite_bonus": minf(ELITE_MAX, ELITE_BASE + ELITE_PER_FLOOR * floor_),
		# Вище — нечисть лютіша понад свій рівень. Надбавки малі: сама мірка нечисті росте з рівнем поверху.
		# Понад 99-й рівень здоров'я й удар ще й множаться за кожен рівень (Data.endless_hp, endless_dmg): вершини нема.
		"hp_mult": (1.0 + HP_PER_FLOOR * floor_) * Data.endless_hp(lvl), "dmg_mult": (1.0 + DMG_PER_FLOOR * floor_ + DMG_PER_RING * ring) * Data.endless_dmg(lvl), "xp_mult": 1.0 + XP_PER_FLOOR * floor_,
		"boss_hp_mult": BOSS_HP_MULT, "boss_dmg_mult": BOSS_DMG_MULT,
		"desc": "Кістяна башта Кощія посеред Москви. Що вище — то лютіше."}


## Поверх пройдено: відкривається наступний. Повертає [повідомлення, перше проходження?].
static func on_clear(world, floor_: int) -> Array:
	var s := state(world)
	var first: bool = floor_ > int(s["best"])
	s["best"] = maxi(int(s["best"]), floor_)
	if floor_ >= int(s["max"]):
		s["max"] = floor_ + 1
	var msg := "Поверх %d пройдено!" % floor_
	if first:
		msg += "\nВідкрито поверх %d" % (floor_ + 1) if floor_ + 1 == int(s["max"]) else ""
	return [msg, first]


## Нагорода за перше проходження поверху: гривні (супербос — більше).
static func first_gold(floor_: int) -> int:
	return (GOLD_BASE + GOLD_PER_FLOOR * floor_) * level_of(floor_) / GOLD_LEVEL_DIV * (GOLD_SUPER if is_super(floor_) else 1)
