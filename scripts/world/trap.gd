extends Node2D
## Пастка пластуна (капкан: ловить першого ворога) або бочка пороху самопальника (вибухає за мить).
## Що буває, коли вона спрацює, вирішує механіка вміння, що її поставила (mech.trap_fire): тут — лише час
## життя, хто ступив у капкан, і вигляд.

var combat
var mech  # механіка, що поставила пастку (HeroMechanic)
var kind := "trap"  # trap / barrel
var damage := 30.0
var crit := false
var radius := 34.0
var blast := 150.0
var burn := 0.0
var life := 20.0
var fuse := 1.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if kind == "barrel":
		if _t >= fuse:
			_explode()
		queue_redraw()
		return
	if _t >= life:
		queue_free()
		return
	for e in combat.enemies_now():
		if not e.dead and global_position.distance_to(e.global_position) < radius + e.radius:
			if mech != null:
				mech.trap_fire(self, e)
			queue_free()
			return
	queue_redraw()


func _explode() -> void:
	if mech != null:
		mech.trap_fire(self, null)
	queue_free()


func _draw() -> void:
	if kind == "barrel":
		var k := clampf(_t / fuse, 0.0, 1.0)
		draw_circle(Vector2.ZERO, blast, Color(1.0, 0.45, 0.1, 0.08 + 0.12 * k))
		draw_arc(Vector2.ZERO, blast, 0.0, TAU, 40, Color(1.0, 0.5, 0.15, 0.6), 2.0)
		draw_circle(Vector2.ZERO, blast * k, Color(1.0, 0.5, 0.15, 0.12))
		draw_rect(Rect2(-12, -16, 24, 30), Color(0.45, 0.28, 0.12))
		draw_line(Vector2(-12, -8), Vector2(12, -8), Color(0.25, 0.25, 0.28), 2.0)
		draw_line(Vector2(-12, 6), Vector2(12, 6), Color(0.25, 0.25, 0.28), 2.0)
		draw_line(Vector2(0, -16), Vector2(4, -26), Color(0.3, 0.25, 0.2), 2.0)
		draw_circle(Vector2(4, -27), 3.0 + sin(_t * 30.0), Color(1.0, 0.8, 0.3))
		return
	# Капкан: зубчасті щелепи
	var a := 0.6 + 0.4 * sin(_t * 3.0)
	draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 20, Color(0.55, 0.55, 0.6, a), 3.0)
	for i in 8:
		var ang := i * TAU / 8.0
		var p := Vector2.from_angle(ang) * radius * 0.8
		draw_line(p, p * 0.6, Color(0.7, 0.7, 0.75, a), 2.5)
	draw_circle(Vector2.ZERO, 5.0, Color(0.4, 0.3, 0.2, a))
