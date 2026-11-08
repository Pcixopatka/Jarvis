extends RefCounted
## Загін: рівні й досвід супутників. Чисті функції над world.companions.
## Запис супутника: {"type", "downed", "level", "xp"}.

const Data := preload("res://scripts/data/data.gd")

const XP_SHARE := 1.0  # частка досвіду з убитого ворога, яку отримує кожен супутник у загоні
const CURVE := 0.7  # супутникам треба менше досвіду на рівень, ніж козакові
const HIRE_BELOW_HERO := 2  # новий супутник приходить на стільки рівнів нижче за козака


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
		if c.get("downed", false):
			continue
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


static func stats(type: String, level: int) -> Dictionary:
	var info: Dictionary = Data.COMPANIONS[type]
	var out := {
		"hp": info["hp"] + info["hp_lvl"] * (level - 1),
		"dmg": info["dmg"] + info["dmg_lvl"] * (level - 1),
	}
	if info.has("heal"):
		out["heal"] = info["heal"] + info["heal_lvl"] * (level - 1)
	return out
