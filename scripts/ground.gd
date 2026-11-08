extends Node2D
## Степ: трава, квіти, соняшники, каміння і частокіл навколо.

var arena := Rect2()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1648  # стабільна «карта»
	draw_rect(arena.grow(400), Color(0.12, 0.16, 0.1))
	draw_rect(arena, Color(0.36, 0.55, 0.24))
	# Плями різної трави
	for i in 70:
		var p := _rand_point(rng)
		var r := rng.randf_range(60, 180)
		var c := Color(0.32, 0.5, 0.2) if rng.randf() < 0.5 else Color(0.42, 0.6, 0.27)
		draw_circle(p, r, Color(c, 0.45))
	# Стежка
	var path := PackedVector2Array()
	for i in 30:
		var t := i / 29.0
		path.append(Vector2(lerpf(arena.position.x, arena.end.x, t), sin(t * 7.0) * 220.0))
	draw_polyline(path, Color(0.55, 0.47, 0.3, 0.6), 46.0, true)
	# Трава
	for i in 900:
		var p := _rand_point(rng)
		var g := Color(0.25, 0.42, 0.15) if rng.randf() < 0.6 else Color(0.5, 0.68, 0.3)
		draw_line(p, p + Vector2(-3, -9), g, 2.0)
		draw_line(p, p + Vector2(3, -8), g, 2.0)
	# Польові квіти
	for i in 260:
		var p := _rand_point(rng)
		var cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.9, 0.3), Color(0.55, 0.6, 1.0), Color(1, 1, 1)]
		draw_circle(p, 3.0, cols[rng.randi() % cols.size()])
	# Каміння
	for i in 40:
		var p := _rand_point(rng)
		var r := rng.randf_range(8, 22)
		draw_circle(p + Vector2(0, 4), r, Color(0, 0, 0, 0.2))
		draw_circle(p, r, Color(0.55, 0.55, 0.52))
		draw_circle(p - Vector2(r, r) * 0.3, r * 0.4, Color(0.68, 0.68, 0.64))
	# Соняшники
	for i in 45:
		var p := _rand_point(rng)
		draw_line(p, p + Vector2(0, 26), Color(0.25, 0.45, 0.15), 4.0)
		for k in 10:
			draw_circle(p + Vector2.from_angle(k * TAU / 10.0) * 9.0, 5.0, Color(1.0, 0.8, 0.1))
		draw_circle(p, 7.0, Color(0.35, 0.2, 0.08))
	# Частокіл
	var step := 28.0
	var x := arena.position.x
	while x <= arena.end.x:
		_stake(Vector2(x, arena.position.y))
		_stake(Vector2(x, arena.end.y))
		x += step
	var y := arena.position.y
	while y <= arena.end.y:
		_stake(Vector2(arena.position.x, y))
		_stake(Vector2(arena.end.x, y))
		y += step


func _rand_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))


func _stake(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-10, -40), Vector2(20, 48)), Color(0.42, 0.27, 0.13))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -40), p + Vector2(10, -40), p + Vector2(0, -54)]), Color(0.5, 0.33, 0.16))
	draw_line(p + Vector2(-4, -36), p + Vector2(-4, 4), Color(0.32, 0.2, 0.1), 2.0)
