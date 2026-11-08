extends Node2D
## Спливаючий текст: числа шкоди, лікування тощо.

var text := ""
var color := Color.WHITE
var life := 0.8
var font_size := 24
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y -= 50.0 * delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var a := clampf(1.0 - (_t / life) * (_t / life), 0.0, 1.0)
	var w := 200.0
	draw_string_outline(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 5, Color(0, 0, 0, a))
	draw_string(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color(color, a))
