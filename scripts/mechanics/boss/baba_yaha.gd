extends "res://scripts/mechanics/mechanic.gd"
## Баба Яга: літає в ступі — переліт у місце цілі з ударом; мітла мете конусом і відкидає; кличе мавок
## та упирів. З печі кидає дві повільні вогняні кулі.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.6 if e.phase2 else 4.8
	match e.ability_step % 3:
		1:
			var t = telegraph("circle", target.global_position, 1.0, e.damage * 1.3)
			t.radius = 130.0
			t.color = Color(1.0, 0.6, 0.2)
			t.on_fire = func():
				if alive():
					combat.fx.burst(e.global_position, Color(0.5, 0.4, 0.3), 20, 200, 7, 0.5)
					e.global_position = t.global_position
					combat.fx.burst(e.global_position, Color(1.0, 0.6, 0.2), 24, 240, 8, 0.5)
			Audio.play("roar", 0.1, -5.0)
		2:
			var t = telegraph("cone", e.global_position, 0.9, e.damage * 1.1)
			t.dir = to_t
			t.length = 380.0
			t.half_angle = 0.6
			t.color = Color(0.8, 0.6, 0.3)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 380.0:
					target.push = to_t * 900.0
		0:
			Audio.play("roar", 0.05, -4.0)
			summon(["mavka", "upyr"], 3 if e.phase2 else 2)


func volley(dir: Vector2) -> void:
	# Жар із печі: дві повільні вогняні кулі, що підпалюють
	for a in [-0.15, 0.15]:
		shoot(e.global_position, dir.rotated(a), 240.0, e.damage * 0.55, Color(1.0, 0.5, 0.1), 12.0)


func phase2() -> void:
	rage("Яга розпалює піч!", ["mavka", "upyr"])
