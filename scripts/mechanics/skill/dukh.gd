extends "res://scripts/mechanics/skill_mechanic.gd"
## Дух гір (Мольфар): 15 с вогник летить біля героя й раз на 0,8 с стріляє іскрою в найближчу нечисть
## (не далі 520).


func cast() -> bool:
	var z = combat.spawn_zone("spirit", p.global_position + Vector2(0, -60), 0.0, 15.0, p.damage * 0.8 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power)
	z.mech = self
	say("Духу гір, прийди!", Color(0.6, 0.9, 1.0))
	combat.spawn_fx("spirit", p.global_position + Vector2(0, -60), 1.6, 0.0, Color.WHITE, 10.0)
	return true


## Вогник кружляє над героєм і стріляє.
func zone_tick(z, delta: float) -> void:
	var hero = z.combat.player
	var target: Vector2 = hero.global_position + Vector2(cos(z._t * 2.0) * 50.0, -60.0 + sin(z._t * 3.0) * 10.0)
	z.global_position = z.global_position.lerp(target, minf(1.0, delta * 6.0))
	if z._tick <= 0.0:
		z._tick = 0.8
		var e = z.combat.nearest_enemy(z.global_position, 520.0)
		if e:
			z.combat.spawn_spark(z.global_position, (e.global_position - z.global_position).normalized(), z.damage, false)


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода вогника", dmg_text(d * 0.8 * (1.0 + 0.2 * (r - 1)) * sp)], ["Тривалість", "15 с (постріл кожні 0.8 с)"]]
