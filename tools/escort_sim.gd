extends "res://tools/balance_sim.gd"
## Супровід (завдання міст): чи встигає герой свого рівня вберегти мандрівника.
## Бот-охоронець тримається біля мандрівника, б'є тих, хто до нього ближче, і п'є зілля, коли припече.
## Запуск:  godot --headless --path . -s res://tools/escort_sim.gd --fixed-fps 60
##   ESC_ONLY=rapids,polissia — лише ці місцевості;  ESC_POTIONS=0 — без зілля;  SIM_CLASS — клас героя (як у balance_sim).

var _aim = null


func _guard(p, c) -> void:
	var hud = game.hud
	var g = c.gate
	var from: Vector2 = g.global_position if g != null and is_instance_valid(g) and g.alive else p.global_position
	# Ціль тримаємо, доки жива: інакше бот метається між стрільцями й нікого не наздоганяє
	if _aim == null or not is_instance_valid(_aim) or _aim.dead:
		_aim = c.nearest_enemy(from, 5000.0)
	var en = _aim
	var dir = Vector2.ZERO
	if en:
		var to: Vector2 = en.global_position - p.global_position
		dir = to.normalized() if to.length() > p.attack_range * 0.7 else Vector2.ZERO
	elif g != null and is_instance_valid(g):
		var to2: Vector2 = g.global_position + Vector2(60, -50) - p.global_position
		dir = to2.normalized() if to2.length() > 30.0 else Vector2.ZERO
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.windup > 0.0 and e.windup < 0.2 and p.global_position.distance_to(e.global_position) < e.radius + 60.0:
			p.dodge()
	for t in c.effects.get_children():
		if t.has_method("contains") and t.contains(p.global_position):
			dir = (p.global_position - t.global_position).normalized()
			if t.duration - t._t < 0.35:
				p.dodge()
	hud.joystick.vector = dir
	hud.btn_attack.held = en != null
	if p.hp < p.max_hp * 0.4 and OS.get_environment("ESC_POTIONS") != "0":
		p.use_potion()  # жива людина п'є зілля, коли припече
	if en:
		for id in p.active_skills():
			if id == "first_aid" and p.hp > p.max_hp * 0.6:
				continue
			p.use_skill(id)


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://balance_sim.save"
	root.add_child(game)
	await process_frame
	var audio = root.get_node("Audio")
	audio.set_sound(false)
	audio.set_music(false)
	load("res://scripts/game/holiday_service.gd").forced = "none"
	var ES = load("res://scripts/game/escort_service.gd")
	var locs := ["wild_field", "rapids", "black_forest", "polissia", "chornohora", "kamianets_walls", "smolensk_road"]
	var only := OS.get_environment("ESC_ONLY")
	for loc_id in locs:
		if only != "" and not (loc_id in only.split(",")):
			continue
		var L: Dictionary = Data.LOCATIONS[loc_id]
		for dl in [-1, 0, 2]:
			var lvl: int = maxi(1, int(L["level"]) + dl)
			var wins := 0
			var deaths := 0
			var left := []
			var times := []
			var hurt := []
			var n := 6
			for s in n:
				seed(4409 * s + lvl * 17 + hash(loc_id))
				_build_hero(lvl)
				var p = game.player
				for k in ["escort", "defense", "combat", "block", "elite"]:
					game.world.hints[k] = true
				var q := {"id": 500 + s, "city": "sich", "loc": loc_id, "progress": 0, "lvl": int(L["level"]), "gold": 1, "xp": 1, "loyalty": 1}
				ES.fill(q, float(s % 4) / 4.0 + 0.01)
				game.world.quests.append(q)
				game.start_escort(q)
				var c = game.combat
				var t := 0.0
				var hp_prev: float = p.hp
				var dmg := 0.0
				while t < 240.0 and not c.defense_over and p.alive and game.state == game.State.PLAYING:
					_guard(p, c)
					await process_frame
					t += 1.0 / 60.0
					if p.hp < hp_prev:
						dmg += hp_prev - p.hp
					hp_prev = p.hp
				var won: bool = c.defense_over and c.field_cleared
				wins += 1 if won else 0
				deaths += 0 if p.alive else 1
				left.append(c.gate.hp / c.gate.max_hp if c.gate != null and is_instance_valid(c.gate) else 0.0)
				times.append(t)
				hurt.append(dmg / p.max_hp)
				if not p.alive:
					for i in 150:
						await process_frame
				for i in 200:
					await process_frame  # поразка: дочекатись повернення на мапу
				if game.state == game.State.PLAYING:
					game.enter_map()
				game.world = load("res://scripts/game/world_state.gd").new()
				await process_frame
			var a_left := 0.0
			var a_t := 0.0
			var a_h := 0.0
			for i in n:
				a_left += left[i] / n
				a_t += times[i] / n
				a_h += hurt[i] / n
			print("%-16s р.%2d герой %2d | довів %d/%d | у мандрівника лишилось %3.0f%% | бій %5.1f с | герой втратив %3.0f%% | смертей %d" % [loc_id, int(L["level"]), lvl, wins, n, a_left * 100.0, a_t, a_h * 100.0, deaths])
	quit()
