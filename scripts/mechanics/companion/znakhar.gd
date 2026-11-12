extends "res://scripts/mechanics/companion_mechanic.gd"
## Знахарка: тримається на відстані, б'є слабко, а раз на 4 с лікує героя й увесь загін зіллям
## (скільки — stats.heal, росте з рівнем, див. Party.stats).

var heal_cd := 2.0  # с до наступного зілля (перше — через 2 с бою)


func attack(target, dir: Vector2) -> void:
	target.take_damage(c.damage, dir * 60.0, false)


func tick(delta: float) -> void:
	heal_cd = maxf(0.0, heal_cd - delta)
	if heal_cd > 0.0:
		return
	heal_cd = 4.0
	var amount: float = c.heal_amount
	for a in combat.allies():
		if a == c:
			c.hp = minf(c.max_hp, c.hp + amount)
		elif a.hp < a.max_hp:
			a.heal(amount)
	combat.float_text(c.global_position + Vector2(0, -40), "Зілля!", Color(0.5, 1.0, 0.5))
