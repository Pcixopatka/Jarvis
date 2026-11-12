extends "res://scripts/mechanics/mechanic.gd"
## Менкв: широкий замах перед собою, що відкидає героя.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(5.0, 7.0)
	if dist > 230.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("cone", e.global_position, 0.8, e.damage * 1.3)
	t.dir = to_t
	t.length = 230.0
	t.half_angle = 0.7
	t.color = Color(0.7, 0.7, 0.75)
	t.on_fire = func():
		if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
			target.push = to_t * 1000.0
	e.cast_time = 0.8
