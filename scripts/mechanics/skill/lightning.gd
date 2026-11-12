extends "res://scripts/mechanics/skill_mechanic.gd"
## Блискавка Перуна (Перунів жрець): ланцюг блискавки по найближчих ворогах (не далі 480). «Ланцюг»
## (chain) — ще двоє за ранг, «Гнів» (wrath) — уповільнює, «Похмурий» (grim) — сильніша, «Душа грози»
## (storm_soul) — швидша перезарядка. Без ворога поруч не спрацьовує.


func cast() -> bool:
	var targets := foes().filter(func(e): return p.global_position.distance_to(e.global_position) <= 480.0 + e.radius)
	if targets.is_empty():
		return false
	targets.sort_custom(func(a, b): return p.global_position.distance_squared_to(a.global_position) < p.global_position.distance_squared_to(b.global_position))
	var count := 2 + rank() + 2 * p.sk("chain")
	var m := (1.2 + 0.25 * rank()) * p.skill_power * (1.0 + 0.1 * p.pk("grim"))
	var pts := PackedVector2Array([p.global_position + Vector2(0, -30)])
	for i in mini(count, targets.size()):
		var e = targets[i]
		pts.append(e.global_position)
		var r := roll(m)
		hit(e, r[0], Vector2.ZERO, r[1])
		combat.spawn_fx("lightning", e.global_position - Vector2(0, 30), 1.2, 0.0, Color.WHITE, 20.0)
		if p.sk("wrath") > 0 and not e.dead:
			e.slow_timer = 2.0
	combat.spawn_bolt(pts)
	combat.shake(5.0)
	Audio.play("lightning")
	for i in range(1, pts.size()):
		combat.fx.burst(pts[i], Color(0.75, 0.9, 1.0), 8, 260, 3.5, 0.3)
	return true


func cooldown(base: float) -> float:
	return base * (1.0 - 0.1 * p.pk("storm_soul"))


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * (1.2 + 0.25 * r) * sp * (1.0 + 0.1 * p.pk("grim")))], ["Цілей", "%d" % (2 + r + 2 * p.sk("chain"))]]
