extends "res://scripts/mechanics/mob/rival.gd"
## Булавник (Тарас Важка Рука): повільний, зате міцніший і б'є важче. Б'є булавою об землю довкола себе
## (і відкидає), стрибає з ударом туди, де стоїть ціль, розганяється по прямій. Рветься до стрільця.


func setup() -> void:
	e.speed *= 0.75
	e.max_hp *= 1.25
	e.damage *= 1.15
	e.windup_max = 0.5
	e.rush = true


func ability(target, _dist: float) -> void:
	var to_t: Vector2 = (target.global_position - e.global_position).normalized()
	e.ability_timer = 3.6
	match e.ability_step % 3:
		1:
			# Удар булавою об землю довкола себе
			var t = telegraph("circle", e.global_position, 1.1, e.damage * 1.6)
			t.radius = 195.0
			e.cast_time = 1.1
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 240.0:
					target.push = (target.global_position - e.global_position).normalized() * 900.0
		2:
			# Стрибок із ударом у місце, де стоїть ціль
			var t = telegraph("circle", target.global_position, 1.0, e.damage * 1.5)
			t.radius = 130.0
			e.cast_time = 1.0
			t.on_fire = func():
				if alive():
					e.global_position = t.global_position
		0:
			# Розгін по прямій
			var t = telegraph("line", e.global_position, 0.8, e.damage * 1.4)
			t.dir = to_t
			t.length = 470.0
			t.width = 110.0
			e.cast_time = 0.8
			t.on_fire = func():
				if alive():
					e.knockback = to_t * 1800.0
