extends "res://scripts/mechanics/act_mechanic.gd"
## Удар довкола героя (з «"at": "enemy"» — довкола найближчого ворога в межах «range», типово 520).
## Поля: radius (200), pct, stun, status, kb (250), pull, shake (8), sound («boom»).


func cast(_n: Dictionary, A: Dictionary, r: int, m: float, col: Color) -> bool:
	var center: Vector2 = p.global_position
	if str(A.get("at", "self")) == "enemy":
		var tn: Node2D = nearest(Classes.val(A.get("range", 520.0), r))
		if tn == null:
			return false
		center = tn.global_position
	return area(A, r, m, col, center)
