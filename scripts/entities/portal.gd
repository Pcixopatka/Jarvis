extends Node2D
## Прохід далі в печері або вихід назовні.

var label := "Далі"
var phase := 0.0


func _process(delta: float) -> void:
	phase += delta * 3.0
	queue_redraw()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(phase)
	draw_circle(Vector2.ZERO, 70.0 + glow * 10.0, Color(1.0, 0.8, 0.3, 0.12))
	draw_rect(Rect2(-36, -70, 72, 80), Color(0.15, 0.1, 0.08))
	draw_circle(Vector2(0, -70), 36.0, Color(0.15, 0.1, 0.08))
	draw_rect(Rect2(-26, -64, 52, 70), Color(1.0, 0.75, 0.3, 0.35 + 0.3 * glow))
	draw_circle(Vector2(0, -64), 26.0, Color(1.0, 0.75, 0.3, 0.35 + 0.3 * glow))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-100, 40), label, HORIZONTAL_ALIGNMENT_CENTER, 200, 24, 6, Color.BLACK)
	draw_string(font, Vector2(-100, 40), label, HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(1, 0.9, 0.6))
