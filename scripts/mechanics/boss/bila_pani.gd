extends "res://scripts/mechanics/mob/bila_pani.gd"
## Біла Пані: зникає й постає поруч із криком, що відкидає й знесилює; мари — дві примари поруч зі
## справжньою; крижаний хрест через увесь зал. Плаче крижаними сльозами (mob/bila_pani.gd).


func ability(target, _dist: float) -> void:
	e.ability_timer = 3.4 if e.phase2 else 4.6
	match e.ability_step % 3:
		1:
			combat.fx.burst(e.global_position, Color(0.85, 0.9, 1.0), 24, 240, 7, 0.5)
			e.global_position = combat._clamp_in(target.global_position + Vector2.from_angle(randf() * TAU) * 150.0, 80.0)
			Audio.play("portal", 0.1, -2.0)
			var t = telegraph("circle", e.global_position, 1.0, e.damage * 1.3)
			t.radius = 230.0
			t.color = Color(0.8, 0.88, 1.0)
			t.on_fire = func():
				if is_instance_valid(target) and target.global_position.distance_to(e.global_position) < 280.0:
					if "push" in target:
						target.push = (target.global_position - e.global_position).normalized() * 1300.0
					if "statuses" in target:
						Status.apply(target, "weak", 4.0)
			e.cast_time = 1.0
		2:
			cast_illusions(target)
		0:
			Audio.play("spell", 0.1, 2.0)
			var spin := randf() * TAU
			var n_lines := 6 if e.phase2 else 4
			for i in n_lines:
				var d := Vector2.from_angle(spin + PI * i / float(n_lines))
				var t = telegraph("line", target.global_position - d * 520.0, 1.2, e.damage * 1.1)
				t.dir = d
				t.length = 1040.0
				t.width = 64.0
				t.color = Color(0.6, 0.85, 1.0)


func phase2() -> void:
	rage("Біла Пані кричить на весь замок!", ["mara", "upyr"])
