extends "res://scripts/mechanics/pet_mechanic.gd"
## Вороний скакун (божий дар): біжить поруч із героєм, трохи позаду й ліворуч.


func home(_carted: bool) -> Vector2:
	return player.position - player.facing * 44.0 + Vector2(-40.0, 18.0)
