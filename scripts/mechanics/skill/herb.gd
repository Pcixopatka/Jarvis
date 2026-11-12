extends "res://scripts/mechanics/skill_mechanic.gd"
## Цілюща трава (Волхв): 6 с лікує героя в часі, загін — на 30% одразу, і знімає заразу.

var t := 0.0  # скільки ще лікує
var rate := 0.0  # здоров'я за секунду


func order() -> int:
	return 80


func cast() -> bool:
	t = 6.0
	rate = p.max_hp * (0.2 + 0.06 * (rank() - 1)) * p.skill_power / 6.0
	for c in combat.companion_nodes:
		if is_instance_valid(c) and c.alive:
			c.heal(c.max_hp * 0.3)
	p.statuses.erase("plague")
	Audio.play("heal", 0.0)
	combat.fx.burst(p.global_position, Color(0.5, 1.0, 0.5), 16, 120, 5, 0.8, -60)
	combat.spawn_fx("heal", p.global_position, 1.4)
	return true


func tick(delta: float) -> void:
	if t > 0.0:
		t -= delta
		p.hp = minf(p.max_hp, p.hp + rate * Status.heal_mult(p) * delta)


func on_revive() -> void:
	t = 0.0


## Три листки кружляють довкола героя.
func draw_aura(_side: float) -> void:
	if t > 0.0:
		for i in 3:
			var a: float = p.walk_phase * 0.3 + t * 2.0 + i * TAU / 3.0
			p.draw_circle(Vector2(cos(a) * 22.0, -10 + sin(a) * 8.0), 2.5, Color(0.5, 1.0, 0.5, 0.8))


func card(r: int) -> Array:
	var sp: float = p.skill_power
	return [["Лікування", "%d%% здоров'я за 6 с" % roundi((0.2 + 0.06 * (r - 1)) * sp * 100)], ["Загін", "+30% одразу"]]
