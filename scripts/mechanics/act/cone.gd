extends "res://scripts/mechanics/act_mechanic.gd"
## Удар перед собою: конус завдовжки «reach» (не коротший за 1,4 дальності удару героя) і завширшки «arc»
## градусів (типово 120). Поля удару — як у nova; звук типово «swing».


func cast(_n: Dictionary, A: Dictionary, r: int, m: float, col: Color) -> bool:
	var reach: float = maxf(Classes.val(A.get("reach", 0.0), r), p.attack_range * 1.4)
	var tc: Node2D = nearest(reach + 80.0)
	if tc:
		p.facing = (tc.global_position - p.global_position).normalized()
	var half: float = deg_to_rad(Classes.val(A.get("arc", 120.0), r)) * 0.5
	for e in foes():
		var to: Vector2 = e.global_position - p.global_position
		if to.length() <= reach + float(e.radius) and absf(p.facing.angle_to(to)) <= half:
			strike(A, r, m, e, to.normalized())
	p.swing_time = 0.3
	p.swing_duration = 0.3
	p.swing_full = false
	p.swing_reach = reach
	combat.shake(6.0)
	var snd: String = str(A["sound"]) if A.has("sound") else ""
	Audio.play(snd if snd != "" else "swing", 0.05, 0.0)
	combat.fx.burst(p.global_position + p.facing * reach * 0.5, col, 16, 260, 6, 0.35, 0, p.facing.angle(), 1.2)
	return true
