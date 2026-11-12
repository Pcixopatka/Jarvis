extends "res://scripts/mechanics/mechanic.gd"
## Боярин-упир: кличе злиднів «до роботи» (не більше трьох поруч); прикликані досвіду не дають.


func ability(_target, dist: float) -> void:
	e.ability_timer = 2.0
	if dist > 700.0:
		return
	var near := 0
	for o in combat.enemies_now():
		if o.kind == "zlyden" and not o.dead and o.global_position.distance_to(e.global_position) < 700.0:
			near += 1
	if near >= 3:
		return
	e.ability_timer = randf_range(7.0, 9.0)
	e.cast_time = 0.8
	combat.fx.burst(e.global_position, Color(1.0, 0.8, 0.3), 18, 180, 6, 0.5)
	combat.float_text(e.global_position + Vector2(0, -e.radius - 30), "Злидні, до роботи!", Color(1.0, 0.8, 0.3))
	for i in 2:
		combat.spawn_enemy("zlyden", maxi(1, e.level - 1), false, e.global_position + Vector2.from_angle(randf() * TAU) * randf_range(90, 160))
		var z = combat._last_enemy()
		if z != null and z != e:
			z.xp_value = 0
