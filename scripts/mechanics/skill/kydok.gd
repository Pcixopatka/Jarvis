extends "res://scripts/mechanics/skill_mechanic.gd"
## Кидок списа (Пластун): спис у найближчого ворога, летить навиліт.


func cast() -> bool:
	var target: Node2D = nearest(650.0)
	var dir := p.facing
	if target:
		dir = (target.global_position - p.global_position).normalized()
		p.facing = dir
	var r := roll(3.0 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power)
	combat.spawn_bullet(p.global_position + Vector2(0, -12) + dir * 30.0, dir, r[0], r[1])
	combat.last_projectile().color = Color(0.85, 0.8, 0.7)
	combat.last_projectile().spear = true
	Audio.play("swing", 0.05, 0.0)
	return true


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 3.0 * (1.0 + 0.2 * (r - 1)) * sp)], ["Пробиває", "усіх на лінії"]]
