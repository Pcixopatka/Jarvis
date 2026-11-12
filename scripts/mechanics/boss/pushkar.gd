extends "res://scripts/mechanics/mechanic.gd"
## Пушкар: Цар-гармата б'є смугою через усю залу, але кожен третій постріл — осічка (тоді пушкар
## приголомшений і беззахисний); ядра, що лишають вогонь; запал довкола себе, що відкидає.
## Стріляє картеччю — віялом дрібних куль.

## Скільки разів уже стріляла Цар-гармата (кожен третій постріл — осічка)
var cannon_shots := 0


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.6 if e.phase2 else 5.0
	match e.ability_step % 4:
		1, 3:
			cannon_shots += 1
			if cannon_shots % 3 == 0:
				var t = telegraph("circle", e.global_position, 1.2, e.damage * 1.0)
				t.radius = 190.0
				t.color = Color(0.5, 0.5, 0.5)
				t.on_fire = func():
					if alive():
						e.stun = 3.5
						e.exposed = 3.5
						combat.fx.burst(e.global_position, Color(0.45, 0.45, 0.45), 30, 260, 9, 0.8)
						Events.banner.emit("Цар-гармата знову не вистрілила!\nБий пушкаря!", Color(0.6, 1.0, 0.6))
						Events.hint.emit("pushkar_misfire", "Кожен третій постріл Цар-гармати — осічка. Вийди із сірого кола, а тоді бий приголомшеного пушкаря.")
				e.cast_time = 1.2
			else:
				for a in ([-0.28, 0.28] if e.phase2 else [0.0]):
					var t = telegraph("line", e.global_position, 1.6, e.damage * 1.8)
					t.dir = to_t.rotated(a)
					t.length = 900.0
					t.width = 170.0
					t.color = Color(1.0, 0.45, 0.1)
					t.on_fire = func(): combat.shake(12.0)
				e.cast_time = 1.6
		2:
			for i in (6 if e.phase2 else 4):
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(100, 220))
				var t = telegraph("circle", pos, 0.9 + 0.25 * i, e.damage * 1.0)
				t.radius = 100.0
				t.color = Color(1.0, 0.55, 0.15)
				t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.25, "burn", Color(1.0, 0.5, 0.1), 3.0)
		0:
			var t = telegraph("circle", e.global_position, 1.0, e.damage * 1.4)
			t.radius = 210.0
			t.color = Color(1.0, 0.6, 0.2)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 250.0:
					target.push = (target.global_position - e.global_position).normalized() * 1100.0
			e.cast_time = 1.0


func volley(dir: Vector2) -> void:
	# Картеч: віяло дрібних куль
	var np := 8 if e.phase2 else 6
	for i in np:
		shoot(e.global_position + dir * 30.0, dir.rotated(lerpf(-0.5, 0.5, i / float(np - 1))), 340.0, e.damage * 0.35, Color(1.0, 0.7, 0.3), 7.0)
	Audio.play("musket", 0.1, -6.0)


func phase2() -> void:
	rage("Пушкар засипає подвійний заряд!", ["mertvyi_strilets", "chort"])
