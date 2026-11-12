extends "res://scripts/mechanics/mechanic.gd"
## Морський цар: хвилі, що змивають усе на шляху й студять; вир, який лишає крижану воду; кличе
## потопельників. З тризуба бризкає віялом водяних куль.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.6 if e.phase2 else 5.0
	match e.ability_step % 3:
		1:
			Audio.play("boom", 0.2, -5.0)
			for a in ([-0.55, 0.0, 0.55] if e.phase2 else [-0.3, 0.3]):
				var t = telegraph("line", e.global_position, 1.1, e.damage * 1.3)
				t.dir = to_t.rotated(a)
				t.length = 760.0
				t.width = 130.0
				t.color = Color(0.3, 0.7, 0.9)
				t.on_fire = func():
					if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 760.0 and absf((target.global_position - e.global_position).angle_to(t.dir)) < 0.22:
						target.push = t.dir * 1300.0
						if "statuses" in target:
							Status.apply(target, "chill", 3.0)
		2:
			var pos: Vector2 = target.global_position
			var t = telegraph("circle", pos, 1.2, e.damage * 1.1)
			t.radius = 150.0
			t.color = Color(0.2, 0.55, 0.85)
			t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.3, "chill", Color(0.25, 0.6, 0.9), 5.0)
		0:
			Audio.play("roar", 0.15, -4.0)
			summon(["potopelnyk"], 3 if e.phase2 else 2)


func volley(dir: Vector2) -> void:
	# Бризки з тризуба: віяло водяних куль
	var nw := 7 if e.phase2 else 5
	for i in nw:
		shoot(e.global_position, dir.rotated((i - (nw - 1) / 2.0) * 0.2), 260.0, e.damage * 0.5, Color(0.35, 0.75, 1.0), 11.0)


func phase2() -> void:
	rage("Морський цар здіймає бурю!", ["potopelnyk", "mara"])
