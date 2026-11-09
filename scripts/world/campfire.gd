extends Node2D
## Вогнище: анімоване полум'я з листа objects.png і тепле світло довкола (сильніше в темряві).

const OBJECTS := preload("res://assets/gfx/cc0/objects.png")
const FRAMES := [4, 5, 6, 7, 8, 9]  # стовпці рядка 3: кадри полум'я

var light: PointLight2D
var t := randf() * 3.0
var darkness := 0.0  # 0 — день, 1 — ніч


func setup(tex: Texture2D) -> void:
	light = PointLight2D.new()
	light.texture = tex
	light.texture_scale = 3.2
	light.color = Color(1.0, 0.7, 0.35)
	light.energy = 0.0
	light.position = Vector2(0, -12)
	add_child(light)


func _process(delta: float) -> void:
	t += delta
	if light:
		light.energy = darkness * (0.6 + sin(t * 11.0) * 0.05)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(-16, 2), Vector2(14, -4), Color(0.35, 0.22, 0.12), 6.0)
	draw_line(Vector2(-14, -4), Vector2(16, 2), Color(0.42, 0.27, 0.14), 6.0)
	var f: int = FRAMES[int(t * 9.0) % FRAMES.size()]
	draw_texture_rect_region(OBJECTS, Rect2(-24, -46, 48, 48), Rect2(f * 16, 48, 16, 16))
