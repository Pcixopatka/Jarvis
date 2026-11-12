extends RefCounted
## Зачарування речей. На кожній легендарній, золотій чи наборній речі може лежати одне зачарування:
## особлива властивість, якої не буває серед звичайних. Накладає коваль на хуторі за трофеї й ресурси;
## нове зачарування замінює старе. На речах 100-го рівня й вище (здобич надважких печер) воно сильніше.
## Записи — у data/enchants.json: slots — на що лягає; fx — ключ і сила (ті самі ключі, що в пасивних умінь:
## data/effects.json). Порядок файлу — порядок у кузні.

const GameDB := preload("res://scripts/core/game_db.gd")

const MIN_RARITY := 3  # зачаровують лише легендарне й краще
const STRONG_LEVEL := 100  # з цього рівня речі зачарування сильніше
const STRONG_MULT := 1.5
## Ціна: трофеї, гривні й ресурс за рівень речі.
const TROPHY_BASE := 20
const TROPHY_PER_LEVEL := 0.4
const GOLD_PER_LEVEL := 400
const RES_PER_LEVEL := 6
const RES := {"weapon": "iron", "amulet": "herbs"}  # решта речей просить дерево


## Запис зачарування (enchants.json); для невідомого — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.enchant(id)


static func has(id: String) -> bool:
	return GameDB.table("enchants").has(id)


## Усі зачарування в порядку файлу.
static func ids() -> Array:
	return GameDB.ids("enchants")


static func mult(item: Dictionary) -> float:
	return STRONG_MULT if int(item.get("ilvl", 1)) >= STRONG_LEVEL else 1.0


## Які зачарування лягають на цю річ.
static func options(item: Dictionary) -> Array:
	var out := []
	for id in ids():
		if str(item.get("slot", "")) in GameDB.enchant(id)["slots"]:
			out.append(id)
	return out


## Сила зачарування id на цій речі: {ключ: значення}.
static func fx_of(item: Dictionary, id: String) -> Dictionary:
	var out := {}
	var D: Dictionary = GameDB.enchant(id)
	if D.is_empty():
		return out
	for k in D["fx"]:
		out[k] = float(D["fx"][k]) * mult(item)
	return out


static func cost(item: Dictionary) -> Dictionary:
	var lvl: int = int(item.get("ilvl", 1))
	var res: String = str(RES.get(str(item.get("slot", "")), "wood"))
	return {"gold": GOLD_PER_LEVEL * lvl, "trophy": TROPHY_BASE + int(TROPHY_PER_LEVEL * lvl), res: RES_PER_LEVEL * lvl}
