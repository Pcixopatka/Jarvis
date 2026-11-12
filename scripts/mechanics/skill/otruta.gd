extends "res://scripts/mechanics/skill_mechanic.gd"
## Отруйне зілля (Знахар): отруйна хмара на найближчому ворогові (коло 110, 5 с) — раз на пів секунди
## накладає заразу на всіх усередині. Без ворога поруч не спрацьовує.


func cast() -> bool:
	var e: Node2D = nearest(450.0)
	if e == null:
		return false
	var z = combat.spawn_zone("otruta", e.global_position, 110.0, 5.0, p.damage * 0.5 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power)
	z.mech = self
	combat.spawn_fx("poison", e.global_position, 2.0, 0.0, Color.WHITE, 10.0)
	Audio.play("swing", 0.1, -6.0)
	return true


## Хмара: раз на 0,5 с зараза всім усередині (z.damage — за секунду).
func zone_tick(z, _delta: float) -> void:
	if z._tick > 0.0:
		return
	z._tick = 0.5
	for e in z.combat.enemies_now():
		if not in_zone(z, e):
			continue
		Status.apply(e, "plague", 2.0, z.damage)


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Зараза", "%s/с" % dmg_text(d * 0.5 * (1.0 + 0.2 * (r - 1)) * sp)], ["Радіус / час", "110 / 5 с"]]
