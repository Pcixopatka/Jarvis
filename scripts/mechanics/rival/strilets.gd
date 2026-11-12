extends "res://scripts/mechanics/mob/rival.gd"
## Стрілець (Гнат Влучний): б'є з пищалі здалеку (постріл — від mob/rival.gd), а прийоми по колу:
## картеч конусом, порохова бочка туди, де стоїть ціль, відскок від того, хто підійшов надто близько.


func setup() -> void:
	e.ranged = true
	e.keep_distance = 330.0
	e.shoot_cd = 1.7
	e.shoot_timer = 1.2
	e.speed *= 0.9


func ability(target, dist: float) -> void:
	var to_t: Vector2 = (target.global_position - e.global_position).normalized()
	e.ability_timer = 3.6
	match e.ability_step % 3:
		1:
			# Картеч: конус перед собою
			var t = telegraph("cone", e.global_position, 0.8, e.damage * 1.2)
			t.dir = to_t
			t.length = 390.0
			t.half_angle = 0.45
			t.color = Color(1.0, 0.75, 0.3)
			e.cast_time = 0.8
			t.on_fire = func():
				Audio.play("musket", 0.05, 0.0)
		2:
			# Порохова бочка туди, де стоїть ціль
			var t = telegraph("circle", target.global_position, 1.3, e.damage * 1.5)
			t.radius = 125.0
			t.color = Color(1.0, 0.5, 0.15)
		0:
			# Відскок від ворога, що підійшов надто близько
			if dist < 230.0:
				e.knockback = -to_t * 1300.0
			e.shoot_timer = minf(e.shoot_timer, 0.4)
