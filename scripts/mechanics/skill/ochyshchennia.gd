extends "res://scripts/mechanics/skill_mechanic.gd"
## Очищення (Знахар): знімає всі стани, і на кілька секунд нові не чіпляються (погляд Вія теж не кам'янить).

var t := 0.0  # скільки ще стани не чіпляються


func cast() -> bool:
	p.statuses.clear()
	t = 2.0 + 1.0 * (rank() - 1)
	combat.fx.ring(p.global_position, Color(0.8, 0.95, 1.0), 20, 160, 4, 0.4)
	combat.spawn_fx("shield", p.global_position - Vector2(0, 10), 1.3, 0.0, Color(0.9, 1.0, 1.0))
	say("Очищення", Color(0.8, 0.95, 1.0))
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func blocks_status() -> bool:
	return t > 0.0


func card(r: int) -> Array:
	return [["Без станів", "%d с" % int(2 + (r - 1))]]
