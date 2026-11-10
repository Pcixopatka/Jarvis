extends "res://tools/balance_sim.gd"
## Коло Кожум'яки: бот заданого рівня б'ється з кожним чудовиськом у кожному з трьох кіл.
## Чи перемагає, за скільки секунд, скільки здоров'я лишається й скільки шкоди він отримав.
## Запуск: SIM_CLASS=cossack SIM_LEVELS=10,30,66 godot --headless --path . -s res://tools/ring_sim.gd --fixed-fps 60
## SIM_BOSSES=vii,zmii — лише ці чудовиська.
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://ringsim.save"
	game.account_path = "user://ringsim_acc.save"
	game.use_slots = false
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var Acts = load("res://scripts/data/activities.gd")
	var levels := []
	for l in _env_list("SIM_LEVELS", ["10", "30", "66"]):
		levels.append(int(l))
	var bosses: Array = _env_list("SIM_BOSSES", Acts.RING_POOL)
	for lvl in levels:
		for kind in bosses:
			var line := "рів. %2d  %-10s" % [lvl, kind]
			for stage in int(Acts.RING_STAGES):
				_build_hero(lvl)
				var p = game.player
				game.world.ring = {}
				game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "ring": true, "city": true, "stones": true}
				var L: Dictionary = game.RingService.battle_loc(p)
				L["bosses"] = [kind, kind, kind]
				game.combat.defense_loc = L
				game.enter_location("ring")
				var c = game.combat
				c.ring_stage = stage  # одразу потрібне коло: сила чудовиська береться за його номером
				c.ring_break = 0.5
				var t := 0.0
				var low: float = p.max_hp
				var taken := 0.0
				var prev: float = p.hp
				while t < 240.0 and p.alive and c.ring_stage == stage and game.state == game.State.PLAYING:
					_bot(p, c)
					await process_frame
					t += 1.0 / 60.0
					low = minf(low, p.hp)
					if p.hp < prev:
						taken += prev - p.hp
					prev = p.hp
				var won: bool = c.ring_stage > stage
				line += " | %d: %s %3.0fс мін %3.0f%% отримав %3.0f%%" % [stage + 1, "ПЕРЕМ" if won else ("ПОРАЗ" if not p.alive else "ЧАС  "), c.ring_time, 100.0 * maxf(low, 0.0) / p.max_hp, 100.0 * taken / p.max_hp]
				for i in 130:
					await process_frame
				if game.state != game.State.MAP:
					game.enter_map()
				game.hud.close_dialogue()
			print(line)
	quit()
