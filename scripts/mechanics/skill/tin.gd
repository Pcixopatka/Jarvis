extends "res://scripts/mechanics/skill_mechanic.gd"
## Тінь (Пластун): 4 с нечисть пластуна не бачить, а перший удар із Тіні — гарантований крит і сильніший;
## той удар Тінь і знімає.

var t := 0.0  # скільки ще діє


func order() -> int:
	return 20


func cast() -> bool:
	t = 4.0
	combat.spawn_fx("smoke", p.global_position - Vector2(0, 10), 1.6)
	combat.fx.burst(p.global_position, Color(0.2, 0.2, 0.25), 20, 160, 7, 0.5)
	say("Тінь", Color(0.6, 0.6, 0.75))
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


## Удар із Тіні: гарантований крит і бонус, а Тінь спадає.
func on_roll(r: Array) -> void:
	if t > 0.0:
		r[1] = true
		r[0] *= 1.2 + 0.2 * rank()
		t = 0.0


func aggro() -> int:
	return -1 if t > 0.0 else 0


## Пластуна в Тіні ледь видно.
func tint(c: Color) -> Color:
	return Color(0.6, 0.6, 0.75, 0.4) if p.alive and t > 0.0 else c


func card(r: int) -> Array:
	return [["Удар із Тіні", "крит, +%d%%" % roundi((0.2 + 0.2 * r) * 100)], ["Тривалість", "4 с"]]
