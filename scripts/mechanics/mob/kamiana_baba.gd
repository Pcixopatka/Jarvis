extends "res://scripts/mechanics/mechanic.gd"
## Кам'яна баба: коли герой поруч, гупає об землю довкола себе.


func ability(_target, dist: float) -> void:
	e.ability_timer = randf_range(5.0, 7.0)
	if dist > 240.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("circle", e.global_position, 1.0, e.damage * 1.3)
	t.radius = 135.0
	t.color = Color(0.65, 0.62, 0.55)
	e.cast_time = 1.0
