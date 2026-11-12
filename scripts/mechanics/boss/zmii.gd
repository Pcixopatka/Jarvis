extends "res://scripts/mechanics/mechanic.gd"
## Змій Горинич: дихає вогнем конусом перед собою, а з трьох пащ плюється вогняними кулями.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	# Вогняний подих конусом
	e.ability_timer = 5.5
	var t = telegraph("cone", e.global_position, 1.0, e.damage * 1.3)
	t.dir = to_t
	t.length = 420.0
	t.half_angle = 0.42
	t.color = Color(1.0, 0.45, 0.1)
	Audio.play("roar", 0.05, -3.0)


func volley(dir: Vector2) -> void:
	for a in [-0.35, 0.0, 0.35]:
		shoot(e.global_position + dir * 40.0, dir.rotated(a), 300.0, e.damage * 0.6, Color(1.0, 0.5, 0.1), 13.0)
