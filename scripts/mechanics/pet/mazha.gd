extends "res://scripts/mechanics/pet_mechanic.gd"
## Чумацька мажа (божий дар «Чумацький віз»): не йде сама, її тягне герой за голоблі. Стоїть герой,
## стоїть і мажа. Рушив, і мажа котиться слідом рівно на довжину голобель та повертає за ним, як
## справжній причіп.

const CART_LEN := 46.0  # довжина голобель: на стільки мажа позаду героя
const CART_RISE := 26.0  # коли мажа «вище» за героя на екрані, вона стоїть далі, щоб не лізти йому на голову
const CART_TURN := 5.0  # рад/с: як швидко мажа розвертається, коли герой суне просто на неї
const HITCH := Vector2(0, 8)  # де герой тримає голоблі (від його середини)

var _hero_was := Vector2.ZERO  # де герой був минулого кадру


## Довжина голобель у напрямку dir (від героя до мажі). Спрайт героя високий, тож угору треба більше місця.
static func cart_len(dir: Vector2) -> float:
	return CART_LEN + CART_RISE * maxf(0.0, -dir.y)


func move(delta: float) -> void:
	var hitch: Vector2 = player.position + HITCH
	var back: Vector2 = p.position - hitch
	var dist := back.length()
	var step: Vector2 = player.position - _hero_was
	_hero_was = player.position
	if dist < 0.01 or dist > 400.0 or step.length() > 300.0:
		back = -player.facing if player.facing.length() > 0.01 else Vector2.LEFT  # герой перейшов далеко: мажа одразу за спиною
		dist = back.length()
	var dir := back / dist
	if step.length() > 0.05:
		# Герой суне просто на мажу: вона об'їжджає його збоку й стає позаду, а не їде задом наперед
		var want: Vector2 = -step.normalized()
		var ang := dir.angle_to(want)
		if absf(ang) > PI * 0.55:
			dir = dir.rotated((signf(ang) if absf(ang) < PI - 0.02 else 1.0) * minf(absf(ang), CART_TURN * delta))
	var old: Vector2 = p.position
	p.position = hitch + dir * cart_len(dir)
	var rolled: float = p.position.distance_to(old)
	p._moving = rolled > 0.15
	p._step += rolled * 0.16
	p._hitch = hitch - p.position  # кінець голобель у місцевих координатах мажі (для малювання)
	if absf(p._hitch.x) > 6.0:
		p._face = signf(p._hitch.x)
