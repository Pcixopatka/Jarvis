extends Node2D
## Земля локації: степ, річка, ліс, болото, гори або печера. Малюється процедурно.

var arena := Rect2()
var biome := "steppe"
var seed_value := 1648
var crystals := []  # [позиція, колір] — у печері біля них ставиться світло

const BASE := {
	"steppe": Color(0.36, 0.55, 0.24), "river": Color(0.38, 0.56, 0.26), "forest": Color(0.2, 0.36, 0.17),
	"swamp": Color(0.28, 0.35, 0.21), "mountain": Color(0.42, 0.46, 0.38), "cave": Color(0.2, 0.17, 0.15),
}


func setup(rect: Rect2, b: String, s: int) -> void:
	arena = rect
	biome = b
	seed_value = s
	crystals.clear()
	if biome == "cave":
		var rng := RandomNumberGenerator.new()
		rng.seed = s + 99
		for i in 7:
			var p := Vector2(rng.randf_range(arena.position.x + 60, arena.end.x - 60), rng.randf_range(arena.position.y + 60, arena.end.y - 60))
			crystals.append([p, Color(0.4, 0.8, 1.0) if rng.randf() < 0.5 else Color(0.75, 0.45, 1.0)])
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base: Color = BASE.get(biome, BASE["steppe"])
	var outside := Color(0.1, 0.08, 0.07) if biome == "cave" else Color(0.12, 0.16, 0.1)
	draw_rect(arena.grow(600), outside)
	draw_rect(arena, base)
	var area := arena.get_area() / 7840000.0  # відносно поля 2800×2800

	# Плями відтінків
	for i in int(70 * area) + 10:
		var p := _pt(rng)
		var c := base.darkened(0.12) if rng.randf() < 0.5 else base.lightened(0.1)
		draw_circle(p, rng.randf_range(60, 180), Color(c, 0.45))

	match biome:
		"steppe":
			_path(rng, Color(0.55, 0.47, 0.3, 0.6))
			_grass(rng, int(900 * area), base)
			_flowers(rng, int(260 * area))
			_rocks(rng, int(40 * area))
			_sunflowers(rng, int(45 * area))
		"river":
			_grass(rng, int(700 * area), base)
			_flowers(rng, int(150 * area))
			_river(rng)
			_rocks(rng, int(30 * area))
		"forest":
			_grass(rng, int(500 * area), base)
			_mushrooms(rng, int(80 * area))
			_trees(rng, int(170 * area), Color(0.12, 0.3, 0.12))
		"swamp":
			_pools(rng, int(45 * area))
			_reeds(rng, int(400 * area))
			_trees(rng, int(40 * area), Color(0.22, 0.3, 0.15))
		"mountain":
			_snow(rng, int(30 * area))
			_rocks(rng, int(140 * area))
			_pines(rng, int(90 * area))
		"cave":
			_cave_floor(rng, int(220 * area))
			_crystals()
	if biome == "cave" or biome == "mountain":
		_rock_wall()
	else:
		_fence()


func _pt(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))


func _path(rng: RandomNumberGenerator, col: Color) -> void:
	var path := PackedVector2Array()
	var off := rng.randf_range(-300, 300)
	for i in 30:
		var t := i / 29.0
		path.append(Vector2(lerpf(arena.position.x, arena.end.x, t), off + sin(t * 7.0) * 220.0))
	draw_polyline(path, col, 46.0, true)


func _grass(rng: RandomNumberGenerator, n: int, base: Color) -> void:
	for i in n:
		var p := _pt(rng)
		var g := base.darkened(0.3) if rng.randf() < 0.6 else base.lightened(0.2)
		draw_line(p, p + Vector2(-3, -9), g, 2.0)
		draw_line(p, p + Vector2(3, -8), g, 2.0)


func _flowers(rng: RandomNumberGenerator, n: int) -> void:
	var cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.9, 0.3), Color(0.55, 0.6, 1.0), Color(1, 1, 1)]
	for i in n:
		draw_circle(_pt(rng), 3.0, cols[rng.randi() % cols.size()])


func _rocks(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		var r := rng.randf_range(8, 26)
		draw_circle(p + Vector2(0, 4), r, Color(0, 0, 0, 0.2))
		draw_circle(p, r, Color(0.55, 0.55, 0.52))
		draw_circle(p - Vector2(r, r) * 0.3, r * 0.4, Color(0.68, 0.68, 0.64))


func _sunflowers(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		draw_line(p, p + Vector2(0, 26), Color(0.25, 0.45, 0.15), 4.0)
		for k in 10:
			draw_circle(p + Vector2.from_angle(k * TAU / 10.0) * 9.0, 5.0, Color(1.0, 0.8, 0.1))
		draw_circle(p, 7.0, Color(0.35, 0.2, 0.08))


func _river(rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := i / 39.0
		pts.append(Vector2(sin(t * 5.0) * 260.0 + 200.0, lerpf(arena.position.y - 50, arena.end.y + 50, t)))
	draw_polyline(pts, Color(0.75, 0.68, 0.45), 300.0, true)  # пісок
	draw_polyline(pts, Color(0.18, 0.4, 0.62), 230.0, true)
	draw_polyline(pts, Color(0.25, 0.5, 0.72), 140.0, true)
	for i in 120:
		var p: Vector2 = pts[rng.randi() % pts.size()] + Vector2(rng.randf_range(-90, 90), rng.randf_range(-30, 30))
		draw_line(p, p + Vector2(rng.randf_range(15, 40), 0), Color(0.75, 0.88, 1.0, 0.5), 3.0)
	# Пороги — каміння в річці
	for i in 25:
		var p: Vector2 = pts[rng.randi() % pts.size()] + Vector2(rng.randf_range(-80, 80), 0)
		var r := rng.randf_range(10, 22)
		draw_circle(p, r + 5, Color(0.9, 0.95, 1.0, 0.5))
		draw_circle(p, r, Color(0.45, 0.45, 0.43))


func _trees(rng: RandomNumberGenerator, n: int, leaf: Color) -> void:
	for i in n:
		var p := _pt(rng)
		var s := rng.randf_range(0.8, 1.4)
		draw_circle(p + Vector2(0, 20 * s), 26 * s, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(p + Vector2(-5, 0) * s, Vector2(10, 22) * s), Color(0.35, 0.22, 0.12))
		draw_circle(p + Vector2(0, -10) * s, 28 * s, leaf.darkened(0.2))
		draw_circle(p + Vector2(-10, -20) * s, 20 * s, leaf)
		draw_circle(p + Vector2(10, -24) * s, 18 * s, leaf.lightened(0.12))


func _pines(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		var s := rng.randf_range(0.8, 1.3)
		draw_rect(Rect2(p + Vector2(-3, 0) * s, Vector2(6, 14) * s), Color(0.3, 0.2, 0.1))
		for k in 3:
			var y := -k * 14.0 * s
			var w := (24.0 - k * 6.0) * s
			draw_colored_polygon(PackedVector2Array([p + Vector2(-w, y), p + Vector2(w, y), p + Vector2(0, y - 24 * s)]), Color(0.1, 0.28, 0.17).lightened(k * 0.05))


func _mushrooms(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, 7)), Color(0.95, 0.9, 0.8))
		draw_circle(p, 6.0, Color(0.85, 0.15, 0.1))
		draw_circle(p + Vector2(-2, -2), 1.5, Color.WHITE)


func _pools(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		var r := rng.randf_range(50, 140)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, r + 10, Color(0.2, 0.24, 0.14))
		draw_circle(Vector2.ZERO, r, Color(0.15, 0.27, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k in 3:
			draw_circle(p + Vector2(rng.randf_range(-r, r) * 0.6, rng.randf_range(-r, r) * 0.3), 9.0, Color(0.3, 0.55, 0.25))


func _reeds(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		var h := rng.randf_range(14, 28)
		draw_line(p, p + Vector2(rng.randf_range(-4, 4), -h), Color(0.45, 0.5, 0.25), 2.0)
		if rng.randf() < 0.3:
			draw_line(p + Vector2(0, -h), p + Vector2(0, -h - 8), Color(0.4, 0.25, 0.12), 4.0)


func _snow(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		draw_circle(_pt(rng), rng.randf_range(40, 120), Color(0.92, 0.95, 1.0, 0.75))


func _cave_floor(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		var r := rng.randf_range(6, 22)
		draw_circle(p, r, Color(0.28, 0.24, 0.21) if rng.randf() < 0.5 else Color(0.15, 0.12, 0.1))
	# Сталагміти
	for i in n / 6:
		var p := _pt(rng)
		var h := rng.randf_range(20, 45)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0), p + Vector2(12, 0), p + Vector2(0, -h)]), Color(0.38, 0.32, 0.27))


func _crystals() -> void:
	for c in crystals:
		var p: Vector2 = c[0]
		var col: Color = c[1]
		draw_circle(p, 30.0, Color(col, 0.12))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(0, -22), p + Vector2(6, 0), p + Vector2(0, 6)]), col)


func _fence() -> void:
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


func _stake(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-10, -40), Vector2(20, 48)), Color(0.42, 0.27, 0.13))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -40), p + Vector2(10, -40), p + Vector2(0, -54)]), Color(0.5, 0.33, 0.16))
	draw_line(p + Vector2(-4, -36), p + Vector2(-4, 4), Color(0.32, 0.2, 0.1), 2.0)


func _rock_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var col := Color(0.3, 0.26, 0.23) if biome == "cave" else Color(0.38, 0.38, 0.36)
	var step := 40.0
	var edges := []
	var x := arena.position.x
	while x <= arena.end.x:
		edges.append(Vector2(x, arena.position.y))
		edges.append(Vector2(x, arena.end.y))
		x += step
	var y := arena.position.y
	while y <= arena.end.y:
		edges.append(Vector2(arena.position.x, y))
		edges.append(Vector2(arena.end.x, y))
		y += step
	for p in edges:
		var r := rng.randf_range(28, 48)
		draw_circle(p, r, col.darkened(0.2))
		draw_circle(p + Vector2(-r * 0.2, -r * 0.25), r * 0.7, col)
