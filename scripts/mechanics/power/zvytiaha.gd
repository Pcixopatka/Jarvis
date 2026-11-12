extends "res://scripts/mechanics/power_mechanic.gd"
## Звитяга: кожен убитий ворог додає {dmg} шкоди на {dur} с, до {max} зарядів. Заряди спадають разом,
## коли час минув чи річ знято.

var stacks := 0  # заряди
var t := 0.0  # скільки ще тримаються


func on_hit(e, _dmg: float, _crit: bool, _hp_before: float) -> void:
	if p._u_proc:
		return
	if e.dead and worn():
		var z: Dictionary = P
		stacks = mini(int(z["max"]), stacks + 1)
		t = float(z["dur"])


func tick(delta: float) -> void:
	if stacks > 0:
		t -= delta
		if t <= 0.0 or not worn():
			stacks = 0


func damage_dealt(dmg: float) -> float:
	if stacks > 0:
		dmg *= 1.0 + stacks * float(P.get("dmg", 0.0))
	return dmg
