extends RefCounted
## Зачарування речей. На кожній легендарній, золотій чи наборній речі може лежати одне зачарування:
## особлива властивість, якої не буває серед звичайних. Накладає коваль на хуторі за трофеї й ресурси;
## нове зачарування замінює старе. На речах 100-го рівня й вище (здобич надважких печер) воно сильніше.
## Записи — у data/enchants.json: slots — на що лягає; fx — ключ і сила (ті самі ключі, що в пасивних умінь:
## data/effects.json). Порядок файлу — порядок у кузні.

const GameDB := preload("res://scripts/core/game_db.gd")

static var MIN_RARITY: int  # зачаровують речі від цієї рідкості
static var STRONG_LEVEL: int  # з цього рівня речі зачарування сильніше
static var STRONG_MULT: float  # у стільки разів сильніше зачарування на речах від strong_level
## Ціна: трофеї, гривні й ресурс за рівень речі.
static var TROPHY_BASE: int  # ціна: трофеї — основа
static var TROPHY_PER_LEVEL: float  # і ще стільки трофеїв за рівень речі
static var GOLD_PER_LEVEL: int  # гривень за рівень речі
static var RES_PER_LEVEL: int  # ресурсу за рівень речі


## Числа-правила вище лежать у data/settings.json (запис «enchants»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("enchants")
	MIN_RARITY = S["min_rarity"]
	STRONG_LEVEL = S["strong_level"]
	STRONG_MULT = S["strong_mult"]
	TROPHY_BASE = S["trophy_base"]
	TROPHY_PER_LEVEL = S["trophy_per_level"]
	GOLD_PER_LEVEL = S["gold_per_level"]
	RES_PER_LEVEL = S["res_per_level"]


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
