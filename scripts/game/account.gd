extends RefCounted
## Спільне на всіх персонажів (один файл account.save):
##   camp       — Козацький хутір (будівлі, пасіка) — те саме, що раніше world.camp
##   chest      — спільна скриня: {"gold", "items", "stones"}; місткість — CHEST_SIZE + бонус Складу
##   stats      — лічильники подій для викликів і досягнень (усі персонажі разом)
##   challenges — щоденні/тижневі виклики й відкриті досягнення
##   records    — рекорди роду: найкраще серед усіх персонажів (див. RecordService)
##   holidays   — жетони й нагороди сезонних свят (див. HolidayService)
## WorldState кожного персонажа тримає посилання на ці словники, тож сервіси, що працюють із
## world.camp / world.stats / world.challenges, не змінюються.

const Data := preload("res://scripts/data/data.gd")

const CHEST_SIZE := 40
const CHEST_PER_SKLAD := 20  # кожен рівень Складу на хуторі — ще стільки місць у скрині
const MAX_HEROES := 5

var camp := {}
var chest := {"gold": 0, "items": [], "stones": {}}
var stats := {}
var challenges := {}
var records := {}
var holidays := {}
var next_uid := 1000000  # uid речей у скрині — з окремого діапазону, щоб не збігались із героєвими


func to_dict() -> Dictionary:
	return {"camp": camp, "chest": chest, "stats": stats, "challenges": challenges, "records": records, "holidays": holidays, "next_uid": next_uid}


func from_dict(d: Dictionary) -> void:
	camp = d.get("camp", {})
	chest = d.get("chest", {"gold": 0, "items": [], "stones": {}})
	if not chest.has("stones"):
		chest["stones"] = {}
	stats = d.get("stats", {})
	challenges = d.get("challenges", {})
	records = d.get("records", {})
	holidays = d.get("holidays", {})
	next_uid = int(d.get("next_uid", 1000000))


## Підключити стан світу персонажа до спільних словників (посилання, не копії).
func attach(world) -> void:
	world.camp = camp
	world.stats = stats
	world.challenges = challenges
	world.records = records
	world.holidays = holidays


## Перший запуск після оновлення: забрати спільне зі старого збереження персонажа.
func absorb_from_world(world) -> void:
	if camp.is_empty() and not world.camp.is_empty():
		camp = world.camp
	if stats.is_empty() and not world.stats.is_empty():
		stats = world.stats
	if challenges.is_empty() and not world.challenges.is_empty():
		challenges = world.challenges


# ---------- Скриня ----------

func chest_size(sklad_level: int) -> int:
	return CHEST_SIZE + CHEST_PER_SKLAD * sklad_level


func chest_full(sklad_level: int) -> bool:
	return chest["items"].size() >= chest_size(sklad_level)


## Покласти річ у скриню (річ отримує новий uid зі скринного діапазону).
func put_item(item: Dictionary, sklad_level: int) -> bool:
	if chest_full(sklad_level):
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
