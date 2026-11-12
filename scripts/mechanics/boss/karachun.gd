extends "res://scripts/mechanics/parts/wind.gd"
## Карачун: хуртовина зносить героя до крижаних кіл (parts/wind.gd); крижаний острог довкола героя;
## подих морозу, що студить. Стріляє сніжною спіраллю, що щоразу трохи повертається.

## Поворот сніжної спіралі
var spin := 0.0


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	match e.ability_step % 3:
		1:
			start_wind(to_t, 4.0 if e.phase2 else 3.0)
			Events.banner.emit("Хуртовина! Іди проти вітру", Color(0.75, 0.9, 1.0))
			Events.hint.emit("karachun_wind", "Хуртовина зносить тебе до крижаних кіл. Іди проти вітру: Карачун тоді стоїть на місці. Під час перекиду вітер тебе не зносить, а в Блоці не встоїш.")
			for i in (7 if e.phase2 else 5):
				var pos: Vector2 = combat._clamp_in(target.global_position + wind_dir * randf_range(120, 420) + Vector2.from_angle(randf() * TAU) * randf_range(0, 80), 60.0)
				var t = telegraph("circle", pos, 1.0 + 0.3 * i, e.damage * 0.9)
				t.radius = 85.0
				t.color = Color(0.75, 0.88, 1.0)
		2:
			e.ability_timer = 3.6 if e.phase2 else 5.0
			var c: Vector2 = target.global_position
			var spin_o := randf() * TAU
			for i in 7:
				var pos: Vector2 = c if i == 6 else c + Vector2.from_angle(spin_o + TAU * i / 6.0) * 190.0
				var t = telegraph("circle", pos, 1.1 if e.phase2 else 1.4, e.damage * 1.1)
				t.radius = 70.0
				t.color = Color(0.7, 0.85, 1.0)
				if i == 6:
					t.on_fire = func(): combat.spawn_plague(c, e.damage * 0.25, "chill", Color(0.7, 0.85, 1.0), 4.0)
		0:
			e.ability_timer = 3.6 if e.phase2 else 5.0
			var t = telegraph("cone", e.global_position, 1.0, e.damage * 1.2)
			t.dir = to_t
			t.length = 460.0
			t.half_angle = 0.5
			t.color = Color(0.6, 0.85, 1.0)
			t.on_fire = func():
				for a in combat.allies():
					if is_instance_valid(a) and t.contains(a.global_position) and "statuses" in a:
						Status.apply(a, "chill", 4.0)
			e.cast_time = 1.0


func volley(_dir: Vector2) -> void:
	# Сніжна спіраль: кільце щоразу трохи повертається
	var nk := 8 if e.phase2 else 6
	spin += 0.26
	for i in nk:
		shoot(e.global_position, Vector2.from_angle(TAU * i / nk + spin), 190.0, e.damage * 0.4, Color(0.85, 0.93, 1.0), 10.0)


func phase2() -> void:
	rage("Карачун кличе найдовшу ніч!", ["vedmid", "lisovyk"])
