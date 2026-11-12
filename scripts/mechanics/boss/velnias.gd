extends "res://scripts/mechanics/mob/velnias.gd"
## Велняс: пекельне коло довкола героя, середина якого б'є слідом; тризуб трьома смугами; морок —
## двійники, з яких справжній лише один; кличе айтварасів (прикликані досвіду не дають).
## Стріляє болотяними вогнями (mob/velnias.gd).


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	match e.ability_step % 4:
		1:
			e.ability_timer = 3.8 if e.phase2 else 4.8
			var c: Vector2 = target.global_position
			var spin := randf() * TAU
			for i in 8:
				var t = telegraph("circle", combat._clamp_in(c + Vector2.from_angle(spin + TAU * i / 8.0) * 175.0, 40.0), 1.0, e.damage * 1.2)
				t.radius = 75.0
				t.color = Color(0.5, 0.9, 0.35)
			# середина б'є слідом: коло треба встигнути перебігти
			var mid = telegraph("circle", c, 1.6 if e.phase2 else 1.9, e.damage * 1.4)
			mid.radius = 110.0
			mid.color = Color(0.4, 0.8, 0.3)
			mid.on_fire = func(): combat.spawn_plague(c, e.damage * 0.25, "burn", Color(0.5, 0.9, 0.35), 4.0)
		2:
			e.ability_timer = 3.4 if e.phase2 else 4.4
			for a in [-0.4, 0.0, 0.4]:
				var t = telegraph("line", e.global_position, 0.8, e.damage * 1.4)
				t.dir = to_t.rotated(a)
				t.length = 620.0
				t.width = 50.0
				t.color = Color(0.85, 0.75, 0.3)
			e.cast_time = 0.8
		3:
			e.ability_timer = 5.0 if e.phase2 else 6.0
			Events.hint.emit("velnias_trick", "Велняс морочить: із трьох справжній лише один. Двійники розсипаються від першого ж удару.")
			cast_illusions(target)
		0:
			e.ability_timer = 5.0
			Audio.play("roar", 0.05, -4.0)
			summon_free(["aitvaras"], 3 if e.phase2 else 2)


func phase2() -> void:
	rage("Велняс скидає людську личину!", ["mertvyi_lytsar", "lauma"])
