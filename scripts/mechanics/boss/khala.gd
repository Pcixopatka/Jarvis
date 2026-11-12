extends "res://scripts/mechanics/parts/wind.gd"
## Хала: градобій довкола героя (дещо з граду лишає крижані калюжі); блискавки смугами; вихор, що
## тягне героя до неї, а тоді б'є довкола; буревій, проти якого треба йти (parts/wind.gd).
## Стріляє крижаними кулями віялом.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	match e.ability_step % 4:
		1:
			e.ability_timer = 4.4 if e.phase2 else 5.4
			for i in (9 if e.phase2 else 6):
				var pos: Vector2 = combat._clamp_in(target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0, 260), 60.0)
				var t = telegraph("circle", pos, 0.8 + 0.22 * i, e.damage * 0.9)
				t.radius = 80.0
				t.color = Color(0.75, 0.88, 1.0)
				if i % 3 == 0:
					t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.22, "chill", Color(0.75, 0.88, 1.0), 4.0)
		2:
			e.ability_timer = 3.4 if e.phase2 else 4.4
			var fan: Array = [-0.35, 0.0, 0.35] if e.phase2 else [0.0]
			for a in fan:
				var t = telegraph("line", e.global_position, 0.7, e.damage * 1.5)
				t.dir = to_t.rotated(a)
				t.length = 760.0
				t.width = 54.0
				t.color = Color(0.7, 0.85, 1.0)
			e.cast_time = 0.7
		3:
			e.ability_timer = 4.0 if e.phase2 else 5.0
			var t = telegraph("cone", e.global_position, 0.9, e.damage * 0.5)
			t.dir = to_t
			t.length = 520.0
			t.half_angle = 0.5
			t.color = Color(0.55, 0.65, 0.9)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
					target.push = (e.global_position - target.global_position).normalized() * 1400.0
				if alive():
					var t2 = telegraph("circle", e.global_position, 1.4, e.damage * 1.3)
					t2.radius = 190.0
					t2.color = Color(0.7, 0.85, 1.0)
			e.cast_time = 0.9
		0:
			start_wind(to_t, 3.0 if e.phase2 else 2.5)
			Events.banner.emit("Буревій! Іди проти вітру", Color(0.75, 0.9, 1.0))
			for i in (6 if e.phase2 else 4):
				var pos: Vector2 = combat._clamp_in(target.global_position + wind_dir * randf_range(120, 420) + Vector2.from_angle(randf() * TAU) * randf_range(0, 80), 60.0)
				var t = telegraph("circle", pos, 1.2 + 0.35 * i, e.damage * 0.9)
				t.radius = 85.0
				t.color = Color(0.7, 0.85, 1.0)


func volley(dir: Vector2) -> void:
	for a in ([-0.3, -0.1, 0.1, 0.3] if e.phase2 else [-0.2, 0.0, 0.2]):
		shoot(e.global_position, dir.rotated(a), 320.0, e.damage * 0.35, Color(0.7, 0.88, 1.0), 10.0)


func phase2() -> void:
	rage("Хала затуляє небо!", ["karakondzhul", "samodiva"])
