extends "res://scripts/mechanics/mechanic.gd"
## Кромішник: кидає аркан і тягне героя до себе.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(5.0, 7.0)
	if dist < 170.0 or dist > 480.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("line", e.global_position, 0.7, e.damage * 0.6)
	t.dir = to_t
	t.length = 480.0
	t.width = 48.0
	t.color = Color(0.7, 0.7, 0.75)
	t.on_fire = func():
		if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
			target.push = (e.global_position - target.global_position).normalized() * 1200.0
			e.contact_cd = 0.0
	e.cast_time = 0.7
