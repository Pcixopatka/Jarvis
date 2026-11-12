extends "res://scripts/mechanics/companion_mechanic.gd"
## Джура: підходить до ворога впритул і рубає шаблею.


func approach(target, _to: Vector2) -> Vector2:
	return target.global_position - c.facing * 30.0


func attack(target, dir: Vector2) -> void:
	target.take_damage(c.damage * randf_range(0.9, 1.1), dir * 160.0, false)
