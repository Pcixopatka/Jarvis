extends Node2D
## Здобич: гривня (досвід і гроші), вареник (лікування) або річ спорядження.

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Gfx := preload("res://scripts/world/gfx.gd")

var combat: Combat
var kind := "coin"  # "coin", "varenyk" або "item"
var item := {}
var value := 1
var phase := randf() * TAU
var pull_speed := 0.0
var spawn_vel := Vector2.ZERO
var manual := false  # викинута з торби річ: сама до героя не летить, підбирається лише впритул
var hold := 0.0  # скільки секунд викинуту річ ще не можна підібрати


func _process(delta: float) -> void:
	phase += delta * 4.0
	position += spawn_vel * delta
	spawn_vel = spawn_vel.move_toward(Vector2.ZERO, 600.0 * delta)
	var p = combat.player
	if not p.alive:
		queue_redraw()
		return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	hold = maxf(0.0, hold - delta)
	var block := _block(p)
	modulate.a = 0.45 if block == "filter" else 1.0  # річ, яку фільтр не бере, лежить тьмяна
	if block != "":
		# нема куди покласти або фільтр не бере: здобич лежить далі, а не зникає
		pull_speed = 0.0
		if block == "full" and kind == "item" and dist < 70.0:
			combat.note_bag_full()
		queue_redraw()
		return
	if manual:
		if hold > 0.0 or dist > 30.0:
			queue_redraw()
			return
	elif dist < p.pickup_radius:
		pull_speed = minf(pull_speed + 1600.0 * delta, 900.0)
		position += to.normalized() * minf(pull_speed * delta, dist)
	if dist < (30.0 if manual else 22.0):
		combat.take_loot(kind, value, item, global_position)  # те саме робить Хованець одразу з нечисті
		queue_free()
		return
	queue_redraw()


## Чому це не підбирається: "" — підбирається, "full" — нема куди покласти (повна торба чи повний
## запас зілля), "filter" — фільтр автопідбору не бере речі такої рідкості.
func _block(_p) -> String:
	return combat.loot_block(kind, item, manual)


func _wanted(p) -> bool:
	return _block(p) == ""


func _draw() -> void:
	var hover := sin(phase) * 3.0
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, hover - 4), 0.0, Vector2.ONE)
	if Gfx.has("icons"):
		_draw_icon()
		return
	if kind == "item":
		var col: Color = Data.item_color(item)
		draw_circle(Vector2.ZERO, 20.0 + sin(phase * 2.0) * 3.0, Color(col, 0.25))
		# Вузлик зі здобиччю
		draw_circle(Vector2(0, 2), 11.0, Color(0.55, 0.38, 0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(0, -2)]), Color(0.45, 0.3, 0.15))
		draw_line(Vector2(-7, -6), Vector2(7, -6), col, 3.0)
		draw_circle(Vector2(6, -10), 2.5, Color(1, 1, 0.9))
		return
	if kind == "res":
		var col: Color = Camp.RESOURCE_COLORS[item["res"]]
		match item["res"]:
			"wood":
				draw_rect(Rect2(-10, -4, 20, 8), col)
				draw_circle(Vector2(10, 0), 4.0, col.lightened(0.3))
			"iron":
				draw_colored_polygon(PackedVector2Array([Vector2(-9, 4), Vector2(-5, -5), Vector2(9, -5), Vector2(5, 4)]), col)
				draw_line(Vector2(-5, -5), Vector2(9, -5), col.lightened(0.4), 2.0)
			_:
				for i in 3:
					draw_line(Vector2(-4 + i * 4, 6), Vector2(-6 + i * 6, -8), col, 3.0)
				draw_circle(Vector2(0, -8), 3.0, Color(0.95, 0.85, 0.3))
		return
	if kind == "potion":
		# Пляшечка з червоним зіллям
		draw_circle(Vector2(0, 2), 9.0, Color(0.85, 0.12, 0.15))
		draw_circle(Vector2(-3, -1), 3.0, Color(1, 0.6, 0.6, 0.8))
		draw_rect(Rect2(-3, -12, 6, 6), Color(0.75, 0.8, 0.85))
		draw_rect(Rect2(-4, -15, 8, 3), Color(0.5, 0.3, 0.15))
		return
	if kind == "coin":
		var r := 6.0 + minf(value, 20) * 0.35
		draw_circle(Vector2.ZERO, r, Color(0.95, 0.75, 0.15))
		draw_circle(Vector2.ZERO, r * 0.65, Color(1.0, 0.88, 0.35))
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 0.9))
	else:
		# Вареник: півмісяць із защипами
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(Vector2.from_angle(PI + i * PI / 12.0) * 13.0)
		draw_colored_polygon(pts, Color(0.98, 0.93, 0.8))
		for i in 7:
			draw_circle(Vector2.from_angle(PI + i * PI / 6.0) * 13.0, 2.5, Color(0.92, 0.85, 0.7))
		draw_line(Vector2(-13, 0), Vector2(13, 0), Color(0.85, 0.78, 0.62), 2.0)


## Нова графіка: значки з атласу замість малюнків кодом.
func _draw_icon() -> void:
	match kind:
		"item":
			var col: Color = Data.item_color(item)
			draw_circle(Vector2.ZERO, 20.0 + sin(phase * 2.0) * 3.0, Color(col, 0.25))
			Gfx.icon(self, "chest", Vector2(0, -2), 2.0)
			draw_circle(Vector2(10, -12), 3.0, col)
		"res":
			Gfx.icon(self, item["res"], Vector2(0, -2), 2.0)
		"potion":
			Gfx.icon(self, "potion", Vector2(0, -2), 2.0)
		"mana":
			Gfx.icon(self, "mana", Vector2(0, -2), 2.0)
		"token":
			draw_circle(Vector2.ZERO, 17.0 + sin(phase * 2.5) * 2.5, Color(1.0, 0.85, 0.4, 0.28))
			Gfx.icon(self, str(item.get("icon", "glory")), Vector2(0, -2), 2.0)
		"coin":
			Gfx.icon(self, "coin" if value >= 8 else "coin_small", Vector2.ZERO, 1.5 + minf(value, 20) * 0.03)
		_:
			Gfx.icon(self, "varenyk", Vector2(0, -2), 2.0)
