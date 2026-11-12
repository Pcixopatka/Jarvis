extends "res://scripts/mechanics/power_mechanic.gd"
## Вогняне ядро: кожні {period} с на найближчого ворога (не далі 520) падає ядро й б'є всіх у колі {r}
## так, як герой за {sec} с бою (Power.dps), ще й підпалює. Нема ворога — пробує за пів секунди.

const Power := preload("res://scripts/game/power.gd")

var t := 2.0  # скільки до наступного ядра


func tick(delta: float) -> void:
	if not worn():
		return
	t -= delta
	if t <= 0.0:
		var y: Dictionary = P
		var target = nearest(520.0)
		if target == null:
			t = 0.5
		else:
			t = float(y["period"])
			var c: Vector2 = target.global_position
			var dmg: float = Power.dps(p) / 1.6 * float(y["sec"])
			p._u_proc = true
			for e in foes():
				if e.global_position.distance_to(c) <= float(y["r"]) + e.radius:
					e.take_damage(dmg, (e.global_position - c).normalized() * 200.0, false)
					if not e.dead:
						Status.apply(e, "burn", 3.0, dmg * 0.1)
			p._u_proc = false
			combat.fx.burst(c, Color(1.0, 0.55, 0.15), 26, 260, 8, 0.5)
			combat.fx.ring(c, Color(1.0, 0.7, 0.2), 24, float(y["r"]), 5, 0.3)
			combat.shake(5.0)
			Audio.play("musket", 0.1, -6.0)
