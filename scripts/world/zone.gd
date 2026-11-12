extends Node2D
## Зони чарів волхвів і дух-помічник:
##   grad   — град у колі: удари раз на 0.3 с + холод
##   tuman  — туман: вороги всередині сповільнені й ослаблені
##   otruta — отруйна хмара знахаря: зараза з'їдає ворогів
##   spirit — дух мольфара: летить біля героя й стріляє вогниками

var combat
var kind := "grad"
var radius := 140.0
var duration := 3.0
var damage := 10.0  # за удар (grad, spirit) або за секунду (otruta)
## Зона вміння за даними (kind == "skill"): як часто б'є, який стан накладає, якого кольору
var tick := 0.5
var status := ""
var status_dur := 1.5
var color := Color(1.0, 0.8, 0.3)
var _dive := 0.0  # сокіл: скільки ще триває піке
var _dive_to := Vector2.ZERO
var _t := 0.0
var _tick := 0.0


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _t >= duration:
		queue_free()
		return
	match kind:
		"spirit":
			var p = combat.player
			var target: Vector2 = p.global_position + Vector2(cos(_t * 2.0) * 50.0, -60.0 + sin(_t * 3.0) * 10.0)
			global_position = global_position.lerp(target, minf(1.0, delta * 6.0))
			if _tick <= 0.0:
				_tick = 0.8
				var e = combat.nearest_enemy(global_position, 520.0)
				if e:
					combat.spawn_spark(global_position, (e.global_position - global_position).normalized(), damage, false)
		"falcon":
			# Сокіл кружляє над героєм, а на удар пірнає до ворога
			var hero = combat.player
			var home: Vector2 = hero.global_position + Vector2(cos(_t * 2.4) * 70.0, -80.0 + sin(_t * 4.8) * 14.0)
			if _dive > 0.0:
				_dive -= delta
				global_position = global_position.lerp(_dive_to, minf(1.0, delta * 14.0))
			else:
				global_position = global_position.lerp(home, minf(1.0, delta * 5.0))
			if _tick <= 0.0:
				_tick = tick
				var prey = combat.nearest_enemy(hero.global_position, 560.0)
				if prey:
					_dive = 0.25
					_dive_to = prey.global_position + Vector2(0, -10)
					hero.hit(prey, damage, Vector2.ZERO, false)
					if status != "" and not prey.dead:
						hero.Status.apply(prey, status, status_dur)
					combat.fx.burst(prey.global_position, color, 6, 160, 4, 0.25)
		_:
			if _tick <= 0.0:
				_tick = 0.3 if kind == "grad" else (tick if kind == "skill" else 0.5)
				for e in combat.enemies_now():
					if e.dead or global_position.distance_to(e.global_position) > radius + e.radius:
						continue
					match kind:
						"grad":
							combat.player.hit(e, damage, Vector2.ZERO, false)
							if not e.dead:
								combat.player.Status.apply(e, "chill", 1.5)
						"tuman":
							combat.player.Status.apply(e, "chill", 1.0)
							combat.player.Status.apply(e, "weak", 1.0)
						"otruta":
							combat.player.Status.apply(e, "plague", 2.0, damage)
						"skill":
							if damage > 0.0:
								combat.player.hit(e, damage, Vector2.ZERO, false)
							if status != "" and not e.dead:
								combat.player.Status.apply(e, status, status_dur, damage * 0.2 if status in ["bleed", "burn", "plague"] else 0.0)
				if kind == "grad":
					for i in 4:
						combat.fx.burst(global_position + Vector2.from_angle(randf() * TAU) * randf() * radius, Color(0.85, 0.95, 1.0), 3, 120, 3, 0.25)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((duration - _t) / 0.5, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
	match kind:
		"spirit":
			draw_circle(Vector2.ZERO, 14.0, Color(0.5, 0.85, 1.0, 0.25 * fade))
			draw_circle(Vector2.ZERO, 7.0, Color(0.75, 0.95, 1.0, 0.85 * fade))
			draw_circle(Vector2(-3, -2), 1.8, Color(0.1, 0.2, 0.3, fade))
			draw_circle(Vector2(3, -2), 1.8, Color(0.1, 0.2, 0.3, fade))
		"grad":
			draw_circle(Vector2.ZERO, radius, Color(0.75, 0.88, 1.0, 0.16 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.85, 0.95, 1.0, 0.5 * fade), 2.0)
		"tuman":
			for i in 7:
				var a := _t * 0.4 + i * TAU / 7.0
				draw_circle(Vector2.from_angle(a) * radius * 0.5, radius * 0.55, Color(0.75, 0.78, 0.82, 0.08 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.8, 0.82, 0.85, 0.35 * fade), 2.0)
		"falcon":
			# тулуб і крила, що б'ють; у піке крила складені
			var flap: float = 0.0 if _dive > 0.0 else sin(_t * 18.0) * 7.0
			var body := Color(0.55, 0.42, 0.28, fade)
			draw_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(-16, -4 - flap), Vector2(-9, 3)]), PackedColorArray([body, body, body]))
			draw_polygon(PackedVector2Array([Vector2(3, 0), Vector2(16, -4 - flap), Vector2(9, 3)]), PackedColorArray([body, body, body]))
			draw_circle(Vector2.ZERO, 5.0, Color(0.7, 0.58, 0.4, fade))
			draw_circle(Vector2(0, -5), 3.0, Color(0.85, 0.78, 0.62, fade))
			draw_line(Vector2(0, -5), Vector2(0, -9), Color(0.95, 0.75, 0.2, fade), 2.0)
		"skill":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.14 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.55 * fade), 2.0)
		"otruta":
			for i in 5:
				var a := _t * 0.8 + i * TAU / 5.0
				draw_circle(Vector2.from_angle(a) * radius * 0.4, radius * 0.5, Color(0.45, 0.75, 0.15, 0.12 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.55, 0.9, 0.2, 0.5 * fade), 2.0)
