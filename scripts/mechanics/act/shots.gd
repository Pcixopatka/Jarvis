extends "res://scripts/mechanics/act_mechanic.gd"
## Снаряди в найближчого ворога (у межах «range», типово 700): «count» штук віялом «spread» радіан, крізь
## «pierce» ворогів (типово крізь усіх), зі станом «status» і вибухом «explode». Звук типово «musket».


func cast(_n: Dictionary, A: Dictionary, r: int, m: float, col: Color) -> bool:
	var ts: Node2D = nearest(Classes.val(A.get("range", 700.0), r))
	var dir: Vector2 = p.facing
	if ts:
		dir = (ts.global_position - p.global_position).normalized()
		p.facing = dir
	var count: int = int(Classes.val(A.get("count", 1), r))
	var spread: float = Classes.val(A.get("spread", 0.0), r)
	for i in count:
		var a: float = 0.0 if count <= 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var rl := roll(m)
		combat.spawn_bullet(p.global_position + Vector2(0, -10) + dir * 30.0, dir.rotated(a), rl[0], rl[1])
		var pr = combat.last_projectile()
		pr.color = col
		pr.pierce = int(A.get("pierce", 999))
		if A.has("status"):
			pr.status = str(A["status"][0])
			pr.status_dur = float(A["status"][1])
		if A.has("explode"):
			pr.explode_radius = Classes.val(A["explode"], r)
	var snd: String = str(A["sound"]) if A.has("sound") else ""
	Audio.play(snd if snd != "" else "musket", 0.05, 0.0)
	combat.fx.burst(p.global_position + Vector2(0, -10) + dir * 40.0, col, 10, 240, 5, 0.25, 0, dir.angle(), 0.8)
	return true
