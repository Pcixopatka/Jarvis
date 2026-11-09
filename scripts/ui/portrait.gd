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
	if npc == "putinoid":
		skin = Color(0.78, 0.8, 0.76)  # мертвотно-бліда шкіра
		draw_circle(c, r, Color(0.12, 0.06, 0.08))
		draw_circle(c + Vector2(0, -10) * s, r * 0.9, Color(0.25, 0.05, 0.08))
	var cloth: Color = {"otaman": Color(0.75, 0.13, 0.12), "kobzar": Color(0.4, 0.3, 0.2), "znakharka": Color(0.95, 0.94, 0.88), "hero": Color(0.78, 0.14, 0.14), "putinoid": Color(0.18, 0.14, 0.2), "polkovnyk": Color(0.18, 0.3, 0.65), "litopysets": Color(0.12, 0.1, 0.1), "selianyn": Color(0.95, 0.94, 0.9),
		"petro": Color(0.55, 0.25, 0.2), "yaryna": Color(0.95, 0.92, 0.8), "oksana": Color(0.3, 0.38, 0.2)}.get(npc, Color.GRAY)
	# Плечі
	draw_colored_polygon(_pts(c, s, [Vector2(-46, 46), Vector2(46, 46), Vector2(54, 64), Vector2(-54, 64)]), cloth)
	if npc == "znakharka":
		for i in 7:
			draw_circle(c + Vector2(-36 + i * 12, 52) * s, 3.0 * s, Color(0.8, 0.12, 0.12))  # вишивка
	if npc == "otaman" or npc == "hero" or npc == "polkovnyk":
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
		"polkovnyk":
			_brows(c, s, Color(0.15, 0.1, 0.05), 3.5)
			_eyes(c, s, eye_y, false)
			_mustache(c, s, Color(0.15, 0.1, 0.05), 30.0)
			# Хутряна шапка з пером
			draw_rect(Rect2(c + Vector2(-30, -36) * s, Vector2(60, 18) * s), Color(0.3, 0.22, 0.15))
			draw_colored_polygon(_pts(c, s, [Vector2(-22, -36), Vector2(22, -36), Vector2(10, -50), Vector2(-14, -48)]), Color(0.18, 0.3, 0.65))
			draw_line(c + Vector2(18, -38) * s, c + Vector2(34, -62) * s, Color(0.95, 0.95, 0.9), 4.0 * s)
		"litopysets":
			# Чернечий клобук, довга темна борода, книга
			draw_colored_polygon(_pts(c, s, [Vector2(-32, 6), Vector2(-30, -30), Vector2(0, -44), Vector2(30, -30), Vector2(32, 6), Vector2(24, -16), Vector2(0, -26), Vector2(-24, -16)]), Color(0.1, 0.08, 0.08))
			_brows(c, s, Color(0.3, 0.25, 0.2), 2.5)
			_eyes(c, s, eye_y, false)
			draw_colored_polygon(_pts(c, s, [Vector2(-18, 10), Vector2(18, 10), Vector2(10, 52), Vector2(0, 58), Vector2(-10, 52)]), Color(0.3, 0.24, 0.18))
			draw_rect(Rect2(c + Vector2(30, 30) * s, Vector2(26, 32) * s), Color(0.5, 0.15, 0.1))
			draw_rect(Rect2(c + Vector2(33, 33) * s, Vector2(20, 26) * s), Color(0.9, 0.85, 0.7))
		"selianyn":
			# Молодий хлопець: чуприна, без вусів, вишита сорочка
			draw_colored_polygon(_pts(c, s, [Vector2(-30, -2), Vector2(-26, -26), Vector2(0, -36), Vector2(26, -26), Vector2(30, -2), Vector2(14, -18), Vector2(-8, -20)]), Color(0.45, 0.3, 0.15))
			_brows(c, s, Color(0.4, 0.25, 0.12), 2.5)
			_eyes(c, s, eye_y, false)
			draw_line(c + Vector2(-6, 14) * s, c + Vector2(6, 14) * s, Color(0.6, 0.35, 0.3), 2.0 * s)
			for i in 6:
				draw_circle(c + Vector2(-30 + i * 12, 52) * s, 3.0 * s, Color(0.8, 0.12, 0.12))
		"petro":
			# Молодий козак: русявий оселедець, короткі вуса, слід зарази на щоці
			_chub(c, s, Color(0.75, 0.6, 0.35))
			_brows(c, s, Color(0.6, 0.45, 0.25), 2.5)
			_eyes(c, s, eye_y, false)
			_mustache(c, s, Color(0.7, 0.55, 0.3), 12.0)
			draw_line(c + Vector2(14, 2) * s, c + Vector2(22, 14) * s, Color(0.3, 0.35, 0.25), 2.5 * s)
			draw_line(c + Vector2(18, 4) * s, c + Vector2(24, 8) * s, Color(0.3, 0.35, 0.25), 2.0 * s)
		"yaryna":
			# Дівчина з косами й вінком
			draw_colored_polygon(_pts(c, s, [Vector2(-30, 0), Vector2(-28, -24), Vector2(0, -34), Vector2(28, -24), Vector2(30, 0), Vector2(18, -18), Vector2(-18, -18)]), Color(0.55, 0.35, 0.15))
			draw_line(c + Vector2(-28, 0) * s, c + Vector2(-34, 50) * s, Color(0.55, 0.35, 0.15), 8.0 * s)
			draw_line(c + Vector2(28, 0) * s, c + Vector2(34, 50) * s, Color(0.55, 0.35, 0.15), 8.0 * s)
			_eyes(c, s, eye_y, false)
			draw_line(c + Vector2(-6, 14) * s, c + Vector2(6, 14) * s, Color(0.8, 0.3, 0.3), 2.5 * s)
			var flowers := [Color(0.9, 0.15, 0.15), Color(0.2, 0.4, 0.9), Color(1.0, 0.85, 0.2)]
			for i in 7:
				draw_circle(c + Vector2(-27 + i * 9, -30 + absf(i - 3) * 2.5) * s, 4.5 * s, flowers[i % 3])
		"oksana":
			# Мисливиця: зелений каптур, лук за плечем
			draw_line(c + Vector2(-50, 60) * s, c + Vector2(-20, -40) * s, Color(0.45, 0.28, 0.12), 4.0 * s)
			draw_colored_polygon(_pts(c, s, [Vector2(-36, 20), Vector2(-32, -26), Vector2(0, -42), Vector2(32, -26), Vector2(36, 20), Vector2(24, -12), Vector2(0, -22), Vector2(-24, -12)]), Color(0.28, 0.36, 0.18))
			_brows(c, s, Color(0.3, 0.2, 0.1), 2.5)
			_eyes(c, s, eye_y, false)
			draw_line(c + Vector2(-6, 14) * s, c + Vector2(6, 14) * s, Color(0.65, 0.35, 0.3), 2.0 * s)
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
		"putinoid":
			# Дрібні червоні очі, тонкі губи, рідке волосся, шапка Мономаха
			for x in [-10.0, 10.0]:
				draw_circle(c + Vector2(x, eye_y) * s, 3.2 * s, Color(0.9, 0.05, 0.05))
				draw_circle(c + Vector2(x, eye_y) * s, 6.0 * s, Color(1.0, 0.1, 0.1, 0.2))
			draw_line(c + Vector2(-17, -12) * s, c + Vector2(-5, -9) * s, Color(0.6, 0.6, 0.55), 2.0 * s)
			draw_line(c + Vector2(5, -9) * s, c + Vector2(17, -12) * s, Color(0.6, 0.6, 0.55), 2.0 * s)
			draw_line(c + Vector2(-9, 14) * s, c + Vector2(9, 14) * s, Color(0.45, 0.3, 0.3), 2.0 * s)
			draw_line(c + Vector2(-14, 20) * s, c + Vector2(-6, 24) * s, Color(0.6, 0.62, 0.58), 1.5 * s)  # зморшки
			draw_line(c + Vector2(14, 20) * s, c + Vector2(6, 24) * s, Color(0.6, 0.62, 0.58), 1.5 * s)
			draw_colored_polygon(_pts(c, s, [Vector2(-30, -16), Vector2(30, -16), Vector2(24, -38), Vector2(0, -50), Vector2(-24, -38)]), Color(0.85, 0.65, 0.2))
			draw_rect(Rect2(c + Vector2(-32, -20) * s, Vector2(64, 9) * s), Color(0.35, 0.25, 0.2))  # хутряна облямівка
			draw_line(c + Vector2(0, -50) * s, c + Vector2(0, -64) * s, Color(0.85, 0.65, 0.2), 3.0 * s)
			draw_line(c + Vector2(-6, -58) * s, c + Vector2(6, -58) * s, Color(0.85, 0.65, 0.2), 3.0 * s)
			for i in 3:
				draw_circle(c + Vector2(-16 + i * 16, -28) * s, 3.0 * s, Color(0.75, 0.05, 0.1))
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
