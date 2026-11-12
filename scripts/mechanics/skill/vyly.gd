extends "res://scripts/mechanics/skill_mechanic.gd"
## Удар вилами (Селянин): випад уперед, б'є всіх на лінії перед собою й відкидає.


func cast() -> bool:
	var target: Node2D = nearest(300.0)
	if target:
		p.facing = (target.global_position - p.global_position).normalized()
	var length := maxf(p.attack_range * 1.6, 200.0)
	var m := 2.0 * (1.0 + 0.15 * (rank() - 1)) * p.skill_power
	for e in foes():
		var l: Vector2 = e.global_position - p.global_position
		var along := l.dot(p.facing)
		if along >= -10.0 and along <= length + e.radius and absf(l.dot(p.facing.orthogonal())) <= 45.0 + e.radius:
			var r := roll(m)
			hit(e, r[0], p.facing * 520.0, r[1])
	p.swing_time = 0.22
	p.swing_duration = 0.22
	p.swing_full = false
	p.dodge_dir = p.facing
	p.dodge_time_left = 0.1  # короткий випад уперед
	Audio.play("swing", 0.1, 0.0)
	combat.fx.burst(p.global_position + p.facing * length * 0.6, Color(0.9, 0.85, 0.7), 10, 220, 4, 0.3, 0, p.facing.angle(), 0.5)
	combat.spawn_fx("slash", p.global_position + p.facing * length * 0.5, 1.6, p.facing.angle(), Color(1.0, 0.95, 0.8))
	combat.shake(4.0)
	return true


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 2.0 * (1.0 + 0.15 * (r - 1)) * sp)],
		["Довжина лінії", "%d" % int(maxf(p.attack_range * 1.6, 200.0))]]
