extends "res://tools/balance_sim.gd"
## Башта Кощія: бот заданого рівня бере поверх свого рівня (і на 5 вище). Чи проходить, за скільки.
## Запуск: SIM_CLASS=zaporozhets godot --headless --path . -s res://tools/tower_sim.gd --fixed-fps 60
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://towersim.save"
	game.account_path = "user://towersim_acc.save"
	game.use_slots = false
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var TS = load("res://scripts/game/tower_service.gd")
	for lvl in [16, 20, 25, 30, 40, 55, 70]:
		for floor_ in [maxi(1, lvl - 14), lvl - 14 + 4]:
			if floor_ < 1:
				continue
			_build_hero(lvl)
			var p = game.player
			game.world.tower = {"max": floor_, "best": floor_ - 1}
			game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "tower": true, "stones": true, "cleared": true}
			game.start_tower(floor_)
			var t := 0.0
			var low: float = p.max_hp
			while t < 420.0 and p.alive and TS.state(game.world)["best"] < floor_:
				_bot(p, game.combat)
				low = minf(low, p.hp)
				await process_frame
				t += 1.0 / 60.0
			var ok: bool = p.alive and t < 420.0
			print("герой %2d поверх %2d (рів. %2d%s) | %s | %3.0f с | мін. здоров'я %3.0f%%" % [lvl, floor_, TS.level_of(floor_), ", СУПЕРБОС" if TS.is_super(floor_) else "", "OK" if ok else ("СМЕРТЬ" if not p.alive else "ЧАС"), t, 100.0 * low / p.max_hp])
			# меню поразки відкривається за півтори секунди й ставить гру на паузу: чекаємо, щоб не зачепити наступний прогін
			for i in 120: await process_frame
			paused = false
			if game.state == game.State.PLAYING: game.enter_map()
			game.world = load("res://scripts/game/world_state.gd").new()
			game._attach_account()
	quit()
