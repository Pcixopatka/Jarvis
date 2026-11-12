extends RefCounted
## Сліди на арені: у звичайній місцевості інколи є стежка слідів.
## Знайди її початок біля місця, де з'явився, і йди від точки до точки — кожна відкриває наступний відтинок.
## Наприкінці — схованка (гривні, ресурси, інколи річ), лігво (еліта зі зграєю біля купи здобичі)
## або поранений вепр (м'ясо для казана). Пластун бачить усю стежку одразу й натрапляє на сліди частіше.

const Acts := preload("res://scripts/data/activities.gd")
## Знахідки, які вміє Combat._trail_found: у data/trail_kinds.json мусять бути саме вони.
const KINDS := ["cache", "den", "beast"]


static func chance(player) -> float:
	return Acts.TRAIL_CHANCE_SCOUT if player.job == "plastun" else Acts.TRAIL_CHANCE


## Чи є стежка в цьому поході (roll — випадкове 0..1).
static func should_spawn(player, roll: float) -> bool:
	return player.level >= Acts.TRAIL_MIN_LEVEL and roll < chance(player)


## Яка знахідка чекає наприкінці (roll — випадкове 0..1).
static func roll_kind(roll: float) -> String:
	var total := 0
	for k in Acts.trail_kinds():
		total += int(Acts.trail_kind(k)["weight"])
	var left := roll * total
	for k in Acts.trail_kinds():
		left -= float(Acts.trail_kind(k)["weight"])
		if left < 0.0:
			return k
	return Acts.trail_kinds().keys()[0]


## Точки стежки в межах арени: перша — початок слідів, остання — знахідка.
static func make_points(start: Vector2, arena: Rect2, rng: RandomNumberGenerator) -> Array:
	var inner := arena.grow(-140.0)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var pts := []
	var p := _inside(start + dir * Acts.TRAIL_START, inner)
	pts.append(p)
	for i in Acts.TRAIL_POINTS - 1:
		var best := p
		# Кілька спроб повернути так, щоб відтинок не вперся в край арени й не вийшов закоротким
		for attempt in 8:
			var d := dir.rotated(rng.randf_range(-1.0, 1.0) * (0.5 + 0.35 * attempt))
			var q := _inside(p + d * Acts.TRAIL_STEP, inner)
			if q.distance_to(p) > best.distance_to(p):
				best = q
				if q.distance_to(p) >= Acts.TRAIL_STEP * 0.9:
					dir = d
					break
		dir = (best - p).normalized() if best != p else dir
		p = best
		pts.append(p)
	return pts


static func _inside(p: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## Гривні в схованці (усього).
static func cache_gold(level: int) -> int:
	return 5 * (4 + 3 * level)


## М'ясо з пораненого вепра (roll — випадкове 0..1).
static func beast_meat(roll: float) -> int:
	return 2 + int(roll * 3.0)  # 2..4
