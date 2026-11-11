extends Node2D
## Атмосферні частинки навколо камери: світлячки в лісі, туман на болоті, сніг у горах,
## пилок у степу, бризки біля порогів, порох у печерах.

var combat
var biome := "steppe"
var parts := []  # [позиція, швидкість, фаза, розмір]
var _t := 0.0

const COUNT := {"steppe": 40, "river": 35, "forest": 45, "swamp": 14, "mountain": 110, "cave": 40, "plague": 50, "village": 60, "snow": 90}


func setup(b: String) -> void:
	biome = b
	parts.clear()
	var view := _view()
	for i in COUNT.get(biome, 30):
		parts.append(_new_part(view, true))


func _view() -> Rect2:
	var vp := get_viewport_rect().size
	var c: Vector2 = combat.camera.get_screen_center_position()
	return Rect2(c - vp / 2.0, vp).grow(80)


func _new_part(view: Rect2, anywhere: bool) -> Array:
	var pos := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
	var vel := Vector2.ZERO
	var size := 3.0
	match biome:
		"mountain", "snow":
			vel = Vector2(randf_range(-30, 10), randf_range(60, 120))
			size = randf_range(2, 4)
			if not anywhere:
				pos.y = view.position.y
		"swamp":
			vel = Vector2(randf_range(8, 20), randf_range(-3, 3))
			size = randf_range(90, 180)
		"forest":
			vel = Vector2(randf_range(-15, 15), randf_range(-15, 15))
			size = randf_range(2, 3.5)
		"village":
			vel = Vector2(randf_range(10, 25), randf_range(-30, -12))
			size = randf_range(1.5, 3.0)
		"cave", "plague":
			vel = Vector2(randf_range(-6, 6), randf_range(-10, -2))
			size = randf_range(1.5, 2.5)
		_:
			vel = Vector2(randf_range(15, 35), randf_range(-8, 8))
			size = randf_range(1.5, 3)
	return [pos, vel, randf() * TAU, size]


func _process(delta: float) -> void:
	if not is_visible_in_tree() or parts.is_empty():
		return
	_t += delta
	var view := _view()
	for i in parts.size():
		var p: Array = parts[i]
		p[0] += p[1] * delta + Vector2(sin(_t + p[2]) * 8.0 * delta, 0)
		if not view.grow(200 if biome == "swamp" else 20).has_point(p[0]):
			parts[i] = _new_part(view, not biome in ["mountain", "snow"])
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var pos: Vector2 = p[0]
		var s: float = p[3]
		var flick := 0.5 + 0.5 * sin(_t * 3.0 + p[2])
		match biome:
			"forest":
				draw_circle(pos, s * 3.0, Color(1.0, 0.95, 0.4, 0.12 * flick))
				draw_circle(pos, s, Color(1.0, 1.0, 0.6, 0.8 * flick))
			"swamp":
				draw_circle(pos, s, Color(0.85, 0.9, 0.85, 0.06))
			"mountain", "snow":
				draw_circle(pos, s, Color(1, 1, 1, 0.85))
			"cave":
				draw_circle(pos, s, Color(1.0, 0.8, 0.5, 0.35 * flick))
			"village":
				# Попіл і жарини
				draw_circle(pos, s, Color(0.35, 0.35, 0.35, 0.6) if p[2] > PI else Color(1.0, 0.55, 0.15, 0.7 * flick))
			"plague":
				draw_circle(pos, s * 2.5, Color(0.45, 0.95, 0.2, 0.1 * flick))
				draw_circle(pos, s, Color(0.55, 1.0, 0.3, 0.5 * flick))
			"river":
				draw_circle(pos, s, Color(0.85, 0.95, 1.0, 0.35 * flick))
			_:
				draw_circle(pos, s, Color(1.0, 0.95, 0.7, 0.4 * flick))
