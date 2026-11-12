extends "res://scripts/mechanics/skill_mechanic.gd"
## Вогняна куля (Волхв): куля в найближчого ворога вибухає серед нечисті й підпалює. «Багаття» (pyre) —
## ширший вибух і сильніше горіння. Без ворога поруч не спрацьовує.


func cast() -> bool:
	var target: Node2D = nearest(650.0)
	if target == null:
		return false
	var dir: Vector2 = (target.global_position - p.global_position).normalized()
	p.facing = dir
	var r := roll(2.4 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power)
	combat.spawn_fireball(p.global_position + Vector2(0, -24) + dir * 30.0, dir, r[0], r[1], 95.0 * (1.0 + 0.2 * p.sk("pyre")), r[0] * (0.12 + 0.04 * p.sk("pyre")))
	Audio.play("fire", 0.1)
	return true


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 2.4 * (1.0 + 0.2 * (r - 1)) * sp)], ["Радіус вибуху", "%d" % int(95.0 * (1.0 + 0.2 * p.sk("pyre")))], ["Горіння", "3 с"]]
