extends "res://tools/balance_sim.gd"
## Знімки екрана для сторінки гри в Google Play: docs/store/screenshots/01…08.png.
## Потрібне справжнє вікно; на сервері без екрана — через xvfb:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --resolution 2560x1440 -s res://tools/store_shots.gd
## Знімки 2560×1440: 16:9 і рівно вдвічі більші за полотно гри, тож пікселі спрайтів лишаються рівними.
## Герой, загін і вороги ставляться кодом, а бої веде бот із balance_sim, тому набір можна перезняти після змін у грі.

const OUT := "res://docs/store/screenshots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String, keep_banner: bool = false) -> void:
	if not keep_banner:
		game.hud.banner.text = ""  # «Рівень 9!» після складання героя в кадрі зайвий
	game.hud.hint_panel.visible = false
	await _frames(2)
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)  # магазин не приймає знімків із прозорістю
	img.save_png(ProjectSettings.globalize_path(OUT) + name + ".png")
	print("знято ", name, " ", img.get_size())


## Герой потрібного класу й рівня; підказки вимкнено, щоб не лізли в кадр.
func _hero(cls: String, lvl: int) -> void:
	OS.set_environment("SIM_CLASS", cls)
	_build_hero(lvl)
	var w = game.world
	for k in ["city", "combat", "map", "camp", "block", "elite", "boss", "item", "cleared", "defense", "trail", "hunt", "escort", "vii_gaze", "mana", "status", "charge", "parry", "skills", "class"]:
		w.hints[k] = true
	w.story = {"chapter": 3, "step": 0, "stage": "active", "progress": 0}
	game.hud.hint_panel.visible = false
	game.player.gold = 1840


func _fight(seconds: float) -> void:
	var t := 0.0
	while t < seconds and game.state == game.State.PLAYING and game.player.alive:
		_bot(game.player, game.combat)
		game.player.hp = maxf(game.player.hp, game.player.max_hp * 0.6)
		await process_frame
		t += 1.0 / 60.0
	game.hud.hint_panel.visible = false


func _clear_enemies() -> void:
	for e in game.combat.get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()


func _ready_skills() -> void:
	var p = game.player
	for id in p.skill_timers:
		p.skill_timers[id] = 0.0
	p.mana = p.max_mana


## Розставити нечисть довкола героя: spots — [[вид, зсув від героя, еліта?], ...].
func _stage(spots: Array, lvl: int) -> Array:
	var c = game.combat
	var out := []
	for sp in spots:
		c.spawn_enemy(sp[0], lvl, false, game.player.global_position + sp[1])
		var e = c._last_enemy()
		if sp.size() > 2 and sp[2]:
			e.make_elite(load("res://scripts/data/elites.gd").roll_affixes(lvl))
		# Міцні, щоб дожили до знімка: герой для кадру сильніший за місцевість
		e.max_hp *= 40.0
		e.hp = e.max_hp
		out.append(e)
	return out


## Кілька секунд бою, потім вихор шаблі — і знімок, поки ефект у кадрі.
func _clash(name: String, seconds: float) -> void:
	var p = game.player
	var t := 0.0
	while t < seconds:
		game.hud.btn_attack.held = true
		p.hp = p.max_hp
		for comp in game.combat.companion_nodes:
			if is_instance_valid(comp):
				comp.hp = comp.max_hp
		await process_frame
		t += 1.0 / 60.0
	_ready_skills()
	p.use_skill("whirl")
	await _frames(5)
	await _shot(name)
	game.hud.btn_attack.held = false
	game.hud.joystick.vector = Vector2.ZERO


func _tab(title: String) -> void:
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		if tc.get_tab_title(i).begins_with(title):
			tc.current_tab = i


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	load("res://scripts/game/holiday_service.gd").forced = "none"
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://store_shots.save"
	game.account_path = "user://store_shots_account.save"
	game.use_slots = false
	root.add_child(game)
	await _frames(3)
	var audio = root.get_node("Audio")
	audio.set_sound(false)
	audio.set_music(false)
	root.get_node("Ads").instant = true
	var p
	var c

	# 1. Бій у пущі: козак із загоном, вихор шаблі серед зграї
	seed(11)
	_hero("cossack", 9)
	game.world.companions = [{"type": "dzhura", "downed": false}, {"type": "znakhar", "downed": false}]
	game.enter_location("bilovezha")
	await _frames(20)
	_clear_enemies()
	p = game.player
	p.global_position = Vector2(-300, 120)
	await _frames(20)
	_stage([["vovkulaka", Vector2(-120, -70)], ["upyr", Vector2(110, -90)], ["mavka", Vector2(170, 30)], ["vovkulaka", Vector2(-150, 60), true],
		["upyr", Vector2(40, 130)], ["mavka", Vector2(-40, -150)], ["vovkulaka", Vector2(250, -120)], ["upyr", Vector2(-260, -40)]], 8)
	await _clash("01_battle", 1.3)

	# 2. Бос: Вій підіймає повіки
	game.enter_map()
	await _frames(3)
	seed(5)
	_hero("molfar", 22)
	game.enter_location("vii_church")
	await _frames(3)
	_clear_enemies()
	await _frames(2)
	p = game.player
	c = game.combat
	p.global_position = Vector2(180, 60)
	game.hud.joystick.vector = Vector2.ZERO
	game.hud.btn_attack.held = false
	c.spawn_enemy("vii", 15, true, p.global_position + Vector2(-290, -70))
	var boss = c._last_enemy()
	boss.ability_timer = 999.0
	boss.mechanic.rock_timer = 999.0
	boss.speed = 0.0
	boss.mechanic.start_gaze(p, (p.global_position - boss.global_position).normalized())
	for b in boss.mechanic.lid_bearers:
		b.speed = 0.0
		b.max_hp *= 50.0  # повікарі мають дожити до знімка, інакше погляд обірветься
		b.hp = b.max_hp
	await _frames(50)
	await _shot("02_boss")

	# 3. Мапа земель
	game.enter_map()
	await _frames(3)
	seed(3)
	_hero("cossack", 9)
	game.world.board("kyiv")
	for q in game.world.board("kyiv").duplicate():
		game.world.take("kyiv", q["id"])
	game.enter_map()
	await _frames(3)
	game._on_map_select("black_forest")
	await _frames(6)
	await _shot("03_map")

	# 4. Місто: крамниця
	game.enter_city("kyiv")
	await _frames(4)
	_tab("Крамниця")
	await _frames(4)
	await _shot("04_city")

	# 5. Хутір: город із грядками
	game.world.camp["buildings"] = {"kurin": 2, "kuznia": 2, "zillia": 1, "pasika": 2, "horod": 2}
	p = game.player
	p.resources = {"wood": 46, "iron": 21, "herbs": 17, "trophy": 6}
	var GS = load("res://scripts/game/garden_service.gd")
	var crops: Array = load("res://scripts/data/camp_data.gd").crop_ids()
	for i in GS.beds_count(game.world):
		GS.plant(game.world, p, i, crops[i % crops.size()])
	game.enter_camp()
	await _frames(4)
	_tab("Город")
	await _frames(6)
	await _shot("05_camp")

	# 6. Дерево вмінь
	game.enter_map()
	await _frames(3)
	_hero("kharakternyk", 26)
	game.char_tab = 2
	game.open_character()
	await _frames(6)
	await _shot("06_skills")
	game.close_character()
	await _frames(3)

	# 7. Полювання
	game.enter_map()
	await _frames(3)
	seed(21)
	game.start_hunt()
	await _frames(10)
	var hg = game.hud.screen_root
	for i in 900:
		if hg.animal != "" and absf(hg.pos.x - hg.field().get_center().x) < 60.0:
			break
		await process_frame
	await _shot("07_hunt")
	game._quit_activity()
	await _frames(3)

	# 8. Оборона міста: нечисть під брамою
	seed(8)
	_hero("zaporozhets", 24)
	game.world.companions = [{"type": "strilets", "downed": false}, {"type": "dzhura", "downed": false}]
	game.world.defense = {"sieges": {"kyiv": 3}, "ruined": {}, "won": 0, "lost": 0, "calm": 3}
	game.start_defense("kyiv")
	await _frames(30)
	p = game.player
	c = game.combat
	p.global_position = c.gate.global_position + Vector2(-40, -230)
	c.wave = 2
	c.wave_timer = 99.0
	await _frames(20)
	var foes := _stage([["zarazhenyi", Vector2(-170, -120)], ["pishchalnyk", Vector2(-330, -240)], ["chort", Vector2(140, -110)], ["zarazhenyi", Vector2(260, -30)],
		["vovkulaka", Vector2(-60, -190)], ["zarazhenyi", Vector2(330, -220), true], ["zarazhenyi", Vector2(-300, 20)], ["pishchalnyk", Vector2(60, -300)]], 22)
	for i in foes.size():
		foes[i].rams_gate = i % 2 == 1
	await _clash("08_defense", 1.3)
	SaveSystem.delete("user://store_shots.save")
	SaveSystem.delete("user://store_shots_account.save")
	quit()
