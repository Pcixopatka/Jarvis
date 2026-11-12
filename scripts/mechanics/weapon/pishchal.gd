extends "res://scripts/mechanics/weapon_mechanic.gd"
## Пищаль самопальника: куля пробиває двох, завершальний постріл — три кулі віялом (кожна слабша);
## заряджений — важка куля навиліт (повна — приголомшує). «Швидке заряджання» (shvydke) — частіші постріли.


func attack(step: int, finisher: bool) -> void:
	var target: Node2D = shot_target()
	if target == null:
		return
	var dir: Vector2 = (target.global_position - p.global_position).normalized()
	p.facing = dir
	var angles := [-0.12, 0.0, 0.12] if finisher else [0.0]
	for a in angles:
		var r := roll(p.COMBO_MULT[step] * p.shot_mult * (0.7 if angles.size() > 1 else 1.0))
		combat.spawn_bullet(p.global_position + Vector2(0, -10) + dir * 34.0, dir.rotated(a), r[0], r[1])
		combat.last_projectile().pierce = 2  # звичайна куля пищалі пробиває двох
	Audio.play("musket", 0.15, -8.0)
	combat.fx.burst(p.global_position + Vector2(0, -10) + dir * 44.0, Color(0.85, 0.85, 0.8, 0.6), 8, 120, 7, 0.6, -40, dir.angle(), 0.8)
	combat.shake(1.5)
	shot_mana()
	next_step(step)


## Заряджений постріл: важка куля навиліт.
func charged(power: float) -> void:
	heavy_shot((2.0 + 2.5 * power) * p.skill_power, power >= 0.99)
	Events.charged_hit.emit()
	p.combo_step = 0
	p.attack_timer = p.attack_cooldown


func cd_mult() -> float:
	return 1.0 + 0.1 * p.pk("shvydke")
