extends "res://scripts/mechanics/skill_mechanic.gd"
## Прицільний постріл (Самопальник): важка куля навиліт (той самий постріл, що й заряджений із пищалі
## чи лука, див. HeroMechanic.heavy_shot).


func cast() -> bool:
	return heavy_shot((3.8 + 0.9 * (rank() - 1)) * p.skill_power, false)


func card(r: int) -> Array:
	var d: float = p.damage
	var sp: float = p.skill_power
	return [["Шкода", dmg_text(d * (3.8 + 0.9 * (r - 1)) * sp)], ["Пробиває", "усіх на лінії"]]
