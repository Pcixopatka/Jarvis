extends "res://scripts/mechanics/weapon_mechanic.gd"
## Пістолі: постріл по черзі з кожної руки, завершальний — з обох одразу (кожна куля слабша); куля далеко
## не летить. Заряджений — залп із двох пістолів: п'ять куль віялом, кожна пробиває двох.


func attack(step: int, finisher: bool) -> void:
	var target: Node2D = shot_target()
	if target == null:
		return
	var dir: Vector2 = (target.global_position - p.global_position).normalized()
	p.facing = dir
	var side: Vector2 = dir.orthogonal() * 8.0
	var hands := [side, -side] if finisher else [side if step % 2 == 0 else -side]
	for h in hands:
		var r := roll(p.COMBO_MULT[step] * p.shot_mult * (0.75 if hands.size() > 1 else 1.0))
		combat.spawn_bullet(p.global_position + Vector2(0, -10) + dir * 30.0 + h, dir, r[0], r[1])
		var pr = combat.last_projectile()
		pr.pierce = 1
		pr.life = 0.45  # куля пістоля далеко не летить
	Audio.play("musket", 0.2, -10.0)
	combat.fx.burst(p.global_position + Vector2(0, -10) + dir * 40.0, Color(1.0, 0.8, 0.3), 4, 200, 4, 0.12, 0, dir.angle(), 0.6)
	shot_mana()
	next_step(step)


## Заряджений залп із двох пістолів: п'ять куль віялом.
func charged(power: float) -> void:
	var tgt: Node2D = nearest(500.0)
	var cdir: Vector2 = p.facing
	if tgt:
		cdir = (tgt.global_position - p.global_position).normalized()
		p.facing = cdir
	for i in 5:
		var cr := roll((0.7 + 0.8 * power) * p.skill_power)
		combat.spawn_bullet(p.global_position + Vector2(0, -10) + cdir * 30.0, cdir.rotated(-0.3 + i * 0.15), cr[0], cr[1])
		combat.last_projectile().pierce = 2
	Audio.play("musket", 0.05, -2.0)
	combat.shake(4.0)
	Events.charged_hit.emit()
	p.combo_step = 0
	p.attack_timer = p.attack_cooldown
