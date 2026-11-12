extends "res://scripts/mechanics/power_mechanic.gd"
## Громовий удар: завершальний удар серії й повний заряджений удар зблизька гримлять на всі боки —
## {pct} шкоди всім у колі {radius}, нечисть ціпеніє на {stun} с. Не частіше ніж раз на 0,8 с.

var cd := 0.0  # скільки ще до наступного грому


func tick(delta: float) -> void:
	cd = maxf(0.0, cd - delta)


func on_finisher() -> void:
	if not worn() or cd > 0.0:
		return
	var h: Dictionary = P
	cd = 0.8
	var r: float = float(h["radius"])
	p._u_proc = true
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() > r + e.radius:
			continue
		var rl := roll(float(h["pct"]))
		hit(e, rl[0], to.normalized() * 520.0, rl[1])
		if not e.dead and not e.is_boss:
			e.stun = maxf(e.stun, float(h["stun"]))
	p._u_proc = false
	combat.fx.ring(p.global_position, Color(1.0, 0.85, 0.3), 36, r, 7, 0.4)
	combat.shake(7.0)
	Audio.play("clash", 0.1, -4.0)
