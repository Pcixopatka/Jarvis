extends "res://tools/balance_sim.gd"
## Надважкі печери: бот-герой 99-го рівня проходить кожну печеру у справжній грі.
## Показує, чи доходить він до боса, скільки триває бій із босом і скільки здоров'я це коштує.
##
## Запуск: SIM_CLASS=zaporozhets godot --headless --path . -s res://tools/peril_sim.gd --fixed-fps 60
##   PERIL_LOCS=devova_ushchelyna,khalyna_planyna   лише ці печери
##   PERIL_GEAR=best | prev | own    спорядження: найкраще 99-го рівня; з попередньої печери; з цієї самої печери
##   PERIL_SEEDS=2                   прогонів на печеру
##   PERIL_LIMIT=900                 секунд на один похід

const PerilS := preload("res://scripts/game/peril_service.gd")


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://perilsim.save"
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	var locs: Array = _env_list("PERIL_LOCS", PerilS.ids())
	var gear: String = OS.get_environment("PERIL_GEAR") if OS.get_environment("PERIL_GEAR") != "" else "best"
	var seeds: int = int(OS.get_environment("PERIL_SEEDS")) if OS.get_environment("PERIL_SEEDS") != "" else 2
	var limit: float = float(OS.get_environment("PERIL_LIMIT")) if OS.get_environment("PERIL_LIMIT") != "" else 900.0
	print("Клас: %s, спорядження: %s" % [OS.get_environment("SIM_CLASS") if OS.get_environment("SIM_CLASS") != "" else "cossack", gear])
	for loc_id in locs:
		var L: Dictionary = Data.place(loc_id)
		for s in seeds:
			seed(977 * s + hash(loc_id))
			_build_hero(99)
			var p = game.player
			var ilvl := 99
			if gear == "prev":
				ilvl = maxi(99, int(L["level"]) - 10)
			elif gear == "own":
				ilvl = int(L["level"])
			_regear(p, ilvl, 3, Data.MAX_UPGRADE, true)
			p.hp = p.max_hp
			p.mana = p.max_mana
			p.potions = p.potion_max()
			game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "enrage": true}
			var Power = load("res://scripts/game/power.gd")
			var dps0: float = Power.dps(p)
			var ehp0: float = Power.ehp(p)
			var v0: int = p.valor_xp + p.valor * 1000000000
			game.enter_location(loc_id)
			var c = game.combat
			var t := 0.0
			var dmg := 0.0
			var hp_prev: float = p.hp
			var pots0: int = p.potions
			var boss_t := 0.0
			var boss_left := 1.0
			var enr := 0
			var done := false
			while t < limit:
				if game.state == game.State.PLAYING:
					_bot(p, c)
				await process_frame
				t += 1.0 / 60.0
				if p.hp < hp_prev:
					dmg += hp_prev - p.hp
				hp_prev = p.hp
				for e in c.get_tree().get_nodes_in_group("enemies"):
					if e.is_boss and not e.illusion and float(e.enrage_after) > 0.0 and not e.dead:
						boss_t += 1.0 / 60.0
						boss_left = float(e.hp) / maxf(1.0, float(e.max_hp))
						enr = int(e.enrage_n)
				if not p.alive or game.state == game.State.DEAD:
					break
				if game.world.cleared.get(loc_id, 0) > 0 or game.state == game.State.MAP:
					done = true
					boss_left = 0.0
					break
			var room: int = int(c.room)
			var res := "ПРОЙДЕНО" if done else ("СМЕРТЬ" if not p.alive else "ЧАС ВИЙШОВ")
			print("%-24s рів. %3d | речі %3d | шкода/с %7.0f, живучість %7.0f | %-10s | кімната %d/%d | %4.0f с | бій із босом %4.0f с, у боса лишилось %3.0f%%, лють ×%d | отримано шкоди %4.1f здоров'їв | зілля %d | досвід/хв %7.0f" % [
				L["name"], int(L["level"]), ilvl, dps0, ehp0, res, room, int(L["rooms"]), t, boss_t, boss_left * 100.0, enr,
				dmg / maxf(1.0, p.max_hp), pots0 - int(p.potions), float(p.valor_xp + p.valor * 1000000000 - v0) / maxf(t / 60.0, 0.01)])
			for i in 150:
				await process_frame
			get_root().get_tree().paused = false
			if game.state == game.State.PLAYING:
				game.enter_map()
			game.world = load("res://scripts/game/world_state.gd").new()
	quit()
