extends Node2D
## Козак — головний герой. Рух, удар шаблею, перекид, вихор, прокачка.

signal died
signal leveled_up(level: int)

var main

# --- Характеристики ---
var radius := 22.0
var max_hp := 100.0
var hp := 100.0
var speed := 260.0
var damage := 20.0
var crit_chance := 0.1
var attack_cooldown := 0.42
var attack_range := 95.0
var attack_arc := deg_to_rad(130.0)
var skill_cooldown := 8.0
var dodge_cooldown := 1.2
var pickup_radius := 120.0
var armor := 0.0

# --- Прогрес ---
var level := 1
var xp := 0
var xp_next := 10

# --- Стан ---
var facing := Vector2.RIGHT
var attack_held := false
var attack_timer := 0.0
var dodge_timer := 0.0
var skill_timer := 0.0
var dodge_time_left := 0.0
var dodge_dir := Vector2.RIGHT
var invuln := 0.0
var swing_time := 0.0
var swing_duration := 0.18
var swing_full := false
var hurt_flash := 0.0
var walk_phase := 0.0
var moving := false
var alive := true


func _process(delta: float) -> void:
	if not alive:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	invuln = maxf(0.0, invuln - delta)
	swing_time = maxf(0.0, swing_time - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)

	var input_vec: Vector2 = main.get_move_input()
	moving = false
	if dodge_time_left > 0.0:
		dodge_time_left -= delta
		position += dodge_dir * speed * 3.2 * delta
	else:
		position += input_vec * speed * delta
		if input_vec.length() > 0.1:
			moving = true
			if swing_time <= 0.0:
				facing = input_vec.normalized()
			walk_phase += delta * 14.0

	var pad := Vector2(radius, radius)
	position = position.clamp(main.ARENA.position + pad, main.ARENA.end - pad)

	if attack_held and attack_timer <= 0.0:
		attack()
	queue_redraw()


# --- Бойові дії ---

func _roll_damage(mult: float) -> Array:
	var crit := randf() < crit_chance
	var dmg := damage * mult * (2.0 if crit else 1.0) * randf_range(0.9, 1.1)
	return [dmg, crit]


func attack() -> void:
	if not alive or attack_timer > 0.0 or dodge_time_left > 0.0:
		return
	attack_timer = attack_cooldown
	# Автонаведення — на телефоні цілитися пальцем незручно.
	var target: Node2D = main.nearest_enemy(global_position, attack_range * 1.8)
	if target:
		facing = (target.global_position - global_position).normalized()
	swing_time = 0.18
	swing_duration = 0.18
	swing_full = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		var dist := to.length()
		if dist > attack_range + e.radius:
			continue
		if dist < 1.0 or absf(facing.angle_to(to)) <= attack_arc * 0.5:
			var r := _roll_damage(1.0)
			e.take_damage(r[0], to.normalized() * 280.0, r[1])
	main.shake(2.0)


func dodge() -> void:
	if not alive or dodge_timer > 0.0:
		return
	dodge_timer = dodge_cooldown
	var input_vec: Vector2 = main.get_move_input()
	dodge_dir = input_vec.normalized() if input_vec.length() > 0.1 else facing
	dodge_time_left = 0.18
	invuln = maxf(invuln, 0.32)


func skill() -> void:
	if not alive or skill_timer > 0.0:
		return
	skill_timer = skill_cooldown
	swing_time = 0.4
	swing_duration = 0.4
	swing_full = true
	invuln = maxf(invuln, 0.4)
	var reach := attack_range * 1.8
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= reach + e.radius:
			var r := _roll_damage(1.8)
			e.take_damage(r[0], to.normalized() * 480.0, r[1])
	main.shake(9.0)
	main.float_text(global_position + Vector2(0, -60), "Вихор!", Color(0.6, 0.85, 1.0))


func take_damage(amount: float) -> void:
	if not alive or invuln > 0.0:
		return
	amount *= (1.0 - armor)
	hp -= amount
	hurt_flash = 0.2
	invuln = 0.35
	main.shake(7.0)
	main.float_text(global_position + Vector2(0, -50), str(int(amount)), Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		hp = 0.0
		alive = false
		queue_redraw()
		died.emit()


func heal(amount: float) -> void:
	var before := hp
	hp = minf(max_hp, hp + amount)
	var gained := int(hp - before)
	if gained > 0:
		main.float_text(global_position + Vector2(0, -50), "+%d" % gained, Color(0.4, 1.0, 0.45))


func add_xp(value: int) -> void:
	xp += value
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(10 + (level - 1) * 7 + pow(level - 1, 1.5))
		leveled_up.emit(level)


func apply_upgrade(id: String) -> void:
	match id:
		"damage":
			damage *= 1.25
		"hp":
			max_hp += 25.0
			hp += 25.0
		"speed":
			speed *= 1.12
		"attack_speed":
			attack_cooldown *= 0.85
		"range":
			attack_range *= 1.2
		"skill":
			skill_cooldown *= 0.8
		"heal":
			heal(max_hp * 0.5)
		"magnet":
			pickup_radius *= 1.4
		"armor":
			armor = minf(0.6, armor + 0.12)
		"crit":
			crit_chance = minf(0.75, crit_chance + 0.08)


# --- Малювання козака (без зовнішніх спрайтів) ---

func _draw() -> void:
	var tint := Color.WHITE
	if not alive:
		tint = Color(0.5, 0.5, 0.5, 0.8)
	elif hurt_flash > 0.0:
		tint = Color(1.0, 0.45, 0.45)
	elif dodge_time_left > 0.0:
		tint = Color(1, 1, 1, 0.55)

	# Тінь
	draw_set_transform(Vector2(0, 20), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not alive:
		# Козак упав
		draw_set_transform(Vector2(0, 8), PI / 2.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	var bob := sin(walk_phase) * 3.0 if moving else 0.0

	# Ноги: широкі сині шаровари та червоні чоботи
	var leg_l := Vector2(-7, 10 + bob)
	var leg_r := Vector2(7, 10 - bob)
	draw_rect(Rect2(leg_l - Vector2(6, 2), Vector2(11, 10)), Color(0.18, 0.3, 0.7) * tint)
	draw_rect(Rect2(leg_r - Vector2(5, 2), Vector2(11, 10)), Color(0.18, 0.3, 0.7) * tint)
	draw_rect(Rect2(leg_l + Vector2(-5, 7), Vector2(10, 6)), Color(0.6, 0.1, 0.1) * tint)
	draw_rect(Rect2(leg_r + Vector2(-4, 7), Vector2(10, 6)), Color(0.6, 0.1, 0.1) * tint)

	# Тулуб: червоний жупан і жовтий пояс
	draw_circle(Vector2(0, -2), 16.0, Color(0.78, 0.14, 0.14) * tint)
	draw_rect(Rect2(-15, 3, 30, 5), Color(0.95, 0.75, 0.15) * tint)

	# Голова, оселедець, вуса
	var head := Vector2(0, -26)
	draw_circle(head, 11.0, Color(0.96, 0.8, 0.65) * tint)
	var chub := PackedVector2Array([
		head + Vector2(0, -11), head + Vector2(-side * 6, -17),
		head + Vector2(-side * 13, -14), head + Vector2(-side * 15, -6),
	])
	draw_polyline(chub, Color(0.25, 0.15, 0.08) * tint, 4.0, true)
	draw_circle(head + Vector2(side * 4, -2), 1.8, Color(0.1, 0.1, 0.1) * tint)
	draw_line(head + Vector2(side * 2, 4), head + Vector2(side * 10, 8), Color(0.3, 0.18, 0.08) * tint, 2.5)
	draw_line(head + Vector2(side * 2, 4), head + Vector2(-side * 5, 8), Color(0.3, 0.18, 0.08) * tint, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not alive:
		return

	# Шабля
	var blade_angle := facing.angle()
	if swing_time > 0.0:
		var t := 1.0 - swing_time / swing_duration
		if swing_full:
			blade_angle += t * TAU * 1.5
		else:
			blade_angle += lerpf(-attack_arc * 0.5, attack_arc * 0.5, t)
	var hand := Vector2(side * 12, -4)
	var dir := Vector2.from_angle(blade_angle)
	var tip := hand + dir * 44.0
	var curve := hand + dir * 26.0 + dir.orthogonal() * 5.0
	draw_polyline(PackedVector2Array([hand, curve, tip]), Color(0.86, 0.9, 0.95), 4.0, true)
	draw_line(hand - dir * 8.0, hand, Color(0.45, 0.28, 0.1), 5.0)
	draw_line(hand + dir.orthogonal() * 6.0, hand - dir.orthogonal() * 6.0, Color(0.85, 0.7, 0.2), 3.0)

	# Слід удару
	if swing_time > 0.0:
		var alpha := swing_time / swing_duration
		if swing_full:
			draw_arc(Vector2.ZERO, attack_range * 1.5, 0.0, TAU, 64, Color(0.7, 0.9, 1.0, 0.55 * alpha), 22.0)
			draw_arc(Vector2.ZERO, attack_range * 1.1, 0.0, TAU, 64, Color(1, 1, 1, 0.4 * alpha), 8.0)
		else:
			var a0 := facing.angle() - attack_arc * 0.5
			draw_arc(Vector2.ZERO, attack_range * 0.75, a0, a0 + attack_arc, 24, Color(1, 1, 1, 0.6 * alpha), 16.0)

	# Індикатор готовності вихору
	if skill_timer <= 0.0:
		draw_arc(Vector2(0, 20), 26.0, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.5), 2.0)
