extends "res://scripts/mechanics/mob/vovkulaka.gd"
## Вовкулака-ватажок: стрибає на героя, як і вся зграя (mob/vovkulaka.gd), а ще по черзі кидається
## ривком по прямій і кличе вовкулак.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 5.0
	if e.ability_step % 2 == 1:
		# Ривок по прямій
		var t = telegraph("line", e.global_position, 0.75, e.damage * 1.3)
		t.dir = to_t
		t.length = 480.0
		t.width = 90.0
		t.on_fire = func():
			if alive():
				e.knockback = to_t * 1900.0
	else:
		Audio.play("roar", 0.05, -2.0)
		summon(["vovkulaka"], 2)
