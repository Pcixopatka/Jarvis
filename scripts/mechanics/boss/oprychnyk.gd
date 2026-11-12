extends "res://scripts/mechanics/mechanic.gd"
## Опричник-кат: мітла й собача голова — ривок із сокирою; кидає ланцюг, що тягне героя до себе;
## кличе кромішників і мертвих стрільців.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.2 if e.phase2 else 4.5
	match e.ability_step % 3:
		1:
			var t = telegraph("line", e.global_position, 0.7, e.damage * 1.5)
			t.dir = to_t
			t.length = 460.0
			t.width = 100.0
			t.color = Color(0.9, 0.2, 0.15)
			t.on_fire = func():
				if alive():
					e.knockback = to_t * 1800.0
		2:
			# Ланцюг: тягне ціль до ката
			var t = telegraph("line", e.global_position, 0.9, e.damage * 0.7)
			t.dir = to_t
			t.length = 560.0
			t.width = 60.0
			t.color = Color(0.7, 0.7, 0.75)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 560.0:
					target.push = (e.global_position - target.global_position).normalized() * 1500.0
		0:
			Audio.play("roar", 0.15, -4.0)
			summon(["kromeshnyk", "mertvyi_strilets"], 3 if e.phase2 else 2)


func phase2() -> void:
	rage("Кат спускає псів!", ["kromeshnyk", "mertvyi_strilets", "vovkulaka"])
