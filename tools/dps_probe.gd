extends "res://tools/balance_sim.gd"
## Справжня шкода героя за секунду: бот б'є одного незламного ворога (а потім гурт із п'яти) всім, що має,
## і ми міряємо, скільки здоров'я з них зійшло. Показує поруч оцінку Power.dps і еталон рівня (Data.ref_dps),
## бо формула Power.dps не бачить, наскільки вміння сильніші за удари.
## Запуск:  SIM_CLASS=perun_zhrets SIM_LEVELS=45,75 SIM_GEAR=good godot --headless --path . -s res://tools/dps_probe.gd --fixed-fps 60
## Наснага витрачається як у бою (зілля бот не п'є); DPS_MANA=full тримає її повною.
const Power := preload("res://scripts/game/power.gd")
const SECONDS := 20.0
const DUMMY_HP := 1.0e13

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://dps_probe.save"
	root.add_child(game)
	await process_frame
	root.get_node("Audio").set_sound(false)
	root.get_node("Audio").set_music(false)
	load("res://scripts/game/holiday_service.gd").forced = "none"
	var cls := OS.get_environment("SIM_CLASS")
	print("клас %s, спорядження %s" % [cls if cls != "" else "cossack", OS.get_environment("SIM_GEAR") if OS.get_environment("SIM_GEAR") != "" else "avg"])
	for l in _env_list("SIM_LEVELS", ["20", "45", "75", "99"]):
		var lvl := int(l)
		var one: float = await _measure(lvl, 1)
		var five: float = await _measure(lvl, 5)
		var p = game.player
		print("рівень %2d | по одному %8.0f/с (×%.2f еталона) | по гурту з п'яти %8.0f/с (×%.2f) | Power.dps %8.0f | сила вмінь %.2f" % [
			lvl, one, one / Data.ref_dps(lvl), five, five / Data.ref_dps(lvl), Power.dps(p), p.skill_power])
	SaveSystem.delete("user://dps_probe.save")
	quit()


## Скільки шкоди за секунду бот завдає n незламним ворогам разом.
func _measure(lvl: int, n: int) -> float:
	seed(700 + lvl * 13 + n)
	_build_hero(lvl)
	var p = game.player
	var c = game.combat
	game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "cleared": true, "char": true, "stones": true}
	game.enter_location("wild_field")
	for i in 3:
		await process_frame
	for e in c.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await process_frame
	var dummies := []
	for i in n:
		c.spawn_enemy("zarazhenyi", lvl, false, p.global_position + Vector2(90 + 30 * (i % 3), -40 + 40 * (i / 3)))
		var d = c._last_enemy()
		d.max_hp = DUMMY_HP
		d.hp = DUMMY_HP
		d.damage = 0.0
		d.speed = 0.0
		d.xp_value = 0
		dummies.append(d)
	var t := 0.0
	while t < SECONDS:
		c.spawn_timer = 999.0  # нова нечисть не заважає
		p.hp = p.max_hp
		if OS.get_environment("DPS_MANA") == "full":
			p.mana = p.max_mana  # DPS_MANA=full — без огляду на запас наснаги
		_bot(p, c)
		await process_frame
		t += 1.0 / 60.0
	var dealt := 0.0
	for d in dummies:
		if is_instance_valid(d):
			dealt += DUMMY_HP - d.hp
	for d in dummies:
		if is_instance_valid(d):
			d.queue_free()
	await process_frame
	if game.state == game.State.PLAYING:
		game.enter_map()
	game.world = load("res://scripts/game/world_state.gd").new()
	return dealt / SECONDS
