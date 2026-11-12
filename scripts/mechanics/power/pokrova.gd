extends "res://scripts/mechanics/power_mechanic.gd"
## Покрова: коли здоров'я падає нижче {threshold}, на {dur} с шкода по героєві менша на {ward}.
## Не частіше ніж раз на {cd} с.

var t := 0.0  # скільки ще діє
var cd := 0.0  # скільки ще до наступного разу


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)
	cd = maxf(0.0, cd - delta)
	if worn() and cd <= 0.0 and p.alive and p.hp > 0.0 and p.hp < p.max_hp * float(P["threshold"]):
		var pk0: Dictionary = P
		t = float(pk0["dur"])
		cd = float(pk0["cd"])
		combat.float_text(p.global_position + Vector2(0, -80), "Покрова", Color(1.0, 0.85, 0.3))
		combat.fx.ring(p.global_position, Color(1.0, 0.85, 0.3), 24, 90, 5, 0.5)


func damage_taken(amount: float) -> float:
	if t > 0.0:
		amount *= 1.0 - float(P.get("ward", 0.0))
	return amount
