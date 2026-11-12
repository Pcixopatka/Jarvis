extends Node2D
## Улюбленець, що ходить за героєм у бою: пес, кіт або ворон (див. Pets.FOLLOWERS). Лише для ока:
## у бійку не лізе, шкоди не завдає й не отримує. Пес ще й бігає до здобичі, що лежить поруч.
## Чумацька мажа не йде сама: герой тягне її за голоблі (_pull_cart).
## Малюється кодом із дрібних прямокутників, як піксельний спрайт.

const OUTLINE := Color(0.106, 0.078, 0.125)
const SPEED := 420.0
const CART_LEN := 46.0  # довжина голобель: на стільки мажа позаду героя
const CART_RISE := 26.0  # коли мажа «вище» за героя на екрані, вона стоїть далі, щоб не лізти йому на голову
const CART_TURN := 5.0  # рад/с: як швидко мажа розвертається, коли герой суне просто на неї
const HITCH := Vector2(0, 8)  # де герой тримає голоблі (від його середини)

var combat
var player
var kind := "pes"
var _face := 1.0  # 1 — дивиться праворуч, -1 — ліворуч
var _step := 0.0
var _moving := false
var _fetch_t := 0.0
var _goal := Vector2.ZERO
var _t := 0.0
var _hero_was := Vector2.ZERO  # де герой був минулого кадру (для мажі)
var _hitch := Vector2.ZERO  # кінець голобель у місцевих координатах мажі


func setup(combat_node, hero, pet_kind: String) -> void:
	combat = combat_node
	player = hero
	kind = pet_kind
	z_index = 0


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	if kind == "mazha":
		_pull_cart(delta)
		queue_redraw()
		return
	# З мажею за спиною улюбленці тримаються збоку й нижче, щоб не лізти під голоблі
	var carted: bool = str(player.divine.get("cart", "")) == "mazha"
	var home: Vector2 = player.position - player.facing * (22.0 if carted else 46.0) + Vector2(0, 42 if carted else 22)
	if kind == "voron":
		home = player.position + Vector2(-player.facing.x * 30.0, -8.0)
	elif kind == "khovanets":
		home = player.position + Vector2((1.0 if player.facing.x >= 0.0 else -1.0) * 34.0, 30.0) if carted else player.position - player.facing * 30.0 + Vector2(34.0, 26.0)
	elif kind == "skakun":
		home = player.position - player.facing * 44.0 + Vector2(-40.0, 18.0)
	_goal = home
	if kind in ["pes", "khovanets"]:
		_fetch_t -= delta
		if _fetch_t <= 0.0:
			_fetch_t = 0.3
			_fetch = _nearest_pickup()
		if _fetch != null and is_instance_valid(_fetch) and not _fetch.is_queued_for_deletion() and _can_fetch(_fetch):
			_goal = _fetch.position
		else:
			_fetch = null  # ціль зникла або її вже не взяти: одразу назад до героя
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


## Довжина голобель у напрямку dir (від героя до мажі). Спрайт героя високий, тож угору треба більше місця.
static func cart_len(dir: Vector2) -> float:
	return CART_LEN + CART_RISE * maxf(0.0, -dir.y)


## Мажу тягне герой: вона причеплена голоблями до його пояса й сама не їде. Стоїть герой, стоїть і мажа.
## Рушив, і мажа котиться слідом рівно на довжину голобель та повертає за ним, як справжній причіп.
func _pull_cart(delta: float) -> void:
	var hitch: Vector2 = player.position + HITCH
	var back: Vector2 = position - hitch
	var dist := back.length()
	var step: Vector2 = player.position - _hero_was
	_hero_was = player.position
	if dist < 0.01 or dist > 400.0 or step.length() > 300.0:
		back = -player.facing if player.facing.length() > 0.01 else Vector2.LEFT  # герой перейшов далеко: мажа одразу за спиною
		dist = back.length()
	var dir := back / dist
	if step.length() > 0.05:
		# Герой суне просто на мажу: вона об'їжджає його збоку й стає позаду, а не їде задом наперед
		var want: Vector2 = -step.normalized()
		var ang := dir.angle_to(want)
		if absf(ang) > PI * 0.55:
			dir = dir.rotated((signf(ang) if absf(ang) < PI - 0.02 else 1.0) * minf(absf(ang), CART_TURN * delta))
	var old := position
	position = hitch + dir * cart_len(dir)
	var rolled := position.distance_to(old)
	_moving = rolled > 0.15
	_step += rolled * 0.16
	_hitch = hitch - position
	if absf(_hitch.x) > 6.0:
		_face = signf(_hitch.x)


func _nearest_pickup():
	var best = null
	var best_d := 320.0
	for n in combat.entities.get_children():
		if n.get_script() == combat.PickupScript and not n.is_queued_for_deletion() and _can_fetch(n):
			var d: float = n.position.distance_to(player.position)
			if d < best_d:
				best_d = d
				best = n
	return best


## Чи варто бігти до здобичі: герой може її зараз узяти (є місце, фільтр бере) і її не викинули вручну.
## До решти улюбленець не біжить, щоб не стояти над нею без кінця.
func _can_fetch(n) -> bool:
	return not n.manual and combat.loot_block(n.kind, n.item, n.manual) == ""


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
		"mazha":
			_draw_cart()
		"khovanets":
			_draw_khovanets(bob)
		"skakun":
			_draw_horse(bob)
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


## Чумацька мажа: дощатий кузов із клунками на двох колесах і дишель до героя.
func _draw_cart() -> void:
	var wood := Color(0.6, 0.4, 0.22)
	var dark := Color(0.38, 0.25, 0.14)
	draw_circle(Vector2(0, 9), 13.0, Color(0, 0, 0, 0.22))
	# Голоблі від передка мажі до рук героя й поперечка, за яку він тягне
	var front := Vector2(11.0 * _face, -3.0)
	var side := Vector2(0, 3) if absf(_hitch.x) >= absf(_hitch.y) else Vector2(3, 0)
	for off in [-side, side]:
		draw_line(front + off, _hitch + off, OUTLINE, 4.0)
	draw_line(_hitch - side * 1.8, _hitch + side * 1.8, OUTLINE, 5.0)
	for off in [-side, side]:
		draw_line(front + off, _hitch + off, dark, 2.0)
	draw_line(_hitch - side * 1.6, _hitch + side * 1.6, wood, 3.0)
	_px(-13, -8, 24, 10, wood)  # кузов
	_px(-13, -8, 24, 2, Color(0.75, 0.55, 0.32))
	_px(-9, -15, 9, 7, Color(0.92, 0.88, 0.78))  # клунок
	_px(-1, -13, 8, 5, Color(0.8, 0.74, 0.6))
	var spin := int(_step) % 2 if _moving else 0
	for wx in [-10.0, 5.0]:
		_px(wx, 1, 7, 7, Color(0.28, 0.2, 0.14))
		_px(wx + 2 + spin, 3, 2, 2, Color(0.9, 0.72, 0.25))


## Хованець: рудий дух із торбою за плечима.
func _draw_khovanets(bob: float) -> void:
	var fur := Color(0.8, 0.43, 0.18)
	var dark := Color(0.55, 0.28, 0.1)
	draw_circle(Vector2(0, 8), 7.0, Color(0, 0, 0, 0.22))
	_legs(-5, 2, 2, dark)
	_px(-6, -6 + bob, 12, 9, fur)  # тулуб
	_px(-5, -14 + bob, 10, 8, fur)  # голова
	_px(-5, -17 + bob, 2, 3, dark)  # вуха
	_px(3, -17 + bob, 2, 3, dark)
	_px(-10, -8 + bob, 5, 7, Color(0.6, 0.45, 0.25))  # торба
	_fills.append([Rect2((1.0 if _face > 0.0 else -3.0), -11 + bob, 2, 2), Color(1.0, 0.95, 0.5)])
	_fills.append([Rect2((-3.0 if _face > 0.0 else 1.0), -11 + bob, 2, 2), Color(1.0, 0.95, 0.5)])


## Вороний скакун: кінь на повний зріст, що біжить поруч із героєм.
func _draw_horse(bob: float) -> void:
	var coat := Color(0.2, 0.18, 0.23)
	var mane := Color(0.38, 0.34, 0.44)
	draw_circle(Vector2(0, 12), 15.0, Color(0, 0, 0, 0.22))
	var a := 3.0 if _moving and sin(_step) > 0.0 else 0.0
	_px(-13, 2 - a, 4, 11, coat)  # ноги
	_px(-6, 2 - (3.0 - a if _moving else 0.0), 4, 11, coat)
	_px(6, 2 - (3.0 - a if _moving else 0.0), 4, 11, coat)
	_px(12, 2 - a, 4, 11, coat)
	_px(-15, -10 + bob, 32, 13, coat)  # тулуб
	_px(13, -22 + bob, 8, 14, coat)  # шия
	_px(15, -27 + bob, 13, 8, coat)  # голова
	_px(15, -30 + bob, 3, 4, coat)  # вухо
	_px(10, -22 + bob, 4, 12, mane)  # грива
	_px(-19, -9 + bob + sin(_t * 6.0) * 1.5, 4, 12, mane)  # хвіст
	_px(-4, -11 + bob, 10, 3, Color(0.68, 0.14, 0.24))  # попона
	_fills.append([Rect2((22.0 if _face > 0.0 else -24.0), -25 + bob, 2, 2), Color(1.0, 0.95, 0.75)])
