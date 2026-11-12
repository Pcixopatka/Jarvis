extends "res://scripts/mechanics/mechanic.gd"
## Заражений: гине й лишає по собі хмару зарази.


func on_death() -> void:
	# Заражена еліта з властивістю «чума» лишає хмару й так (Enemy.take_damage): одну, не дві
	if not "plague" in e.affixes:
		combat.spawn_plague(e.global_position, e.damage * 0.6)
