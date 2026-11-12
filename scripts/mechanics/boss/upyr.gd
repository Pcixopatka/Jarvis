extends "res://scripts/mechanics/mechanic.gd"
## Упир-володар: по черзі стрибає туди, де стоїть ціль, і кличе з трун упирів та мавок.


func ability(target, _dist: float) -> void:
	e.ability_timer = 6.0
	if e.ability_step % 2 == 1:
		# Стрибок-удар у місце, де стоїть ціль
		var t = telegraph("circle", target.global_position, 1.0, e.damage * 1.4)
		t.radius = 120.0
		t.on_fire = func():
			if alive():
				e.global_position = t.global_position
	else:
		Audio.play("roar", 0.05, -4.0)
		summon(["upyr", "mavka"], 3)
