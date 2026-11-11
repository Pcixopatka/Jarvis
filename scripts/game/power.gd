extends RefCounted
## Мірило сили героя — щоб герць і варта були чесними на будь-якому рівні:
## здоров'я ворога рахуємо від шкоди героя, удар ворога — від здоров'я героя.

const Data := preload("res://scripts/data/data.gd")


## Приблизна шкода героя за секунду по одній цілі (удари з критами, серії та вміння).
static func dps(player) -> float:
	var crit: float = 1.0 + player.crit_chance * (player.crit_mult - 1.0)
	# вміння додають до ударів тим більше, що вища сила вмінь (але не безмежно)
	return player.damage / maxf(player.attack_cooldown, 0.1) * crit * maxf(1.6, 1.3 + 0.15 * minf(float(player.skill_power), 4.0))


## Скільки варта сила золотої речі в порівнянні спорядження: шкода й здоров'я її не показують.
const UNIQUE_WORTH := 0.1
## На скільки річ має підняти силу героя, щоб вважатись кращою (менше — шум, а не покращення).
const MIN_GAIN := 0.01


## Одне число сили героя для порівняння спорядження: шкода за секунду на запас живучості
## (здоров'я з поправкою на захист). Що більше, то сильніший герой загалом.
static func score(player) -> float:
	return dps(player) * player.max_hp / maxf(1.0 - Data.ARMOR_CAP, 1.0 - player.armor)


## Удар, що забирає в героя частку frac здоров'я вже після його захисту.
static func hit(player, frac: float) -> float:
	return player.max_hp * frac / maxf(1.0 - Data.ARMOR_CAP, 1.0 - player.armor)
