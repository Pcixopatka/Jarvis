extends "res://scripts/mechanics/mechanic.gd"
## Стрілець-мрець: цілиться й стріляє вздовж смуги; куля підпалює.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(4.5, 6.0)
	if dist > 720.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("line", e.global_position, 1.0, e.damage * 1.4)
	t.dir = to_t
	t.length = 700.0
	t.width = 48.0
	t.color = Color(1.0, 0.7, 0.3)
	t.on_fire = func():
		Audio.play("musket", 0.1, -6.0)
		if is_instance_valid(target) and t.contains(target.global_position) and target.has_method("add_status"):
			target.add_status("burn", 3.0, e.damage * 0.1)
	e.cast_time = 1.0
