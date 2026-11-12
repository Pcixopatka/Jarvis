extends "res://scripts/mechanics/mechanic.gd"
## Чаклун: кидає віялом чотири згустки зарази (і звичайний, і бос).


func volley(dir: Vector2) -> void:
	for a in [-0.3, -0.1, 0.1, 0.3]:
		shoot(e.global_position, dir.rotated(a), 250.0, e.damage * 0.5, Color(0.45, 0.95, 0.2), 11.0)
