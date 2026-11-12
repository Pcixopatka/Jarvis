extends "res://scripts/mechanics/skill_mechanic.gd"
## Вовча подоба (Характерник): на час характерник бігає на 40% швидше, б'є на 25% сильніше й лікується
## з кожного удару (8% завданої шкоди, у межах вампіризму).

var t := 0.0  # скільки ще діє


func order() -> int:
	return 70


func cast() -> bool:
	t = 10.0 + 2.0 * (rank() - 1)
	Audio.play("roar", 0.0, 0.0)
	say("Вовча подоба!", Color(0.8, 0.8, 0.85))
	combat.fx.burst(p.global_position, Color(0.5, 0.5, 0.5), 26, 220, 8, 0.6)
	combat.spawn_fx("wolf", p.global_position - Vector2(0, 10), 1.8, 0.0, Color.WHITE, 12.0)
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func speed_mult() -> float:
	return 1.4 if t > 0.0 else 1.0


func damage_dealt(dmg: float) -> float:
	if t > 0.0:
		dmg *= 1.25
	return dmg


func on_hit(e, _dmg: float, _crit: bool, hp_before: float) -> void:
	if t > 0.0:
		p._leech(maxf(0.0, hp_before - maxf(0.0, e.hp)) * 0.08)


func tint(c: Color) -> Color:
	return c * Color(0.75, 0.75, 0.8) if p.alive and t > 0.0 else c


## Вуха й сяйво очей (герой без спрайту).
func draw_head(head: Vector2, side: float, tint_c: Color) -> void:
	if t > 0.0:
		p.draw_colored_polygon(PackedVector2Array([head + Vector2(-9, -8), head + Vector2(-12, -22), head + Vector2(-3, -11)]), Color(0.5, 0.5, 0.52) * tint_c)
		p.draw_colored_polygon(PackedVector2Array([head + Vector2(9, -8), head + Vector2(12, -22), head + Vector2(3, -11)]), Color(0.5, 0.5, 0.52) * tint_c)
		p.draw_circle(head + Vector2(side * 4, -2), 2.6, Color(1.0, 0.85, 0.2))


func overlay() -> String:
	return "overlay_wolf" if t > 0.0 else ""


func card(r: int) -> Array:
	return [["Тривалість", "%d с" % int(10 + 2 * (r - 1))], ["Швидкість / шкода", "+40% / +25%"], ["Лікування з удару", "8%"]]
