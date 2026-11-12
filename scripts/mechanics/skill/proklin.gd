extends "res://scripts/mechanics/skill_mechanic.gd"
## Прокляття (Мольфар): на 8 с проклинає й ослаблює всіх у колі 150 довкола найближчого ворога (не далі
## 500). Без ворога поруч не спрацьовує.


func cast() -> bool:
	var e: Node2D = nearest(500.0)
	if e == null:
		return false
	for t in foes():
		if t.global_position.distance_to(e.global_position) <= 150.0:
			Status.apply(t, "curse", 8.0)
			Status.apply(t, "weak", 8.0)
	combat.fx.ring(e.global_position, Color(0.5, 0.2, 0.5), 20, 300, 5, 0.5)
	combat.spawn_fx("curse", e.global_position - Vector2(0, 20), 1.6, 0.0, Color.WHITE, 10.0)
	Audio.play("spell", 0.15, -1.0)
	return true


func card(_r: int) -> Array:
	return [["Шкода по проклятих", "+35%"], ["Радіус / час", "150 / 8 с"]]
