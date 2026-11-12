extends RefCounted
## Елітна нечисть: рідкісні сильніші вороги з властивостями. Більший шанс у зараженій місцевості.

const CHANCE := 0.04  # базовий шанс, що звичайний ворог — еліта
const CHANCE_PER_PLAGUE := 0.025
const MIN_LEVEL := 4  # у найперших місцях еліт немає
const SECOND_AFFIX_LEVEL := 8  # з цього рівня місцевості еліта може мати дві властивості
const HP_MULT := 2.6
const DMG_MULT := 1.25
const XP_MULT := 3
const ITEM_CHANCE := 0.35

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
