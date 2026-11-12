extends "res://scripts/mechanics/mechanic.gd"
## Лісовий Дід: то стає вищий за ліс — повільний і товстошкірий, тупає й валить дерева; то нижчий
## за траву — швидкий і крихкий, кидається ривками. У люті ще й лишає під ногами студене болото.

## Зараз нижчий за траву
var small := false


func setup() -> void:
	e._base_speed = e.speed  # від неї рахується швидкість, коли Дід міняє зріст


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.4 if e.phase2 else 4.6
	match e.ability_step % 4:
		1:
			set_size(false)
			Events.banner.emit("Лісовий Дід став вищий за ліс!", Color(1.0, 0.7, 0.4))
			var t = telegraph("circle", e.global_position, 1.2, e.damage * 1.4)
			t.radius = 280.0
			t.color = Color(0.55, 0.42, 0.25)
			t.on_fire = func():
				if is_instance_valid(target) and "push" in target and target.global_position.distance_to(e.global_position) < 330.0:
					target.push = (target.global_position - e.global_position).normalized() * 1200.0
			e.cast_time = 1.2
		2:
			var spin := randf() * TAU
			for i in 4:
				var d := Vector2.from_angle(spin + PI * i / 4.0)
				var t = telegraph("line", target.global_position - d * 450.0, 1.4 + 0.15 * i, e.damage * 1.2)
				t.dir = d
				t.length = 900.0
				t.width = 80.0
				t.color = Color(0.45, 0.32, 0.2)
			if e.phase2:
				for i in 2:
					var pos: Vector2 = target.global_position + Vector2.from_angle(randf() * TAU) * 140.0
					var t = telegraph("circle", pos, 1.0, e.damage * 0.9)
					t.radius = 90.0
					t.color = Color(0.4, 0.6, 0.3)
					t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.25, "chill", Color(0.4, 0.6, 0.3), 4.0)
			e.cast_time = 1.0
		3, 0:
			if e.ability_step % 4 == 3:
				set_size(true)
				Events.banner.emit("Лісовий Дід став нижчий за траву!", Color(1.0, 0.7, 0.4))
			var t = telegraph("line", e.global_position, 0.5, e.damage * 1.3)
			t.dir = to_t
			t.length = 400.0
			t.width = 64.0
			t.color = Color(0.5, 0.75, 0.35)
			t.on_fire = func():
				if alive():
					e.knockback = to_t * 1700.0
			e.cast_time = 0.5


func phase2() -> void:
	rage("Лісовий Дід кличе весь ліс!", ["lisovyk", "vedmid"])


## Міняє зріст: малий — швидкий і крихкий, великий — повільний і товстошкірий.
func set_size(is_small: bool) -> void:
	small = is_small
	e.base_scale = 1.1 if is_small else 2.0
	e.scale = Vector2.ONE * e.base_scale
	e.radius = e.r_draw * e.base_scale
	e.speed = e._base_speed * (1.9 if is_small else 0.6) * (1.2 if e.phase2 else 1.0)
	e.dmg_taken_mult = 1.4 if is_small else 0.6
	combat.fx.burst(e.global_position, Color(0.5, 0.8, 0.35), 30, 260, 8, 0.6)
