extends "res://tools/escort_sim.gd"
## Події з хвилями: облога міста, набіг на село, облога Січі, напад на валку, супровід.
## Бот-охоронець свого рівня боронить браму, хати, вози чи мандрівника. Показує, чи встигає,
## скільки лишилось у того, що він боронив, скільки тривав бій і скільки здоров'я втратив герой.
## Запуск:  SIM_LEVELS=20,45,74 godot --headless --path . -s res://tools/event_sim.gd --fixed-fps 60
##   EV_KINDS=siege,village_raid,sich_siege,ambush,escort — лише ці події;  SIM_SEEDS — скільки боїв на рядок;
##   EV_NOLIFT=1 — без мірки героя (як було до 0.36.0), щоб порівняти;  SIM_CLASS — клас героя (як у balance_sim).


func _loc_for(kind: String, p) -> Dictionary:
	var w = game.world
	match kind:
		"siege":
			return game.DefenseService.battle_loc(w, "chyhyryn", p)
		"ambush":
			return game.TradeService.battle_loc(w, "kyiv", p)
		"escort":
			var q := {"id": 900, "city": "sich", "loc": "black_forest", "progress": 0, "lvl": 4, "gold": 1, "xp": 1, "loyalty": 1}
			game.EscortService.fill(q, 0.3)
			w.quests.append(q)
			return game.EscortService.battle_loc(q, p)
	game.EventService.start(w, p, kind, "sich" if kind == "sich_siege" else "black_forest")
	return game.EventService.battle_loc(w, game.EventService.active(w), p)


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://balance_sim.save"
	root.add_child(game)
	await process_frame
	var audio = root.get_node("Audio")
	audio.set_sound(false)
	audio.set_music(false)
	load("res://scripts/game/holiday_service.gd").forced = "none"
	var Far = load("res://scripts/game/far_service.gd")
	var nolift := OS.get_environment("EV_NOLIFT") == "1"
	var n := int(OS.get_environment("SIM_SEEDS")) if OS.get_environment("SIM_SEEDS") != "" else 2
	for kind in _env_list("EV_KINDS", ["siege", "village_raid", "escort"]):
		for l in _env_list("SIM_LEVELS", ["20", "45", "74"]):
			var lvl := int(l)
			var wins := 0
			var deaths := 0
			var a_left := 0.0
			var a_t := 0.0
			var a_h := 0.0
			var note := ""
			for s in n:
				seed(7717 * s + lvl * 13 + hash(kind))
				_build_hero(lvl)
				var p = game.player
				game.world.missions = {}
				game.QuestEngine.place_at(game.world, "rada", "active")  # розділ IV: «Похід на Північ»
				for k in ["escort", "defense", "combat", "block", "elite", "ambush", "event_village_raid", "event_sich_siege", "boss", "item"]:
					game.world.hints[k] = true
				var L: Dictionary = _loc_for(kind, p)
				var guard: float = Far.guard_mult(int(L["level"]), L)
				note = "рів. нечисті %d, мірка ×%.1f до удару" % [int(L["level"]), guard]
				if nolift:
					L["gate_hp"] = float(L["gate_hp"]) / guard
					L.erase("min_std_hp")
					L.erase("min_std_dmg")
				game.combat.defense_loc = L
				game.enter_location("defense")
				var c = game.combat
				_aim = null
				var t := 0.0
				var hp_prev: float = p.hp
				var dmg := 0.0
				while t < 300.0 and not c.defense_over and p.alive and game.state == game.State.PLAYING:
					_guard(p, c)
					await process_frame
					t += 1.0 / 60.0
					if p.hp < hp_prev:
						dmg += hp_prev - p.hp
					hp_prev = p.hp
				wins += 1 if c.defense_over and c.field_cleared else 0
				deaths += 0 if p.alive else 1
				a_left += (c.gate.hp / c.gate.max_hp if c.gate != null and is_instance_valid(c.gate) else 0.0) / n
				a_t += t / n
				a_h += dmg / p.max_hp / n
				for i in 330:
					await process_frame  # дочекатись повернення на мапу
				if game.state == game.State.PLAYING:
					game.enter_map()
				game.world = load("res://scripts/game/world_state.gd").new()
				await process_frame
			print("%-13s герой %2d %s| виграно %d/%d | у оборонюваного лишилось %3.0f%% | бій %5.1f с | герой втратив %3.0f%% здоров'я | смертей %d | %s" % [kind, lvl,
				"(без мірки) " if nolift else "", wins, n, a_left * 100.0, a_t, a_h * 100.0, deaths, note])
	quit()
