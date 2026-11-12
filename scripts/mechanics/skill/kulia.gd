extends "res://scripts/mechanics/skill_mechanic.gd"
## Куля не бере (Характерник): невразливість на кілька секунд.


func cast() -> bool:
	p.invuln = maxf(p.invuln, 2.0 + 0.5 * (rank() - 1))
	say("Куля не бере!", Color(1.0, 0.85, 0.3))
	combat.fx.ring(p.global_position, Color(1.0, 0.85, 0.3), 20, 100, 4, 0.4)
	combat.spawn_fx("gold", p.global_position - Vector2(0, 10), 1.6)
	return true


func card(r: int) -> Array:
	return [["Невразливість", "%.1f с" % (2.0 + 0.5 * (r - 1))]]
