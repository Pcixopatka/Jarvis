extends "res://tools/balance_sim.gd"
## Козацька варта: бот заданого рівня стоїть на варті до 7 хвилин. Скільки вистояв, скільки вбив, де було найважче.
## Запуск: SIM_CLASS=cossack SIM_LEVELS=6,20 godot --headless --path . -s res://tools/vigil_sim.gd --fixed-fps 60
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://vigilsim.save"
	game.account_path = "user://vigilsim_acc.save"
	game.use_slots = false
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var levels := []
	for l in _env_list("SIM_LEVELS", ["6", "12", "20", "35", "60"]):
		levels.append(int(l))
	for lvl in levels:
		_build_hero(lvl)
		var p = game.player
		game.world.vigil = {}
		game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "vigil": true, "city": true, "stones": true, "cleared": true}
		var gold0: int = p.gold
		game.start_vigil()
		var t := 0.0
		var lows := []
		var low: float = p.max_hp
		var next_mark := 60.0
		while t < 420.0 and p.alive and game.state == game.State.PLAYING:
			# бот не йде в портал: стоїть до кінця
			var portal = game.combat.portal
			game.combat.portal = null
			_bot(p, game.combat)
			game.combat.portal = portal
			await process_frame
			t += 1.0 / 60.0
			low = minf(low, p.hp)
			if t >= next_mark:
				lows.append("%d%%" % int(100.0 * maxf(low, 0.0) / p.max_hp))
				low = p.max_hp
				next_mark += 60.0
		print("рів. %2d | %s | вистояв %s | вбито %3d | гривень +%d | мін. здоров'я по хвилинах: %s" % [lvl, "ЖИВИЙ" if p.alive else "ВПАВ ", game.VigilService.time_text(game.combat.vigil_time), game.combat.vigil_kills, p.gold - gold0, " ".join(lows)])
		for i in 130:
			await process_frame
		if game.state != game.State.CITY:
			game.enter_city("sich")
		game.hud.close_dialogue()
	quit()
