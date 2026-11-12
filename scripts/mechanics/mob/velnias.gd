extends "res://scripts/mechanics/mechanic.gd"
## Велняс: болотяні вогні віялом (у люті — чотири). Так стріляють і бос, і його двійники.


func volley(dir: Vector2) -> void:
	for a in ([-0.3, -0.1, 0.1, 0.3] if e.phase2 else [-0.2, 0.0, 0.2]):
		shoot(e.global_position, dir.rotated(a), 320.0, e.damage * 0.5, Color(0.5, 0.95, 0.35), 10.0)
