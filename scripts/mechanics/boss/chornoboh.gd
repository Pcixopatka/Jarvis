extends "res://scripts/mechanics/mechanic.gd"
## Чорнобог: чорне сонце — удар у героя, а за ним кільце менших; коса смерті двома конусами; тіні з
## мороку (мари й хійсі, досвіду не дають), а сам переноситься до героя; прокляття, що знесилює;
## ґрати темряви — смуги вздовж, потім упоперек, стій між ними. Стріляє чорною спіраллю.

## Поворот чорної спіралі
var spin := 0.0


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	match e.ability_step % 5:
		1:
			e.ability_timer = 3.8 if e.phase2 else 4.8
			var c: Vector2 = target.global_position
			var t = telegraph("circle", c, 1.3, e.damage * 1.7)
			t.radius = 190.0
			t.color = Color(0.45, 0.15, 0.6)
			t.on_fire = func():
				combat.shake(12.0)
				if not alive():
					return
				for i in 8:
					var t2 = telegraph("circle", combat._clamp_in(c + Vector2.from_angle(TAU * i / 8.0) * 300.0, 40.0), 0.8, e.damage * 1.1)
					t2.radius = 80.0
					t2.color = Color(0.45, 0.15, 0.6)
		2:
			e.ability_timer = 3.6 if e.phase2 else 4.6
			for side in [-1.0, 1.0]:
				var t = telegraph("cone", e.global_position, 0.9 if side < 0.0 else 1.6, e.damage * 1.4)
				t.dir = to_t.rotated(0.55 * side)
				t.length = 520.0
				t.half_angle = 0.6
				t.color = Color(0.6, 0.1, 0.2)
			e.cast_time = 1.6
		3:
			e.ability_timer = 5.0
			Audio.play("roar", 0.05, -4.0)
			summon_free(["mara", "khiisi"], 4 if e.phase2 else 3)
			combat.fx.burst(e.global_position, Color(0.45, 0.15, 0.6), 24, 240, 8, 0.5)
			e.global_position = combat._clamp_in(target.global_position + Vector2.from_angle(randf() * TAU) * 340.0, 80.0)
			combat.fx.burst(e.global_position, Color(0.45, 0.15, 0.6), 24, 240, 8, 0.5)
		4:
			e.ability_timer = 4.0 if e.phase2 else 5.0
			var c: Vector2 = target.global_position
			var t = telegraph("circle", c, 1.0, e.damage * 1.0)
			t.radius = 170.0
			t.color = Color(0.3, 0.3, 0.35)
			t.on_fire = func():
				combat.spawn_plague(c, e.damage * 0.3, "plague", Color(0.4, 0.2, 0.5), 6.0)
				for a in combat.allies():
					if is_instance_valid(a) and a.global_position.distance_to(c) < 170.0 and "statuses" in a:
						Status.apply(a, "weak", 5.0)
		0:
			# Ґрати темряви: смуги вздовж, потім упоперек; стій між ними
			e.ability_timer = 4.6 if e.phase2 else 5.6
			var ar: Rect2 = combat.arena
			var n := 4 if e.phase2 else 3
			for i in n:
				var t = telegraph("line", Vector2(ar.position.x, ar.position.y + ar.size.y * (i + 0.5) / n), 1.1, e.damage * 1.5)
				t.dir = Vector2.RIGHT
				t.length = ar.size.x
				t.width = ar.size.y / n * 0.45
				t.color = Color(0.35, 0.1, 0.45)
			for i in n:
				var t = telegraph("line", Vector2(ar.position.x + ar.size.x * (i + 0.5) / n, ar.position.y), 2.0, e.damage * 1.5)
				t.dir = Vector2.DOWN
				t.length = ar.size.y
				t.width = ar.size.x / n * 0.45
				t.color = Color(0.35, 0.1, 0.45)
			e.cast_time = 1.1


func volley(_dir: Vector2) -> void:
	# Чорна спіраль: кільце щоразу трохи повертається
	var nc := 10 if e.phase2 else 7
	spin += 0.31
	for i in nc:
		shoot(e.global_position, Vector2.from_angle(TAU * i / nc + spin), 200.0, e.damage * 0.4, Color(0.6, 0.25, 0.8), 10.0)


func phase2() -> void:
	rage("Чорнобог гасить світло!", ["stallo", "khiisi", "mara"])
