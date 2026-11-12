extends "res://scripts/mechanics/mechanic.gd"
## Хуртовина (Карачун, Хала): вітер зносить героя, доки дме. Іти можна лише проти нього.

## Скільки ще дме, с
var wind_t := 0.0
## Куди дме
var wind_dir := Vector2.ZERO


## Здіймає вітер у напрямку dir на dur секунд; бос тим часом стоїть.
func start_wind(dir: Vector2, dur: float) -> void:
	wind_dir = dir
	wind_t = dur
	e.cast_time = wind_t
	e.ability_timer = wind_t + 1.5


func tick(delta: float) -> void:
	if wind_t > 0.0:
		wind_t -= delta
		var pl = combat.player
		if pl != null and pl.alive:
			var wind: float = minf(200.0, pl.speed * Status.speed_mult(pl) * 0.7)
			if pl.push.length() < wind:
				pl.push = wind_dir * wind
			if randf() < delta * 10.0:
				combat.fx.burst(pl.global_position - wind_dir * 200.0, Color(0.95, 0.97, 1.0), 6, 220, 4, 0.5)
