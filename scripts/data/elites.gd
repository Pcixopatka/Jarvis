extends RefCounted
## Елітна нечисть: рідкісні сильніші вороги з властивостями. Більший шанс у зараженій місцевості.

static var CHANCE: float  # базовий шанс, що звичайний ворог — еліта
static var CHANCE_PER_PLAGUE: float  # і ще стільки за кожен рівень зарази місцевості
static var MIN_LEVEL: int  # у місцях нижче цього рівня еліт немає
static var SECOND_AFFIX_LEVEL: int  # з цього рівня місцевості еліта може мати дві властивості
static var HP_MULT: float  # еліта у стільки разів здоровіша
static var DMG_MULT: float  # і б'є у стільки разів сильніше
static var XP_MULT: int  # і дає у стільки разів більше досвіду (ціле)
static var ITEM_CHANCE: float  # шанс речі з еліти


## Числа-правила вище лежать у data/settings.json (запис «elites»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("elites")
	CHANCE = S["chance"]
	CHANCE_PER_PLAGUE = S["chance_per_plague"]
	MIN_LEVEL = S["min_level"]
	SECOND_AFFIX_LEVEL = S["second_affix_level"]
	HP_MULT = S["hp_mult"]
	DMG_MULT = S["dmg_mult"]
	XP_MULT = S["xp_mult"]
	ITEM_CHANCE = S["item_chance"]


const GameDB := preload("res://scripts/core/game_db.gd")
const _EMPTY := {}


## Властивість еліти (data/elite_affixes.json): name {m, f}, color, status (стан, який накладає кожен
## удар), desc. Решта особливих правил — у коді (див. enemy.gd).
static func affix(id: String) -> Dictionary:
	return GameDB.table("elite_affixes").get(id, _EMPTY)


static func is_affix(id: String) -> bool:
	return GameDB.table("elite_affixes").has(id)


## Властивості в порядку файлу (лише для читання; щоб перетасувати — duplicate()).
static func affix_ids() -> Array:
	return GameDB.ids("elite_affixes")


## Нечисть жіночого роду («feminine» у data/mobs.json): «Крижана Мавка», «переможена».
static func is_feminine(kind: String) -> bool:
	return bool(GameDB.mob(kind).get("feminine", false))


static func chance(loc_level: int, plague: int) -> float:
	if loc_level < MIN_LEVEL:
		return 0.0
	return CHANCE + CHANCE_PER_PLAGUE * plague


static func roll_affixes(loc_level: int) -> Array:
	var keys := affix_ids().duplicate()
	keys.shuffle()
	var n := 2 if loc_level >= SECOND_AFFIX_LEVEL and randf() < 0.5 else 1
	return keys.slice(0, n)


## «Вогняний залізний Упир», «Крижана Мавка».
static func title(kind: String, base_name: String, affixes: Array) -> String:
	var g := "f" if is_feminine(kind) else "m"
	var words := []
	for i in affixes.size():
		var w: String = affix(affixes[i])["name"][g]
		words.append(w if i == 0 else w.to_lower())
	words.append(base_name)
	return " ".join(words)
