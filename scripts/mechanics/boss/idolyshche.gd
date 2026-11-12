extends "res://scripts/mechanics/parts/feast.gd"
## Ідолище: ківш браги під ноги героя (знесилює); ковтає — тягне героя до себе; гупає черевом;
## сідає бенкетувати й гоїться, поки його не переб'ють шкодою (parts/feast.gd). Кидає обгризені кістки.


func _init() -> void:
	feast_text = ["Ідолище сіло бенкетувати!\nЗавдай шкоди, поки не вдавиться", "Ідолище наїлося й набралося сил.", "Ідолище вдавилося! Бий!"]


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 4.0 if e.phase2 else 5.5
	match e.ability_step % 4:
		1:
			for i in (2 if e.phase2 else 1):
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 200.0)
				var t = telegraph("circle", pos, 1.2, e.damage * 1.2)
				t.radius = 150.0
				t.color = Color(0.75, 0.55, 0.25)
				t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.25, "weak", Color(0.75, 0.55, 0.25), 5.0)
		2:
			var t = telegraph("cone", e.global_position, 1.1, e.damage * 0.6)
			t.dir = to_t
			t.length = 480.0
			t.half_angle = 0.5
			t.color = Color(0.6, 0.45, 0.35)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and t.contains(target.global_position):
					target.push = (e.global_position - target.global_position).normalized() * 1500.0
			e.cast_time = 1.1
			e.ability_timer = 2.1
		3:
			var t = telegraph("circle", e.global_position, 1.0, e.damage * 1.5)
			t.radius = 220.0
			t.color = Color(0.8, 0.6, 0.4)
			t.on_fire = func():
				combat.shake(10.0)
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 270.0:
					target.push = (target.global_position - e.global_position).normalized() * 1000.0
			e.cast_time = 1.0
		0:
			start_feast()
			Events.banner.emit(str(feast_text[0]), Color(1.0, 0.7, 0.4))
			Events.hint.emit("idol_feast", "Ідолище бенкетує й відновлює здоров'я. Завдай йому багато шкоди за ці чотири секунди, і воно вдавиться й стане беззахисним.")


func volley(dir: Vector2) -> void:
	# Обгризені кістки (поки бенкетує — не кидає)
	if feast <= 0.0:
		for a in [-0.25, 0.0, 0.25]:
			shoot(e.global_position, dir.rotated(a), 260.0, e.damage * 0.5, Color(0.92, 0.88, 0.78), 11.0)


func phase2() -> void:
	Events.banner.emit("Ідолище реве: «Ще їсти!»", Color(1.0, 0.4, 0.3))
	stop_feast()
	summon(["boyaryn", "zlyden", "zlyden"], 3)
