extends Node2D
## Здобич: дукат (досвід і гроші), вареник (лікування) або річ спорядження.

const Data := preload("res://scripts/data/data.gd")

var combat: Combat
var kind := "coin"  # "coin", "varenyk" або "item"
var item := {}
var value := 1
var phase := randf() * TAU
var pull_speed := 0.0
var spawn_vel := Vector2.ZERO


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
	if dist < p.pickup_radius:
		pull_speed = minf(pull_speed + 1600.0 * delta, 900.0)
		position += to.normalized() * minf(pull_speed * delta, dist)
	if dist < 22.0:
		if kind == "coin":
			p.add_xp(value)
			p.add_gold(value)
			Audio.play("coin", 0.1, -6.0)
			combat.fx.burst(global_position, Color(1.0, 0.9, 0.4), 4, 90, 3, 0.3)
		elif kind == "item":
			combat.pick_item(item)
		else:
			p.heal(value)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var hover := sin(phase) * 3.0
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, hover - 4), 0.0, Vector2.ONE)
	if kind == "item":
		var col: Color = Data.RARITY_COLORS[item["rarity"]]
		draw_circle(Vector2.ZERO, 20.0 + sin(phase * 2.0) * 3.0, Color(col, 0.25))
		# Вузлик зі здобиччю
		draw_circle(Vector2(0, 2), 11.0, Color(0.55, 0.38, 0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(0, -2)]), Color(0.45, 0.3, 0.15))
		draw_line(Vector2(-7, -6), Vector2(7, -6), col, 3.0)
		draw_circle(Vector2(6, -10), 2.5, Color(1, 1, 0.9))
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
