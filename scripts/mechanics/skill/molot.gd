extends "res://scripts/mechanics/skill_mechanic.gd"
## Громовий молот (Перунів жрець): блискавка з неба на найближчого ворога (не далі 600) — б'є всіх у колі
## 160 і приголомшує (крім босів). Без ворога поруч не спрацьовує.


func cast() -> bool:
	var e: Node2D = nearest(600.0)
	if e == null:
		return false
	var pos: Vector2 = e.global_position
	var m := 3.5 * (1.0 + 0.2 * (rank() - 1)) * (1.0 + 0.1 * p.pk("grim")) * p.skill_power
	for t in foes():
		var to: Vector2 = t.global_position - pos
		if to.length() <= 160.0 + t.radius:
			var r := roll(m)
			hit(t, r[0], to.normalized() * 320.0, r[1])
			if not t.dead and not t.is_boss:
				t.stun = maxf(t.stun, 0.8)
	combat.spawn_bolt(PackedVector2Array([pos + Vector2(10, -460), pos + Vector2(-20, -200), pos]))
	combat.spawn_fx("lightning", pos - Vector2(0, 30), 2.4, 0.0, Color.WHITE, 20.0)
	combat.fx.ring(pos, Color(0.75, 0.85, 1.0), 30, 320, 6, 0.35)
	combat.shake(10.0)
	Audio.play("lightning", 0.0, 2.0)
	return true


func cooldown(base: float) -> float:
	return base * (1.0 - 0.1 * p.pk("storm_soul"))


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 3.5 * (1.0 + 0.2 * (r - 1)) * (1.0 + 0.1 * p.pk("grim")) * sp)], ["Радіус", "160"], ["Приголомшення", "0.8 с"]]
