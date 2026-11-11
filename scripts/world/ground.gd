extends Node2D
## Земля локації: степ, річка, ліс, болото, гори або печера. Малюється процедурно.

const Tiles := preload("res://scripts/world/tiles.gd")
const PropScript := preload("res://scripts/world/prop.gd")

var arena := Rect2()
var biome := "steppe"
var seed_value := 1648
var crystals := []  # [позиція, колір] — у печері біля них ставиться світло
var props_parent: Node2D = null  # шар сутностей: сюди ставляться дерева й камені (сортування за y)
var props := []
## Біоми, що малюються тайлами (решта — поки що процедурно)
const TILED := ["forest", "steppe", "village", "cave", "plague", "river", "swamp", "mountain", "maidan", "sand", "snow"]

const BASE := {
	"steppe": Color(0.36, 0.55, 0.24), "river": Color(0.38, 0.56, 0.26), "forest": Color(0.2, 0.36, 0.17),
	"swamp": Color(0.28, 0.35, 0.21), "mountain": Color(0.42, 0.46, 0.38), "cave": Color(0.2, 0.17, 0.15),
	"plague": Color(0.15, 0.17, 0.11), "village": Color(0.4, 0.5, 0.25), "sand": Color(0.8, 0.7, 0.45),
	"snow": Color(0.86, 0.9, 0.95),
}


func setup(rect: Rect2, b: String, s: int) -> void:
	arena = rect
	biome = b
	seed_value = s
	crystals.clear()
	if biome == "cave" or biome == "plague":
		var rng := RandomNumberGenerator.new()
		rng.seed = s + 99
		for i in 7:
			var p := Vector2(rng.randf_range(arena.position.x + 60, arena.end.x - 60), rng.randf_range(arena.position.y + 60, arena.end.y - 60))
			var col := Color(0.4, 0.8, 1.0) if rng.randf() < 0.5 else Color(0.75, 0.45, 1.0)
			if biome == "plague":
				col = Color(0.45, 0.95, 0.2)
			crystals.append([p, col])
	_spawn_props()
	queue_redraw()


func tiled() -> bool:
	return biome in TILED and props_parent != null


func _prop(k: String, pos: Vector2) -> void:
	var pr = PropScript.new()
	pr.setup(k, pos)
	props_parent.add_child(pr)
	props.append(pr)


## Дерева, камені, хати — окремими вузлами в шарі сутностей (щоб герой ходив і перед ними, і за ними).
func _spawn_props() -> void:
	for pr in props:
		if is_instance_valid(pr):
			pr.queue_free()
	props.clear()
	if not tiled():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var area := arena.get_area() / 7840000.0
	match biome:
		"forest":
			_scatter(rng, "tree", int(110 * area) + 8, 230.0, 70.0)
			_scatter(rng, "pine", int(50 * area), 230.0, 60.0)
			_scatter(rng, "bush", int(40 * area), 180.0, 40.0)
			_scatter(rng, "stump", int(14 * area), 180.0, 40.0)
			_scatter(rng, "log", int(8 * area), 200.0, 60.0)
			_scatter(rng, "rock", int(10 * area), 200.0, 50.0)
		"steppe":
			_scatter(rng, "tree", int(18 * area), 260.0, 90.0)
			_scatter(rng, "bush", int(30 * area), 180.0, 40.0)
			_scatter(rng, "rock", int(25 * area), 200.0, 50.0)
		"village":
			_scatter(rng, "house", int(10 * area) + 3, 320.0, 170.0)
			_scatter(rng, "hut", int(8 * area) + 2, 280.0, 90.0)
			_scatter(rng, "tree", int(16 * area), 240.0, 80.0)
			_scatter(rng, "post", int(20 * area), 200.0, 40.0)
		"river":
			_scatter(rng, "tree", int(22 * area), 260.0, 90.0)
			_scatter(rng, "bush", int(30 * area), 180.0, 40.0)
			_scatter(rng, "rock", int(20 * area), 200.0, 50.0)
			_scatter(rng, "stump", int(8 * area), 180.0, 40.0)
		"swamp":
			_scatter(rng, "tree", int(45 * area), 240.0, 80.0)
			_scatter(rng, "log", int(14 * area), 200.0, 60.0)
			_scatter(rng, "stump", int(20 * area), 180.0, 40.0)
			_scatter(rng, "bush", int(25 * area), 180.0, 40.0)
		"snow":
			# Зимова тайга Московії: ялини в снігу, валуни, повалені стовбури
			_scatter(rng, "pine", int(70 * area) + 6, 230.0, 60.0)
			_scatter(rng, "pine2", int(40 * area), 230.0, 60.0)
			_scatter(rng, "boulder", int(18 * area), 180.0, 45.0)
			_scatter(rng, "log", int(8 * area), 200.0, 60.0)
			_scatter(rng, "stump", int(10 * area), 180.0, 40.0)
		"sand":
			# Піски й узбережжя: каміння, сухі кущі, де-не-де корч
			_scatter(rng, "boulder", int(26 * area), 200.0, 50.0)
			_scatter(rng, "boulder_big", int(8 * area) + 1, 240.0, 70.0)
			_scatter(rng, "pebbles", int(44 * area), 120.0, 40.0)
			_scatter(rng, "bush", int(12 * area), 220.0, 50.0)
			_scatter(rng, "stump", int(6 * area), 200.0, 40.0)
		"mountain":
			_scatter(rng, "boulder_big", int(24 * area) + 2, 230.0, 70.0)
			_scatter(rng, "boulder", int(40 * area), 160.0, 40.0)
			_scatter(rng, "pine", int(60 * area), 230.0, 60.0)
			_scatter(rng, "pine2", int(30 * area), 230.0, 60.0)
			_scatter(rng, "pebbles", int(30 * area), 120.0, 40.0)
		"maidan":
			# Майдан Січі: огорожа зі стовпців довкола, за нею хати
			var px := arena.position.x
			while px <= arena.end.x:
				_prop("post", Vector2(px, arena.position.y + 4.0))
				_prop("post", Vector2(px, arena.end.y + 22.0))
				px += 48.0
			var py := arena.position.y + 48.0
			while py < arena.end.y:
				_prop("post", Vector2(arena.position.x - 6.0, py))
				_prop("post", Vector2(arena.end.x + 6.0, py))
				py += 48.0
			for hx in [-380.0, -40.0, 320.0]:
				_prop("house", Vector2(hx, arena.position.y - 70.0))
			for hy in [-200.0, 120.0]:
				_prop("hut", Vector2(arena.position.x - 130.0, hy))
				_prop("hut", Vector2(arena.end.x + 130.0, hy))
			for tx in [-560.0, 560.0]:
				for ty in [-330.0, -40.0, 300.0]:
					_prop("tree", Vector2(tx + rng.randf_range(-20, 20), ty + rng.randf_range(-20, 20)))
		"cave", "plague":
			_scatter(rng, "boulder_big", int(18 * area) + 2, 230.0, 70.0)
			_scatter(rng, "boulder", int(40 * area), 160.0, 40.0)
			_scatter(rng, "boulder2", int(30 * area), 160.0, 40.0)
			_scatter(rng, "pebbles", int(40 * area), 120.0, 40.0)
			if biome == "plague":
				_scatter(rng, "idol", int(6 * area) + 1, 260.0, 60.0)
	# Узлісся: щільний ряд дерев по краю арени (замість паркану)
	if biome in ["forest", "steppe", "village", "river", "swamp"]:
		var step := 58.0
		var x := arena.position.x
		while x < arena.end.x:
			_prop("tree", Vector2(x + rng.randf_range(-10, 10), arena.position.y + rng.randf_range(10, 40)))
			_prop("tree", Vector2(x + rng.randf_range(-10, 10), arena.end.y + rng.randf_range(20, 50)))
			x += step
		var y := arena.position.y
		while y < arena.end.y:
			_prop("tree", Vector2(arena.position.x + rng.randf_range(-10, 20), y + rng.randf_range(-10, 10)))
			_prop("tree", Vector2(arena.end.x + rng.randf_range(-10, 20), y + rng.randf_range(-10, 10)))
			y += step
	elif biome == "snow":
		# узлісся тайги: суцільна стіна ялин
		var step := 52.0
		var x := arena.position.x
		while x < arena.end.x:
			_prop("pine", Vector2(x + rng.randf_range(-10, 10), arena.position.y + rng.randf_range(10, 40)))
			_prop("pine2", Vector2(x + rng.randf_range(-10, 10), arena.end.y + rng.randf_range(20, 50)))
			x += step
		var y := arena.position.y
		while y < arena.end.y:
			_prop("pine", Vector2(arena.position.x + rng.randf_range(-10, 20), y + rng.randf_range(-10, 10)))
			_prop("pine2", Vector2(arena.end.x + rng.randf_range(-10, 20), y + rng.randf_range(-10, 10)))
			y += step
	elif biome in ["mountain", "sand"]:
		var step := 70.0
		var x := arena.position.x
		while x < arena.end.x:
			_prop("boulder_big", Vector2(x + rng.randf_range(-10, 10), arena.position.y + rng.randf_range(10, 40)))
			_prop("boulder_big", Vector2(x + rng.randf_range(-10, 10), arena.end.y + rng.randf_range(30, 50)))
			x += step
		var y := arena.position.y
		while y < arena.end.y:
			_prop("boulder_big", Vector2(arena.position.x + rng.randf_range(-10, 20), y + rng.randf_range(-10, 10)))
			_prop("boulder_big", Vector2(arena.end.x + rng.randf_range(-10, 20), y + rng.randf_range(-10, 10)))
			y += step


func _scatter(rng: RandomNumberGenerator, k: String, n: int, clear_center: float, min_gap: float) -> void:
	var placed := []
	for i in n * 3:
		if placed.size() >= n:
			break
		var p := Vector2(rng.randf_range(arena.position.x + 70, arena.end.x - 70), rng.randf_range(arena.position.y + 70, arena.end.y - 70))
		if p.length() < clear_center:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < min_gap:
				ok = false
				break
		if ok:
			placed.append(p)
			_prop(k, p)


func _draw() -> void:
	if tiled():
		_draw_tiles()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base: Color = BASE.get(biome, BASE["steppe"])
	var outside := Color(0.1, 0.08, 0.07) if biome in ["cave", "plague"] else Color(0.12, 0.16, 0.1)
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
		"village":
			_path(rng, Color(0.5, 0.42, 0.28, 0.7))
			_grass(rng, int(700 * area), base)
			_huts(rng, int(28 * area) + 6)
			_sunflowers(rng, int(20 * area))
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
		"plague":
			_cave_floor(rng, int(200 * area))
			_pools(rng, int(10 * area))
			_crystals()
	if biome in ["cave", "mountain", "plague"]:
		_rock_wall()
	else:
		_fence()


## Хати: білені стіни, солом'яна стріха; частина — спалені.
func _huts(rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var p := _pt(rng)
		if p.length() < 260.0:
			continue  # центр лишаємо вільним для бою
		var burnt := rng.randf() < 0.6
		var wall := Color(0.22, 0.2, 0.18) if burnt else Color(0.95, 0.93, 0.86)
		var roof := Color(0.12, 0.1, 0.08) if burnt else Color(0.75, 0.6, 0.3)
		draw_circle(p + Vector2(0, 26), 46.0, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(p + Vector2(-38, -10), Vector2(76, 40)), wall)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-48, -8), p + Vector2(0, -48), p + Vector2(48, -8)]), roof)
		draw_rect(Rect2(p + Vector2(-8, 6), Vector2(16, 24)), Color(0.3, 0.2, 0.12))
		draw_rect(Rect2(p + Vector2(16, 0), Vector2(14, 12)), Color(0.4, 0.55, 0.7) if not burnt else Color(0.1, 0.08, 0.06))
		if burnt:
			for k in 3:
				draw_circle(p + Vector2(rng.randf_range(-30, 30), -40 - k * 18), 14.0 - k * 3, Color(0.25, 0.25, 0.25, 0.35))
			draw_circle(p + Vector2(rng.randf_range(-20, 20), -12), 9.0, Color(1.0, 0.45, 0.1, 0.55))


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
	var col := Color(0.3, 0.26, 0.23) if biome in ["cave", "plague"] else Color(0.38, 0.38, 0.36)
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


# ======================= Тайли (нова графіка) =======================

func _draw_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cave := biome in ["cave", "plague"]
	var tex: Texture2D = Tiles.CAVE if cave else Tiles.OV
	var ts := float(Tiles.TILE)
	var outer := arena.grow(640)
	var c0 := floori(outer.position.x / ts)
	var r0 := floori(outer.position.y / ts)
	var c1 := ceili(outer.end.x / ts)
	var r1 := ceili(outer.end.y / ts)
	# Доріжка через поле
	var path_off := rng.randf_range(-300, 300)
	var dark := Color(0.45, 0.5, 0.45) if not cave else Color(1, 1, 1)
	var river_y := rng.randf_range(-200, 200)
	var ponds := []  # болото: озерця 3×3 клітинки
	if biome == "swamp":
		for i in int(34 * arena.get_area() / 7840000.0) + 6:
			ponds.append(Vector2(floori(rng.randf_range(arena.position.x + 120, arena.end.x - 200) / ts), floori(rng.randf_range(arena.position.y + 120, arena.end.y - 200) / ts)))
	var mountain := biome == "mountain"
	var swamp_tint := Color(0.7, 0.75, 0.6)
	for r in range(r0, r1):
		for c in range(c0, c1):
			var pos := Vector2(c * ts, r * ts)
			var inside := arena.has_point(pos + Vector2(ts / 2, ts / 2))
			var roll := rng.randf()
			if cave:
				if not inside:
					draw_rect(Rect2(pos, Vector2(ts, ts)), Color(0.06, 0.05, 0.05))
					continue
				var fl: Array = Tiles.CAVE_FLOOR_LIGHT if roll < 0.04 else Tiles.CAVE_FLOOR
				Tiles.rg_tile(self, fl[rng.randi() % fl.size()], pos, Color(0.85, 0.8, 0.78) if biome == "cave" else Color(0.7, 0.8, 0.6))
				continue
			var tint := Color.WHITE if inside else dark
			if biome == "maidan":
				# Втоптана земля в колі, довкола трава
				if inside:
					Tiles.rg_tile(self, Tiles.RG_DIRT[rng.randi() % Tiles.RG_DIRT.size()], pos)
				else:
					Tiles.tile(self, tex, Tiles.GRASS[0], pos, Color(0.82, 0.86, 0.8))
				continue
			if biome == "snow":
				# Сніг: холодно-білі клітинки (тайл Kenney кремовий), замети, сліди, камінь із-під снігу
				var snow_shade := 0.975 + 0.025 * rng.randf()
				draw_rect(Rect2(pos, Vector2(ts, ts)), Color(0.9 * snow_shade, 0.93 * snow_shade, 0.98 * snow_shade) * tint)
				if inside and roll > 0.93:
					draw_rect(Rect2(pos + Vector2(4.0, ts * 0.55), Vector2(ts - 8.0, 3.0)), Color(0.76, 0.82, 0.92) * tint)  # замет
				elif inside and roll < 0.015:
					draw_rect(Rect2(pos + Vector2(ts * 0.3, ts * 0.35), Vector2(ts * 0.4, ts * 0.25)), Color(0.62, 0.66, 0.72) * tint)  # камінь з-під снігу
				elif inside and roll < 0.04:
					draw_rect(Rect2(pos + Vector2(ts * 0.25, ts * 0.4), Vector2(3.0, 4.0)), Color(0.66, 0.72, 0.84) * tint)
					draw_rect(Rect2(pos + Vector2(ts * 0.55, ts * 0.62), Vector2(3.0, 4.0)), Color(0.66, 0.72, 0.84) * tint)
				continue
			if biome == "sand":
				# Піски: світлі бархани, подекуди темніші смуги, які намів вітер
				var shade := 0.94 + 0.08 * rng.randf()
				draw_rect(Rect2(pos, Vector2(ts, ts)), Color(0.86 * shade, 0.76 * shade, 0.5 * shade) * tint)
				if roll > 0.9:
					draw_rect(Rect2(pos + Vector2(4.0, ts * 0.5), Vector2(ts - 8.0, 3.0)), Color(0.74, 0.63, 0.4) * tint)
				elif roll < 0.03:
					draw_rect(Rect2(pos + Vector2(ts * 0.3, ts * 0.3), Vector2(4.0, 4.0)), Color(0.92, 0.88, 0.75) * tint)
				continue
			if biome == "swamp":
				tint = tint * swamp_tint
			if mountain:
				# Гори: світлий камінь, подекуди трава й сніг
				var st: Array = Tiles.STONE if roll > 0.07 else (Tiles.SNOW if roll < 0.03 else Tiles.STONE_DARK)
				Tiles.rg_tile(self, st[rng.randi() % st.size()], pos, tint)
				if inside and roll > 0.93:
					Tiles.rg_tile(self, Tiles.RG_GRASS[rng.randi() % 2], pos, tint)
				continue
			var cell: Array = Tiles.GRASS[0]
			if roll < 0.08:
				cell = Tiles.GRASS[1 + rng.randi() % (Tiles.GRASS.size() - 1)]
			Tiles.tile(self, tex, cell, pos, tint)
			if not inside:
				continue
			var cy := pos.y + ts / 2
			if biome == "river":
				# Річка: смуга води з хвилями по краях, латаття подекуди
				var band := river_y + sin((pos.x - arena.position.x) / arena.size.x * 5.0) * 140.0
				var dy := cy - band
				if absf(dy) < 96.0:
					if absf(dy) > 64.0:
						Tiles.tile(self, tex, Tiles.WAVES[rng.randi() % Tiles.WAVES.size()], pos)
					else:
						Tiles.tile(self, tex, Tiles.WATER[rng.randi() % Tiles.WATER.size()], pos)
						if roll > 0.9:
							Tiles.tile(self, tex, Tiles.LILY[rng.randi() % Tiles.LILY.size()], pos)
					continue
			if biome == "swamp":
				var in_pond := false
				for pd in ponds:
					var dx: int = c - int(pd.x)
					var dyy: int = r - int(pd.y)
					if dx >= 0 and dx < 3 and dyy >= 0 and dyy < 3:
						Tiles.tile(self, tex, [2 + dx, 6 + dyy], pos, swamp_tint)
						if dx == 1 and dyy == 1 and roll > 0.5:
							Tiles.tile(self, tex, Tiles.LILY[rng.randi() % Tiles.LILY.size()], pos, swamp_tint)
						in_pond = true
						break
				if in_pond:
					continue
				if roll > 0.8:
					Tiles.tile(self, tex, Tiles.GRASS_TALL[rng.randi() % Tiles.GRASS_TALL.size()], pos, swamp_tint)
				continue
			var on_path: bool = biome != "forest" and absf(cy - (path_off + sin((pos.x - arena.position.x) / arena.size.x * 7.0) * 220.0)) < 40.0
			if on_path:
				Tiles.tile(self, tex, Tiles.DIRT[rng.randi() % Tiles.DIRT.size()], pos)
			elif roll > 0.955:
				Tiles.tile(self, tex, Tiles.FLOWERS[rng.randi() % Tiles.FLOWERS.size()], pos)
			elif roll > 0.9 and biome != "village":
				Tiles.tile(self, tex, Tiles.GRASS_TALL[rng.randi() % Tiles.GRASS_TALL.size()], pos)
			elif roll > 0.885 and biome != "village":
				Tiles.tile(self, tex, Tiles.ROCKS_SMALL[rng.randi() % Tiles.ROCKS_SMALL.size()], pos)
	if cave:
		# Стіна печери понад верхнім краєм арени
		var c := floori(arena.position.x / ts) - 1
		while c * ts < arena.end.x + ts:
			var pos := Vector2(c * ts, arena.position.y - ts)
			Tiles.tile(self, tex, Tiles.CAVE_WALL[rng.randi() % 3], pos)
			Tiles.tile(self, tex, Tiles.CAVE_WALL_TOP[rng.randi() % 3], pos - Vector2(0, ts))
			c += 1
		_crystals()
