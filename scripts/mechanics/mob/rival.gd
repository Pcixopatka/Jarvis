extends "res://scripts/mechanics/mechanic.gd"
## Суперник у герці: стрілець б'є кулею з пищалі. Прийоми суперників залежать від стилю бою, а не
## від виду, тому вони поки в Enemy._rival_ability.


func volley(dir: Vector2) -> void:
	shoot(e.global_position + dir * 26.0, dir, 520.0, e.damage * 0.8, Color(1.0, 0.8, 0.4), 6.0)  # куля з пищалі
	Audio.play("musket", 0.15, -8.0)
