extends "res://scripts/mechanics/mechanic.gd"
## Самодива: прицільний постріл уздовж смуги; стріла студить.

## Що накладає влучний постріл і якого кольору смуга (у чуді — камінь, що знесилює, див. chud.gd)
var shot_status := "chill"
var shot_color := Color(0.7, 0.85, 1.0)


func ability(target, dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = randf_range(4.5, 6.0)
	if dist > 720.0:
		e.ability_timer = 1.0
		return
	var st: String = shot_status
	var t = telegraph("line", e.global_position, 0.9, e.damage * 1.4)
	t.dir = to_t
	t.length = 700.0
	t.width = 44.0
	t.color = shot_color
	t.on_fire = func():
		if is_instance_valid(target) and t.contains(target.global_position) and target.has_method("add_status"):
			target.add_status(st, 3.0, e.damage * 0.1)
	e.cast_time = 0.9
