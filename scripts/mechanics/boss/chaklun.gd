extends "res://scripts/mechanics/mob/chaklun.gd"
## Чаклун: стріляє згустками зарази, як і звичайний (mob/chaklun.gd), а по черзі ще й:
## дощ зарази — три зони навколо цілі, після яких лишаються хмари; кличе заражених; зникає в
## зеленому димі й постає якнайдалі від героя, розкидаючи кільце снарядів.


func ability(target, _dist: float) -> void:
	e.ability_timer = 4.5
	match e.ability_step % 3:
		1:
			# Дощ зарази: три зони навколо цілі, після удару лишаються хмари
			Audio.play("lightning", 0.1, -6.0)
			for i in 3:
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 130.0)
				var t = telegraph("circle", pos, 1.1, e.damage * 0.9)
				t.radius = 85.0
				t.color = Color(0.45, 0.9, 0.15)
				t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.5)
		2:
			Audio.play("roar", 0.15, -4.0)
			summon(["zarazhenyi"], 3)
		0:
			# Зникає в зеленому димі й з'являється подалі, розкидаючи кільце снарядів
			combat.fx.burst(e.global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
			var best: Vector2 = e.global_position
			for i in 8:
				var cand := Vector2(randf_range(combat.arena.position.x + 120, combat.arena.end.x - 120), randf_range(combat.arena.position.y + 120, combat.arena.end.y - 120))
				if cand.distance_to(target.global_position) > best.distance_to(target.global_position):
					best = cand
			e.global_position = best
			combat.fx.burst(e.global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
			for i in 10:
				shoot(e.global_position, Vector2.from_angle(TAU * i / 10.0), 220.0, e.damage * 0.45, Color(0.45, 0.95, 0.2), 10.0)
