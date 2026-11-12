extends "res://scripts/mechanics/skill_mechanic.gd"
## Постріл із самопала (Козак): куля в найближчого ворога, з «Картеччю» (buckshot) — п'ять віялом, кожна
## слабша. «Швидке набивання» (reload) скорочує перезарядку.


func cast() -> bool:
	var target: Node2D = nearest(750.0)
	var dir := p.facing
	if target:
		dir = (target.global_position - p.global_position).normalized()
		p.facing = dir
	var m := (2.2 + 0.4 * (rank() - 1)) * p.skill_power
	var angles := [-0.3, -0.15, 0.0, 0.15, 0.3] if p.sk("buckshot") > 0 else [0.0]
	for a in angles:
		var r := roll(m * (0.6 if angles.size() > 1 else 1.0))
		combat.spawn_bullet(p.global_position + Vector2(0, -10) + dir * 30.0, dir.rotated(a), r[0], r[1])
	combat.shake(4.0)
	Audio.play("musket")
	combat.fx.burst(p.global_position + Vector2(0, -10) + dir * 40.0, Color(0.85, 0.85, 0.8, 0.6), 14, 140, 9, 0.8, -40, dir.angle(), 0.9)
	combat.fx.burst(p.global_position + Vector2(0, -10) + dir * 40.0, Color(1.0, 0.8, 0.3), 6, 300, 4, 0.15, 0, dir.angle(), 0.6)
	return true


func cooldown(base: float) -> float:
	return base * (1.0 - 0.12 * p.sk("reload"))


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	var n := 5 if p.sk("buckshot") > 0 else 1
	return [["Шкода кулі", dmg_text(d * (2.2 + 0.4 * (r - 1)) * sp * (0.6 if n > 1 else 1.0))], ["Куль", "%d" % n]]
