extends Node2D
## Попередження про удар боса: червона зона на землі заповнюється, а потім б'є всіх усередині.
## Форми: "circle" (коло), "cone" (конус вогню), "line" (ривок).

var combat
var source  # хто атакує; якщо загинув — атака скасовується
var shape := "circle"
var radius := 120.0
var dir := Vector2.RIGHT
var length := 300.0
var width := 80.0
var half_angle := 0.45
var duration := 0.9
var damage := 20.0
var color := Color(1.0, 0.25, 0.1)
var on_fire: Callable
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if source != null and (not is_instance_valid(source) or source.dead):
		queue_free()
		return
	if _t >= duration:
		_fire()
		queue_free()
		return
	queue_redraw()


func contains(p: Vector2) -> bool:
	var l := p - global_position
	match shape:
		"cone":
			return l.length() <= length and absf(dir.angle_to(l)) <= half_angle
		"line":
			var along := l.dot(dir)
			return along >= -20.0 and along <= length and absf(l.dot(dir.orthogonal())) <= width / 2.0
	return l.length() <= radius


func _fire() -> void:
	for a in combat.allies():
		if contains(a.global_position):
			a.take_damage(damage, null)
	combat.shake(9.0)
	Audio.play("boom", 0.1, -4.0)
	match shape:
		"cone":
			for i in 5:
				combat.fx.burst(global_position + dir.rotated(randf_range(-half_angle, half_angle)) * randf_range(60, length), Color(1.0, 0.55, 0.1), 8, 180, 7, 0.6, -120)
		"line":
			for i in 6:
				combat.fx.burst(global_position + dir * length * i / 5.0, Color(0.7, 0.65, 0.6), 5, 160, 6, 0.5)
		_:
			combat.fx.ring(global_position, Color(0.75, 0.6, 0.45), 24, radius * 2.0, 8, 0.4)
	if on_fire.is_valid():
		on_fire.call()


func _poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"cone":
			pts.append(Vector2.ZERO)
			for i in 13:
				pts.append(dir.rotated(lerpf(-half_angle, half_angle, i / 12.0)) * length)
		"line":
			var o := dir.orthogonal() * width / 2.0
			pts = PackedVector2Array([o - dir * 20.0, o + dir * length, -o + dir * length, -o - dir * 20.0])
		_:
			for i in 32:
				pts.append(Vector2.from_angle(TAU * i / 32.0) * radius)
	return pts


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var pts := _poly()
	draw_colored_polygon(pts, Color(color, 0.12 + 0.12 * k))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color, 0.85), 3.0, true)
	# Внутрішня зона, що росте до моменту удару
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * k)
	if k > 0.05:
		draw_colored_polygon(inner, Color(color, 0.3))
