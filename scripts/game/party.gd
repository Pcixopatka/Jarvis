extends RefCounted
## Загін: рівні й досвід супутників. Чисті функції над world.companions.
## Запис супутника: {"type", "downed", "level", "xp"}.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")

static var XP_SHARE: float  # частка досвіду з убитого ворога, яку отримує кожен супутник у загоні
static var CURVE: float  # супутникам на рівень треба стільки досвіду, як козакові, помножене на це
static var HIRE_BELOW_HERO: int  # новий супутник приходить на стільки рівнів нижче за героя


## Числа-правила вище лежать у data/settings.json (запис «party»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("party")
	XP_SHARE = S["xp_share"]
	CURVE = S["curve"]
	HIRE_BELOW_HERO = S["hire_below_hero"]


static func xp_for_level(l: int) -> int:
	return int(Data.xp_for_level(l) * CURVE)


static func new_member(type: String, hero_level: int) -> Dictionary:
	return {"type": type, "downed": false, "level": maxi(1, hero_level - HIRE_BELOW_HERO), "xp": 0}


## Доповнює старі записи (до появи рівнів) — для збережень із попередніх версій.
static func normalize(world, hero_level: int) -> void:
	for c in world.companions:
		if not c.has("level"):
			c["level"] = maxi(1, hero_level - HIRE_BELOW_HERO)
		if not c.has("xp"):
			c["xp"] = 0


## Досвід усім супутникам, що не поранені. Повертає [індекс, новий рівень] для тих, хто підріс.
static func gain_xp(world, hero_level: int, amount: int) -> Array:
	var ups := []
	for i in world.companions.size():
		var c: Dictionary = world.companions[i]
		if c.get("downed", false) or not c.get("away", {}).is_empty():
			continue  # поранені й ті, хто у власному поході, досвіду з бою не мають
		var lvl: int = int(c.get("level", 1))
		if lvl >= hero_level:
			c["xp"] = 0  # не обганяє козака: досвід не накопичується понад стелю
			continue
		c["xp"] = int(c.get("xp", 0)) + maxi(1, roundi(amount * XP_SHARE))
		while lvl < hero_level and c["xp"] >= xp_for_level(lvl):
			c["xp"] -= xp_for_level(lvl)
			lvl += 1
		if lvl != int(c.get("level", 1)):
			c["level"] = lvl
			ups.append([i, lvl])
	return ups


static func stats(type: String, level: int, mult: float = 1.0) -> Dictionary:
	var info: Dictionary = GameDB.companion(type)["stats"]  # сила 1-го рівня (data/companions.json)
	# Побратим тримає свою частку від еталонного героя на будь-якому рівні: інакше нечисть,
	# що росте за еталоном рівня, клала б його одним ударом, а його удари нічого не важили б.
	var live: float = Data.ref_ehp(level) / Data.ref_ehp(1)
	var out := {
		"hp": info["hp"] * live * mult,
		"dmg": info["dmg"] * Data.ref_dps(level) / Data.ref_dps(1) * mult,
	}
	if info.has("heal"):
		out["heal"] = info["heal"] * live * mult
	return out
