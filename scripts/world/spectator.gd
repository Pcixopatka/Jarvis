extends Node2D
## Глядач на майдані: стоїть за огорожею, дивиться на герць і підстрибує, коли хтось влучив.

const Gfx := preload("res://scripts/world/gfx.gd")

var sheet := "comp_dzhura"
var look := Vector2.DOWN
var phase := randf() * TAU
var cheer := 0.0


func _process(delta: float) -> void:
	phase += delta
	cheer = maxf(0.0, cheer - delta)
	queue_redraw()


func _draw() -> void:
	var hop := absf(sin(phase * 9.0)) * 7.0 if cheer > 0.0 else 0.0
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not Gfx.has(sheet):
		return
	var frame := Gfx.IDLE
	if cheer > 0.0 and int(phase * 5.0) % 2 == 0:
		frame = Gfx.ATK0  # рука вгору: «Слава!»
	Gfx.draw(self, sheet, look, frame, Vector2(-24, -30 - hop))
