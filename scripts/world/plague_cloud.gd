extends Node2D
## Хмара зарази, що лишається після загиблого зараженого: кілька секунд ранить усіх поруч.

var combat
var radius := 75.0
var life := 3.0
var dps := 5.0
var status := "plague"  # який стан накладає: зараза (звичайна хмара) чи, скажімо, слабкість (відьмине зілля)
var tint := Color(0.35, 0.6, 0.12)
var _t := 0.0
var _tick := 0.0


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _t >= life:
		queue_free()
		return
	if _tick <= 0.0:
		_tick = 0.5
		for a in combat.allies():
			if status == "plague" and a.get("plague_immune") == true:
				continue
			if a.global_position.distance_to(global_position) < radius + a.radius:
				var resist = a.get("plague_resist") if status == "plague" else null
				a.take_damage(dps * 0.5 * (1.0 - (resist if resist != null else 0.0)), null)
				if a.has_method("add_status"):
					a.add_status(status, 2.0)  # у хмарі зарази рани гояться вдвічі гірше; відьмине зілля знесилює
	queue_redraw()


func _draw() -> void:
	var fade := clampf((life - _t) / 0.8, 0.0, 1.0) * clampf(_t / 0.3, 0.0, 1.0)
	for i in 6:
		var a := _t * 0.8 + i * TAU / 6.0
		var p := Vector2.from_angle(a) * radius * 0.45
		draw_circle(p, radius * 0.55, Color(tint, 0.2 * fade))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(tint.darkened(0.45), 0.28 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(tint.lightened(0.45), 0.6 * fade), 3.0)
