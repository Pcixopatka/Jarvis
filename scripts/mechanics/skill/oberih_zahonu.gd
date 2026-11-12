extends "res://scripts/mechanics/skill_mechanic.gd"
## Оберіг загону (Знахар): 8 с шкода по героєві й по всьому загону менша.

var t := 0.0  # скільки ще діє
var mult := 1.0  # яка частка шкоди проходить


func order() -> int:
	return 60


func cast() -> bool:
	t = 8.0
	mult = 1.0 - (0.25 + 0.05 * (rank() - 1))
	combat.fx.ring(p.global_position, Color(0.5, 0.7, 1.0), 24, 320, 5, 0.5)
	combat.spawn_fx("shield", p.global_position - Vector2(0, 10), 2.2)
	say("Оберіг загону", Color(0.6, 0.8, 1.0))
	Audio.play("heal", 0.0, -3.0)
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func damage_taken(amount: float) -> float:
	if t > 0.0:
		amount *= mult
	return amount


func party_damage(amount: float) -> float:
	if t > 0.0:
		amount *= mult
	return amount


func card(r: int) -> Array:
	return [["Шкода по загону", "−%d%%" % roundi((0.25 + 0.05 * (r - 1)) * 100)], ["Тривалість", "8 с"]]
