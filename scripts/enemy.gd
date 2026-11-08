extends Node2D
## Нечисть: мавка, упир, болотяник та бос — Змій.

var main
var kind := "mavka"
var radius := 16.0
var max_hp := 30.0
var hp := 30.0
var speed := 150.0
var damage := 8.0
var xp_value := 3
var color := Color.WHITE
var ranged := false
var is_boss := false
var keep_distance := 0.0
var shoot_cd := 2.0
var shoot_timer := 1.5
var knockback := Vector2.ZERO
var flash := 0.0
var contact_cd := 0.0
var phase := randf() * TAU
var facing := Vector2.LEFT
var dead := false


func setup(k: String, wave: int) -> void:
	kind = k
	var s := 1.0 + 0.12 * (wave - 1)
	match k:
		"mavka":
			radius = 16.0; max_hp = 30.0 * s; speed = 150.0; damage = 8.0; xp_value = 3
			color = Color(0.6, 0.92, 0.65)
		"upyr":
			radius = 22.0; max_hp = 85.0 * s; speed = 92.0; damage = 15.0; xp_value = 6
			color = Color(0.5, 0.1, 0.14)
		"bolotianyk":
			radius = 20.0; max_hp = 45.0 * s; speed = 85.0; damage = 10.0; xp_value = 5
			color = Color(0.33, 0.45, 0.2)
			ranged = true; keep_distance = 320.0; shoot_cd = 2.2
		"zmii":
			radius = 52.0; max_hp = 700.0 * s; speed = 70.0; damage = 25.0; xp_value = 60
			color = Color(0.2, 0.55, 0.25)
			ranged = true; is_boss = true; shoot_cd = 2.6
	speed *= minf(1.35, 1.0 + 0.025 * (wave - 1))
	shoot_timer = randf_range(1.0, shoot_cd)
	hp = max_hp
	add_to_group("enemies")


func _process(delta: float) -> void:
	if dead:
		return
	var p = main.player
	flash = maxf(0.0, flash - delta)
	contact_cd = maxf(0.0, contact_cd - delta)
	phase += delta * 6.0

	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	facing = dir
	var desired := dir
	if keep_distance > 0.0:
		if dist < keep_distance * 0.8:
			desired = -dir
		elif dist < keep_distance * 1.15:
			desired = dir.orthogonal() * sin(phase * 0.15)

	# Розштовхування, щоб нечисть не злипалась в одну купу
	var sep := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or o.dead:
			continue
		var d: Vector2 = global_position - o.global_position
		var min_d: float = radius + o.radius
		var l := d.length()
		if l < min_d and l > 0.01:
			sep += d / l * (min_d - l) / min_d

	if not p.alive:
		desired = Vector2.ZERO
	var vel := desired * speed + sep * speed * 1.5 + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	position += vel * delta
	var pad := Vector2(radius, radius)
	position = position.clamp(main.ARENA.position + pad, main.ARENA.end - pad)

	if p.alive and dist < radius + p.radius + 4.0 and contact_cd <= 0.0:
		p.take_damage(damage)
		contact_cd = 0.9

	if ranged and p.alive:
		shoot_timer -= delta
		if shoot_timer <= 0.0 and dist < 750.0:
			shoot_timer = shoot_cd
			if is_boss:
				for a in [-0.35, 0.0, 0.35]:
					main.spawn_projectile(global_position + dir * 40.0, dir.rotated(a), 300.0, damage * 0.7, Color(1.0, 0.5, 0.1), 13.0)
			else:
				main.spawn_projectile(global_position, dir, 260.0, damage, Color(0.55, 0.85, 0.2), 9.0)
	queue_redraw()


func take_damage(amount: float, kb: Vector2, crit: bool = false) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	knockback += kb * (0.15 if is_boss else 1.0)
	var col := Color(1.0, 0.85, 0.2) if crit else Color.WHITE
	main.float_text(global_position + Vector2(0, -radius - 14), str(int(amount)) + ("!" if crit else ""), col)
	if hp <= 0.0:
		dead = true
		remove_from_group("enemies")
		main.on_enemy_killed(self)
		queue_free()


# --- Малювання ---

func _c(c: Color) -> Color:
	return Color(1, 1, 1, c.a) if flash > 0.0 else c


func _draw() -> void:
	draw_set_transform(Vector2(0, radius * 0.9), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	match kind:
		"mavka":
			_draw_mavka(side)
		"upyr":
			_draw_upyr(side)
		"bolotianyk":
			_draw_bolotianyk(side)
		"zmii":
			_draw_zmii()
	if hp < max_hp and not is_boss:
		var w := radius * 2.2
		var y := -radius * 2.0 - 14.0
		draw_rect(Rect2(-w / 2, y, w, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, y, w * hp / max_hp, 5), Color(0.9, 0.2, 0.2))


func _draw_mavka(side: float) -> void:
	var sway := sin(phase) * 3.0
	# Сукня
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(15 + sway, 14), Vector2(-15 + sway, 14)
	]), _c(Color(0.85, 0.95, 0.85, 0.9)))
	# Довге зелене волосся
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -22), Vector2(10, -22), Vector2(9 - side * 4 + sway, 4), Vector2(-9 - side * 4 + sway, 4)
	]), _c(Color(0.2, 0.5, 0.3)))
	draw_circle(Vector2(0, -20), 8.0, _c(color))
	draw_circle(Vector2(side * 3, -21), 1.6, Color(0.1, 0.3, 0.2))
	# Вінок
	for i in 5:
		var a := PI + i * PI / 4.0
		var fc: Color = [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.5, 0.6, 1.0)][i % 3]
		draw_circle(Vector2(0, -22) + Vector2.from_angle(a) * 9.0, 2.6, _c(fc))


func _draw_upyr(side: float) -> void:
	# Темний плащ
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -16), Vector2(14, -16), Vector2(22, 16), Vector2(0, 10), Vector2(-22, 16)
	]), _c(Color(0.15, 0.05, 0.08)))
	draw_circle(Vector2(0, -2), 15.0, _c(color))
	draw_circle(Vector2(side * 4, -24), 11.0, _c(Color(0.75, 0.75, 0.72)))
	draw_circle(Vector2(side * 8, -26), 2.4, Color(1, 0.1, 0.1))
	draw_circle(Vector2(side * 1, -26), 2.4, Color(1, 0.1, 0.1))
	draw_line(Vector2(side * 3, -17), Vector2(side * 3, -13), Color.WHITE, 2.0)
	draw_line(Vector2(side * 7, -17), Vector2(side * 7, -13), Color.WHITE, 2.0)


func _draw_bolotianyk(side: float) -> void:
	var squash := 1.0 + sin(phase * 0.8) * 0.06
	draw_set_transform(Vector2(0, -6), 0.0, Vector2(squash, 2.0 - squash))
	draw_circle(Vector2.ZERO, radius, _c(color))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Мох і багнюка
	draw_circle(Vector2(-9, -16), 6.0, _c(Color(0.25, 0.38, 0.12)))
	draw_circle(Vector2(8, -18), 5.0, _c(Color(0.42, 0.55, 0.2)))
	draw_line(Vector2(-12, 6), Vector2(-13, 16 + sin(phase) * 3.0), _c(Color(0.3, 0.4, 0.15)), 3.0)
	draw_line(Vector2(10, 6), Vector2(11, 15 + cos(phase) * 3.0), _c(Color(0.3, 0.4, 0.15)), 3.0)
	draw_circle(Vector2(side * 6 - 4, -8), 4.0, Color(1, 0.95, 0.4))
	draw_circle(Vector2(side * 6 + 5, -8), 4.0, Color(1, 0.95, 0.4))
	draw_circle(Vector2(side * 7 - 4, -8), 1.8, Color.BLACK)
	draw_circle(Vector2(side * 7 + 5, -8), 1.8, Color.BLACK)


func _draw_zmii() -> void:
	# Крила
	var flap := sin(phase * 0.7) * 10.0
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(s * 30, -20), Vector2(s * 100, -60 - flap), Vector2(s * 90, 0), Vector2(s * 40, 10)
		]), _c(Color(0.15, 0.4, 0.2, 0.9)))
	# Тіло
	draw_circle(Vector2(0, 0), radius, _c(color))
	draw_circle(Vector2(0, 8), radius * 0.6, _c(Color(0.75, 0.7, 0.35)))
	# Три голови на шиях, що тягнуться до козака
	for i in 3:
		var a := facing.angle() + (i - 1) * 0.6
		var sway := sin(phase * 0.5 + i) * 6.0
		var neck_end := Vector2.from_angle(a) * 70.0 + Vector2(0, -30 + sway)
		draw_line(Vector2(0, -20), neck_end, _c(color.darkened(0.15)), 16.0)
		draw_circle(neck_end, 17.0, _c(color.lightened(0.1)))
		var eye := neck_end + Vector2.from_angle(a) * 8.0
		draw_circle(eye + Vector2(0, -5), 3.5, Color(1, 0.85, 0.1))
		draw_circle(eye + Vector2(0, -5), 1.5, Color.BLACK)
	# Смуга здоров'я боса
	var w := 160.0
	draw_rect(Rect2(-w / 2, -radius - 70, w, 9), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -radius - 70, w * hp / max_hp, 9), Color(0.95, 0.35, 0.1))
