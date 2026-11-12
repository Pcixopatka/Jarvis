extends "res://scripts/mechanics/parts/feast.gd"
## Золота Баба: золоті промені хрестом (у люті — дві хвилі); золота лихоманка під ногами героя;
## обвал по всій залі; вбирає жертовне золото й гоїться, поки її не переб'ють шкодою (parts/feast.gd).
## Кидає віялом п'ять золотих куль.


func _init() -> void:
	feast_text = ["Золота Баба вбирає жертовне золото!\nЗавдай шкоди, поки не налилася силою", "Золота Баба налилася силою.", "Золото розсипалось! Бий!"]


func ability(target, _dist: float) -> void:
	match e.ability_step % 4:
		1:
			e.ability_timer = 3.6 if e.phase2 else 4.6
			var base := randf() * TAU
			for wave in (2 if e.phase2 else 1):
				for i in 4:
					var t = telegraph("line", e.global_position, 1.0 + 0.7 * wave, e.damage * 1.5)
					t.dir = Vector2.from_angle(base + TAU * i / 4.0 + wave * PI / 4.0)
					t.length = 720.0
					t.width = 64.0
					t.color = Color(1.0, 0.85, 0.3)
			e.cast_time = 1.0
		2:
			e.ability_timer = 4.0 if e.phase2 else 5.0
			var c: Vector2 = target.global_position
			var t = telegraph("circle", c, 1.1, e.damage * 1.1)
			t.radius = 150.0
			t.color = Color(1.0, 0.8, 0.25)
			t.on_fire = func(): combat.spawn_plague(c, e.damage * 0.25, "weak", Color(1.0, 0.8, 0.25), 5.0)
		3:
			e.ability_timer = 4.6 if e.phase2 else 5.6
			for i in (10 if e.phase2 else 7):
				var pos: Vector2 = target.global_position
				if i > 0:
					pos = Vector2(randf_range(combat.arena.position.x + 90, combat.arena.end.x - 90), randf_range(combat.arena.position.y + 90, combat.arena.end.y - 90))
				var t = telegraph("circle", pos, 0.9 + 0.2 * i, e.damage * 1.2)
				t.radius = 95.0
				t.color = Color(0.75, 0.65, 0.4)
		0:
			start_feast()
			Events.banner.emit(str(feast_text[0]), Color(1.0, 0.85, 0.3))
			Events.hint.emit("baba_gold", "Золота Баба лікується жертовним золотом. Завдай їй багато шкоди за ці чотири секунди, і золото розсиплеться, а вона стане беззахисною.")


func volley(dir: Vector2) -> void:
	if feast <= 0.0:
		for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			shoot(e.global_position, dir.rotated(a), 250.0, e.damage * 0.45, Color(1.0, 0.85, 0.3), 11.0)


func phase2() -> void:
	Events.banner.emit("Золота Баба розплющує очі!", Color(1.0, 0.4, 0.3))
	stop_feast()
	summon(["menkv", "chud"], 3)
