extends Node2D
## Улюбленець, що ходить за героєм у бою: пес, кіт або ворон (див. Pets.FOLLOWERS). Лише для ока:
## у бійку не лізе, шкоди не завдає й не отримує. Пес ще й бігає до здобичі, що лежить поруч.
## Малюється кодом із дрібних прямокутників, як піксельний спрайт.

const OUTLINE := Color(0.106, 0.078, 0.125)
const SPEED := 420.0

var combat
var player
var kind := "pes"
var _face := 1.0  # 1 — дивиться праворуч, -1 — ліворуч
var _step := 0.0
var _moving := false
var _fetch_t := 0.0
var _goal := Vector2.ZERO
var _t := 0.0


func setup(combat_node, hero, pet_kind: String) -> void:
	combat = combat_node
	player = hero
	kind = pet_kind
	z_index = 0


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	var home: Vector2 = player.position - player.facing * 46.0 + Vector2(0, 22)
	if kind == "voron":
		home = player.position + Vector2(-player.facing.x * 30.0, -8.0)
	_goal = home
	if kind == "pes":
		_fetch_t -= delta
		if _fetch_t <= 0.0:
			_fetch_t = 0.3
			_fetch = _nearest_pickup()
		if _fetch != null and is_instance_valid(_fetch) and not _fetch.is_queued_for_deletion():
			_goal = _fetch.position
	var to: Vector2 = _goal - position
	var dist := to.length()
	if dist > 900.0:
		position = home  # герой перейшов далеко: улюбленець уже поруч
		dist = 0.0
	_moving = dist > 14.0
	if _moving:
		position += to / dist * minf(dist, SPEED * delta * clampf(dist / 120.0, 0.5, 1.6))
		_step += delta * 14.0
		if absf(to.x) > 2.0:
			_face = signf(to.x)
	queue_redraw()


var _fetch = null


func _nearest_pickup():
	var best = null
	var best_d := 320.0
	for n in combat.entities.get_children():
		if n.get_script() == combat.PickupScript and not n.is_queued_for_deletion():
			var d: float = n.position.distance_to(player.position)
			if d < best_d:
				best_d = d
				best = n
	return best


## Прямокутник у «пікселях» спрайта з темним обводом; x віддзеркалюється, коли улюбленець дивиться ліворуч.
func _px(x: float, y: float, w: float, h: float, col: Color) -> void:
	var rx := x if _face > 0.0 else -x - w
	draw_rect(Rect2(rx - 1, y - 1, w + 2, h + 2), OUTLINE)
	_fills.append([Rect2(rx, y, w, h), col])


var _fills := []


func _draw() -> void:
	_fills.clear()
	var bob := sin(_step) * 1.5 if _moving else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match kind:
		"kit":
			_draw_cat(bob)
		"voron":
			_draw_raven()
		_:
			_draw_dog(bob)
	for f in _fills:
		draw_rect(f[0], f[1])


func _legs(x0: float, x1: float, y: float, col: Color) -> void:
	var a := 2.0 if _moving and sin(_step) > 0.0 else 0.0
	_px(x0, y - a, 3, 5, col)
	_px(x1, y - (2.0 - a if _moving else 0.0), 3, 5, col)


func _draw_dog(bob: float) -> void:
	var fur := Color(0.62, 0.45, 0.26)
	var dark := Color(0.42, 0.29, 0.16)
	draw_circle(Vector2(0, 8), 9.0, Color(0, 0, 0, 0.22))
	_legs(-8, 4, 2, dark)
	_px(-10, -6 + bob, 18, 8, fur)  # тулуб
	_px(6, -12 + bob, 8, 8, fur)  # голова
	_px(12, -8 + bob, 4, 4, Color(0.85, 0.72, 0.5))  # морда
	_px(6, -15 + bob, 3, 4, dark)  # вухо
	var wag := sin(_t * 12.0) * 2.0
	_px(-13, -10 + bob + wag, 3, 6, fur)  # хвіст
	_fills.append([Rect2((10.0 if _face > 0.0 else -12.0), -10 + bob, 2, 2), OUTLINE])  # око


func _draw_cat(bob: float) -> void:
	var fur := Color(0.55, 0.55, 0.6)
	var dark := Color(0.36, 0.36, 0.42)
	draw_circle(Vector2(0, 7), 7.0, Color(0, 0, 0, 0.22))
	_legs(-6, 3, 2, dark)
	_px(-8, -4 + bob, 14, 6, fur)
	_px(4, -10 + bob, 7, 7, fur)
	_px(4, -13 + bob, 2, 3, dark)
	_px(9, -13 + bob, 2, 3, dark)
	_px(-11, -12 + bob + sin(_t * 3.0) * 1.5, 3, 10, fur)  # хвіст трубою
	_fills.append([Rect2((8.0 if _face > 0.0 else -10.0), -8 + bob, 2, 2), Color(0.6, 0.9, 0.3)])


func _draw_raven() -> void:
	var body := Color(0.13, 0.12, 0.16)
	var wing := Color(0.22, 0.2, 0.28)
	var hover := -30.0 + sin(_t * 3.0) * 4.0
	draw_circle(Vector2(0, 6), 6.0, Color(0, 0, 0, 0.18))
	var flap := sin(_t * 16.0)
	_px(-6, hover, 12, 6, body)
	_px(5, hover - 3, 6, 6, body)
	_px(10, hover - 1, 4, 2, Color(0.75, 0.65, 0.3))  # дзьоб
	_px(-9, hover + 1, 4, 3, body)  # хвіст
	_px(-5, hover - (6.0 if flap > 0.0 else -4.0), 9, 4, wing)  # крило
	_fills.append([Rect2((7.0 if _face > 0.0 else -9.0), hover - 1, 2, 2), Color(0.9, 0.9, 0.9)])
