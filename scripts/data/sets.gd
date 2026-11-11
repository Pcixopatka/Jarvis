extends RefCounted
## Набори речей. У наборі шість речей: зброя, шапка, жупан, пояс, чоботи й оберіг.
## Падають лише в надважких печерах (див. SetService). Сама річ набору кидається як легендарна,
## але з іменем набору й властивостями з його переліку. Вдягнені разом речі одного набору дають
## бонуси за 2, 4 й 6 речей; бонуси складаються.

const Data := preload("res://scripts/data/data.gd")

const RARITY := 3
const COLOR := Data.SET_COLOR  # колір назви й клітинки речі набору
const MARK := "✦"
const STEPS := [2, 4, 6]
## Шанс речі набору: з надважкого боса, з елітної нечисті надважкої печери.
## Перша перемога над кожним надважким босом дає річ набору напевно.
const BOSS_CHANCE := 0.25
const ELITE_CHANCE := 0.03
## Яку річ дадуть: набір під головну рису класу й річ, якої ще нема, трапляються частіше.
const W_CLASS := 4.0
const W_NEW := 4.0

## Бонуси наборів: текст (число у відсотках).
const FX := {
	"dmg": "+%s%% шкоди",
	"hp": "+%s%% здоров'я",
	"armor": "+%s%% захисту",
	"aspd": "+%s%% швидкості удару",
	"crit": "+%s%% шансу криту",
	"crit_dmg": "+%s%% шкоди критичного удару",
	"speed": "+%s%% швидкості бігу",
	"skill": "+%s%% сили вмінь",
	"cd": "вміння відновлюються на %s%% швидше",
	"big_dmg": "+%s%% шкоди елітам і босам",
}

## stat — головна риса, під яку набір зібрано; affixes — з цих властивостей кидаються три на кожну річ.
const SETS := {
	"sviatohor": {"name": "Спадок Святогора", "of": "Святогора", "stat": "str",
		"affixes": ["str", "vit", "hp", "armor", "dmg_pct"],
		"bonus": {2: {"hp": 8}, 4: {"dmg": 8, "armor": 4}, 6: {"dmg": 10, "hp": 8, "big_dmg": 10}},
		"lore": "Святогора не носила земля, такий він був дужий. Силу свою він передав тому, хто не побоявся її взяти."},
	"dovbush": {"name": "Убір Довбуша", "of": "Довбуша", "stat": "agi",
		"affixes": ["agi", "crit", "aspd", "dmg_pct", "speed"],
		"bonus": {2: {"aspd": 6}, 4: {"crit": 6, "speed": 6}, 6: {"dmg": 8, "crit_dmg": 30}},
		"lore": "Олекса Довбуш ходив горами швидше за погоню й бив раніше, ніж його помічали."},
	"boian": {"name": "Шати Віщого Бояна", "of": "Бояна", "stat": "spi",
		"affixes": ["spi", "skill_power", "skill_cd", "hp", "crit"],
		"bonus": {2: {"skill": 8}, 4: {"cd": 8, "hp": 6}, 6: {"skill": 14, "dmg": 6}},
		"lore": "Боян, Велесів онук, співав так, що слово ставало ділом. Його шати пам'ятають кожне замовляння."},
}
const ORDER := ["sviatohor", "dovbush", "boian"]

## Скільки речей якого набору вдягнено на герої, чиї показники рахувались останніми (для картки речі).
static var worn := {}


static func is_set(item: Dictionary) -> bool:
	return item.has("set") and SETS.has(str(item["set"]))


static func set_of(item: Dictionary) -> String:
	return str(item["set"]) if is_set(item) else ""


## Назва речі набору: «Шабля Святогора», «Пояс Довбуша».
static func piece_name(set_id: String, slot: String, type: String = "") -> String:
	var base: String = str(Data.WEAPON_TYPES[type]["name"]) if slot == "weapon" and Data.WEAPON_TYPES.has(type) else str(Data.SLOT_NAMES[slot])
	return "%s %s" % [base, str(SETS[set_id]["of"])]


## Створює річ набору для клітинки slot (зброї потрібен вид type).
static func make(set_id: String, slot: String, ilvl: int, type: String = "") -> Dictionary:
	var it := Data.gen_item(ilvl, RARITY, slot, type)
	var pool: Array = SETS[set_id]["affixes"].duplicate()
	pool.erase(Data.SLOT_PRIMARY[slot])
	pool.shuffle()
	var affixes := {}
	for i in mini(RARITY, pool.size()):
		affixes[pool[i]] = Data._roll_value(pool[i], ilvl, RARITY)
	it["affixes"] = affixes
	it["set"] = set_id
	it["name"] = piece_name(set_id, slot, str(it["type"]))
	return it


## Скільки речей кожного набору вдягнено: {набір: кількість}.
static func count(equipment: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipment:
		var id := set_of(equipment[slot])
		if id != "":
			out[id] = int(out.get(id, 0)) + 1
	return out


## Сума бонусів усіх наборів за вдягненим: {ключ: відсотки}.
static func fx(equipment: Dictionary) -> Dictionary:
	var out := {}
	var n := count(equipment)
	for id in n:
		var B: Dictionary = SETS[id]["bonus"]
		for step in STEPS:
			if int(n[id]) >= int(step):
				for k in B[step]:
					out[k] = float(out.get(k, 0.0)) + float(B[step][k])
	return out


## Бонус одного щабля словами: «+8% шкоди, +4% захисту».
static func step_text(set_id: String, step: int) -> String:
	var parts := []
	var B: Dictionary = SETS[set_id]["bonus"][step]
	for k in B:
		parts.append(str(FX[k]) % str(int(B[k])))
	return ", ".join(parts)
