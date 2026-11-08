extends Node2D
## Візуальний ефект блискавки Перуна між точками (глобальні координати).

var points := PackedVector2Array()
var life := 0.3
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / life
	for i in points.size() - 1:
		var p0 := points[i]
		var p1 := points[i + 1]
		var zig := PackedVector2Array([p0])
		var segs := 7
		for k in range(1, segs):
			zig.append(p0.lerp(p1, float(k) / segs) + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
		zig.append(p1)
		draw_polyline(zig, Color(0.55, 0.75, 1.0, 0.5 * a), 10.0)
		draw_polyline(zig, Color(1, 1, 1, a), 3.0)
		draw_circle(p1, 14.0 * a, Color(0.8, 0.9, 1.0, 0.6 * a))
