extends "res://scripts/mechanics/mechanic.gd"
## Каджі: розпалює вогняну пляму під ногами героя.

## Колір плями й стан, який вона накладає (у лауми — пристріт, див. lauma.gd)
var zone_color := Color(1.0, 0.55, 0.2)
var zone_status := "burn"


func ability(target, dist: float) -> void:
	e.ability_timer = randf_range(5.5, 7.5)
	if dist > 600.0:
		e.ability_timer = 1.0
		return
	var pos: Vector2 = target.global_position
	var zc: Color = zone_color
	var zs: String = zone_status
	var t = telegraph("circle", pos, 1.0, e.damage * 0.9)
	t.radius = 85.0
	t.color = zc
	t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.25, zs, zc, 3.5)
	e.cast_time = 0.6
