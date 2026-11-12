extends "res://scripts/mechanics/weapon_mechanic.gd"
## Булава: б'є зблизька, як типова зброя, але завершальний удар серії оглушує нечисть (крім босів) на
## 0,6 с, а «Майстер булави» (mace_master) додає їй 10% шкоди за ранг.


func finisher_hit(e) -> void:
	if not e.dead and not e.is_boss:
		e.stun = maxf(e.stun, 0.6)  # завершальний удар булавою оглушує


func damage_mult() -> float:
	return 1.0 + 0.1 * p.pk("mace_master")
