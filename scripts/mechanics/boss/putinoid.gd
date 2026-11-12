extends "res://scripts/mechanics/mechanic.gd"
## Путіноїд: дощ зарази довкола героя, кличе заражених, пищальників і чортів, ривок трону через
## усю залу, кільце зарази з-під трону. Плюється заразою віялом (у люті — ширшим).


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.2 if e.phase2 else 4.5
	match e.ability_step % 4:
		1:
			# Дощ зарази
			Audio.play("lightning", 0.1, -6.0)
			for i in (5 if e.phase2 else 4):
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 150.0)
				var t = telegraph("circle", pos, 1.1, e.damage * 0.9)
				t.radius = 90.0
				t.color = Color(0.45, 0.9, 0.15)
				t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.5)
		2:
			Audio.play("roar", 0.15, -4.0)
			summon(["zarazhenyi", "pishchalnyk", "chort"], 4 if e.phase2 else 3)
		3:
			# Ривок трону — по прямій через усю залу
			var t = telegraph("line", e.global_position, 0.85, e.damage * 1.4)
			t.dir = to_t
			t.length = 620.0
			t.width = 110.0
			t.on_fire = func():
				if alive():
					e.knockback = to_t * 2000.0
		0:
			# Кільце зарази з-під трону
			combat.fx.burst(e.global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
			for i in 14:
				shoot(e.global_position, Vector2.from_angle(TAU * i / 14.0), 230.0, e.damage * 0.45, Color(0.45, 0.95, 0.2), 10.0)


func volley(dir: Vector2) -> void:
	var n := 7 if e.phase2 else 5
	for i in n:
		shoot(e.global_position, dir.rotated((i - (n - 1) / 2.0) * 0.18), 270.0, e.damage * 0.5, Color(0.5, 1.0, 0.2), 11.0)


func phase2() -> void:
	rage("Путіноїд скидає личину!", ["zarazhenyi", "pishchalnyk", "chort"])
