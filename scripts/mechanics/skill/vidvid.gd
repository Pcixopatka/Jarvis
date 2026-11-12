extends "res://scripts/mechanics/skill_mechanic.gd"
## Відвід очей (Характерник): уся нечисть ближче за 300 ціпеніє (боси — ні) і слабне. Нема нікого поруч —
## не спрацьовує.


func cast() -> bool:
	var dur := 2.0 + 0.3 * (rank() - 1)
	var n := 0
	for e in foes():
		if p.global_position.distance_to(e.global_position) <= 300.0 + e.radius:
			Status.apply(e, "weak", dur + 2.0)
			if not e.is_boss:
				e.stun = maxf(e.stun, dur)
			n += 1
	if n == 0:
		return false
	Audio.play("spell", 0.1)
	combat.fx.ring(p.global_position, Color(0.6, 0.4, 0.8), 28, 600, 5, 0.5)
	combat.spawn_fx("smoke", p.global_position - Vector2(0, 10), 2.4, 0.0, Color(0.8, 0.6, 1.0))
	return true


func card(r: int) -> Array:
	return [["Заціпеніння", "%.1f с" % (2.0 + 0.3 * (r - 1))], ["Радіус", "300"]]
