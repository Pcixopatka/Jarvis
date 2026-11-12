extends "res://scripts/mechanics/mechanic.gd"
## Лихо Однооке: топче землю — хвиля по всій залі з вузькими безпечними щілинами; хапає й кидає;
## злий погляд накладає слабкість.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 4.0 if e.phase2 else 5.5
	match e.ability_step % 3:
		1:
			Audio.play("boom", 0.0, -4.0)
			for a in [-0.9, -0.3, 0.3, 0.9]:
				var t = telegraph("line", e.global_position, 1.2, e.damage * 1.4)
				t.dir = to_t.rotated(a)
				t.length = 700.0
				t.width = 120.0
				t.color = Color(0.55, 0.4, 0.6)
		2:
			var t = telegraph("circle", target.global_position, 0.8, e.damage * 1.2)
			t.radius = 110.0
			t.color = Color(0.7, 0.3, 0.6)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(t.global_position) < 110.0:
					target.push = (target.global_position - e.global_position).normalized() * 1600.0
		0:
			# Злий погляд: накладає слабкість на всіх у смузі
			var t = telegraph("cone", e.global_position, 1.0, e.damage * 0.8)
			t.dir = to_t
			t.length = 520.0
			t.half_angle = 0.35
			t.color = Color(0.9, 0.2, 0.3)
			t.on_fire = func():
				if is_instance_valid(target) and target.global_position.distance_to(e.global_position) < 520.0 and "statuses" in target:
					Status.apply(target, "weak", 5.0)


func phase2() -> void:
	rage("Лихо шаленіє!", ["upyr", "bolotianyk"])
