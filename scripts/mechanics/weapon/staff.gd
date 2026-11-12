extends "res://scripts/mechanics/weapon_mechanic.gd"
## Посох волхва: іскри летять у найближчого ворога (завершальний удар — три віялом; з «Подвійною іскрою»
## (twin_spark) — дві), а заряджений удар — велика вогняна куля, повна — «Гнів Роду» з приголомшенням.
## «Іскра» (iskra) робить іскри сильнішими.


func attack(step: int, finisher: bool) -> void:
	var target: Node2D = shot_target()
	if target == null:
		return
	var dir: Vector2 = (target.global_position - p.global_position).normalized()
	p.facing = dir
	p.swing_time = 0.15
	p.swing_duration = 0.15
	p.swing_full = false
	var angles := [0.0]
	if finisher:
		angles = [-0.22, 0.0, 0.22]
	elif p.sk("twin_spark") > 0:
		angles = [-0.08, 0.08]
	var mult: float = p.COMBO_MULT[step] * (1.0 + 0.1 * p.sk("iskra")) * (0.75 if angles.size() > 1 else 1.0)
	for a in angles:
		var r := roll(mult)
		combat.spawn_spark(p.global_position + Vector2(0, -24) + dir * 26.0, dir.rotated(a), r[0], r[1])
	Audio.play("zap", 0.2)
	next_step(step)


## Заряджене закляття: велика вогняна куля у найближчого ворога.
func charged(power: float) -> void:
	var target: Node2D = nearest(700.0)
	var dir: Vector2 = p.facing if target == null else (target.global_position - p.global_position).normalized()
	p.facing = dir
	var r := roll((1.6 + 1.6 * power) * p.skill_power)
	combat.spawn_fireball(p.global_position + Vector2(0, -24) + dir * 30.0, dir, r[0], r[1], 120.0 * (1.0 + power), r[0] * 0.1, power >= 0.99)
	p.combo_step = 0
	p.attack_timer = p.attack_cooldown
	combat.shake(4.0 + 4.0 * power)
	combat.spawn_fx("gold", p.global_position + Vector2(0, -24) + dir * 30.0, 0.8 + power, 0.0, Color(1.0, 0.8, 0.5), 24.0)
	Audio.play("lightning", 0.05, -3.0)
	Events.charged_hit.emit()
	if power >= 0.99:
		combat.float_text(p.global_position + Vector2(0, -70), "Гнів Роду!", Color(1.0, 0.7, 0.3))
