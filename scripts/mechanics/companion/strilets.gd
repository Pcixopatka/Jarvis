extends "res://scripts/mechanics/companion_mechanic.gd"
## Стрілець: тримається на відстані й стріляє з рушниці.


func attack(_target, dir: Vector2) -> void:
	combat.spawn_bullet(c.global_position + dir * 20.0, dir, c.damage, false)
	var shot = combat.last_projectile()
	if shot != null:
		shot.ally = true  # влучання рахується побратимові, а не героєві
