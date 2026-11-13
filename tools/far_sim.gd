extends "res://tools/balance_sim.gd"
## Далекі краї: бот проходить кожну місцевість і печеру краю на її рівні та значно вище.
## Печери з босом міряються з героєм, тож час і шкода там мають бути схожі на будь-якому рівні; поле має
## сталий рівень, тож вище за нього воно легшає.
## Запуск: SIM_CLASS=cossack SIM_LEVELS=0,30,66 godot --headless --path . -s res://tools/far_sim.gd --fixed-fps 60
## Рівень 0 означає «рівень самого краю». SIM_LOCS=oleshky,zmiinyi — лише ці місця.
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://farsim.save"
	game.account_path = "user://farsim_acc.save"
	game.use_slots = false
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var levels := []
	for l in _env_list("SIM_LEVELS", ["0", "30", "66"]):
		levels.append(int(l))
	var all := []
	for id in Data.place_ids():
		if Data.place(id).has("region"):
			all.append(id)
	var locs: Array = _env_list("SIM_LOCS", all)
	for loc_id in locs:
		var L: Dictionary = Data.place(loc_id)
		var line := "%-16s (%2d+)" % [loc_id, int(L["level"])]
		for lv in levels:
			var lvl: int = int(L["level"]) if lv == 0 else lv
			if lvl < int(L["level"]):
				continue
			seed(1000 + lvl * 31 + hash(loc_id))
			var r: Dictionary = await _simulate(loc_id, lvl)
			line += " | рів.%2d %s %3.0fс шкода %3.0f%% досв/хв %6.0f грн/хв %5.0f" % [lvl, "ОК  " if r["cleared"] > 0.5 else ("СМЕРТЬ" if r["died"] > 0.5 else "ЧАС "), r["time"], r["dmg_pct"] * 100.0, r["xp_min"], r["gold_min"]]
		print(line)
	SaveSystem.delete("user://farsim.save")
	quit()
