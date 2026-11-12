extends "res://scripts/mechanics/mechanic.gd"
## Мара: зникає й постає просто за спиною героя.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(4.0, 6.0)
	if dist > 520.0 or dist < 90.0:
		e.ability_timer = 1.5
		return
	combat.fx.burst(e.global_position, Color(0.8, 0.85, 1.0), 12, 160, 5, 0.4)
	e.global_position = combat._clamp_in(target.global_position + to_t.rotated(randf_range(-0.8, 0.8)) * 115.0, 50.0)
	combat.fx.burst(e.global_position, Color(0.8, 0.85, 1.0), 12, 160, 5, 0.4)
	e.contact_cd = maxf(e.contact_cd, 0.6)
