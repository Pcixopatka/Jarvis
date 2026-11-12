extends "res://scripts/mechanics/skill_mechanic.gd"
## Картеч (Самопальник): сім куль віялом, кожна б'є одного.


func cast() -> bool:
	var target: Node2D = nearest(600.0)
	var dir := p.facing
	if target:
		dir = (target.global_position - p.global_position).normalized()
		p.facing = dir
	var m := 0.65 * (1.0 + 0.15 * (rank() - 1)) * p.skill_power
	for i in 7:
		var r := roll(m)
		combat.spawn_bullet(p.global_position + Vector2(0, -10) + dir * 34.0, dir.rotated(-0.42 + i * 0.14), r[0], r[1])
		combat.last_projectile().pierce = 1  # картеч не пробиває
	Audio.play("musket", 0.05, 0.0)
	combat.shake(5.0)
	combat.fx.burst(p.global_position + Vector2(0, -10) + dir * 44.0, Color(1.0, 0.8, 0.3), 14, 300, 5, 0.2, 0, dir.angle(), 0.9)
	combat.spawn_fx("fire", p.global_position + Vector2(0, -10) + dir * 50.0, 0.8, 0.0, Color.WHITE, 24.0)
	return true


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода кулі", dmg_text(d * 0.65 * (1.0 + 0.15 * (r - 1)) * sp)], ["Куль", "7"]]
