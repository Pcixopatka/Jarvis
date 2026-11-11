class_name Companion
extends Node2D
## Супутник козака: джура (ближній бій), стрілець (рушниця) або знахарка (лікування).

const Data := preload("res://scripts/data/data.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const Party := preload("res://scripts/game/party.gd")
const OFFSETS := [Vector2(-70, 40), Vector2(70, 40), Vector2(-60, -55), Vector2(60, -55)]  # строй загону

var combat: Combat
var type := "dzhura"
var info := {}
var index := 0  # місце в загоні (для зсуву під час руху)
var level := 1
var heal_amount := 0.0
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
var anim_moving := false  # для спрайтів: чи рухався цього кадру
var swing := 0.0
var hero := ""  # id побратима або "" для найманця
var mult := 1.0  # побратими сильніші за найманців
var boost := 1.0  # Бойовий стяг героя: множник шкоди й здоров'я загону
var display_name := ""


## data — запис загону: {"type", "level", "hero", "mult", "name", "color"}.
func setup(t: String, lvl: int, idx: int, data: Dictionary = {}) -> void:
	type = t
	index = idx
	info = Data.COMPANIONS[t].duplicate()
	hero = data.get("hero", "")
	mult = float(data.get("mult", 1.0))
	display_name = data.get("name", info["name"])
	if data.has("color"):
		info["color"] = data["color"]
	set_level(lvl)
	hp = max_hp


## Новий рівень: показники ростуть, здоров'я відновлюється повністю.
func set_level(lvl: int) -> void:
	level = lvl
	var st := Party.stats(type, lvl, mult)
	max_hp = st["hp"] * boost
	damage = st["dmg"] * boost
	heal_amount = st.get("heal", 0.0)
	hp = max_hp


func _process(delta: float) -> void:
	if not alive:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	heal_cd = maxf(0.0, heal_cd - delta)
	flash = maxf(0.0, flash - delta)
	swing = maxf(0.0, swing - delta)
	var p = combat.player
	var target: Node2D = combat.nearest_enemy(global_position, 450.0)
	var dest: Vector2 = p.global_position + OFFSETS[index % OFFSETS.size()]
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
	anim_moving = move.length() > 12.0
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
		var amount: float = heal_amount
		for a in combat.allies():
			if a == self:
				hp = minf(max_hp, hp + amount)
			elif a.hp < a.max_hp:
				a.heal(amount)
		combat.float_text(global_position + Vector2(0, -40), "Зілля!", Color(0.5, 1.0, 0.5))
	queue_redraw()


func _attack(target) -> void:
	attack_cd = info["cd"]
	swing = 0.2
	var dir: Vector2 = (target.global_position - global_position).normalized()
	match type:
		"dzhura":
			target.take_damage(damage * randf_range(0.9, 1.1), dir * 160.0, false)
		"strilets":
			combat.spawn_bullet(global_position + dir * 20.0, dir, damage, false)
		"znakhar":
			target.take_damage(damage, dir * 60.0, false)


func heal(amount: float, _show: bool = true) -> void:
	hp = minf(max_hp, hp + amount)


func take_damage(amount: float, _source = null) -> void:
	if not alive:
		return
	if combat.ally_hit_frac > 0.0:
		# сутичка ватаг: суперник міряний за еталоном рівня героя, тож побратимові рахуємо удар часткою його власного здоров'я
		amount = max_hp * combat.ally_hit_frac
	if combat.player.zahyst_timer > 0.0:
		amount *= combat.player.zahyst_mult  # Оберіг загону знахаря
	hp -= amount
	flash = 0.15
	if hp <= 0.0:
		alive = false
		visible = false
		combat.on_companion_down(self)


func sprite_id() -> String:
	var id := "comp_" + (hero if hero != "" else type)
	return id if Gfx.has(id) else "comp_" + type


func _draw() -> void:
	var col: Color = info.get("color", Color.WHITE)
	if flash > 0.0:
		col = Color(1, 0.5, 0.5)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Gfx.has(sprite_id()):
		var frame := Gfx.IDLE
		if not alive:
			frame = Gfx.DEAD
		elif flash > 0.0:
			frame = Gfx.HURT
		elif swing > 0.0:
			frame = Gfx.attack_frame(1.0 - swing / 0.2)
		elif anim_moving:
			frame = Gfx.walk_frame(walk)
		Gfx.draw(self, sprite_id(), facing, frame, Vector2(-24, -30), Color(1.6, 1.6, 1.6) if flash > 0.0 else Color.WHITE)
		_draw_marks()
		return
	_draw_vector(col, side)
	_draw_marks()


func _draw_marks() -> void:
	var head := Vector2(0, -22)
	if hero != "":
		# Побратим: золота зірочка над головою
		var st0 := head + Vector2(0, -24)
		var star := PackedVector2Array()
		for i in 10:
			star.append(st0 + Vector2.from_angle(-PI / 2 + i * PI / 5) * (6.0 if i % 2 == 0 else 2.6))
		draw_colored_polygon(star, Color(1.0, 0.82, 0.25))
	# Смужка здоров'я
	draw_rect(Rect2(-16, -40, 32, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-16, -40, 32 * hp / max_hp, 4), Color(0.3, 0.9, 0.4))


func _draw_vector(col: Color, side: float) -> void:
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

