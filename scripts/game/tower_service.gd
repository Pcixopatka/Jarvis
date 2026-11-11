extends RefCounted
## «Башта Кощія» в Москві — безкінечний підйом. Поверх — одна арена: хвилі нечисті й міні-бос
## (іменована еліта з 2–3 властивостями); кожен п'ятий поверх — супербос. Вище — сильніше.
## Відкривається з 15-го рівня героя. Стан — world.tower: {"max": найвищий відкритий, "best": найвищий пройдений}.
## За перше проходження поверху — нагорода; за супербоса — гарантований камінь долі й легендарна річ.

const Data := preload("res://scripts/data/data.gd")

const LOC_ID := "bashta"
const OPEN_LEVEL := 15
const SUPER_EVERY := 5
const BASE_LEVEL := 14  # поверх 1 — рівень 15
const SUPER_BOSSES := ["baba_yaha", "solovei", "lykho", "oprychnyk"]
const POOL := ["zarazhenyi", "pishchalnyk", "chort", "upyr", "vovkulaka", "bolotianyk", "mavka", "chaklun"]
## Прізвиська міні-босів: сотники Кощієвої раті
const MINI_TITLES := ["Сотник", "Осавул раті", "Десятник", "Воєвода поверху", "Кат", "Стражник", "Ключник", "Дозорець"]


static func state(world) -> Dictionary:
	if world.tower.is_empty():
		world.tower = {"max": 1, "best": 0}
	return world.tower


static func unlocked(player) -> bool:
	return player.level >= OPEN_LEVEL


static func is_super(floor_: int) -> bool:
	return floor_ % SUPER_EVERY == 0


static func level_of(floor_: int) -> int:
	return mini(Data.Classes.BASE_LEVEL_MAX, BASE_LEVEL + floor_)


static func waves_of(floor_: int) -> int:
	return mini(4, 2 + floor_ / 10)


static func super_boss(floor_: int) -> String:
	return SUPER_BOSSES[(floor_ / SUPER_EVERY - 1) % SUPER_BOSSES.size()]


## Опис поверху (як місцевість у Data.LOCATIONS; бій — тип "tower").
static func loc_for(floor_: int) -> Dictionary:
	var lvl := level_of(floor_)
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_ * 104729
	var pool := POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var sup := is_super(floor_)
	var ring := floor_ / SUPER_EVERY  # скільки кіл по 5 поверхів уже пройдено
	return {"name": "Башта, поверх %d" % floor_, "type": "tower", "biome": "plague" if sup else "cave",
		"level": lvl, "floor": floor_, "waves": waves_of(floor_), "enemies": pool.slice(0, 3),
		"boss": super_boss(floor_) if sup else "", "mini": pool[3],
		"mini_title": MINI_TITLES[(floor_ - 1) % MINI_TITLES.size()],
		"mini_affixes": 2 if floor_ < 20 else 3,
		"elite_bonus": minf(0.3, 0.05 + 0.01 * floor_),
		# Вище — нечисть лютіша понад свій рівень. Надбавки малі: сама мірка нечисті росте з рівнем поверху.
		"hp_mult": 1.0 + 0.012 * floor_, "dmg_mult": 1.0 + 0.006 * floor_ + 0.01 * ring, "xp_mult": 1.0 + 0.05 * floor_,
		"boss_hp_mult": 2.2, "boss_dmg_mult": 1.35,
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
	return (60 + 12 * floor_) * level_of(floor_) / 4 * (3 if is_super(floor_) else 1)
