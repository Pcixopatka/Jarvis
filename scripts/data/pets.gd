extends RefCounted
## Улюбленці героя. Живуть на хуторі (спільні для роду), кожен герой бере з собою одного.
## Улюбленця купують за гривні й ресурси, а потім годують: кожен ступінь (до MAX_LEVEL) підсилює його хист.
## Сили в бою улюбленець не додає: він помічник у дорозі й у господарстві.
##
## Записи — у data/pets.json (див. docs/data.md): улюбленці стайні мають «stable»:
##   stat — що дає: pickup (радіус збору), travel (швидкість дороги мапою), xp (досвід), res (шанс ресурсу з нечисті);
##   base — надбавка на першому ступені, per — приріст за кожен наступний (частки);
##   gold, res — ціна першого ступеня; кожен наступний коштує стільки ж, помножене на номер ступеня.
## У тому ж файлі — супутники з божих дарів («gift»). Хто ходить за героєм у бою, має «mechanic».
## Тут лише правила ступенів і зручні виклики.

const GameDB := preload("res://scripts/core/game_db.gd")

static var MAX_LEVEL: int  # найвищий ступінь улюбленця


## Числа-правила вище лежать у data/settings.json (запис «party»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("party")
	MAX_LEVEL = S["pet_max_level"]


static var _ids: Array = []


## Улюбленці стайні в порядку файлу (без дарів).
static func ids() -> Array:
	if _ids.is_empty():
		for id in GameDB.pet_ids():
			if GameDB.pet(id).has("stable"):
				_ids.append(id)
		_ids.make_read_only()
	return _ids


## Запис улюбленця (data/pets.json); для невідомого — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.pet(id)


## Чи це улюбленець стайні (його купують і годують).
static func is_stable(id: String) -> bool:
	return GameDB.pet(id).has("stable")


static func pet_name(id: String) -> String:
	return str(GameDB.pet(id).get("name", ""))


## Що дає: pickup, travel, xp чи res.
static func stat(id: String) -> String:
	return str(GameDB.pet(id)["stable"]["stat"])


## Улюбленець стайні, що ходить за героєм у бою (пес, кіт, ворон; кінь — ні).
static func follows(id: String) -> bool:
	var R: Dictionary = GameDB.pet(id)
	return R.has("stable") and R.has("mechanic")


## Супутник із божого дару в гнізді slot, що ходить за героєм у бою (Хованець, скакун, мажа).
static func gift_follows(id: String, slot: String) -> bool:
	var R: Dictionary = GameDB.pet(id)
	if not R.has("gift") or not R.has("mechanic"):
		return false
	return str(GameDB.gift(id).get("slot", "")) == slot


static func value(id: String, level: int) -> float:
	if not is_stable(id) or level <= 0:
		return 0.0
	var D: Dictionary = GameDB.pet(id)["stable"]
	return float(D["base"]) + float(D["per"]) * (mini(level, MAX_LEVEL) - 1)


static func text(id: String, level: int) -> String:
	return str(GameDB.pet(id)["stable"]["text"]) % roundi(value(id, level) * 100.0)


## Ціна ступеня level (1 — купівля): {"gold", ресурс: скільки}.
static func cost(id: String, level: int) -> Dictionary:
	var D: Dictionary = GameDB.pet(id)["stable"]
	var out := {"gold": int(D["gold"]) * level}
	for r in D["res"]:
		out[r] = int(D["res"][r]) * level
	return out
