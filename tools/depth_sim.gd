extends "res://tools/balance_sim.gd"
## Темп гри після сюжету: бот заданого рівня проходить глибину свого рівня.
## Запуск: SIM_CLASS=volkhv godot --headless --path . -s res://tools/depth_sim.gd --fixed-fps 60
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://depthsim.save"
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var DS = load("res://scripts/game/depth_service.gd")
	for lvl in [30, 40, 55, 70, 85, 99]:
		var d: int = maxi(1, (lvl - 22) / 2 + 1)
		_build_hero(lvl)
		var p = game.player
		game.world.missions = {}
		game.QuestEngine.finish_line(game.world, "story")
		game.world.depths = {"max": d, "best": d - 1}
		game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "depths": true, "stones": true}
		var xp0 = _total_xp(p)
		game.start_depth(d)
		var t := 0.0
		while t < 600.0 and p.alive and game.DepthService.state(game.world)["best"] < d:
			_bot(p, game.combat)
			await process_frame
			t += 1.0 / 60.0
		var gained = _total_xp(p) - xp0
		var per_min = gained / maxf(t / 60.0, 0.01)
		print("герой %2d глибина %2d (рів. %2d) | %s | %3.0f с | досвід/хв %7.0f | хв на рівень %5.1f" % [lvl, d, DS.level_of(d), "OK" if p.alive and t < 600 else ("СМЕРТЬ" if not p.alive else "ЧАС"), t, per_min, (Data.xp_for_level(lvl) / maxf(per_min, 1.0)) if lvl < 99 else 0.0])
		for i in 120: await process_frame
		if game.state == game.State.PLAYING: game.enter_map()
		game.world = load("res://scripts/game/world_state.gd").new()
	quit()
