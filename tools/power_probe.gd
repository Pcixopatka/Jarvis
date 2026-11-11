extends "res://tools/balance_sim.gd"
## Сила героя за рівнем і спорядженням: скільки шкоди за секунду, здоров'я й захисту має герой
## у середньому, доброму й найкращому спорядженні. З цих чисел зроблено еталон сили для нечисті (Power.reference).
## Запуск:  SIM_LEVELS=5,20,60,99 SIM_CLASS=cossack godot --headless --path . -s res://tools/power_probe.gd
const Power := preload("res://scripts/game/power.gd")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://balance_sim.save"
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	load("res://scripts/game/holiday_service.gd").forced = "none"
	print("рівень | спорядження | шкода/с | здоров'я | захист | запас живучості | проти нечисті свого рівня: секунд на ворога, ударів до смерті")
	for l in _env_list("SIM_LEVELS", ["1", "5", "10", "20", "30", "45", "60", "75", "90", "99"]):
		var lvl := int(l)
		for tier in [["середнє", 1, mini(lvl / 3, 4), false], ["добре", 3, 5, false], ["найкраще", 3, Data.MAX_UPGRADE, true]]:
			var dps := 0.0
			var hp := 0.0
			var armor := 0.0
			var n := 4
			for i in n:
				seed(900 + i * 37 + lvl)
				_build_hero(lvl)
				var p = game.player
				if tier[0] != "середнє":
					_regear(p, lvl, tier[1], tier[2], tier[3])
				dps += Power.dps(p) / n
				hp += p.max_hp / n
				armor += minf(p.armor, Data.ARMOR_CAP) / n
			var ehp := hp / (1.0 - armor)
			var e_hp: float = Data.enemy_std_hp(lvl)
			var e_dmg: float = Data.enemy_std_dmg(lvl)
			print("%2d | %-9s | %7.0f | %7.0f | %3.0f%% | %8.0f | %5.2f с, %5.0f ударів" % [lvl, tier[0], dps, hp, armor * 100.0, ehp, e_hp / dps, ehp / e_dmg])
	quit()
