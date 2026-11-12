extends "res://scripts/mechanics/skill_mechanic.gd"
## Перша допомога (Селянин): перев'язка травами — частина здоров'я одразу, кровотеча знімається.
## Лише пораненому.


func cast() -> bool:
	if p.hp >= p.max_hp:
		return false
	p.heal(p.max_hp * (0.15 + 0.05 * rank()))
	p.statuses.erase("bleed")
	combat.spawn_fx("heal", p.global_position, 1.1)
	return true


func card(r: int) -> Array:
	var hp: float = p.max_hp
	return [["Лікування", "%d%% здоров'я (%d)" % [roundi((0.15 + 0.05 * r) * 100), int(hp * (0.15 + 0.05 * r))]]]
