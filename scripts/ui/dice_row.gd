extends Control
## Ряд гральних кісток: малює значення 1–6 цяточками. Порожній ряд тримає місце під один кубик.
## Нові кості (від roll_from) «котяться»: кожна по черзі миготить випадковими гранями, підстрибує й лягає.

const D := 56.0  # сторона кубика
const GAP := 10.0
const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}

const ROLL := 0.42  # секунд котиться одна кість
const STAGGER := 0.34  # затримка між сусідніми кістками

var values: Array = []
var face := Color(0.95, 0.91, 0.8)
var pip := Color(0.15, 0.1, 0.08)
var roll_from := 9999  # з якої кості починається анімація (9999 — усі вже лежать)
var _t := 0.0
var _sounded := -1


func setup(v: Array, face_col: Color = Color(0.95, 0.91, 0.8), animate_from: int = 9999):
	values = v
	face = face_col
	roll_from = animate_from
	custom_minimum_size = Vector2(maxi(1, v.size()) * (D + GAP), D + 14.0)
	set_process(roll_from < v.size())
	return self


## Скільки триватиме анімація для заданої кількості нових кісток.
static func roll_time(new_dice: int) -> float:
	return 0.0 if new_dice <= 0 else ROLL + STAGGER * (new_dice - 1)


func _process(delta: float) -> void:
	_t += delta
	# Стукіт кожної нової кості, щойно вона починає котитись
	var started := roll_from + int(_t / STAGGER)
	if started > _sounded and started < values.size():
		_sounded = started
		Audio.play("dice", 0.2, -2.0)
	if _t > roll_time(values.size() - roll_from) + 0.1:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for i in values.size():
		var shown := int(values[i])
		var lift := 0.0
		var alpha := 1.0
		if i >= roll_from:
			var local := _t - (i - roll_from) * STAGGER
			if local < 0.0:
				continue  # ця кість іще в руці
			if local < ROLL:
				shown = 1 + (int(local * 22.0) + i * 3) % 6  # грані миготять, поки котиться
				lift = -absf(sin(local / ROLL * PI * 2.0)) * 10.0 * (1.0 - local / ROLL)
				alpha = minf(1.0, local * 12.0)
		var r := Rect2(i * (D + GAP), 12.0 + lift, D, D)
		draw_rect(Rect2(Vector2(r.position.x + 3, 16.0), r.size), Color(0, 0, 0, 0.45 * alpha))
		draw_rect(r, Color(face, alpha))
		draw_rect(r, Color(pip, alpha), false, 3.0)
		for p in PIPS.get(shown, []):
			draw_circle(r.position + Vector2(p.x, p.y) * D, D * 0.085, Color(pip, alpha))
