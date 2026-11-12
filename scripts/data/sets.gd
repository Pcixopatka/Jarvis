extends RefCounted
## Набори речей. У наборі шість речей: зброя, шапка, жупан, пояс, чоботи й оберіг.
## Падають лише в надважких печерах (див. SetService). Сама річ набору кидається як легендарна,
## але з іменем набору й властивостями з його переліку. Вдягнені разом речі одного набору дають
## бонуси за 2, 4 й 6 речей; бонуси складаються.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")

const RARITY := 3
const COLOR := Data.SET_COLOR  # колір назви й клітинки речі набору
const MARK := "✦"
const STEPS := [2, 4, 6]  # щаблі бонусу: кожен набір у sets.json має саме ці (перевіряє GameDB.problems())
## Шанс речі набору: з надважкого боса, з елітної нечисті надважкої печери.
## Перша перемога над кожним надважким босом дає річ набору напевно.
static var BOSS_CHANCE: float  # шанс речі набору з надважкого боса (перша перемога — напевно)
static var ELITE_CHANCE: float  # шанс речі набору з елітної нечисті надважкої печери
## Яку річ дадуть: набір під головну рису класу й річ, якої ще нема, трапляються частіше.
static var W_CLASS: float  # вага набору під головну рису класу (решта — 1)
static var W_NEW: float  # вага речі набору, якої ще нема (решта — 1)


## Числа-правила вище лежать у data/settings.json (запис «sets»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("sets")
	BOSS_CHANCE = S["boss_chance"]
	ELITE_CHANCE = S["elite_chance"]
	W_CLASS = S["w_class"]
	W_NEW = S["w_new"]


## Записи — у data/sets.json (набори: назва, родовий відмінок, головна риса класу «stat», з яких бонусів
## кидаються властивості «affixes», бонуси за 2, 4 і 6 речей) і data/set_effects.json (тексти бонусів).


## Запис набору (sets.json); для невідомого — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.item_set(id)


## Усі набори в порядку файлу.
static func ids() -> Array:
	return GameDB.ids("sets")


## Бонус набору за step вдягнених речей: {ключ: відсотки} (порожній, якщо такого щабля нема).
static func bonus(set_id: String, step: int) -> Dictionary:
	for st in GameDB.item_set(set_id).get("bonus", []):
		if int(st["pieces"]) == step:
			return st["fx"]
	return {}


## Текст бонусу набору з %s (відсотки).
static func fx_text(key: String) -> String:
	return str(GameDB.row("set_effects", key)["text"])


## Скільки речей якого набору вдягнено на герої, чиї показники рахувались останніми (для картки речі).
static var worn := {}


static func is_set(item: Dictionary) -> bool:
	return item.has("set") and GameDB.table("sets").has(str(item["set"]))


static func set_of(item: Dictionary) -> String:
	return str(item["set"]) if is_set(item) else ""


## Назва речі набору: «Шабля Святогора», «Пояс Довбуша».
static func piece_name(set_id: String, slot: String, type: String = "") -> String:
	var base: String = Data.weapon_name(type) if slot == "weapon" and Data.has_weapon(type) else Data.slot_name(slot)
	return "%s %s" % [base, str(GameDB.item_set(set_id)["of"])]


## Створює річ набору для клітинки slot (зброї потрібен вид type).
static func make(set_id: String, slot: String, ilvl: int, type: String = "") -> Dictionary:
	var it := Data.gen_item(ilvl, RARITY, slot, type)
	var pool: Array = GameDB.item_set(set_id)["affixes"].duplicate()
	pool.erase(Data.slot_primary(slot))
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
		for st in GameDB.item_set(id)["bonus"]:
			if int(n[id]) >= int(st["pieces"]):
				var B: Dictionary = st["fx"]
				for k in B:
					out[k] = float(out.get(k, 0.0)) + float(B[k])
	return out


## Бонус одного щабля словами: «+8% шкоди, +4% захисту».
static func step_text(set_id: String, step: int) -> String:
	var parts := []
	var B: Dictionary = bonus(set_id, step)
	for k in B:
		parts.append(fx_text(k) % str(int(B[k])))
	return ", ".join(parts)
