extends "res://scripts/mechanics/act_mechanic.gd"
## Стрибок до найближчого ворога (у межах «range», типово 420) і удар довкола місця приземлення;
## на мить герой невразливий. Поля удару — як у nova.


func cast(_n: Dictionary, A: Dictionary, r: int, m: float, col: Color) -> bool:
	var t: Node2D = nearest(Classes.val(A.get("range", 420.0), r))
	if t == null:
		return false
	p.facing = (t.global_position - p.global_position).normalized()
	combat.fx.burst(p.global_position, col, 12, 200, 6, 0.3)
	p.global_position = combat._clamp_in(t.global_position - p.facing * (float(t.radius) + p.radius + 6.0), 30.0)
	p.invuln = maxf(p.invuln, 0.3)
	return area(A, r, m, col, p.global_position)
