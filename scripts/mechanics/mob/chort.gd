extends "res://scripts/mechanics/mechanic.gd"
## Чорт: зникає в клубі диму й вигулькує просто біля цілі, а тоді мить зволікає з ударом.

var blink_timer := 2.5


func chase(target, dist: float, _dir: Vector2, delta: float) -> void:
	blink_timer -= delta
	if blink_timer <= 0.0 and dist > 160.0 and dist < 900.0:
		blink_timer = randf_range(3.5, 5.0)
		combat.fx.burst(e.global_position, Color(0.3, 0.1, 0.05), 14, 160, 6, 0.4)
		e.global_position = target.global_position + Vector2.from_angle(randf() * TAU) * 80.0
		combat.fx.burst(e.global_position, Color(0.9, 0.35, 0.1), 14, 160, 6, 0.4)
		e.windup = e.windup_max * 1.6  # даємо мить, щоб ухилитися
