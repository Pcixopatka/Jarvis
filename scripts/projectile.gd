extends Node2D
## Снаряд: плювок болотяника, вогонь Змія або куля козацького самопала.

var main
var velocity := Vector2.ZERO
var damage := 10.0
var color := Color.GREEN
var radius := 9.0
var life := 3.5
var friendly := false  # true — куля козака: пробиває ворогів наскрізь
var crit := false
var _hit_ids := []


func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if friendly:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead or e.get_instance_id() in _hit_ids:
				continue
			if global_position.distance_to(e.global_position) < radius + e.radius:
				_hit_ids.append(e.get_instance_id())
				main.player.hit(e, damage, velocity.normalized() * 160.0, crit)
	else:
		var p = main.player
		if p.alive and global_position.distance_to(p.global_position) < radius + p.radius:
			p.take_damage(damage)
			queue_free()
			return
	if life <= 0.0 or not main.ARENA.has_point(global_position):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var back := -velocity.normalized()
	if friendly:
		draw_line(Vector2.ZERO, back * 40.0, Color(1.0, 0.9, 0.6, 0.5), radius)
		draw_circle(Vector2.ZERO, radius, Color(0.25, 0.25, 0.28))
		draw_circle(Vector2(-1, -1), radius * 0.4, Color(0.8, 0.8, 0.85))
		return
	draw_circle(back * radius * 1.2, radius * 0.6, Color(color, 0.35))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.5, color.lightened(0.5))
