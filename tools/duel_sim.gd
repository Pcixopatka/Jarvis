extends "res://tools/balance_sim.gd"
## Герць: бот заданого рівня б'ється з кожним суперником у кожному колі. Чи перемагає, за скільки, скільки здоров'я лишилось.
## Запуск: SIM_CLASS=cossack SIM_LEVELS=6,20 godot --headless --path . -s res://tools/duel_sim.gd --fixed-fps 60
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://duelsim.save"
	game.account_path = "user://duelsim_acc.save"
	game.use_slots = false
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var Acts = load("res://scripts/data/activities.gd")
	var levels := []
	for l in _env_list("SIM_LEVELS", ["6", "12", "20", "35", "60"]):
		levels.append(int(l))
	for lvl in levels:
		for rid in Acts.RIVAL_ORDER:
			var line := "рів. %2d  %-22s" % [lvl, Acts.RIVALS[rid]["name"]]
			for r in 3:
				_build_hero(lvl)
				var p = game.player
				game.world.duel = {}
				game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "duel": true, "city": true, "stones": true}
				game.combat.defense_loc = game.DuelService.loc_for(p, rid, r)
				game.enter_location("duel")
				var t := 0.0
				var low: float = p.max_hp
				var taken := 0.0
				var prev: float = p.hp
				while t < 180.0 and p.alive and not game.combat.duel_over:
					_bot(p, game.combat)
					await process_frame
					t += 1.0 / 60.0
					low = minf(low, p.hp)
					if p.hp < prev:
						taken += prev - p.hp
					prev = p.hp
				var won: bool = game.combat.duel_over
				line += " | %d: %s %3.0fс мін %3.0f%% отримав %3.0f%%" % [r + 1, "ПЕРЕМ" if won else ("ПОРАЗ" if not p.alive else "ЧАС  "), t, 100.0 * maxf(low, 0.0) / p.max_hp, 100.0 * taken / p.max_hp]
				for i in 130:
					await process_frame
				if game.state != game.State.CITY:
					game.enter_city("sich")
				game.hud.close_dialogue()
			print(line)
	quit()
