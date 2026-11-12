extends Node2D
## Пастка пластуна (капкан: ловить першого ворога) або бочка пороху самопальника (вибухає за мить).

var combat
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
			combat.player.hit(e, damage, Vector2.ZERO, crit)
			if not e.dead:
				if not e.is_boss:
					e.stun = maxf(e.stun, 1.6)
				combat.player.Status.apply(e, "bleed", 3.0, damage * 0.1)
			combat.fx.burst(global_position, Color(0.75, 0.75, 0.8), 10, 160, 4, 0.3)
			Audio.play("hit", 0.1)
			queue_free()
			return
	queue_redraw()


func _explode() -> void:
	for e in combat.enemies_now():
		if e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= blast + e.radius:
			combat.player.hit(e, damage, to.normalized() * 420.0, crit)
			if not e.dead and burn > 0.0:
				combat.player.Status.apply(e, "burn", 3.0, burn)
	combat.fx.ring(global_position, Color(1.0, 0.55, 0.15), 36, blast * 2.0, 8, 0.4)
	combat.fx.burst(global_position, Color(1.0, 0.5, 0.15), 30, 340, 8, 0.6, -80)
	combat.fx.burst(global_position, Color(0.3, 0.3, 0.3, 0.8), 20, 200, 10, 1.0, -60)
	combat.spawn_fx("fire", global_position, blast / 26.0, 0.0, Color.WHITE, 12.0)
	combat.shake(10.0)
	Audio.play("boom", 0.05, 0.0)
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
