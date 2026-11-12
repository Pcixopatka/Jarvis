extends "res://scripts/mechanics/skill_mechanic.gd"
## Щит-оберіг (Волхв): 8 с щит поглинає шкоду, доки не вичерпається його запас.

var ward_hp := 0.0  # скільки шкоди ще поглине
var t := 0.0  # скільки ще діє


func order() -> int:
	return 70


func cast() -> bool:
	ward_hp = p.max_hp * (0.2 + 0.05 * (rank() - 1)) * p.skill_power
	t = 8.0
	Audio.play("heal", 0.0, -2.0)
	say("Щит-оберіг!", Color(0.6, 0.85, 1.0))
	combat.fx.ring(p.global_position, Color(0.5, 0.75, 1.0), 20, 90, 4, 0.4)
	combat.spawn_fx("shield", p.global_position - Vector2(0, 10), 1.5)
	return true


func tick(delta: float) -> void:
	if t > 0.0:
		t -= delta
		if t <= 0.0:
			ward_hp = 0.0


func absorb(amount: float) -> float:
	if ward_hp > 0.0:
		var absorbed := minf(ward_hp, amount)
		ward_hp -= absorbed
		amount -= absorbed
		combat.fx.ring(p.global_position, Color(0.5, 0.75, 1.0), 12, 70, 3, 0.2)
		if amount <= 0.0:
			say("Оберіг", Color(0.6, 0.85, 1.0))
			return -1.0
	return amount


func on_revive() -> void:
	ward_hp = 0.0


func draw_aura(_side: float) -> void:
	if ward_hp > 0.0:
		p.draw_circle(Vector2(0, -8), 36.0, Color(0.5, 0.75, 1.0, 0.12))
		p.draw_arc(Vector2(0, -8), 36.0, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.6), 2.5)


func card(r: int) -> Array:
	var sp: float = p.skill_power
	var hp: float = p.max_hp
	return [["Поглинає", "%d%% здоров'я (%d)" % [roundi((0.2 + 0.05 * (r - 1)) * sp * 100), int(hp * (0.2 + 0.05 * (r - 1)) * sp)]], ["Тривалість", "8 с"]]
