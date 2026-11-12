extends RefCounted
## Артефакти: трофеї босів, що діють, поки просто лежать у торбі героя.
## У кожного боса свій артефакт. Другий такий самий не діє; у скрині артефакт спить.

const GameDB := preload("res://scripts/core/game_db.gd")

const RARITY := 5
const SLOT := "artifact"
## Шанс трофея з господаря лігва за одну перемогу. Повторів нема: що вже лежить у торбі, удруге не падає.
static var CHANCE: float  # шанс трофея з господаря лігва за одну перемогу
static var CHANCE_TOWER: float  # шанс артефакта із супербоса Башти
static var CHANCE_GREY: float  # шанс артефакта з боса, значно слабшого за героя (golden.level_gap)
static var CHANCE_PERIL: float  # шанс артефакта з надважкого боса в його печері
## Доля трофея: кожна перемога над босом без його артефакта наближає удачу саме з цим босом.
## Без цього кожен десятий гравець бив одного боса понад 59 разів, а кожен сотий понад 113 (tools/loot_probe.gd).
## Із цими числами трофей у середньому за 17 перемог (без долі було 25), кожен десятий чекає понад 36,
## найдовше 61.
static var LUCK_STEP: float  # за стільки перемог без трофея шанс подвоюється
static var LUCK_SURE: int  # стільки перемог поспіль без трофея — і наступна дає його напевно


## Числа-правила вище лежать у data/settings.json (запис «artifacts»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("artifacts")
	CHANCE = S["chance"]
	CHANCE_TOWER = S["chance_tower"]
	CHANCE_GREY = S["chance_grey"]
	CHANCE_PERIL = S["chance_peril"]
	LUCK_STEP = S["luck_step"]
	LUCK_SURE = S["luck_sure"]


## Записи — у data/artifacts.json: назва, чий трофей («boss»), бонуси («bonus»: ключ → значення, їх читають
## Player і служби), текст і переказ.


## Запис артефакта (artifacts.json); для невідомого — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.artifact(id)


## Усі артефакти в порядку файлу.
static func ids() -> Array:
	return GameDB.ids("artifacts")


static func is_artifact(item: Dictionary) -> bool:
	return item.has("artifact") and GameDB.table("artifacts").has(str(item["artifact"]))


static func make(id: String) -> Dictionary:
	return {"slot": SLOT, "type": "", "name": GameDB.artifact(id)["name"], "rarity": RARITY, "ilvl": 1, "up": 0, "spent": 0,
		"artifact": id, "base": {}, "affixes": {}}


## Артефакт цього боса ("" — у боса свого трофея нема).
static func by_boss(kind: String) -> String:
	for id in ids():
		if GameDB.artifact(id)["boss"] == kind:
			return id
	return ""


## Які артефакти діють: кожен вид один раз.
static func active_ids(inventory: Array) -> Array:
	var out := []
	for it in inventory:
		if is_artifact(it) and not str(it["artifact"]) in out:
			out.append(str(it["artifact"]))
	return out


## Сума бонусів усіх різних артефактів у торбі: {ключ: значення}.
static func mods(inventory: Array) -> Dictionary:
	var out := {}
	for id in active_ids(inventory):
		var b: Dictionary = GameDB.artifact(id)["bonus"]
		for k in b:
			out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out


static func has(inventory: Array, id: String) -> bool:
	return id in active_ids(inventory)
