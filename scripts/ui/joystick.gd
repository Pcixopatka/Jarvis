extends Node2D
## Плаваючий віртуальний джойстик: торкніться будь-де в лівій частині екрана.

var vector := Vector2.ZERO
var rest_pos := Vector2(190, 530)
var base_radius := 110.0
var full_at := 0.5  # частка радіуса, на якій швидкість уже повна
const DEAD_ZONE := 0.15  # частка радіуса, менший хід пальця не рухає героя
var knob_radius := 48.0
var _touch_index := -1
var _base_pos := Vector2.ZERO
var _knob_pos := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if _touch_index != -1:
			release()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and event.position.x < get_viewport_rect().size.x * 0.45:
			_touch_index = event.index
			_base_pos = event.position
			_knob_pos = event.position
			vector = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var d: Vector2 = event.position - _base_pos
		d = d.limit_length(base_radius)
		_knob_pos = _base_pos + d
		if d.length() < base_radius * DEAD_ZONE:
			vector = Vector2.ZERO
		else:
			vector = (d / (base_radius * full_at)).limit_length(1.0)
		queue_redraw()


## Чи тримає гравець палець на джойстику (тоді автобій героя не веде).
func touched() -> bool:
	return _touch_index != -1


func release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var active := _touch_index != -1
	var c := _base_pos if active else rest_pos
	var k := _knob_pos if active else rest_pos
	draw_circle(c, base_radius, Color(1, 1, 1, 0.12 if active else 0.07))
	draw_arc(c, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(k, knob_radius, Color(1, 1, 1, 0.4 if active else 0.22))
