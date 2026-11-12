extends "res://scripts/mechanics/power_mechanic.gd"
## Пластунський випад: {window} с після перекиду кожен удар героя критичний і на {bonus} сильніший.

var t := 0.0  # скільки ще після перекиду


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func on_dodge() -> void:
	if worn():
		t = float(P["window"])


func on_roll(r: Array) -> void:
	if t > 0.0:
		r[1] = true
		r[0] *= 1.0 + float(P.get("bonus", 0.0))
