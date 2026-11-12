extends RefCounted
## Нагороди за добровільний перегляд реклами. Стан — world.boosts і world.ads.
## Із Гетьманським універсалом (PremiumService) реклама не потрібна: ×2 досвіду й ×2 здобичі діють
## постійно, накопичені години не згорають, а безпечних заточок на день більше.

const GameDB := preload("res://scripts/core/game_db.gd")

const Premium := preload("res://scripts/game/premium_service.gd")

static var XP2_SECONDS: float  # ×2 досвіду: секунд гри за перегляд (час іде лише в поході)
static var XP2_MAX: float  # ×2 досвіду: можна накопичити до стількох секунд
static var DROP2_SECONDS: float  # ×2 здобичі: секунд гри за перегляд
static var DROP2_MAX: float  # ×2 здобичі: можна накопичити до стількох секунд
static var SAFE_PER_DAY: int  # безпечних заточок за рекламу на день


## Числа-правила вище лежать у data/settings.json (запис «ads»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("ads")
	XP2_SECONDS = S["xp2_seconds"]
	XP2_MAX = S["xp2_max"]
	DROP2_SECONDS = S["drop2_seconds"]
	DROP2_MAX = S["drop2_max"]
	SAFE_PER_DAY = S["safe_per_day"]


static func xp2_left(world) -> float:
	return float(world.boosts.get("xp2", 0.0))


static func can_xp2(world) -> bool:
	return xp2_left(world) + XP2_SECONDS <= XP2_MAX


static func grant_xp2(world) -> void:
	world.boosts["xp2"] = minf(XP2_MAX, xp2_left(world) + XP2_SECONDS)


## ×2 здобичі: удвічі частіше падають речі й ресурси, бос кидає на одну річ більше.
static func drop2_left(world) -> float:
	return float(world.boosts.get("drop2", 0.0))


static func can_drop2(world) -> bool:
	return drop2_left(world) + DROP2_SECONDS <= DROP2_MAX


static func grant_drop2(world) -> void:
	world.boosts["drop2"] = minf(DROP2_MAX, drop2_left(world) + DROP2_SECONDS)


## Час іде лише під час гри в поході.
static func tick(world, delta: float) -> void:
	if Premium.active(world):
		return  # з універсалом куплені за рекламу години чекають, поки він скінчиться
	if xp2_left(world) > 0.0:
		world.boosts["xp2"] = maxf(0.0, xp2_left(world) - delta)
	if drop2_left(world) > 0.0:
		world.boosts["drop2"] = maxf(0.0, drop2_left(world) - delta)


static func xp_mult(world) -> float:
	return 2.0 if xp2_left(world) > 0.0 or Premium.active(world) else 1.0


static func drop_mult(world) -> float:
	return 2.0 if drop2_left(world) > 0.0 or Premium.active(world) else 1.0


## День обмежень той самий, що й у викликів: за годинником гри, який назад не йде (Clock).
static func _today() -> String:
	var CS = load("res://scripts/game/challenge_service.gd")
	return CS.day_key(CS._now())


## Скільки безпечних заточок можна взяти за день: з універсалом більше.
static func safe_per_day(world) -> int:
	return Premium.SAFE_PER_DAY if Premium.active(world) else SAFE_PER_DAY


static func safe_left_today(world) -> int:
	if world.ads.get("day", "") != _today():
		return safe_per_day(world)
	return maxi(0, safe_per_day(world) - int(world.ads.get("safe_used", 0)))


## Напис на кнопці безпечної заточки в коваля.
static func safe_button_text(world) -> String:
	return ("Універсал: +1 безпечна заточка (сьогодні ще %d)" if Premium.active(world) else "Реклама: +1 безпечна заточка (сьогодні ще %d)") % safe_left_today(world)


static func grant_safe(world) -> bool:
	if safe_left_today(world) <= 0:
		return false
	if world.ads.get("day", "") != _today():
		world.ads["day"] = _today()
		world.ads["safe_used"] = 0
	world.ads["safe_used"] = int(world.ads.get("safe_used", 0)) + 1
	world.boosts["safe_sharpen"] = int(world.boosts.get("safe_sharpen", 0)) + 1
	return true


static func safe_tokens(world) -> int:
	return int(world.boosts.get("safe_sharpen", 0))


## Використати жетон безпечної заточки (лише коли спроба справді ризикована).
static func use_safe(world) -> bool:
	if safe_tokens(world) <= 0:
		return false
	world.boosts["safe_sharpen"] = safe_tokens(world) - 1
	return true


## Обидва годинні подарунки за рекламу ("xp2", "drop2") однаково накопичуються до 3 годин.
const BOOST_NAMES := {"xp2": "×2 досвіду", "drop2": "×2 здобичі"}


static func boost_left(world, id: String) -> float:
	return drop2_left(world) if id == "drop2" else xp2_left(world)


static func can_boost(world, id: String) -> bool:
	if Premium.active(world):
		return false  # і так діє постійно
	return can_drop2(world) if id == "drop2" else can_xp2(world)


static func grant_boost(world, id: String) -> void:
	if id == "drop2":
		grant_drop2(world)
	else:
		grant_xp2(world)


## Напис на кнопці: назва й скільки лишилося (або що дасть перегляд).
static func boost_button_text(world, id: String) -> String:
	if Premium.active(world):
		return "%s\nдіє: універсал" % BOOST_NAMES[id]
	var left := boost_left(world, id)
	return "%s\n%s" % [BOOST_NAMES[id], ("ще " + format_time(left)) if left > 0.0 else "година гри"]


static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	return "%d год %02d хв" % [m / 60, m % 60] if m >= 60 else "%d хв" % m
