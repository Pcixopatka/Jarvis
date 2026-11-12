extends "res://scripts/mechanics/skill_mechanic.gd"
## Вихор (Козак): кругова атака довкола козака, що відкидає; на мить козак невразливий. З «Буревієм»
## (storm) нечисть спершу притягує, а за 0,3 с б'є вдруге (70% сили). «Гострий вітер» (whirl_cd) скорочує
## перезарядку.

var storm_t := -1.0  # скільки до другого удару Буревію (від'ємне — не чекаємо)


## Радіус Вихору.
func reach() -> float:
	return p.attack_range * 1.8 * (1.0 + 0.08 * (rank() - 1))


func cast() -> bool:
	var storm := p.sk("storm") > 0
	p.swing_time = 0.4
	p.swing_duration = 0.4
	p.swing_full = true
	p.swing_reach = 0.0
	p.invuln = maxf(p.invuln, 0.4)
	if storm:
		# Притягуємо нечисть до козака, а за мить — другий удар.
		for e in foes():
			var to: Vector2 = e.global_position - p.global_position
			if to.length() <= reach() * 1.6 + e.radius:
				e.knockback = -to.normalized() * minf(to.length() * 5.0, 900.0)
		storm_t = 0.3
		_strike(1.0, 0.0)
	else:
		_strike(1.0, 480.0)
	combat.float_text(p.global_position + Vector2(0, -60), "Буревій!" if storm else "Вихор!", Color(0.6, 0.85, 1.0))
	Audio.play("whirl")
	combat.fx.ring(p.global_position, Color(0.7, 0.9, 1.0, 0.8), 28, reach() * 2.2, 5, 0.35)
	for i in 3:
		combat.spawn_fx("slash", p.global_position + Vector2(0, -8), reach() / 30.0, TAU * i / 3.0, Color(0.8, 0.95, 1.0), 20.0)
	return true


func _strike(mult: float, kb: float) -> void:
	var m := 1.8 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power * mult
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach() + e.radius:
			var r := roll(m)
			hit(e, r[0], to.normalized() * kb, r[1])
	p.swing_time = 0.4
	p.swing_duration = 0.4
	p.swing_full = true
	p.swing_reach = 0.0
	combat.shake(9.0)


func tick_late(delta: float) -> void:
	if storm_t >= 0.0:
		storm_t -= delta
		if storm_t < 0.0:
			_strike(0.7, 480.0)


func cooldown(base: float) -> float:
	return base * (1.0 - 0.1 * p.sk("whirl_cd"))


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	var out := [["Шкода", dmg_text(d * 1.8 * (1.0 + 0.2 * (r - 1)) * sp)], ["Радіус", "%d" % int(p.attack_range * 1.8 * (1.0 + 0.08 * (r - 1)))]]
	if p.sk("storm") > 0:
		out.append(["Буревій", "притягує і б'є вдруге"])
	return out
