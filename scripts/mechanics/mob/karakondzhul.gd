extends "res://scripts/mechanics/mechanic.gd"
## Караконджул: ривок по прямій крізь героя.


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(4.0, 6.0)
	if dist < 130.0 or dist > 440.0:
		e.ability_timer = 1.0
		return
	var t = telegraph("line", e.global_position, 0.45, e.damage * 1.2)
	t.dir = to_t
	t.length = 340.0
	t.width = 50.0
	t.color = Color(0.75, 0.6, 0.85)
	t.on_fire = func():
		if alive():
			e.knockback = to_t * 1350.0
	e.cast_time = 0.45
