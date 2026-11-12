extends RefCounted
## Гетьманський універсал: преміум на 30 днів за червінці. Спільний для всіх героїв роду (стан у world.shop:
## "premium_until" — час у секундах, до якого він діє, "stipend_day" — день останньої платні).
## Що дає, зібрано тут, щоб було легко міняти:
##  - усе, що дається за рекламу, без реклами: ×2 досвіду й ×2 здобичі діють постійно,
##    швидкий похід і безпечна заточка не просять перегляду;
##  - швидких походів на день QUICK_PER_DAY замість звичайних, безпечних заточок SAFE_PER_DAY;
##  - щоденна платня червінцями, більша торба, швидша дорога мапою, автобій у будь-якому пройденому місці.

const GameDB := preload("res://scripts/core/game_db.gd")

const Shop := preload("res://scripts/data/shop.gd")
const Clock := preload("res://scripts/core/clock.gd")

const DAY := 86400.0
static var DAYS: int  # на скільки днів один універсал
static var PRICE: int  # ціна в червінцях
static var QUICK_PER_DAY: int  # швидких походів на день з універсалом
static var SAFE_PER_DAY: int  # безпечних заточок на день з універсалом
static var STIPEND: int  # червінців платні на день
static var BAG_BONUS: int  # додаткових місць у торбі
static var TRAVEL_MULT: float  # у скільки разів швидша дорога мапою


## Числа-правила вище лежать у data/settings.json (запис «premium»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("premium")
	DAYS = S["days"]
	PRICE = S["price"]
	QUICK_PER_DAY = S["quick_per_day"]
	SAFE_PER_DAY = S["safe_per_day"]
	STIPEND = S["stipend"]
	BAG_BONUS = S["bag_bonus"]
	TRAVEL_MULT = S["travel_mult"]


const NAME := "Гетьманський універсал"

static var now_override := -1.0  # для тестів: «зараз» у секундах від початку епохи


static func now() -> float:
	return now_override if now_override >= 0.0 else Clock.now()


static func today() -> String:
	return Time.get_date_string_from_unix_time(int(now()))


static func until(world) -> float:
	return float(world.shop.get("premium_until", 0.0))


static func active(world) -> bool:
	return world != null and now() < until(world)


## Скільки повних і неповних днів лишилось (0 — не діє).
static func days_left(world) -> int:
	return ceili(maxf(0.0, until(world) - now()) / DAY)


static func block_reason(world) -> String:
	var coins: int = int(world.shop.get("coins", 0))
	if coins < PRICE:
		return "бракує %d %s" % [PRICE - coins, Shop.COIN_SHORT]
	return ""


## Купити чи продовжити універсал: нові 30 днів додаються до решти, а не згорають.
static func buy(world) -> bool:
	if block_reason(world) != "":
		return false
	var s: Dictionary = world.shop
	s["coins"] = int(s.get("coins", 0)) - PRICE
	s["spent"] = int(s.get("spent", 0)) + PRICE
	s["premium_until"] = maxf(now(), until(world)) + DAYS * DAY
	s["premium_bought"] = int(s.get("premium_bought", 0)) + 1
	return true


## Денна платня: раз на день, поки діє універсал. Повертає, скільки червінців зараховано.
static func stipend(world) -> int:
	if not active(world) or str(world.shop.get("stipend_day", "")) == today():
		return 0
	world.shop["stipend_day"] = today()
	world.shop["coins"] = int(world.shop.get("coins", 0)) + STIPEND
	return STIPEND


static func bag_bonus(world) -> int:
	return BAG_BONUS if active(world) else 0


static func travel_mult(world) -> float:
	return TRAVEL_MULT if active(world) else 1.0


## Рядки «що дає універсал» для крамниці й довідника. base_quick і base_safe — звичайні денні межі.
static func perks(base_quick: int, base_safe: int) -> Array:
	return [
		"Усе, що дається за рекламу, без реклами: швидкий похід і безпечна заточка одним дотиком",
		"×2 досвіду й ×2 здобичі діють постійно, без годинників",
		"Швидких походів на день: %d замість %d" % [QUICK_PER_DAY, base_quick],
		"Безпечних заточок на день: %d замість %d" % [SAFE_PER_DAY, base_safe],
		"Щодня %d червінців платні: зайди в гру, і вони твої" % STIPEND,
		"Торба більша на %d місць" % BAG_BONUS,
		"Дорога мапою вдвічі швидша",
		"Автобій у будь-якому пройденому місці, а не лише там, де був тричі",
	]
