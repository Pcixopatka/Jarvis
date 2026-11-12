extends "res://scripts/mechanics/mechanic.gd"
## Лісовик: дме з гущавини й відкидає героя.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(7.0, 10.0)
	if dist > 300.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("cone", e.global_position, 0.8, e.damage * 0.9)
	t.dir = to_t
	t.length = 300.0
	t.half_angle = 0.55
	t.color = Color(0.55, 0.75, 0.4)
	t.on_fire = func():
		if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
			target.push = to_t * 900.0
	e.cast_time = 0.8
