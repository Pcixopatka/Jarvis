extends Node2D
## Снаряд нечисті: плювок болотяника або вогонь Змія.

var main
var velocity := Vector2.ZERO
var damage := 10.0
var color := Color.GREEN
var radius := 9.0
var life := 3.5


func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
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
	draw_circle(back * radius * 1.2, radius * 0.6, Color(color, 0.35))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.5, color.lightened(0.5))
