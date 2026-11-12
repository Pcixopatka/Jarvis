extends "res://scripts/mechanics/mechanic.gd"
## Песиголовець: здалеку кидається ривком по прямій просто крізь героя.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(4.5, 6.5)
	if dist < 140.0 or dist > 460.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("line", e.global_position, 0.5, e.damage * 1.2)
	t.dir = to_t
	t.length = 330.0
	t.width = 56.0
	t.color = Color(0.85, 0.5, 0.2)
	t.on_fire = func():
		if alive():
			e.knockback = to_t * 1300.0
	e.cast_time = 0.5
