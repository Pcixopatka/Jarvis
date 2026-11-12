extends "res://scripts/mechanics/pet_mechanic.gd"
## Хованець (божий дар): бігає поруч із героєм і, як пес, зносить здобич, яку герой зараз може взяти.


func fetches() -> bool:
	return true


func home(carted: bool) -> Vector2:
	if carted:
		return player.position + Vector2((1.0 if player.facing.x >= 0.0 else -1.0) * 34.0, 30.0)
	return player.position - player.facing * 30.0 + Vector2(34.0, 26.0)
