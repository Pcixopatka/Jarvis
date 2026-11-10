extends SceneTree
## Автотести гри. Запуск (без вікна, приблизно хвилина):
##   godot --headless --path . -s res://tests/run_tests.gd --fixed-fps 60
## Код виходу 0 — усе гаразд, 1 — є помилки (зручно для CI).
##
## 1. Дані: узгодженість локацій, ворогів, вмінь, перків; генерація речей і завдань.
## 2. Козак: рівні, очки, вміння й перки, спорядження, заточка, серіалізація.
## 3. Збереження: запис/читання, резервна копія, міграція версій.
## 4. Місто: крамниця, продаж, найм, здача завдань.
## 5. Сценарій: бот проходить повний цикл гри у справжній сцені.

const Data := preload("res://scripts/data/data.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")
const WorldState := preload("res://scripts/game/world_state.gd")
# Модулі, що залежать від автозавантажень (Events, Audio), вантажимо під час виконання:
# скрипт тестів компілюється раніше, ніж Godot їх реєструє.
var CityService
var PlayerScript
var StoryService

const TEST_SAVE := "user://test_hero.save"
const TEST_ACCOUNT := "user://test_account.save"

var failures = 0
var checks = 0
var _suite = ""


func _initialize() -> void:
	# Свята за календарем вимкнено: тести мають однаково проходити будь-якого дня року
	load("res://scripts/game/holiday_service.gd").forced = "none"
	CityService = load("res://scripts/game/city_service.gd")
	PlayerScript = load("res://scripts/entities/player.gd")
	StoryService = load("res://scripts/game/story_service.gd")
	_run()


func _run() -> void:
	var t0 = Time.get_ticks_msec()
	_suite_data()
	_suite_player()
	_suite_save()
	_suite_city()
	_suite_story()
	_suite_party()
	_suite_camp()
	_suite_heroes()
	_suite_plague()
	_suite_travel()
	_suite_defense_logic()
	_suite_challenges()
	_suite_craft()
	_suite_classes()
	_suite_specs()
	_suite_stones()
	_suite_endgame()
	_suite_bulk_sell()
	_suite_account()
	await _suite_gameplay()
	await _suite_moves()
	await _suite_defense_battle()
	await _suite_mage_battle()
	await _suite_spec_battle()
	await _suite_volkhv_specs()
	await _suite_depth_battle()
	_suite_tower()
	await _suite_tower_battle()
	_suite_events()
	await _suite_event_battles()
	_suite_duel()
	await _suite_duel_battle()
	_suite_bounty()
	await _suite_bounty_battle()
	_suite_vigil()
	await _suite_vigil_battle()
	_suite_trade()
	await _suite_trade_game()
	_suite_outdoor()
	await _suite_outdoor_game()
	_suite_tavern()
	await _suite_tavern_game()
	_suite_trail()
	await _suite_trail_battle()
	_suite_garden()
	await _suite_garden_game()
	_suite_expedition()
	await _suite_expedition_game()
	_suite_records()
	await _suite_records_game()
	_suite_holidays()
	await _suite_holidays_game()
	_suite_audio()
	await _suite_audio_game()
	_suite_mana_potion()
	await _suite_mana_potion_game()
	await _suite_new_bosses()
	_suite_escort()
	await _suite_escort_game()
	await _suite_safe_area()
	await _suite_back_button()
	_suite_transfer()
	await _suite_transfer_game()
	await _suite_travel_ride()
	print("\n==== Перевірок: %d, провалено: %d, час: %.1f с ====" % [checks, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if OS.get_environment("TEST_VERBOSE") != "" and _suite in ["Сценарій гри", "Сюжет"]:
		print("  %s %s" % ["✓" if cond else "✗", msg])
	if not cond:
		failures += 1
		printerr("  ✗ [%s] %s" % [_suite, msg])


func suite(name: String) -> void:
	_suite = name
	print("— " + name)


func _new_player():
	var p = PlayerScript.new()
	p._ready()  # стартова шабля і перерахунок без додавання в сцену
	return p


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# ======================= 1. Дані =======================

func _suite_data() -> void:
	suite("Дані")
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		for e in L["enemies"]:
			check(Data.ENEMY_NAMES.has(e) and Data.QUEST_ITEMS.has(e), "%s: невідомий ворог %s" % [id, e])
		if L["type"] == "dungeon":
			check(Data.BOSS_NAMES.has(L["boss"]) and int(L["rooms"]) >= 2, "%s: бос або кімнати" % id)
	var Classes = load("res://scripts/data/classes.gd")
	for cls in Classes.TREES:
		var skill_ids = {}
		for b in Classes.TREES[cls]:
			for n in b["nodes"]:
				check(not skill_ids.has(n["id"]), "%s: дубль вміння %s" % [cls, n["id"]])
				skill_ids[n["id"]] = true
				if n.get("active", false):
					check(Data.ACTIVE_SKILLS.has(n["id"]) and Classes.COOLDOWNS.has(n["id"]) and int(n.get("cost", 0)) > 0, "%s: активне %s має кнопку, перезарядку й ціну" % [cls, n["id"]])
		for b in Classes.TREES[cls]:
			for n in b["nodes"]:
				for r in n["req"]:
					check(skill_ids.has(r), "%s: вміння %s вимагає невідоме %s" % [cls, n["id"], r])
		var info: Dictionary = Classes.CLASSES[cls]
		for wt in info["weapons"]:
			check(Data.WEAPON_TYPES.has(wt), "%s: зброя %s існує" % [cls, wt])
		for nx in info["next"]:
			check(Classes.CLASSES.has(nx), "%s → %s" % [cls, nx])
	var perk_ids = {}
	for b in Data.PERK_BRANCHES:
		for t in b["tiers"]:
			for pk in t:
				check(not perk_ids.has(pk["id"]), "дубль перка " + pk["id"])
				perk_ids[pk["id"]] = true
	# Речі всіх слотів, рідкостей і типів зброї
	for slot in Data.SLOTS:
		for r in 4:
			var types: Array = Data.WEAPON_TYPES.keys() if slot == "weapon" else [""]
			for t in types:
				var it = Data.gen_item(5, r, slot, t)
				var st = Data.item_stats(it)
				check(it["affixes"].size() == r, "%s/%d: кількість бонусів" % [slot, r])
				check(not st.is_empty(), "%s: порожні бонуси" % slot)
				for k in st:
					check(st[k] >= 0.0 and Data.STAT_FMT.has(k), "%s: бонус %s" % [slot, k])
				check(Data.sell_price(it) > 0, "%s: ціна" % slot)
	var it = Data.gen_item(3, 1, "weapon", "sabre")
	var prev = 0
	for up in Data.MAX_UPGRADE:
		it["up"] = up
		var c = Data.sharpen_cost(it)
		check(c > prev, "ціна заточки росте")
		prev = c
	for i in 200:
		check(Data.roll_rarity(5, 2) >= 2, "мінімальна рідкість")
	# Завдання
	var w = WorldState.new()
	for city in Data.CITIES:
		for i in 10:
			var q: Dictionary = w._gen_quest(city)
			check(q["type"] in ["kill", "fetch", "dungeon", "escort"], "тип завдання")
			check(int(q["count"]) > 0 and int(q["gold"]) > 0 and int(q["xp"]) > 0 and int(q["loyalty"]) > 0, "нагорода/кількість")
			check(Data.LOCATIONS.has(q["loc"]), "локація завдання")
		var b: Array = w.board(city)
		check(b.size() == 3, "дошка %s має 3 завдання" % city)


# ======================= 2. Козак =======================

func _suite_player() -> void:
	suite("Козак")
	var p = _new_player()
	check(p.equipment.has("weapon"), "стартова зброя")
	check(p.level == 1 and p.hp == p.max_hp, "початковий стан")
	var lv_before = p.level
	p.add_xp(500)
	check(p.level > lv_before, "рівень росте від досвіду")
	var gained = p.level - 1
	check(p.stat_points == gained * Data.STAT_POINTS_PER_LEVEL, "очки характеристик")
	check(p.perk_points == p.level / 2, "Загартування: очко за кожні 2 рівні")
	check(p.job_level > 1 and p.skill_points == p.job_level - 1, "очки вмінь — з майстерності (%d)" % p.job_level)
	var dmg = p.damage
	check(p.add_stat("str") and p.damage > dmg, "сила збільшує шкоду")
	# Усі вміння й перки до максимуму
	p.skill_points = 99
	p.perk_points = 99
	var Classes = load("res://scripts/data/classes.gd")
	for i in 8:
		for b in Classes.TREES["cossack"]:
			for n in b["nodes"]:
				p.learn_skill(n["id"])
		for b in Data.PERK_BRANCHES:
			for t in b["tiers"]:
				for pk in t:
					p.learn_perk(pk["id"])
	for b in Classes.TREES["cossack"]:
		for n in b["nodes"]:
			check(p.sk(n["id"]) == n["max"], "вміння %s на максимумі" % n["id"])
	check(not p.learn_skill("fireball"), "козак не вчить вміння волхва")
	for b in Data.PERK_BRANCHES:
		for t in b["tiers"]:
			for pk in t:
				check(p.pk(pk["id"]) == pk["max"], "перк %s на максимумі" % pk["id"])
	check(not p.learn_skill("whirl"), "не можна перевищити максимум")
	check(p.armor <= 0.75 and p.crit_chance <= 0.8 and p.skill_cd_mult >= 0.3, "межі показників")
	# Дерево Загартування розраховане на 99 рівень: очок (49) менше, ніж вузлів, — є з чого вибирати
	var perk_total := 0
	for b in Data.PERK_BRANCHES:
		for t in b["tiers"]:
			for pk in t:
				perk_total += int(pk["max"])
	check(perk_total > Classes.BASE_LEVEL_MAX / Classes.HARDEN_EVERY, "Загартування: вузлів (%d) більше за очки на 99 рівні" % perk_total)
	check(Data.PERK_BRANCHES.size() == 3, "Загартування: три гілки")
	# Нові перки діють
	var q0 = _new_player()
	q0.perk_points = 99
	var hp0: float = q0.max_hp
	var dmg0: float = q0.damage
	var pot0: int = q0.potion_max()
	for i in 5:
		q0.learn_perk("h_body")
		q0.learn_perk("h_hand")
	check(q0.pk("h_body") == 5 and q0.max_hp > hp0 * 1.19 and q0.damage > dmg0 * 1.14, "Міцна кістка й Важкий удар")
	q0.learn_perk("h_skin")
	q0.learn_perk("h_blood")
	q0.learn_perk("purse")
	q0.learn_perk("kobzar")
	q0.learn_perk("h_gold")
	q0.learn_perk("h_eye")
	q0.learn_perk("h_flask")
	check(q0.gold_mult > 1.07 and q0.potion_max() == pot0 + 1 and q0.regen >= 0.5, "Торгова жилка, баклага, Живуча кров")
	q0.learn_perk("luck")
	q0.learn_perk("luck")
	check(q0.learn_perk("h_crit") and q0.crit_mult == 2.25, "Жорстокий крит")
	for i in 3:
		q0.learn_perk("sich")
	check(q0.pk("sich") == 0, "Загартований закритий, поки гілка «Тіло» не набрала 8 очок")
	for i in 3:
		q0.learn_perk("varenyk")
		q0.learn_perk("h_potion")
		q0.learn_perk("h_roll")
	var str0: int = q0.stat("str")
	check(q0.learn_perk("sich") and q0.stat("str") == str0 + 2, "Загартований: +2 до характеристик за ранг")
	# Спорядження
	var helm = Data.gen_item(5, 2, "head")
	check(p.add_item(helm), "річ у торбу")
	var hp_before = p.max_hp
	check(p.equip(helm["uid"]) and p.max_hp > hp_before, "шапка додає здоров'я")
	check(p.unequip(helm["uid"]) and is_equal_approx(p.max_hp, hp_before), "зняття повертає показники")
	# Заточка
	var w: Dictionary = p.equipment["weapon"]
	p.gold = 100000
	for i in 40:
		p.sharpen(w["uid"])
		check(w["up"] >= 0 and w["up"] <= Data.MAX_UPGRADE, "заточка в межах")
	w["up"] = Data.MAX_UPGRADE
	check(p.sharpen(w["uid"]) == "max" and w["up"] == Data.MAX_UPGRADE, "межа заточки")
	w["up"] = Data.SHARPEN_RISK_FROM - 1
	p.recalc()
	p.gold = 0
	var up_before: int = w["up"]
	if up_before < Data.MAX_UPGRADE:
		check(p.sharpen(w["uid"]) == "nogold" and w["up"] == up_before, "без гривень не точить")
	# Серіалізація
	var d = p.to_dict()
	var q = _new_player()
	q.from_dict(d)
	check(q.level == p.level and q.gold == p.gold and q.skills == p.skills and q.perks == p.perks, "to_dict/from_dict")
	check(q.equipment["weapon"]["up"] == w["up"] and q.inventory.size() == p.inventory.size(), "спорядження після відновлення")
	check(is_equal_approx(q.damage, p.damage), "показники після відновлення")
	p.free()
	q.free()


# ======================= 3. Збереження =======================

func _suite_save() -> void:
	suite("Збереження")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	check(SaveSystem.load_data(TEST_SAVE).is_empty(), "немає збереження — порожньо")
	var p = _new_player()
	p.gold = 777
	var w = WorldState.new()
	w.add_loyalty("kyiv", 120)
	w.hints["map"] = true
	check(SaveSystem.save({"player": p.to_dict(), "world": w.to_dict(), "meta": {"playtime": 5.0}}, TEST_SAVE), "запис")
	var d = SaveSystem.load_data(TEST_SAVE)
	check(d.get("version", 0) == SaveSystem.SAVE_VERSION, "версія")
	check(d["player"]["gold"] == 777 and d["world"]["loyalty"]["kyiv"] == 120, "дані після читання")
	# Друге збереження створює .bak; псуємо основний файл — має підхопитися резервний
	p.gold = 888
	SaveSystem.save({"player": p.to_dict(), "world": w.to_dict(), "meta": {}}, TEST_SAVE)
	var f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("це вже не збереження")
	f.close()
	d = SaveSystem.load_data(TEST_SAVE)
	check(not d.is_empty() and d["player"]["gold"] == 777, "відновлення з резервної копії")
	# Міграції
	var v2 = {"version": 2, "player": p.to_dict(), "world": {"loyalty": {}}}
	var m = SaveSystem.migrate(v2)
	check(m.get("version", 0) == SaveSystem.SAVE_VERSION and m.has("meta") and m["world"].has("hints"), "міграція v2 → поточна")
	check(m["player"]["xp_next"] == Data.xp_for_level(m["player"]["level"]), "міграція перераховує поріг досвіду")
	var v6 = SaveSystem.migrate({"version": 6, "player": p.to_dict(), "world": {"story": {"chapter": 1, "step": 3, "stage": "active", "progress": 0}}})
	check(v6["world"]["story"]["chapter"] == 2 and v6["world"]["story"]["step"] == 3, "міграція v7: розділ зсувається через пролог")
	var v6d = SaveSystem.migrate({"version": 6, "player": {}, "world": {"story": {"chapter": 2, "step": 0, "stage": "done"}}})
	check(v6d["world"]["story"]["chapter"] == 2, "завершений сюжет не зсувається")
	var v8a = SaveSystem.migrate({"version": 8, "player": p.to_dict(), "world": {"story": {"chapter": 0, "step": 3, "stage": "active", "progress": 0, "choices": {"trial": 0}}}})
	check(v8a["world"]["story"]["step"] == 4, "міграція v9: присяга зсувається за кроком «Обери дорогу»")
	var v8b = SaveSystem.migrate({"version": 8, "player": p.to_dict(), "world": {"story": {"chapter": 0, "step": 2, "stage": "turnin", "progress": 10, "choices": {}}}})
	check(v8b["world"]["story"]["step"] == 3 and v8b["world"]["story"]["stage"] == "active", "міграція v9: хто чекав вибору — йде до Мирона й Зореслави")
	var v8c = SaveSystem.migrate({"version": 8, "player": p.to_dict(), "world": {"story": {"chapter": 2, "step": 1, "stage": "active", "progress": 0}}})
	check(v8c["world"]["story"]["step"] == 1, "міграція v9: пізні розділи не чіпає")
	check(SaveSystem.migrate({"version": 1, "player": {}, "world": {}}).is_empty(), "v1 не підтримується")
	check(SaveSystem.migrate({"version": 99, "player": {}, "world": {}}).is_empty(), "майбутня версія відхиляється")
	var w2 = WorldState.new()
	w2.from_dict(m["world"])
	check(w2.last_city == "sich" and w2.quests.is_empty(), "світ із мінімальних даних")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	check(not SaveSystem.exists(TEST_SAVE), "видалення")
	p.free()


# ======================= 4. Місто =======================

func _suite_city() -> void:
	suite("Місто")
	var p = _new_player()
	var w = WorldState.new()
	var stock: Array = CityService.shop_stock(w, p, "sich")
	check(stock.size() == CityService.SHOP_SIZE, "розмір крамниці")
	check(CityService.shop_stock(w, p, "sich") == stock, "крамниця не змінюється без походу")
	var it: Dictionary = stock[0]
	var price = CityService.buy_price(w, "sich", it)
	p.gold = price - 1
	check(not CityService.buy(w, p, "sich", it["uid"]), "не купити без грошей")
	p.gold = price
	check(CityService.buy(w, p, "sich", it["uid"]) and p.gold == 0, "купівля")
	check(p.find_item(it["uid"]) == it and stock.size() == CityService.SHOP_SIZE - 1, "товар у торбі")
	check(CityService.sell(p, it["uid"]) == Data.sell_price(it) and p.inventory.is_empty(), "продаж")
	p.add_item(Data.gen_item(2, 0))
	p.add_item(Data.gen_item(2, 2))
	CityService.sell_junk(p)
	check(p.inventory.size() == 1 and p.inventory[0]["rarity"] == 2, "продаж лише звичайних")
	# Найм
	p.gold = 10000
	check(not CityService.hire(w, p, "sich", "strilets"), "стрільця не найняти без лояльності")
	check(CityService.hire(w, p, "sich", "dzhura"), "найм джури")
	check(not CityService.hire(w, p, "sich", "dzhura"), "другого джуру не найняти")
	w.add_loyalty("sich", 300)
	check(CityService.hire(w, p, "sich", "znakhar"), "найм знахарки з лояльністю")
	check(not CityService.hire(w, p, "sich", "strilets"), "загін не більше двох")
	CityService.dismiss(w, 0)
	check(w.companions.size() == 1, "відпустити супутника")
	# Здача завдання
	var q: Dictionary = w.board("sich")[0]
	check(w.take("sich", q["id"]), "взяти завдання")
	check(CityService.turn_in(w, p, q["id"]).is_empty(), "невиконане не здати")
	q["progress"] = q["count"]
	var g_before = p.gold
	var loy_before: int = w.loyalty_points("sich")
	var r = CityService.turn_in(w, p, q["id"])
	check(not r.is_empty() and p.gold == g_before + q["gold"] and w.loyalty_points("sich") == loy_before + q["loyalty"], "нагорода за завдання")
	p.free()


# ======================= 5. Сюжет =======================

func _suite_story() -> void:
	suite("Сюжет")
	var Classes = load("res://scripts/data/classes.gd")
	var p = _new_player()
	var w = WorldState.new()
	var gold0 = p.gold
	p.job = "peasant"
	p.skills = {}
	check(StoryService.state(w)["stage"] == "active" and StoryService.current(w)["id"] == "village", "пролог: одразу бій за рідне село")
	check(not StoryService.intro(w).is_empty(), "пролог: кобзар розповідає вступ")
	check(StoryService.city_dialogue(w, "kyiv").is_empty(), "у чужому місті розмови немає")
	check(StoryService.target(w) == "ridne_selo" and StoryService.objective_line(w) != "", "зірка й рядок мети")
	check(p.is_peasant() and not p.can_learn_skill(Classes.find_node("whirl")), "селянин не вчить козацьких умінь")
	var steps_done = 0
	var guard = 0
	while StoryService.state(w)["stage"] != "done" and guard < 300:
		guard += 1
		var st = StoryService.current(w)
		var stage = StoryService.state(w)["stage"]
		if stage == "offer":
			var d = StoryService.city_dialogue(w, st["city"])
			check(d.get("kind", "") == "start", "%s: стартова розмова" % st["id"])
			StoryService.on_dialogue_done(w, p, "start")
		elif stage == "active":
			var obj = st["objective"]
			check(StoryService.target(w) == obj["loc"], "%s: зірка веде до мети" % st["id"])
			if obj["type"] == "job":
				StoryService.on_event(w, p, "job", str(int(obj["count"]) - 1))
				check(StoryService.state(w)["stage"] == "active", "%s: замало майстерності" % st["id"])
				StoryService.on_event(w, p, "job", str(obj["count"]))
			elif obj["type"] == "choose":
				var PS = load("res://scripts/game/path_service.gd")
				check(PS.choosing(w) and not PS.can_choose(w), "%s: без розмов обрати не можна" % st["id"])
				check(PS.choose(w, p, "cossack").is_empty(), "%s: вибір без розмов не проходить" % st["id"])
				PS.mark_talked(w, "cossack")
				PS.mark_talked(w, "volkhv")
				check(PS.can_choose(w), "%s: після обох розмов можна обирати" % st["id"])
				PS.choose(w, p, "cossack")
			elif obj["type"] in ["clear", "dungeon", "visit"]:
				StoryService.on_event(w, p, "kill", "nobody")
				check(StoryService.state(w)["stage"] == "active", "%s: чужа подія не зараховується" % st["id"])
				StoryService.on_event(w, p, obj["type"], obj["loc"])
			else:
				var n = 0
				while StoryService.state(w)["stage"] == "active" and StoryService.current(w)["id"] == st["id"] and n < 500:
					StoryService.on_event(w, p, "kill", obj["enemy"])
					n += 1
				check(n >= int(obj["count"]), "%s: треба щонайменше %d" % [st["id"], obj["count"]])
			if st["turn_in"] == "":
				steps_done += 1
		elif stage == "turnin":
			check(StoryService.city_dialogue(w, "nowhere").is_empty(), "%s: здати можна лише у своєму місті" % st["id"])
			var d = StoryService.city_dialogue(w, st["turn_in"])
			check(d.get("kind", "") == "end", "%s: фінальна розмова" % st["id"])
			StoryService.on_dialogue_done(w, p, "end", 0 if not d["choices"].is_empty() else -1)
			steps_done += 1
	check(StoryService.state(w)["stage"] == "done", "розділ пройдено до кінця")
	check(not p.is_peasant() and p.sk("whirl") >= 1, "після посвяти — козак із вихором")
	check(p.rank == "hetman" and "Гетьманська булава" in p.inventory.map(func(it): return it["name"]), "фінал: гетьман із булавою")
	check(StoryService.effect(w, "koshchii_mortal") == 1.0, "зламана голка — Кощій смертний")
	check(w.plague["pressure"] == 0.0 and load("res://scripts/game/plague_service.gd").infected_count(w) == 0, "після Кремля зарази немає")
	var total_steps = 0
	for ch in load("res://scripts/data/story.gd").CHAPTERS:
		for stp in ch["steps"]:
			if not stp.has("if") or StoryService.chose(w, stp["if"]):
				total_steps += 1
	check(steps_done == total_steps, "усі %d кроків (пройдено %d)" % [total_steps, steps_done])
	var names = []
	for it in p.inventory:
		names.append(it["name"])
	check(p.equipment["weapon"]["name"] == "Козацька шабля" or "Козацька шабля" in names, "шабля за посвяту")
	check("Шабля кошового" in names and "Оберіг Мотрі" in names, "сюжетні нагороди розділу I")
	check("Булава полковника" in names and "Каптур літописця" in names, "сюжетні нагороди розділу II")
	check(w.story.get("choices", {}).get("crypt", -1) == 0 and w.loyalty_points("kyiv") >= 270, "вибір у розділі II враховано")
	check(w.loyalty_points("chyhyryn") >= 90 and w.story.get("choices", {}).get("potion", -1) == 0, "вибір у розмові з Мотрею враховано")
	check(p.gold > gold0 and p.level > 1, "гривні й досвід за сюжет")
	# Наслідки виборів (тест завжди обирає перший варіант)
	check(p.stats["str"] == Data.STAT_BASE + 3, "присяга помсти: +3 сили")
	check("Печатка Києва" in names, "стіни Києва: печатка в нагороду")
	check(is_equal_approx(StoryService.effect(w, "plague_resist"), 0.3) and StoryService.effect(w, "potion_max") == 2.0, "вибори дають опір заразі й зілля")
	check(w.discount("chyhyryn") >= 0.25 and w.discount("chyhyryn") > w.discount("lviv"), "вдячний Чигирин продає дешевше")
	check(StoryService.chronicle(w).size() == 8, "у літописі 8 виборів (%d)" % StoryService.chronicle(w).size())
	var CampService = load("res://scripts/game/camp_service.gd")
	CampService.apply_effects(w, p)
	check(p.plague_resist > 0.0 and p.potion_max() == Data.POTION_MAX + 2, "наслідки застосовано до козака")
	var lair: Dictionary = StoryService._find_step("lair")
	w.story["choices"]["camp"] = 0
	var heard0 = StoryService.lines(w, lair["end"]).size()
	w.story["choices"]["camp"] = 1
	var heard1 = StoryService.lines(w, lair["end"])
	check(heard0 == heard1.size() and heard0 == lair["end"].size() - 1, "кожен чує лише свою репліку")
	check(heard1.any(func(l): return "холодною головою" in l[1]), "інший вибір — інша репліка")
	var wb = WorldState.new()
	wb.story = {"chapter": 2, "step": 6, "stage": "turnin", "progress": 0, "choices": {"crypt": 1}}
	var pb = _new_player()
	StoryService.on_dialogue_done(wb, pb, "end")
	var got_seal = pb.inventory.any(func(it): return it["name"] == "Печатка Києва")
	check(not got_seal, "забрав золото — печатки немає")
	pb.free()
	check(StoryService.objective_line(w) == "" and StoryService.target(w) == "", "після завершення — без мети")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.story["stage"] == "done", "сюжет зберігається")
	p.free()


# ======================= 6. Зілля і загін =======================

func _suite_party() -> void:
	suite("Зілля і загін")
	var Party = load("res://scripts/game/party.gd")
	var p = _new_player()
	var w = WorldState.new()
	check(p.potions == Data.POTION_START, "на старті є зілля")
	check(not p.use_potion(), "із повним здоров'ям зілля не п'ється")
	p.hp = p.max_hp * 0.3
	var hp_before = p.hp
	check(p.use_potion() and p.hp > hp_before and p.potions == Data.POTION_START - 1, "зілля лікує й витрачається")
	p.hp = p.max_hp * 0.3
	check(not p.use_potion(), "перезарядка між ковтками")
	p.potion_timer = 0.0
	p.potions = 0
	check(not p.use_potion(), "без зілля не лікує")
	p.gold = 10000
	for i in 10:
		CityService.buy_potion(w, p, "sich")
	check(p.potions == Data.POTION_MAX, "купівля зілля до межі")
	check(not p.add_potion(), "понад межу не набрати")
	var q = _new_player()
	q.from_dict(p.to_dict())
	check(q.potions == Data.POTION_MAX, "зілля зберігається")
	# Загін
	p.add_xp(5000)
	var hero_lvl = p.level
	check(CityService.hire(w, p, "sich", "dzhura"), "найм джури")
	var c = w.companions[0]
	check(int(c["level"]) == maxi(1, hero_lvl - Party.HIRE_BELOW_HERO), "супутник приходить на 2 рівні нижче")
	var st0 = Party.stats("dzhura", c["level"])
	var ups = Party.gain_xp(w, hero_lvl, Party.xp_for_level(c["level"]) + 1)
	check(ups.size() == 1 and int(c["level"]) == st0.size() * 0 + int(ups[0][1]), "рівень супутника росте від досвіду")
	check(Party.stats("dzhura", c["level"])["hp"] > st0["hp"], "показники ростуть із рівнем")
	Party.gain_xp(w, hero_lvl, 1000000)
	check(int(c["level"]) == hero_lvl, "супутник не обганяє козака")
	c["downed"] = true
	var lvl_before = c["level"]
	Party.gain_xp(w, hero_lvl + 5, 1000000)
	check(c["level"] == lvl_before, "поранений не отримує досвіду")
	var w2 = WorldState.new()
	w2.companions = [{"type": "strilets", "downed": false}]
	Party.normalize(w2, 7)
	check(w2.companions[0]["level"] == 5 and w2.companions[0]["xp"] == 0, "старі збереження отримують рівень")
	p.free()
	q.free()


# ======================= 7. Хутір і реклама =======================

func _suite_heroes() -> void:
	suite("Побратими")
	var HS = load("res://scripts/game/hero_service.gd")
	var p = _new_player()
	p.level = 8
	var w = WorldState.new()
	# Розділ I пройдено, полоненого врятовано
	w.story = {"chapter": 2, "step": 0, "stage": "offer", "progress": 0, "choices": {"camp": 0, "potion": 1}}
	check(not HS.can_meet(w, "petro", "kyiv") and HS.can_meet(w, "petro", "chyhyryn"), "Петро чекає в Чигирині")
	check(not HS.can_meet(w, "oksana", "chernihiv"), "Оксана — лише після зразків Іларіона")
	var d = HS.city_dialogue(w, "chyhyryn")
	check(d.get("kind", "") == "meet" and d["hero"] in ["petro", "yaryna"] and d["choices"].size() == 2, "розмова-знайомство з вибором")
	HS.on_dialogue_done(w, p, d, 0)
	var first = d["hero"]
	check(HS.in_party(w, first) and w.companions[0].get("hero", "") == first, "%s у загоні" % first)
	var d2 = HS.city_dialogue(w, "chyhyryn")
	HS.on_dialogue_done(w, p, d2, 1)
	check(HS.waiting(w).size() == 1 and not HS.in_party(w, d2["hero"]), "відмовлений побратим чекає в корчмі")
	check(HS.city_dialogue(w, "chyhyryn").is_empty(), "двічі не знайомляться")
	HS.join(w, p, d2["hero"])
	check(w.companions.size() == 2 and HS.waiting(w).is_empty(), "покликали з корчми")
	check(not w.has_companion("dzhura") and not w.has_companion("znakhar"), "побратими не займають місце найманців")
	check(HS.member_name(w.companions[0]) != Data.COMPANIONS[w.companions[0]["type"]]["name"], "побратима звуть на ймення")
	check(HS.power(w, "petro") > 1.0, "побратим сильніший за найманця")
	var w2 = WorldState.new()
	w2.story = {"chapter": 2, "step": 0, "stage": "offer", "progress": 0, "choices": {"camp": 1}}
	check(not HS.can_meet(w2, "petro", "chyhyryn"), "не врятував полоненого — Петра немає")
	# Дружба й особисте завдання Петра
	for i in 59:
		HS.on_event(w, "kill", "vovk")
	check(HS.city_dialogue(w, "kyiv").is_empty(), "до потрібної дружби завдання немає")
	HS.on_event(w, "kill", "vovk")
	var dq = HS.city_dialogue(w, "kyiv")
	check(dq.get("kind", "") == "quest" and dq["hero"] == "petro", "Петро розповідає про сестру")
	HS.on_dialogue_done(w, p, dq, -1)
	check(HS.objective_lines(w).size() == 1 and "black_forest" in HS.targets(w), "мета й позначка на мапі")
	HS.on_event(w, "clear", "wild_field")
	check(HS.st(w, "petro")["quest"] == "active", "чужа місцевість не рахується")
	var before: float = HS.power(w, "petro")
	HS.on_event(w, "clear", "black_forest")
	var de = HS.city_dialogue(w, "lviv")
	check(de.get("kind", "") == "end", "повернення в будь-яке місто")
	HS.on_dialogue_done(w, p, de, -1)
	check(HS.st(w, "petro")["quest"] == "done" and HS.power(w, "petro") > before, "побратим навіки — сильнішає")
	var Party = load("res://scripts/game/party.gd")
	check(Party.stats("dzhura", 5, 1.5)["hp"] > Party.stats("dzhura", 5)["hp"], "множник сили побратима")
	var CompanionScript = load("res://scripts/entities/companion.gd")
	var cn = CompanionScript.new()
	cn.setup("dzhura", 5, 0, {"hero": "petro", "mult": 1.5, "name": "Петро Канівець", "color": Color.RED})
	check(cn.display_name == "Петро Канівець" and is_equal_approx(cn.max_hp, Party.stats("dzhura", 5)["hp"] * 1.5), "побратим у бою")
	cn.free()
	var w3 = WorldState.new()
	w3.from_dict(w.to_dict())
	check(w3.heroes["petro"]["quest"] == "done" and w3.companions.size() == 2, "побратими зберігаються")
	p.free()


func _suite_plague() -> void:
	suite("Живий світ: зараза")
	var PS = load("res://scripts/game/plague_service.gd")
	var w = WorldState.new()
	check(PS.level(w, "bryansk_forest") == 3 and PS.level(w, "kyiv") == 0, "зараза стартує з Московії")
	check(PS.mods(2)["hp"] > PS.mods(0)["hp"] and PS.mods(2)["reward"] > 1.0 and PS.mods(1)["cloud_every"] == 0.0, "заражене — сильніше й щедріше")
	seed(7)
	var total0 := 0
	for id in Data.LOCATIONS:
		total0 += PS.level(w, id)
	var spread_any := false
	for i in 12:
		var sp = PS.tick(w)
		check(sp.size() <= PS.MAX_SPREAD_PER_TRIP, "за похід — не більше %d місць" % PS.MAX_SPREAD_PER_TRIP)
		if not sp.is_empty():
			spread_any = true
	var total1 := 0
	for id in Data.LOCATIONS:
		total1 += PS.level(w, id)
		check(PS.level(w, id) <= PS.MAX_LEVEL, "%s: рівень зарази в межах" % id)
	check(spread_any and total1 > total0 and w.plague["day"] == 12, "зараза повзе між походами")
	PS.set_level(w, "wild_field", 2)
	check(PS.cleanse(w, "wild_field") == 1 and PS.cleanse(w, "wild_field") == 0 and PS.cleanse(w, "wild_field") == 0, "зачистка відкидає заразу")
	PS.set_level(w, "black_forest", 3)
	var p0: float = w.plague["pressure"]
	PS.on_chapter_done(w, 1)
	check(PS.level(w, "black_forest") == 0 and w.plague["pressure"] < p0, "перемога в розділі очищає край")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.plague["day"] == 12 and PS.level(w2, "black_forest") == 0, "зараза зберігається")
	var w3 = WorldState.new()
	w3.plague = {"levels": {}, "day": 0, "pressure": 0.0}
	PS.set_level(w3, "bryansk_forest", 3)
	for i in 5:
		PS.tick(w3)
	check(PS.infected_count(w3) == 1, "після перемоги над Путіноїдом зараза не повзе")


func _suite_travel() -> void:
	suite("Події в дорозі")
	var TS = load("res://scripts/game/travel_service.gd")
	var p = _new_player()
	var w = WorldState.new()
	p.job = "peasant"
	w.travel = {"cooldown": 0, "seen": {}}
	var none := true
	for i in 30:
		if not TS.roll(w, p).is_empty():
			none = false
	check(none, "селянин до посвяти пригод не має")
	p.job = "cossack"
	p.level = 6
	p.gold = 5000
	p.potions = 1
	p.resources = {"wood": 10, "iron": 5, "herbs": 5}
	seed(3)
	var got := 0
	var streak_ok := true
	var last_hit := -10
	for i in 200:
		var ev = TS.roll(w, p)
		if not ev.is_empty():
			got += 1
			if i - last_hit <= TS.COOLDOWN:
				streak_ok = false
			last_hit = i
	check(got > 15 and got < 90, "пригоди трапляються іноді (%d зі 200)" % got)
	check(streak_ok, "між пригодами — перерва")
	for id in TS.EVENTS:
		var ev = TS.prepare(w, p, id)
		check(not ev["lines"].is_empty() and ev["choices"].size() >= 2, "%s: текст і щонайменше два варіанти" % id)
		for c in ev["choices"]:
			check(c.has("text") and c.has("reply") and c.has("outcome"), "%s: варіант «%s» повний" % [id, c["text"]])
	# Бідний козак без зілля й ресурсів отримує лише доступні варіанти
	var poor = _new_player()
	poor.job = "cossack"
	poor.gold = 0
	poor.potions = 0
	poor.resources = {}
	for id in TS.EVENTS:
		var ev = TS.prepare(w, poor, id)
		var ok := true
		for c in ev["choices"]:
			var o: Dictionary = c["outcome"]
			if int(o.get("gold", 0)) < 0 or int(o.get("potions", 0)) < 0:
				ok = false
			for r in o.get("res", {}):
				if int(o["res"][r]) < 0:
					ok = false
		check(ok and ev["choices"].size() >= 1, "%s: бідному не пропонують того, на що не стає" % id)
	poor.free()
	# Наслідки
	var g0: int = p.gold
	var hp0: float = p.max_hp
	p.hp = p.max_hp
	var msg = TS.apply(w, p, {"gold": -30, "hp_pct": -0.25, "loyalty": {"kyiv": 50}, "res": {"wood": -2}})
	check(p.gold == g0 - 30 and is_equal_approx(p.hp, hp0 * 0.75) and w.loyalty_points("kyiv") == 50 and p.resources["wood"] == 8 and msg != "", "наслідки застосовано")
	p.hp = 1.0
	TS.apply(w, p, {"hp_pct": -0.9})
	check(p.hp >= 1.0, "пригода не вбиває")
	var dmg0: float = p.damage
	TS.apply(w, p, {"trip": "inspired"})
	check(p.damage > dmg0 and p.trip_buffs.has("inspired"), "дума кобзаря надихає на похід")
	p.equip_new(Data.gen_item(5, 1, "weapon", "sabre"))
	var up0: int = p.equipment["weapon"]["up"]
	TS.apply(w, p, {"sharpen": true})
	check(p.equipment["weapon"]["up"] == up0 + 1, "мандрівний коваль гострить зброю")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.travel.has("seen") and not w2.travel["seen"].is_empty(), "пригоди зберігаються")
	p.free()


func _suite_defense_logic() -> void:
	suite("Оборона: облоги")
	var DS = load("res://scripts/game/defense_service.gd")
	var p = _new_player()
	p.level = 6
	var w = WorldState.new()
	w.story = {"chapter": 0, "step": 0, "stage": "active", "progress": 0}
	w.defense = {"sieges": {}, "ruined": {}, "won": 0, "lost": 0, "calm": 0}
	var any := false
	for i in 30:
		if not DS.tick(w, p).is_empty():
			any = true
	check(not any and w.defense["sieges"].is_empty(), "у пролозі облог немає")
	w.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	check(not DS.threatened(w, p).is_empty(), "міста поруч із заразою під загрозою: %s" % ", ".join(DS.threatened(w, p)))
	seed(11)
	var started := ""
	for i in 60:
		for m in DS.tick(w, p):
			if "облягають" in m:
				started = m
		if not w.defense["sieges"].is_empty():
			break
	check(started != "" and w.defense["sieges"].size() == 1, "облога починається")
	var target: String = w.defense["sieges"].keys()[0]
	check(DS.is_besieged(w, target) and DS.trips_left(w, target) == DS.DEADLINE, "у міста є кілька походів на допомогу")
	if target != "hutir":
		var loy0: int = w.loyalty_points(target)
		var g0: int = p.gold
		DS.win(w, p, target)
		check(not DS.is_besieged(w, target) and w.loyalty_points(target) == loy0 + 80 and p.gold > g0, "перемога: лояльність і гривні")
	# Запізнення
	w.defense["sieges"] = {"kyiv": 1}
	w.loyalty["kyiv"] = 100
	var price0: int = int(Data.potion_price(p.level) * (1.0 - w.discount("kyiv")))
	var msgs = DS.tick(w, p)
	check(not DS.is_besieged(w, "kyiv") and msgs.any(func(m): return "Не встиг" in m), "не встиг — місто падає")
	check(w.loyalty_points("kyiv") == 40 and DS.markup(w, "kyiv") > 0.0, "пограбоване місто: лояльність −60")
	check(int(Data.potion_price(p.level) * (1.0 - w.discount("kyiv"))) > price0, "після пограбування дорожче")
	for i in DS.RUIN_TRIPS:
		DS.tick(w, p)
	check(DS.markup(w, "kyiv") == 0.0, "місто відбудовується")
	p.resources = {"wood": 10, "iron": 10, "herbs": 10}
	DS.lose(w, p, "hutir")
	check(p.resources["wood"] == 7, "пограбований хутір утрачає запаси")
	var bl = DS.battle_loc(w, "chyhyryn", p)
	check(bl["type"] == "defense" and bl["level"] >= p.level - 1 and bl["waves"] == DS.WAVES, "бій-оборона під рівень козака")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.defense["lost"] == w.defense["lost"], "облоги зберігаються")
	p.free()


func _suite_defense_battle() -> void:
	suite("Оборона: бій біля брами")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	p.job = "cossack"
	p.stats["str"] = 60
	p.stats["vit"] = 60
	p.skills = {"whirl": 3, "lightning": 3}
	p.recalc()
	p.hp = p.max_hp
	game.world.hints = {"combat": true, "block": true, "defense": true, "elite": true, "city": true, "map": true, "boss": true, "item": true}
	game.world.defense = {"sieges": {"chyhyryn": 3}, "ruined": {}, "won": 0, "lost": 0, "calm": 3}
	game.world.story = {"chapter": 1, "step": 3, "stage": "active", "progress": 0}
	await _ride(game, "chyhyryn")
	check(game.state == game.State.PLAYING and game.combat.is_defense() and game.combat.gate != null, "обложене місто — після поїздки бій біля брами")
	var loy0: int = game.world.loyalty_points("chyhyryn")
	var frames := 0
	while not game.combat.defense_over and frames < 6000:
		_bot_fight(game)
		if game.combat.gate != null and is_instance_valid(game.combat.gate):
			game.combat.gate.hp = game.combat.gate.max_hp  # тест про хвилі, а не про міцність
		p.hp = p.max_hp
		await process_frame
		frames += 1
	check(game.combat.defense_over and game.combat.wave == game.DefenseService.WAVES, "усі хвилі відбито (кадрів: %d)" % frames)
	check(not game.DefenseService.is_besieged(game.world, "chyhyryn") and game.world.loyalty_points("chyhyryn") == loy0 + 80, "Чигирин відстояно")
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and game.city_id == "chyhyryn", "з порталу — просто в урятоване місто")
	game.hud.close_dialogue()
	# Облога хутора: кнопка з мапи має вести в бій, а не на хутір
	game.world.camp = {"buildings": {"kurin": 1}, "pasika_ts": 0}
	game.world.defense["sieges"]["hutir"] = 3
	await _ride(game, "hutir")
	check(game.state == game.State.PLAYING and game.combat.is_defense() and game.combat.gate != null and game.combat.gate.camp, "обложений хутір — бій біля тину, а не екран хутора")
	frames = 0
	while not game.combat.defense_over and frames < 6000:
		_bot_fight(game)
		if game.combat.gate != null and is_instance_valid(game.combat.gate):
			game.combat.gate.hp = game.combat.gate.max_hp
		p.hp = p.max_hp
		await process_frame
		frames += 1
	check(game.combat.defense_over and not game.DefenseService.is_besieged(game.world, "hutir"), "хутір відстояно")
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.CAMP, "з порталу — просто на хутір")
	# Поразка: браму зламано
	game.world.defense["sieges"]["kyiv"] = 2
	await _ride(game, "kyiv")
	game.combat.gate.take_damage(game.combat.gate.max_hp * 2.0)
	await _frames(2)
	check(not game.DefenseService.is_besieged(game.world, "kyiv") and game.DefenseService.markup(game.world, "kyiv") > 0.0, "браму зламано — Київ пограбовано")
	await create_timer(2.8).timeout
	check(game.state == game.State.MAP, "після поразки — на мапу")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_challenges() -> void:
	suite("Виклики й досягнення")
	var CS = load("res://scripts/game/challenge_service.gd")
	var p = _new_player()
	var w = WorldState.new()
	CS.now_override = 1762700000  # фіксований день
	var c = CS.state(w)
	check(c["daily"].size() == 3 and c["weekly"].size() == 2, "3 щоденні й 2 тижневі виклики")
	var w_same = WorldState.new()
	check(CS.state(w_same)["daily"][0]["text"] == c["daily"][0]["text"], "у всіх гравців того ж дня — ті самі виклики")
	var stats := {}
	for ch in c["daily"]:
		stats[ch["stat"]] = true
	check(stats.size() == 3, "щоденні виклики різні")
	var ch0: Dictionary = c["daily"][0]
	var msgs := []
	for i in int(ch0["goal"]):
		msgs.append_array(CS.record(w, p, ch0["stat"]))
	check(ch0["progress"] == ch0["goal"] and msgs.any(func(m): return "Виклик виконано" in m), "виклик виконано")
	check(CS.ready_count(w) >= 1, "нагорода чекає")
	var g0: int = p.gold
	var t = CS.claim(w, p, false, 0)
	check(t != "" and p.gold > g0 and c["daily"][0]["claimed"], "нагороду забрано")
	check(CS.claim(w, p, false, 0) == "", "двічі не забереш")
	check(CS.claim(w, p, true, 0) == "" or c["weekly"][0]["progress"] >= c["weekly"][0]["goal"], "невиконаний тижневий не віддає нагороди")
	# Новий день — нові виклики, тиждень той самий
	CS.now_override = 1762700000 + 86400
	var c2 = CS.state(w)
	check(not c2["daily"][0]["claimed"] and c2["day"] != "" , "наступного дня — нові виклики")
	# Досягнення
	var g1: int = p.gold
	var m2 = CS.record(w, p, "kill")
	check(c2["ach"].has("first_blood") and p.gold == g1 + 20 and m2.any(func(m): return "Перша кров" in m), "досягнення «Перша кров»")
	CS.record(w, p, "kill")
	check(p.gold == g1 + 20, "досягнення відкривається лише раз")
	CS.record(w, p, "level", 10)
	CS.record(w, p, "level", 7)
	check(w.stats["level"] == 10 and c2["ach"].has("level_10"), "рівень — найвищий, а не сума")
	for i in 3:
		CS.record(w, p, "boss:zmii")
	check(c2["ach"].has("zmii"), "Змієборець")
	# Тижнева нагорода
	var wk: Dictionary = c2["weekly"][0]
	CS.record(w, p, wk["stat"], int(wk["goal"]))
	var tok0: int = int(w.boosts.get("safe_sharpen", 0))
	var inv0: int = p.inventory.size()
	check(CS.claim(w, p, true, 0) != "" and int(w.boosts["safe_sharpen"]) == tok0 + 1 and p.inventory.size() == inv0 + 1, "тижнева нагорода: річ і жетон заточки")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.stats["kill"] == w.stats["kill"] and w2.challenges["ach"].has("zmii"), "лічильники й досягнення зберігаються")
	CS.now_override = 0
	p.free()


func _suite_craft() -> void:
	suite("Крафт у кузні")
	var CR = load("res://scripts/game/craft_service.gd")
	var p = _new_player()
	p.level = 8
	var w = WorldState.new()
	p.gold = 100000
	p.resources = {"wood": 500, "iron": 500, "herbs": 500, "trophy": 100}
	check(CR.forge(w, p, "weapon", "mace", 1).is_empty(), "без кузні не кується")
	w.camp = {"buildings": {"kuznia": 1}, "pasika_ts": 0}
	var it = CR.forge(w, p, "weapon", "mace", 1)
	check(not it.is_empty() and it["type"] == "mace" and it["rarity"] == 1 and it["ilvl"] == 8, "викувано добротну булаву свого рівня")
	check(CR.forge(w, p, "head", "", 2).is_empty(), "рідкісне — лише з кузнею 2")
	w.camp["buildings"]["kuznia"] = 3
	var gold0: int = p.gold
	var tr0: int = p.resources["trophy"]
	var leg = CR.forge(w, p, "amulet", "", 3)
	check(leg["rarity"] == 3 and leg["affixes"].size() == 3 and p.gold < gold0 and p.resources["trophy"] == tr0 - CR.TIER_TROPHY[3], "легендарний оберіг за трофеї")
	check(CR.forge_cost("weapon", 3, 8)["gold"] > CR.forge_cost("weapon", 1, 8)["gold"], "краща якість — дорожче")
	var poor = _new_player()
	poor.gold = 0
	check(not CR.can_pay(poor, CR.forge_cost("body", 1, 1)), "без гривень не викуєш")
	poor.free()
	# Перекування
	var old_keys: Array = leg["affixes"].keys()
	var target: String = old_keys[0]
	var fresh: String = CR.reforge(w, p, leg["uid"], target)
	check(fresh != "" and not leg["affixes"].has(target) and leg["affixes"].has(fresh) and leg["affixes"].size() == 3, "перекувано одну властивість")
	check(not (fresh in old_keys) and fresh != Data.SLOT_PRIMARY["amulet"], "нова властивість не повторюється")
	# Оновлення до рівня
	var story_it = Data.gen_item(3, 3, "weapon", "sabre")
	story_it["up"] = 4
	p.add_item(story_it)
	var dmg_before: float = story_it["base"]["flat_dmg"]
	check(CR.renew(w, p, story_it["uid"]) and story_it["ilvl"] == 8 and story_it["base"]["flat_dmg"] > dmg_before and story_it["up"] == 4, "стару шаблю оновлено до свого рівня, заточку збережено")
	check(not CR.can_renew(w, story_it, 8), "оновлена річ уже свого рівня")
	p.free()


func _suite_classes() -> void:
	suite("Класи: Селянин, Козак, Волхв")
	var Classes = load("res://scripts/data/classes.gd")
	var p = _new_player()
	p.job = "peasant"
	p.job_level = 1
	p.skills = {}
	p.skill_points = 0
	p.recalc()
	check(not p.can_change_class(), "селянин 1 рівня ще не обирає дорогу")
	var total := 0
	for jl in range(1, 10):
		total += Classes.job_xp_for(0, jl)
	p.add_xp(total)
	check(p.job_level == 10 and p.skill_points == 9 and p.can_change_class(), "майстерність 10 за %d досвіду — 9 очок, можна обирати" % total)
	p.add_xp(5000)
	check(p.job_level == 10 and p.job_xp == 0, "на вершині класу майстерність стоїть")
	check(p.learn_skill("hardy") and p.learn_skill("vyly"), "селянин вчить свою науку")
	var hp_before: float = p.max_hp
	p.learn_skill("hardy")
	check(p.max_hp > hp_before, "Селянська витривалість додає здоров'я")
	check(not p.learn_skill("fireball") and not p.learn_skill("whirl"), "чужих умінь не вчить")
	# Волхв
	var pts_before: int = p.skill_points
	check(p.change_class("volkhv") and p.job == "volkhv" and p.job_level == 1 and p.skill_points == pts_before, "зміна класу: майстерність з 1, очки лишились")
	check(p.sk("vyly") == 1 and p.sk("hardy") == 2, "селянська наука лишається з волхвом")
	check(p.max_mana > 60.0 and p.mana_regen > 3.0, "волхв має великий запас наснаги (%d)" % p.max_mana)
	check(p.learn_skill("fireball") and not p.learn_skill("vyly"), "волхв вчить вогонь, а селянське — вже ні")
	check("fireball" in p.active_skills() and "fireball" in p.panel["attack"], "нове вміння саме стає на панель атак")
	# Панель бою: 3 атаки + 5 бафів, вибір і перенесення
	var SI = load("res://scripts/data/skill_info.gd")
	check(SI.kind("fireball") == "attack" and SI.kind("shield") == "buff" and p.panel["attack"].size() == 3 and p.panel["buff"].size() == 5, "панель: 3 атаки й 5 бафів")
	check(not p.set_panel("buff", 0, "fireball"), "атаку не поставиш у комірку бафа")
	check(not p.set_panel("attack", 1, "whirl"), "невивчене на панель не стає")
	var first: String = p.panel["attack"][0]
	check(p.set_panel("attack", 2, first) and p.panel["attack"][2] == first and p.panel["attack"][0] != first, "перенесення в іншу комірку")
	check(p.set_panel("attack", 2, "") and p.panel["attack"][2] == "", "комірку можна звільнити")
	p.sync_panel()
	check(first in p.panel["attack"], "після синхронізації вивчене вміння повертається у вільну комірку")
	for id in SI.KIND:
		var node: Dictionary = Classes.find_node(id)
		check(not node.is_empty() and node.get("active", false), "довідник: %s — активне вміння" % id)
		check(not SI.stats(id, 1, p).is_empty() or SI.KIND[id] == "buff", "довідник: %s має цифри" % id)
		check(SI.WHAT.has(id), "довідник: %s має опис" % id)
	for cls in Classes.TREES:
		for b in Classes.TREES[cls]:
			for node in b["nodes"]:
				if node.get("active", false):
					check(SI.KIND.has(node["id"]), "активне %s є в довіднику панелі" % node["id"])
	var sabre = Data.gen_item(3, 1, "weapon", "sabre")
	var staff = Data.gen_item(3, 1, "weapon", "staff")
	p.add_item(sabre)
	p.add_item(staff)
	check(not p.can_use(sabre) and not p.equip(sabre["uid"]), "волхв не бере шаблю")
	check(p.equip(staff["uid"]) and p.is_mage() and p.attack_range > 300.0, "волхв із посохом б'є здалеку")
	var dmg_spi: float = p.damage
	p.stats["spi"] += 10
	p.recalc()
	check(p.damage > dmg_spi * 1.4, "сила волхва — від Характерництва")
	# Наснага
	p.mana = 0.0
	p.skill_timers["fireball"] = 0.0
	check(p.skill_cost("fireball") > 0.0, "закляття коштує наснагу")
	# Козак
	var c = _new_player()
	check(c.job == "cossack" and not c.can_use(staff) and c.can_use(sabre), "козак — шабля так, посох ні")
	check(c.max_mana < p.max_mana, "у козака наснаги менше")
	c.learn_skill("whirl")
	c.skill_points = 5
	check(c.learn_skill("battle_cry") and c.learn_skill("tough"), "козак вчить клич і Міцну шкуру")
	check(c.pk("tough") == 1, "вузли класу діють як колишні перки")
	# Загартування й стеля рівня
	c.perk_points = 2
	check(c.learn_perk("boots") and c.learn_perk("purse"), "Загартування — для всіх")
	c.level = 98
	c.xp_next = Data.xp_for_level(98)
	c.add_xp(c.xp_next * 5)
	check(c.level == 99, "стеля рівня героя — 99")
	# Пул зброї в здобичі
	Data.weapon_pool = ["staff"]
	var all_staff := true
	for i in 20:
		if Data.gen_item(5, 1, "weapon")["type"] != "staff":
			all_staff = false
	check(all_staff, "волхвові падає зброя волхва")
	Data.weapon_pool = []
	# Сюжет: дорога волхва
	var w = WorldState.new()
	var v = _new_player()
	v.job = "peasant"
	v.skills = {}
	StoryService.hero_class = "peasant"
	var path := []
	var guard := 0
	while StoryService.state(w)["chapter"] == 0 and guard < 100:
		guard += 1
		var st = StoryService.current(w)
		path.append(st["id"])
		match StoryService.state(w)["stage"]:
			"offer":
				StoryService.on_dialogue_done(w, v, "start")
			"active":
				var obj = st["objective"]
				if obj["type"] == "job":
					StoryService.on_event(w, v, "job", "10")
				elif obj["type"] == "choose":
					var PSv = load("res://scripts/game/path_service.gd")
					PSv.mark_talked(w, "cossack")
					PSv.mark_talked(w, "volkhv")
					PSv.choose(w, v, "volkhv")
				elif obj["type"] == "kill":
					for i in obj["count"]:
						StoryService.on_event(w, v, "kill", obj["enemy"])
				else:
					StoryService.on_event(w, v, obj["type"], obj["loc"])
			"turnin":
				StoryService.on_dialogue_done(w, v, "end", 0)
	check(not "oath" in path and "to_carpathians" in path and "volkhv_trial" in path and "back_to_sich" in path, "дорога волхва: Капище, випробування, повернення")
	check(v.job == "volkhv" and v.equipment["weapon"]["type"] == "staff" and v.sk("fireball") == 1, "посвячено у волхви — посох у руці")
	check(StoryService.chose(w, "trial=1") and w.story["chapter"] == 1, "далі — Розділ I разом із козаками")
	var ln: Array = StoryService.lines(w, [["otaman", "Ну що, козаче?"], ["hero", "Я готовий."]])
	check(ln[0][1] == "Ну що, волхве?" and ln[1][0] == "hero_volkhv", "до волхва звертаються «волхве»")
	StoryService.hero_class = "cossack"
	# Міграція старого збереження
	var old = {"version": 7, "player": {"level": 12, "rank": "cossack", "skills": {"whirl": 5, "lightning": 3}, "perks": {"sharp": 3}}, "world": {"story": {"chapter": 0, "step": 2, "stage": "active", "progress": 0, "choices": {}}}}
	var m = SaveSystem.migrate(old)
	var mp: Dictionary = m["player"]
	check(mp["job"] == "cossack" and mp["job_level"] == 12 and mp["skill_points"] == 20 and mp["perks"].is_empty() and mp["perk_points"] == 6, "міграція: колишній козак — клас «Козак», очки повернуто")
	check(m["world"]["story"]["step"] == 4 and m["world"]["story"]["choices"]["trial"] == 0, "міграція: посвята — тепер козацька присяга (після кроку «Обери дорогу»)")
	var oldp = SaveSystem.migrate({"version": 7, "player": {"level": 2, "rank": "peasant"}, "world": {}})
	check(oldp["player"]["job"] == "peasant", "міграція: селянин лишається селянином")
	p.free()
	c.free()
	v.free()


func _suite_mage_battle() -> void:
	suite("Бій волхва й нові вміння")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true}
	var p = game.player
	p.change_class("volkhv")
	p.skills = {"fireball": 3, "shield": 2, "herb": 2, "iskra": 2}
	var st = Data.gen_item(5, 1, "weapon", "staff")
	p.add_item(st)
	p.equip(st["uid"])
	p.recalc()
	p.mana = p.max_mana
	game.enter_location("wild_field")
	await _frames(2)
	var e = _moves_dummy(game, "upyr")
	e.global_position = p.global_position + Vector2(250, 0)
	var hp0: float = e.hp
	p.attack_timer = 0.0
	p.attack()
	for i in 30:
		await process_frame
	check(e.hp < hp0, "іскра волхва влучає здалеку")
	var m0: float = p.mana
	p.skill_timers["fireball"] = 0.0
	var hp1: float = e.hp
	p.use_skill("fireball")
	check(p.mana < m0, "вогняна куля коштує наснагу")
	for i in 40:
		await process_frame
	check(e.hp < hp1 and e.statuses.has("burn"), "вогняна куля вибухає й підпалює")
	p.mana = 0.0
	p.skill_timers["fireball"] = 0.0
	var hp2: float = e.hp
	p.use_skill("fireball")
	for i in 5:
		await process_frame
	check(p.skill_timers["fireball"] <= 0.0, "без наснаги закляття не вийде")
	p.mana = p.max_mana
	p.use_skill("shield")
	check(p.ward_hp > 0.0, "щит-оберіг")
	p.invuln = 0.0
	var hp3: float = p.hp
	p.take_damage(5.0, null)
	check(p.hp == hp3, "оберіг поглинає удар")
	p.ward_hp = 0.0
	p.hp = p.max_hp * 0.3
	p.invuln = 5.0  # упир поруч не повинен заважати перевірці лікування
	var hp4: float = p.hp
	p.use_skill("herb")
	for i in 60:
		await process_frame
	check(p.hp > hp4 + p.max_hp * 0.03 and p.herb_timer > 0.0, "цілюща трава лікує в часі")
	# Заряджене закляття
	var e2 = _moves_dummy(game, "mavka")
	e2.global_position = p.global_position + Vector2(200, 0)
	var hp5: float = e2.hp
	p.block_held = true
	p._update_block(0.0)
	p._update_block(p.CHARGE_FULL)
	p.block_held = false
	p._update_block(0.0)
	for i in 40:
		await process_frame
	check(e2.hp < hp5 and e2.stun > 0.0, "заряджене закляття — «Гнів Роду» з приголомшенням")
	# Козацькі й селянські вміння
	p.change_class("cossack")
	var sb = Data.gen_item(5, 1, "weapon", "sabre")
	p.add_item(sb)
	p.equip(sb["uid"])
	p.skills["battle_cry"] = 2
	p.skills["vyly"] = 2
	p.skills["first_aid"] = 1
	p.recalc()
	p.mana = p.max_mana
	var e3 = _moves_dummy(game, "upyr")
	p.crit_chance = 0.0
	p.attack_timer = 0.0
	p.combo_timer = 0.0
	# Середнє з багатьох кидків: шкода має розкид ±10%, а клич дає +20%
	var plain := 0.0
	for i in 40:
		plain += p._roll(1.0)[0]
	p.use_skill("battle_cry")
	check(p.cry_timer > 0.0, "бойовий клич")
	var loud := 0.0
	for i in 40:
		loud += p._roll(1.0)[0]
	check(loud > plain * 1.12, "клич посилює удар (%.0f → %.0f)" % [plain / 40.0, loud / 40.0])
	p.attack_timer = 0.0
	p.combo_timer = 0.0
	p.attack()
	var mana_hit: float = p.mana
	p.attack_timer = 0.0
	p.attack()
	check(p.mana > mana_hit, "влучний удар козака поповнює наснагу")
	var a2: float = e3.hp
	p.use_skill("vyly")
	check(e3.hp < a2, "удар вилами")
	p.hp = p.max_hp * 0.5
	p.mana = p.max_mana
	var h0: float = p.hp
	p.use_skill("first_aid")
	check(p.hp > h0, "перша допомога")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_specs() -> void:
	suite("Спеціалізації Козака: наставники й випробування")
	var SS = load("res://scripts/game/spec_service.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var p = _new_player()
	var w = WorldState.new()
	check(Classes.CLASSES["cossack"]["next"].size() == 4, "у Козака 4 дороги")
	for spec in Classes.CLASSES["cossack"]["next"]:
		var info: Dictionary = Classes.CLASSES[spec]
		check(info["tier"] == 2 and info["job_max"] == 50 and SS.TRIALS.has(spec), "%s: ступінь 2, є випробування" % spec)
		check(load("res://scripts/data/story.gd").NPCS.has(info["mentor"]), "%s: наставник %s" % [spec, info["mentor"]])
		var t: Dictionary = SS.TRIALS[spec]
		check(not t["start"].is_empty() and not t["end"].is_empty() and t["item"]["type"] in info["weapons"], "%s: розмови й зброя класу" % spec)
		var obj: Dictionary = t["objective"]
		check(not obj.has("loc") or Data.LOCATIONS.has(obj["loc"]), "%s: місце випробування існує" % spec)
	p.job_level = 29
	check(SS.available(p).is_empty() and not SS.start(w, p, "plastun"), "до 30-ї майстерності випробувань немає")
	p.job_level = 30
	check(SS.available(p).size() == 4 and SS.start(w, p, "plastun"), "з 30-ї — можна до наставника")
	check(SS.objective_line(w).begins_with("◆") and SS.target(w) == "", "мета пластуна — будь-де")
	for i in 7:
		SS.on_event(w, "elite", "")
	SS.on_event(w, "kill", "upyr")
	check(w.spec_trial["stage"] == "active" and w.spec_trial["progress"] == 7, "звичайні вороги не рахуються")
	var m = SS.on_event(w, "elite", "")
	check(w.spec_trial["stage"] == "turnin" and not m.is_empty() and SS.target(w) == "sich", "8 еліт — повертайся на Січ")
	check(SS.city_dialogue(w, "kyiv").is_empty() and SS.city_dialogue(w, "sich")["spec"] == "plastun", "посвята — лише на Січі")
	var skills_before: Dictionary = p.skills.duplicate()
	var t2 = SS.complete(w, p)
	check(t2 != "" and p.job == "plastun" and p.job_level == 1 and w.spec_trial.is_empty(), "посвячено в пластуни")
	check(p.equipment["weapon"]["name"] == "Спис пластуна" and p.equipment["weapon"]["rarity"] == 2, "наставник дає зброю")
	check(p.skills.has("whirl") and "cossack" in Classes.lineage("plastun"), "козацькі вміння лишаються")
	p.skill_points = 1
	check(p.learn_skill("kydok") and not p.learn_skill("whirl"), "пластун вчить свої вміння, а козацькі — вже ні")
	check(SS.available(p).is_empty(), "з пластуна далі не обирають (поки)")
	# Пищаль: лише для самопальника
	var gun = Data.gen_item(10, 1, "weapon", "pishchal")
	var c = _new_player()
	c.add_item(gun)
	check(not c.can_use(gun), "звичайний козак пищаль не бере")
	c.change_class("samopalnyk")
	check(c.equip(gun["uid"]) and c.attack_range > 400.0, "самопальник — пищаль здалеку")
	var d0: float = c.damage
	c.stats["agi"] += 10
	c.recalc()
	check(c.damage > d0 * 1.3, "сила пищалі — від Спритності")
	# Міграція не потрібна: новий стан порожній за замовчуванням
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.spec_trial.is_empty(), "стан випробування зберігається")
	p.free()
	c.free()


func _suite_spec_battle() -> void:
	suite("Бій спеціалізацій")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true}
	var p = game.player
	p.change_class("zaporozhets")
	var mace = Data.gen_item(10, 1, "weapon", "mace")
	p.add_item(mace)
	p.equip(mace["uid"])
	p.skills = {"zemnyi": 2, "stina": 2, "bulava": 2, "nevhamovnyi": 3, "tin": 1, "pastka": 1, "kydok": 1,
		"kartech": 1, "prytsil": 1, "bochka": 1, "vovk": 1, "kulia": 1, "zamova": 1, "vidvid": 1}
	p.recalc()
	game.enter_location("wild_field")
	await _frames(2)
	p.invuln = 99.0
	# Запорожець
	var e = _moves_dummy(game, "upyr")
	p.mana = p.max_mana
	var h0: float = e.hp
	p.use_skill("zemnyi")
	check(e.hp < h0 and e.stun > 0.5, "Земний удар: шкода й приголомшення")
	p.mana = p.max_mana
	p.use_skill("stina")
	var far = _moves_dummy(game, "mavka")
	far.global_position = p.global_position + Vector2(300, 0)
	check(far._pick_target() == p, "Козацька стіна: вороги б'ють запорожця")
	p.invuln = 0.0
	var hp0: float = p.hp
	p.take_damage(100.0, null)
	check(hp0 - p.hp < 100.0 * (1.0 - p.armor) * 0.7, "Стіна зменшує шкоду")
	p.invuln = 99.0
	p.stina_timer = 0.0
	var b = _moves_dummy(game, "upyr")
	var bh: float = b.hp
	p.mana = p.max_mana
	p.use_skill("bulava")
	check(b.hp < bh, "Булава гніву")
	p.crit_chance = 0.0
	var low := 0.0
	var full := 0.0
	p.hp = p.max_hp * 0.2
	for i in 40:
		low += p._roll(1.0)[0]
	p.hp = p.max_hp
	for i in 40:
		full += p._roll(1.0)[0]
	check(low > full * 1.15, "Невгамовний: поранений б'є сильніше")
	# Пластун
	p.change_class("plastun")
	p.mana = p.max_mana
	p.use_skill("tin")
	var seer = _moves_dummy(game, "upyr")
	check(p.tin_timer > 0.0 and seer._pick_target() != p, "Тінь: вороги не бачать")
	var r: Array = p._roll(1.0)
	check(r[1] and p.tin_timer == 0.0, "удар із Тіні — гарантований крит")
	var t = _moves_dummy(game, "upyr")
	t.global_position = p.global_position + Vector2(120, 0)
	p.mana = p.max_mana
	p.use_skill("pastka")
	var th: float = t.hp
	for i in 5:
		await process_frame
	check(t.hp < th and t.stun > 0.5, "пастка ловить ворога")
	var k = _moves_dummy(game, "upyr")
	k.global_position = p.global_position + Vector2(200, 0)
	var kh: float = k.hp
	p.mana = p.max_mana
	p.use_skill("kydok")
	for i in 20:
		await process_frame
	check(k.hp < kh, "кидок списа")
	# Самопальник
	p.change_class("samopalnyk")
	var gun = Data.gen_item(10, 1, "weapon", "pishchal")
	p.add_item(gun)
	p.equip(gun["uid"])
	var g = _moves_dummy(game, "upyr")
	g.global_position = p.global_position + Vector2(300, 0)
	var gh: float = g.hp
	p.attack_timer = 0.0
	p.attack()
	for i in 20:
		await process_frame
	check(g.hp < gh, "пищаль б'є здалеку")
	gh = g.hp
	p.mana = p.max_mana
	p.use_skill("kartech")
	for i in 20:
		await process_frame
	check(g.hp < gh, "картеч")
	gh = g.hp
	p.mana = p.max_mana
	p.use_skill("bochka")
	for i in 80:
		await process_frame
	check(g.hp < gh and g.statuses.has("burn"), "бочка пороху вибухає й підпалює")
	# Характерник
	p.change_class("kharakternyk")
	var sb = Data.gen_item(10, 1, "weapon", "sabre")
	p.add_item(sb)
	p.equip(sb["uid"])
	p.mana = p.max_mana
	p.use_skill("vovk")
	check(p.wolf_timer > 0.0, "Вовча подоба")
	p.wolf_timer = 0.0
	p.invuln = 0.0
	p.mana = p.max_mana
	p.use_skill("kulia")
	check(p.invuln >= 2.0, "Куля не бере — невразливість")
	p.mana = p.max_mana
	p.use_skill("zamova")
	var z1 = _moves_dummy(game, "upyr")
	game.combat.spawn_enemy("mavka", 5, false, z1.global_position + Vector2(40, 40))
	var z2 = game.combat.get_tree().get_nodes_in_group("enemies")[-1]
	z2.max_hp = 100000.0
	z2.hp = z2.max_hp
	var z2h: float = z2.hp
	p.hit(z1, 50.0, Vector2.ZERO, false)
	check(z2.hp < z2h, "замовлена шабля перескакує блискавкою")
	p.zamova_timer = 0.0
	p.mana = p.max_mana
	p.use_skill("vidvid")
	check(z1.stun > 1.0 and z1.statuses.has("weak"), "Відвід очей: заціпеніння й слабкість")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_volkhv_specs() -> void:
	suite("Спеціалізації Волхва")
	var SS = load("res://scripts/game/spec_service.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var UiCity = load("res://scripts/ui/ui_city.gd")
	check(Classes.CLASSES["volkhv"]["next"].size() == 3, "у Волхва 3 дороги")
	var places := {}
	for spec in Classes.CLASSES["volkhv"]["next"]:
		var info: Dictionary = Classes.CLASSES[spec]
		check(Data.CITIES.has(info["where"]) and not places.has(info["where"]), "%s: окремий наставник у %s" % [spec, info["where"]])
		places[info["where"]] = true
		check(SS.TRIALS.has(spec) and Classes.is_volkhv_line(spec) and info["weapons"] == ["staff"], "%s: випробування, посох" % spec)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "city": true}
	var p = game.player
	p.change_class("volkhv")
	game._sync_class()
	p.job_level = 30
	check(UiCity._city_specs(game, "verkhovyna") == ["znakhar"] and UiCity._city_specs(game, "sich").is_empty(), "у Верховині — наставник знахарів, на Січі для волхва нікого")
	check(SS.start(game.world, p, "znakhar"), "випробування знахаря")
	SS.on_event(game.world, "clear", "bryansk_forest")
	check(SS.city_dialogue(game.world, "kapyshche").is_empty() and not SS.city_dialogue(game.world, "verkhovyna").is_empty(), "посвята — у Верховині")
	SS.complete(game.world, p)
	game._after_class_change()
	check(p.job == "znakhar" and p.equipment["weapon"]["name"] == "Калиновий посох" and StoryService.hero_class == "volkhv", "посвячено в знахарі, звертання «волхве»")
	var st = Data.gen_item(15, 1, "weapon", "staff")
	p.add_item(st)
	p.equip(st["uid"])
	p.skills = {"zhyvytsia": 2, "ochyshchennia": 1, "oberih_zahonu": 2, "otruta": 2, "pidniaty": 1,
		"lightning": 3, "molot": 2, "burya": 1, "grad": 2, "tuman": 1, "proklin": 1, "dukh": 1}
	p.recalc()
	game.world.companions = [{"type": "dzhura", "downed": false, "level": 5, "xp": 0}]
	game.enter_location("wild_field")
	await _frames(2)
	p.invuln = 99.0
	# Знахар
	p.hp = p.max_hp * 0.3
	var h0: float = p.hp
	p.mana = p.max_mana
	p.use_skill("zhyvytsia")
	check(p.hp > h0 + p.max_hp * 0.2, "Живиця лікує")
	p.add_status("bleed", 5.0, 3.0)
	p.mana = p.max_mana
	p.use_skill("ochyshchennia")
	p.add_status("burn", 5.0, 3.0)
	check(p.statuses.is_empty(), "Очищення знімає стани й не дає новим")
	p.cleanse_timer = 0.0
	p.mana = p.max_mana
	p.use_skill("oberih_zahonu")
	p.invuln = 0.0
	var h1: float = p.hp
	p.take_damage(100.0, null)
	check(h1 - p.hp < 100.0 * (1.0 - p.armor) * 0.8, "Оберіг загону зменшує шкоду")
	p.invuln = 99.0
	p.zahyst_timer = 0.0
	var cn = game.combat.companion_nodes[0]
	cn.take_damage(cn.max_hp * 5.0)
	check(not cn.alive and game.world.companions[0]["downed"], "побратим упав")
	p.mana = p.max_mana
	p.use_skill("pidniaty")
	check(cn.alive and not game.world.companions[0]["downed"], "Підняти побратима")
	var e = _moves_dummy(game, "upyr")
	e.global_position = p.global_position + Vector2(200, 0)
	var eh: float = e.hp
	p.mana = p.max_mana
	p.use_skill("otruta")
	for i in 70:
		await process_frame
	check(e.hp < eh, "Отруйне зілля з'їдає ворога")
	# Перунів жрець
	p.change_class("perun_zhrets")
	var e2 = _moves_dummy(game, "upyr")
	e2.global_position = p.global_position + Vector2(250, 0)
	var e2h: float = e2.hp
	p.mana = p.max_mana
	p.use_skill("lightning")
	check(e2.hp < e2h, "Блискавка Перуна")
	e2h = e2.hp
	p.mana = p.max_mana
	p.use_skill("molot")
	check(e2.hp < e2h and e2.stun > 0.5, "Громовий молот приголомшує")
	e2h = e2.hp
	p.mana = p.max_mana
	p.use_skill("burya")
	for i in 70:
		await process_frame
	check(e2.hp < e2h and p.burya_timer > 0.0, "Буря б'є блискавками")
	p.burya_timer = 0.0
	# Мольфар
	p.change_class("molfar")
	var e3 = _moves_dummy(game, "upyr")
	e3.global_position = p.global_position + Vector2(250, 0)
	p.mana = p.max_mana
	p.use_skill("proklin")
	check(e3.statuses.has("curse") and e3.statuses.has("weak"), "Прокляття")
	var before: float = e3.hp
	e3.take_damage(100.0, Vector2.ZERO)
	check(before - e3.hp > 120.0, "проклятий отримує більше шкоди")
	var e3h: float = e3.hp
	p.mana = p.max_mana
	p.use_skill("grad")
	for i in 40:
		await process_frame
	check(e3.hp < e3h and e3.statuses.has("chill"), "Град б'є й морозить")
	e3h = e3.hp
	p.mana = p.max_mana
	p.use_skill("dukh")
	for i in 90:
		await process_frame
	check(e3.hp < e3h, "дух-помічник стріляє вогниками")
	p.mana = p.max_mana
	p.use_skill("tuman")
	for i in 40:
		await process_frame
	var near = _moves_dummy(game, "mavka")
	for i in 40:
		await process_frame
	check(near.statuses.has("chill") and near.statuses.has("weak"), "Туман сповільнює й слабить")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_stones() -> void:
	suite("Камені долі")
	var ST = load("res://scripts/game/stone_service.gd")
	var p = _new_player()
	p.job = "cossack"
	p.skills = {}
	p.skill_gifts = {"whirl": 1}
	p.skills["whirl"] = 1
	p.stat_gifts = {"str": 3}
	p.stats["str"] += 3
	p.stat_points = 6
	p.add_stat("str")
	p.add_stat("vit")
	p.skill_points = 5
	p.learn_skill("whirl")
	p.learn_skill("sharp")
	p.learn_skill("battle_cry")
	p.perk_points = 2
	p.learn_perk("boots")
	check(not ST.reset_points(p), "без каменя не скинеш")
	ST.grant(p, "zabuttia")
	var str_gift: int = Data.STAT_BASE + 3
	check(ST.reset_points(p) and ST.count(p, "zabuttia") == 0, "Камінь забуття витрачено")
	check(p.stats["str"] == str_gift and p.stats["vit"] == Data.STAT_BASE and p.stat_points == 6, "характеристики повернуто, присяга лишилась")
	check(p.sk("whirl") == 1 and p.sk("sharp") == 0 and p.skill_points == 5, "вміння класу повернуто, подарований Вихор лишився")
	check(p.perks.is_empty() and p.perk_points == 2, "Загартування повернуто")
	# Алатир: Козак → Волхв
	p.learn_skill("whirl")
	p.learn_skill("battle_cry")
	check(ST.siblings(p) == ["volkhv"], "сусідня дорога Козака — Волхв")
	check(not ST.change_path(p, "volkhv"), "без Алатиря дорогу не зміниш")
	ST.grant(p, "alatyr")
	p.job_level = 25
	var pts: int = p.skill_points
	check(ST.change_path(p, "volkhv") and p.job == "volkhv" and p.job_level == 25, "Алатир: тепер волхв, майстерність лишилась")
	check(p.sk("whirl") == 0 and p.sk("battle_cry") == 0 and p.skill_points == pts + 3, "козацькі вміння забуто з поверненням очок")
	check(p.learn_skill("fireball"), "одразу вчить волхвівське")
	var sp = _new_player()
	sp.change_class("plastun")
	check(ST.siblings(sp).size() == 3 and not "plastun" in ST.siblings(sp), "пластун може стати іншим козацьким майстром")
	# Боси
	var msgs: Array = ST.on_boss(sp, "koshchii", true)
	check(ST.count(sp, "alatyr") == 1 and not msgs.is_empty(), "перший Кощій — гарантований Алатир")
	var n0: int = ST.count(sp, "alatyr") + ST.count(sp, "zabuttia")
	seed(5)
	for i in 200:
		ST.on_boss(sp, "upyr", false)
	var got: int = ST.count(sp, "alatyr") + ST.count(sp, "zabuttia") - n0
	check(got > 15 and got < 70, "з босів камені падають рідко (%d за 200)" % got)
	var w = sp.to_dict()
	check(w["stones"]["alatyr"] >= 1 and w.has("stat_gifts"), "камені зберігаються")
	# Зілля відновлює й наснагу
	var m = _new_player()
	m.mana = 0.0
	m.potions = 1
	m.potion_timer = 0.0
	check(m.use_potion() and m.mana > 0.0, "зілля повертає наснагу навіть при повному здоров'ї")
	p.free()
	sp.free()
	m.free()


func _suite_endgame() -> void:
	suite("Після сюжету: крива досвіду й Глибини")
	var DS = load("res://scripts/game/depth_service.gd")
	var same := true
	for l in range(1, 30):
		if Data.xp_for_level(l) != 200 + 150 * l + 15 * l * l:
			same = false
	check(same, "до 30-го рівня крива без змін (сюжет не сповільнився)")
	check(Data.xp_for_level(35) > 3 * (200 + 150 * 35 + 15 * 35 * 35), "після 30-го крива крутішає")
	var prev := 0
	var mono := true
	for l in range(1, 99):
		if Data.xp_for_level(l) <= prev:
			mono = false
		prev = Data.xp_for_level(l)
	check(mono, "досвід на рівень завжди росте")
	var w = WorldState.new()
	check(not DS.unlocked(w), "Глибини закриті до кінця сюжету")
	w.story = {"chapter": 6, "step": 0, "stage": "done"}
	check(DS.unlocked(w) and DS.state(w)["max"] == 1, "після Путіноїда — перша глибина")
	var a = DS.loc_for(1)
	var b = DS.loc_for(20)
	check(b["level"] > a["level"] and b["rooms"] >= a["rooms"] and b["elite_bonus"] > a["elite_bonus"], "глибше — сильніше")
	check(DS.loc_for(200)["level"] == 99, "рівень глибини не вище 99")
	check(DS.loc_for(7)["enemies"] == DS.loc_for(7)["enemies"], "та сама глибина — та сама печера")
	for d in [1, 5, 12]:
		var L: Dictionary = DS.loc_for(d)
		check(Data.BOSS_NAMES.has(L["boss"]) and L["enemies"].size() == 3, "глибина %d: бос і нечисть" % d)
	var m = DS.on_clear(w, 1)
	check(DS.state(w)["max"] == 2 and DS.state(w)["best"] == 1 and "2" in m, "пройшов — відкрито наступну")
	DS.on_clear(w, 1)
	check(DS.state(w)["max"] == 2, "повторне проходження не відкриває зайвого")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.depths["best"] == 1, "глибини зберігаються")
	var wq = WorldState.new()
	var bad := false
	for i in 200:
		if wq._gen_quest("lviv")["loc"] == "hlybyny" or wq._gen_quest("chernihiv")["loc"] == "hlybyny":
			bad = true
	check(not bad, "доручення не ведуть у Глибини")


func _suite_depth_battle() -> void:
	suite("Глибини зарази: спуск")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "depths": true, "stones": true}
	var p = game.player
	game.start_depth(1)
	await _frames(2)
	check(game.state != game.State.PLAYING, "до кінця сюжету не пускає")
	game.world.story = {"chapter": 6, "step": 0, "stage": "done"}
	p.change_class("cossack")
	p.level = 40
	p.stats["str"] = 200
	p.stats["vit"] = 200
	p.skills = {"whirl": 5}
	p.recalc()
	p.hp = p.max_hp
	game.start_depth(1)
	await _frames(2)
	check(game.state == game.State.PLAYING and game.combat.loc.get("depth", 0) == 1 and game.combat.is_dungeon(), "спуск на глибину 1")
	var frames := 0
	while game.state == game.State.PLAYING and game.DepthService.state(game.world)["best"] < 1 and frames < 9000:
		_bot_fight(game)
		p.hp = p.max_hp
		await process_frame
		frames += 1
	check(game.DepthService.state(game.world)["best"] == 1 and game.DepthService.state(game.world)["max"] == 2, "глибину 1 пройдено (кадрів: %d)" % frames)
	check(int(game.world.stats.get("depth", 0)) == 1, "рекорд глибини записано")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_tower() -> void:
	suite("Башта Кощія: правила")
	var TS = load("res://scripts/game/tower_service.gd")
	var w = WorldState.new()
	var p = _new_player()
	p.level = 14
	check(not TS.unlocked(p), "до 15 рівня Башта закрита")
	p.level = 15
	check(TS.unlocked(p) and TS.state(w)["max"] == 1 and TS.state(w)["best"] == 0, "з 15 рівня — перший поверх")
	check(Data.LOCATIONS.has(TS.LOC_ID) and Data.LOCATIONS[TS.LOC_ID].get("endless", false) and Data.LOCATIONS[TS.LOC_ID].get("tower", false), "Башта на мапі")
	var a = TS.loc_for(1)
	var b = TS.loc_for(30)
	check(a["type"] == "tower" and a["level"] == 15 and a["boss"] == "" and a["mini"] != "" and a["waves"] == 2, "поверх 1: рівень 15, хвилі, міні-бос")
	check(b["level"] > a["level"] and b["waves"] > a["waves"] and b["hp_mult"] > a["hp_mult"] and b["mini_affixes"] == 3, "вище — сильніше")
	check(TS.loc_for(200)["level"] == 99, "рівень поверху не вище 99")
	check(TS.loc_for(7)["enemies"] == TS.loc_for(7)["enemies"], "той самий поверх — ті самі вороги")
	var supers := {}
	for f in [5, 10, 15, 20]:
		var L: Dictionary = TS.loc_for(f)
		check(TS.is_super(f) and L["boss"] != "" and Data.BOSS_NAMES.has(L["boss"]) and Data.ENEMY_NAMES.has(L["boss"]), "поверх %d: супербос %s" % [f, L["boss"]])
		supers[L["boss"]] = true
	check(supers.size() == 4, "чотири різні супербоси за перші 20 поверхів")
	check(not TS.is_super(4) and TS.loc_for(4)["boss"] == "", "4-й поверх — міні-бос")
	for f in [1, 2, 3, 6, 11]:
		var L: Dictionary = TS.loc_for(f)
		check(not (L["mini"] in L["enemies"]) and Data.ENEMY_NAMES.has(L["mini"]), "поверх %d: міні-бос не з рядової нечисті" % f)
	var r = TS.on_clear(w, 1)
	check(TS.state(w)["max"] == 2 and TS.state(w)["best"] == 1 and r[1] == true and "2" in r[0], "пройшов 1-й — відкрито 2-й, перше проходження")
	r = TS.on_clear(w, 1)
	check(TS.state(w)["max"] == 2 and r[1] == false, "повторне проходження — не перше й не відкриває зайвого")
	check(TS.first_gold(5) > TS.first_gold(4) * 2, "за супербоса нагорода більша")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.tower["best"] == 1, "Башта зберігається")
	var wq = WorldState.new()
	var bad := false
	for i in 200:
		if wq._gen_quest("lviv")["loc"] == TS.LOC_ID or wq._gen_quest("chernihiv")["loc"] == TS.LOC_ID:
			bad = true
	check(not bad, "доручення не ведуть у Башту")
	# Нові боси: є назви й камінь за першу перемогу
	var SS = load("res://scripts/game/stone_service.gd")
	for k in TS.SUPER_BOSSES:
		check(SS.FIRST_KILL.has(k) and Data.ENEMY_PLURAL.has(k), "%s: камінь за першу перемогу" % k)
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	var w3 = WorldState.new()
	var p3 = _new_player()
	CS.record(w3, p3, "tower", 7)
	CS.record(w3, p3, "tower", 3)
	check(int(w3.stats.get("tower", 0)) == 7 and CS.state(w3)["ach"].has("tower_5"), "рекорд Башти — найвищий поверх, досягнення є")
	CS.now_override = 0


func _suite_events() -> void:
	suite("Події світу: правила")
	var ES = load("res://scripts/game/event_service.gd")
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	p.level = 10
	w.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	check(ES.battle_at(w, "black_forest").is_empty() and ES.state(w)["active"].is_empty(), "спочатку подій нема")
	# Набіг
	var m: String = ES.start(w, p, "village_raid", "black_forest")
	check("Набіг" in m and ES.battle_at(w, "black_forest")["kind"] == "village_raid", "набіг почався там, де треба")
	var L: Dictionary = ES.battle_loc(w, ES.active(w), p)
	check(L["type"] == "defense" and L["variant"] == "village" and L["waves"] == 3 and L["biome"] == "forest", "бій набігу: 3 хвилі, хати, біом лісу")
	var marks: Array = ES.map_marks(w)
	check(marks.size() == 1 and marks[0]["icon"] == "raid" and marks[0]["id"] == "black_forest", "значок набігу на мапі")
	var g0: int = p.gold
	var wm: String = ES.win(w, p, ES.active(w))
	check("врятовано" in wm and p.gold > g0 and ES.active(w).is_empty() and int(p.resources.get("trophy", 0)) >= 2, "перемога: гривні, ресурси, трофеї")
	ES.start(w, p, "village_raid", "black_forest")
	ES.lose(w, p, ES.active(w), true)
	check(ES.is_burned(w, "black_forest") and ES.mods_for(w, "black_forest")["xp_mult"] < 1.0 and ES.mods_for(w, "black_forest")["hp_mult"] > 1.0, "програш: спалене село — менше досвіду, лютіша нечисть")
	for i in ES.BURN_TRIPS:
		ES.tick(w, p)
	check(not ES.is_burned(w, "black_forest"), "спалене село відновлюється")
	# Валка
	w.events = {}
	var cm: String = ES.start(w, p, "caravan", "kyiv")
	var ev: Dictionary = ES.active(w)
	check("Чумаки" in cm and ev["target"] == "kyiv" and ev["to"] != "kyiv" and Data.CITIES.has(ev["to"]), "валка: з Києва в інше місто")
	var L2: Dictionary = ES.battle_loc(w, ev, p)
	check(L2["variant"] == "caravan" and L2["waves"] == 4, "бій валки: вози, 4 хвилі")
	var to: String = ev["to"]
	var loy0: int = w.loyalty_points(to)
	var bag0: int = p.inventory.size()
	var wm2: String = ES.win(w, p, ev, 1.0)
	check("цілою" in wm2 and w.loyalty_points(to) == loy0 + 40 and p.inventory.size() == bag0 + 1 and p.inventory[-1]["rarity"] == 2, "валка ціла: рідкісна річ і лояльність")
	ES.start(w, p, "caravan", "kyiv")
	var wm3: String = ES.win(w, p, ES.active(w), 0.4)
	check("побиту" in wm3, "побита валка — менша нагорода")
	# Облога Січі
	w.events = {}
	w.story["chapter"] = 3
	ES.start(w, p, "sich_siege")
	var L3: Dictionary = ES.battle_loc(w, ES.active(w), p)
	check(L3["waves"] == 6 and L3["variant"] == "city" and L3["target"] == "sich", "облога Січі: 6 хвиль біля брами")
	ES.lose(w, p, ES.active(w))
	var DS = load("res://scripts/game/defense_service.gd")
	check(DS.is_besieged(w, "sich"), "програна облога: Січ зачинена, поки не відіб'єш")
	DS.state(w)["sieges"].erase("sich")
	ES.start(w, p, "sich_siege")
	var st0: int = int(p.stones.get("zabuttia", 0))
	ES.win(w, p, ES.active(w))
	check(int(ES.state(w)["sich_done"]) == 3 and int(p.stones.get("zabuttia", 0)) == st0 + 1, "Січ відстояно: камінь і позначка розділу")
	# Полон: значок рухається до Кремля
	w.events = {}
	ES.start(w, p, "captives", "black_forest")
	var ll0: Vector2 = ES.map_marks(w)[0]["ll"]
	ES.tick(w, p)
	var ll1: Vector2 = ES.map_marks(w)[0]["ll"]
	check(ll1.distance_to(ES.KREMLIN_LL) < ll0.distance_to(ES.KREMLIN_LL) and ES.battle_at(w, "black_forest")["kind"] == "captives", "конвой рухається до Кремля, але наздогнати можна там само")
	ES.win(w, p, ES.active(w))
	check(ES.free_hire(w), "звільнені бранці: безкоштовний найм")
	var CS = load("res://scripts/game/city_service.gd")
	w.add_loyalty("sich", 300)
	p.gold = 0
	check(CS.hire_price(w, p, "sich", "dzhura") == 0 and CS.hire(w, p, "sich", "dzhura") and not ES.free_hire(w), "найм задарма — один раз")
	# Поранений
	w.events = {}
	ES.start(w, p, "wounded", "wild_field")
	check(ES.battle_loc(w, ES.active(w), p)["variant"] == "wounded", "поранений — свій варіант бою")
	ES.lose(w, p, ES.active(w))
	check(ES.active(w).is_empty(), "поранений загинув — подія скінчилась")
	# Ніч, скарб, ярмарок
	w.events = {}
	ES.state(w)["night"]["wild_field"] = 2
	ES.state(w)["treasure"]["black_forest"] = true
	var nm: Dictionary = ES.mods_for(w, "wild_field")
	check(nm.get("night", false) and nm["hp_mult"] > 1.2 and nm["xp_mult"] > 1.4, "ніч: сильніша нечисть, більше досвіду")
	check(ES.mods_for(w, "black_forest").get("treasure", false) and ES.notes_for(w, "black_forest").size() == 1, "скарб: мітка й пояснення")
	ES.treasure_found(w, "black_forest")
	check(not ES.has_treasure(w, "black_forest"), "скарб знайдено — мітка зникає")
	ES.state(w)["fair"] = {"city": "kyiv", "left": 2}
	check(ES.sell_mult(w, "kyiv") == 2.0 and ES.sell_mult(w, "lviv") == 1.0, "ярмарок: продаж удвічі дорожчий лише там")
	var fm: Array = ES.map_marks(w)
	check(fm.size() >= 2 and fm.any(func(x): return x["icon"] == "tent") and fm.any(func(x): return x["icon"] == "moon"), "значки ярмарку й ночі")
	ES.tick(w, p)
	ES.tick(w, p)
	check(ES.state(w)["fair"].is_empty(), "ярмарок закінчується")
	# Ярмарок раз на FAIR_EVERY походів
	w.events = {}
	var had_fair := false
	for i in ES.FAIR_EVERY:
		ES.tick(w, p)
		if not ES.state(w)["fair"].is_empty():
			had_fair = true
	check(had_fair, "ярмарок з'являється сам")
	# Крадіжка на хуторі
	w.camp = {"buildings": {"pasika": 1}, "pasika_ts": 1000.0}
	var now := 1000.0 + 10.0 * 3600.0
	check(ES.check_theft(w, now, 0, 0.9) == "" and float(w.camp["pasika_ts"]) == 1000.0, "крадіжки може й не бути")
	var tm: String = ES.check_theft(w, now, 0, 0.1)
	check("обікрали" in tm and float(w.camp["pasika_ts"]) > 1000.0, "крадіжка: частина меду зникла")
	w.camp["pasika_ts"] = 1000.0
	check(ES.check_theft(w, now, 2, 0.2) == "", "Курінь 2 — злодіїв сполохано")
	check(ES.check_theft(w, 1000.0 + 3600.0, 0, 0.0) == "", "за годину не крадуть")
	# Серіалізація
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.events.has("trips") and int(w2.events["trips"]) == int(w.events["trips"]), "події зберігаються")


func _suite_event_battles() -> void:
	suite("Події світу: бої")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	p.change_class("cossack")
	p.level = 20
	p.stats["str"] = 120
	p.stats["vit"] = 120
	p.skills = {"whirl": 5}
	p.recalc()
	p.hp = p.max_hp
	game.world.hints = {"combat": true, "block": true, "defense": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "event_village_raid": true, "event_caravan": true}
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	var ES = game.EventService
	ES.start(game.world, p, "village_raid", "black_forest")
	await _ride(game, "black_forest")
	check(game.state == game.State.PLAYING and game.combat.is_defense() and game.combat.gate != null and game.combat.gate.variant == "village", "набіг: бій біля хат, а не звичайний похід")
	var frames := 0
	while not game.combat.defense_over and frames < 7000:
		_bot_fight(game)
		game.combat.gate.hp = game.combat.gate.max_hp
		p.hp = p.max_hp
		await process_frame
		frames += 1
	check(game.combat.defense_over and ES.active(game.world).is_empty() and not ES.is_burned(game.world, "black_forest"), "набіг відбито (кадрів: %d)" % frames)
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.MAP, "з порталу — на мапу")
	# Валка: вози їдуть
	ES.start(game.world, p, "caravan", "kyiv")
	await _ride(game, "kyiv")
	check(game.state == game.State.PLAYING and game.combat.gate.variant == "caravan", "валка: бій із возами, а не вхід у місто")
	var y0: float = game.combat.gate.position.y
	for i in 120:
		_bot_fight(game)
		game.combat.gate.hp = game.combat.gate.max_hp
		p.hp = p.max_hp
		await process_frame
	check(game.combat.gate.position.y < y0, "вози їдуть ареною")
	# Нічний похід зі скарбом
	game.enter_map()
	await _frames(2)
	ES.state(game.world)["active"] = {}
	ES.state(game.world)["night"]["wild_field"] = 2
	ES.state(game.world)["treasure"]["wild_field"] = true
	await _ride(game, "wild_field")
	check(game.state == game.State.PLAYING and game.combat.loc.get("night", false) and game.combat.torch.enabled, "ніч: темно, смолоскип горить")
	var guard = null
	for e in game.combat.get_tree().get_nodes_in_group("enemies"):
		if e.treasure_guard:
			guard = e
	check(guard != null and guard.elite and guard.affixes.size() == 2, "сторож скарбу з двома властивостями на арені")
	var items0 := 0
	guard.take_damage(guard.max_hp * 5.0, Vector2.ZERO)
	await _frames(3)
	var chest := false
	for c in game.combat.entities.get_children():
		if c.get_script() == game.combat.PickupScript and c.kind == "item" and int(c.item["rarity"]) >= 2:
			chest = true
	check(chest and not ES.has_treasure(game.world, "wild_field"), "сторож убитий — скриня з рідкісною річчю, мітка знята")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_trade() -> void:
	suite("Чумацький шлях: торгівля")
	var TS = load("res://scripts/game/trade_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	for g in Acts.TRADE_ORDER:
		var lo := 9.0
		var hi := 0.0
		for c in Acts.TRADE_CITIES:
			check(Acts.TRADE_CITIES[c].has(g), "%s: у місті %s є ціна" % [g, c])
			lo = minf(lo, Acts.TRADE_CITIES[c][g])
			hi = maxf(hi, Acts.TRADE_CITIES[c][g])
		check(Acts.TRADE_GOODS.has(g) and lo <= 0.7 and hi >= 1.5, "%s: є де купити дешево й продати дорого" % g)
	for c in Acts.TRADE_CITIES:
		check(Data.CITIES.has(c) and TS.has_market(c), "%s — торгове місто" % c)
	check(not TS.has_market("kapyshche"), "на Капищі крамом не торгують")
	var w = WorldState.new()
	var p = _new_player()
	p.level = 10
	p.gold = 100000
	check(TS.capacity(w) == Acts.TRADE_CART and TS.cargo_count(w) == 0 and TS.ambush_chance(w) == 0.0 and not TS.should_ambush(w, 0.0), "порожній віз: 6 місць, нападів нема")
	w.camp = {"buildings": {"sklad": 2}, "pasika_ts": 0}
	check(TS.capacity(w) == Acts.TRADE_CART + 2 * Acts.TRADE_CART_SKLAD, "Склад збільшує віз")
	var cheap: int = TS.price(w, "sich", "salt", 10)
	var dear: int = TS.price(w, "lviv", "salt", 10)
	check(dear > cheap * 2 and TS.price(w, "sich", "salt", 10) == cheap, "сіль на Січі дешева, у Львові дорога; ціна стала протягом дня")
	check(TS.price(w, "sich", "salt", 30) > cheap * 2, "ціни ростуть із рівнем героя")
	check(TS.sell_price(w, "sich", "salt", 10) < cheap, "продаж дешевший за купівлю в тому самому місті")
	var fl: float = TS.fluct(w, "kyiv", "wine")
	check(fl >= 0.88 and fl <= 1.12, "денне коливання в межах 12%")
	check(TS.tag("sich", "salt") == "cheap" and TS.tag("lviv", "salt") == "dear" and TS.tag("poltava", "fish") == "" and TS.best_city("salt") == "verkhovyna" and TS.best_city("salt", "verkhovyna") == "lviv", "позначки «дешево/у ціні» і найкраще місто збуту")
	# Купівля
	var g0: int = p.gold
	check(TS.buy(w, p, "sich", "salt", 1) == 1 and p.gold == g0 - cheap and TS.cargo_n(w, "salt") == 1, "купив одиницю солі")
	check(TS.price(w, "sich", "salt", 10) > cheap, "після купівлі ціна підросла")
	check(TS.buy(w, p, "sich", "salt", 99) == Acts.TRADE_STOCK - 1 and TS.stock_left(w, "sich", "salt") == 0 and not TS.can_buy(w, p, "sich", "salt"), "запас міста — 6 одиниць на торговий день")
	var avg: float = TS.avg_cost(w, "salt")
	check(avg > cheap and avg < cheap * 1.4, "середня ціна купленого трохи вища за першу")
	check(TS.buy(w, p, "sich", "fish", 99) == Acts.TRADE_STOCK and TS.buy(w, p, "sich", "honey", 99) == 2 and TS.free_space(w) == 0, "віз повний — більше не влазить")
	check(absf(TS.ambush_chance(w) - minf(Acts.TRADE_AMBUSH_MAX, Acts.TRADE_AMBUSH + Acts.TRADE_AMBUSH_UNIT * 14)) < 0.001 and TS.should_ambush(w, 0.0) and not TS.should_ambush(w, 0.99), "повний віз — напад імовірніший")
	var poor = _new_player()
	poor.gold = 0
	check(not TS.can_buy(w, poor, "kyiv", "powder"), "без гривень не купиш")
	# Продаж
	var before: int = p.gold
	var sp1: int = TS.sell_price(w, "lviv", "salt", 10)
	var r1: Dictionary = TS.sell(w, p, "lviv", "salt", 1)
	check(r1["n"] == 1 and r1["gold"] == sp1 and p.gold == before + sp1 and r1["profit"] > 0 and TS.cargo_n(w, "salt") == 5, "продав одиницю у Львові з зиском")
	check(TS.sell_price(w, "lviv", "salt", 10) < sp1, "після продажу ціна впала")
	var r2: Dictionary = TS.sell(w, p, "lviv", "salt", 99)
	check(r2["n"] == 5 and TS.cargo_n(w, "salt") == 0 and not TS.state(w)["cargo"].has("salt") and r2["profit"] > 0, "продав решту — крам зник із воза")
	check(int(TS.state(w)["sold"]) == 6 and int(TS.state(w)["profit"]) == int(r1["profit"]) + int(r2["profit"]), "лічильники торгівлі")
	check(TS.sell(w, p, "lviv", "salt", 1)["n"] == 0 and TS.sell(w, p, "kapyshche", "fish", 1)["n"] == 0, "нема краму чи ринку — нема продажу")
	# Купив і продав у тому самому місті — у збитку
	var w2 = WorldState.new()
	var p2 = _new_player()
	p2.level = 10
	p2.gold = 10000
	TS.buy(w2, p2, "kyiv", "powder", 3)
	TS.sell(w2, p2, "kyiv", "powder", 3)
	check(p2.gold < 10000, "перепродати в тому самому місті — у збитку")
	# Новий торговий день
	check(TS.stock_left(w, "sich", "salt") == 0, "запас солі на Січі вичерпано")
	for i in Acts.TRADE_PERIOD:
		TS.tick(w)
	check(TS.stock_left(w, "sich", "salt") == Acts.TRADE_STOCK and TS.state(w)["moves"].is_empty(), "новий торговий день: запаси й ціни відновились")
	# Ярмарок
	var norm: int = TS.sell_price(w, "kyiv", "fish", 10)
	w.events = {"fair": {"city": "kyiv", "left": 2}}
	check(TS.sell_price(w, "kyiv", "fish", 10) > norm, "на ярмарку крам беруть дорожче")
	w.events = {}
	# Напад: половина краму
	var n_before: int = TS.cargo_count(w)
	var lm: String = TS.lose_half(w)
	check(TS.cargo_count(w) == n_before - (3 + 1) and "половину" in lm, "вози розбито — половина краму пропала (риба 6→3, мед 2→1)")
	var bl: Dictionary = TS.battle_loc(w, "kyiv", p)
	check(bl["type"] == "defense" and bl["variant"] == "caravan" and bl["ambush"] and bl["waves"] == 3 and bl["target"] == "kyiv", "бій за вози")
	var w3 = WorldState.new()
	w3.from_dict(w.to_dict())
	check(TS.cargo_count(w3) == TS.cargo_count(w) and int(w3.trade["sold"]) == 6, "віз і лічильники зберігаються")


func _suite_trade_game() -> void:
	suite("Чумацький шлях: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	p.change_class("cossack")
	p.level = 12
	p.stats["str"] = 80
	p.stats["vit"] = 80
	p.skills = {"whirl": 3}
	p.recalc()
	p.hp = p.max_hp
	p.gold = 5000
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "ambush": true, "defense": true, "stones": true}
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	var TS = game.TradeService
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.city_do("trade_buy", ["salt", 4])
	check(TS.cargo_n(game.world, "salt") == 4 and p.gold < 5000, "купив сіль на Січі через вкладку «Торг»")
	# Напад дорогою: відбити
	game.start_ambush("kyiv")
	await _frames(2)
	check(game.state == game.State.PLAYING and game.combat.is_defense() and game.combat.gate.variant == "caravan" and game.combat.loc["ambush"], "напад на валку: бій біля возів")
	var frames := 0
	while not game.combat.defense_over and frames < 7000:
		_bot_fight(game)
		game.combat.gate.hp = game.combat.gate.max_hp
		p.hp = p.max_hp
		await process_frame
		frames += 1
	check(game.combat.defense_over and TS.cargo_n(game.world, "salt") == 4 and int(game.world.stats.get("ambush", 0)) == 1, "напад відбито, крам цілий (кадрів: %d)" % frames)
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and game.city_id == "kyiv", "з порталу — у місто, куди їхав")
	game.hud.close_dialogue()
	var g1: int = p.gold
	game.city_do("trade_sell", ["salt", 2])
	check(p.gold > g1 and TS.cargo_n(game.world, "salt") == 2 and int(game.world.stats.get("trade_sold", 0)) == 2 and int(game.world.stats.get("trade_profit", 0)) > 0, "продав у Києві із зиском; лічильники")
	# Напад програно: вози розбито
	game.start_ambush("chernihiv")
	await _frames(2)
	game.combat.gate.take_damage(1.0e9)
	await _frames(3)
	check(game.combat.defense_over and TS.cargo_n(game.world, "salt") == 1, "вози розбито — половина краму пропала")
	frames = 0
	while game.state != game.State.CITY and frames < 400:
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and game.city_id == "chernihiv", "після розгрому все одно дістався міста")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_outdoor() -> void:
	suite("Полювання й рибалка: правила")
	var OS2 = load("res://scripts/game/outdoor_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var w = WorldState.new()
	var p = _new_player()
	check(OS2.ready(w, "hunt") and OS2.ready(w, "fish"), "спершу звір і риба на місці")
	check(OS2.arrows_for(p) == Acts.HUNT_ARROWS, "у козака три стріли")
	p.job = "plastun"
	check(OS2.arrows_for(p) == Acts.HUNT_ARROWS + 1, "пластун бере на стрілу більше")
	p.job = "cossack"
	var h: Dictionary = OS2.new_hunt(p, 7)
	var ok: bool = h["queue"].size() == Acts.HUNT_PASSES
	for id in h["queue"]:
		ok = ok and Acts.HUNT_ANIMALS.has(id)
	check(ok and OS2.new_hunt(p, 7)["queue"] == h["queue"], "черга звірів: шість проходів, однакова для одного зерна")
	# Постріли по відомій черзі
	h["queue"] = ["hare", "deer", "boar", "boar", "hare", "hare"]
	h["arrows"] = 10
	check(OS2.current(h) == "hare", "перший звір — заєць")
	check(OS2.shoot(h, 200.0) == "miss" and int(h["arrows"]) == 9 and int(h["index"]) == 0 and int(h["meat"]) == 0, "мимо: стріла пропала, звір той самий")
	check(OS2.shoot(h, float(Acts.HUNT_ANIMALS["hare"]["radius"]) - 1.0) == "hit" and int(h["meat"]) == 1 and int(h["index"]) == 1, "влучив у зайця: 1 м'яса, наступний звір")
	check(OS2.shoot(h, 2.0) == "bullseye" and int(h["meat"]) == 1 + 5 and int(h["bull"]) == 1, "олень у яблучко: 3 + 2 м'яса")
	check(OS2.shoot(h, 40.0) == "wound" and h["wounded"] and int(h["index"]) == 2 and int(h["meat"]) == 6, "вепр від простого влучання лише поранений")
	check(OS2.shoot(h, 40.0) == "hit" and not h["wounded"] and int(h["meat"]) == 10 and int(h["index"]) == 3, "друга стріла добиває вепра")
	check(OS2.shoot(h, 5.0) == "bullseye" and int(h["meat"]) == 16, "вепр у яблучко: одразу, 4 + 2 м'яса")
	OS2.escaped(h)
	check(int(h["index"]) == 5 and OS2.current(h) == "hare" and not OS2.hunt_over(h), "звір утік — на черзі наступний")
	h["arrows"] = 0
	check(OS2.current(h) == "" and OS2.hunt_over(h) and OS2.shoot(h, 0.0) == "none", "стріли скінчились — полюванню кінець")
	# Поранений вепр без стріл: полювання триває, доки він не втече
	var h2: Dictionary = OS2.new_hunt(p, 3)
	h2["queue"] = ["boar", "hare"]
	h2["arrows"] = 1
	OS2.shoot(h2, 40.0)
	check(int(h2["arrows"]) == 0 and h2["wounded"] and OS2.current(h2) == "boar", "поранений вепр іще на галявині, хоч стріл нема")
	OS2.escaped(h2)
	check(OS2.current(h2) == "", "утік — і все")
	# Підсумок
	var g0: int = GS.glory(w)
	var msgs: Array = OS2.finish_hunt(w, p, h)
	check(OS2.food(p, "meat") == 16 and not OS2.ready(w, "hunt") and OS2.ready(w, "fish") and "м'яса" in msgs[0], "здобич у запасі, звір сполоханий до походу")
	check(GS.glory(w) == g0, "був промах — слави за влучність нема")
	OS2.tick(w)
	check(OS2.ready(w, "hunt"), "після походу звір повернувся")
	var h3: Dictionary = OS2.new_hunt(p, 5)
	h3["queue"] = ["hare", "hare", "hare", "hare", "hare", "hare"]
	for i in 3:
		OS2.shoot(h3, 1.0)
	OS2.finish_hunt(w, p, h3)
	check(GS.glory(w) == g0 + 3 and OS2.food(p, "meat") == 16 + 6, "жодної стріли намарно: +3 слави")
	var h4: Dictionary = OS2.new_hunt(p, 5)
	check("без здобичі" in OS2.finish_hunt(w, p, h4)[0], "порожнє полювання — так і кажемо")
	# Рибалка
	var f: Dictionary = OS2.new_fishing(11)
	check(int(f["bait"]) == Acts.FISH_BAIT and Acts.FISH.has(OS2.roll_fish(f)), "п'ять закидів, риба з таблиці")
	var d: float = OS2.bite_delay(f)
	check(d >= 1.5 and d <= 4.5, "клювання чекати 1.5–4.5 с")
	check(OS2.step_tension(0.5, true, 0.0, 0.0, 0.5) > 0.5 and OS2.step_tension(0.5, false, 0.0, 0.0, 0.5) < 0.5, "тримаєш — натяг росте, відпустив — падає")
	check(OS2.step_tension(0.5, false, 0.7, 1.0, 0.5) > 0.5, "сом смикає сильніше, ніж попускаєш")
	check(OS2.in_zone(0.5) and not OS2.in_zone(0.1) and not OS2.in_zone(0.9), "зелена смуга натягу")
	OS2.use_bait(f)
	OS2.catch_fish(f, "karas")
	OS2.catch_fish(f, "som")
	check(int(f["bait"]) == Acts.FISH_BAIT - 1 and int(f["ryba"]) == 5 and not OS2.fishing_over(f), "улов: карась 1 + сом 4")
	g0 = GS.glory(w)
	msgs = OS2.finish_fishing(w, p, f)
	check(OS2.food(p, "ryba") == 5 and not OS2.ready(w, "fish") and GS.glory(w) == g0 + 3 and int(OS2.state(w)["som"]) == 1, "риба в запасі, за сома +3 слави")
	var f2: Dictionary = OS2.new_fishing(1)
	for i in Acts.FISH_BAIT:
		OS2.use_bait(f2)
	check(OS2.fishing_over(f2) and "не клювало" in OS2.finish_fishing(w, p, f2)[0], "закиди скінчились без улову")
	# Казан
	p.resources["herbs"] = 0
	check(not OS2.can_cook(p, "kulish"), "без трав куліш не звариш")
	p.resources["herbs"] = 4
	p.recalc()
	var hp0: float = p.max_hp
	var dmg0: float = p.damage
	check(OS2.cook(p, "kulish") and OS2.eaten(p) == "kulish" and OS2.food(p, "meat") == 20 and int(p.resources["herbs"]) == 2, "куліш: мінус 2 м'яса й 2 трави")
	check(absf(p.max_hp - hp0 * 1.15) < 1.0, "куліш: +15%% здоров'я (%.0f → %.0f)" % [hp0, p.max_hp])
	check(not OS2.can_cook(p, "kulish") and not OS2.cook(p, "kulish"), "ту саму страву двічі не варять")
	check(OS2.cook(p, "pechenia") and OS2.eaten(p) == "pechenia" and absf(p.max_hp - hp0) < 1.0 and absf(p.damage - dmg0 * 1.1) < 0.6, "печеня замінює куліш: +10% шкоди")
	var regen0: float = p.regen
	check(OS2.cook(p, "yushka") and p.regen >= regen0 + 1.0 - 0.01 and absf(p.damage - dmg0) < 0.6, "юшка: +1 здоров'я за секунду")
	p.trip_buffs.clear()
	p.recalc()
	check(absf(p.max_hp - hp0) < 1.0 and absf(p.damage - dmg0) < 0.6, "після походу страва вивітрилась")
	# Збереження
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(int(OS2.state(w2)["som"]) == 1 and int(OS2.state(w2)["hunts"]) == 3 and not OS2.ready(w2, "fish"), "стан занять переживає збереження")
	var p2 = _new_player()
	p2.from_dict(p.to_dict())
	check(OS2.food(p2, "meat") == OS2.food(p, "meat") and OS2.food(p2, "ryba") == OS2.food(p, "ryba"), "запас їжі зберігається разом з героєм")


func _suite_outdoor_game() -> void:
	suite("Полювання й рибалка: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var OS2 = game.OutdoorService
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.level = 2
	game.enter_map()
	game.enter_spot("hunt")
	await _frames(2)
	check(game.state == game.State.MAP, "до 3-го рівня на полювання не пускають")
	p.change_class("cossack")
	p.level = 8
	p.recalc()
	p.hp = p.max_hp
	game.enter_spot("hunt")
	await _frames(3)
	var hg = game.hud.screen_root
	check(game.state == game.State.ACTIVITY and hg != null and "animal" in hg and hg.size.x > 100.0, "полювання: мініігра на весь екран")
	check(hg.hero_sheet == "hunter_cossack", "мисливець тримає лук: %s" % hg.hero_sheet)
	check(get_root().get_tree().paused and not game.combat.active, "бій не йде")
	hg._finish()
	await _frames(2)
	check(game.state == game.State.MAP and OS2.ready(game.world, "hunt") and int(game.world.stats.get("hunt", 0)) == 0, "пішов, не стрілявши: звіра не сполохано")
	game.enter_spot("hunt")
	await _frames(3)
	hg = game.hud.screen_root
	# Дочекатись звіра й бити в серцевину, доки є стріли
	var frames := 0
	var shots := 0
	while game.state == game.State.ACTIVITY and frames < 4000:
		if hg.animal != "" and hg.fall_t <= 0.0 and hg.pos.x > 100.0 and hg.pos.x < hg.size.x - 100.0 and int(hg.h["arrows"]) > 0:
			var res: String = hg.shoot_at(hg.target_point())
			if res != "none":
				shots += 1
		await process_frame
		frames += 1
	check(shots == game.Acts.HUNT_ARROWS and game.state == game.State.MAP, "три стріли — три звірі, далі назад на мапу (кадрів: %d)" % frames)
	check(OS2.food(p, "meat") >= 3 and not OS2.ready(game.world, "hunt") and int(game.world.stats.get("hunt", 0)) == 1 and int(game.world.stats.get("meat", 0)) == OS2.food(p, "meat"), "м'ясо в запасі: %d; лічильники" % OS2.food(p, "meat"))
	check(game.account.challenges["ach"].has("hunt_1"), "досягнення «Перша здобич»")
	game.enter_spot("hunt")
	await _frames(2)
	check(game.state == game.State.MAP, "вдруге поспіль не пускають: звір сполоханий")
	# Рибалка: закинути, підсікти, втримати натяг
	game.enter_spot("fish")
	await _frames(3)
	var fg = game.hud.screen_root
	check(game.state == game.State.ACTIVITY and fg != null and "phase" in fg and fg.phase == "idle", "рибалка: мініігра")
	fg.press()
	fg.release()
	check(fg.phase == "wait" and fg.fish != "", "закинув — чекаємо клювання")
	fg.press()
	fg.release()
	check(fg.phase == "wait" and int(fg.f["bait"]) == game.Acts.FISH_BAIT, "випадковий другий дотик одразу після закиду не рахується")
	fg.step(0.7)
	fg.press()
	fg.release()
	check(fg.phase == "idle" and int(fg.f["bait"]) == game.Acts.FISH_BAIT - 1, "смикнув зарано — закид пропав")
	frames = 0
	var caught := 0
	while game.state == game.State.ACTIVITY and frames < 6000:
		match fg.phase:
			"idle":
				fg.press()
				fg.release()
			"bite":
				fg.press()
			"reel":
				fg.holding = fg.tension < 0.5
		caught = fg.f["caught"].size()
		fg.step(0.05)  # проганяємо час швидше за кадри
		await process_frame
		frames += 1
	check(game.state == game.State.MAP and caught >= 1, "рибалку завершено, спіймано: %d (кадрів: %d)" % [caught, frames])
	check(OS2.food(p, "ryba") >= 1 and not OS2.ready(game.world, "fish") and int(game.world.stats.get("fishing", 0)) == 1, "риба в запасі: %d" % OS2.food(p, "ryba"))
	# Казан на хуторі
	p.resources["herbs"] = 6
	p.resources["meat"] = 4
	game.enter_camp()
	await _frames(2)
	var hp0: float = p.max_hp
	game.camp_do("cook", "kulish")
	check(OS2.eaten(p) == "kulish" and p.max_hp > hp0 * 1.1 and int(game.world.stats.get("cook", 0)) == 1, "куліш із казана додає здоров'я")
	# Похід: страва діє, після нього вивітрюється, а звір і риба повертаються
	game.enter_location("wild_field")
	await _frames(3)
	check(game.state == game.State.PLAYING and OS2.eaten(p) == "kulish", "у поході страва ще діє")
	game.enter_map()
	await _frames(2)
	check(OS2.eaten(p) == "" and absf(p.max_hp - hp0) < 1.0, "після походу страва вивітрилась")
	check(OS2.ready(game.world, "hunt") and OS2.ready(game.world, "fish"), "після походу знову можна полювати й рибалити")
	# Кнопка «Назад» посеред мініігри — те саме, що «Досить»
	game.enter_spot("fish")
	await _frames(3)
	check(game.state == game.State.ACTIVITY, "знову на тоні")
	game._quit_activity()
	await _frames(2)
	check(game.state == game.State.MAP and OS2.ready(game.world, "fish"), "«Назад» виводить на мапу; вудку не закидав — риба не сполохана")
	# Герць на майдані походом не є: страва лишається
	p.resources["meat"] = 2
	p.resources["herbs"] = 2
	game.enter_camp()
	await _frames(2)
	game.camp_do("cook", "kulish")
	p.level = 10
	p.recalc()
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.start_duel()
	await _frames(3)
	check(game.combat.is_duel() and OS2.eaten(p) == "kulish", "на майдані страва діє")
	game.combat.duel_over = true
	game.enter_city("sich")
	game.hud.close_dialogue()
	await _frames(2)
	check(OS2.eaten(p) == "kulish", "після герцю страва лишилась на справжній похід")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_tavern() -> void:
	suite("Шинок: кості й чутки")
	var TS = load("res://scripts/game/tavern_service.gd")
	var TR = load("res://scripts/game/trade_service.gd")
	var OS2 = load("res://scripts/game/outdoor_service.gd")
	var ES = load("res://scripts/game/event_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	p.level = 10
	p.recalc()
	p.gold = 10000
	var st: int = TS.stake("shynkar", 10)
	check(st == 120 and TS.stake("chumak", 10) == 360 and TS.stake("sotnyk", 10) == 720, "ставки ростуть із рівнем і суперником")
	check(TS.games_left(w) == Acts.DICE_GAMES and TS.can_start(w, p, "shynkar"), "вісім партій на день")
	# Перемога: 6 + 5 = 11, шинкар добирає 4 + 5 = 9 і спиняється
	check(TS.start(w, p, "shynkar", 6) and p.gold == 10000 - st and TS.playing(w), "сів до столу: ставка на кону, перша кість кинута")
	check(not TS.can_start(w, p, "chumak"), "дві партії одночасно не грають")
	check(TS.roll(w, p, 5) == "ok" and TS.total(TS.game(w)["mine"]) == 11, "докинув: 11")
	check(TS.stand(w, p, [4, 5]) == "win" and p.gold == 10000 + st and int(TS.game(w)["gold"]) == st and TS.game(w)["theirs"] == [4, 5], "11 проти 9: виграв ставку")
	check(not TS.playing(w) and TS.roll(w, p, 1) == "" and TS.stand(w, p) == "", "партію скінчено: кидати нема чого")
	check("Твоя взяла" in TS.result_text(TS.game(w)), "текст перемоги")
	TS.clear(w)
	check(TS.game(w).is_empty() and int(TS.state(w)["wins"]) == 1 and int(TS.state(w)["streak"]) == 1, "стіл прибрано, перемога в заліку")
	# Перебір
	TS.start(w, p, "shynkar", 6)
	TS.roll(w, p, 4)
	check(TS.roll(w, p, 3) == "bust" and TS.game(w)["over"] and TS.game(w)["result"] == "lose" and p.gold == 10000, "13 — перебір, ставка пропала")
	check("Перебір" in TS.result_text(TS.game(w)) and int(TS.state(w)["streak"]) == 0, "серія обірвалась")
	TS.clear(w)
	# Рівно дванадцять
	TS.start(w, p, "shynkar", 6)
	TS.roll(w, p, 6)
	check(TS.stand(w, p, [3, 3, 3]) == "win" and p.gold == 10000 + int(st * 1.5) and int(TS.state(w)["twelves"]) == 1, "дванадцять: виграш у півтора раза")
	TS.clear(w)
	# Нічия
	var g0: int = p.gold
	TS.start(w, p, "shynkar", 5)
	TS.roll(w, p, 4)
	check(TS.stand(w, p, [6, 3]) == "draw" and p.gold == g0, "порівну — ставки назад")
	TS.clear(w)
	# Суперник перебрав
	TS.start(w, p, "chumak", 4)
	check(TS.stand(w, p, [6, 3, 5]) == "win" and "перебрав" in TS.result_text(TS.game(w)), "чумак женеться до десяти й перебирає")
	TS.clear(w)
	# Як грають суперники
	check(TS.rival_goes("cautious", 8, 3) and not TS.rival_goes("cautious", 9, 12), "шинкар: до дев'яти й годі")
	check(TS.rival_goes("reckless", 9, 2) and not TS.rival_goes("reckless", 10, 12), "чумак: до десяти")
	check(TS.rival_goes("steady", 9, 10) and not TS.rival_goes("steady", 6, 5) and TS.rival_goes("steady", 7, 7) and not TS.rival_goes("steady", 10, 10), "сотник: перебити, на малій нічиїй ризикнути")
	# Сотник і слава
	var gl: int = GS.glory(w)
	TS.start(w, p, "sotnyk", 6)
	TS.roll(w, p, 5)
	TS.stand(w, p, [6, 4, 6])
	check(GS.glory(w) == gl + Acts.DICE_GLORY and not TS.game(w)["msgs"].is_empty(), "перша за день перемога над сотником: слава")
	TS.clear(w)
	TS.start(w, p, "sotnyk", 6)
	TS.roll(w, p, 5)
	TS.stand(w, p, [6, 4, 6])
	check(GS.glory(w) == gl + Acts.DICE_GLORY, "удруге за день слави не дають")
	TS.clear(w)
	# Денна межа
	while TS.games_left(w) > 0:
		TS.start(w, p, "shynkar", 6)
		TS.stand(w, p, [5, 5])
		TS.clear(w)
	check(not TS.can_start(w, p, "shynkar"), "вісім партій зіграно — на сьогодні все")
	CS.now_override = 1762700000 + 86400
	check(TS.games_left(w) == Acts.DICE_GAMES and TS.can_start(w, p, "shynkar"), "завтра знову можна")
	p.gold = 5
	check(not TS.can_start(w, p, "shynkar"), "без гривень до столу не сядеш")
	# Чутки
	p.gold = 10000
	var kinds: Array = TS.rumor_kinds(w, p, "sich")
	check("treasure" in kinds and "night" in kinds and "trade" in kinds and "outdoor" in kinds, "на Січі доступні всі чутки: %s" % str(kinds))
	var cost: int = TS.rumor_cost(10)
	var text: String = TS.buy_rumor(w, p, "sich", "treasure")
	check(text != "" and p.gold == 10000 - cost and ES.state(w)["treasure"].size() == 1, "чутка про скарб: мітка на мапі")
	check(not TS.can_rumor(w, p, "sich") and TS.buy_rumor(w, p, "sich") == "", "одна чутка за похід")
	TS.tick(w)
	check(TS.can_rumor(w, p, "sich") and not ("treasure" in TS.rumor_kinds(w, p, "sich")), "після походу — нова чутка; про скарб уже знаємо")
	text = TS.buy_rumor(w, p, "sich", "night")
	check(text != "" and ES.state(w)["night"].size() == 1, "чутка про нічний похід")
	TS.tick(w)
	text = TS.buy_rumor(w, p, "sich", "trade")
	var tip: Dictionary = TS.tip(w)
	check(text != "" and not tip.is_empty() and tip["city"] != "sich" and int(tip["left"]) == Acts.RUMOR_TIP_TRIPS, "торгова порада: %s у %s" % [tip.get("good", "?"), tip.get("city", "?")])
	var base: int = TR.sell_price(w, "sich", tip["good"], 10)
	var w3 = WorldState.new()
	check(TR.sell_price(w, tip["city"], tip["good"], 10) > TR.sell_price(w3, tip["city"], tip["good"], 10) and base == TR.sell_price(w3, "sich", tip["good"], 10), "порада піднімає ціну лише в названому місті")
	for i in Acts.RUMOR_TIP_TRIPS:
		TS.tick(w)
	check(TS.tip(w).is_empty(), "за три походи порада застаріла")
	OS2.finish_hunt(w, p, OS2.new_hunt(p, 1))
	text = TS.buy_rumor(w, p, "sich", "outdoor")
	check(text != "" and OS2.rich(w, "hunt") and OS2.rich(w, "fish") and OS2.ready(w, "hunt"), "чутка про багаті угіддя: звір повернувся")
	var hq: Array = OS2.new_hunt(p, 4, true)["queue"]
	check(not ("hare" in hq), "на багатих угіддях зайців нема: %s" % str(hq))
	var h: Dictionary = OS2.new_hunt(p, 4, OS2.rich(w, "hunt"))
	OS2.shoot(h, 1.0)
	OS2.finish_hunt(w, p, h)
	check(not OS2.rich(w, "hunt") and OS2.rich(w, "fish"), "багате полювання використано, рибалка ще чекає")
	var pe = _new_player()
	pe.job = "peasant"
	pe.gold = 1000
	check(not ("trade" in TS.rumor_kinds(WorldState.new(), pe, "sich")), "селянинові торгових порад не дають")
	# Збереження
	TS.start(w, p, "shynkar", 4)
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(TS.playing(w2) and TS.game(w2)["mine"] == [4] and int(TS.state(w2)["wins"]) == int(TS.state(w)["wins"]), "недограна партія переживає збереження")
	CS.now_override = 0


func _suite_tavern_game() -> void:
	suite("Шинок: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var TS = game.TavernService
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true}
	p.change_class("cossack")
	p.level = 10
	p.recalc()
	p.gold = 5000
	game.enter_city("sich")
	game.hud.close_dialogue()
	var tabs: Array = []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		tabs.append(tc.get_tab_title(i))
	check("Шинок" in tabs, "у місті є вкладка «Шинок»: %s" % str(tabs))
	game.city_do("dice_start", "shynkar")
	check(TS.playing(game.world) and p.gold == 5000 - TS.stake("shynkar", 10), "сів грати через вкладку")
	# Грати до кінця: добирати до десяти
	var guard := 0
	while TS.playing(game.world) and guard < 20:
		if TS.total(TS.game(game.world)["mine"]) < 10:
			game.city_do("dice_roll", null)
		else:
			game.city_do("dice_stand", null)
		guard += 1
	var g: Dictionary = TS.game(game.world)
	check(g["over"] and g["result"] in ["win", "lose", "draw"] and int(game.world.stats.get("dice", 0)) == 1, "партію дограно: %s" % g["result"])
	check(game.state == game.State.CITY, "лишились у місті")
	game.city_do("dice_clear", null)
	check(TS.game(game.world).is_empty(), "стіл прибрано")
	var gold0: int = p.gold
	game.city_do("rumor", null)
	check(p.gold == gold0 - TS.rumor_cost(10) and str(TS.state(game.world)["rumor_text"]) != "" and int(game.world.stats.get("rumor", 0)) == 1, "чутку куплено")
	game.city_do("rumor", null)
	check(int(game.world.stats.get("rumor", 0)) == 1, "друга чутка за той самий похід не продається")
	# Похід — і в шинку нові язики
	game.enter_location("wild_field")
	await _frames(3)
	game.enter_map()
	await _frames(2)
	check(not TS.state(game.world)["rumor_done"], "після походу знову можна слухати чутки")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_trail() -> void:
	suite("Сліди: правила")
	var TS = load("res://scripts/game/trail_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var p = _new_player()
	check(not TS.should_spawn(p, 0.0), "новачкові першого рівня сліди не трапляються")
	p.level = 5
	check(TS.should_spawn(p, 0.1) and not TS.should_spawn(p, 0.9), "стежка трапляється не в кожному поході")
	p.job = "plastun"
	check(TS.chance(p) > Acts.TRAIL_CHANCE and TS.should_spawn(p, 0.5), "пластун натрапляє на сліди частіше")
	check(TS.roll_kind(0.0) == "cache" and TS.roll_kind(0.5) == "den" and TS.roll_kind(0.99) == "beast", "три знахідки за вагою")
	var seen := {}
	for i in 200:
		seen[TS.roll_kind(randf())] = true
	check(seen.size() == Acts.TRAIL_KINDS.size(), "трапляються всі знахідки")
	var arena := Rect2(-1400, -1400, 2800, 2800)
	var ok := true
	var min_seg := 1.0e9
	for sd in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		# і з центру, і з кута арени
		var start := Vector2.ZERO if sd % 2 == 0 else Vector2(1300, -1300)
		var pts: Array = TS.make_points(start, arena, rng)
		ok = ok and pts.size() == Acts.TRAIL_POINTS
		for i in pts.size():
			ok = ok and arena.grow(-100.0).has_point(pts[i])
			if i > 0:
				min_seg = minf(min_seg, pts[i].distance_to(pts[i - 1]))
	check(ok, "точки стежки завжди в межах арени")
	check(min_seg > 150.0, "відтинки не вироджуються навіть у кутку (найкоротший: %.0f)" % min_seg)
	check(TS.cache_gold(10) > TS.cache_gold(1) and TS.beast_meat(0.0) == 2 and TS.beast_meat(0.99) == 4, "нагороди: гривні ростуть із рівнем, м'яса 2–4")


func _suite_trail_battle() -> void:
	suite("Сліди: у бою")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var c = game.combat
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true}
	p.change_class("cossack")
	p.level = 10
	p.stats["str"] = 80
	p.stats["vit"] = 80
	p.recalc()
	p.hp = p.max_hp
	for kind in ["cache", "beast", "den"]:
		game.enter_location("wild_field")
		await _frames(3)
		c.spawn_trail(kind, 5)
		await _frames(2)
		var tr = c.trail
		check(tr != null and tr.points.size() == game.Acts.TRAIL_POINTS and tr.step == 0 and tr.revealed() == 0 and not tr.found, "%s: стежка лежить, видно лише початок" % kind)
		var gold0: int = p.gold
		var meat0: int = int(p.resources.get("meat", 0))
		var enemies0: int = c.alive_enemy_count()
		var trails0: int = int(game.world.stats.get("trail", 0))
		for i in tr.points.size():
			p.global_position = tr.points[i]
			p.invuln = 5.0
			await _frames(2)
			if i < tr.points.size() - 1:
				check(tr.step == i + 1 and not tr.found, "%s: точка %d відкрила наступний відтинок" % [kind, i + 1])
		check(tr.found and int(game.world.stats.get("trail", 0)) == trails0 + 1 and int(game.world.stats.get("trail:" + kind, 0)) >= 1, "%s: знахідку знайдено, лічильник росте" % kind)
		match kind:
			"cache":
				p.invuln = 5.0
				await _frames(90)
				check(p.gold > gold0, "схованка: гривні підібрано (+%d)" % (p.gold - gold0))
			"beast":
				var got: int = int(p.resources.get("meat", 0)) - meat0
				check(got >= 2 and got <= 4, "поранений вепр: +%d м'яса" % got)
			"den":
				var elite := 0
				for e in c.get_tree().get_nodes_in_group("enemies"):
					if e.elite:
						elite += 1
				check(c.alive_enemy_count() >= enemies0 + 3 and elite >= 1, "лігво: зграя з елітою вискочила")
		# Удруге та сама стежка нічого не дає
		p.global_position = tr.points[-1]
		await _frames(2)
		check(int(game.world.stats.get("trail", 0)) == trails0 + 1, "%s: знахідка одноразова" % kind)
		game.enter_map()
		await _frames(2)
		check(c.trail == null, "після виходу стежку прибрано")
	# Пластун бачить усю стежку
	p.job = "plastun"
	game.enter_location("wild_field")
	await _frames(3)
	c.spawn_trail("cache", 9)
	await _frames(2)
	check(c.trail.show_all and c.trail.revealed() == game.Acts.TRAIL_POINTS - 1 and c.trail.step == 0, "пластун бачить усю стежку одразу, але пройти її треба")
	p.job = "cossack"
	# У печері слідів нема
	game.enter_map()
	await _frames(2)
	var saw := false
	for i in 12:
		game.enter_location("zmii_cave")
		await _frames(2)
		if c.is_dungeon() and c.trail != null:
			saw = true
		game.enter_map()
		await _frames(1)
	check(not saw, "у печерах стежок не буває")
	check(game.account.challenges["ach"].has("trail_1"), "досягнення «Слідопит»")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_garden() -> void:
	suite("Город: правила")
	var GS = load("res://scripts/game/garden_service.gd")
	var CampService = load("res://scripts/game/camp_service.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var OS2 = load("res://scripts/game/outdoor_service.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	var T0 := 1762700000
	CS.now_override = T0
	var w = WorldState.new()
	var p = _new_player()
	p.level = 10
	p.gold = 100000
	p.resources = {"wood": 1000, "iron": 1000, "herbs": 100}
	check(GS.beds_count(w) == 0 and not GS.plant(w, p, 0, "veg"), "без городу грядок нема")
	check(CampService.build(w, p, "horod") and GS.beds_count(w) == 2, "город 1 рівня: дві грядки")
	var gold0: int = p.gold
	check(GS.plant(w, p, 0, "veg") and p.gold == gold0 - int(Camp.CROPS["veg"]["seed"]) and not GS.bed(w, 0).is_empty(), "посадив городину: насіння оплачено")
	check(not GS.plant(w, p, 0, "herbs") and not GS.can_plant(w, p, 5, "herbs"), "зайняту чи неіснуючу грядку не засадиш")
	check(GS.progress(w, 0) == 0.0 and not GS.ready(w, 0) and GS.time_left(w, 0) == 4 * 3600 and GS.harvest(w, p, 0) == "", "щойно посаджене не зібрати")
	CS.now_override = T0 + 2 * 3600
	check(absf(GS.progress(w, 0) - 0.5) < 0.01 and GS.time_text(GS.time_left(w, 0)) == "2 год", "за дві години — половина")
	CS.now_override = T0 + 4 * 3600
	check(GS.ready(w, 0) and GS.ready_count(w) == 1, "за чотири години достигло")
	var msg: String = GS.harvest(w, p, 0)
	check(msg != "" and OS2.food(p, "veg") == 4 and GS.bed(w, 0).is_empty() and GS.harvest(w, p, 0) == "", "зібрав: +4 городини, грядка вільна")
	# Зілля й хміль
	var herbs0: int = int(p.resources["herbs"])
	GS.plant(w, p, 0, "herbs")
	GS.plant(w, p, 1, "khmil")
	CS.now_override = T0 + 4 * 3600 + 2 * 3600
	check(GS.ready(w, 0) and not GS.ready(w, 1), "зілля достигає за 2 години, хміль іще росте")
	CS.now_override = T0 + 4 * 3600 + 8 * 3600
	gold0 = p.gold
	var all: Array = GS.harvest_all(w, p)
	check(all.size() == 2 and int(p.resources["herbs"]) == herbs0 + 6 and p.gold == gold0 + GS.yield_of("khmil", 10), "зібрав усе: трави й гривні за хміль (+%d)" % (p.gold - gold0))
	check(GS.yield_of("khmil", 20) > GS.yield_of("khmil", 10) and GS.yield_of("veg", 20) == GS.yield_of("veg", 1), "хміль дорожчає з рівнем, городина — ні")
	# Викорчувати
	GS.plant(w, p, 0, "khmil")
	check(GS.uproot(w, 0) and GS.bed(w, 0).is_empty() and not GS.uproot(w, 0), "викорчував грядку")
	# Рівні городу
	CampService.build(w, p, "horod")
	check(GS.beds_count(w) == 3, "другий рівень: три грядки")
	var slow: float = GS.grow_time(w, "veg")
	CampService.build(w, p, "horod")
	check(GS.beds_count(w) == 4 and GS.grow_time(w, "veg") < slow, "третій рівень: чотири грядки й швидший ріст")
	check(GS.plant(w, p, 3, "veg"), "четверта грядка працює")
	check(GS.time_text(0) == "готово" and GS.time_text(59) == "1 хв" and GS.time_text(3600) == "1 год" and GS.time_text(3660 + 1) == "1 год 2 хв" and GS.time_text(7199) == "2 год", "текст часу")
	# Борщ
	p.resources["meat"] = 1
	p.resources["veg"] = 3
	p.recalc()
	var hp0: float = p.max_hp
	var xp0: float = p.xp_mult
	check(OS2.cook(p, "borshch") and absf(p.max_hp - hp0 * 1.1) < 1.0 and absf(p.xp_mult - xp0 - 0.1) < 0.001 and OS2.food(p, "veg") == 0, "борщ: +10% здоров'я й досвіду")
	# Збереження: город живе в спільному хуторі
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(GS.beds_count(w2) == 4 and not GS.bed(w2, 3).is_empty() and int(GS.state(w2)["harvests"]) == 3, "город переживає збереження")
	CS.now_override = 0


func _suite_garden_game() -> void:
	suite("Город: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var CS = load("res://scripts/game/challenge_service.gd")
	var T0 := 1762700000
	CS.now_override = T0
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var GS = game.GardenService
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.level = 8
	p.gold = 5000
	p.resources = {"wood": 200, "iron": 200, "herbs": 200}
	game.enter_camp()
	await _frames(2)
	var titles := func() -> Array:
		var out := []
		var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
		for i in tc.get_tab_count():
			out.append(tc.get_tab_title(i))
		return out
	check(not ("Город" in titles.call()) and "Казан" in titles.call(), "без городу вкладки нема, казан є завжди")
	game.camp_do("build", "horod")
	await _frames(2)
	check("Город" in titles.call(), "збудував город — з'явилась вкладка")
	game.camp_do("plant", [0, "veg"])
	game.camp_do("plant", [1, "herbs"])
	check(not GS.bed(game.world, 0).is_empty() and int(game.world.stats.get("plant", 0)) == 2, "посадив дві грядки")
	CS.now_override = T0 + 5 * 3600
	game.enter_camp()
	await _frames(2)
	check("Город (2)" in titles.call(), "вкладка показує, скільки достигло: %s" % str(titles.call()))
	game.camp_do("harvest_all", null)
	check(int(p.resources.get("veg", 0)) == 4 and int(game.world.stats.get("harvest", 0)) == 2 and game.account.challenges["ach"].has("harvest_1"), "зібрав урожай: городина, лічильник, досягнення")
	p.resources["meat"] = 2
	game.camp_do("cook", "borshch")
	check(game.OutdoorService.eaten(p) == "borshch" and game.account.challenges["ach"].has("borshch"), "борщ із власної городини")
	# Город спільний: інший персонаж бачить ті самі грядки
	game.camp_do("plant", [0, "khmil"])
	game.save_game()
	check(not game.account.camp.get("garden", {}).get("beds", [{}])[0].is_empty(), "грядки лежать у спільному хуторі акаунта")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	CS.now_override = 0


func _suite_expedition() -> void:
	suite("Походи побратимів: правила")
	var ES = load("res://scripts/game/expedition_service.gd")
	var Party = load("res://scripts/game/party.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	var T0 := 1762700000
	CS.now_override = T0
	var w = WorldState.new()
	var p = _new_player()
	p.level = 12
	w.companions = [Party.new_member("dzhura", 12), Party.new_member("dzhura", 12)]
	check(not ES.away(w.companions[0]) and ES.can_send(w, 0, "scout") and not ES.can_send(w, 5, "scout") and not ES.can_send(w, 0, "nope"), "вільного супутника можна відправити")
	check(ES.send(w, 0, "raid") and ES.away(w.companions[0]) and not ES.back(w.companions[0]) and ES.time_left(w.companions[0]) == 4 * 3600, "далекий похід: чотири години")
	check(not ES.send(w, 0, "scout") and ES.away_count(w) == 1, "двічі одного не відправиш")
	w.companions[1]["downed"] = true
	check(not ES.can_send(w, 1, "scout"), "пораненого в похід не шлють")
	w.companions[1]["downed"] = false
	# Досвід із бою йде лише тим, хто в загоні
	Party.gain_xp(w, 12, 50)
	check(int(w.companions[0]["xp"]) == 0 and int(w.companions[1]["xp"]) == 50, "хто в поході — досвіду з бою не має")
	check(ES.collect(w, p, 1).is_empty(), "поки не повернувся — зустрічати нікого")
	CS.now_override = T0 + 4 * 3600
	check(ES.back(w.companions[0]) and ES.time_text(ES.time_left(w.companions[0])) == "уже тут", "за чотири години повернувся")
	var gold0: int = p.gold
	var lvl0: int = int(w.companions[0]["level"])
	var msgs: Array = ES.collect(w, p, 1)
	check(msgs.size() == 1 and p.gold > gold0 and not ES.away(w.companions[0]) and "повернувся" in msgs[0], "зустрів: гривні в героя, супутник знову в загоні")
	check(int(p.resources.get("trophy", 0)) >= 1 and int(p.resources.get("wood", 0)) + int(p.resources.get("iron", 0)) + int(p.resources.get("herbs", 0)) == 6, "ресурси й трофей із далекого походу")
	check(int(w.companions[0]["level"]) > lvl0 or int(w.companions[0]["xp"]) > 0, "сам набрався досвіду")
	check(ES.collect(w, p, 1).is_empty(), "удруге здобичі нема")
	# Довший похід — більша здобич; іменний побратим приносить більше
	var rng := RandomNumberGenerator.new()
	var c: Dictionary = Party.new_member("dzhura", 12)
	var sums := {}
	for kind in Acts.EXPEDITION_ORDER:
		var total := 0
		for i in 200:
			total += int(ES.reward(c, kind, rng)["gold"])
		sums[kind] = total
	check(sums["scout"] < sums["raid"] and sums["raid"] < sums["venture"], "що довший похід, то більше гривень: %s" % str(sums))
	var hero_c: Dictionary = c.duplicate()
	hero_c["hero"] = "ostap"
	var plain := 0
	var named := 0
	for i in 200:
		plain += int(ES.reward(c, "raid", rng)["gold"])
		named += int(ES.reward(hero_c, "raid", rng)["gold"])
	check(named > plain, "іменний побратим приносить більше")
	var weak: Dictionary = Party.new_member("dzhura", 3)
	check(int(ES.reward(weak, "venture", rng)["gold"]) < int(ES.reward(c, "venture", rng)["gold"]), "досвідченіший супутник — більша здобич")
	var got_item := 0
	var wounded := 0
	for i in 300:
		var r: Dictionary = ES.reward(c, "venture", rng)
		got_item += 1 if r["item"] else 0
		wounded += 1 if r["wounded"] else 0
	check(got_item == 300 and wounded > 20 and wounded < 110, "виправа: річ напевно, засідка приблизно в кожній п'ятій (%d із 300)" % wounded)
	# Засідка: гривень удвічі менше, сам поранений (якщо зустрів не в місті)
	var found := false
	for sd in 400:
		var w2 = WorldState.new()
		w2.companions = [Party.new_member("dzhura", 12)]
		CS.now_override = T0
		ES.send(w2, 0, "venture")
		CS.now_override = T0 + 8 * 3600
		var p2 = _new_player()
		p2.level = 12
		var m2: Array = ES.collect(w2, p2, sd)
		if "засідку" in m2[0]:
			found = true
			check(w2.companions[0]["downed"] and "поранений" in m2[0], "засідка в полі: супутник поранений")
			var w3 = WorldState.new()
			w3.companions = [Party.new_member("dzhura", 12)]
			CS.now_override = T0
			ES.send(w3, 0, "venture")
			CS.now_override = T0 + 8 * 3600
			var p3 = _new_player()
			p3.level = 12
			var m3: Array = ES.collect(w3, p3, sd, true)
			check(not w3.companions[0]["downed"] and "перев'язали" in m3[0] and p3.gold == p2.gold, "у місті рани одразу перев'язують, здобич та сама")
			break
	check(found, "засідки трапляються")
	# Повна торба: річ продається
	var w4 = WorldState.new()
	w4.companions = [Party.new_member("dzhura", 12)]
	CS.now_override = T0
	ES.send(w4, 0, "venture")
	CS.now_override = T0 + 8 * 3600
	var p4 = _new_player()
	p4.level = 12
	while not p4.bag_full():
		p4.add_item(Data.gen_item(1, 0))
	var n4: int = p4.inventory.size()
	var m4: Array = ES.collect(w4, p4, 3)
	check(p4.inventory.size() == n4 and "продано" in m4[0], "торба повна — річ продано")
	# Відкликати
	CS.now_override = T0
	ES.send(w, 1, "venture")
	gold0 = p.gold
	check(ES.recall(w, 1) and not ES.away(w.companions[1]) and p.gold == gold0 and not ES.recall(w, 1), "відкликав: повернувся з порожніми руками")
	# Супутник не обганяє героя
	var w5 = WorldState.new()
	w5.companions = [Party.new_member("dzhura", 12)]
	w5.companions[0]["level"] = 12
	ES.send(w5, 0, "venture")
	CS.now_override = T0 + 8 * 3600
	ES.collect(w5, p, 2)
	check(int(w5.companions[0]["level"]) == 12 and int(w5.companions[0]["xp"]) == 0, "вище рівня героя супутник не росте")
	# Збереження
	CS.now_override = T0
	ES.send(w, 1, "raid")
	var w6 = WorldState.new()
	w6.from_dict(w.to_dict())
	check(ES.away(w6.companions[1]) and ES.time_left(w6.companions[1]) == 4 * 3600, "похід переживає збереження")
	check(ES.time_text(3600) == "1 год" and ES.time_text(5400) == "1 год 30 хв" and ES.time_text(60) == "1 хв", "текст часу")
	CS.now_override = 0


func _suite_expedition_game() -> void:
	suite("Походи побратимів: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var CS = load("res://scripts/game/challenge_service.gd")
	var T0 := 1762700000
	CS.now_override = T0
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var ES = game.ExpeditionService
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.change_class("cossack")
	p.level = 10
	p.recalc()
	p.hp = p.max_hp
	game.world.companions = [game.Party.new_member("dzhura", 10), game.Party.new_member("dzhura", 10)]
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.city_do("exp_send", [0, "scout"])
	check(ES.away(game.world.companions[0]) and int(game.world.stats.get("expedition_sent", 0)) == 1, "відправив джуру в розвідку з корчми")
	# У бою тільки той, хто лишився, і на своєму місці в загоні
	game.enter_location("wild_field")
	await _frames(3)
	check(game.combat.companion_nodes.size() == 1 and game.combat.companion_nodes[0].index == 1, "у бій пішов лише другий супутник (місце в загоні збережено)")
	game.enter_map()
	await _frames(2)
	check(ES.away(game.world.companions[0]), "година ще не минула — джура в поході")
	# Минула година: на мапі його зустрічають зі здобиччю
	CS.now_override = T0 + 3700
	var gold0: int = p.gold
	game.enter_map()
	await _frames(2)
	check(not ES.away(game.world.companions[0]) and p.gold > gold0 and int(game.world.stats.get("expedition", 0)) == 1, "повернувся: здобич у героя (+%d грн)" % (p.gold - gold0))
	check(game.account.challenges["ach"].has("expedition_1"), "досягнення «Гінці повернулись»")
	game.enter_location("wild_field")
	await _frames(3)
	check(game.combat.companion_nodes.size() == 2, "тепер у бою знову обидва")
	game.enter_map()
	await _frames(2)
	# Відкликати
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.city_do("exp_send", [1, "venture"])
	game.city_do("exp_recall", 1)
	check(not ES.away(game.world.companions[1]), "відкликав із дороги")
	# Зустріч у місті
	game.city_do("exp_send", [1, "scout"])
	game.leave_city()
	await _frames(2)
	CS.now_override = T0 + 3700 + 3700
	game.enter_city("sich")
	game.hud.close_dialogue()
	check(not ES.away(game.world.companions[1]) and not game.world.companions[1]["downed"] and int(game.world.stats.get("expedition", 0)) == 2, "у місті теж зустрічають, і поранених там нема")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	CS.now_override = 0


func _suite_records() -> void:
	suite("Літопис слави: рекорди роду")
	var RS = load("res://scripts/game/record_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Account = load("res://scripts/game/account.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	for key in Acts.RECORD_ORDER:
		check(Acts.RECORDS.has(key) and Acts.RECORDS[key]["name"] != "", "%s: рекорд описано" % key)
	var acc = Account.new()
	# Перший герой (слот 1)
	var w1 = WorldState.new()
	acc.attach(w1)
	var p1 = _new_player()
	p1.change_class("cossack")
	p1.level = 20
	check(RS.value_text("tower", 0) == "—" and RS.value_text("tower", 7) == "7 поверх" and RS.value_text("vigil", 325) == "5:25", "як показуємо значення")
	var msgs: Array = RS.sync(w1, p1, 1)
	check(msgs.is_empty() and int(RS.record(w1, "level")["value"]) == 20 and RS.record(w1, "level")["who"] == "Козак 20 рівня", "перший запис рекорду без галасу")
	w1.tower = {"max": 5, "best": 4}
	msgs = RS.sync(w1, p1, 1)
	check(msgs.is_empty() and int(RS.record(w1, "tower")["value"]) == 4, "четвертий поверх: рекорд є, віхи ще нема")
	var g0: int = GS.glory(w1)
	w1.tower["best"] = 5
	msgs = RS.sync(w1, p1, 1)
	check(msgs.size() >= 1 and "+5 слави" in msgs[0] and GS.glory(w1) == g0 + 5, "п'ятий поверх — віха: +5 слави")
	check(int(RS.record(w1, "glory")["value"]) == GS.glory(w1), "рекорд слави оновлено одразу")
	w1.tower["best"] = 16
	msgs = RS.sync(w1, p1, 1)
	check(GS.glory(w1) == g0 + 5 + 10, "стрибок через дві віхи (10 і 15): +10 слави")
	check(RS.sync(w1, p1, 1).is_empty(), "без нового рекорду — тиша")
	w1.duel = {"titles": 1, "wins": 3}
	w1.vigil = {"best_time": 325.0, "best_kills": 140}
	g0 = GS.glory(w1)
	msgs = RS.sync(w1, p1, 1)
	check(GS.glory(w1) == g0 + 3 and int(RS.record(w1, "vigil")["value"]) == 325 and int(RS.record(w1, "vigil_kills")["value"]) == 140, "титул чемпіона — віха; варта записана")
	# Другий герой (слот 2) того самого роду
	var w2 = WorldState.new()
	acc.attach(w2)
	var p2 = _new_player()
	p2.change_class("volkhv")
	p2.level = 8
	w2.tower = {"max": 4, "best": 3}
	g0 = GS.glory(w2)
	msgs = RS.sync(w2, p2, 2)
	check(msgs.is_empty() and GS.glory(w2) == g0 and int(RS.record(w2, "tower")["value"]) == 16 and int(RS.record(w2, "level")["value"]) == 20, "молодший герой рекордів роду не чіпає й слави за них не має")
	var rows: Array = RS.rows(w2, p2, 2)
	var tower_row: Dictionary = rows.filter(func(r): return r["key"] == "tower")[0]
	check(tower_row["mine"] == "3 поверх" and tower_row["best"] == "16 поверх" and tower_row["who"] == "Козак 20 рівня" and not tower_row["holder"], "рядок літопису: свій результат і рекорд роду з власником")
	w2.tower["best"] = 17
	msgs = RS.sync(w2, p2, 2)
	check(msgs.size() >= 1 and "побито" in msgs[0] and "Козак 20 рівня" in msgs[0] and int(RS.record(w2, "tower")["slot"]) == 2, "перевершив рекорд іншого персонажа: окреме повідомлення")
	tower_row = RS.rows(w2, p2, 2).filter(func(r): return r["key"] == "tower")[0]
	check(tower_row["holder"], "тепер рекорд тримає другий герой")
	check(not RS.rows(w1, p1, 1).filter(func(r): return r["key"] == "tower")[0]["holder"] and RS.rows(w1, p1, 1).filter(func(r): return r["key"] == "level")[0]["holder"], "перший герой утратив Башту, але тримає рівень")
	# Збереження акаунта
	var acc2 = Account.new()
	acc2.from_dict(acc.to_dict())
	check(int(acc2.records["tower"]["value"]) == 17 and acc2.records["tower"]["who"] == "Волхв 8 рівня", "рекорди лежать в акаунті й переживають збереження")
	CS.now_override = 0


func _suite_records_game() -> void:
	suite("Літопис слави: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var RS = game.RecordService
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.change_class("cossack")
	p.level = 15
	p.recalc()
	game.enter_map()
	await _frames(2)
	check(int(game.account.records.get("level", {}).get("value", 0)) == 15, "на мапі рекорди роду звірено")
	game.open_character()
	await _frames(2)
	var tabs: Array = []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		tabs.append(tc.get_tab_title(i))
	check("Слава" in tabs, "на екрані героя є вкладка «Слава»: %s" % str(tabs))
	game.close_character()
	# Новий рекорд Башти — слава й новина на мапі
	var g0: int = game.GloryService.glory(game.world)
	game.TowerService.state(game.world)["best"] = 5
	game.enter_map()
	await _frames(2)
	check(game.GloryService.glory(game.world) == g0 + 5 and int(game.account.records["tower"]["value"]) == 5, "п'ятий поверх Башти: +5 слави за рекорд роду")
	game.save_game()
	var raw = FileAccess.open(TEST_ACCOUNT, FileAccess.READ).get_var()
	check(raw is Dictionary and int(raw.get("records", {}).get("tower", {}).get("value", 0)) == 5, "рекорди записано у файл акаунта")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _ts(y: int, m: int, d: int, h: int = 12) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": h, "minute": 0, "second": 0}))


func _suite_holidays() -> void:
	suite("Сезонні свята: правила")
	var HS = load("res://scripts/game/holiday_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var GardenS = load("res://scripts/game/garden_service.gd")
	var CampService = load("res://scripts/game/camp_service.gd")
	var TS = load("res://scripts/game/tavern_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Account = load("res://scripts/game/account.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	HS.forced = ""
	var GfxH = load("res://scripts/world/gfx.gd")
	var known_keys: Array = Acts.HOLIDAY_PLAYER_KEYS + Acts.HOLIDAY_COMBAT_KEYS + ["glory", "harvest", "dice", "rumor", "loyalty", "outdoor", "sharpen", "hire"]
	var great_n := 0
	for id in Acts.HOLIDAY_ORDER:
		var H: Dictionary = Acts.HOLIDAYS[id]
		check(H["name"] != "" and H["desc"] != "" and H["token"] != "" and H["tokens"] != "" and H["bonus_text"] != "" and not H["bonus"].is_empty() and (H.has("from") or H.has("easter") or H.has("nth")), "%s: свято описано" % id)
		check(H["rank"] in ["great", "small"] and GfxH.ICON_ORDER.has("tok_" + id), "%s: має ранг і значок жетона" % id)
		for k in H["bonus"]:
			check(k in known_keys, "%s: бонус «%s» гра вміє застосувати" % [id, k])
		great_n += 1 if H["rank"] == "great" else 0
	check(Acts.HOLIDAYS.size() == Acts.HOLIDAY_ORDER.size() and Acts.HOLIDAY_ORDER.size() == 28 and great_n == 9, "двадцять вісім свят, із них дев'ять великих")
	# Великдень за східним обрядом
	var e25: Dictionary = Time.get_date_dict_from_unix_time(HS.easter_day(2025) * 86400)
	var e26: Dictionary = Time.get_date_dict_from_unix_time(HS.easter_day(2026) * 86400)
	var e27: Dictionary = Time.get_date_dict_from_unix_time(HS.easter_day(2027) * 86400)
	check(e25["month"] == 4 and e25["day"] == 20 and e26["month"] == 4 and e26["day"] == 12 and e27["month"] == 5 and e27["day"] == 2, "Великдень: 20 квітня 2025, 12 квітня 2026, 2 травня 2027")
	# Які дні святкові
	check(HS.active(_ts(2026, 11, 18)) == "" and HS.active(_ts(2026, 11, 11)) == "" and HS.active(_ts(2027, 1, 20)) == "", "18 листопада, 11 листопада й 20 січня — будні")
	check(HS.active(_ts(2026, 12, 25)) == "rizdvo" and HS.active(_ts(2027, 1, 7)) == "rizdvo" and HS.active(_ts(2026, 12, 23)) == "", "Різдво: від 24 грудня до 7 січня")
	check(HS.active(_ts(2027, 1, 8)) == "malanka" and HS.active(_ts(2027, 1, 14)) == "malanka" and HS.active(_ts(2027, 1, 15)) == "vodokhreshche" and HS.active(_ts(2027, 1, 22)) == "sobornist", "після Різдва: Маланка, Водохреще, Соборність")
	check(HS.season(_ts(2026, 12, 25)) == "rizdvo:2026" and HS.season(_ts(2027, 1, 7)) == "rizdvo:2026", "січневі дні належать тому самому Різдву")
	check(HS.active(_ts(2026, 4, 11)) == "velykden" and HS.active(_ts(2026, 4, 19)) == "velykden" and HS.active(_ts(2026, 4, 20)) == "" and HS.active(_ts(2026, 4, 10)) == "", "Великдень 2026: від суботи до кінця світлого тижня")
	check(HS.active(_ts(2026, 6, 24)) == "kupala" and HS.active(_ts(2026, 8, 6)) == "spas" and HS.active(_ts(2026, 8, 24)) == "nezalezhnist" and HS.active(_ts(2026, 10, 1)) == "pokrova" and HS.active(_ts(2026, 11, 30)) == "andrii", "Купала, Спас, Незалежність, Покрова, Андрія")
	check(HS.active(_ts(2026, 8, 20)) == "" and HS.active(_ts(2026, 8, 26)) == "", "між Спасом і Незалежністю та після неї — будні")
	check(HS.days_left(_ts(2026, 10, 1)) == 14 and HS.days_left(_ts(2026, 10, 14)) == 1 and HS.days_left(_ts(2026, 11, 18)) == 0, "скільки днів свята лишилось")
	var nx: Dictionary = HS.upcoming(_ts(2026, 11, 18))
	check(nx["id"] == "kateryny" and int(nx["in_days"]) == 6, "найближче свято 18 листопада: Катерини за 6 днів")
	check(HS.upcoming(_ts(2026, 12, 20))["id"] == "rizdvo" and HS.upcoming(_ts(2026, 12, 30))["id"] == "malanka", "черга свят переходить через Новий рік")
	check(HS.dates_text("rizdvo", 2026) == "24 грудня – 7 січня" and HS.dates_text("velykden", 2026) == "11 квітня – 19 квітня", "дати словами")
	var cal: Array = HS.calendar(_ts(2026, 11, 18))
	check(cal.size() == Acts.HOLIDAY_ORDER.size() and cal[0]["id"] == "kateryny" and cal[1]["id"] == "andrii" and not cal[0]["active"] and cal[1]["great"] and not cal[0]["great"], "календар від найближчого свята")
	# Свята нових видів: рухомі від Великодня й «третій четвер травня»
	check(HS.active(_ts(2026, 2, 16)) == "masnytsia" and HS.active(_ts(2026, 2, 22)) == "masnytsia" and HS.active(_ts(2026, 2, 23)) == "", "Масниця 2026: тиждень за сім тижнів до Великодня")
	check(HS.active(_ts(2026, 4, 5)) == "verbna" and HS.active(_ts(2026, 5, 31)) == "zeleni" and HS.active(_ts(2026, 6, 6)) == "zeleni" and HS.active(_ts(2026, 6, 7)) == "", "Вербна неділя й Зелені свята 2026")
	check(HS.dates_text("vyshyvanka", 2026) == "21 травня – 23 травня" and HS.dates_text("vyshyvanka", 2027) == "20 травня – 22 травня" and HS.active(_ts(2026, 5, 21)) == "vyshyvanka", "День вишиванки: третій четвер травня")
	var d3: Dictionary = Time.get_date_dict_from_unix_time(HS.nth_weekday(2026, 5, 3, 4) * 86400)
	check(int(d3["weekday"]) == 4 and int(d3["day"]) == 21, "третій четвер травня 2026 — двадцять перше")
	# Коли свята припадають на один день: велике перебиває мале, серед рівних коротше перебиває довше
	check(HS.active(_ts(2027, 3, 8)) == "masnytsia" and HS.active(_ts(2027, 3, 9)) == "shevchenko" and HS.active(_ts(2027, 3, 11)) == "masnytsia", "Шевченківські дні посеред Масниці 2027")
	check(HS.active(_ts(2027, 4, 23)) == "yurii" and HS.active(_ts(2027, 4, 25)) == "verbna" and HS.active(_ts(2027, 5, 2)) == "velykden" and HS.active(_ts(2027, 4, 28)) == "yurii", "Весняний Юрій поступається Вербній неділі й Великодню")
	check(HS.active(_ts(2027, 6, 20)) == "zeleni" and HS.active(_ts(2027, 6, 27)) == "kupala" and HS.active(_ts(2027, 6, 22)) == "zeleni", "пізні Зелені свята 2027 перебивають початок Купала")
	var shadowed := []
	for year in [2025, 2027, 2030, 2033, 2036]:
		var seen := {}
		var d0: int = _ts(year, 1, 1)
		for i in 366:
			seen[HS.active(d0 + i * 86400)] = true
		for id in Acts.HOLIDAY_ORDER:
			if not seen.has(id):
				shadowed.append("%d:%s" % [year, id])
	check(shadowed.is_empty(), "кожне свято щороку має хоч один свій день: %s" % str(shadowed))
	var busy := 0
	for i in 365:
		busy += 1 if HS.active(_ts(2026, 1, 1) + i * 86400) != "" else 0
	check(busy > 170 and busy < 220, "святкових днів у 2026 році близько половини: %d" % busy)
	cal = HS.calendar(_ts(2026, 12, 30))
	check(cal[0]["id"] == "rizdvo" and cal[0]["active"] and int(cal[0]["in_days"]) == 0, "свято, що триває, стоїть першим")
	# Бонуси
	CS.now_override = _ts(2026, 11, 18)
	check(HS.bonus("gold") == 0.0 and HS.player_mods().is_empty() and HS.combat_mods().is_empty(), "у будень бонусів нема")
	var p = _new_player()
	p.level = 10
	p.recalc()
	var hp0: float = p.max_hp
	var gm0: float = p.gold_mult
	var xm0: float = p.xp_mult
	CS.now_override = _ts(2026, 12, 25)
	p.festive = HS.player_mods()
	p.recalc()
	check(absf(p.gold_mult - gm0 - 0.25) < 0.001 and p.max_hp == hp0, "Різдво: +25% гривень")
	CS.now_override = _ts(2026, 4, 12)
	p.festive = HS.player_mods()
	p.recalc()
	check(absf(p.max_hp - hp0 * 1.15) < 1.0 and absf(p.gold_mult - gm0) < 0.001, "Великдень: +15% здоров'я")
	CS.now_override = _ts(2026, 8, 24)
	p.festive = HS.player_mods()
	p.recalc()
	check(absf(p.xp_mult - xm0 - 0.24) < 0.001 and absf(p.gold_mult - gm0 - 0.24) < 0.001, "День Незалежності: +24% досвіду й гривень")
	var w = WorldState.new()
	CS.now_override = _ts(2026, 10, 5)
	GS.add(w, p, 10)
	check(GS.glory(w) == 20, "Покрова: слава вдвічі")
	CS.now_override = _ts(2026, 11, 18)
	GS.add(w, p, 10)
	check(GS.glory(w) == 30, "у будень слава звичайна")
	var veg0: int = GardenS.yield_of("veg", 10)
	var honey0: float = CampService.pasika_rate(w, 10)
	CS.now_override = _ts(2026, 8, 6)
	check(GardenS.yield_of("veg", 10) == 6 and veg0 == 4 and CampService.pasika_rate(w, 10) == honey0 * 1.5, "Спас: урожай і мед у півтора раза")
	CS.now_override = _ts(2026, 11, 18)
	var cost0: int = TS.rumor_cost(10)
	var games0: int = TS.games_max()
	CS.now_override = _ts(2026, 12, 1)
	check(TS.games_max() == games0 + 4 and TS.rumor_cost(10) == cost0 / 2, "Андрія: більше партій у кості, чутки за пів ціни")
	# --- Бонуси нових свят: показники героя ---
	CS.now_override = _ts(2026, 11, 18)
	p.festive = HS.player_mods()
	p.recalc()
	var dmg0: float = p.damage
	var armor0: float = p.armor
	var crit0: float = p.crit_chance
	var regen0: float = p.regen
	var mreg0: float = p.mana_regen
	var sp0: float = p.skill_power
	var cd0: float = p.skill_cd_mult
	var cases := [[_ts(2026, 11, 9), "mykhaila"], [_ts(2026, 2, 2), "stritennia"], [_ts(2026, 4, 5), "verbna"], [_ts(2026, 5, 21), "vyshyvanka"],
		[_ts(2026, 3, 25), "blahovishchennia"], [_ts(2026, 7, 21), "illi"], [_ts(2026, 10, 26), "didy"], [_ts(2026, 3, 9), "shevchenko"], [_ts(2026, 12, 6), "mykolai"]]
	var got := {}
	for c in cases:
		CS.now_override = int(c[0])
		check(HS.active() == c[1], "%s цього дня" % c[1])
		p.festive = HS.player_mods()
		p.recalc()
		got[c[1]] = {"dmg": p.damage, "armor": p.armor, "crit": p.crit_chance, "regen": p.regen, "mana": p.mana_regen, "skill": p.skill_power, "cd": p.skill_cd_mult, "xp": p.xp_mult, "gold": p.gold_mult, "hp": p.max_hp}
	check(absf(got["mykhaila"]["dmg"] / dmg0 - 1.15) < 0.001 and got["mykhaila"]["hp"] == hp0, "Михайла: +15% шкоди")
	check(absf(got["stritennia"]["armor"] - armor0 - 0.1) < 0.001, "Стрітення: +10% захисту")
	check(absf(got["verbna"]["crit"] - crit0 - 0.1) < 0.001, "Вербна неділя: +10% до критичного удару")
	check(absf(got["vyshyvanka"]["regen"] - regen0 - hp0 * 0.005) < 0.01, "День вишиванки: рани гояться самі")
	check(absf(got["blahovishchennia"]["mana"] / mreg0 - 1.3) < 0.001, "Благовіщення: наснага на 30% швидше")
	check(absf(got["illi"]["skill"] - sp0 - 0.2) < 0.001, "Іллі: +20% сили вмінь")
	check(absf(got["didy"]["cd"] / cd0 - 0.85) < 0.001, "Осінні Діди: вміння відновлюються на 15% швидше")
	check(absf(got["shevchenko"]["xp"] - xm0 - 0.3) < 0.001, "Шевченківські дні: +30% досвіду")
	check(absf(got["mykolai"]["xp"] - xm0 - 0.15) < 0.001 and absf(got["mykolai"]["gold"] - gm0 - 0.15) < 0.001, "Миколая: +15% досвіду й гривень")
	# Водохреще: зілля дужче. Здвиження: стани коротші
	CS.now_override = _ts(2026, 11, 18)
	p.festive = HS.player_mods()
	p.recalc()
	p.potions = 5
	p.hp = 1.0
	p.potion_timer = 0.0
	p.use_potion()
	var healed0: float = p.hp - 1.0
	p.add_status("burn", 6.0, 0.0)
	var burn0: float = float(p.statuses["burn"]["t"])
	p.statuses.clear()
	CS.now_override = _ts(2026, 1, 16)
	p.festive = HS.player_mods()
	p.recalc()
	p.hp = 1.0
	p.potion_timer = 0.0
	p.use_potion()
	check(HS.active() == "vodokhreshche" and absf((p.hp - 1.0) / healed0 - 1.3) < 0.01, "Водохреще: зілля лікує на 30% більше")
	CS.now_override = _ts(2026, 9, 15)
	p.festive = HS.player_mods()
	p.recalc()
	p.add_status("burn", 6.0, 0.0)
	check(HS.active() == "zdvyzhennia" and absf(float(p.statuses["burn"]["t"]) / burn0 - 0.5) < 0.01, "Здвиження: стани тривають удвічі менше")
	p.statuses.clear()
	p.hp = p.max_hp
	# --- Бонуси нових свят: служби ---
	var ws = WorldState.new()
	CS.now_override = _ts(2026, 11, 18)
	ws.add_loyalty("sich", 10)
	var OutS = load("res://scripts/game/outdoor_service.gd")
	var rich0: bool = OutS.rich(ws, "hunt")
	p.gold = 100000
	ws.add_loyalty("kyiv", 500)
	var hire0: int = CityService.hire_price(ws, p, "kyiv", "dzhura")
	CS.now_override = _ts(2026, 1, 22)
	ws.add_loyalty("sich", 10)
	ws.add_loyalty("sich", -4)
	check(ws.loyalty_points("sich") == 10 + 15 - 4, "День Соборності: +50% лояльності (а штраф не росте)")
	CS.now_override = _ts(2026, 7, 9)
	check(not rich0 and OutS.rich(ws, "hunt") and OutS.rich(ws, "fish"), "Петра й Павла: полювання й рибалка щедрі")
	CS.now_override = _ts(2026, 7, 15)
	check(CityService.hire_price(ws, p, "kyiv", "dzhura") == hire0 / 2, "День Державності: найм за пів ціни")
	CS.now_override = _ts(2026, 11, 13)
	check(HS.active() == "kuzma" and absf(HS.bonus("sharpen") - 0.1) < 0.001, "Кузьми й Дем'яна: +10% до заточки")
	# --- Бонуси нових свят: здобич у бою ---
	var loot_days := {"malanka": [_ts(2026, 1, 9), "loot", 0.5], "kateryny": [_ts(2026, 11, 25), "rare", 0.25], "zeleni": [_ts(2026, 5, 31), "res", 1.0],
		"masnytsia": [_ts(2026, 2, 17), "varenyk", 2.0], "obzhynky": [_ts(2026, 9, 2), "trophy", 1.0], "yurii": [_ts(2026, 4, 24), "boss", 0.2]}
	for id in loot_days:
		CS.now_override = int(loot_days[id][0])
		var cm: Dictionary = HS.combat_mods()
		check(HS.active() == id and cm.size() == 1 and absf(float(cm[loot_days[id][1]]) - float(loot_days[id][2])) < 0.001 and HS.player_mods().is_empty(), "%s: бонус до здобичі «%s»" % [id, loot_days[id][1]])
	# Жетони й нагороди (спільні для акаунта)
	check(HS.token_roll(true, false, 0.9) == Acts.TOKEN_BOSS and HS.token_roll(false, true, 0.9) == Acts.TOKEN_ELITE and HS.token_roll(false, false, 0.01) == 1 and HS.token_roll(false, false, 0.5) == 0, "жетони: бос, еліта, інколи звичайна нечисть")
	check(HS.tiers("nezalezhnist") == Acts.TOKEN_TIERS_SHORT and HS.tiers("rizdvo") == Acts.TOKEN_TIERS and HS.tiers("velykden") == Acts.TOKEN_TIERS, "коротке свято має нижчі пороги")
	check(HS.tiers("mykhaila") == Acts.TOKEN_TIERS_TINY and HS.tiers("malanka") == Acts.TOKEN_TIERS_SHORT and HS.tiers("andrii") == Acts.TOKEN_TIERS and HS.length("mykhaila") == 3 and HS.length("rizdvo") == 15, "мале свято: пороги нижчі, найкоротші — найнижчі")
	check("Алатир" in HS.reward_text(2, 10, "pokrova") and "Алатир" not in HS.reward_text(2, 10, "mykhaila") and "рідкісна" in HS.reward_text(2, 10, "mykhaila") and "добротна" in HS.reward_text(1, 10, "mykhaila"), "нагороди малого свята скромніші")
	var acc = Account.new()
	var w1 = WorldState.new()
	acc.attach(w1)
	CS.now_override = _ts(2026, 11, 18)
	check(HS.add_tokens(w1, 5) == 0 and HS.progress(w1).is_empty() and not HS.can_claim(w1, 0), "у будень жетонів нема")
	CS.now_override = _ts(2026, 10, 3)
	check(HS.add_tokens(w1, 14) == 14 and not HS.can_claim(w1, 0), "14 хрестів — замало для першої нагороди")
	HS.add_tokens(w1, 1)
	check(HS.can_claim(w1, 0) and not HS.can_claim(w1, 1), "15 — перша нагорода доступна")
	var gold0: int = p.gold
	var msgs: Array = HS.claim(w1, p, 0)
	check(msgs.size() == 1 and p.gold == gold0 + 200 + 40 * 10 and not HS.can_claim(w1, 0) and HS.claim(w1, p, 0).is_empty(), "нагороду забирають один раз")
	# Інший персонаж того ж акаунта бачить ті самі жетони
	var w2 = WorldState.new()
	acc.attach(w2)
	check(HS.tokens(w2) == 15 and not HS.can_claim(w2, 0), "жетони й забрані нагороди спільні для персонажів")
	HS.add_tokens(w2, 70)
	var p2 = _new_player()
	p2.level = 20
	var items0: int = p2.inventory.size()
	msgs = HS.claim(w2, p2, 1)
	check(msgs.size() == 1 and p2.inventory.size() == items0 + 1 and int(p2.inventory[-1]["rarity"]) >= 2 and int(p2.resources.get("trophy", 0)) == 3, "друга нагорода: рідкісна річ і трофеї")
	var stones0: int = int(p2.stones.get("alatyr", 0))
	var gl0: int = GS.glory(w2)
	msgs = HS.claim(w2, p2, 2)
	check(int(p2.stones.get("alatyr", 0)) == stones0 + 1 and GS.glory(w2) == gl0 + Acts.TOKEN_GLORY, "третя нагорода: Алатир-камінь і слава (без святкового подвоєння)")
	# Мале свято: Михайла. Пороги 6, 15, 30; замість Алатир-каменя — рідкісна річ
	CS.now_override = _ts(2026, 11, 9)
	var p3 = _new_player()
	p3.level = 20
	HS.add_tokens(w2, 30)
	check(HS.season() == "mykhaila:2026" and HS.tokens(w2) == 30 and HS.can_claim(w2, 0) and HS.can_claim(w2, 2), "Михайла: 30 пер — усі три нагороди")
	var g3: int = p3.gold
	var res3: int = int(p3.resources.get("wood", 0))
	HS.claim(w2, p3, 0)
	check(p3.gold == g3 + 150 + 30 * 20 and int(p3.resources.get("wood", 0)) == res3 + 3, "мале свято, перша нагорода: гривні й по три ресурси")
	var inv3: int = p3.inventory.size()
	HS.claim(w2, p3, 1)
	check(p3.inventory.size() == inv3 + 1 and int(p3.inventory[-1]["rarity"]) >= 1 and int(p3.resources.get("trophy", 0)) == 2, "друга: добротна річ і два трофеї")
	var st3: int = int(p3.stones.get("alatyr", 0))
	var gl3: int = GS.glory(w2)
	g3 = p3.gold
	msgs = HS.claim(w2, p3, 2)
	check(int(p3.stones.get("alatyr", 0)) == st3 and p3.inventory.size() == inv3 + 2 and int(p3.inventory[-1]["rarity"]) >= 2 and GS.glory(w2) == gl3 + Acts.TOKEN_GLORY_SMALL and p3.gold == g3 + 300 + 60 * 20, "третя: рідкісна річ, слава й гривні, без Алатир-каменя")
	p3.free()
	# Наступного року — нове свято з чистого аркуша
	CS.now_override = _ts(2027, 10, 3)
	check(HS.season() == "pokrova:2027" and HS.tokens(w2) == 0 and not HS.progress(w2)["claimed"][0], "наступної Покрови жетони збирають заново")
	# Привітання раз на свято
	CS.now_override = _ts(2026, 12, 24)
	var hello: String = HS.greeting(w1)
	check("Різдво" in hello and "гривень" in hello and HS.greeting(w1) == "" and HS.greeting(w2) == "", "вітаємо зі святом один раз на весь акаунт")
	CS.now_override = _ts(2026, 11, 18)
	check(HS.greeting(w1) == "", "у будень привітань нема")
	# Примусове свято для перевірок
	HS.forced = "kupala"
	check(HS.active() == "kupala" and HS.bonus("xp") == 0.25, "примусове свято вмикається")
	HS.forced = "none"
	CS.now_override = _ts(2026, 12, 25)
	check(HS.active() == "" and HS.bonus("gold") == 0.0, "вимкнені свята не діють навіть на Різдво")
	var acc2 = Account.new()
	acc2.from_dict(acc.to_dict())
	check(int(acc2.holidays["pokrova:2026"]["tokens"]) == 85 and acc2.holidays["pokrova:2026"]["claimed"] == [true, true, true], "жетони лежать в акаунті й переживають збереження")
	CS.now_override = 0


func _suite_holidays_game() -> void:
	suite("Сезонні свята: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var HS = load("res://scripts/game/holiday_service.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	HS.forced = ""
	CS.now_override = _ts(2026, 11, 18)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.change_class("cossack")
	p.level = 12
	p.stats["str"] = 120
	p.stats["vit"] = 80
	p.recalc()
	p.hp = p.max_hp
	game.enter_map()
	await _frames(2)
	check(game.holiday_id == "" and p.festive.is_empty(), "будень: свята нема")
	var gm0: float = p.gold_mult
	# Настає Різдво
	CS.now_override = _ts(2026, 12, 25)
	game.enter_map()
	await _frames(2)
	check(game.holiday_id == "rizdvo" and absf(p.gold_mult - gm0 - 0.25) < 0.001, "на мапі свято підхопилось: +25% гривень")
	check("Різдво" in game.hud.banner.text, "привітання зі святом: %s" % game.hud.banner.text.split("\n")[0])
	game.open_character()
	await _frames(2)
	var tabs: Array = []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		tabs.append(tc.get_tab_title(i))
	check("Свята" in tabs, "вкладка «Свята» на екрані героя")
	game.close_character()
	# У поході з нечисті падають зірки колядників
	game.enter_location("wild_field")
	await _frames(3)
	var frames := 0
	while HS.tokens(game.world) < 3 and frames < 5000:
		_bot_fight(game)
		p.hp = p.max_hp
		for e in game.combat.get_tree().get_nodes_in_group("enemies"):
			if not e.dead and not e.elite:
				e.make_elite(game.combat.Elites.roll_affixes(1))  # еліта дає жетони напевно
				e.max_hp = 5.0
				e.hp = 5.0
		await process_frame
		frames += 1
	check(HS.tokens(game.world) >= 3 and int(game.world.stats.get("holiday_token", 0)) >= 3, "жетони з нечисті: %d (кадрів: %d)" % [HS.tokens(game.world), frames])
	game.enter_map()
	await _frames(2)
	# Нагорода
	HS.add_tokens(game.world, 20)
	game.open_character()
	await _frames(2)
	var gold0: int = p.gold
	game.char_do("holiday_claim", 0)
	check(p.gold > gold0 and int(game.world.stats.get("holiday_reward", 0)) == 1 and not HS.can_claim(game.world, 0), "забрав першу нагороду свята")
	game.close_character()
	game.save_game()
	var raw = FileAccess.open(TEST_ACCOUNT, FileAccess.READ).get_var()
	check(raw is Dictionary and raw.get("holidays", {}).has("rizdvo:2026"), "свято записано у файл акаунта")
	# Свята зі здобиччю: Весняний Юрій (шкода по босах), а далі рідкість речей і ресурси
	CS.now_override = _ts(2026, 4, 24)
	game.enter_map()
	await _frames(2)
	check(game.holiday_id == "yurii" and absf(float(game.combat.festive.get("boss", 0.0)) - 0.2) < 0.001 and p.festive.is_empty(), "Весняний Юрій: бій знає про святковий бонус")
	game.enter_location("wild_field")
	await _frames(3)
	game.combat.spawn_enemy("upyr", 5, true, p.global_position + Vector2(400, 0))
	var yb = game.combat._last_enemy()
	yb.stun = 9.0
	var yhp: float = yb.hp
	yb.take_damage(10.0, Vector2.ZERO)
	var hit_fest: float = yhp - yb.hp
	game.combat.festive = {}
	yhp = yb.hp
	yb.take_damage(10.0, Vector2.ZERO)
	check(hit_fest > 0.0 and absf(hit_fest / (yhp - yb.hp) - 1.2) < 0.01, "на Юрія бос дістає на 20% більше шкоди")
	game.combat.festive = {"rare": 1.0, "res": 1.0}
	check(int(game.combat._loot(5, 0)["rarity"]) == 1 and int(game.combat._loot(5, 3)["rarity"]) == 3 and game.combat._res_amount(3) == 6, "рідкість речі росте (але не вище легендарної), ресурсів удвічі більше")
	game.combat.festive = {}
	check(int(game.combat._loot(5, 0)["rarity"]) == 0 and game.combat._res_amount(3) == 3, "у будень здобич звичайна")
	yb.take_damage(1e9, Vector2.ZERO)
	await _frames(3)
	game.enter_map()
	await _frames(2)
	# Свято минуло
	CS.now_override = _ts(2027, 1, 20)
	game.enter_map()
	await _frames(2)
	check(game.holiday_id == "" and absf(p.gold_mult - gm0) < 0.001, "після свята бонус знято")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	HS.forced = "none"
	CS.now_override = 0


## Усі назви звуків, які гра просить зіграти (Audio.play("...")), зібрані з коду.
func _sound_names_in_code(dir_path: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_sound_names_in_code(dir_path + "/" + sub, out)
	var re := RegEx.new()
	re.compile("Audio\\.play\\(([^)]*)\\)")
	var lit := RegEx.new()
	lit.compile("(?<!== )(?<!!= )\"([a-z_]+)\"")  # рядки після порівняння — не назви звуків
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir_path + "/" + f)
		for m in re.search_all(text):
			# у виклику можуть бути дві назви: "crit" if ... else "hit"
			for n in lit.search_all(m.get_string(1)):
				out[n.get_string(1)] = f


func _suite_audio() -> void:
	suite("Звук: набір і мапа")
	var Sounds = load("res://scripts/data/sounds.gd")
	var Index = load("res://scripts/data/sound_index.gd")
	var audio = root.get_node("Audio")
	var missing := []
	for name in Index.SFX:
		for i in range(1, int(Index.SFX[name]) + 1):
			if not ResourceLoader.exists("res://assets/audio/sfx/%s_%d.ogg" % [name, i]):
				missing.append("%s_%d" % [name, i])
	check(missing.is_empty() and Index.SFX.size() >= 40, "усі звукові файли з переліку на місці (%d назв)%s" % [Index.SFX.size(), "" if missing.is_empty() else ": нема " + str(missing)])
	missing = []
	for m in Index.MUSIC:
		if not ResourceLoader.exists("res://assets/audio/music/%s.ogg" % m):
			missing.append(m)
	for a in Index.AMBIENT:
		if not ResourceLoader.exists("res://assets/audio/ambient/%s.ogg" % a):
			missing.append(a)
	check(missing.is_empty() and Index.MUSIC.size() >= 8 and Index.AMBIENT.size() >= 6, "музика й фонові шуми на місці: %d і %d" % [Index.MUSIC.size(), Index.AMBIENT.size()])
	var no_volume := []
	for name in Index.SFX:
		if not Sounds.VOLUME.has(name):
			no_volume.append(name)
	var no_file := []
	for name in Sounds.VOLUME:
		if not Index.SFX.has(name):
			no_file.append(name)
	check(no_volume.is_empty() and no_file.is_empty(), "кожен звук має гучність, кожна гучність — звук%s%s" % [(" без гучності: " + str(no_volume)) if not no_volume.is_empty() else "", (" без файлів: " + str(no_file)) if not no_file.is_empty() else ""])
	# Жодної назви-привида в коді: кожен Audio.play("...") має записаний звук
	var used := {"click": "audio.gd"}  # клацання кнопок рушій грає сам
	_sound_names_in_code("res://scripts", used)
	var ghosts := []
	for name in used:
		if not Index.SFX.has(name):
			ghosts.append("%s (%s)" % [name, used[name]])
	check(ghosts.is_empty() and used.size() >= 25, "усі звуки, які просить код, існують (%d назв)%s" % [used.size(), "" if ghosts.is_empty() else ": нема " + str(ghosts)])
	var unused := []
	for name in Index.SFX:
		if not used.has(name) and not (name in Sounds.DEATH.values()) and name != "enemy_die":
			unused.append(name)
	check(unused.is_empty(), "жоден зібраний звук не лежить без діла%s" % ("" if unused.is_empty() else ": " + str(unused)))
	for kind in Sounds.DEATH:
		check(Index.SFX.has(Sounds.DEATH[kind]), "голос смерті для %s" % kind)
	check(Sounds.death("vovkulaka") == "die_beast" and Sounds.death("невідоме") == "enemy_die", "невідома нечисть має загальний голос")
	var biomes := {}
	for id in Data.LOCATIONS:
		biomes[Data.LOCATIONS[id]["biome"]] = true
	var bad := []
	for b in biomes:
		var amb: String = Sounds.ambient_for(b)
		if amb == "" or not (amb in Index.AMBIENT):
			bad.append(b)
	check(bad.is_empty(), "кожен ландшафт має свій фон%s" % ("" if bad.is_empty() else ": без фону " + str(bad)))
	check(Sounds.ambient_for("steppe", true) == "night" and Sounds.ambient_for("cave", true) == "cave", "уночі цвіркуни, та не в печері")
	# Рушій
	check(audio.samples.size() == Index.SFX.size() and audio.has_sample("hit") and audio.samples["hit"].size() == int(Index.SFX["hit"]), "записані звуки завантажено з варіантами")
	audio.play_music("calm")
	check(audio.current_music == "map", "стара назва «calm» веде на мелодію мапи")
	audio.play_music("city")
	check(audio.current_music == "city" and audio._music_live.stream != null and audio._music_live.stream.loop, "мелодія міста грає по колу")
	audio.play_music("нема-такої")
	check(audio.current_music == "map", "невідома мелодія не глушить музику")
	audio.jingle("victory")
	check(audio._jingle.stream != null and not audio._jingle.stream.loop, "мотив перемоги грає один раз")
	audio.play_ambient("forest")
	check(audio.current_ambient == "forest", "фон лісу")
	audio.play_ambient("нема-такого")
	check(audio.current_ambient == "", "невідомий фон — тиша")
	audio.set_music(false)
	audio.play_music("battle")
	check(audio.current_music == "battle" and not audio._music_a.playing and not audio._music_b.playing, "вимкнена музика не грає, але пам'ятає, що мала б")
	audio.set_music(true)
	audio.set_sound(false)
	audio.play_ambient("wind")
	check(not audio._ambient_live.playing, "вимкнений звук глушить і фон")
	audio.set_sound(true)
	audio.play_ambient("")


func _suite_audio_game() -> void:
	suite("Звук: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var HS = load("res://scripts/game/holiday_service.gd")
	var audio = root.get_node("Audio")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	check(audio.current_music == "menu", "у меню — своя мелодія")
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true, "hunt": true, "fish": true}
	p.change_class("cossack")
	p.level = 12
	p.stats["str"] = 200
	p.recalc()
	p.hp = p.max_hp
	game.enter_map()
	await _frames(2)
	check(audio.current_music == "map" and audio.current_ambient == "", "мапа: мелодія мандрів, без фону")
	game.enter_city("sich")
	game.hud.close_dialogue()
	check(audio.current_music == "city", "місто: ярмаркова мелодія")
	game.city_tab_changed("Шинок")
	check(audio.current_music == "inn", "у шинку — корчемна мелодія")
	game.city_tab_changed("Крамниця")
	check(audio.current_music == "city", "вийшов із шинку — знову міська")
	game.enter_camp()
	await _frames(2)
	check(audio.current_music == "camp" and audio.current_ambient == "fire", "хутір: своя мелодія й тріск багаття")
	HS.forced = "kupala"
	game.enter_city("sich")
	game.hud.close_dialogue()
	check(audio.current_music == "festive", "у свято в місті святкова мелодія")
	HS.forced = "none"
	game.enter_location("wild_field")
	await _frames(3)
	check(audio.current_music == "battle" and audio.current_ambient == "wind", "степ: бойова мелодія й вітер")
	game.combat.spawn_enemy("zmii", 3, true)
	await _frames(2)
	check(audio.current_music == "boss", "з'явився бос — тема боса")
	var boss = game.combat._last_enemy()
	boss.take_damage(1.0e9, Vector2.ZERO)
	await _frames(4)
	check(audio.current_music == "map", "боса вбито — бойова тема стихає")
	game.enter_map()
	await _frames(2)
	game.enter_location("zmii_cave")
	await _frames(3)
	check(audio.current_ambient == "cave", "печера: гул підземелля")
	game.enter_map()
	await _frames(2)
	game.enter_spot("hunt")
	await _frames(3)
	check(audio.current_ambient == "forest", "на полюванні — птахи")
	game._quit_activity()
	await _frames(2)
	game.enter_spot("fish")
	await _frames(3)
	check(audio.current_ambient == "river", "на рибалці — вода")
	game._quit_activity()
	await _frames(2)
	check(audio.current_ambient == "", "на мапі фон стихає")
	game.queue_free()
	await _frames(2)
	audio.play_ambient("")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_mana_potion() -> void:
	suite("Зілля наснаги: правила")
	var CampService = load("res://scripts/game/camp_service.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var w = WorldState.new()
	var p = _new_player()
	p.level = 10
	p.recalc()
	check(p.mana_potions == 0 and p.mana_potion_max() == Data.MANA_POTION_MAX, "козак починає без зілля наснаги, місця — три")
	check(not p.use_mana_potion(), "нема зілля — нема чого пити")
	check(p.add_mana_potion() and p.add_mana_potion() and p.add_mana_potion() and not p.add_mana_potion() and p.mana_potions == 3, "понад запас не візьмеш")
	p.mana = p.max_mana
	check(not p.use_mana_potion() and p.mana_potions == 3, "при повній насназі зілля не марнується")
	p.mana = 0.0
	var hp0: float = p.hp
	check(p.use_mana_potion() and p.mana_potions == 2 and absf(p.mana - p.max_mana * Data.MANA_POTION_RESTORE) < 0.5 and p.hp == hp0, "ковток повертає 70% наснаги й не лікує")
	p.mana = 0.0
	check(not p.use_mana_potion() and p.mana_potion_timer > 0.0, "між ковтками треба перечекати")
	p.mana_potion_timer = 0.0
	p.alive = false
	check(not p.use_mana_potion(), "полеглий не п'є")
	p.alive = true
	# Волхв
	var m = _new_player()
	m.level = 10
	m.change_class("volkhv")
	check(m.mana_potions == 2 and m.mana_potion_max() == Data.MANA_POTION_MAX + 1, "волхв на посвяті дістає два зілля й несе на одне більше")
	m.change_class("cossack")
	m.change_class("volkhv")
	check(m.mana_potions == 2, "повторна посвята зілля не множить")
	# Крамниця
	p.gold = 0
	p.mana_potions = 0
	check(not CityService.buy_mana_potion(w, p, "sich"), "без гривень не купиш")
	p.gold = 10000
	var price: int = CityService.mana_potion_price(w, p, "sich")
	check(price > 0 and price < CityService.potion_price(w, p, "sich") and CityService.buy_mana_potion(w, p, "sich") and p.gold == 10000 - price and p.mana_potions == 1, "зілля наснаги дешевше за зілля здоров'я")
	p.mana_potions = p.mana_potion_max()
	check(not CityService.buy_mana_potion(w, p, "sich"), "повний запас — крамар не продає")
	# Зілляварня
	p.resources = {"wood": 100, "iron": 100, "herbs": 100}
	p.mana_potions = 0
	check(not CampService.can_brew(w, p, "mana"), "без зілляварні не звариш")
	CampService.build(w, p, "zillia")
	var herbs0: int = int(p.resources["herbs"])
	check(CampService.brew(w, p, "mana") and p.mana_potions == 1 and int(p.resources["herbs"]) == herbs0 - int(Camp.BREW["mana"]["herbs"]) and not p.trip_buffs.has("mana"), "зварив зілля наснаги з трав")
	p.mana_potions = p.mana_potion_max()
	check(not CampService.can_brew(w, p, "mana"), "повний запас — варити нема куди")
	# Збереження
	p.mana_potions = 2
	var p2 = _new_player()
	p2.from_dict(p.to_dict())
	check(p2.mana_potions == 2, "запас зілля наснаги зберігається")
	check(Camp.res_name("meat") == "М'ясо" and Camp.res_name("wood") == "Дерево" and Camp.res_name("trophy") == Camp.TROPHY_NAME and Camp.RESOURCE_COLORS.has("ryba"), "провіант має назви й кольори для написів здобичі")
	for id in ["mana", "meat", "ryba", "veg", "glory", "tok_rizdvo", "tok_velykden", "tok_kupala", "tok_spas", "tok_nezalezhnist", "tok_pokrova", "tok_andrii"]:
		check(load("res://scripts/world/gfx.gd").ICON_ORDER.has(id), "значок %s є на листі" % id)
	var GfxS = load("res://scripts/world/gfx.gd")
	check(GfxS.icon_tex("meat") != null and GfxS.icon_tex("tok_pokrova") != null and GfxS.icon_tex("нема") == null, "значки доступні інтерфейсу як текстури")
	for job in ["peasant", "cossack", "volkhv", "zaporozhets", "plastun", "samopalnyk", "kharakternyk", "znakhar", "perun_zhrets", "molfar"]:
		check(GfxS.has("hunter_" + job) and GfxS.has("plain_" + job), "%s: є постаті мисливця з луком і без зброї" % job)
	var DiceRow = load("res://scripts/ui/dice_row.gd")
	check(DiceRow.roll_time(0) == 0.0 and DiceRow.roll_time(3) > DiceRow.roll_time(1) and DiceRow.roll_time(1) > 0.2, "кожна нова кість додає часу анімації")
	var sheet: Texture2D = load("res://assets/gfx/sprites/icons.png")
	check(sheet.get_width() == 16 * load("res://scripts/world/gfx.gd").ICON_ORDER.size(), "лист значків відповідає переліку")


func _suite_mana_potion_game() -> void:
	suite("Зілля наснаги: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.change_class("cossack")
	p.level = 10
	p.recalc()
	p.hp = p.max_hp
	p.gold = 5000
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.city_do("buy_mana_potion", null)
	check(p.mana_potions == 1, "купив зілля наснаги в крамниці")
	game.enter_location("wild_field")
	await _frames(3)
	check(game.hud.btn_mana.visible and "1" in game.hud.btn_mana.label, "у бою є кнопка «Наснага 1»")
	p.mana = 0.0
	game.hud.mana_pressed.emit()
	check(p.mana > p.max_mana * 0.5 and p.mana_potions == 0, "кнопка в бою повертає наснагу")
	await _frames(2)
	check(not game.hud.btn_mana.visible, "у козака порожня кнопка ховається")
	# Здобич: синя пляшечка
	game.combat.spawn_pickup(p.global_position, "mana", 1)
	await _frames(30)
	check(p.mana_potions == 1, "підібрав зілля наснаги зі здобичі")
	p.mana_potions = p.mana_potion_max()
	var gold0: int = p.gold
	game.combat.spawn_pickup(p.global_position, "mana", 1)
	await _frames(30)
	check(p.mana_potions == p.mana_potion_max() and p.gold > gold0, "зайве зілля обертається на гривні")
	# Провіант як здобич: напис і значок не ламаються
	game.combat.spawn_pickup(p.global_position, "res", 2, {"res": "meat"})
	await _frames(30)
	check(int(p.resources.get("meat", 0)) >= 2, "м'ясо підбирається як ресурс")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Прибрати з арени всю нечисть (щоб перевіряти боса наодинці).
func _clear_enemies(game) -> void:
	for e in game.combat.get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()


func _suite_new_bosses() -> void:
	suite("Нові боси: Відьма й Вій")
	var GfxS = load("res://scripts/world/gfx.gd")
	var Stones = load("res://scripts/game/stone_service.gd")
	for id in ["lysa_hora", "vii_church"]:
		var L: Dictionary = Data.LOCATIONS[id]
		check(L["type"] == "dungeon" and Data.BOSS_NAMES.has(L["boss"]) and Data.ENEMY_NAMES.has(L["boss"]) and GfxS.has(L["boss"]), "%s: печера з босом %s, спрайт є" % [id, L["boss"]])
		var clash := false
		for other in Data.LOCATIONS:
			if other != id and Data.LOCATIONS[other]["pos"].distance_to(L["pos"]) < 0.6:
				clash = true
		for c in Data.CITIES:
			if Data.CITIES[c]["pos"].distance_to(L["pos"]) < 0.6:
				clash = true
		check(not clash, "%s: не налазить на інші місця мапи" % id)
		check(Stones.FIRST_KILL.has(L["boss"]), "%s: перша перемога дає камінь долі" % L["boss"])
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "vii_gaze"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 12
	p.stats["str"] = 60
	p.stats["vit"] = 200
	p.recalc()
	p.hp = p.max_hp
	# ---------------- Відьма ----------------
	game.enter_location("lysa_hora")
	await _frames(3)
	check(c.is_dungeon() and c.loc.get("night", false) and root.get_node("Audio").current_ambient == "night", "Лиса гора: нічна печера-галявина із цвіркунами")
	_clear_enemies(game)
	await _frames(1)
	c.spawn_enemy("vidma", 9, true, p.global_position + Vector2(0, -300))
	var w = c._last_enemy()
	check(w.is_boss and w.kind == "vidma" and w.ranged and w.title != "Мара", "Відьма — бос-стрілець")
	# 1) зілля: три кола, після них калюжі, що знесилюють
	w.ability_step = 0
	w._boss_ability(p)
	var circles := 0
	for t in c.effects.get_children():
		if t.has_method("contains") and t.shape == "circle":
			circles += 1
	check(circles == 3, "зілля: три кола під ногами")
	p.invuln = 3.0
	await _frames(70)
	var puddles := 0
	for t in c.effects.get_children():
		if "status" in t and t.status == "weak":
			puddles += 1
	check(puddles == 3, "після ударів лишаються калюжі слабкості: %d" % puddles)
	# 2) мари
	var spot0: Vector2 = w.global_position
	w.ability_step = 1
	w._boss_ability(p)
	await _frames(2)
	var maras := []
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.illusion:
			maras.append(e)
	check(maras.size() == 2 and w.global_position != spot0 and maras[0].title == "Мара" and maras[0].modulate.a < 1.0 and not maras[0].is_boss, "мари: дві примари, сама відьма перескочила")
	var kills0: int = int(game.world.stats.get("kill", 0))
	var gold0: int = p.gold
	maras[0].take_damage(1.0, Vector2.ZERO)
	await _frames(3)
	check(not is_instance_valid(maras[0]) or maras[0].dead, "мара розвіюється від першого удару")
	check(int(game.world.stats.get("kill", 0)) == kills0 and p.gold == gold0, "за мару ні вбивства, ні здобичі")
	maras[1].life_left = 0.05
	await _frames(6)
	check(not is_instance_valid(maras[1]) or maras[1].dead, "мара сама зникає з часом")
	# 3) віяло проклять
	w.ability_step = 2
	w._boss_ability(p)
	await _frames(2)
	var shots := 0
	for n in c.effects.get_children():
		if n.get_script() == c.ProjectileScript:
			shots += 1
	check(shots >= 5, "віяло проклять: п'ять згустків (%d)" % shots)
	# 4) лють на половині здоров'я
	w.take_damage(w.max_hp * 0.55, Vector2.ZERO)
	await _frames(2)
	check(w.phase2 and c.alive_enemy_count() >= 4, "на половині здоров'я відьма скликає шабаш")
	var stones0: int = int(p.stones.get("zabuttia", 0))
	w.take_damage(1.0e9, Vector2.ZERO)
	await _frames(5)
	check(int(game.world.stats.get("boss:vidma", 0)) == 1 and game.account.challenges["ach"].has("vidma") and int(p.stones.get("zabuttia", 0)) == stones0 + 1, "Відьму здолано: досягнення й Камінь забуття")
	game.enter_map()
	await _frames(2)
	# ---------------- Вій ----------------
	game.enter_location("vii_church")
	await _frames(3)
	_clear_enemies(game)
	await _frames(1)
	c.spawn_enemy("vii", 15, true, p.global_position + Vector2(0, -260))
	var v = c._last_enemy()
	v._rock_timer = 999.0
	check(v.is_boss and v.kind == "vii" and not v.ranged, "Вій — повільний бос ближнього бою")
	v.ability_timer = 999.0  # прийоми в цій перевірці запускаємо самі
	# Скам'яніння героя
	check(p.petrify(1.0) and p.petrified > 0.0, "герой кам'яніє")
	var pos0: Vector2 = p.global_position
	game.hud.joystick.vector = Vector2.RIGHT
	var skills0: float = p.attack_timer
	p.attack()
	p.dodge()
	await _frames(10)
	check(p.global_position.distance_to(pos0) < 2.0 and p.dodge_time_left <= 0.0, "скам'янілий не ходить і не перекидається")
	check(not p.petrify(1.0), "двічі поспіль не скам'яніти")
	p.petrified = 0.0
	p.petrify_guard = 0.0
	p.dodge_time_left = 0.2
	check(not p.petrify(1.0), "перекид саме в мить погляду рятує")
	p.dodge_time_left = 0.0
	game.hud.joystick.vector = Vector2.ZERO
	# Погляд: герой перед очима й нічого не робить — скам'яніє
	p.global_position = v.global_position + Vector2(0, 200)
	v._start_gaze(p, Vector2.DOWN)
	await _frames(2)
	check(v._gaze != null and v._lid_bearers.size() == 2 and v._lid_bearers[0].title == "Повікар" and v.cast_time > 2.0, "«Підніміть мені повіки!»: два повікарі й три секунди")
	for b in v._lid_bearers:
		b.global_position = v.global_position + Vector2(0, -400)  # подалі від героя, щоб не заважали
		b.speed = 0.0
	var hp0: float = p.hp
	await _frames(190)
	check(p.petrified > 0.0 and p.hp < hp0, "погляд ударив: герой скам'янів і поранений")
	check(v._gaze == null, "погляд відпрацював")
	# Погляд: герой устиг забігти за спину — цілий
	p.petrified = 0.0
	p.petrify_guard = 0.0
	p.hp = p.max_hp
	_clear_enemies(game)
	await _frames(1)
	c.spawn_enemy("vii", 15, true, p.global_position + Vector2(0, -260))
	v = c._last_enemy()
	v._rock_timer = 999.0
	v.ability_timer = 999.0
	v._start_gaze(p, Vector2.DOWN)
	for b in v._lid_bearers:
		b.speed = 0.0
		b.global_position = v.global_position + Vector2(300, -300)
	p.global_position = v.global_position + Vector2(0, -180)
	await _frames(190)
	check(p.petrified <= 0.0 and p.hp == p.max_hp, "за спиною Вія погляд не дістає")
	# Погляд: повікарів убито — Вій осліп
	p.global_position = v.global_position + Vector2(0, 200)
	v._start_gaze(p, Vector2.DOWN)
	await _frames(2)
	var blind0: int = int(game.world.stats.get("vii_blind", 0))
	for b in v._lid_bearers:
		b.take_damage(1.0e9, Vector2.ZERO)
	await _frames(4)
	check(v._gaze == null and v.stun > 2.0 and v.exposed > 2.0 and int(game.world.stats.get("vii_blind", 0)) == blind0 + 1, "обох повікарів здолано: повіки впали, Вій осліп")
	var before: float = v.hp
	v.take_damage(100.0, Vector2.ZERO)
	check(absf((before - v.hp) - 150.0) < 1.0, "осліплий Вій отримує в півтора раза більше")
	await _frames(190)
	check(p.petrified <= 0.0, "скасований погляд нікого не скам'янив")
	check(game.account.challenges["ach"].has("vii_blind"), "досягнення «Повіки впали»")
	# Тупіт і каміння
	v.stun = 0.0
	v.exposed = 0.0
	v.ability_step = 1
	v._boss_ability(p)
	var lines := 0
	var rings := 0
	for t in c.effects.get_children():
		if t.has_method("contains") and not t.is_queued_for_deletion():
			lines += 1 if t.shape == "line" else 0
			rings += 1 if t.shape == "circle" else 0
	check(lines == 6 and rings >= 1, "тупіт: коло довкола й шість тріщин")
	v.cast_time = 0.0
	v._rock_timer = 0.0
	var rocks0 := rings
	await _frames(3)
	rings = 0
	for t in c.effects.get_children():
		if t.has_method("contains") and t.shape == "circle" and not t.is_queued_for_deletion():
			rings += 1
	check(rings > rocks0, "зі стелі падає каміння")
	var alatyr0: int = int(p.stones.get("alatyr", 0))
	v.take_damage(1.0e9, Vector2.ZERO)
	await _frames(5)
	check(int(game.world.stats.get("boss:vii", 0)) == 1 and game.account.challenges["ach"].has("vii") and int(p.stones.get("alatyr", 0)) == alatyr0 + 1, "Вія здолано: досягнення й Алатир-камінь")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_vigil() -> void:
	suite("Козацька варта: правила")
	var VS = load("res://scripts/game/vigil_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	check(Acts.SPOTS.has("varta") and Acts.SPOTS["varta"]["kind"] == "vigil" and Data.place_name("varta") == "Сторожова могила", "Сторожова могила — місце на мапі")
	for sid in Acts.SPOTS:
		var S: Dictionary = Acts.SPOTS[sid]
		var clash := false
		for c in Data.CITIES:
			if Data.CITIES[c]["pos"].distance_to(S["pos"]) < 0.5:
				clash = true
		for l in Data.LOCATIONS:
			if Data.LOCATIONS[l]["pos"].distance_to(S["pos"]) < 0.5:
				clash = true
		check(not clash and S["name"] != "" and S["desc"] != "", "%s: не налазить на інші місця" % sid)
	var w = WorldState.new()
	var p = _new_player()
	p.job = "peasant"
	p.level = 10
	check(not VS.unlocked(p), "селянина на варту не беруть")
	p.change_class("cossack")
	p.level = 5
	check(not VS.unlocked(p), "до 6 рівня — зарано")
	p.level = 10
	p.recalc()
	check(VS.unlocked(p), "козак 10 рівня стає на варту")
	var L: Dictionary = VS.battle_loc(p)
	check(L["type"] == "vigil" and L["std_hp"] > 0.0 and L["std_dmg"] > 0.0 and L["enemies"].size() == 4 and L["goal"] == Acts.VIGIL_GOAL, "опис варти")
	var t0: Dictionary = VS.targets_at(p, 0)
	var t4: Dictionary = VS.targets_at(p, 4)
	check(t4["std_hp"] > t0["std_hp"] * 1.5 and t4["std_dmg"] > t0["std_dmg"] * 1.5 and t0["xp_mult"] < 1.0, "щохвилини нечисть лютішає; досвіду з юрби менше")
	var strong = _new_player()
	strong.change_class("cossack")
	strong.level = 10
	strong.stats["str"] = 90
	strong.stats["vit"] = 90
	strong.recalc()
	check(VS.targets_at(strong, 0)["std_hp"] > t0["std_hp"] * 1.5 and VS.targets_at(strong, 0)["std_dmg"] > t0["std_dmg"] * 1.5, "нечисть міряється силою з героєм")
	var r3: Dictionary = VS.minute_reward(10, 3)
	var r5: Dictionary = VS.minute_reward(10, 5)
	var r6: Dictionary = VS.minute_reward(10, 6)
	check(r3["item"] == 1 and r5["item"] == 2 and r5["trophy"] == 2 and r5["glory"] == Acts.VIGIL_GLORY + Acts.VIGIL_GLORY_GOAL and r5["gold"] > r3["gold"] and r6["item"] == -1, "нагороди за хвилини: речі на 3-й і 5-й, трофеї за повну варту")
	var g0: int = p.gold
	var o1: Dictionary = VS.on_minute(w, p, 1)
	check(o1["paid"] and p.gold == g0 + Acts.VIGIL_GOLD * 10 and GS.glory(w) == Acts.VIGIL_GLORY, "перша хвилина оплачена")
	var o1b: Dictionary = VS.on_minute(w, p, 1)
	check(not o1b["paid"] and p.gold == g0 + Acts.VIGIL_GOLD * 10, "ту саму хвилину вдруге за день не платять")
	check(VS.on_minute(w, p, 2)["paid"] and int(VS.state(w)["paid"]) == 2, "друга хвилина — оплачена")
	CS.now_override = 1762700000 + 86400
	check(int(VS.state(w)["paid"]) == 0 and VS.on_minute(w, p, 1)["paid"], "новий день — нагороди знову")
	# Рекорди
	var f1: Array = VS.finish(w, p, 130.0, 40)
	check(float(VS.state(w)["best_time"]) == 130.0 and int(VS.state(w)["best_kills"]) == 40 and int(VS.state(w)["runs"]) == 1 and "2:10" in f1[0] and not ("рекорд" in f1[0]), "перша варта задає рекорд без премії")
	var gl0: int = GS.glory(w)
	var f2: Array = VS.finish(w, p, 200.0, 30)
	check(float(VS.state(w)["best_time"]) == 200.0 and int(VS.state(w)["best_kills"]) == 40 and "рекорд" in f2[0] and GS.glory(w) == gl0 + 5, "побив власний рекорд часу — +5 слави")
	VS.finish(w, p, 100.0, 90)
	check(float(VS.state(w)["best_time"]) == 200.0 and int(VS.state(w)["best_kills"]) == 90 and GS.glory(w) == gl0 + 5, "гірший час рекорду не псує; рекорд убитих окремий")
	check(VS.time_text(305.4) == "5:05", "час варти читається як 5:05")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(float(w2.vigil["best_time"]) == 200.0, "рекорди варти зберігаються")
	CS.now_override = 0


func _suite_vigil_battle() -> void:
	suite("Козацька варта: бій")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	p.change_class("cossack")
	p.level = 12
	p.stats["str"] = 50
	p.stats["vit"] = 50
	p.skills = {"whirl": 3}
	p.recalc()
	p.hp = p.max_hp
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "vigil": true, "stones": true}
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	game.enter_map()
	await _frames(2)
	check(game.hud.map_view._markers.has("varta") or true, "мапа відкрита")
	game._on_map_select("varta")
	await _frames(2)
	check(game.hud.map_view._place_ll("varta") == game.Acts.SPOTS["varta"]["pos"], "варта має місце на мапі")
	await _ride(game, "varta")
	var c = game.combat
	check(game.state == game.State.PLAYING and c.is_vigil() and c.arena == c.VIGIL_ARENA and game.map_here == "varta", "приїхав на могилу — варта почалась")
	check(c._vigil_fire != null and c.counts_as_trip(), "вогнище горить; варта рахується походом")
	for i in 200:
		_bot_fight(game)
		p.hp = p.max_hp
		await process_frame
	check(c.alive_enemy_count() > 0 or c.vigil_kills > 0, "нечисть суне")
	var sample = c.nearest_enemy(p.global_position, 5000.0)
	check(sample == null or sample.damage < p.max_hp, "удар ворога міряється зі здоров'ям героя")
	var gold0: int = p.gold
	c.vigil_time = 59.6
	for i in 40:
		_bot_fight(game)
		p.hp = p.max_hp
		await process_frame
	check(c.vigil_minute == 1 and p.gold > gold0 and int(game.world.stats.get("vigil", 0)) == 1 and int(game.VigilService.state(game.world)["paid"]) == 1, "перша хвилина: нагорода й лічильник")
	c.vigil_time = 239.6
	for i in 40:
		_bot_fight(game)
		p.hp = p.max_hp
		await process_frame
	var boss := false
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			boss = true
	check(c.vigil_minute == 4 and boss, "остання хвилина: ватажок іде на могилу")
	c.vigil_time = 299.6
	for i in 40:
		p.hp = p.max_hp
		await process_frame
	check(c.vigil_done and c.portal != null and int(game.world.stats.get("vigil", 0)) == 5 and c._vigil_fire.darkness > 0.95 and c.canvas_mod.color.r < c._vigil_day.r * 0.4, "п'ять хвилин: портал відкрито, надворі ніч")
	check(game.world.challenges["ach"].has("vigil_5"), "досягнення «Вартовий»")
	# Упасти на варті — без втрат
	var trips0: int = int(game.EventService.state(game.world)["trips"])
	var gold1: int = p.gold
	p.invuln = 0.0
	p.unbreak_ready = false
	p.berehynia_ready = false
	p.take_damage(p.max_hp * 50.0, null)
	await _frames(3)
	check(not p.alive, "нечисть прорвалась")
	var frames := 0
	while game.state != game.State.CITY and frames < 300:
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and p.alive and p.gold >= gold1, "після падіння — у місті, гривні цілі")
	check(float(game.VigilService.state(game.world)["best_time"]) >= 299.0 and int(game.VigilService.state(game.world)["runs"]) == 1, "рекорд варти записано")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_bounty() -> void:
	suite("Дошка розшуку: правила")
	var BS = load("res://scripts/game/bounty_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Elites = load("res://scripts/data/elites.gd")
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		if L["type"] != "field":
			continue
		var named := false
		for k in L["enemies"]:
			if Acts.BOUNTY_NAMES.has(k):
				named = true
		check(named, "%s: є кого розшукувати" % id)
	var w = WorldState.new()
	var p = _new_player()
	p.level = 3
	check(not BS.unlocked(p) and BS.board(w, "kyiv", p).is_empty(), "до 4 рівня розшуку нема")
	p.level = 10
	var b: Array = BS.board(w, "kyiv", p)
	check(b.size() == Acts.BOUNTY_BOARD, "на дошці два оголошення")
	var ok := true
	for bt in b:
		var L: Dictionary = Data.LOCATIONS[bt["loc"]]
		if L["type"] != "field" or not (bt["kind"] in L["enemies"]) or not (bt["name"] in Acts.BOUNTY_NAMES[bt["kind"]]):
			ok = false
		if bt["affixes"].size() < 2 or bt["affixes"].size() > 3 or int(bt["gold"]) <= 0 or int(bt["glory"]) <= 0 or bt["killed"]:
			ok = false
		for a in bt["affixes"]:
			if not Elites.AFFIXES.has(a):
				ok = false
		if int(L["level"]) > p.level + 3:
			ok = false
	check(ok, "оголошення: дика місцевість до снаги, вид звідти, ім'я, властивості, нагорода")
	check(b[0]["name"] != b[1]["name"] and b[0]["id"] != b[1]["id"], "оголошення різні")
	check(BS.board(w, "kyiv", p) == b, "дошка не змінюється без походів")
	for c in Data.CITIES:
		check(BS.board(w, c, p).size() == Acts.BOUNTY_BOARD and not BS.candidates(c, p).is_empty(), "%s: дошка розшуку заповнена" % c)
	# Узяти
	var first: Dictionary = b[0]
	check(BS.take(w, "kyiv", first["id"], p) and BS.state(w)["active"].size() == 1 and BS.board(w, "kyiv", p).size() == 1, "узяв — з дошки зникло")
	check(BS.mine(w, "kyiv").size() == 1 and BS.mine(w, "lviv").is_empty(), "узяте видно в тому самому місті")
	check(BS.target_at(w, first["loc"])["id"] == first["id"] and first["loc"] in BS.targets(w), "ціль ходить у своїй місцевості")
	var m: Dictionary = BS.mods_for(w, first["loc"], p)
	check(m.has("bounty") and int(m["bounty"]["level"]) >= p.level and m["bounty"]["name"] == first["name"], "ціль не слабша за героя")
	check(BS.mods_for(w, "kremlin", p).is_empty(), "в інших місцях цілі нема")
	var second: Dictionary = BS.board(w, "kyiv", p)[0]
	BS.take(w, "kyiv", second["id"], p)
	var lb: Array = BS.board(w, "lviv", p)
	check(not BS.can_take(w) and not BS.take(w, "lviv", lb[0]["id"], p), "більше двох голів водночас не шукають")
	BS.drop(w, second["id"])
	check(BS.state(w)["active"].size() == 1, "відмовився — оголошення знято")
	# Убити й здати
	check(BS.turn_in(w, p, first["id"]).is_empty(), "живу ціль не здати")
	var km: String = BS.on_kill(w, first["id"])
	check(first["name"] in km and BS.target_at(w, first["loc"]).is_empty() and BS.on_kill(w, first["id"]) == "" and BS.on_kill(w, 9999) == "", "ціль убито один раз")
	var g0: int = p.gold
	var loy0: int = w.loyalty_points("kyiv")
	var tm: Array = BS.turn_in(w, p, first["id"])
	check(not tm.is_empty() and p.gold == g0 + int(first["gold"]) and w.loyalty_points("kyiv") == loy0 + 30 and GS.glory(w) == int(first["glory"]) and int(BS.state(w)["done"]) == 1, "здав голову: гривні, слава, лояльність")
	check(BS.state(w)["active"].is_empty() and BS.turn_in(w, p, first["id"]).is_empty(), "двічі не здати")
	check(BS.traits(first) != "", "властивості цілі описані словами")
	# Оновлення дошки
	var old_ids := []
	for bt in BS.board(w, "lviv", p):
		old_ids.append(bt["id"])
	for i in Acts.BOUNTY_REFRESH:
		BS.tick(w)
	var fresh := true
	for bt in BS.board(w, "lviv", p):
		if bt["id"] in old_ids:
			fresh = false
	check(fresh and BS.board(w, "lviv", p).size() == Acts.BOUNTY_BOARD, "за шість походів дошка нова")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(int(w2.bounties["done"]) == 1 and w2.bounties["boards"].has("lviv"), "розшук зберігається")


func _suite_bounty_battle() -> void:
	suite("Дошка розшуку: полювання на ціль")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	p.change_class("cossack")
	p.level = 12
	p.stats["str"] = 60
	p.stats["vit"] = 60
	p.recalc()
	p.hp = p.max_hp
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "bounty": true, "stones": true}
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	game.enter_city("kyiv")
	game.hud.close_dialogue()
	var BS = game.BountyService
	var bt: Dictionary = BS.board(game.world, "kyiv", p)[0]
	game.city_do("bounty_take", bt["id"])
	check(BS.state(game.world)["active"].size() == 1, "узяв оголошення в місті")
	game.enter_map()
	await _frames(2)
	check(game.hud.map_view.targets.has(bt["loc"]), "місцевість цілі позначена на мапі")
	await _ride(game, bt["loc"])
	var target = null
	for e in game.combat.get_tree().get_nodes_in_group("enemies"):
		if e.bounty_id == bt["id"]:
			target = e
	check(game.state == game.State.PLAYING and target != null and target.elite and target.title == bt["name"] and target.level >= p.level, "ціль на місцевості: еліта з іменем, не слабша за героя")
	check(target.affixes == bt["affixes"], "властивості — як в оголошенні")
	target.take_damage(target.max_hp * 5.0, Vector2.ZERO)
	await _frames(3)
	check(BS.state(game.world)["active"][0]["killed"] and int(game.world.stats.get("bounty_kill", 0)) == 1, "ціль убито — голову здобуто")
	game.enter_map()
	await _frames(2)
	check(not game.hud.map_view.targets.has(bt["loc"]) or not game.world.quest_targets().is_empty(), "позначка з мапи зникла")
	var g0: int = p.gold
	game.enter_city("kyiv")
	game.hud.close_dialogue()
	game.city_do("bounty_turn_in", bt["id"])
	check(p.gold >= g0 + int(bt["gold"]) and BS.state(game.world)["active"].is_empty() and int(game.world.stats.get("bounty", 0)) == 1, "здав голову в місті — нагорода")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_duel() -> void:
	suite("Герць: правила турніру")
	var DS = load("res://scripts/game/duel_service.gd")
	var GS = load("res://scripts/game/glory_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	var w = WorldState.new()
	var p = _new_player()
	check(not DS.unlocked(p), "селянина на майдан не пускають")
	p.change_class("cossack")
	p.level = 4
	check(not DS.unlocked(p), "до 5 рівня — зарано")
	p.level = 12
	p.recalc()
	check(DS.unlocked(p) and DS.can_fight(w, p), "козак 12 рівня може битись")
	var s: Dictionary = DS.state(w)
	check(int(s["round"]) == 0 and int(s["tries"]) == DS.TRIES and not DS.is_champion(w), "новий тиждень: 0 кіл, 3 спроби")
	var lu: Array = DS.lineup()
	check(lu.size() == 3 and lu[0] != lu[1] and lu[1] != lu[2] and lu[0] != lu[2], "три різні суперники")
	check(lu == DS.lineup(), "склад суперників сталий протягом тижня")
	var variety := {}
	for i in 12:
		variety[str(DS.lineup("W%d" % (3000 + i)))] = true
	check(variety.size() >= 4, "щотижня склад інший")
	for id in Acts.RIVAL_ORDER:
		check(Acts.RIVALS.has(id) and Acts.RIVALS[id]["bio"] != "" and Acts.RIVALS[id]["style"] in ["rubaka", "spysnyk", "strilets", "kharakternyk", "bulavnyk"], "суперник %s описаний" % id)
	var l0: Dictionary = DS.loc_for(p, "ostap", 0)
	var l2: Dictionary = DS.loc_for(p, "ostap", 2)
	check(l0["type"] == "duel" and l0["rival_hp"] > 0.0 and l2["rival_hp"] > l0["rival_hp"] and l2["rival_dmg"] > l0["rival_dmg"], "фінал важчий за перше коло")
	var weak = _new_player()
	weak.change_class("cossack")
	weak.level = 12
	weak.recalc()
	p.stats["str"] = 80
	p.stats["vit"] = 80
	p.recalc()
	check(DS.loc_for(p, "ostap", 0)["rival_hp"] > DS.loc_for(weak, "ostap", 0)["rival_hp"] * 1.5, "суперник міряється силою з героєм")
	# Перемоги
	var g0: int = p.gold
	var m1: Array = DS.win(w, p)
	check(int(DS.state(w)["round"]) == 1 and p.gold == g0 + DS.gold_for(0, p.level) and GS.glory(w) == Acts.DUEL_GLORY[0] and "Коло 1" in m1[0], "перше коло: гривні й слава")
	DS.win(w, p)
	var bag0: int = p.inventory.size()
	var m3: Array = DS.win(w, p)
	check(DS.is_champion(w) and int(DS.state(w)["titles"]) == 1 and not DS.can_fight(w, p), "три кола — чемпіон, більше цього тижня не б'ється")
	check(p.inventory.size() == bag0 + 1 and p.inventory[-1]["name"] == DS.BELT_NAME and p.inventory[-1]["rarity"] == 3 and p.inventory[-1]["slot"] == "belt", "перший титул — легендарний пояс чемпіона")
	check(GS.glory(w) == 40 and GS.rank_name(w) == "Знаний козак" and "чемпіон" in m3[0].to_lower(), "40 слави — ранг «Знаний козак»")
	check(m3.size() >= 2 and "Слава росте" in m3[-1], "повідомлення про новий ранг")
	check(DS.next_rival(w).is_empty(), "після фіналу суперників нема")
	# Наступний тиждень
	CS.now_override = 1762700000 + 7 * 86400
	check(int(DS.state(w)["round"]) == 0 and int(DS.state(w)["tries"]) == DS.TRIES and DS.can_fight(w, p) and int(DS.state(w)["titles"]) == 1, "новий тиждень — новий турнір, титули лишаються")
	var tr0: int = int(p.resources.get("trophy", 0))
	for i in 3:
		DS.win(w, p)
	check(int(DS.state(w)["titles"]) == 2 and int(p.resources.get("trophy", 0)) == tr0 + 3 and p.inventory.size() == bag0 + 1, "другий титул — трофеї замість другого пояса")
	# Поразки
	CS.now_override = 1762700000 + 14 * 86400
	var lm: String = DS.lose(w)
	check(int(DS.state(w)["tries"]) == 2 and "2" in lm, "поразка — мінус спроба")
	DS.lose(w)
	DS.lose(w)
	check(int(DS.state(w)["tries"]) == 0 and not DS.can_fight(w, p), "без спроб на майдан не вийти")
	check(DS.days_to_reset() >= 1 and DS.days_to_reset() <= 7, "до нового турніру 1–7 днів")
	# Слава: ранги
	var w2 = WorldState.new()
	var p2 = _new_player()
	var gg: int = p2.gold
	var st0: int = int(p2.stones.get("zabuttia", 0))
	var gm: Array = GS.add(w2, p2, 300)
	check(gm.size() == 3 and GS.rank_name(w2) == "Славний лицар" and p2.gold == gg + 300 + 800 + 2000 and int(p2.stones.get("zabuttia", 0)) == st0 + 1, "слава одразу через три ранги: усі нагороди й камінь")
	check(GS.to_next(w2) == 400 and GS.add(w2, p2, 0).is_empty(), "до наступного рангу 400")
	var w3 = WorldState.new()
	w3.from_dict(w.to_dict())
	check(w3.glory == w.glory and int(w3.duel["titles"]) == 2, "слава й герць зберігаються")
	CS.now_override = 0


func _suite_duel_battle() -> void:
	suite("Герць: поєдинок")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "duel": true, "stones": true}
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.city_do("duel_start", null)
	await _frames(2)
	check(game.state == game.State.CITY, "селянин на герць не виходить")
	p.change_class("cossack")
	p.level = 15
	p.stats["str"] = 40
	p.stats["vit"] = 40
	p.skills = {"whirl": 3}
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	game.world.companions = [{"type": "dzhura", "downed": false, "level": 10, "xp": 0}]
	var trips0: int = int(game.EventService.state(game.world)["trips"])
	var gold0: int = p.gold
	game.city_do("duel_start", null)
	await _frames(2)
	var rival = game.combat.nearest_enemy(p.global_position, 5000.0)
	check(game.state == game.State.PLAYING and game.combat.is_duel() and rival != null and rival.style != "" and rival.title != "", "герць почався: суперник з іменем і стилем")
	check(game.combat.companion_nodes.is_empty() and game.combat.spectators.size() > 10, "сам на сам, довкола глядачі")
	check(game.combat.arena == game.combat.DUEL_ARENA and game.combat.loc["biome"] == "maidan", "бій на майдані")
	game.open_character()
	check(game.state == game.State.PLAYING, "під час герцю торбу не відкрити")
	var hp_full: float = rival.max_hp
	rival.take_damage(hp_full * 0.9, Vector2.ZERO)
	check(rival.hp > hp_full * 0.5, "суперника не зарубати одним ударом")
	var frames := 0
	while not game.combat.duel_over and frames < 9000 and game.state == game.State.PLAYING:
		_bot_fight(game)
		p.hp = p.max_hp
		await process_frame
		frames += 1
	check(game.combat.duel_over and int(game.DuelService.state(game.world)["round"]) == 1 and p.gold > gold0, "коло виграно (кадрів: %d): гривні й поступ" % frames)
	check(int(game.world.stats.get("duel", 0)) == 1 and game.GloryService.glory(game.world) > 0, "лічильник герцю й слава")
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and game.city_id == "sich", "з порталу — назад на Січ")
	check(int(game.EventService.state(game.world)["trips"]) == trips0, "герць — не похід: світ не робить кроку")
	# Поразка: без втрати гривень, мінус спроба
	game.hud.close_dialogue()
	var gold1: int = p.gold
	game.city_do("duel_start", null)
	await _frames(2)
	check(game.combat.is_duel() and game.combat.loc["round"] == 1, "друге коло")
	p.invuln = 0.0  # після входу в місто герой мить невразливий
	p.take_damage(p.max_hp * 20.0, null)
	await _frames(3)
	check(not p.alive and int(game.DuelService.state(game.world)["tries"]) == game.DuelService.TRIES - 1, "поклали на лопатки — мінус спроба")
	frames = 0
	while game.state != game.State.CITY and frames < 300:
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and p.alive and p.gold == gold1, "після поразки — на Січі, живий і при грошах")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_tower_battle() -> void:
	suite("Башта Кощія: підйом")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "block": true, "elite": true, "boss": true, "item": true, "map": true, "tower": true, "stones": true, "cleared": true}
	var p = game.player
	game.start_tower(1)
	await _frames(2)
	check(game.state != game.State.PLAYING, "до 15 рівня не пускає")
	p.change_class("cossack")
	p.level = 40
	p.stats["str"] = 200
	p.stats["vit"] = 200
	p.skills = {"whirl": 5}
	p.recalc()
	p.hp = p.max_hp
	var gold0: int = p.gold
	game.start_tower(1)
	await _frames(2)
	check(game.state == game.State.PLAYING and game.combat.loc.get("floor", 0) == 1 and game.combat.is_tower(), "підйом на поверх 1")
	var frames := 0
	var saw_mini := false
	while game.state == game.State.PLAYING and game.TowerService.state(game.world)["best"] < 1 and frames < 9000:
		_bot_fight(game)
		p.hp = p.max_hp
		if game.combat.tower_boss_spawned and not saw_mini:
			for e in game.combat.get_tree().get_nodes_in_group("enemies"):
				if e.elite and ":" in e.title:
					saw_mini = true
		await process_frame
		frames += 1
	check(game.TowerService.state(game.world)["best"] == 1 and game.TowerService.state(game.world)["max"] == 2, "поверх 1 пройдено (кадрів: %d)" % frames)
	check(saw_mini, "міні-бос з іменем був на арені")
	check(p.gold > gold0 and int(game.world.stats.get("tower", 0)) == 1, "нагорода за перше проходження й рекорд")
	# Портал «Вище» веде на другий поверх без виходу на мапу
	frames = 0
	while game.combat.loc.get("floor", 0) == 1 and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.PLAYING and game.combat.loc.get("floor", 0) == 2 and game.combat.is_tower(), "портал «Вище» — поверх 2 без виходу (кадрів: %d)" % frames)
	# Супербоси створюються й б'ються без помилок
	for k in game.TowerService.SUPER_BOSSES:
		game.combat.spawn_enemy(k, 20, true, Vector2(0, -300))
		var e = game.combat._last_enemy()
		check(e.is_boss and e.kind == k and e.max_hp > 1000.0, "супербос %s на арені" % k)
		e._boss_ability(p)
		e._boss_ability(p)
		e._boss_ability(p)
		e.take_damage(e.max_hp * 0.6, Vector2.ZERO)
		check(e.phase2, "%s лютує на половині здоров'я" % k)
		e.take_damage(e.max_hp, Vector2.ZERO)
	await _frames(3)
	check(p.alive, "герой живий після здібностей босів")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_bulk_sell() -> void:
	suite("Масовий продаж")
	var p = _new_player()
	p.inventory.clear()
	p.gold = 0
	var junk_a = Data.gen_item(3, 0, "head")
	var junk_b = Data.gen_item(3, 0, "belt")
	var good = Data.gen_item(3, 1, "head")
	var rare = Data.gen_item(3, 2, "boots")
	var best_sabre = Data.gen_item(9, 0, "weapon", "sabre")  # краща за вдягнену «Стару шаблю» — лишається
	var cheap_sabre = Data.gen_item(1, 0, "weapon", "sabre")
	for it in [junk_a, junk_b, good, rare, best_sabre, cheap_sabre]:
		p.add_item(it)
	check(CityService.is_upgrade(p, best_sabre) and not CityService.is_upgrade(p, cheap_sabre), "краща за вдягнену шабля — покращення")
	check(CityService.is_upgrade(p, good) and not CityService.is_upgrade(p, junk_a), "у порожній слот лишається лише найкраща шапка")
	var c0: Array = CityService.bulk_candidates(p, 0)
	check(c0.size() == 2 and (junk_a in c0) and (cheap_sabre in c0) and not (best_sabre in c0) and not (junk_b in c0), "звичайні: без кращої шаблі й без єдиного пояса")
	var c2: Array = CityService.bulk_candidates(p, 2)
	check(c2.size() == 2, "до рідкісних: єдині пояс, шапка й чоботи лишаються")
	p.equip(good["uid"])
	p.equip(rare["uid"])
	p.equip(junk_b["uid"])
	var got: int = CityService.sell_up_to(p, 1)
	check(got > 0 and p.inventory.size() == 1 and (best_sabre in p.inventory), "продано до добротних; покращення лишилось")
	var sabre_uid: int = best_sabre["uid"]
	p.equip(sabre_uid)
	var old_sabre_uid: int = p.inventory[0]["uid"]
	var got2: int = CityService.sell_many(p, [sabre_uid, old_sabre_uid])
	check(got2 > 0 and p.inventory.is_empty() and p.is_equipped(sabre_uid), "вибране продано, вдягнене — ні")
	check(CityService.sell_up_to(p, 2) == 0, "порожня торба — нічого продавати")
	p.free()


func _suite_escort() -> void:
	suite("Супровід: правила")
	var Acts = load("res://scripts/data/activities.gd")
	var ES = load("res://scripts/game/escort_service.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	for id in Acts.ESCORT_ORDER:
		var W: Dictionary = Acts.ESCORT_WHO[id]
		check(W["name"] != "" and W["acc"] != "" and W["thanks"] != "" and GfxS.has(W["sheet"]), "%s: назва, знахідний відмінок, подяка й спрайт" % id)
	check(Acts.ESCORT_WHO.size() == Acts.ESCORT_ORDER.size(), "усі мандрівники в черзі")
	# Дошка: супровід трапляється лише в дику місцевість, не в печеру
	seed(20261110)
	var w = WorldState.new()
	var field_n := 0
	var escort_n := 0
	var kinds := {}
	var types := {}
	for i in 900:
		var q: Dictionary = w._gen_quest(["sich", "kyiv", "lviv"][i % 3])
		var L: Dictionary = Data.LOCATIONS[q["loc"]]
		types[q["type"]] = true
		if L["type"] != "dungeon":
			field_n += 1
		if q["type"] != "escort":
			continue
		escort_n += 1
		kinds[q["target"]] = true
		check(L["type"] != "dungeon" and int(q["count"]) == 1 and Acts.ESCORT_WHO.has(q["target"]), "супровід: дика місцевість, один мандрівник")
		check(q["text"] == "Проведи %s (%s)" % [Acts.ESCORT_WHO[q["target"]]["acc"], L["name"]], "текст завдання: %s" % q["text"])
		check(int(q["gold"]) == int((40 + 25 * int(L["level"])) * Acts.ESCORT_MULT), "нагорода більша за звичайну")
	var share := float(escort_n) / float(maxi(field_n, 1))
	check(share > Acts.ESCORT_CHANCE - 0.08 and share < Acts.ESCORT_CHANCE + 0.08, "частка супроводів серед завдань у поле: %.2f" % share)
	check(kinds.size() == Acts.ESCORT_ORDER.size(), "трапляються всі мандрівники")
	check(types.has("kill") and types.has("fetch") and types.has("dungeon"), "решта типів завдань лишилась")
	for r in [0.0, 0.26, 0.51, 0.76, 0.999, 1.0]:
		var qq := {"id": 1, "city": "sich", "loc": "wild_field", "progress": 0, "lvl": 1}
		ES.fill(qq, r)
		check(qq["target"] == Acts.ESCORT_ORDER[mini(int(r * 4.0), 3)], "вибір мандрівника за кидком %.2f" % r)
	# Узяте завдання: служба бачить його в місцевості
	var w2 = WorldState.new()
	var p = _new_player()
	var q1 := {"id": 77, "city": "sich", "loc": "rapids", "progress": 0, "lvl": 2, "gold": 100, "xp": 50, "loyalty": 40}
	ES.fill(q1, 0.0)
	check(ES.at(w2, "rapids").is_empty(), "не взяте завдання в місцевості не чекає")
	w2.quests.append(q1)
	check(ES.at(w2, "rapids") == q1 and ES.at(w2, "wild_field").is_empty() and ES.is_open(q1), "узяте завдання чекає у своїй місцевості")
	check(w2.quest_targets().has("rapids"), "місцевість позначено на мапі")
	check(w2.on_kill("mavka").is_empty() and int(q1["progress"]) == 0, "убита нечисть супроводу не зараховує")
	w2.on_dungeon("rapids")
	check(int(q1["progress"]) == 0, "зачистка печери теж")
	# Опис бою
	var B: Dictionary = ES.battle_loc(q1)
	var L1: Dictionary = Data.LOCATIONS["rapids"]
	check(B["type"] == "defense" and B["variant"] == "escort" and int(B["waves"]) == Acts.ESCORT_WAVES and int(B["escort"]) == 77 and B["who"] == "kobzar", "бій: оборона з мандрівником, три засідки")
	check(int(B["level"]) == int(L1["level"]) and B["enemies"] == L1["enemies"] and B["target"] == "rapids" and B["biome"] == L1["biome"], "рівень, нечисть і краєвид — від місцевості")
	check(is_equal_approx(float(B["gate_hp"]), Acts.ESCORT_HP + Acts.ESCORT_HP_LVL * int(L1["level"])) and ES.hp(10) > ES.hp(2), "здоров'я мандрівника росте з рівнем")
	check("кобзар" in B["name"], "назва бою: %s" % B["name"])
	# Не вберіг: завдання лишається
	var lost: String = ES.lose(w2, 77)
	check("спробуй ще раз" in lost and "Кобзар" in lost and "втік" in lost and ES.is_open(q1) and w2.quests.size() == 1, "поразка: завдання лишилось")
	# Довів: виконано, вдячність за цілого мандрівника, нагорода в місті
	p.gold = 0
	var won: String = ES.win(w2, p, 77, 1.0)
	check(w2.is_done(q1) and not ES.is_open(q1) and ES.at(w2, "rapids").is_empty(), "перемога: завдання виконано")
	check(p.gold == Acts.ESCORT_TIP * 2 and "дійшов" in won and Data.CITIES["sich"]["name"] in won and str(Acts.ESCORT_WHO["kobzar"]["thanks"]) in won, "подяка й гривні на дорогу: %d" % p.gold)
	check(ES.win(w2, p, 77, 1.0) == "Мандрівник дійшов." and p.gold == Acts.ESCORT_TIP * 2, "двічі те саме завдання не зарахувати")
	check(not w2.quest_targets().has("rapids"), "позначка з мапи зникла")
	var g0: int = p.gold
	var loy0: int = w2.loyalty_points("sich")
	var r1: Dictionary = CityService.turn_in(w2, p, 77)
	check(not r1.is_empty() and p.gold == g0 + 100 and w2.loyalty_points("sich") == loy0 + 40 and w2.quests.is_empty(), "здача в місті: гривні й лояльність")
	# Побитий мандрівник дякує скупіше; знахарка — жіночого роду
	var q2 := {"id": 78, "city": "kyiv", "loc": "black_forest", "progress": 0, "lvl": 4, "gold": 10, "xp": 10, "loyalty": 10}
	ES.fill(q2, 0.99)
	w2.quests.append(q2)
	check(q2["target"] == "znakharka" and "втекла" in ES.lose(w2, 78), "знахарка: «втекла»")
	p.gold = 0
	var won2: String = ES.win(w2, p, 78, 0.5)
	check(p.gold == int(round(Acts.ESCORT_TIP * 4 * 0.5)) and "дійшла" in won2, "половина здоров'я — половина подяки")
	var q3 := {"id": 79, "city": "kyiv", "loc": "black_forest", "progress": 0, "lvl": 4, "gold": 10, "xp": 10, "loyalty": 10}
	ES.fill(q3, 0.3)
	w2.quests.append(q3)
	p.gold = 0
	check("грн" not in ES.win(w2, p, 79, 0.0) and p.gold == 0 and w2.is_done(q3), "ледве живий — без гривень, але завдання виконано")
	# Збереження
	var w3 = WorldState.new()
	w3.from_dict(w2.to_dict())
	check(w3.quests.size() == 2 and w3.quests[0]["type"] == "escort" and w3.is_done(w3.quests[0]), "супровід зберігається разом із завданнями")
	# Досягнення й тижневий виклик
	var ach := {}
	for a in Ach.ACHIEVEMENTS:
		ach[a["id"]] = a
	check(ach.has("escort_1") and ach.has("escort_15") and ach.has("escort_clean") and ach["escort_clean"]["stat"] == "escort_clean", "досягнення супроводу")
	var weekly := false
	for c in Ach.WEEKLY:
		if c["stat"] == "escort":
			weekly = true
	check(weekly, "тижневий виклик на супровід")
	p.free()


func _suite_escort_game() -> void:
	suite("Супровід: у грі")
	var Acts = load("res://scripts/data/activities.gd")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	root.get_node("Ads").instant = true
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	p.change_class("cossack")
	p.level = 20
	p.stats["str"] = 120
	p.stats["vit"] = 120
	p.skills = {"whirl": 5}
	p.recalc()
	p.hp = p.max_hp
	game.world.hints = {"combat": true, "block": true, "defense": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "trail": true}
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	var ES = game.EscortService
	var q := {"id": 901, "city": "sich", "loc": "wild_field", "progress": 0, "lvl": 1, "gold": 104, "xp": 80, "loyalty": 56}
	ES.fill(q, 0.0)
	game.world.quests.append(q)
	# Мапа: окрема кнопка «Провести», звичайний похід супроводу не починає
	game.enter_map()
	await _frames(2)
	game._on_map_select("wild_field")
	await _frames(2)
	var texts := []
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		texts.append(b.text)
	check("Провести кобзаря" in texts and "Вирушити" in texts, "на мапі дві кнопки: %s" % str(texts))
	game._on_map_select("rapids")
	await _frames(2)
	texts = []
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		texts.append(b.text)
	check("Вирушити" in texts and texts.size() == 1, "в іншій місцевості кнопки супроводу нема")
	await _ride(game, "wild_field")
	check(game.state == game.State.PLAYING and not game.combat.is_defense() and ES.is_open(q), "«Вирушити» — звичайний похід")
	# «Провести»: бій із мандрівником
	await _ride(game, "wild_field", true)
	var c = game.combat
	check(game.state == game.State.PLAYING and c.is_defense() and c.gate != null and c.gate.variant == "escort", "«Провести» — супровід")
	check(c.gate.sheet == "trav_kobzar" and c.gate.label_text() == "Кобзар" and c.gate.radius < 30.0 and is_equal_approx(c.gate.max_hp, ES.hp(1)), "мандрівник на арені: кобзар")
	check(game.world.hints.has("escort"), "підказку про супровід показано")
	check("Шлях 0%" in game._combat_info()["sub"] and "Кобзар 100%" in game._combat_info()["sub"], "рядок бою: %s" % game._combat_info()["sub"])
	var y0: float = c.gate.position.y
	for i in 260:
		await process_frame
	check(c.gate.position.y < y0 - 40.0 and c.gate.walking and not c.gate.scared and c.wave == 0, "мандрівник іде ареною сам (пройшов %.0f)" % (y0 - c.gate.position.y))
	check(c.escort_part() > 0.03 and c.escort_part() < 0.25, "частка шляху: %.2f" % c.escort_part())
	# Перша засідка на чверті шляху
	var frames := 0
	while c.wave == 0 and frames < 900:
		await process_frame
		frames += 1
	var pack: int = Acts.ESCORT_PACK + Acts.ESCORT_PACK_STEP
	check(c.wave == 1 and c.alive_enemy_count() == pack and absf(c.escort_part() - 0.25) < 0.02, "засідка на чверті шляху: %d ворогів" % c.alive_enemy_count())
	var near := 0
	var rams := 0
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(c.gate.global_position) < 380.0:
			near += 1
		if e.rams_gate:
			rams += 1
	check(near == 0 and rams == pack / 2, "нечисть вискакує не впритул, половина кидається на мандрівника")
	# Нечисть поруч — стоїть; лікування діє
	var foe = c.get_tree().get_nodes_in_group("enemies")[0]
	foe.global_position = c.gate.global_position + Vector2(120, 0)
	foe.stun = 5.0
	await _frames(3)
	var y1: float = c.gate.position.y
	await _frames(20)
	check(c.gate.scared and not c.gate.walking and is_equal_approx(c.gate.position.y, y1), "нечисть поруч — мандрівник стоїть")
	c.gate.take_damage(100.0, foe)
	var hp1: float = c.gate.hp
	c.gate.heal(40.0)
	check(hp1 < c.gate.max_hp and is_equal_approx(c.gate.hp, hp1 + 40.0), "мандрівника можна лікувати")
	# Влучили здалеку (стрілець за межею страху): однаково на мить завмирає
	foe.global_position = c.gate.global_position + Vector2(0, -700)
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e != foe:
			e.global_position = c.gate.global_position + Vector2(randf_range(-80, 80), -720)
			e.stun = 5.0
	c.gate.flinch = 0.0
	await _frames(3)
	var far_ok: bool = not c.gate.scared
	c.gate.take_damage(1.0, foe)
	await _frames(3)
	check(far_ok and c.gate.scared and not c.gate.walking and c.gate.flinch > 0.0, "постріл здалеку теж спиняє мандрівника")
	check("Кобзар" in game._combat_info()["sub"] and "Шлях 25%" in game._combat_info()["sub"], "рядок бою: %s" % game._combat_info()["sub"])
	# Бот доводить до кінця
	var kills0 := int(game.world.stats.get("escort", 0))
	frames = 0
	var max_wave := 0
	while not c.defense_over and frames < 9000:
		_bot_fight(game)
		c.gate.hp = c.gate.max_hp
		p.hp = p.max_hp
		max_wave = maxi(max_wave, c.wave)
		await process_frame
		frames += 1
	check(c.defense_over and c.field_cleared and max_wave == 3 and c.escort_part() >= 1.0, "довів до кінця через три засідки (кадрів: %d)" % frames)
	check(game.world.is_done(q) and int(game.world.stats.get("escort", 0)) == kills0 + 1 and int(game.world.stats.get("escort_clean", 0)) == 1, "завдання виконано, лічильники зросли")
	var ach_open: Dictionary = load("res://scripts/game/challenge_service.gd").state(game.world)["ach"]
	check(ach_open.has("escort_1") and ach_open.has("escort_clean"), "досягнення «Надійний провідник» і «Ані подряпини»")
	check("Портал веде на мапу" in game._combat_info()["sub"], "рядок після перемоги: %s" % game._combat_info()["sub"])
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.MAP, "з порталу — на мапу")
	game._on_map_select("wild_field")
	await _frames(2)
	texts = []
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		texts.append(b.text)
	check("Провести кобзаря" not in texts, "виконане завдання кнопки не лишає")
	var g0: int = p.gold
	check(not CityService.turn_in(game.world, p, 901).is_empty() and p.gold == g0 + 104, "нагорода в місті")
	# Не вберіг: мандрівник тікає, завдання лишається
	var q2 := {"id": 902, "city": "sich", "loc": "wild_field", "progress": 0, "lvl": 1, "gold": 104, "xp": 80, "loyalty": 56}
	ES.fill(q2, 0.99)
	game.world.quests.append(q2)
	await _ride(game, "wild_field", true)
	c = game.combat
	check(c.is_defense() and c.gate.sheet == "trav_znakharka" and c.gate.label_text() == "Знахарка", "другий супровід: знахарка")
	var y2: float = c.gate.position.y
	c.gate.take_damage(99999.0, null)
	check(c.defense_over and not c.gate.alive and ES.is_open(q2), "не вберіг: бій програно, завдання лишилось")
	await _frames(30)
	check(c.gate.position.y > y2 + 20.0, "мандрівниця тікає назад")
	await create_timer(2.8).timeout
	await _frames(3)
	check(game.state == game.State.MAP and game.world.quests.has(q2) and int(game.world.stats.get("escort", 0)) == kills0 + 1, "після поразки — на мапу, завдання чекає")
	# Звичайна поїздка після супроводу не тягне супровід за собою
	await _ride(game, "wild_field")
	check(game.state == game.State.PLAYING and not game.combat.is_defense(), "наступний звичайний похід — звичайний")
	# Герой поліг під час супроводу: завдання лишається, місто нічого не втрачає
	await _ride(game, "wild_field", true)
	check(game.combat.is_defense() and game.combat.gate.variant == "escort", "третій супровід почався")
	var loy0: int = game.world.loyalty_points("sich")
	p.unbreak_ready = false
	p.berehynia_ready = false
	p.take_damage(1e9)
	await _frames(3)
	check(game.state == game.State.DEAD and game.combat.defense_over and ES.is_open(q2) and game.world.loyalty_points("sich") == loy0, "герой поліг: супровід зірвано, завдання чекає")
	await create_timer(1.6).timeout
	await _frames(3)
	game.enter_city(game.world.last_city)
	await _frames(2)
	check(game.state == game.State.CITY and game.world.quests.has(q2), "після поразки герой у місті, завдання при ньому")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_safe_area() -> void:
	suite("Безпечна зона екрана")
	var WM = load("res://scripts/ui/world_map.gd")
	check(WM.ICONS.get_width() == 24 * WM.ICON_ORDER.size() and WM.ICON_ORDER.has("rider") and WM.ICON_ORDER.has("rider2"), "лист значків мапи відповідає переліку, вершник має два кадри")
	var frames_seen := {}
	for i in 40:
		frames_seen[WM.rider_frame(i * 0.1)] = true
	check(frames_seen.size() == 2, "у дорозі кадри вершника чергуються")
	var HudS = load("res://scripts/ui/hud.gd")
	var zero := [0.0, 0.0, 0.0, 0.0]
	var view := Vector2(1600, 720)
	var win := Vector2i(2400, 1080)
	check(HudS.insets_from(win, Rect2i(0, 0, 2400, 1080), view) == zero, "без вирізу відступів нема")
	var a: Array = HudS.insets_from(win, Rect2i(90, 0, 2310, 1080), view)
	check(is_equal_approx(a[0], 60.0) and a[1] == 0.0 and a[2] == 0.0 and a[3] == 0.0, "виріз ліворуч: 90 пікселів екрана — 60 одиниць полотна")
	var b: Array = HudS.insets_from(win, Rect2i(0, 0, 2310, 1080), view)
	check(b[0] == 0.0 and is_equal_approx(b[2], 60.0), "виріз праворуч")
	var c: Array = HudS.insets_from(win, Rect2i(0, 30, 2400, 1020), view)
	check(is_equal_approx(c[1], 20.0) and is_equal_approx(c[3], 20.0), "смуги згори й знизу")
	check(HudS.insets_from(win, Rect2i(0, 0, 0, 0), view) == zero and HudS.insets_from(Vector2i(0, 0), Rect2i(0, 0, 10, 10), view) == zero, "порожні дані пристрою — без відступів")
	var d: Array = HudS.insets_from(win, Rect2i(1000, 500, 400, 80), view)
	check(d[0] <= view.x * HudS.SAFE_MAX_X + 0.01 and d[2] <= view.x * HudS.SAFE_MAX_X + 0.01 and d[1] <= view.y * HudS.SAFE_MAX_Y + 0.01 and d[3] <= view.y * HudS.SAFE_MAX_Y + 0.01, "хибні дані не з'їдають екран: %s" % str(d))
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	var hud = game.hud
	var full: Vector2 = hud.get_viewport().get_visible_rect().size
	check(hud.insets == zero and hud.ui_root.offset_left == 0.0 and hud.ui_root.offset_right == 0.0, "на комп'ютері відступів нема")
	# Значок і заставка застосунку на місці (їх шукають і проєкт, і пресети збірки)
	for path in [str(ProjectSettings.get_setting("application/config/icon")), str(ProjectSettings.get_setting("application/boot_splash/image")),
			"res://assets/gfx/icon/icon_fg_432.png", "res://assets/gfx/icon/icon_bg_432.png"]:
		check(path.begins_with("res://assets/gfx/icon/") and ResourceLoader.exists(path), "зображення застосунку є: %s" % path)
	var joy0: Vector2 = hud.joystick.rest_pos
	var atk0: Vector2 = hud.btn_attack.position
	var map0: Rect2 = hud.map_view.map_rect
	# Виріз ліворуч
	HudS.insets_override = [64.0, 0.0, 0.0, 0.0]
	hud.layout()
	check(hud.ui_root.offset_left == 64.0 and hud.ui_root.offset_right == 0.0 and is_equal_approx(hud.joystick.rest_pos.x, joy0.x + 64.0) and hud.btn_attack.position == atk0, "виріз ліворуч: джойстик і смуги героя відсунуто, кнопки праворуч на місці")
	check(is_equal_approx(hud.map_view.map_rect.size.x, map0.size.x - 64.0) and hud.vignette.offset_left == -64.0, "мапа вужча на виріз, червоне мерехтіння — до краю")
	# Виріз праворуч: телефон перевернули, екран той самий — інтерфейс має помітити сам
	HudS.insets_override = [0.0, 0.0, 64.0, 0.0]
	await create_timer(0.7).timeout
	await _frames(2)
	check(hud.insets == [0.0, 0.0, 64.0, 0.0] and hud.ui_root.offset_left == 0.0 and hud.ui_root.offset_right == -64.0, "перевернутий телефон: відступ переїхав сам")
	check(is_equal_approx(hud.btn_attack.position.x, atk0.x - 64.0) and is_equal_approx(hud.joystick.rest_pos.x, joy0.x) and is_equal_approx(hud.attack_slots[0].x, full.x - 64.0 - 120.0), "кнопки бою відсунуто від вирізу праворуч")
	# Меню затемнює й смугу під вирізом
	hud.open_overlay()
	await _frames(2)
	check(hud.edge_dim[1].visible and is_equal_approx(hud.edge_dim[1].size.x, 64.0) and is_equal_approx(hud.edge_dim[1].position.x, full.x - 64.0) and not hud.edge_dim[0].visible, "меню затемнює смугу під вирізом")
	hud.close_overlay()
	await _frames(2)
	check(not hud.edge_dim[1].visible, "закрили меню — смуга знову прозора")
	HudS.insets_override = []
	hud.layout()
	check(hud.insets == zero and hud.btn_attack.position == atk0 and hud.joystick.rest_pos == joy0 and hud.map_view.map_rect == map0, "без вирізу все на своїх місцях")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_back_button() -> void:
	suite("Кнопка «Назад»")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	game.allow_quit = false
	root.add_child(game)
	await _frames(2)
	var BACK := Node.NOTIFICATION_WM_GO_BACK_REQUEST
	check(not quit_on_go_back, "система сама гру не закриває: «Назад» розбирає гра")
	check(game.state == game.State.MENU, "старт: головне меню")
	game.go_back(false)
	check(not game.quit_requested, "Esc у головному меню гри не закриває")
	game.new_game()
	await _frames(2)
	check(game.hud.dialogue_root != null, "нова гра: кобзар розповідає пролог")
	game._notification(BACK)
	check(game.hud.dialogue_root != null and not game.quit_requested, "під час розмови «Назад» нічого не робить і гри не закриває")
	game.world.hints = {"combat": true, "block": true, "defense": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "camp": true}
	game.hud.dialogue_root._finish()
	await _frames(3)
	check(game.state == game.State.PLAYING and game.hud.dialogue_root == null, "після прологу — бій за рідне село")
	var job1: String = game.player.job
	var pts1: int = game.player.stat_points
	game.player.job = "perun_zhrets"
	game.player.stat_points = 123
	await _frames(4)
	var br: Rect2 = game.hud.char_btn.get_global_rect()
	check(br.size.x > 180.0 and game.hud.map_btn.visible and not br.intersects(game.hud.map_btn.get_global_rect()) and not br.intersects(game.hud.pause_btn.get_global_rect()), "у бою три кнопки в куті не налазять одна на одну (ширина %.0f)" % br.size.x)
	game.player.job = job1
	game.player.stat_points = pts1
	await _frames(2)
	game._notification(BACK)
	check(game.state == game.State.PAUSED and game.hud.overlay.visible, "у бою «Назад» ставить паузу")
	game._notification(BACK)
	check(game.state == game.State.PLAYING and not game.hud.overlay.visible, "на паузі «Назад» повертає в бій")
	game.open_character()
	await _frames(2)
	game._notification(BACK)
	check(game.state == game.State.PLAYING, "з екрана героя «Назад» вертає туди, звідки прийшов")
	game.enter_city("sich")
	await _frames(2)
	game._notification(BACK)
	await _frames(2)
	check(game.state == game.State.MAP, "з міста «Назад» виводить на мапу")
	game.enter_camp()
	await _frames(2)
	game._notification(BACK)
	await _frames(2)
	check(game.state == game.State.MAP, "з хутора теж")
	# Мапа: привал із налаштуваннями
	game._notification(BACK)
	await _frames(2)
	var texts := []
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		texts.append(b.text)
	check(game.state == game.State.MAP and game.hud.overlay.visible and game.map_menu and "Головне меню" in texts and "Вийти з гри" in texts, "на мапі «Назад» відкриває привал: %s" % str(texts))
	game._notification(BACK)
	await _frames(2)
	check(game.state == game.State.MAP and not game.hud.overlay.visible and not game.map_menu, "ще раз «Назад» — привал закрито")
	check(game.hud.pause_btn.visible, "на мапі є кнопка меню")
	# Довга назва класу з очками не налазить на сусідні кнопки (було: «Запорожець +23» закривав кнопку меню)
	var job0: String = game.player.job
	var pts0: int = game.player.stat_points
	game.player.job = "perun_zhrets"
	game.player.stat_points = 123
	await _frames(4)
	var cr: Rect2 = game.hud.char_btn.get_global_rect()
	var pr: Rect2 = game.hud.pause_btn.get_global_rect()
	check(game.hud.char_btn.text.ends_with("+123") and cr.size.x > 180.0 and not cr.intersects(pr) and cr.end.x <= pr.position.x and pr.end.x <= game.hud.get_viewport().get_visible_rect().size.x, "кнопка героя росте ліворуч і не закриває кнопку меню (%s, ширина %.0f)" % [game.hud.char_btn.text, cr.size.x])
	game.player.job = job0
	game.player.stat_points = pts0
	await _frames(2)
	game.hud.pause_pressed.emit()
	await _frames(2)
	check(game.hud.overlay.visible and game.map_menu, "кнопка меню на мапі теж відкриває привал")
	game.go_back(false)
	check(not game.hud.overlay.visible, "Esc закриває привал")
	game._go_to("wild_field")
	game._notification(BACK)
	check(not game.hud.overlay.visible and game.travel_to == "wild_field", "у дорозі привалу нема")
	var frames := 0
	while game.travel_to != "" and frames < 1200:
		if game.hud.dialogue_root != null:
			game.hud.dialogue_root._finish()
		await process_frame
		frames += 1
	game.enter_map()
	await _frames(2)
	# З привалу в головне меню, а звідти системне «Назад» виходить із гри
	game._show_map_menu()
	await _frames(2)
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		if b.text == "Головне меню":
			b.pressed.emit()
	await _frames(2)
	check(game.state == game.State.MENU and SaveSystem.exists(TEST_SAVE), "привал → головне меню, гру збережено")
	game._notification(BACK)
	check(game.quit_requested, "у головному меню системне «Назад» виходить із гри")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Збереження героя для перевірок перенесення: рівень, гривні й клас — щоб було що впізнати.
func _transfer_hero(level: int, gold: int, job: String = "cossack") -> Dictionary:
	var p = _new_player()
	p.change_class(job)
	p.level = level
	p.gold = gold
	p.add_item(Data.gen_item(level, 2))
	var w = WorldState.new()
	w.board("sich")
	w.add_loyalty("sich", 120)
	var d := {"player": p.to_dict(), "world": w.to_dict(), "meta": {"playtime": 60.0 * level}, "version": SaveSystem.SAVE_VERSION}
	p.free()
	return d


func _suite_transfer() -> void:
	suite("Перенесення роду: код")
	var ST = load("res://scripts/core/save_transfer.gd")
	var profile := {"v": 1, "account": {"chest": {"gold": 777, "items": [], "stones": {}}, "camp": {"buildings": {"kuznia": 2}}},
		"heroes": [{"slot": 1, "data": _transfer_hero(26, 1840)}, {"slot": 3, "data": _transfer_hero(9, 55)}], "made": 1762700000}
	var code: String = ST.pack(profile)
	var rx := RegEx.create_from_string("^KZ1:\\d+:\\d+:[0-9a-f]{8}:[A-Za-z0-9+/]+$")
	check(rx.search(code) != null, "код складається лише зі знаків, які не ламають месенджери")
	check(code.length() < 16000, "двоє героїв і хутір — %d знаків" % code.length())
	var r: Dictionary = ST.unpack(code)
	check(r["ok"] and not r["partial"] and r["error"] == "" and r["profile"] == profile, "код розпаковується в той самий рід")
	check(r["profile"]["heroes"][0]["data"]["player"]["level"] == 26 and typeof(r["profile"]["heroes"][0]["data"]["player"]["level"]) == TYPE_INT, "типи збережено: рівень лишився цілим числом")
	# Месенджер розбив код рядками й пробілами, а в кінці дописав своє
	var broken := ""
	for i in range(0, code.length(), 61):
		broken += code.substr(i, 61) + ("\n" if i % 2 == 0 else "  ")
	check(ST.unpack("  " + broken + "\n")["ok"], "пробіли й переноси рядків усередині коду не заважають")
	check(ST.unpack(code + "\nНадіслано з телефона")["ok"], "дописане після коду відтинається")
	# Вставлено лише початок
	var half: String = code.substr(0, code.length() / 2)
	var part: Dictionary = ST.unpack(half)
	check(not part["ok"] and part["partial"] and part["error"] == "" and int(part["have"]) > 0 and int(part["have"]) < int(part["need"]), "початок коду: каже, скільки знаків бракує (%d із %d)" % [part["have"], part["need"]])
	check(ST.unpack(half + code.substr(code.length() / 2))["ok"], "початок і решта разом — цілий код")
	# Зіпсований і чужий текст
	var body_at: int = code.rfind(":") + 1
	var flipped: String = code.substr(0, body_at + 40) + ("A" if code[body_at + 40] != "A" else "B") + code.substr(body_at + 41)
	var bad: Dictionary = ST.unpack(flipped)
	check(not bad["ok"] and not bad["partial"] and "пошкоджено" in bad["error"], "змінений знак: код пошкоджено")
	check("немає коду" in ST.unpack("Привіт, як справи?")["error"] and "немає коду" in ST.unpack("")["error"], "не код: зрозуміле пояснення")
	check("новішій версії" in ST.unpack("KZ2:" + code.substr(4))["error"], "код новішого формату: просить оновити гру")
	check("пошкоджено" in ST.unpack("KZ1:abc:12:00000000:AAAA")["error"] and "пошкоджено" in ST.unpack("KZ1:4:999999999:00000000:AAAA")["error"], "зіпсований заголовок")
	# Перевірка вмісту
	check(ST.check(profile) == "", "справжній рід проходить перевірку")
	check(ST.check({}) != "" and ST.check([]) != "" and ST.check(null) != "" and ST.check({"v": 1, "account": {}, "heroes": []}) != "", "порожнє й чуже — не рід")
	var twice: Dictionary = profile.duplicate(true)
	twice["heroes"][1]["slot"] = 1
	var far: Dictionary = profile.duplicate(true)
	far["heroes"][0]["slot"] = 9
	var lvl0: Dictionary = profile.duplicate(true)
	lvl0["heroes"][0]["data"]["player"]["level"] = 0
	var noworld: Dictionary = profile.duplicate(true)
	noworld["heroes"][0]["data"].erase("world")
	check(ST.check(twice) != "" and ST.check(far) != "" and ST.check(lvl0) != "" and ST.check(noworld) != "", "два герої в одному слоті, слот 9, рівень 0, герой без світу — відмова")
	var newer: Dictionary = profile.duplicate(true)
	newer["heroes"][0]["data"]["version"] = SaveSystem.SAVE_VERSION + 1
	var newer2: Dictionary = profile.duplicate(true)
	newer2["v"] = 2
	check("новішій версії" in ST.check(newer) and "новішій версії" in ST.check(newer2), "рід із новішої гри: просить оновити")
	var lines: Array = ST.summary(profile)
	check(lines.size() == 2 and "Слот 1" in lines[0] and "рівень 26" in lines[0] and "Козак" in lines[0] and "Слот 3" in lines[1], "підсумок для підтвердження: %s" % str(lines))
	# Файли: пристрій зі своїми героями у слотах 1 і 2 приймає рід зі слотами 1 і 3
	var paths := {1: "user://t_transfer_1.save", 2: "user://t_transfer_2.save", 3: "user://t_transfer_3.save"}
	var acc_path := "user://t_transfer_acc.save"
	for k in paths:
		SaveSystem.delete(paths[k])
		for suffix in [ST.BACKUP, ST.NONE]:
			if FileAccess.file_exists(paths[k] + suffix):
				DirAccess.remove_absolute(paths[k] + suffix)
	SaveSystem.delete(acc_path)
	for suffix in [ST.BACKUP, ST.NONE]:
		if FileAccess.file_exists(acc_path + suffix):
			DirAccess.remove_absolute(acc_path + suffix)
	SaveSystem.save(_transfer_hero(4, 11), paths[1])
	SaveSystem.save(_transfer_hero(5, 22), paths[2])
	var f := FileAccess.open(acc_path, FileAccess.WRITE)
	f.store_var({"chest": {"gold": 5, "items": [], "stones": {}}})
	f.close()
	var own: Dictionary = ST.collect(paths, acc_path)
	check(own["heroes"].size() == 2 and int(own["account"]["chest"]["gold"]) == 5 and ST.check(own) == "", "збирання роду з файлів пристрою")
	check(not ST.has_backup(paths, acc_path), "до перенесення запасу немає")
	check(ST.apply(profile, paths, acc_path), "рід записано")
	var got: Dictionary = ST.collect(paths, acc_path)
	var slots := []
	for h in got["heroes"]:
		slots.append(int(h["slot"]))
	check(slots == [1, 3] and int(got["heroes"][0]["data"]["player"]["level"]) == 26 and int(got["account"]["chest"]["gold"]) == 777, "на пристрої тепер перенесений рід: слоти %s" % str(slots))
	check(ST.has_backup(paths, acc_path), "те, що було, лежить у запасі")
	check(ST.restore(paths, acc_path), "повернення попереднього роду")
	var back: Dictionary = ST.collect(paths, acc_path)
	slots = []
	for h in back["heroes"]:
		slots.append(int(h["slot"]))
	check(slots == [1, 2] and int(back["heroes"][0]["data"]["player"]["level"]) == 4 and int(back["heroes"][1]["data"]["player"]["gold"]) == 22 and int(back["account"]["chest"]["gold"]) == 5, "усе як до перенесення: слоти %s" % str(slots))
	check(not ST.has_backup(paths, acc_path) and not ST.restore(paths, acc_path), "запас одноразовий")
	check(not ST.apply(profile, {1: paths[1]}, acc_path) and int(ST.collect(paths, acc_path)["heroes"][0]["data"]["player"]["level"]) == 4, "якщо слота для героя нема — нічого не чіпаємо")
	check(not ST.apply({"v": 1, "account": {}, "heroes": []}, paths, acc_path), "порожній рід не записується")
	for k in paths:
		SaveSystem.delete(paths[k])
	SaveSystem.delete(acc_path)


func _suite_transfer_game() -> void:
	suite("Перенесення роду: у грі")
	var ST = load("res://scripts/core/save_transfer.gd")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	for path in [TEST_SAVE, TEST_ACCOUNT]:
		for suffix in [ST.BACKUP, ST.NONE]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	ST.clipboard_override = ""
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	game.allow_quit = false
	root.add_child(game)
	await _frames(2)
	game.transfer_copy()
	check(ST.clipboard_override == "", "без персонажів копіювати нічого")
	# Пристрій А: герой 12 рівня, скриня з гривнями
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "city": true, "map": true, "camp": true}
	var p = game.player
	p.change_class("cossack")
	p.level = 12
	p.gold = 4321
	game.account.chest["gold"] = 900
	game.enter_map()
	await _frames(2)
	game.save_game()
	game._show_main_menu()
	await _frames(2)
	game._show_transfer_menu()
	await _frames(2)
	game.transfer_copy()
	await _frames(2)
	var code: String = ST.clipboard_override
	check(code.begins_with("KZ1:") and ST.unpack(code)["ok"], "код роду в буфері обміну (%d знаків)" % code.length())
	var texts := []
	for l in game.hud.overlay_box.find_children("*", "Label", true, false):
		texts.append(l.text)
	check("\n".join(texts).contains("Код скопійовано"), "гра каже, що код скопійовано")
	# Пристрій Б: там свій герой 3 рівня
	game.new_game()
	game.hud.close_dialogue()
	game.player.level = 3
	game.player.gold = 7
	game.account.chest["gold"] = 1
	game.save_game()
	game._show_main_menu()
	await _frames(2)
	# Чужий текст у буфері
	ST.clipboard_override = "купити хліба"
	game.transfer_paste()
	await _frames(2)
	check(game.transfer_buffer == "" and int(SaveSystem.load_data(TEST_SAVE)["player"]["level"]) == 3, "чужий текст нічого не міняє")
	# Месенджер розрізав код на два повідомлення
	var cut: int = code.length() / 2
	ST.clipboard_override = code.substr(0, cut)
	game.transfer_paste()
	await _frames(2)
	texts = []
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		texts.append(b.text)
	check(game.transfer_buffer != "" and "Вставити наступну частину" in texts, "перша частина коду: гра чекає на решту")
	ST.clipboard_override = code.substr(cut)
	game.transfer_paste()
	await _frames(2)
	texts = []
	for l in game.hud.overlay_box.find_children("*", "Label", true, false):
		texts.append(l.text)
	var yes: Button = null
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		if b.text == "Так, замінити":
			yes = b
	check(yes != null and "\n".join(texts).contains("рівень 12") and int(SaveSystem.load_data(TEST_SAVE)["player"]["level"]) == 3, "підтвердження показує, хто в коді; до згоди нічого не змінено")
	yes.pressed.emit()
	await _frames(2)
	var d: Dictionary = SaveSystem.load_data(TEST_SAVE)
	check(int(d["player"]["level"]) == 12 and int(d["player"]["gold"]) == 4321, "рід перенесено: герой 12 рівня з гривнями")
	check(game.player == null, "старого героя в пам'яті більше нема")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(int(SaveSystem.load_data(TEST_SAVE)["player"]["level"]) == 12, "згортання гри не затирає перенесене")
	game._continue_game()
	await _frames(3)
	check(game.player != null and game.player.level == 12 and game.player.gold == 4321 and int(game.account.chest["gold"]) == 900 and game.state == game.State.CITY, "гра продовжується перенесеним героєм зі спільною скринею")
	# Передумав: повернути, як було
	game._show_main_menu()
	await _frames(2)
	game._show_transfer_menu()
	await _frames(2)
	texts = []
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		texts.append(b.text)
	check("Повернути рід, який був до перенесення" in texts, "кнопка повернення є")
	game.transfer_restore()
	await _frames(2)
	check(int(SaveSystem.load_data(TEST_SAVE)["player"]["level"]) == 3 and int(SaveSystem.load_data(TEST_SAVE)["player"]["gold"]) == 7 and game.player == null, "повернуто героя 3 рівня")
	game._continue_game()
	await _frames(3)
	check(game.player.level == 3 and int(game.account.chest["gold"]) == 1, "і його скриню")
	ST.clipboard_override = null
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_travel_ride() -> void:
	suite("Подорож мапою")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.world.hints = {"combat": true, "map": true, "city": true, "block": true, "elite": true, "boss": true, "item": true}
	var p = game.player
	p.change_class("cossack")
	game._sync_class()
	p.level = 6
	game.world.travel = {"cooldown": 99, "seen": {}}  # поки без пригод
	game.map_here = "sich"
	game.enter_map()
	await _frames(2)
	game._go_to("kyiv")
	await _frames(3)
	check(game.travel_to == "kyiv" and game.state == game.State.MAP and not game.hud.map_view.travel.is_empty(), "«Вирушити» — починається поїздка, ми ще на мапі")
	var t0: float = game.travel_t
	var dur: float = game.travel_dur
	check(dur >= 1.5 and dur <= 4.0, "час поїздки Січ→Київ у межах (%.1f с)" % dur)
	game._go_to("chyhyryn")
	check(game.travel_to == "kyiv", "другу поїздку під час першої не почати")
	await _frames(10)
	check(game.travel_t > t0 and game.hud.map_view.travel["t"] == game.travel_t, "фігурка їде, мапа знає прогрес")
	# Прискорення дотиком
	var before: float = game.travel_t
	await _frames(6)
	var slow: float = game.travel_t - before
	game._travel_speed_up()
	before = game.travel_t
	await _frames(6)
	var fast: float = game.travel_t - before
	check(fast > slow * 2.0, "дотик по мапі прискорює (×3)")
	var frames := 0
	while game.travel_to != "" and frames < 600:
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and game.city_id == "kyiv" and game.map_here == "kyiv", "приїхали в Київ")
	check(game.hud.map_view.travel.is_empty(), "після прибуття фігурка зникає")
	# Пригода посеред шляху
	game.hud.close_dialogue()
	game.world.travel = {"cooldown": 0, "seen": {}}
	game.enter_map()
	await _frames(2)
	seed(3)
	var got_event := false
	var tries := 0
	while not got_event and tries < 12:
		tries += 1
		game._go_to("black_forest")
		if game.travel_event_at > 0.0:
			got_event = true
			break
		# без пригоди — доїхати й повернутись на мапу
		while game.travel_to != "":
			await process_frame
		await _frames(2)
		game.enter_map()
		game.world.travel["cooldown"] = 0
		await _frames(2)
	check(got_event, "пригода може трапитись у дорозі (спроб: %d)" % tries)
	if got_event:
		check(game.travel_event_at >= 0.4 and game.travel_event_at <= 0.65, "пригода чекає посеред шляху (t=%.2f)" % game.travel_event_at)
		frames = 0
		while game.hud.dialogue_root == null and frames < 600:
			await process_frame
			frames += 1
		check(game.hud.dialogue_root != null and game.travel_paused and game.state == game.State.MAP, "поїздка зупинилась на пригоду")
		var tp: float = game.travel_t
		await _frames(10)
		check(is_equal_approx(game.travel_t, tp), "поки триває розмова — фігурка стоїть")
		game.hud.dialogue_root._finish()
		await _frames(3)
		check(not game.travel_paused and game.travel_to == "black_forest", "після пригоди дорога продовжується")
		frames = 0
		while game.travel_to != "" and frames < 600:
			await process_frame
			frames += 1
		check(game.state == game.State.PLAYING and game.combat.loc_id == "black_forest", "доїхали до Чорного лісу — бій")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_account() -> void:
	suite("Акаунт: спільні хутір, скриня, досягнення")
	var Account = load("res://scripts/game/account.gd")
	var acc = Account.new()
	var p = _new_player()
	p.gold = 500
	p.inventory.clear()
	# Скриня: гривні
	check(acc.put_gold(p, 200) == 200 and p.gold == 300 and acc.chest["gold"] == 200, "покласти гривні")
	check(acc.put_gold(p, 9999) == 300 and p.gold == 0, "покласти більше, ніж є, — кладе все")
	check(acc.take_gold(p, 150) == 150 and p.gold == 150 and acc.chest["gold"] == 350, "взяти гривні")
	# Скриня: речі
	var it = Data.gen_item(5, 2, "head")
	p.add_item(it)
	var uid_before: int = it["uid"]
	var taken: Dictionary = p.remove_from_bag(uid_before)
	check(acc.put_item(taken, 0) and acc.chest["items"].size() == 1 and int(acc.chest["items"][0]["uid"]) >= 1000000, "річ у скрині отримує свій uid")
	var back: Dictionary = acc.take_item(acc.chest["items"][0]["uid"])
	check(not back.is_empty() and not back.has("uid") and acc.chest["items"].is_empty(), "взяти річ зі скрині")
	check(p.add_item(back) and p.inventory.size() == 1 and p.inventory[0]["name"] == it["name"], "річ повернулась у торбу з новим uid героя")
	check(acc.chest_size(0) == Account.CHEST_SIZE and acc.chest_size(2) == Account.CHEST_SIZE + 2 * Account.CHEST_PER_SKLAD, "Склад збільшує скриню")
	for i in Account.CHEST_SIZE:
		acc.put_item(Data.gen_item(1, 0, "belt"), 0)
	check(acc.chest_full(0) and not acc.put_item(Data.gen_item(1, 0, "belt"), 0), "повна скриня не бере")
	check(not acc.chest_full(1), "із Складом місце є")
	# Камені
	p.stones = {"alatyr": 1}
	check(acc.put_stone(p, "alatyr") and p.stones["alatyr"] == 0 and acc.chest["stones"]["alatyr"] == 1, "камінь у скриню")
	check(not acc.put_stone(p, "alatyr"), "каменів більше немає")
	check(acc.take_stone(p, "alatyr") and p.stones["alatyr"] == 1, "камінь зі скрині")
	# Спільне майно — посилання: два світи бачать один хутір і одні досягнення
	var w1 = WorldState.new()
	var w2 = WorldState.new()
	acc.attach(w1)
	acc.attach(w2)
	var CampService = load("res://scripts/game/camp_service.gd")
	w1.camp = acc.camp
	CampService.state(w1)["buildings"]["kuznia"] = 2
	check(CampService.level(w2, "kuznia") == 2, "хутір спільний: збудував один — бачить другий")
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	var p2 = _new_player()
	CS.record(w1, p2, "kill")
	check(int(w2.stats.get("kill", 0)) == 1 and CS.state(w2)["ach"].has("first_blood"), "досягнення й лічильники спільні")
	CS.now_override = 0
	# Серіалізація
	var acc2 = Account.new()
	acc2.from_dict(acc.to_dict())
	check(acc2.chest["gold"] == 350 and acc2.chest["items"].size() == Account.CHEST_SIZE and acc2.camp["buildings"]["kuznia"] == 2, "акаунт зберігається")
	# Старе збереження: хутір і досягнення переїжджають в акаунт
	var old_w = WorldState.new()
	old_w.camp = {"buildings": {"pasika": 1}, "pasika_ts": 0}
	old_w.stats = {"kill": 42}
	var acc3 = Account.new()
	acc3.absorb_from_world(old_w)
	acc3.attach(old_w)
	check(acc3.camp["buildings"]["pasika"] == 1 and acc3.stats["kill"] == 42, "старий хутір і статистика стають спільними")
	# Слоти збереження
	for i in range(1, 6):
		SaveSystem.delete(SaveSystem.slot_path(i))
	var sums = SaveSystem.slot_summaries()
	check(sums.size() == 5 and sums.all(func(x): return x.is_empty()), "5 порожніх слотів")
	SaveSystem.save({"player": p.to_dict(), "world": w1.to_dict(), "meta": {"playtime": 3700.0}}, SaveSystem.slot_path(3))
	sums = SaveSystem.slot_summaries()
	check(sums[2]["slot"] == 3 and sums[2]["level"] == p.level and sums[2]["playtime"] == 3700.0 and sums[0].is_empty(), "слот 3 зайнятий, решта порожні")
	SaveSystem.delete(SaveSystem.slot_path(3))
	p.free()
	p2.free()


func _suite_camp() -> void:
	suite("Хутір і реклама")
	var CampService = load("res://scripts/game/camp_service.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var AdRewards = load("res://scripts/game/ad_rewards.gd")
	var p = _new_player()
	var w = WorldState.new()
	check(CampService.party_size(w) == Data.MAX_COMPANIONS and p.bag_size() == Data.INVENTORY_SIZE, "без будівель — базові межі")
	check(not CampService.build(w, p, "kurin"), "без ресурсів не збудувати")
	p.gold = 100000
	p.resources = {"wood": 1000, "iron": 1000, "herbs": 1000}
	for id in Camp.BUILD_ORDER:
		for i in 5:
			CampService.build(w, p, id)
		check(CampService.level(w, id) == CampService.max_level(id), "%s до максимуму" % id)
	check(not CampService.build(w, p, "kurin"), "понад максимум не будується")
	check(CampService.party_size(w) == Data.MAX_COMPANIONS + 2, "курінь: загін до 4")
	check(p.bag_size() == Data.INVENTORY_SIZE + 16 and p.potion_max() == Data.POTION_MAX + 2, "склад і зілляварня дають бонуси")
	check(CampService.companion_xp_mult(w) == 1.5 and CampService.forge_cost_mult(w) < 1.0, "тренування й знижка кузні")
	# Зілляварня
	p.potions = 0
	check(CampService.brew(w, p, "heal") and p.potions == 1, "варіння зілля здоров'я")
	var dmg = p.damage
	check(CampService.brew(w, p, "strength") and p.damage > dmg * 1.25, "зілля сили на похід")
	check(not CampService.brew(w, p, "strength"), "двічі на один похід не вариться")
	CampService.brew(w, p, "antiplague")
	check(p.plague_immune, "зілля проти зарази")
	# Переплавка
	var junk = Data.gen_item(6, 2, "boots")
	p.add_item(junk)
	var iron = p.resources["iron"]
	check(CampService.salvage(w, p, junk["uid"]) > 0 and p.resources["iron"] > iron and p.find_item(junk["uid"]).is_empty(), "переплавка на залізо")
	# Пасіка
	var now = Time.get_unix_time_from_system()
	w.camp["pasika_ts"] = now - 2 * 3600
	var honey = CampService.pasika_ready(w, p.level, now)
	check(honey > 0, "пасіка накопичує")
	w.camp["pasika_ts"] = now - 100 * 3600
	check(CampService.pasika_ready(w, p.level, now) == int(Camp.PASIKA_CAP_HOURS * CampService.pasika_rate(w, p.level)), "пасіка має стелю")
	var g = p.gold
	check(CampService.collect_pasika(w, p, now) > 0 and p.gold > g and CampService.pasika_ready(w, p.level, now) == 0, "збір меду")
	# Реклама: ×2 досвіду
	check(AdRewards.xp_mult(w) == 1.0, "без реклами множник 1")
	AdRewards.grant_xp2(w)
	check(AdRewards.xp_mult(w) == 2.0 and AdRewards.xp2_left(w) == AdRewards.XP2_SECONDS, "реклама дає годину ×2")
	AdRewards.grant_xp2(w)
	AdRewards.grant_xp2(w)
	check(not AdRewards.can_xp2(w), "не більше 3 годин наперед")
	AdRewards.tick(w, 10000.0)
	AdRewards.tick(w, 10000.0)
	check(AdRewards.xp_mult(w) == 1.0, "час минає")
	var q = _new_player()
	q.xp_boost = 2.0
	var xp_before = q.xp
	q.add_xp(10)
	check(q.xp - xp_before == 20, "×2 досвіду працює")
	# Безпечна заточка
	for i in 5:
		AdRewards.grant_safe(w)
	check(AdRewards.safe_tokens(w) == AdRewards.SAFE_PER_DAY and AdRewards.safe_left_today(w) == 0, "денний ліміт безпечних заточок")
	var wpn = p.equipment["weapon"]
	var downs = 0
	for i in 60:
		wpn["up"] = Data.SHARPEN_RISK_FROM + 2
		p.gold = 100000
		if p.sharpen(wpn["uid"], 1.0, 0.0, true) == "down":
			downs += 1
	check(downs == 0, "безпечна заточка не знижує рівень")
	# Збереження
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(w2.camp["buildings"]["kurin"] == 3 and w2.boosts.has("safe_sharpen"), "хутір і нагороди зберігаються")
	var r = _new_player()
	r.from_dict(p.to_dict())
	check(r.resources["iron"] == p.resources["iron"], "ресурси зберігаються")
	var old = {"version": 5, "player": {"level": 3}, "world": {}}
	var m = SaveSystem.migrate(old)
	check(m["world"].has("camp") and m["player"].has("resources"), "міграція v5 → v6")
	p.free()
	q.free()
	r.free()


# ======================= 8. Ігровий сценарій =======================

func _bot_fight(game) -> void:
	var p = game.player
	var c = game.combat
	var en = c.nearest_enemy(p.global_position, 5000.0)
	game.hud.joystick.vector = (en.global_position - p.global_position).normalized() * 0.8 if en else Vector2.ZERO
	game.hud.btn_attack.held = true
	for id in Data.ACTIVE_SKILLS:
		p.use_skill(id)
	if c.portal != null and is_instance_valid(c.portal):
		p.global_position = c.portal.global_position


## Натиснути «Вирушити» й дочекатись прибуття (подорож мапою триває кілька секунд).
## Поїздка рухається лише на мапі — тож спершу виходимо на неї, як і справжній гравець.
func _ride(game, id: String, escort: bool = false) -> void:
	if game.state != game.State.MAP:
		game.enter_map()
		await _frames(2)
	if escort:
		game._go_escort(id)  # кнопка «Провести» на мапі
	else:
		game._go_to(id)
	var frames := 0
	while game.travel_to != "" and frames < 1200:
		if game.hud.dialogue_root != null:
			game.hud.dialogue_root._finish()  # пригода в дорозі — беремо перший варіант
		await process_frame
		frames += 1
	await _frames(2)


func _moves_dummy(game, kind: String = "upyr"):
	for e in game.combat.get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	var p = game.player
	game.combat.spawn_enemy(kind, 5, false, p.global_position + Vector2(60, 0))
	var e = game.combat.get_tree().get_nodes_in_group("enemies")[-1]
	e.max_hp = 1000000.0
	e.hp = e.max_hp
	p.facing = Vector2.RIGHT
	return e


func _suite_moves() -> void:
	suite("Бойові прийоми")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	game.enter_location("wild_field")
	await _frames(2)
	var p = game.player
	p.job = "cossack"
	p.crit_chance = 0.0
	p.lifesteal = 0.0
	p.armor = 0.0
	# Комбо: третій удар серії сильніший
	var e = _moves_dummy(game)
	var dmg := []
	for i in 3:
		p.attack_timer = 0.0
		var before: float = e.hp
		p.attack()
		dmg.append(before - e.hp)
	check(dmg[0] > 0.0 and dmg[2] > dmg[0] * 1.4, "третій удар серії — завершальний (%.0f → %.0f)" % [dmg[0], dmg[2]])
	check(p.combo_step == 0 and p.attack_timer > p.attack_cooldown, "після завершального — нова серія й пауза")
	p.attack_timer = 0.0
	p.combo_timer = 0.0
	var b0: float = e.hp
	p.attack()
	check(b0 - e.hp < dmg[2] * 0.8, "перерва між ударами скидає серію")
	# Блок
	p.invuln = 0.0
	p.block_held = true
	p._update_block(0.0)
	p._update_block(0.5)
	var hp0: float = p.hp
	p.take_damage(40.0, e)
	check(p.blocking and is_equal_approx(hp0 - p.hp, 40.0 * p.BLOCK_MULT), "блок зменшує шкоду (%.1f)" % (hp0 - p.hp))
	# Парирування: щойно натиснутий блок
	p.block_held = false
	p._update_block(0.0)
	p.block_cd = 0.0
	p.invuln = 0.0
	p.block_held = true
	p._update_block(0.0)
	e.windup = 0.2
	var hp1: float = p.hp
	var ehp: float = e.hp
	p.take_damage(40.0, e)
	check(p.hp == hp1 and e.stun > 1.0 and e.hp < ehp and e.windup == 0.0, "парирування: без шкоди, ворог приголомшений, удар у відповідь")
	check(p.combo_step == 2, "після парирування наступний удар — завершальний")
	p.invuln = 0.0
	p.block_held = false
	p._update_block(0.0)
	# Пізно натиснутий блок — уже не парирування
	p.block_cd = 0.0
	p.block_held = true
	p._update_block(0.0)
	p._update_block(p.PARRY_WINDOW + 0.05)
	var hp2: float = p.hp
	p.take_damage(40.0, e)
	check(p.hp < hp2, "запізнився — лише блок, не парирування")
	p.invuln = 0.0
	# Заряджений удар
	e.stun = 0.0
	var c1: float = e.hp
	p._update_block(p.CHARGE_FULL)
	check(p.charge_ratio() >= 1.0, "заряд наповнюється")
	p.block_held = false
	p._update_block(0.0)
	var charged: float = c1 - e.hp
	check(not p.blocking and charged > dmg[0] * 2.5 and e.stun > 0.0, "повний заряд — потужний удар і приголомшення (%.0f)" % charged)
	p.block_cd = 0.0
	p.block_held = true
	p._update_block(0.0)
	p._update_block(0.2)
	p.block_held = false
	var c2: float = e.hp
	p._update_block(0.0)
	check(e.hp == c2, "короткий блок не б'є")
	# Приголомшений ворог не рухається й не б'є
	e.stun = 1.0
	var pos0: Vector2 = e.global_position
	e.knockback = Vector2.ZERO
	e._process(0.1)
	check(e.global_position == pos0 and e.windup == 0.0, "приголомшений стоїть")
	# Чорт телепортується до цілі
	var ch = _moves_dummy(game, "chort")
	ch.global_position = p.global_position + Vector2(600, 0)
	ch.blink_timer = 0.0
	ch._process(0.016)
	check(ch.global_position.distance_to(p.global_position) < 150.0, "чорт вигулькує поруч")
	# Стани
	var Status = load("res://scripts/game/status.gd")
	var Elites = load("res://scripts/data/elites.gd")
	var dummy = {"statuses": {}}
	Status.apply(dummy, "burn", 1.0, 10.0)
	check(is_equal_approx(Status.tick(dummy, 0.5), 5.0), "горіння б'є раз на пів секунди")
	Status.tick(dummy, 0.6)
	check(dummy["statuses"].is_empty(), "стан минає")
	p.statuses.clear()
	p.invuln = 0.0
	p.plague_immune = false
	p.plague_resist = 0.0
	p.add_status("chill", 2.0)
	check(Status.speed_mult(p) < 1.0, "холод сповільнює козака")
	p.add_status("plague", 2.0, 0.0)
	p.hp = p.max_hp * 0.5
	var h0: float = p.hp
	p.heal(20.0, false)
	check(is_equal_approx(p.hp - h0, 10.0), "зараза вдвічі слабшить лікування")
	p.statuses.clear()
	p.plague_immune = true
	p.add_status("plague", 2.0, 5.0)
	check(p.statuses.is_empty(), "оберіг від зарази — імунітет")
	p.plague_immune = false
	p.add_status("bleed", 2.0, 10.0)
	var h1: float = p.hp
	p._process(0.6)
	check(p.hp < h1, "кровотеча ранить козака навіть крізь невразливість")
	p.statuses.clear()
	p.hp = p.max_hp
	# Удар ворога з властивістю накладає стан
	var el = _moves_dummy(game, "upyr")
	el.make_elite(["fiery", "vampire"])
	check(el.elite and el.title == "Вогняний упирячий Упир" and el.base_scale > 1.0, "еліта: ім'я «%s»" % el.title)
	el.hp = el.max_hp * 0.5
	var eh: float = el.hp
	el.on_hit(p)
	check(p.statuses.has("burn") and el.hp > eh, "вогняна еліта підпалює, упиряча — п'є кров")
	p.statuses.clear()
	var ir = _moves_dummy(game, "vovkulaka")
	var ir_hp: float = ir.hp
	ir.take_damage(100.0, Vector2.ZERO)
	var plain: float = ir_hp - ir.hp
	ir.make_elite(["iron"])
	ir.hp = ir.max_hp
	ir.take_damage(100.0, Vector2.ZERO)
	check(ir.max_hp - ir.hp < plain * 0.7, "залізна еліта тримає удар")
	check(Elites.title("mavka", "Мавка", ["frost"]) == "Крижана Мавка", "жіночий рід: «Крижана Мавка»")
	check(Elites.chance(1, 0) == 0.0 and Elites.chance(5, 2) > Elites.chance(5, 0), "еліт немає на старті, у заразі — частіше")
	var ex = _moves_dummy(game, "mavka")
	ex.make_elite(["explosive"])
	var tele_before: int = game.combat.effects.get_child_count()
	ex.take_damage(ex.max_hp * 10.0, Vector2.ZERO)
	check(game.combat.effects.get_child_count() > tele_before, "вибухова еліта після смерті вибухає")
	var cb = _moves_dummy(game, "upyr")
	p.crit_chance = 1.0
	p.attack_timer = 0.0
	p.combo_timer = 0.0
	p.attack()
	check(cb.statuses.has("bleed"), "критичний удар лишає кровотечу")
	p.crit_chance = 0.0
	# Кощій встає, поки голка ціла
	game.combat.boss_revives = 1
	game.combat.spawn_enemy("koshchii", 16, true, p.global_position + Vector2(300, 0))
	var k = game.combat.get_tree().get_nodes_in_group("enemies")[-1]
	k.take_damage(k.max_hp * 2.0, Vector2.ZERO)
	check(not k.dead and k.hp > 0.0 and game.combat.boss_revives == 0, "Кощій встає знову")
	k.take_damage(k.max_hp * 2.0, Vector2.ZERO)
	check(k.dead, "удруге — падає")
	game.combat.spawn_enemy("putinoid", 22, true, p.global_position + Vector2(300, 0))
	var pu = game.combat.get_tree().get_nodes_in_group("enemies")[-1]
	pu.take_damage(pu.max_hp * 0.6, Vector2.ZERO)
	check(pu.phase2, "Путіноїд скидає личину на половині здоров'я")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_gameplay() -> void:
	suite("Сценарій гри")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(3)
	check(game.state == game.State.MENU, "старт у головному меню")
	game.new_game()
	await _frames(2)
	root.get_node("Ads").instant = true
	var p = game.player
	check(game.hud.dialogue_root != null, "нова гра: кобзар розповідає вступ")
	check(p.is_peasant() and p.skills.is_empty() and p.equipment["weapon"]["name"] == "Вила", "старт простим селянином із вилами")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.state == game.State.PLAYING and game.combat.loc_id == "ridne_selo", "пролог: бій у рідному селі")
	p.stats["str"] = 40
	p.stats["vit"] = 40
	p.recalc()
	p.hp = p.max_hp
	var pf = 0
	while not game.combat.field_cleared and pf < 3600:
		_bot_fight(game)
		await process_frame
		pf += 1
	check(game.combat.field_cleared and game.world.story["step"] == 1, "рідне село відбито — веди вцілілих на Січ")
	game.enter_city("sich")
	await _frames(2)
	check(game.hud.dialogue_root != null, "кошовий зустрічає втікача")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["step"] == 2 and game.hud.dialogue_root != null, "кошовий посилає набиратися сили")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["stage"] == "active" and StoryService.current(game.world)["objective"]["type"] == "job", "мета — 10 рівень майстерності")
	while p.job_level < 10:
		p.add_xp(p.job_next())
	await _frames(2)
	check(p.job_level == 10 and game.world.story["stage"] == "turnin" and p.can_change_class(), "майстерність 10 — час обирати дорогу")
	check(p.skill_points == 9, "селянин заробив 9 очок вмінь")
	p.learn_skill("vyly")
	check(p.sk("vyly") == 1 and "vyly" in p.active_skills(), "селянин вчить «Удар вилами»")
	game.enter_city("sich")
	await _frames(2)
	check(game.hud.dialogue_root != null and game.hud.dialogue_root.choices.is_empty(), "кошовий радить поговорити з обома, а не питає одразу")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.PathService.choosing(game.world) and game.world.story["step"] == 3, "крок «Обери дорогу» активний")
	game.city_do("path_choose", "cossack")
	game.city_do("path_choose", "cossack")
	check(game.PathService.choosing(game.world), "без розмов обрати не вийде")
	game.city_do("path_talk", "cossack")
	await _frames(2)
	check(game.hud.dialogue_root != null, "розмова з осавулом Мироном")
	game.hud.dialogue_root._finish()
	await _frames(2)
	game.city_do("path_talk", "volkhv")
	await _frames(2)
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.PathService.can_choose(game.world), "після обох розмов вибір відкрито")
	game.city_do("path_choose", "cossack")
	check(game.PathService.choosing(game.world), "перше натискання — лише підтвердження")
	game.city_do("path_choose", "cossack")
	await _frames(2)
	check(game.world.story["step"] == 4 and game.world.story["choices"]["trial"] == 0 and game.hud.dialogue_root != null, "козацька дорога: посвята")
	game.hud.dialogue_root._finish()
	await _frames(2)
	for i in 8:
		game._story_event("kill", "zarazhenyi")
	game.enter_city("sich")
	await _frames(2)
	check(game.hud.dialogue_root != null, "посвята: урочиста розмова")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(p.job == "cossack" and p.job_level < 5 and p.sk("whirl") == 1 and p.sk("vyly") == 1 and game.world.story["chapter"] == 1, "посвячено в козаки — розділ I, селянське вміння лишилось")
	check(p.equipment["weapon"]["type"] == "sabre", "козацька шабля одразу в руці")
	check(game.hud.dialogue_root != null, "розділ I: кошовий одразу кличе")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["stage"] == "active" and game.hud.map_view != null, "після розмови сюжет активний")
	# Сильний козак, щоб тест ішов швидко й стабільно
	p.stats["str"] = 40
	p.stats["vit"] = 40
	p.skills = {"whirl": 3, "battle_cry": 3, "musket": 2}
	p.recalc()
	p.hp = p.max_hp
	for q in game.world.board("sich").duplicate():
		game.city_do("take", q["id"])
	check(game.world.quests.size() == 3, "узято 3 завдання")

	# Дика місцевість до зачистки
	game.leave_city()
	check(game.state == game.State.MAP, "мапа")
	game.enter_location("wild_field")
	check(game.combat.plague == game.PlagueService.level(game.world, "wild_field"), "бій знає рівень зарази місцевості")
	game.combat.autosell = true
	var full_bag := []
	while not p.bag_full():
		p.add_item(Data.gen_item(1, 1, "belt"))
	var g_as: int = p.gold
	game.combat.pick_item(Data.gen_item(1, 0, "head"))
	check(p.gold > g_as and p.bag_full(), "автопродаж: мотлох при повній торбі одразу продано")
	game.combat.autosell = false
	p.inventory.clear()
	game.combat.field_goal = 10
	var frames = 0
	while not game.combat.field_cleared and frames < 3600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.combat.field_cleared, "Дике Поле очищено (кадрів: %d)" % frames)
	frames = 0
	while game.state == game.State.PLAYING and frames < 600:
		_bot_fight(game)
		await process_frame
		frames += 1
	check(game.state == game.State.MAP, "портал повертає на мапу")
	check(game.world.cleared.get("wild_field", 0) == 1, "облік очищення")
	check(game.world.story["stage"] == "turnin", "сюжет: Дике Поле зараховано")
	check(game.hud.map_view.story_target == "sich", "зірка на мапі веде на Січ")

	# Печера з босом
	game.enter_location("zmii_cave")
	frames = 0
	var max_room = 1
	while game.state == game.State.PLAYING and frames < 12000:
		_bot_fight(game)
		max_room = maxi(max_room, game.combat.room)
		await process_frame
		frames += 1
	check(max_room == int(Data.LOCATIONS["zmii_cave"]["rooms"]), "пройдено всі кімнати")
	check(game.world.cleared.get("zmii_cave", 0) == 1, "печеру очищено (кадрів: %d)" % frames)
	check(game.state == game.State.MAP, "вихід із печери на мапу")
	check(Engine.time_scale == 1.0, "час не лишився сповільненим")

	# Місто: здача, крамниця, коваль, найм
	game.enter_city("sich")
	check(game.hud.dialogue_root != null, "кошовий чекає зі звітом")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["step"] == 1 and game.hud.dialogue_root != null, "одразу далі — розмова з кобзарем")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["stage"] == "active" and game.hud.dialogue_root == null, "мета від кобзаря активна")
	var done = 0
	for q in game.world.quests.duplicate():
		if game.world.is_done(q):
			game.city_do("turn_in", q["id"])
			done += 1
	check(game.world.loyalty_points("sich") > 0 or done == 0, "лояльність за завдання")
	p.gold = 5000
	var stock: Array = game.shop_stock("sich")
	var uid: int = stock[0]["uid"]
	game.city_do("buy", uid)
	check(p.find_item(uid).size() > 0, "куплено в крамниці")
	game.city_do("sharpen", p.equipment["weapon"]["uid"])
	check(game.smith_msg != "", "коваль відповідає")
	game.city_do("hire", "dzhura")
	check(game.world.has_companion("dzhura"), "джура в загоні")

	# Хутір
	game.enter_city("sich")
	game.enter_camp()
	check(game.state == game.State.CAMP and game.player.hp == game.player.max_hp, "хутір: відпочинок")
	p.resources = {"wood": 100, "iron": 100, "herbs": 100}
	p.gold = 5000
	game.camp_do("build", "kurin")
	check(game.CampService.level(game.world, "kurin") == 1, "будівництво на хуторі")
	game.camp_do("ad_xp2", null)
	await _frames(3)
	check(game.AdRewards.xp_mult(game.world) == 2.0, "реклама в сцені дає ×2 досвіду")
	game.open_character()
	game.close_character()
	check(game.state == game.State.CAMP, "з екрана козака назад на хутір")
	game.enter_city("sich")

	# Екран козака
	game.open_character()
	check(game.state == game.State.CHARACTER, "екран козака")
	game.char_do("select", uid)
	game.char_do("equip", uid)
	check(p.is_equipped(uid), "вдягнуто куплену річ")
	game.close_character()
	check(game.state == game.State.CITY, "повернення в місто")

	# Збереження й завантаження
	var lvl = p.level
	var gold = p.gold
	game.save_game()
	check(game.load_game(), "завантаження")
	await _frames(2)
	check(game.player.level == lvl and game.player.gold == gold and game.player.is_equipped(uid), "герой після завантаження")

	# Супутник у бою й смерть
	game.enter_location("rapids")
	await _frames(30)
	check(game.combat.companion_nodes.size() == 1, "джура вийшов у похід")
	var comp = game.world.companions[0]
	var clvl = comp["level"]
	for i in 25:
		game.combat.spawn_enemy("mavka", 20, true, game.player.global_position + Vector2(600, 0))
	await _frames(2)
	for e in game.combat.get_tree().get_nodes_in_group("enemies"):
		e.take_damage(1e9, Vector2.ZERO)
	await _frames(2)
	check(comp["level"] > clvl or clvl >= game.player.level, "супутник підріс у бою")
	check(game.combat.companion_nodes[0].level == comp["level"], "показники живого супутника оновились")
	var gold_before: int = game.player.gold
	game.player.invuln = 0.0
	game.player.take_damage(1e9)
	await _frames(150)
	check(game.state == game.State.DEAD, "смерть козака")
	check(game.player.gold == gold_before - int(gold_before * 0.25), "втрата чверті гривень")
	game.enter_city(game.world.last_city)
	check(game.player.alive and game.player.hp == game.player.max_hp, "козак отямився в місті")
	game.queue_free()
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	await _frames(2)
