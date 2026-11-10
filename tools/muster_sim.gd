extends "res://tools/balance_sim.gd"
## Гетьманський огляд: бот заданого рівня з побратимами чи без б'ється з кожною сотнею в кожній сутичці.
## Запуск: SIM_CLASS=cossack SIM_LEVELS=8,30,66 SIM_ALLIES=0,3 godot --headless --path . -s res://tools/muster_sim.gd --fixed-fps 60
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://mustersim.save"
	game.account_path = "user://mustersim_acc.save"
	game.use_slots = false
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var Acts = load("res://scripts/data/activities.gd")
	var MS = game.MusterService
	var levels := []
	for l in _env_list("SIM_LEVELS", ["8", "30", "66"]):
		levels.append(int(l))
	for lvl in levels:
		for al in _env_list("SIM_ALLIES", ["0", "3"]):
			for tid in Acts.MUSTER_ORDER:
				var line := "рів. %2d  побратимів %s  %-20s" % [lvl, al, Acts.MUSTER_TEAMS[tid]["name"]]
				for r in 3:
					_build_hero(lvl)
					var p = game.player
					game.world.muster = {}
					game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "duel": true, "muster": true, "city": true, "stones": true}
					game.world.companions = []
					for i in int(al):
						game.world.companions.append({"type": ["dzhura", "strilets", "znakhar"][i % 3], "downed": false, "level": maxi(1, lvl - 2), "xp": 0})
					var L: Dictionary = MS.battle_loc(game.world, p)
					var n: int = MS.team_size(r, MS.allies(game.world))
					L["team"] = MS.fighters(tid, n)
					L["round"] = r
					var secs: float = float(Acts.MUSTER_SECONDS[r])
					L["rival_hp"] = load("res://scripts/game/power.gd").dps(p) * secs
					L["rival_cap"] = 1.0 / (0.5 * secs)
					L["rival_dmg"] = load("res://scripts/game/power.gd").hit(p, float(Acts.MUSTER_HIT[r]) * game.DuelService.hit_scale(p.level))
					L["ally_hit"] = float(Acts.MUSTER_ALLY_HIT[r])
					game.combat.defense_loc = L
					game.enter_location("duel")
					var t := 0.0
					var low: float = p.max_hp
					var taken := 0.0
					var prev: float = p.hp
					while t < 240.0 and p.alive and not game.combat.duel_over:
						_bot(p, game.combat)
						await process_frame
						t += 1.0 / 60.0
						low = minf(low, p.hp)
						if p.hp < prev:
							taken += prev - p.hp
						prev = p.hp
					var won: bool = game.combat.duel_over
					var up := 0
					for cn in game.combat.companion_nodes:
						if is_instance_valid(cn) and cn.alive:
							up += 1
					line += " | %d(%d): %s %3.0fс мін %3.0f%% отр %3.0f%% своїх %d" % [r + 1, n, "ПЕРЕМ" if won else ("ПОРАЗ" if not p.alive else "ЧАС  "), t, 100.0 * maxf(low, 0.0) / p.max_hp, 100.0 * taken / p.max_hp, up]
					for i in 130:
						await process_frame
					if game.state != game.State.CITY:
						game.enter_city("chyhyryn")
					game.hud.close_dialogue()
				print(line)
	quit()
