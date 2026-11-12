extends "res://scripts/mechanics/pet_mechanic.gd"
## Ворон Карк: кружляє над плечем героя, з того боку, звідки той прийшов.


func home(_carted: bool) -> Vector2:
	return player.position + Vector2(-player.facing.x * 30.0, -8.0)
