extends Node2D
## Сенсорна кнопка дії з підтримкою мультитачу та індикатором перезарядки.

signal triggered

var radius := 70.0
var label := ""
var color := Color(0.8, 0.2, 0.2)
var held := false
var cooldown_ratio := 0.0  # 0 — готово, 1 — щойно використано
var icon: Texture2D = null  # значок вміння (піксельний); підпис тоді дрібніший, під ним
var _touch_index := -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_touch_index = -1
		held = false
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and event.position.distance_to(global_position) <= radius * 1.2:
				_touch_index = event.index
				held = true
				triggered.emit()
				get_viewport().set_input_as_handled()
				queue_redraw()
		elif event.index == _touch_index:
			_touch_index = -1
			held = false
			queue_redraw()


func set_cooldown(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if not is_equal_approx(ratio, cooldown_ratio):
		cooldown_ratio = ratio
		queue_redraw()


func _draw() -> void:
	var ready := cooldown_ratio <= 0.0
	var base := color if ready else color.darkened(0.55)
	draw_circle(Vector2.ZERO, radius, Color(base, 0.75 if held else 0.55))
	if not ready:
		# Затемнений сектор перезарядки (товста дуга замість полігона)
		var start := -PI / 2.0
		draw_arc(Vector2.ZERO, radius * 0.5, start, start + TAU * cooldown_ratio, 32, Color(0, 0, 0, 0.45), radius)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8 if ready else 0.35), 4.0)
	var font := ThemeDB.fallback_font
	var w := radius * 2.0
	if icon != null:
		var isz := radius * 1.15
		var tint := Color.WHITE if ready else Color(0.55, 0.55, 0.55)
		draw_texture_rect(icon, Rect2(Vector2(-isz / 2.0, -isz / 2.0 - radius * 0.12), Vector2(isz, isz)), false, tint)
		var fs2 := int(radius * 0.24)
		draw_string_outline(font, Vector2(-radius, radius * 0.78), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs2, 3, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(-radius, radius * 0.78), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs2, Color.WHITE)
		return
	var fs := int(radius * 0.36)
	draw_string_outline(font, Vector2(-radius, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-radius, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color.WHITE)
