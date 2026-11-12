extends "res://scripts/mechanics/mechanic.gd"
## Відьма з Лисої гори: зілля під ногами героя, що знесилює; мари — дві примари поруч зі справжньою;
## віяло проклять, між якими треба прослизнути; у люті ще й кличе шабаш.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.4 if e.phase2 else 4.6
	match e.ability_step % (4 if e.phase2 else 3):
		1:
			Audio.play("spell", 0.1, 2.0)
			for i in 3:
				var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 140.0)
				var t = telegraph("circle", pos, 1.0, e.damage * 0.9)
				t.radius = 80.0
				t.color = Color(0.65, 0.3, 0.95)
				t.on_fire = func(): combat.spawn_plague(pos, e.damage * 0.35, "weak", Color(0.5, 0.2, 0.75), 4.0)
		2:
			cast_illusions(target)
		3:
			Audio.play("roar", 0.15, -4.0)
			summon(["chort", "mavka"], 3)
		0:
			# Віяло проклять: п'ять повільних згустків, між якими треба прослизнути
			Audio.play("spell", 0.1, 2.0)
			for i in 5:
				shoot(e.global_position, to_t.rotated((i - 2) * 0.28), 210.0, e.damage * 0.55, Color(0.75, 0.4, 1.0), 12.0)


func phase2() -> void:
	rage("Відьма скликає шабаш!", ["chort", "mavka"])
