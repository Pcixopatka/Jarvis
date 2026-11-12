extends RefCounted
## Вбрання героя: лише вигляд, сили не додає. Купується в крамниці за червінці раз на весь рід,
## вдягає його кожен герой окремо (Player.costume). Вбрання міняє постать цілком, однаково для
## будь-якого класу; зброя в руці лишається та, що вдягнена.
## Листи малює tools/pixel/sprites.py (COSTUMES, ті самі id): costume_<id>_<зброя> і plain_costume_<id>.

## Записи — у data/costumes.json: назва, ціна в червінцях, опис; порядок файлу — порядок у крамниці.

const GameDB := preload("res://scripts/core/game_db.gd")

## Для якої зброї є лист кожного вбрання.
## Це перелік намальованих листів (tools/pixel/sprites.py), а не таблиця: нова зброя без листа малюється з шаблею.
const WEAPONS := ["sabre", "mace", "pike", "staff", "pishchal", "bow", "pistols"]


## Запис вбрання (costumes.json); для невідомого — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.costume(id)


## Усі вбрання в порядку файлу.
static func ids() -> Array:
	return GameDB.ids("costumes")


## Ціна в червінцях (0 — такого нема).
static func price(id: String) -> int:
	return int(GameDB.costume(id).get("price", 0))


static func has(id: String) -> bool:
	return GameDB.table("costumes").has(id)


static func name_of(id: String) -> String:
	return str(GameDB.costume(id)["name"]) if has(id) else "Свій одяг"


## Лист вбрання для зброї в руці ("" — такого листа нема).
static func sprite(id: String, weapon_type: String) -> String:
	if not has(id):
		return ""
	return "costume_%s_%s" % [id, weapon_type if weapon_type in WEAPONS else "sabre"]


## Лист без зброї: для рибалки й мирних занять.
static func plain(id: String) -> String:
	return "plain_costume_" + id if has(id) else ""
