extends RefCounted
## Спільне на всіх персонажів (один файл account.save):
##   camp       — Козацький хутір (будівлі, пасіка) — те саме, що раніше world.camp
##   chest      — спільна скриня: {"gold", "items", "stones"}; місткість — chest_size(world)
##   stats      — лічильники подій для викликів і досягнень (усі персонажі разом)
##   challenges — щоденні/тижневі виклики й відкриті досягнення
##   records    — рекорди роду: найкраще серед усіх персонажів (див. RecordService)
##   holidays   — жетони й нагороди сезонних свят (див. HolidayService)
##   shop       — крамниця за донат: червінці й покупки (див. ShopService)
## WorldState кожного персонажа тримає посилання на ці словники, тож сервіси, що працюють із
## world.camp / world.stats / world.challenges, не змінюються.

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")
const Clock := preload("res://scripts/core/clock.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")
const Valor := preload("res://scripts/data/valor.gd")
const CampService := preload("res://scripts/game/camp_service.gd")

static var CHEST_SIZE: int  # місць у скрині роду
static var CHEST_PER_SKLAD: int  # кожен рівень Складу на хуторі — ще стільки місць у скрині
static var MAX_HEROES: int  # героїв у роді


## Числа-правила вище лежать у data/settings.json (запис «account»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("account")
	CHEST_SIZE = S["chest_size"]
	CHEST_PER_SKLAD = S["chest_per_sklad"]
	MAX_HEROES = S["max_heroes"]


var camp := {}
var chest := {"gold": 0, "items": [], "stones": {}}
var stats := {}
var challenges := {}
var records := {}
var holidays := {}
var shop := {}  # крамниця за донат: червінці й покупки роду (див. ShopService)
var next_uid := 1000000  # uid речей у скрині — з окремого діапазону, щоб не збігались із героєвими
## Позначка в файлі акаунта: досвід і гривні на речах у скрині вже перераховано під стелю
## (Data.XP_GOLD_MAX_TOP). Файл акаунта версії не має, тож у нього своя позначка, окремо від героя.
const XP_GOLD_KEY := "xp_gold_scaled"


func to_dict() -> Dictionary:
	# "clock": найпізніший час, який бачила гра, щоб переведений назад годинник нічого не скидав (Clock)
	return {"camp": camp, "chest": chest, "stats": stats, "challenges": challenges, "records": records, "holidays": holidays, "shop": shop, "next_uid": next_uid,
		"clock": Clock.now(), XP_GOLD_KEY: 1}


func from_dict(d: Dictionary) -> void:
	if not d.has(XP_GOLD_KEY):
		# старий акаунт: речі в скрині дістають нові числа досвіду й гривень рівно раз
		# (а річ, що вже має позначку Data.XP_GOLD_MARK, не зменшується вдруге)
		SaveSystem.rescale_items_xp_gold(d)
		d[XP_GOLD_KEY] = 1
	camp = d.get("camp", {})
	chest = d.get("chest", {"gold": 0, "items": [], "stones": {}})
	if not chest.has("stones"):
		chest["stones"] = {}
	stats = d.get("stats", {})
	challenges = d.get("challenges", {})
	records = d.get("records", {})
	holidays = d.get("holidays", {})
	shop = d.get("shop", {})
	next_uid = int(d.get("next_uid", 1000000))
	Clock.adopt(float(d.get("clock", 0.0)))
	_cap_valor()


## Підключити стан світу персонажа до спільних словників (посилання, не копії).
func attach(world) -> void:
	world.camp = camp
	world.stats = stats
	world.challenges = challenges
	world.records = records
	world.holidays = holidays
	world.shop = shop


## Перший запуск після оновлення: забрати спільне зі старого збереження персонажа.
func absorb_from_world(world) -> void:
	if camp.is_empty() and not world.camp.is_empty():
		camp = world.camp
	if stats.is_empty() and not world.stats.is_empty():
		stats = world.stats
	if challenges.is_empty() and not world.challenges.is_empty():
		challenges = world.challenges
	_cap_valor()


## Старі збереження могли записати звитягу понад стелю (Valor.max_valor): лічильник викликів
## і рекорд у «Літописі слави» опускаються до неї.
func _cap_valor() -> void:
	var top := Valor.max_valor()
	if int(stats.get("valor", 0)) > top:
		stats["valor"] = top
	var rec = records.get("valor", {})
	if rec is Dictionary and int(rec.get("value", 0)) > top:
		rec["value"] = top


# ---------- Скриня ----------

## Місткість скрині — лише тут: основа, Склад на хуторі й Чумацький віз героя, яким грають
## (world.chest_divine). Як дар зняти, речі понад місткість лишаються, але класти не можна.
func chest_size(world) -> int:
	return CHEST_SIZE + CHEST_PER_SKLAD * CampService.level(world, "sklad") + int(world.chest_divine)


func chest_full(world) -> bool:
	return chest["items"].size() >= chest_size(world)


## Покласти річ у скриню (річ отримує новий uid зі скринного діапазону).
func put_item(item: Dictionary, world) -> bool:
	if chest_full(world):
		return false
	item = item.duplicate(true)
	item["uid"] = next_uid
	next_uid += 1
	chest["items"].append(item)
	return true


## Забрати річ зі скрині (повертає її без uid — герой призначить свій).
func take_item(uid: int) -> Dictionary:
	var items: Array = chest["items"]
	for i in items.size():
		if int(items[i]["uid"]) == uid:
			var it: Dictionary = items[i]
			items.remove_at(i)
			it.erase("uid")
			return it
	return {}


func put_gold(player, amount: int) -> int:
	amount = clampi(amount, 0, player.gold)
	player.gold -= amount
	chest["gold"] = int(chest["gold"]) + amount
	return amount


func take_gold(player, amount: int) -> int:
	amount = clampi(amount, 0, int(chest["gold"]))
	chest["gold"] = int(chest["gold"]) - amount
	player.gold += amount
	return amount


func put_stone(player, id: String) -> bool:
	if int(player.stones.get(id, 0)) <= 0:
		return false
	player.stones[id] -= 1
	chest["stones"][id] = int(chest["stones"].get(id, 0)) + 1
	return true


func take_stone(player, id: String) -> bool:
	if int(chest["stones"].get(id, 0)) <= 0:
		return false
	chest["stones"][id] -= 1
	player.stones[id] = int(player.stones.get(id, 0)) + 1
	return true
