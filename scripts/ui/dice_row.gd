extends Control
## Ряд гральних кісток: малює значення 1–6 цяточками. Порожній ряд тримає місце під один кубик.

const D := 56.0  # сторона кубика
const GAP := 10.0
const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}

var values: Array = []
var face := Color(0.95, 0.91, 0.8)
var pip := Color(0.15, 0.1, 0.08)


func setup(v: Array, face_col: Color = Color(0.95, 0.91, 0.8)):
	values = v
	face = face_col
	custom_minimum_size = Vector2(maxi(1, v.size()) * (D + GAP), D + 4.0)
	return self


func _draw() -> void:
	for i in values.size():
		var r := Rect2(i * (D + GAP), 2.0, D, D)
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.45))
		draw_rect(r, face)
		draw_rect(r, pip, false, 3.0)
		for p in PIPS.get(int(values[i]), []):
			draw_circle(r.position + Vector2(p.x, p.y) * D, D * 0.085, pip)
