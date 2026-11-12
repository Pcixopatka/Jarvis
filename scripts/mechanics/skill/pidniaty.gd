extends "res://scripts/mechanics/skill_mechanic.gd"
## Підняти побратима (Знахар): поранені побратими встають просто в бою з часткою здоров'я. Нема кого —
## не спрацьовує.


func cast() -> bool:
	return combat.revive_companions(0.4 + 0.15 * (rank() - 1)) > 0


func card(r: int) -> Array:
	return [["Здоров'я побратима", "%d%%" % roundi((0.4 + 0.15 * (r - 1)) * 100)]]
