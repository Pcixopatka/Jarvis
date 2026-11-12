extends "res://scripts/mechanics/skill_mechanic.gd"
## Пастка (Пластун): капкан під найближчим ворогом (чи перед собою); ловить першого, хто ступить, —
## удар, приголомшення 1,6 с (крім босів) і кровотеча. «Ловець» (trapper) — сильніша пастка й ще одна
## одночасно. Пастка живе 20 с.


func cast() -> bool:
	var target: Node2D = nearest(260.0)
	var pos: Vector2 = target.global_position if target else p.global_position + p.facing * 80.0
	var r := roll(2.2 * (1.0 + 0.2 * (rank() - 1)) * (1.0 + 0.2 * p.pk("trapper")) * p.skill_power)
	var t = combat.spawn_trap(pos, r[0], r[1], 2 + p.pk("trapper"))
	t.mech = self
	Audio.play("sharpen_ok", 0.1, -8.0)
	return true


## Капкан ухопив e.
func trap_fire(t, e) -> void:
	t.combat.player.hit(e, t.damage, Vector2.ZERO, t.crit)
	if not e.dead:
		if not e.is_boss:
			e.stun = maxf(e.stun, 1.6)
		Status.apply(e, "bleed", 3.0, t.damage * 0.1)
	t.combat.fx.burst(t.global_position, Color(0.75, 0.75, 0.8), 10, 160, 4, 0.3)
	Audio.play("hit", 0.1)


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 2.2 * (1.0 + 0.2 * (r - 1)) * (1.0 + 0.2 * p.pk("trapper")) * sp)],
		["Пасток одночасно", "%d" % (2 + p.pk("trapper"))], ["Приголомшення", "1.6 с + кровотеча"]]
