extends "res://scripts/mechanics/parts/rocks.gd"
## Шубін: обвал — каміння сиплеться довкола героя; гримучий газ — великі кола, що вибухають і палять;
## ривок із кайлом. У люті копальня валиться: зі стелі весь час падає каміння (parts/rocks.gd).


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.4 if e.phase2 else 4.8
	match e.ability_step % 3:
		1:
			Audio.play("boom", 0.0, -4.0)
			for i in (8 if e.phase2 else 6):
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(90.0, 260.0))
				var t = telegraph("circle", pos, 0.9 + 0.08 * i, e.damage * 0.9)
				t.radius = 78.0
				t.color = Color(0.6, 0.55, 0.5)
		2:
			var spin := randf() * TAU
			for i in 3:
				var pos: Vector2 = target.global_position + Vector2.from_angle(spin + TAU * i / 3.0) * 150.0
				var t = telegraph("circle", pos, 1.6, e.damage * 1.2)
				t.radius = 125.0
				t.color = Color(1.0, 0.6, 0.15)
				t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.3, "burn", Color(1.0, 0.5, 0.1), 3.5)
		0:
			var t = telegraph("line", e.global_position, 0.8, e.damage * 1.5)
			t.dir = to_t
			t.length = 480.0
			t.width = 110.0
			t.color = Color(0.9, 0.5, 0.15)
			t.on_fire = func():
				if alive():
					e.knockback = to_t * 1700.0


## Каміння сиплеться лише в люті.
func rocks_falling() -> bool:
	return e.phase2


func phase2() -> void:
	rage("Шубін валить копальню!", ["kamiana_baba", "zlyden", "zlyden"])
