extends RefCounted
## Мірило сили героя — щоб герць і варта були чесними на будь-якому рівні:
## здоров'я ворога рахуємо від шкоди героя, удар ворога — від здоров'я героя.

const Data := preload("res://scripts/data/data.gd")


## Приблизна шкода героя за секунду по одній цілі (удари з критами, серії та вміння).
static func dps(player) -> float:
	var crit: float = 1.0 + player.crit_chance * (player.crit_mult - 1.0)
	# вміння додають до ударів тим більше, що вища сила вмінь (але не безмежно)
	return player.damage / maxf(player.attack_cooldown, 0.1) * crit * maxf(1.6, 1.3 + 0.15 * minf(float(player.skill_power), 4.0))


## Удар, що забирає в героя частку frac здоров'я вже після його захисту.
static func hit(player, frac: float) -> float:
	return player.max_hp * frac / maxf(1.0 - Data.ARMOR_CAP, 1.0 - player.armor)
