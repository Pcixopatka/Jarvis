extends "res://scripts/mechanics/mob/rival.gd"
## Списник (Данило Довгий Спис): тримається на відстані списа; по черзі коле по прямій із випадом уперед
## і широко замахується древком, відскакуючи назад.


func setup() -> void:
	e.keep_distance = 170.0


func ability(target, _dist: float) -> void:
	var to_t: Vector2 = (target.global_position - e.global_position).normalized()
	e.ability_timer = 2.1
	if e.ability_step % 2 == 1:
		# Укол по прямій із випадом уперед
		var t = telegraph("line", e.global_position, 0.55, e.damage * 1.3)
		t.dir = to_t
		t.length = 310.0
		t.width = 56.0
		e.cast_time = 0.55
		t.on_fire = func():
			if alive():
				e.knockback = to_t * 700.0
	else:
		# Широкий замах древком і відскок назад
		var t = telegraph("cone", e.global_position, 0.7, e.damage * 1.0)
		t.dir = to_t
		t.length = 220.0
		t.half_angle = 1.0
		t.color = Color(0.9, 0.8, 0.6)
		e.cast_time = 0.7
		t.on_fire = func():
			if alive():
				e.knockback = -to_t * 900.0
