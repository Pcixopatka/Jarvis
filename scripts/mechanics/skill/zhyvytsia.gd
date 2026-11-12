extends "res://scripts/mechanics/skill_mechanic.gd"
## Живиця (Знахар): лікує героя й увесь живий загін одразу (сила лікування героя, з «Травником» — більше).


func cast() -> bool:
	var pct := (0.3 + 0.05 * (rank() - 1)) * p.heal_power()
	p.heal(p.max_hp * pct)
	for c in combat.companion_nodes:
		if is_instance_valid(c) and c.alive:
			c.heal(c.max_hp * pct)
	combat.fx.ring(p.global_position, Color(0.5, 1.0, 0.55), 24, 260, 5, 0.5)
	combat.spawn_fx("heal", p.global_position, 1.8)
	for c in combat.companion_nodes:
		if is_instance_valid(c) and c.alive:
			combat.spawn_fx("heal", c.global_position, 1.2)
	Audio.play("heal", 0.0)
	return true


func card(r: int) -> Array:
	var sp: float = p.skill_power
	var hp: float = p.max_hp
	var hp_pct: float = (0.3 + 0.05 * (r - 1)) * sp * (1.0 + 0.12 * p.pk("travnyk"))
	return [["Лікування", "%d%% здоров'я (%d)" % [roundi(hp_pct * 100), int(hp * hp_pct)]], ["Кого", "тебе й увесь загін"]]
