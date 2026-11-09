extends Node2D
## Анімований ефект вміння з листа fx_<kind>.png (64×64 × 6 кадрів, див. tools/pixel/effects.py).
## Програється один раз і зникає.

const Gfx := preload("res://scripts/world/gfx.gd")
const FRAME := 64
const FRAMES := 6

var kind := "slash"
var fps := 16.0
var tint := Color.WHITE
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t * fps >= FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var tex := Gfx.sheet("fx_" + kind)
	if tex == null:
		return
	var f := clampi(int(_t * fps), 0, FRAMES - 1)
	draw_texture_rect_region(tex, Rect2(-FRAME / 2.0, -FRAME / 2.0, FRAME, FRAME), Rect2(f * FRAME, 0, FRAME, FRAME), tint)
