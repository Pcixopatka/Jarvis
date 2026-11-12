extends "res://scripts/mechanics/power_mechanic.gd"
## Перунова блискавка: критичний удар із шансом {chance} б'є блискавкою ще {jumps} ворогів поруч (кожен
## наступний — найближчий до попереднього, не далі 260), по {pct} шкоди удару. Не частіше ніж раз на {icd} с.

var cd := 0.0  # скільки ще до наступної блискавки


func tick(delta: float) -> void:
	cd = maxf(0.0, cd - delta)


func on_hit(e, dmg: float, crit: bool, _hp_before: float) -> void:
	if p._u_proc:
		return
	if crit and worn() and cd <= 0.0:
		var pr: Dictionary = P
		if randf() < float(pr["chance"]):
			cd = float(pr["icd"])
			var from = e
			var seen := [e]
			var pts := PackedVector2Array([e.global_position])
			p._u_proc = true
			for i in int(pr["jumps"]):
				var best = null
				var best_d := 260.0
				for o in foes():
					if o in seen:
						continue
					var dd: float = o.global_position.distance_to(from.global_position)
					if dd < best_d:
						best_d = dd
						best = o
				if best == null:
					break
				seen.append(best)
				pts.append(best.global_position)
				best.take_damage(dmg * float(pr["pct"]), Vector2.ZERO, false)
				from = best
			p._u_proc = false
			if pts.size() > 1:
				combat.spawn_bolt(pts)
				Audio.play("lightning", 0.1, -8.0)
