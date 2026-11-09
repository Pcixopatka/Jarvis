extends RefCounted
## Нагороди за добровільний перегляд реклами. Стан — world.boosts і world.ads.

const XP2_SECONDS := 3600.0  # ×2 досвіду на годину гри (час іде лише в поході)
const XP2_MAX := 3.0 * 3600.0  # можна накопичити до 3 годин
const SAFE_PER_DAY := 3  # безпечних заточок за рекламу на день


static func xp2_left(world) -> float:
	return float(world.boosts.get("xp2", 0.0))


static func can_xp2(world) -> bool:
	return xp2_left(world) + XP2_SECONDS <= XP2_MAX


static func grant_xp2(world) -> void:
	world.boosts["xp2"] = minf(XP2_MAX, xp2_left(world) + XP2_SECONDS)


## Час іде лише під час гри в поході.
static func tick(world, delta: float) -> void:
	if xp2_left(world) > 0.0:
		world.boosts["xp2"] = maxf(0.0, xp2_left(world) - delta)


static func xp_mult(world) -> float:
	return 2.0 if xp2_left(world) > 0.0 else 1.0


static func _today() -> String:
	return Time.get_date_string_from_system()


static func safe_left_today(world) -> int:
	if world.ads.get("day", "") != _today():
		return SAFE_PER_DAY
	return SAFE_PER_DAY - int(world.ads.get("safe_used", 0))


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


static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	return "%d год %02d хв" % [m / 60, m % 60] if m >= 60 else "%d хв" % m
