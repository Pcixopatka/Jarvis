extends "res://scripts/mechanics/mechanic.gd"
## Алмасти: стрибає на героя, а після стрибка мить стоїть.

## Коло стрибка (Стало б'є ширше, див. stallo.gd)
var leap_radius := 110.0


func ability(target, dist: float) -> void:
	e.ability_timer = randf_range(5.0, 7.0)
	if dist < 150.0 or dist > 440.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("circle", target.global_position, 0.85, e.damage * 1.3)
	t.radius = leap_radius
	t.color = Color(0.6, 0.5, 0.4)
	t.on_fire = func():
		if alive():
			e.global_position = t.global_position
			e.cast_time = 0.6
			e.contact_cd = 1.0
	e.cast_time = 0.85
