extends "res://scripts/mechanics/skill_mechanic.gd"
## Земний удар (Запорожець): удар об землю довкола, приголомшує нечисть (крім босів).


func cast() -> bool:
	var reach := 230.0
	var m := 1.6 * (1.0 + 0.15 * (rank() - 1)) * p.skill_power
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach + e.radius:
			var r := roll(m)
			hit(e, r[0], to.normalized() * 300.0, r[1])
			if not e.dead and not e.is_boss:
				e.stun = maxf(e.stun, 1.0 + 0.2 * rank())
	p.swing_time = 0.35
	p.swing_duration = 0.35
	p.swing_full = true
	p.swing_reach = reach
	combat.shake(10.0)
	Audio.play("boom", 0.05, -2.0)
	combat.fx.ring(p.global_position + Vector2(0, 16), Color(0.6, 0.45, 0.25), 30, reach * 2.0, 8, 0.4)
	combat.fx.burst(p.global_position + Vector2(0, 16), Color(0.5, 0.4, 0.25), 24, 260, 7, 0.6)
	combat.spawn_fx("earth", p.global_position + Vector2(0, 16), 2.6, 0.0, Color.WHITE, 12.0)
	return true


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 1.6 * (1.0 + 0.15 * (r - 1)) * sp)], ["Радіус", "230"], ["Приголомшення", "%.1f с" % (1.0 + 0.2 * r)]]
