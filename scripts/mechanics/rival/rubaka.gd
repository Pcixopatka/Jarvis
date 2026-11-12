extends "res://scripts/mechanics/mob/rival.gd"
## Рубака (Остап Рубай): сипле серією з трьох рубких ударів віялом, а кожен третій прийом — ривок по прямій.
## Швидший за інших і рветься до стрільця, що тримає відстань.


func setup() -> void:
	e.speed *= 1.1
	e.windup_max = 0.3
	e.rush = true


func ability(target, _dist: float) -> void:
	var to_t: Vector2 = (target.global_position - e.global_position).normalized()
	if e.ability_step % 3 == 0:
		# Ривок по прямій
		e.ability_timer = 3.0
		var t = telegraph("line", e.global_position, 0.6, e.damage * 1.4)
		t.dir = to_t
		t.length = 420.0
		t.width = 80.0
		e.cast_time = 0.6
		t.on_fire = func():
			if alive():
				e.knockback = to_t * 1700.0
	else:
		# Серія з трьох рубких ударів віялом: стоїть на місці й рубає
		e.ability_timer = 2.8
		e.cast_time = 1.1
		for i in 3:
			var t = telegraph("cone", e.global_position, 0.5 + 0.28 * i, e.damage * 0.9)
			t.dir = to_t.rotated((i - 1) * 0.55)
			t.length = 160.0
			t.half_angle = 0.6
			t.color = Color(1.0, 0.85, 0.5)
