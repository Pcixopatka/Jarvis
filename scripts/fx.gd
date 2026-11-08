extends Node2D
## Легка система частинок: іскри від ударів, хмарки смерті, блиск монет, пил від перекиду.
## Один вузол на всю локацію — частинки зберігаються масивом і малюються колами.

const MAX_PARTS := 500

# Кожна частинка: [позиція, швидкість, залишок життя, повне життя, колір, розмір, гравітація]
var parts := []


func burst(pos: Vector2, color: Color, count: int, speed: float, size: float, life: float, gravity: float = 0.0, dir: float = 0.0, spread: float = TAU) -> void:
	for i in count:
		if parts.size() >= MAX_PARTS:
			parts.pop_front()
		var a := dir + randf_range(-spread / 2.0, spread / 2.0)
		var v := Vector2.from_angle(a) * speed * randf_range(0.35, 1.0)
		var l := life * randf_range(0.6, 1.0)
		parts.append([pos, v, l, l, color, size * randf_range(0.6, 1.2), gravity])


## Кільце, що розлітається (рівень, вибух).
func ring(pos: Vector2, color: Color, count: int, speed: float, size: float, life: float) -> void:
	for i in count:
		var v := Vector2.from_angle(TAU * i / count) * speed
		parts.append([pos, v, life, life, color, size, 0.0])


func clear() -> void:
	parts.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if parts.is_empty():
		return
	var alive := []
	for p in parts:
		p[2] -= delta
		if p[2] <= 0.0:
			continue
		p[1] = p[1] * (1.0 - 3.0 * delta) + Vector2(0, p[6] * delta)
		p[0] += p[1] * delta
		alive.append(p)
	parts = alive
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var t: float = p[2] / p[3]
		var c: Color = p[4]
		draw_circle(p[0], p[5] * (0.4 + 0.6 * t), Color(c, c.a * t))
