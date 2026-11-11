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

## status — стан, який накладає кожен удар; решта — особливі правила (див. enemy.gd)
const AFFIXES := {
	"fiery": {"m": "Вогняний", "f": "Вогняна", "color": Color(1.0, 0.5, 0.1), "status": "burn", "desc": "підпалює"},
	"plague": {"m": "Зачумлений", "f": "Зачумлена", "color": Color(0.45, 0.9, 0.15), "status": "plague", "desc": "заражає"},
	"frost": {"m": "Крижаний", "f": "Крижана", "color": Color(0.55, 0.85, 1.0), "status": "chill", "desc": "морозить"},
	"swift": {"m": "Швидкий", "f": "Швидка", "color": Color(1.0, 1.0, 0.6), "desc": "дуже швидкий"},
	"iron": {"m": "Залізний", "f": "Залізна", "color": Color(0.72, 0.74, 0.8), "desc": "тримає удар"},
	"vampire": {"m": "Упирячий", "f": "Упиряча", "color": Color(0.85, 0.1, 0.25), "desc": "п'є кров"},
	"explosive": {"m": "Вибуховий", "f": "Вибухова", "color": Color(1.0, 0.3, 0.1), "desc": "вибухає"},
}
const FEMININE := ["mavka", "kamiana_baba", "mara", "kikimora", "samodiva", "lauma", "chud"]


static func chance(loc_level: int, plague: int) -> float:
	if loc_level < MIN_LEVEL:
		return 0.0
	return CHANCE + CHANCE_PER_PLAGUE * plague


static func roll_affixes(loc_level: int) -> Array:
	var keys := AFFIXES.keys()
	keys.shuffle()
	var n := 2 if loc_level >= SECOND_AFFIX_LEVEL and randf() < 0.5 else 1
	return keys.slice(0, n)


## «Вогняний залізний Упир», «Крижана Мавка».
static func title(kind: String, base_name: String, affixes: Array) -> String:
	var g := "f" if kind in FEMININE else "m"
	var words := []
	for i in affixes.size():
		var w: String = AFFIXES[affixes[i]][g]
		words.append(w if i == 0 else w.to_lower())
	words.append(base_name)
	return " ".join(words)
