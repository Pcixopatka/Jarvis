extends "res://scripts/mechanics/power_mechanic.gd"
## Відлуння: кожне вміння з шансом {chance} перезаряджається вдвічі швидше.


func on_cast(id: String) -> void:
	if worn() and randf() < float(P["chance"]):
		p.skill_timers[id] *= 0.5
		combat.float_text(p.global_position + Vector2(0, -80), "Відлуння", Color(1.0, 0.85, 0.3))
