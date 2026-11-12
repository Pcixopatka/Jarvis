extends "res://scripts/mechanics/mechanic.gd"
## Кікімора: пряде з туману пряжу під ногами героя, і та студить.


func ability(target, dist: float) -> void:
	e.ability_timer = randf_range(6.0, 8.0)
	if dist > 600.0:
		e.ability_timer = 1.0
		return
	var pos: Vector2 = target.global_position
	var t = telegraph("circle", pos, 1.1, e.damage * 0.8)
	t.radius = 80.0
	t.color = Color(0.6, 0.66, 0.72)
	t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.25, "chill", Color(0.6, 0.66, 0.72), 3.0)
	e.cast_time = 0.6
