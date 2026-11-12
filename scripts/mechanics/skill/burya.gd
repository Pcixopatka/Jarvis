extends "res://scripts/mechanics/skill_mechanic.gd"
## Буря (Перунів жрець): кілька секунд раз на пів секунди блискавка б'є випадкового ворога ближче за 450.

var t := 0.0  # скільки ще триває
var tick_t := 0.0  # скільки до наступної блискавки


func order() -> int:
	return 60


func cast() -> bool:
	t = 6.0 + 1.0 * (rank() - 1)
	tick_t = 0.0
	say("Буря!", Color(0.7, 0.8, 1.0))
	return true


func tick(delta: float) -> void:
	if t > 0.0:
		t -= delta
		tick_t -= delta
		if tick_t <= 0.0:
			tick_t = 0.5
			_strike()


func _strike() -> void:
	var near := foes().filter(func(e): return p.global_position.distance_to(e.global_position) <= 450.0)
	if near.is_empty():
		return
	var e = near[randi() % near.size()]
	var r := roll(1.3 * (1.0 + 0.15 * (rank() - 1)) * (1.0 + 0.1 * p.pk("grim")) * p.skill_power)
	hit(e, r[0], Vector2.ZERO, r[1])
	combat.spawn_bolt(PackedVector2Array([e.global_position + Vector2(randf_range(-40, 40), -420), e.global_position]))
	combat.spawn_fx("lightning", e.global_position - Vector2(0, 30), 1.4, 0.0, Color.WHITE, 20.0)
	Audio.play("lightning", 0.2, -8.0)


func cooldown(base: float) -> float:
	return base * (1.0 - 0.1 * p.pk("storm_soul"))


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода удару", dmg_text(d * 1.3 * (1.0 + 0.15 * (r - 1)) * (1.0 + 0.1 * p.pk("grim")) * sp)], ["Тривалість", "%d с" % int(6 + (r - 1))]]
