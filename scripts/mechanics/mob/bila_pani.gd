extends "res://scripts/mechanics/mechanic.gd"
## Біла Пані: крижані сльози — три швидкі бурульки. Так стріляють і бос, і її мари.


func volley(dir: Vector2) -> void:
	for a in [-0.16, 0.0, 0.16]:
		shoot(e.global_position, dir.rotated(a), 330.0, e.damage * 0.55, Color(0.85, 0.93, 1.0), 9.0)
