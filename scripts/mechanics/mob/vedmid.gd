extends "res://scripts/mechanics/mechanic.gd"
## Ведмідь-шатун: стрибає просто на героя, а після стрибка мить стоїть.


func ability(target, dist: float) -> void:
	e.ability_timer = randf_range(5.5, 7.5)
	if dist < 150.0 or dist > 430.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("circle", target.global_position, 0.9, e.damage * 1.3)
	t.radius = 105.0
	t.color = Color(0.6, 0.4, 0.25)
	t.on_fire = func():
		if alive():
			e.global_position = t.global_position
			e.cast_time = 0.6
			e.contact_cd = 1.0
	e.cast_time = 0.9
