class_name Projectile
extends Node2D
## Снаряд: плювок болотяника, вогонь Змія або куля козацького самопала.

var combat: Combat
var velocity := Vector2.ZERO
var damage := 10.0
var color := Color.GREEN
var radius := 9.0
var life := 3.5
var friendly := false  # true — куля козака: пробиває ворогів наскрізь
var crit := false
var source = null  # ворог, що вистрілив (щоб удар міг накласти стан)
var spell := false  # іскра чи вогняна куля волхва (не пробиває, своє світіння)
var explode_radius := 0.0  # > 0 — вибухає при першому влучанні або в кінці польоту
var burn_dps := 0.0
var stun_all := false  # повний заряд волхва приголомшує
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
				if explode_radius > 0.0:
					_explode()
					return
				combat.player.hit(e, damage, velocity.normalized() * 160.0, crit)
				if spell:
					combat.fx.burst(global_position, color, 6, 140, 3, 0.25)
					queue_free()
					return
	else:
		for p in combat.allies():
			if global_position.distance_to(p.global_position) < radius + p.radius:
				if p.take_damage(damage) == true and source != null and is_instance_valid(source):
					source.on_hit(p)
				queue_free()
				return
	if life <= 0.0 or not combat.arena.has_point(global_position):
		if explode_radius > 0.0 and friendly:
			_explode()
			return
		queue_free()
		return
	queue_redraw()


## Вогняна куля: шкода всім у колі, підпал.
func _explode() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= explode_radius + e.radius:
			combat.player.hit(e, damage, to.normalized() * 260.0, crit)
			if not e.dead and burn_dps > 0.0:
				combat.player.Status.apply(e, "burn", 3.0, burn_dps)
			if not e.dead and stun_all and not e.is_boss:
				e.stun = maxf(e.stun, 1.2)
	combat.fx.ring(global_position, Color(1.0, 0.55, 0.15), 30, explode_radius * 2.0, 6, 0.35)
	combat.fx.burst(global_position, Color(1.0, 0.6, 0.2), 20, 260, 6, 0.5, -60)
	combat.shake(5.0)
	Audio.play("boom", 0.1, -6.0)
	queue_free()


func _draw() -> void:
	var back := -velocity.normalized()
	if spell:
		draw_line(Vector2.ZERO, back * radius * 3.0, Color(color, 0.45), radius * 1.2)
		draw_circle(Vector2.ZERO, radius * 1.6, Color(color, 0.25))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 0.9))
		return
	if friendly:
		draw_line(Vector2.ZERO, back * 40.0, Color(1.0, 0.9, 0.6, 0.5), radius)
		draw_circle(Vector2.ZERO, radius, Color(0.25, 0.25, 0.28))
		draw_circle(Vector2(-1, -1), radius * 0.4, Color(0.8, 0.8, 0.85))
		return
	draw_circle(back * radius * 1.2, radius * 0.6, Color(color, 0.35))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.5, color.lightened(0.5))
