extends "res://scripts/mechanics/weapon_mechanic.gd"
## Лук: стріла в найближчого ворога, завершальний постріл — три стріли віялом (бічні слабші: вони для
## гурту); заряджений — важка стріла навиліт (повна — приголомшує).


func attack(step: int, finisher: bool) -> void:
	var target: Node2D = shot_target()
	if target == null:
		return
	var dir: Vector2 = (target.global_position - p.global_position).normalized()
	p.facing = dir
	var angles := [-0.14, 0.0, 0.14] if finisher else [0.0]
	for a in angles:
		# завершальний постріл: середня стріла повної сили, бічні слабші (вони для гурту)
		var r := roll(p.COMBO_MULT[step] * p.shot_mult * (0.35 if a != 0.0 else 1.0))
		combat.spawn_bullet(p.global_position + Vector2(0, -12) + dir * 30.0, dir.rotated(a), r[0], r[1])
		var pr = combat.last_projectile()
		pr.pierce = 1
		pr.color = Color(0.85, 0.75, 0.55)
		pr.spear = true  # стріла малюється довгою, як спис
	Audio.play("swing", 0.15, -6.0)
	shot_mana()
	next_step(step)


## Заряджений постріл: важка стріла навиліт.
func charged(power: float) -> void:
	heavy_shot((2.0 + 2.5 * power) * p.skill_power, power >= 0.99)
	Events.charged_hit.emit()
	p.combo_step = 0
	p.attack_timer = p.attack_cooldown
