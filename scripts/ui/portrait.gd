extends Control
## Портрет персонажа, намальований кодом (до появи справжнього арту).

var npc := "otaman"


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	var s := r / 80.0
	var skin := Color(0.95, 0.78, 0.62)
	draw_circle(c, r, Color(0.22, 0.17, 0.12))
	draw_circle(c + Vector2(0, -10) * s, r * 0.9, Color(0.3, 0.24, 0.16))
	var cloth: Color = {"otaman": Color(0.75, 0.13, 0.12), "kobzar": Color(0.4, 0.3, 0.2), "znakharka": Color(0.95, 0.94, 0.88), "hero": Color(0.78, 0.14, 0.14)}.get(npc, Color.GRAY)
	# Плечі
	draw_colored_polygon(_pts(c, s, [Vector2(-46, 46), Vector2(46, 46), Vector2(54, 64), Vector2(-54, 64)]), cloth)
	if npc == "znakharka":
		for i in 7:
			draw_circle(c + Vector2(-36 + i * 12, 52) * s, 3.0 * s, Color(0.8, 0.12, 0.12))  # вишивка
	if npc == "otaman" or npc == "hero":
		draw_line(c + Vector2(-46, 56) * s, c + Vector2(46, 56) * s, Color(0.95, 0.75, 0.2), 5.0 * s)  # пояс
	# Шия й голова
	draw_rect(Rect2(c + Vector2(-9, 26) * s, Vector2(18, 22) * s), skin.darkened(0.08))
	draw_circle(c + Vector2(0, 0) * s, 30.0 * s, skin)
	var eye_y := -4.0
	match npc:
		"otaman":
			_chub(c, s, Color(0.75, 0.75, 0.75))
			_brows(c, s, Color(0.6, 0.6, 0.6), 3.5)
			_eyes(c, s, eye_y, false)
			_mustache(c, s, Color(0.78, 0.78, 0.78), 34.0)
			draw_line(c + Vector2(-22, -12) * s, c + Vector2(-14, 4) * s, Color(0.7, 0.4, 0.35), 2.0 * s)  # шрам
		"hero":
			_chub(c, s, Color(0.22, 0.14, 0.08))
			_brows(c, s, Color(0.25, 0.15, 0.08), 2.5)
			_eyes(c, s, eye_y, false)
			_mustache(c, s, Color(0.3, 0.18, 0.08), 24.0)
		"kobzar":
			draw_circle(c + Vector2(0, -16) * s, 24.0 * s, Color(0.92, 0.92, 0.9))  # сиве волосся
			draw_circle(c + Vector2(0, -2) * s, 26.0 * s, skin)
			_brows(c, s, Color(0.9, 0.9, 0.88), 3.0)
			_eyes(c, s, eye_y, true)  # сліпий — очі заплющені
			draw_colored_polygon(_pts(c, s, [Vector2(-20, 8), Vector2(20, 8), Vector2(12, 46), Vector2(0, 54), Vector2(-12, 46)]), Color(0.93, 0.93, 0.9))  # борода
			# Бандура
			draw_set_transform(c + Vector2(-50, 40) * s, -0.5, Vector2(1.0, 1.4))
			draw_circle(Vector2.ZERO, 18.0 * s, Color(0.6, 0.38, 0.18))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_line(c + Vector2(-50, 40) * s, c + Vector2(-26, -10) * s, Color(0.45, 0.28, 0.12), 6.0 * s)
		"znakharka":
			_eyes(c, s, eye_y, false)
			draw_line(c + Vector2(-8, 14) * s, c + Vector2(8, 14) * s, Color(0.6, 0.3, 0.3), 2.0 * s)
			# Хустка
			draw_colored_polygon(_pts(c, s, [Vector2(-34, 4), Vector2(-30, -26), Vector2(0, -38), Vector2(30, -26), Vector2(34, 4), Vector2(26, -14), Vector2(0, -24), Vector2(-26, -14)]), Color(0.75, 0.1, 0.12))
			draw_colored_polygon(_pts(c, s, [Vector2(-34, 4), Vector2(-26, -14), Vector2(-14, 30), Vector2(-28, 34)]), Color(0.75, 0.1, 0.12))
			draw_colored_polygon(_pts(c, s, [Vector2(34, 4), Vector2(26, -14), Vector2(14, 30), Vector2(28, 34)]), Color(0.75, 0.1, 0.12))
			for i in 5:
				draw_circle(c + Vector2(-20 + i * 10, -28) * s, 3.0 * s, Color(1.0, 0.85, 0.3))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.95, 0.75, 0.2), 4.0)


func _pts(c: Vector2, s: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(c + p * s)
	return out


func _chub(c: Vector2, s: float, col: Color) -> void:
	draw_polyline(_pts(c, s, [Vector2(0, -30), Vector2(-10, -42), Vector2(-26, -40), Vector2(-34, -26)]), col, 6.0 * s, true)


func _brows(c: Vector2, s: float, col: Color, w: float) -> void:
	draw_line(c + Vector2(-18, -12) * s, c + Vector2(-6, -10) * s, col, w * s)
	draw_line(c + Vector2(6, -10) * s, c + Vector2(18, -12) * s, col, w * s)


func _eyes(c: Vector2, s: float, y: float, closed: bool) -> void:
	for x in [-11.0, 11.0]:
		if closed:
			draw_line(c + Vector2(x - 5, y) * s, c + Vector2(x + 5, y) * s, Color(0.25, 0.18, 0.12), 2.0 * s)
		else:
			draw_circle(c + Vector2(x, y) * s, 3.0 * s, Color(0.15, 0.12, 0.1))


func _mustache(c: Vector2, s: float, col: Color, length: float) -> void:
	draw_polyline(_pts(c, s, [Vector2(0, 10), Vector2(-14, 12), Vector2(-24, 20), Vector2(-24, 10 + length)]), col, 5.0 * s, true)
	draw_polyline(_pts(c, s, [Vector2(0, 10), Vector2(14, 12), Vector2(24, 20), Vector2(24, 10 + length)]), col, 5.0 * s, true)
