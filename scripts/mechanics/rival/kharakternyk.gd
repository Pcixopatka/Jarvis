extends "res://scripts/mechanics/mob/rival.gd"
## Характерник (Марко Проклятий): зникає в диму й вигулькує за спиною, кличе три блискавки, відводить очі —
## перестрибує вбік і б'є ривком. Рветься до стрільця, що тримає відстань.


func setup() -> void:
	e.windup_max = 0.3
	e.rush = true


func ability(target, _dist: float) -> void:
	var to_t: Vector2 = (target.global_position - e.global_position).normalized()
	e.ability_timer = 3.3
	match e.ability_step % 3:
		1:
			# Зникає в диму й вигулькує за спиною
			combat.spawn_fx("smoke", e.global_position - Vector2(0, 10), 1.4)
			var behind: Vector2 = target.global_position + to_t * 80.0
			e.global_position = behind.clamp(combat.arena.position + Vector2(40, 40), combat.arena.end - Vector2(40, 40))
			combat.spawn_fx("smoke", e.global_position - Vector2(0, 10), 1.4, 0.0, Color(0.7, 0.6, 1.0))
			e.windup = e.windup_max * 1.6  # мить, щоб обернутись і ухилитись
		2:
			# Три блискавки: одна в ціль, дві поруч, одна за одною
			Audio.play("lightning", 0.1, -6.0)
			for i in 3:
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 140.0)
				var t = telegraph("circle", pos, 0.8 + 0.3 * i, e.damage * 1.0)
				t.radius = 82.0
				t.color = Color(0.6, 0.8, 1.0)
				t.on_fire = func():
					combat.spawn_bolt(PackedVector2Array([pos + Vector2(12, -420), pos + Vector2(-16, -180), pos]))
		0:
			# Відвід очей: перестрибує вбік і б'є ривком
			combat.spawn_fx("smoke", e.global_position - Vector2(0, 10), 1.2, 0.0, Color(0.7, 0.6, 1.0))
			var side_pos: Vector2 = target.global_position + to_t.orthogonal() * (220.0 if randf() < 0.5 else -220.0)
			e.global_position = side_pos.clamp(combat.arena.position + Vector2(40, 40), combat.arena.end - Vector2(40, 40))
			var d2: Vector2 = (target.global_position - e.global_position).normalized()
			var t = telegraph("line", e.global_position, 0.6, e.damage * 1.3)
			t.dir = d2
			t.length = 380.0
			t.width = 70.0
			t.color = Color(0.7, 0.6, 1.0)
			e.cast_time = 0.6
			t.on_fire = func():
				if alive():
					e.knockback = d2 * 1500.0
