extends RefCounted
## Крамниця за донат: усе рідкісне за окрему валюту, червінці.
## Червінці купують за справжні гроші наборами (див. Billing); вони спільні для всіх героїв роду.

const COIN := "червінці"
const COIN_SHORT := "черв."

## Чи продаються червінці за справжні гроші. ТИМЧАСОВЕ рішення власника гри: купівлю наборів вимкнено.
## Червінці, що вже є на рахунку, лишаються й витрачаються, як раніше. Щоб повернути продаж, постав true
## (робоче значення лежить у ShopService.coins_on_sale, його читають служба, екран крамниці й довідник).
static var COINS_ON_SALE: bool  # чи продаються набори червінців (вимикач продажу)


## Числа-правила вище лежать у data/settings.json (запис «shop»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("shop")
	COINS_ON_SALE = S["coins_on_sale"]


## Записи — у таблицях: набори червінців у data/coin_packs.json (id — назва товару в магазині застосунків;
## price — орієнтовна ціна справжніми грошима, справжню показує магазин; bonus — скільки відсотків червінців
## понад найменший набір), розділи крамниці у data/shop_kinds.json (назва вкладки й ціни артефакта та
## речей набору), ціни золотих речей і душ — у їхніх ступенях (golden_tiers.json, soul_tiers.json).

const GameDB := preload("res://scripts/core/game_db.gd")


## Набори червінців у порядку файлу.
static func pack_ids() -> Array:
	return GameDB.ids("coin_packs")


## Набір червінців: {name, coins, bonus, price}; для невідомого — порожній.
static func pack(id: String) -> Dictionary:
	return GameDB.row("coin_packs", id)


## Розділи крамниці за порядком вкладок.
static func kinds() -> Array:
	return GameDB.ids("shop_kinds")


static func kind_name(kind: String) -> String:
	return str(GameDB.row("shop_kinds", kind)["name"])


## Ціни розділу: price (артефакт, річ набору), peril_price (артефакт надважкого боса), full_price (увесь набір).
static func kind_price(kind: String, field: String = "price") -> int:
	return int(GameDB.row("shop_kinds", kind).get(field, 0))
