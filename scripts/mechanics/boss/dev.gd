extends "res://scripts/mechanics/mechanic.gd"
## Дев: кидає скелі довкола героя; гупає довкола себе й відкидає; таранить по прямій; кличе алмастів
## (прикликані досвіду не дають).


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	match e.ability_step % 4:
		1:
			e.ability_timer = 4.2 if e.phase2 else 5.2
			for i in (5 if e.phase2 else 3):
				var pos: Vector2 = combat._clamp_in(target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(120, 260)), 60.0)
				var t = telegraph("circle", pos, 0.9 + 0.25 * i, e.damage * 1.2)
				t.radius = 105.0
				t.color = Color(0.6, 0.6, 0.62)
				t.on_fire = func(): combat.shake(7.0)
		2:
			e.ability_timer = 4.0 if e.phase2 else 5.0
			var t = telegraph("circle", e.global_position, 1.1, e.damage * 1.6)
			t.radius = 250.0
			t.color = Color(0.75, 0.6, 0.45)
			t.on_fire = func():
				combat.shake(12.0)
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 300.0:
					target.push = (target.global_position - e.global_position).normalized() * 1100.0
			e.cast_time = 1.1
		3:
			e.ability_timer = 4.0 if e.phase2 else 5.0
			var t = telegraph("line", e.global_position, 0.8, e.damage * 1.5)
			t.dir = to_t
			t.length = 560.0
			t.width = 110.0
			t.color = Color(0.8, 0.5, 0.3)
			t.on_fire = func():
				if alive():
					e.knockback = to_t * 2300.0
			e.cast_time = 0.8
		0:
			e.ability_timer = 5.0
			Audio.play("roar", 0.05, -4.0)
			summon_free(["almasty"], 3 if e.phase2 else 2)


func phase2() -> void:
	rage("Дев рве ланцюг!", ["almasty", "kadzhi"])
