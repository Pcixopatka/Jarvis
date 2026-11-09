extends Node2D
## Стежка слідів на землі: відбитки між точками, наприкінці — знахідка (скриня, лігво або поранений вепр).
## Лише малює; логіку (чи дійшов герой до точки) веде combat.gd.

const Gfx := preload("res://scripts/world/gfx.gd")
const ANIMALS := preload("res://assets/gfx/sprites/animals.png")
const PRINT := Color(0.13, 0.09, 0.06, 0.72)
const K := 1.4  # розмір відбитка

var points: Array = []  # перша — початок слідів, остання — знахідка
var kind := "cache"
var step := 0  # до якої точки герой уже дійшов (0 — початок іще не знайдено)
var show_all := false  # пластун бачить усю стежку
var found := false
var _t := 0.0


func setup(pts: Array, k: String, all_visible: bool):
	points = pts
	kind = k
	show_all = all_visible
	return self


## Куди зараз іти.
func target() -> Vector2:
	return points[mini(step, points.size() - 1)]


## Номер останньої точки, до якої сліди вже видно.
func revealed() -> int:
	return points.size() - 1 if show_all else step


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if points.is_empty():
		return
	var upto := revealed()
	# Початок: купка слідів довкола першої точки (видно завжди)
	var a0: Vector2 = points[0]
	var lead: Vector2 = (points[1] - a0).normalized() if points.size() > 1 else Vector2.RIGHT
	for i in 5:
		var off := Vector2.from_angle(i * 1.9 + 0.4) * (10.0 + 7.0 * (i % 3))
		_print(a0 + off - lead * 14.0, lead.angle(), i % 2 == 0, 1.0)
	if step == 0 and not show_all:
		# Легке миготіння, щоб око зачепилось
		draw_arc(a0, 34.0 + sin(_t * 3.0) * 4.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.5, 0.35 + 0.2 * sin(_t * 3.0)), 2.0)
	for i in upto:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var d := b - a
		var n := maxi(1, int(d.length() / 30.0))
		var dir := d.normalized()
		var side := dir.orthogonal()
		var fresh := i == upto - 1 and not found
		for j in range(1, n):
			var p := a + dir * (j * 30.0) + side * (7.0 if j % 2 == 0 else -7.0)
			_print(p, dir.angle(), j % 2 == 0, 1.0 if not fresh else 0.8 + 0.2 * sin(_t * 4.0 - j * 0.5))
	if upto >= points.size() - 1 or found:
		_draw_goal(points[-1])


## Один відбиток: чобіт (схованка), лапа з пазурами (лігво) або ратиця (звір).
func _print(p: Vector2, ang: float, _left: bool, alpha: float) -> void:
	var c := Color(PRINT.r, PRINT.g, PRINT.b, PRINT.a * alpha)
	draw_set_transform(p, ang, Vector2(K, K))
	match kind:
		"den":
			draw_circle(Vector2(-2, 0), 4.0, c)
			for k in 3:
				draw_circle(Vector2(5, (k - 1) * 4.0), 1.6, c)
		"beast":
			draw_set_transform(p, ang, Vector2(K, 0.5 * K))
			draw_circle(Vector2(0, -5), 3.6, c)
			draw_circle(Vector2(0, 5), 3.6, c)
		_:
			draw_set_transform(p, ang, Vector2(K, 0.55 * K))
			draw_circle(Vector2(2, 0), 5.5, c)
			draw_set_transform(p, ang, Vector2(K, K))
			draw_circle(Vector2(-6, 0), 2.6, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_goal(p: Vector2) -> void:
	match kind:
		"den":
			draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 46.0, Color(0.08, 0.06, 0.05, 0.9))
			draw_circle(Vector2.ZERO, 34.0, Color(0.02, 0.02, 0.02, 0.95))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in 4:
				var b := p + Vector2.from_angle(k * 1.7 + 0.3) * 52.0
				draw_line(b + Vector2(-7, 0), b + Vector2(7, 2), Color(0.9, 0.88, 0.8, 0.9), 3.0)
				draw_circle(b + Vector2(-7, 0), 2.5, Color(0.9, 0.88, 0.8, 0.9))
				draw_circle(b + Vector2(7, 2), 2.5, Color(0.9, 0.88, 0.8, 0.9))
		"beast":
			if not found:
				draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.35))
				draw_circle(Vector2.ZERO, 38.0, Color(0, 0, 0, 0.25))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_texture_rect_region(ANIMALS, Rect2(p + Vector2(-48, -44), Vector2(96, 64)), Rect2(96, 64, 48, 32))
			else:
				for k in 5:
					draw_circle(p + Vector2.from_angle(k * 1.3) * 16.0, 5.0, Color(0.45, 0.08, 0.08, 0.5))
		_:
			var c := Gfx.OBJ["chest_open" if found else "chest"] as Array
			draw_set_transform(p + Vector2(0, 4), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect_region(Gfx.OBJECTS, Rect2(p + Vector2(-24, -40), Vector2(48, 48)), Rect2(c[0] * 16, c[1] * 16, 16, 16))
