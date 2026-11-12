extends "res://scripts/mechanics/skill_mechanic.gd"
## Бойовий клич (Козак): 8 с кожен удар сильніший, а козак бігає на 20% швидше.

var t := 0.0  # скільки ще діє
var bonus := 0.0  # надбавка до шкоди удару, частка


func order() -> int:
	return 10


func cast() -> bool:
	t = 8.0
	bonus = 0.15 + 0.05 * (rank() - 1)
	Audio.play("roar", 0.05, -2.0)
	say("Гей, козаки!", Color(1.0, 0.7, 0.3))
	combat.fx.ring(p.global_position, Color(1.0, 0.6, 0.25), 24, 260, 5, 0.4)
	combat.spawn_fx("cry", p.global_position + Vector2(0, -20), 1.8)
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func damage_bonus() -> float:
	return bonus if t > 0.0 else 0.0


func speed_mult() -> float:
	return 1.2 if t > 0.0 else 1.0


func on_revive() -> void:
	t = 0.0


func draw_aura(_side: float) -> void:
	if t > 0.0:
		p.draw_arc(Vector2(0, 16), 28.0, 0.0, TAU, 32, Color(1.0, 0.6, 0.25, 0.5), 3.0)


func card(r: int) -> Array:
	return [["Шкода", "+%d%%" % roundi((0.15 + 0.05 * (r - 1)) * 100)], ["Швидкість бігу", "+20%"], ["Тривалість", "8 с"]]
