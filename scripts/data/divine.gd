extends RefCounted
## Божі дари: речі з крамниці за червінці. Вдягаються у власні гнізда на екрані героя, поруч зі
## звичайним спорядженням, і не займають місця в торбі. Купуються раз на весь рід, вдягає кожен герой окремо.
## У гнізді лежить один дар. Де дарів на гніздо два (Супутник, Реліквія), герой обирає між ними.
## На відміну від вбрання, дари дають силу й зручність. Поля запису (data/gifts.json):
##   slot — гніздо; icon — значок (tools/pixel/icons.py); price — червінці;
##   pickup — у скільки разів більший радіус збору (надбавка), shop — чи дає крамницю будь-де,
##   loot — здобич одразу лягає в торбу, на землю падає лише те, що нема куди покласти (Combat.spawn_pickup),
##   bag — місця в торбі, trade (одиниці краму до місткості воза в чумацькому торзі, TradeService.capacity), stats — частка до всіх чотирьох характеристик,
##   xp, gold — частка до досвіду й гривень, revive — з якою часткою здоров'я дар раз на бій піднімає героя,
##   party — частка до шкоди й здоров'я побратимів, sight — чи показує стрілкою еліту,
##   light — у скільки разів далі світить смолоскип уночі й у печерах,
##   auto_buffs: бафи з нижньої панелі бою вмикаються самі (DivineService.auto_buff_tick),
##   fx — бойові показники (ключі бонусів data/effects.json, як у пасивних умінь); lines — рядки опису.

## Чи продаються божі дари за червінці. ТИМЧАСОВЕ рішення власника гри: купівлю дарів вимкнено.
## Куплені дари лишаються, вдягаються, знімаються й діють, як раніше. Щоб повернути продаж, постав true
## (робоче значення лежить у DivineService.on_sale, його читають служба, крамниця, екран героя й довідник).
static var ON_SALE: bool  # чи продаються божі дари (вимикач продажу; купленого не забирає)


## Числа-правила вище лежать у data/settings.json (запис «divine»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("divine")
	ON_SALE = S["on_sale"]


const GameDB := preload("res://scripts/core/game_db.gd")

## Записи — у data/gifts.json (дари, поля вище; порядок файлу — порядок у крамниці) і data/gift_slots.json
## (гнізда: назва; порядок файлу — порядок гнізд на екрані героя).


## Запис дару (gifts.json); для невідомого — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.gift(id)


## Усі дари в порядку файлу.
static func ids() -> Array:
	return GameDB.ids("gifts")


## Гнізда в порядку файлу.
static func slots() -> Array:
	return GameDB.ids("gift_slots")


## Назва гнізда: «Супутник».
static func slot_name(slot: String) -> String:
	return str(GameDB.row("gift_slots", slot)["name"])


static func has(id: String) -> bool:
	return GameDB.table("gifts").has(id)


## Які дари лягають у це гніздо, за порядком файлу.
static func in_slot(slot: String) -> Array:
	var out := []
	for id in ids():
		if str(GameDB.gift(id)["slot"]) == slot:
			out.append(id)
	return out
