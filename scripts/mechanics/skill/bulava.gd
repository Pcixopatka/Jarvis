extends "res://scripts/mechanics/skill_mechanic.gd"
## Булава гніву (Запорожець): важкий удар дугою перед собою, далеко відкидає.


func cast() -> bool:
	var target: Node2D = nearest(300.0)
	if target:
		p.facing = (target.global_position - p.global_position).normalized()
	var reach := maxf(p.attack_range * 1.5, 190.0)
	var m := 3.0 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach + e.radius and (to.length() < 1.0 or absf(p.facing.angle_to(to)) <= 1.05):
			var r := roll(m)
			hit(e, r[0], to.normalized() * 900.0, r[1])
	p.swing_time = 0.3
	p.swing_duration = 0.3
	p.swing_full = false
	combat.shake(9.0)
	combat.hitstop(0.06)
	Audio.play("crit", 0.05)
	combat.fx.burst(p.global_position + p.facing * reach * 0.6, Color(1.0, 0.6, 0.3), 18, 300, 6, 0.4, 0, p.facing.angle(), 1.2)
	combat.spawn_fx("slash", p.global_position + p.facing * reach * 0.5, 2.0, p.facing.angle(), Color(1.0, 0.75, 0.4))
	return true


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 3.0 * (1.0 + 0.2 * (r - 1)) * sp)], ["Дальність", "%d" % int(maxf(p.attack_range * 1.5, 190.0))]]
