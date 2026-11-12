extends "res://scripts/mechanics/skill_mechanic.gd"
## Туман (Мольфар): 6 с туман довкола героя (коло 230) — нечисть усередині повільна й слабка.


func cast() -> bool:
	var z = combat.spawn_zone("tuman", p.global_position, 230.0, 6.0, 0.0)
	z.mech = self
	combat.spawn_fx("smoke", p.global_position, 4.0, 0.0, Color(0.85, 0.88, 0.95), 8.0)
	return true


## Раз на пів секунди холод і слабкість усім у тумані.
func zone_tick(z, _delta: float) -> void:
	if z._tick > 0.0:
		return
	z._tick = 0.5
	for e in z.combat.enemies_now():
		if not in_zone(z, e):
			continue
		Status.apply(e, "chill", 1.0)
		Status.apply(e, "weak", 1.0)


func card(_r: int) -> Array:
	return [["Радіус / час", "230 / 6 с"], ["Вороги в тумані", "повільні й слабкі"]]
