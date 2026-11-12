extends "res://scripts/mechanics/skill_mechanic.gd"
## Град (Мольфар): 3 с град у колі на найближчому ворогові — раз на 0,3 с б'є всіх усередині й холодить.
## «Хмара» (khmara) — ширше коло й сильніший град. Без ворога поруч не спрацьовує.


func cast() -> bool:
	var e: Node2D = nearest(550.0)
	if e == null:
		return false
	var k := 1.0 + 0.2 * p.pk("khmara")
	var z = combat.spawn_zone("grad", e.global_position, 140.0 * k, 3.0, p.damage * 0.45 * (1.0 + 0.2 * (rank() - 1)) * k * p.skill_power)
	z.mech = self
	for i in 3:
		combat.spawn_fx("hail", e.global_position + Vector2(randf_range(-80, 80), randf_range(-60, 40)), 2.0 * k, 0.0, Color.WHITE, 10.0)
	Audio.play("spell", 0.2, -2.0)
	return true


## Раз на 0,3 с удар і холод усім у колі.
func zone_tick(z, _delta: float) -> void:
	if z._tick > 0.0:
		return
	z._tick = 0.3
	var hero = z.combat.player
	for e in z.combat.enemies_now():
		if not in_zone(z, e):
			continue
		hero.hit(e, z.damage, Vector2.ZERO, false)
		if not e.dead:
			Status.apply(e, "chill", 1.5)
	for i in 4:
		z.combat.fx.burst(z.global_position + Vector2.from_angle(randf() * TAU) * randf() * z.radius, Color(0.85, 0.95, 1.0), 3, 120, 3, 0.25)


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	var k: float = 1.0 + 0.2 * p.pk("khmara")
	return [["Шкода удару", dmg_text(d * 0.45 * (1.0 + 0.2 * (r - 1)) * k * sp)], ["Радіус / час", "%d / 3 с (10 ударів)" % int(140.0 * k)]]
