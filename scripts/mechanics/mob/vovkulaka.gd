extends "res://scripts/mechanics/mechanic.gd"
## Вовкулака: коли герой близько, робить стрибок на нього (і звичайний, і бос).

var lunge_timer := 0.0


func tick(delta: float) -> void:
	lunge_timer = maxf(0.0, lunge_timer - delta)


func chase(_target, dist: float, dir: Vector2, _delta: float) -> void:
	if dist < 220.0 and lunge_timer <= 0.0:
		lunge_timer = 2.5
		e.knockback += dir * 520.0
