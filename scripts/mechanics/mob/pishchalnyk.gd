extends "res://scripts/mechanics/mechanic.gd"
## Пищальник: стріляє з пищалі — одна швидка куля.


func volley(dir: Vector2) -> void:
	shoot(e.global_position + dir * 24.0, dir, 420.0, e.damage, Color(1.0, 0.75, 0.3), 7.0)
