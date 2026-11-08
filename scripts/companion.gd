extends Node2D
## Супутник козака: джура (ближній бій), стрілець (рушниця) або знахарка (лікування).

const Data := preload("res://scripts/data.gd")

var main
var type := "dzhura"
var info := {}
var index := 0  # місце в загоні (для зсуву під час руху)
var radius := 16.0
var max_hp := 90.0
var hp := 90.0
var damage := 8.0
var attack_cd := 0.0
var heal_cd := 2.0
var alive := true
var dead := false  # для сумісності з перевірками ворогів
var flash := 0.0
var facing := Vector2.RIGHT
var walk := 0.0
var swing := 0.0


func setup(t: String, hero_level: int, idx: int) -> void:
	type = t
	index = idx
	info = Data.COMPANIONS[t]
	max_hp = info["hp"] + info["hp_lvl"] * (hero_level - 1)
	hp = max_hp
	damage = info["dmg"] + info["dmg_lvl"] * (hero_level - 1)


func _process(delta: float) -> void:
	if not alive:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	heal_cd = maxf(0.0, heal_cd - delta)
	flash = maxf(0.0, flash - delta)
	swing = maxf(0.0, swing - delta)
	var p = main.player
	var target: Node2D = main.nearest_enemy(global_position, 450.0)
	var dest: Vector2 = p.global_position + Vector2(-70 if index == 0 else 70, 40)
	var reach: float = info["range"]

	if target and p.global_position.distance_to(target.global_position) < 500.0:
		var to := target.global_position - global_position
		facing = to.normalized()
		if type == "dzhura":
			dest = target.global_position - facing * 30.0
		else:
			# Стрілець і знахарка тримаються на відстані
			dest = target.global_position - facing * minf(reach * 0.8, to.length())
		if to.length() <= reach + target.radius and attack_cd <= 0.0:
			_attack(target)

	var move := dest - global_position
	if move.length() > 12.0:
		var spd: float = info["speed"] * (1.4 if move.length() > 300.0 else 1.0)
		position += move.normalized() * minf(spd * delta, move.length())
		walk += delta * 12.0
		if not target:
			facing = move.normalized()
	if global_position.distance_to(p.global_position) > 900.0:
		global_position = p.global_position + Vector2(-60, 40)

	if type == "znakhar" and heal_cd <= 0.0:
		heal_cd = 4.0
		var amount: float = info["heal"] + info["heal_lvl"] * (p.level - 1)
		for a in main.allies():
			if a == self:
				hp = minf(max_hp, hp + amount)
			elif a.hp < a.max_hp:
				a.heal(amount)
		main.float_text(global_position + Vector2(0, -40), "Зілля!", Color(0.5, 1.0, 0.5))
	queue_redraw()


func _attack(target) -> void:
	attack_cd = info["cd"]
	swing = 0.2
	var dir: Vector2 = (target.global_position - global_position).normalized()
	match type:
		"dzhura":
			target.take_damage(damage * randf_range(0.9, 1.1), dir * 160.0, false)
		"strilets":
			main.spawn_bullet(global_position + dir * 20.0, dir, damage, false)
		"znakhar":
			target.take_damage(damage, dir * 60.0, false)


func heal(amount: float, _show: bool = true) -> void:
	hp = minf(max_hp, hp + amount)


func take_damage(amount: float, _source = null) -> void:
	if not alive:
		return
	hp -= amount
	flash = 0.15
	if hp <= 0.0:
		alive = false
		visible = false
		main.on_companion_down(self)


func _draw() -> void:
	var col: Color = info.get("color", Color.WHITE)
	if flash > 0.0:
		col = Color(1, 0.5, 0.5)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bob := sin(walk) * 2.0
	draw_rect(Rect2(-9, 6 + bob, 7, 10), Color(0.25, 0.22, 0.2))
	draw_rect(Rect2(2, 6 - bob, 7, 10), Color(0.25, 0.22, 0.2))
	if type == "znakhar":
		# Довга сорочка-вишиванка
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -14), Vector2(10, -14), Vector2(14, 14), Vector2(-14, 14)]), col)
		draw_line(Vector2(-12, 6), Vector2(12, 6), Color(0.8, 0.15, 0.15), 3.0)
	else:
		draw_circle(Vector2(0, -2), 13.0, col)
	var head := Vector2(0, -22)
	draw_circle(head, 9.0, Color(0.96, 0.8, 0.65))
	if type == "znakhar":
		draw_arc(head, 10.0, PI, TAU, 12, Color(0.85, 0.2, 0.2), 4.0)  # стрічка / вінок
	else:
		draw_rect(Rect2(head + Vector2(-9, -12), Vector2(18, 6)), Color(0.2, 0.15, 0.1))
	draw_circle(head + Vector2(side * 3, -1), 1.5, Color.BLACK)
	var hand := Vector2(side * 10, -4)
	match type:
		"dzhura":
			var a := facing.angle() + (lerpf(-1.0, 1.0, 1.0 - swing / 0.2) if swing > 0.0 else 0.0)
			draw_line(hand, hand + Vector2.from_angle(a) * 32.0, Color(0.85, 0.9, 0.95), 3.0)
		"strilets":
			draw_line(hand - facing * 8.0, hand + facing * 34.0, Color(0.35, 0.22, 0.1), 4.0)
			if swing > 0.0:
				draw_circle(hand + facing * 38.0, 7.0, Color(1, 0.8, 0.3, 0.8))
		"znakhar":
			draw_circle(hand, 5.0, Color(0.4, 0.8, 0.3))
	# Смужка здоров'я
	draw_rect(Rect2(-16, -40, 32, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-16, -40, 32 * hp / max_hp, 4), Color(0.3, 0.9, 0.4))
