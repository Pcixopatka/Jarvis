extends "res://scripts/mechanics/skill_mechanic.gd"
## Козацька стіна (Запорожець): 6 с уся нечисть ближче за 520 б'є лише запорожця, а шкода по ньому менша.

var t := 0.0  # скільки ще діє


func order() -> int:
	return 20


func cast() -> bool:
	t = 6.0
	Audio.play("roar", 0.05, -3.0)
	say("Козацька стіна!", Color(0.9, 0.8, 0.5))
	combat.fx.ring(p.global_position, Color(0.85, 0.75, 0.5), 24, 420, 5, 0.4)
	combat.spawn_fx("shockwave", p.global_position + Vector2(0, 10), 2.4, 0.0, Color(1.0, 0.9, 0.6))
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func damage_taken(amount: float) -> float:
	if t > 0.0:
		amount *= 1.0 - (0.4 + 0.05 * (rank() - 1))
	return amount


func aggro() -> int:
	return 1 if t > 0.0 else 0


func draw_aura(_side: float) -> void:
	if t > 0.0:
		p.draw_arc(Vector2(0, -6), 44.0, 0.0, TAU, 40, Color(0.95, 0.8, 0.45, 0.7), 4.0)


func card(r: int) -> Array:
	return [["Шкода по тобі", "−%d%%" % roundi((0.4 + 0.05 * (r - 1)) * 100)], ["Тривалість", "6 с"]]
