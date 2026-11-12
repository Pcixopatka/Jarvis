extends RefCounted
## Артефакти: трофеї босів, що діють, поки просто лежать у торбі героя.
## У кожного боса свій артефакт. Другий такий самий не діє; у скрині артефакт спить.

const GameDB := preload("res://scripts/core/game_db.gd")

const RARITY := 5
const SLOT := "artifact"
## Шанс трофея з господаря лігва за одну перемогу. Повторів нема: що вже лежить у торбі, удруге не падає.
const CHANCE := 0.04
const CHANCE_TOWER := 0.06  # супербос Башти
const CHANCE_GREY := 0.02  # бос, значно слабший за героя (див. Uniques.LEVEL_GAP)
const CHANCE_PERIL := 0.08  # надважкий бос у своїй печері
## Доля трофея: кожна перемога над босом без його артефакта наближає удачу саме з цим босом.
## Без цього кожен десятий гравець бив одного боса понад 59 разів, а кожен сотий понад 113 (tools/loot_probe.gd).
## Із цими числами трофей у середньому за 17 перемог (без долі було 25), кожен десятий чекає понад 36,
## найдовше 61.
const LUCK_STEP := 30.0  # за стільки перемог без трофея шанс подвоюється
const LUCK_SURE := 60  # стільки перемог поспіль без трофея, і наступна дає його напевно

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
