extends "res://scripts/mechanics/skill_mechanic.gd"
## Бочка пороху (Самопальник): бочка під найближчим ворогом (чи перед собою) вибухає за мить — б'є всіх
## у колі 150 і підпалює.


func cast() -> bool:
	var target: Node2D = nearest(450.0)
	var pos: Vector2 = target.global_position if target else p.global_position + p.facing * 220.0
	var r := roll(2.8 * (1.0 + 0.2 * (rank() - 1)) * p.skill_power)
	var b = combat.spawn_barrel(pos, r[0], r[1], 150.0, r[0] * 0.1)
	b.mech = self
	Audio.play("swing", 0.05, -2.0)
	return true


## Бочка вибухнула (e == null).
func trap_fire(t, _e) -> void:
	for e in t.combat.enemies_now():
		if e.dead:
			continue
		var to: Vector2 = e.global_position - t.global_position
		if to.length() <= t.blast + e.radius:
			t.combat.player.hit(e, t.damage, to.normalized() * 420.0, t.crit)
			if not e.dead and t.burn > 0.0:
				Status.apply(e, "burn", 3.0, t.burn)
	t.combat.fx.ring(t.global_position, Color(1.0, 0.55, 0.15), 36, t.blast * 2.0, 8, 0.4)
	t.combat.fx.burst(t.global_position, Color(1.0, 0.5, 0.15), 30, 340, 8, 0.6, -80)
	t.combat.fx.burst(t.global_position, Color(0.3, 0.3, 0.3, 0.8), 20, 200, 10, 1.0, -60)
	t.combat.spawn_fx("fire", t.global_position, t.blast / 26.0, 0.0, Color.WHITE, 12.0)
	t.combat.shake(10.0)
	Audio.play("boom", 0.05, 0.0)


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * 2.8 * (1.0 + 0.2 * (r - 1)) * sp)], ["Радіус вибуху", "150"], ["Підпал", "так"]]
