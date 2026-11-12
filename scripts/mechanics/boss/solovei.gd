extends "res://scripts/mechanics/mechanic.gd"
## Соловей-розбійник: посвист валить хвилею від себе; свистить з дуба — стріли падають дощем довкола
## героя. Стріляє кільцем звукових хвиль.


func ability(target, _dist: float) -> void:
	e.ability_timer = 3.4 if e.phase2 else 5.0
	match e.ability_step % 2:
		1:
			var t = telegraph("circle", e.global_position, 1.2, e.damage * 1.5)
			t.radius = 260.0
			t.color = Color(0.75, 0.9, 1.0)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 320.0:
					target.push = (target.global_position - e.global_position).normalized() * 1400.0
			Audio.play("roar", 0.3, -3.0)
		0:
			for i in (6 if e.phase2 else 4):
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 160.0)
				var t = telegraph("circle", pos, 1.0, e.damage * 0.9)
				t.radius = 80.0
				t.color = Color(0.6, 0.75, 0.5)


func volley(_dir: Vector2) -> void:
	# Посвист: кільце звукових хвиль
	var n := 10 if e.phase2 else 8
	for i in n:
		shoot(e.global_position, Vector2.from_angle(TAU * i / n + e.phase * 0.1), 200.0, e.damage * 0.4, Color(0.8, 0.9, 1.0), 9.0)


func phase2() -> void:
	rage("Соловей свище на повну!", ["vovkulaka", "chort"])
