extends "res://scripts/mechanics/mechanic.gd"
## Дракула: обертається кажаном і падає на ціль; кривавий туман трьома смугами віялом; п'є кров
## слуг — кличе стригоїв і мороїв і загоює рани.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 5.5
	match e.ability_step % 3:
		1:
			# Обертається кажаном і падає на ціль
			var bat = telegraph("circle", target.global_position, 0.9, e.damage * 1.4)
			bat.radius = 125.0
			bat.color = Color(0.6, 0.05, 0.1)
			bat.on_fire = func():
				if alive():
					e.global_position = bat.global_position
		2:
			# Кривавий туман: три смуги віялом
			for a in [-0.35, 0.0, 0.35]:
				var mist = telegraph("line", e.global_position, 0.8, e.damage * 1.1)
				mist.dir = to_t.rotated(a)
				mist.length = 460.0
				mist.width = 60.0
				mist.color = Color(0.7, 0.1, 0.15)
			Audio.play("roar", 0.05, -4.0)
		_:
			# П'є кров слуг: кличе стригоїв і загоює рани
			Audio.play("roar", 0.05, -4.0)
			summon(["strygoi", "moroi"], 2)
			e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.04)


func phase2() -> void:
	rage("Дракула розгортає плащ: ніч густішає!", ["strygoi", "moroi", "vovkulaka"])
