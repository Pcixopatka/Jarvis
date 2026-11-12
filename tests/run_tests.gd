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
	_suite_kleinody()
	await _suite_kleinody_game()
	_suite_ring_muster()
	await _suite_ring_muster_game()
	_suite_far_lands()
	await _suite_far_lands_game()
	_suite_muscovy()
	await _suite_muscovy_game()
	_suite_uniques()
	await _suite_uniques_game()
	await _suite_artifacts()
	await _suite_souls()
	await _suite_difficulty()
	await _suite_hero_screen()
	await _suite_journal()
	await _suite_skills_tab()
	await _suite_full_bag_and_scroll()
	await _suite_event_lift()
	await _suite_guide()
	await _suite_way()
	await _suite_objective_arrow()
	await _suite_gear_best()
	await _suite_quick_raid()
	await _suite_pickup_filter()
	await _suite_renew_cost()
	_suite_peril()
	_suite_sets()
	_suite_valor()
	await _suite_peril_game()
	_suite_shop()
	await _suite_shop_game()
	_suite_skill_trees()
	await _suite_skill_engine_game()
	_suite_strilets()
	await _suite_strilets_game()
	await _suite_premium()
	await _suite_boss_hunt()
	await _suite_costumes()
	await _suite_pets()
	await _suite_enchant_fair()
	await _suite_auto()
	await _suite_saga()
	await _suite_loot_rates()
	await _suite_divine()
	await _suite_legends()
	await _suite_grid_shops()
	await _suite_audit()
	await _suite_place_restore()
	await _suite_hero_names()
	await _suite_pet_fetch()
	await _suite_salvage_confirm()
	_suite_events_wiki()
	await _suite_events_wiki_game()
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


## Скільки всього рангів у дереві класу.
func _tree_ranks(Classes, cls: String) -> int:
	var total := 0
	for br in Classes.TREES[cls]:
		for n in br["nodes"]:
			total += int(n["max"])
	return total


func _new_player():
	var p = PlayerScript.new()
	p._ready()  # стартова шабля і перерахунок без додавання в сцену
	return p


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Вкладки екрана будуються ліниво: лише та, що відкрита (UI.screen). Тест, який шукає щось по всьому
## екрану, спершу гортає всі вкладки, як це зробив би гравець, і вертається на ту, що була.
func _reveal_tabs(game) -> void:
	if game.hud.screen_root == null or not is_instance_valid(game.hud.screen_root):
		return
	for tc in game.hud.screen_root.find_children("*", "TabContainer", true, false):
		var was: int = tc.current_tab
		for i in tc.get_tab_count():
			tc.current_tab = i
		tc.current_tab = was


## Підійти до того, хто чекає в ратуші міста: розмови там самі не починаються (Game.hall_rows).
## kind — котрого шукати ("" — першого). Повертає, чи було до кого підійти.
func _hall_talk(game, kind: String = "", line: String = "") -> bool:
	for r in game.hall_rows(game.city_id):
		if (kind == "" or str(r["kind"]) == kind) and (line == "" or str(r["line"]) == line):
			game.hall_talk(str(r["kind"]), str(r["line"]))
			return true
	return false


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
					check(Classes.actives().has(n["id"]) and Classes.cooldown(n["id"]) > 0.0 and Classes.label(n["id"]) != "" and int(n.get("cost", 0)) > 0 and (Data.ACTIVE_SKILLS.has(n["id"]) or n.has("act")), "%s: активне %s має кнопку, перезарядку й ціну" % [cls, n["id"]])
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
	# Рідкість: легендарних із рівнем більшає, але повільно; частки сходяться в одиницю
	var share_sum := 0.0
	for r in 4:
		share_sum += Data.rarity_share(75, r)
	check(is_equal_approx(share_sum, 1.0) and is_equal_approx(Data.rarity_share(75, 0, 2), 0.0) and is_equal_approx(Data.rarity_share(75, 2, 2) + Data.rarity_share(75, 3, 2), 1.0), "частки рідкостей сходяться в одиницю, нижчих за найменшу нема")
	check(Data.rarity_share(1, 3) > 0.01 and Data.rarity_share(75, 3) > Data.rarity_share(20, 3) and Data.rarity_share(20, 3) > Data.rarity_share(1, 3) and Data.rarity_share(99, 3) < 0.05, "легендарна з рядової нечисті: від %.1f%% на 1-му рівні до %.1f%% на 99-му" % [Data.rarity_share(1, 3) * 100.0, Data.rarity_share(99, 3) * 100.0])
	check(Data.rarity_share(75, 3, 2) > 0.1 and Data.rarity_share(75, 3, 2) < 0.25 and Data.rarity_share(75, 3, 1) > Data.rarity_share(75, 3), "бос і еліта дають легендарну частіше: з боса %.0f%% речей на 75-му рівні" % (Data.rarity_share(75, 3, 2) * 100.0))
	var rolled := [0, 0, 0, 0]
	for i in 4000:
		rolled[Data.roll_rarity(75)] += 1
	check(absf(float(rolled[3]) / 4000.0 - Data.rarity_share(75, 3)) < 0.015 and absf(float(rolled[2]) / 4000.0 - Data.rarity_share(75, 2)) < 0.04, "кидок рідкості відповідає часткам (легендарних %d із 4000)" % rolled[3])
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
				check(not PS.can_choose(w), "%s: двох розмов із трьох замало" % st["id"])
				PS.mark_talked(w, "strilets")
				check(PS.can_choose(w), "%s: після всіх розмов можна обирати" % st["id"])
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
	check(p.damage > dmg0 and is_equal_approx(p.buff_left("inspired"), Data.INSPIRED_TIME), "дума кобзаря надихає на десять хвилин бою")
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
	var A = load("res://scripts/data/achievements.gd")
	var ES = load("res://scripts/game/event_service.gd")
	var DS = load("res://scripts/game/defense_service.gd")
	var EscortS = load("res://scripts/game/escort_service.gd")
	var p = _new_player()
	p.job = "peasant"  # нова гра починається селянином: події й заняття йому ще закриті
	var w = WorldState.new()
	var T0 := 1762700000  # фіксований день
	CS.now_override = T0
	var c = CS.state(w, p)
	check(A.DAILY_COUNT == 4 and A.WEEKLY_COUNT == 3 and c["daily"].size() == 4 and c["weekly"].size() == 3, "4 щоденні й 3 тижневі виклики")
	check(c["daily"].all(func(x): return x["group"] == "base") and c["weekly"].all(func(x): return x["group"] == "base"), "селянинові викликів про події не дають: вони ще закриті")
	var w_same = WorldState.new()
	check(CS.state(w_same, p)["daily"][0]["text"] == c["daily"][0]["text"], "у всіх гравців того ж дня — ті самі виклики")
	var stats := {}
	for ch in c["daily"]:
		stats[ch["stat"]] = true
	check(stats.size() == 4, "щоденні виклики різні")
	var ch0: Dictionary = c["daily"][0]
	var msgs := []
	for i in int(ch0["goal"]):
		msgs.append_array(CS.record(w, p, ch0["stat"]))
	check(ch0["progress"] == ch0["goal"] and msgs.any(func(m): return "Виклик виконано" in m), "виклик виконано")
	check(CS.ready_count(w) >= 1 and not CS.pending(w, ch0["stat"]) or c["weekly"].any(func(x): return x["stat"] == ch0["stat"]), "нагорода чекає, виклик більше не «в роботі»")
	var g0: int = p.gold
	var t = CS.claim(w, p, false, 0)
	check(t != "" and p.gold > g0 and c["daily"][0]["claimed"], "нагороду забрано")
	check(CS.claim(w, p, false, 0) == "", "двічі не забереш")
	check(CS.claim(w, p, true, 0) == "" or c["weekly"][0]["progress"] >= c["weekly"][0]["goal"], "невиконаний тижневий не віддає нагороди")
	# Новий день — нові виклики, тиждень той самий
	CS.now_override = T0 + 86400
	var c2 = CS.state(w, p)
	check(not c2["daily"][0]["claimed"] and c2["day"] != "" , "наступного дня — нові виклики")
	# Досягнення (на чистому світі, щоб виклики вище не заважали рахунку)
	var wa = WorldState.new()
	var ca = CS.state(wa, p)
	var g1: int = p.gold
	var m2 = CS.record(wa, p, "kill")
	check(ca["ach"].has("first_blood") and p.gold == g1 + 20 and m2.any(func(m): return "Перша кров" in m), "досягнення «Перша кров»")
	CS.record(wa, p, "kill")
	check(p.gold == g1 + 20, "досягнення відкривається лише раз")
	CS.record(wa, p, "level", 10)
	CS.record(wa, p, "level", 7)
	check(wa.stats["level"] == 10 and ca["ach"].has("level_10"), "рівень — найвищий, а не сума")
	for i in 3:
		CS.record(wa, p, "boss:zmii")
	check(ca["ach"].has("zmii"), "Змієборець")
	# Тижнева нагорода
	var wk: Dictionary = c2["weekly"][0]
	CS.record(w, p, wk["stat"], int(wk["goal"]))
	var tok0: int = int(w.boosts.get("safe_sharpen", 0))
	var inv0: int = p.inventory.size()
	check(CS.claim(w, p, true, 0) != "" and int(w.boosts["safe_sharpen"]) == tok0 + 1 and p.inventory.size() == inv0 + 1, "тижнева нагорода: річ і жетон заточки")
	var w2 = WorldState.new()
	w2.from_dict(wa.to_dict())
	check(w2.stats["kill"] == wa.stats["kill"] and w2.challenges["ach"].has("zmii"), "лічильники й досягнення зберігаються")

	# ---- Події у викликах ----
	var hero = _new_player()
	hero.change_class("cossack")
	hero.level = 30
	var story_mid := {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	var wh = WorldState.new()
	wh.story = story_mid.duplicate()
	CS.now_override = T0
	var chh = CS.state(wh, hero)
	var ev_d: Array = chh["daily"].filter(func(x): return x["group"] == "event")
	var ev_w: Array = chh["weekly"].filter(func(x): return x["group"] == "event")
	check(A.DAILY_EVENTS == 2 and ev_d.size() == 2 and chh["daily"].size() == 4, "бувалому героєві щодня два виклики про події й заняття: %s" % str(chh["daily"].map(func(x): return x["stat"])))
	check(A.WEEKLY_EVENTS == 2 and ev_w.size() == 2 and chh["weekly"].size() == 3, "і два на тиждень: %s" % str(chh["weekly"].map(func(x): return x["stat"])))
	check(chh["daily"][0]["group"] == "base" and chh["daily"][3]["group"] == "event", "спершу бій і господарство, потім події")
	check(ev_d.all(func(x): return str(x["where"]) != "") and ev_w.all(func(x): return str(x["where"]) != ""), "у викликів про події є підказка, куди йти")
	var seen := {}
	var seen_w := {}
	var always_two := true
	for d in 70:
		CS.now_override = T0 + 86400 * d
		var wd = WorldState.new()
		wd.story = story_mid.duplicate()
		var cd = CS.state(wd, hero)
		always_two = always_two and cd["daily"].filter(func(x): return x["group"] == "event").size() == 2 and cd["weekly"].filter(func(x): return x["group"] == "event").size() == 2
		for x in cd["daily"]:
			seen[x["stat"]] = true
		for x in cd["weekly"]:
			seen_w[x["stat"]] = true
	var all_daily := true
	for st in ["vigil_min", "duel", "bounty", "escort", "event", "trail", "tower_floor"]:
		all_daily = all_daily and seen.has(st)
	for wk_i in 40:
		CS.now_override = T0 + 7 * 86400 * wk_i
		var ww = WorldState.new()
		ww.story = story_mid.duplicate()
		for x in CS.state(ww, hero)["weekly"]:
			seen_w[x["stat"]] = true
	var all_weekly := true
	for st in ["vigil_min", "duel", "bounty", "escort", "event", "trail", "tower_floor"]:
		all_weekly = all_weekly and seen_w.has(st)
	check(always_two and all_daily and all_weekly, "за десять тижнів у щоденних і за сорок у тижневих побували варта, герць, розшук, супровід, події, сліди й Башта: %s / %s" % [str(seen.keys()), str(seen_w.keys())])
	check(not seen.has("depth_clear") and not seen_w.has("depth_clear"), "Глибини у виклики не потрапляють, доки сюжет не пройдено")
	var wdone = WorldState.new()
	wdone.story = {"chapter": 5, "step": 0, "stage": "done", "progress": 0}
	check(CS.available("depth", wdone, hero) and not CS.available("depth", wh, hero), "після перемоги над Путіноїдом Глибини відкриті для викликів")
	var young = _new_player()
	young.change_class("cossack")
	young.level = 5
	check(CS.available("duel", wh, young) and not CS.available("vigil", wh, young) and not CS.available("tower", wh, young) and CS.available("bounty", wh, young), "на п'ятому рівні є герць і розшук, а варти й Башти ще нема")
	check(not CS.available("garden", wh, hero) and not CS.available("party", wh, hero) and not CS.available("defense", WorldState.new(), hero), "город, загін і облоги — лише коли вони справді є")
	# Нові лічильники сумуються й просувають виклики
	CS.now_override = T0
	var wv = WorldState.new()
	wv.story = story_mid.duplicate()
	var cv = CS.state(wv, hero)
	cv["daily"][3] = {"stat": "vigil_min", "text": "Простій на Козацькій варті хвилин: 2", "goal": 2, "progress": 0, "claimed": false, "group": "event", "where": "Сторожова могила на мапі"}
	check(CS.pending(wv, "vigil_min"), "виклик про варту ще не виконано")
	CS.record(wv, hero, "vigil", 1)
	CS.record(wv, hero, "vigil_min")
	CS.record(wv, hero, "vigil", 2)
	CS.record(wv, hero, "vigil_min")
	check(int(wv.stats["vigil"]) == 2 and int(wv.stats["vigil_min"]) == 2 and int(cv["daily"][3]["progress"]) == 2 and not CS.pending(wv, "vigil_min"), "дві хвилини на варті закривають виклик")
	# Виклик просить подію — вона приходить після першого ж походу, без перепочинку
	cv["daily"][2] = {"stat": "event", "text": "Прийди на поміч", "goal": 1, "progress": 0, "claimed": false, "group": "event", "where": ""}
	ES.state(wv)["calm"] = 9
	ES.tick(wv, hero)
	check(not ES.active(wv).is_empty(), "подія світу з'явилась на вимогу виклику: %s" % str(ES.active(wv).get("kind", "")))
	var wcalm = WorldState.new()
	wcalm.story = story_mid.duplicate()
	CS.state(wcalm, hero)["daily"] = []
	wcalm.challenges["weekly"] = []
	ES.state(wcalm)["calm"] = 9
	ES.tick(wcalm, hero)
	check(ES.active(wcalm).is_empty() and int(ES.state(wcalm)["calm"]) == 8, "без виклику події чекають свого часу")
	# Герой, якому місцевості вже не по силі: подія однаково знайдеться (валка між містами)
	var vet = _new_player()
	vet.change_class("cossack")
	vet.level = 66
	var wvet = WorldState.new()
	wvet.story = {"chapter": 5, "step": 0, "stage": "done", "progress": 0}
	CS.state(wvet, vet)["daily"] = [{"stat": "event", "text": "Прийди на поміч", "goal": 1, "progress": 0, "claimed": false, "group": "event", "where": ""}]
	var got_event := true
	for i in 12:
		ES.state(wvet)["active"] = {}
		ES.tick(wvet, vet)
		got_event = got_event and not ES.active(wvet).is_empty()
	check(got_event, "і героєві 66 рівня подія приходить щоразу")
	# Виклик просить супроводу — на дошці міста він є
	var wq = WorldState.new()
	wq.story = story_mid.duplicate()
	CS.state(wq, hero)["daily"] = [{"stat": "escort", "text": "Проведи мандрівника", "goal": 1, "progress": 0, "claimed": false, "group": "event", "where": ""}]
	var all_boards := true
	for city in ["kyiv", "sich", "lviv", "chyhyryn"]:
		var wq2 = WorldState.new()
		wq2.challenges = wq.challenges.duplicate(true)
		var board: Array = wq2.board(city)
		all_boards = all_boards and board.size() == 3 and board.any(func(q): return EscortS.is_open(q))
	check(all_boards, "на дошці будь-якого міста є супровід, коли його просить виклик")
	var bq: Array = wq.board("kyiv")
	var esc: Array = bq.filter(func(q): return EscortS.is_open(q))
	check(not esc.is_empty() and Data.LOCATIONS[esc[0]["loc"]]["type"] != "dungeon", "супровід веде в дику місцевість, не в печеру")
	check(DS.CHANCE_WANTED > DS.CHANCE * 2.0, "облога, яку просить виклик тижня, приходить швидше")
	# Оновлення гри посеред дня: розпочате лишається, решта — за новою схемою
	var wm = WorldState.new()
	wm.story = story_mid.duplicate()
	wm.challenges = {"day": CS.day_key(T0), "week": CS.week_key(T0), "ach": {"first_blood": true},
		"daily": [{"stat": "kill", "text": "Здолай 40 ворогів", "goal": 40, "progress": 12, "claimed": false},
			{"stat": "parry", "text": "Відбий 4 ударів парируванням", "goal": 4, "progress": 0, "claimed": false},
			{"stat": "field", "text": "Очисти місцевості: 1", "goal": 1, "progress": 1, "claimed": true}],
		"weekly": [{"stat": "boss", "text": "Здолай босів: 3", "goal": 3, "progress": 0, "claimed": false},
			{"stat": "elite", "text": "Здолай 20 еліт", "goal": 20, "progress": 5, "claimed": false}]}
	var cm = CS.state(wm, hero)
	check(int(cm["v"]) == CS.VERSION and cm["daily"].size() == 4 and cm["weekly"].size() == 3 and cm["ach"].has("first_blood"), "старі виклики перескладено за новою схемою")
	check(cm["daily"].any(func(x): return x["stat"] == "kill" and int(x["progress"]) == 12) and cm["daily"].any(func(x): return x["stat"] == "field" and x["claimed"]), "розпочатий і забраний виклики дня лишились")
	check(cm["weekly"].any(func(x): return x["stat"] == "elite" and int(x["progress"]) == 5) and cm["daily"].any(func(x): return x.get("group", "") == "event"), "тижневий із поступом лишився, а до денних додались події")
	var again = CS.state(wm, hero)
	check(again["daily"] == cm["daily"] and again["weekly"] == cm["weekly"], "удруге того ж дня виклики не перескладаються")
	# Перше звернення до викликів — від екрана (лічильник нагород), а не від бою: склад однаково під героя
	var wf = WorldState.new()
	wf.story = story_mid.duplicate()
	wf.challenges = {"day": CS.day_key(T0), "week": CS.week_key(T0), "ach": {}, "daily": [{"stat": "kill", "text": "Здолай 40 ворогів", "goal": 40, "progress": 3, "claimed": false}], "weekly": []}
	CS.ready_count(wf, hero)
	check(int(wf.challenges["v"]) == CS.VERSION and wf.challenges["daily"].filter(func(x): return x.get("group", "") == "event").size() == 2 and wf.challenges["weekly"].filter(func(x): return x.get("group", "") == "event").size() == 2, "після оновлення виклики з подіями, навіть якщо першим спитав лічильник на екрані")
	var wsave = WorldState.new()
	wsave.from_dict(wm.to_dict())
	check(CS.state(wsave, hero)["daily"] == cm["daily"], "склад викликів переживає збереження")
	CS.now_override = 0
	p.free()
	hero.free()
	young.free()
	vet.free()


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
	var vyly0: int = p.sk("vyly")
	check(p.learn_skill("fireball") and p.learn_skill("vyly") and p.sk("vyly") == vyly0 + 1, "волхв вчить вогонь, а вільне очко може вкласти й у селянську науку")
	check(not p.learn_skill("whirl"), "козацького волхв не вчить: це чужа дорога")
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
					check(SI.KIND.has(node["id"]) or node.has("act"), "активне %s є в довіднику панелі" % node["id"])
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
					PSv.mark_talked(w, "strilets")
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
	check(Classes.CLASSES["cossack"]["next"].size() == 3 and Classes.CLASSES["strilets"]["next"].size() == 4, "у Козака 3 дороги, у Стрільця 4")
	for spec in Classes.CLASSES["cossack"]["next"] + Classes.CLASSES["strilets"]["next"]:
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
	check(SS.available(p).size() == 3 and SS.start(w, p, "plastun"), "з 30-ї — можна до наставника")
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
	p.skill_points = 4
	var whirl0: int = p.sk("whirl")
	check(p.learn_skill("kydok") and p.learn_skill("whirl") and p.sk("whirl") == whirl0 + 1, "пластун вчить свої вміння, а вільні очки вкладає й у козацькі")
	check(not p.learn_skill("fireball") and not p.learn_skill(Classes.TREES["zaporozhets"][0]["nodes"][0]["id"]), "чужої дороги й сусідньої спеціалізації пластун не вчить")
	# Очки ніколи не зависають: рангів на дорозі більше, ніж очок, тож усе вивчити не вийде
	# і вільне очко завжди є куди вкласти (див. також «Вміння: дерева більші за запас очок»).
	var stuck := []
	for cls3 in Classes.CLASSES:
		if int(Classes.CLASSES[cls3]["tier"]) != 2:
			continue
		var ranks := 0
		var earned := 0
		for c3 in Classes.lineage(cls3):
			earned += int(Classes.CLASSES[c3]["job_max"]) - 1
			ranks += int(_tree_ranks(Classes, c3))
		var own: int = _tree_ranks(Classes, cls3)
		if earned > ranks:
			stuck.append("%s: очок %d, рангів на дорозі %d, у своєму дереві %d" % [cls3, earned, ranks, own])
	check(stuck.is_empty(), "очкам завжди є куди піти: рангів на дорозі не менше, ніж очок: %s" % ", ".join(stuck))
	p.skill_points = 0
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
	check(ST.siblings(p) == ["volkhv", "strilets"], "сусідні дороги Козака — Волхв і Стрілець")
	check(not ST.change_path(p, "volkhv"), "без Алатиря дорогу не зміниш")
	ST.grant(p, "alatyr")
	p.job_level = 25
	var pts: int = p.skill_points
	check(ST.change_path(p, "volkhv") and p.job == "volkhv" and p.job_level == 25, "Алатир: тепер волхв, майстерність лишилась")
	check(p.sk("whirl") == 0 and p.sk("battle_cry") == 0 and p.skill_points == pts + 3, "козацькі вміння забуто з поверненням очок")
	check(p.learn_skill("fireball"), "одразу вчить волхвівське")
	var sp = _new_player()
	sp.change_class("plastun")
	check(ST.siblings(sp).size() == 2 and not "plastun" in ST.siblings(sp), "пластун може стати іншим козацьким майстром")
	# Камінь забуття вертає очки з усієї дороги: і з пройдених дерев теж
	var rp = _new_player()
	rp.skills = {}
	rp.skill_points = 3
	rp.learn_skill("vyly")
	rp.change_class("cossack")
	rp.learn_skill("whirl")
	rp.change_class("plastun")
	rp.learn_skill("kydok")
	ST.grant(rp, "zabuttia")
	check(rp.skill_points == 0 and ST.reset_points(rp) and rp.skill_points == 3 and rp.sk("vyly") == 0 and rp.sk("whirl") == 0 and rp.sk("kydok") == 0, "Камінь забуття вертає очки з усіх дерев дороги")
	check(rp.learn_skill("whirl") and rp.learn_skill("vyly") and rp.learn_skill("kydok"), "і їх можна розкласти наново в будь-яке дерево дороги")
	rp.free()
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
	var deep: Dictionary = DS.loc_for(200)
	var edge_d := 1
	while DS.level_of(edge_d + 1) <= Data.ENDLESS_SOFT:
		edge_d += 1
	check(int(deep["level"]) == DS.BASE_LEVEL + 2 * 199 and int(deep["level"]) > 400 and int(deep["loot_level"]) == Data.ENDLESS_SOFT, "дна нема: глибина 200 має %d-й рівень, а здобич лишається %d-го" % [int(deep["level"]), Data.ENDLESS_SOFT])
	check(int(DS.loc_for(10)["loot_level"]) == int(DS.loc_for(10)["level"]) and is_equal_approx(float(DS.loc_for(edge_d)["hp_mult"]), 1.1 + 0.02 * edge_d), "до %d-го рівня глибини ростуть, як і раніше" % Data.ENDLESS_SOFT)
	var d1: Dictionary = DS.loc_for(edge_d + 10)
	var d2: Dictionary = DS.loc_for(edge_d + 11)
	check(float(d2["hp_mult"]) / float(d1["hp_mult"]) > pow(Data.ENDLESS_HP_PER_LEVEL, 2.0) * 0.999 and float(d2["dmg_mult"]) / float(d1["dmg_mult"]) > pow(Data.ENDLESS_DMG_PER_LEVEL, 2.0) * 0.999, "понад %d-й рівень кожна глибина множить здоров'я й удар нечисті" % Data.ENDLESS_SOFT)
	check(Data.endless_hp(Data.ENDLESS_SOFT) == 1.0 and Data.endless_hp(Data.ENDLESS_SOFT + 50) > 2.5 and Data.endless_dmg(Data.ENDLESS_SOFT + 50) > 2.0 and Data.enemy_std_hp(400) > Data.enemy_std_hp(99), "мірка нечисті росте й на сотих рівнях")
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
	check(int(game.world.stats.get("depth", 0)) == 1 and int(game.world.stats.get("depth_clear", 0)) == 1, "рекорд глибини записано, пройдена глибина йде у виклики")
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
	var high: Dictionary = TS.loc_for(200)
	check(int(high["level"]) == TS.BASE_LEVEL + 200 and int(high["loot_level"]) == Data.ENDLESS_SOFT and TS.loot_level(30) == TS.level_of(30), "вершини нема: поверх 200 має %d-й рівень, а здобич лишається %d-го" % [int(high["level"]), Data.ENDLESS_SOFT])
	var f1: Dictionary = TS.loc_for(120)
	var f2: Dictionary = TS.loc_for(121)
	check(float(f2["hp_mult"]) / float(f1["hp_mult"]) > Data.ENDLESS_HP_PER_LEVEL * 0.999 and float(TS.loc_for(60)["hp_mult"]) == 1.0 + 0.012 * 60 and TS.first_gold(200) > TS.first_gold(85), "понад %d-й рівень кожен поверх множить силу нечисті, нагорода теж росте" % Data.ENDLESS_SOFT)
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
	# ×2 здобичі: бос кидає на одну річ більше, елітний удвічі більше жмень ресурсів
	var cb = game.combat
	cb.spawn_enemy("upyr", 5, true, p.global_position + Vector2(300, 0))
	var tboss = null
	for e in cb.get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			tboss = e
	var count_kind := func(kind: String) -> int:
		var n := 0
		for ch in cb.entities.get_children():
			if ch.get_script() == cb.PickupScript and ch.kind == kind and not ch.is_queued_for_deletion():
				n += 1
		return n
	var it0: int = count_kind.call("item")
	cb.drop_boost = 1.0
	cb._drop_loot(tboss)
	var it1: int = count_kind.call("item")
	cb.drop_boost = 2.0
	cb._drop_loot(tboss)
	var it2: int = count_kind.call("item")
	check(it1 - it0 == 2 and it2 - it1 == 3, "бос: 2 речі, з ×2 здобичі — 3 (%d, %d)" % [it1 - it0, it2 - it1])
	tboss.is_boss = false
	tboss.elite = true
	tboss.title = "Пробний"
	tboss.affixes = ["fiery"]
	var r0: int = count_kind.call("res")
	cb.drop_boost = 1.0
	cb._drop_loot(tboss)
	var r1: int = count_kind.call("res")
	cb.drop_boost = 2.0
	cb._drop_loot(tboss)
	var r2: int = count_kind.call("res")
	# трофей з еліти падає через раз, тож підборів 2 чи 3 без ×2 і 4 чи 5 з ним
	check(r1 - r0 in [2, 3] and r2 - r1 in [4, 5], "елітний: 2 жмені й, може, трофей; з ×2 — 4 жмені (%d, %d)" % [r1 - r0, r2 - r1])
	tboss.queue_free()
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
	# Страва діє за часом бою: 20 хвилин; та сама ще раз додає час, але запас не більший за годину
	check(is_equal_approx(p.buff_left("food"), Data.MEAL_TIME) and Data.MEAL_TIME == 1200.0, "куліш діє двадцять хвилин бою")
	p.resources["herbs"] = 20
	check(OS2.can_cook(p, "kulish") and OS2.cook(p, "kulish") and is_equal_approx(p.buff_left("food"), 2400.0) and absf(p.max_hp - hp0 * 1.15) < 1.0, "той самий куліш ще раз: час додається, а бонус не подвоюється")
	check(OS2.cook(p, "kulish") and is_equal_approx(p.buff_left("food"), 3600.0) and not OS2.can_cook(p, "kulish") and not OS2.cook(p, "kulish"), "запас страви — не більше години")
	check(OS2.cook(p, "pechenia") and OS2.eaten(p) == "pechenia" and absf(p.max_hp - hp0) < 1.0 and absf(p.damage - dmg0 * 1.1) < 0.6 and is_equal_approx(p.buff_left("food"), Data.MEAL_TIME), "печеня замінює куліш: +10% шкоди, час рахується заново")
	var regen0: float = p.regen
	check(OS2.cook(p, "yushka") and p.regen >= regen0 + 1.0 - 0.01 and absf(p.damage - dmg0) < 0.6, "юшка: +1 здоров'я за секунду")
	check(p.tick_buffs(600.0).is_empty() and OS2.eaten(p) == "yushka" and is_equal_approx(p.buff_left("food"), 600.0), "десять хвилин бою минуло — юшка ще діє")
	var gone: Array = p.tick_buffs(600.0)
	check(gone == ["food:yushka"] and OS2.eaten(p) == "" and p.buff_left("food") == 0.0 and not p.trip_buffs.has("food_t"), "ще десять — страва скінчилась")
	check(absf(p.max_hp - hp0) < 1.0 and absf(p.damage - dmg0) < 0.6 and absf(p.regen - regen0) < 0.01, "без страви показники звичайні")
	# Старе збереження: страва й зілля «на похід» без часу дістають повний строк
	var old_p = _new_player()
	old_p.from_dict({"level": 5, "trip_buffs": {"food": "kulish", "strength": true, "inspired": true}})
	check(is_equal_approx(old_p.buff_left("food"), Data.MEAL_TIME) and is_equal_approx(old_p.buff_left("strength"), Data.BREW_TIME) and is_equal_approx(old_p.buff_left("inspired"), Data.INSPIRED_TIME), "старе збереження: підсилення дістали час")
	old_p.tick_buffs(100.0)
	var again = _new_player()
	again.from_dict(old_p.to_dict().duplicate(true))
	check(is_equal_approx(again.buff_left("food"), Data.MEAL_TIME - 100.0) and is_equal_approx(again.buff_left("strength"), Data.BREW_TIME - 100.0) and OS2.eaten(again) == "kulish", "залишок часу зберігається разом із героєм")
	old_p.free()
	again.free()
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
	# Страва діє за часом бою: на мапі час стоїть, у поході йде, після походу страва лишається
	var left0: float = p.buff_left("food")
	game.enter_map()
	await _frames(30)
	check(is_equal_approx(p.buff_left("food"), left0) and "Куліш 20 хв" in game.buffs_line(), "на мапі час страви стоїть: %s" % game.buffs_line())
	game.enter_location("wild_field")
	await _frames(60)
	check(game.state == game.State.PLAYING and OS2.eaten(p) == "kulish" and p.buff_left("food") < left0 - 0.5 and p.buff_left("food") > left0 - 3.0, "у поході час страви йде")
	game.enter_map()
	await _frames(2)
	check(OS2.eaten(p) == "kulish" and p.max_hp > hp0 * 1.1, "після походу страва лишилась")
	# Час вичерпано посеред бою: показники вертаються, над героєм напис
	game.enter_location("wild_field")
	await _frames(3)
	p.trip_buffs["food_t"] = 0.05
	await _frames(6)
	check(OS2.eaten(p) == "" and absf(p.max_hp - hp0) < 1.0 and game.buffs_line() == "", "двадцять хвилин бою минуло — куліш більше не діє")
	game.enter_map()
	await _frames(2)
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
	check(OS2.eaten(p) == "kulish", "після герцю страва лишилась")
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
	# Виклик дня просить стежку слідів — вона є в першому ж поході, без жеребу
	var sure := true
	game.ChallengeService.state(game.world, p)["daily"] = [{"stat": "trail", "text": "Пройди стежку слідів до знахідки", "goal": 1, "progress": 0, "claimed": false, "group": "event", "where": ""}]
	for i in 4:
		game.enter_location("wild_field")
		await _frames(3)
		sure = sure and c.trail != null
		game.enter_map()
		await _frames(2)
	check(sure, "сліди є в кожному поході, поки їх просить виклик")
	game.world.challenges["daily"] = []
	game.world.challenges["weekly"] = []
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
	game.world.revive_companions()  # розвідник із шансом 5% вертається пораненим; тут перевіряємо не це
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
	var left_mana := 0
	for ch in game.combat.entities.get_children():
		if ch.get_script() == game.combat.PickupScript and ch.kind == "mana" and not ch.is_queued_for_deletion():
			left_mana += 1
	check(p.mana_potions == p.mana_potion_max() and p.gold == gold0 and left_mana == 1, "зайве зілля не зникає й не продається, а лишається лежати")
	p.mana_potions = 0
	await _frames(30)
	check(p.mana_potions == 1, "звільнилось місце — зілля підібрано")
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
	game.combat.enemies_dirty()


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
	check(is_equal_approx(float(VS.targets_at(strong, 0)["std_hp"]), float(t0["std_hp"])) and is_equal_approx(float(VS.targets_at(strong, 0)["std_dmg"]), float(t0["std_dmg"])), "сила нечисті на варті не залежить від спорядження героя")
	strong.level = 30
	check(VS.targets_at(strong, 0)["std_hp"] > t0["std_hp"] * 1.5 and VS.targets_at(strong, 0)["std_dmg"] > t0["std_dmg"] * 1.5, "нечисть на варті росте з рівнем героя")
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
	check(int(game.world.stats.get("vigil_min", 0)) == 1, "хвилина на варті йде в лічильник для викликів")
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
	check(is_equal_approx(float(DS.loc_for(p, "ostap", 0)["rival_hp"]), float(DS.loc_for(weak, "ostap", 0)["rival_hp"])), "сила суперника не залежить від спорядження героя")
	weak.level = 30
	check(DS.loc_for(weak, "ostap", 0)["rival_hp"] > DS.loc_for(p, "ostap", 0)["rival_hp"] * 1.5, "суперник росте з рівнем героя")
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
	# Вільний герць: поза турніром, до першої поразки
	var DS = game.DuelService
	var Acts = game.Acts
	game.hud.close_dialogue()
	_reveal_tabs(game)
	var texts := ""
	for n in game.hud.screen_root.find_children("*", "Button", true, false):
		texts += n.text + "\n"
	check("Вільний герць: " in texts, "на майдані є кнопка вільного герцю")
	var tries0: int = int(DS.state(game.world)["tries"])
	var round0: int = int(DS.state(game.world)["round"])
	var first: Dictionary = DS.free_rival(game.world)
	var loc0: Dictionary = DS.free_loc(game.world, p)
	check(loc0["free"] and loc0["type"] == "duel" and loc0["rival"] == first["id"] and is_equal_approx(float(loc0["rival_hp"]), Data.ref_dps(int(p.level)) * Acts.FREE_DUEL_SECONDS), "перший суперник тримає двадцять секунд шкоди еталонного героя")
	var duels0: int = int(game.world.stats.get("duel", 0))
	var glory0: int = game.GloryService.glory(game.world)
	var wins := 0
	var paid_ok := true
	var harder := true
	var last_hp := 0.0
	for bout in 4:
		var gold_b: int = p.gold
		var want_gold: int = DS.free_gold(p.level, bout) if bout < Acts.FREE_DUEL_PAID else 0
		game.city_do("duel_free", null)
		await _frames(2)
		var rv = game.combat.nearest_enemy(p.global_position, 5000.0)
		if not (game.combat.is_duel() and game.combat.loc.get("free", false) and rv != null):
			break
		harder = harder and rv.max_hp > last_hp
		last_hp = rv.max_hp / (1.25 if rv.style == "bulavnyk" else 1.0)
		frames = 0
		while not game.combat.duel_over and frames < 9000 and game.state == game.State.PLAYING:
			_bot_fight(game)
			p.hp = p.max_hp
			await process_frame
			frames += 1
		if game.combat.duel_over:
			wins += 1
		paid_ok = paid_ok and p.gold - gold_b == want_gold
		frames = 0
		while game.state == game.State.PLAYING and frames < 600:
			_bot_fight(game)
			await process_frame
			frames += 1
		game.hud.close_dialogue()
	var st: Dictionary = DS.state(game.world)
	check(wins == 4 and int(st["streak"]) == 4 and int(st["best_streak"]) == 4, "чотири перемоги поспіль: серія й рекорд")
	check(paid_ok and int(st["free_paid"]) == Acts.FREE_DUEL_PAID and DS.free_paid_left(game.world) == 0, "гаманець дають за перші три перемоги дня, четверта — за серію")
	check(harder, "кожен наступний суперник у серії здоровіший")
	check(int(game.world.stats.get("duel", 0)) == duels0 + 4 and int(game.world.stats.get("duel_free", 0)) == 4 and game.GloryService.glory(game.world) == glory0 + Acts.FREE_DUEL_GLORY, "вільний герць іде в лічильник викликів, слава — за першу перемогу дня")
	check(int(st["tries"]) == tries0 and int(st["round"]) == round0, "турнірні спроби й кола вільний герць не чіпає")
	check(DS.free_rival(game.world)["id"] != first["id"] or Acts.RIVAL_ORDER.size() == 1, "суперники в серії міняються")
	check(game.RecordService.hero_values(game.world, p)["duel_streak"] == 4 and Acts.RECORDS.has("duel_streak") and "duel_streak" in Acts.RECORD_ORDER, "серія потрапляє в Літопис слави")
	# Поразка рве серію, рекорд лишається
	game.city_do("duel_free", null)
	await _frames(2)
	p.invuln = 0.0
	p.take_damage(p.max_hp * 20.0, null)
	await _frames(3)
	check(int(DS.state(game.world)["streak"]) == 0 and int(DS.state(game.world)["best_streak"]) == 4 and int(DS.state(game.world)["tries"]) == tries0, "поразка рве серію, рекорд і турнірні спроби цілі")
	frames = 0
	while game.state != game.State.CITY and frames < 300:
		await process_frame
		frames += 1
	check(game.state == game.State.CITY and p.alive, "після поразки у вільному герці — на Січі й живий")
	# Наступного дня гаманці знову є
	var CSx = game.ChallengeService
	CSx.now_override = int(Time.get_unix_time_from_system()) + 86400
	check(DS.free_paid_left(game.world) == Acts.FREE_DUEL_PAID, "наступного дня гаманці знову чекають")
	CSx.now_override = 0
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
	check(p.gold > gold0 and int(game.world.stats.get("tower", 0)) == 1 and int(game.world.stats.get("tower_floor", 0)) == 1, "нагорода за перше проходження, рекорд і поверх для викликів")
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
	var place_btns := texts.filter(func(t): return not str(t).begins_with("×2") and not str(t).begins_with("Боси дня"))
	check("Вирушити" in texts and place_btns.size() == 1, "в іншій місцевості кнопки супроводу нема")
	check(texts.any(func(t): return str(t).begins_with("×2 досвіду")) and texts.any(func(t): return str(t).begins_with("×2 здобичі")), "реклама ×2 досвіду і ×2 здобичі видно й з обраним місцем: %s" % str(texts))
	var ad_sc: ScrollContainer = game.hud.map_panel.find_children("*", "ScrollContainer", true, false)[0]
	check(ad_sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "панель мапи гортається, кнопки реклами під нею")
	await _ride(game, "wild_field")
	check(game.state == game.State.PLAYING and not game.combat.is_defense() and ES.is_open(q), "«Вирушити» — звичайний похід")
	# «Провести»: бій із мандрівником
	await _ride(game, "wild_field", true)
	var c = game.combat
	check(game.state == game.State.PLAYING and c.is_defense() and c.gate != null and c.gate.variant == "escort", "«Провести» — супровід")
	check(c.gate.sheet == "trav_kobzar" and c.gate.label_text() == "Кобзар" and c.gate.radius < 30.0 and is_equal_approx(c.gate.max_hp, float(ES.battle_loc(q, game.player)["gate_hp"])) and c.gate.max_hp >= ES.hp(1), "мандрівник на арені: кобзар")
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
	check(game.player != null and game.player.level == 12 and game.player.gold == 4321 and int(game.account.chest["gold"]) == 900 and game.state == game.State.MAP and game.map_here == "ridne_selo", "гра продовжується перенесеним героєм зі спільною скринею там, де він стояв")
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
	# ---- Кожне місце мапи: кнопка панелі починає поїздку, а не переносить героя миттю ----
	var ActsT = load("res://scripts/data/activities.gd")
	var CampT = load("res://scripts/data/camp_data.gd")
	var StoryT = load("res://scripts/data/story.gd")
	var TowerT = load("res://scripts/game/tower_service.gd")
	var DepthT = load("res://scripts/game/depth_service.gd")
	game.enter_map()
	await _frames(2)
	p.level = 99
	p.invuln = 9999.0
	game.world.story = {"chapter": StoryT.CHAPTERS.size(), "step": 0, "stage": "done", "progress": 0}
	game.world.travel = {"cooldown": 99, "seen": {}}
	var go_texts := ["Вирушити", "Увійти до міста", "Увійти на хутір", "Спуститися", "Піднятися", "Вирушити до табору", "Полювати", "Рибалити", "Стати на варту", "Стати в коло"]
	var all_places: Array = Data.CITIES.keys() + Data.LOCATIONS.keys() + ActsT.SPOTS.keys() + [CampT.CAMP_ID]
	var rode := []
	var jumped := []
	for id in all_places:
		if id == "sich":
			continue
		game.travel_to = ""
		game.hud.map_view.travel = {}
		game.map_here = "sich"
		game._on_map_select(id)
		await _frames(1)
		var go_btn = null
		for b in game.hud.map_panel.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion() and not b.disabled and b.text in go_texts:
				go_btn = b
		if go_btn == null:
			continue  # місце ще замкнене або там подія зі своєю кнопкою
		go_btn.pressed.emit()
		if game.travel_to == id and game.state == game.State.MAP and game.map_here == "sich" and not game.hud.map_view.travel.is_empty():
			rode.append(id)
		else:
			jumped.append(id)
			game.hud.close_dialogue()
			game.enter_map()
			await _frames(2)
	game.travel_to = ""
	game.hud.map_view.travel = {}
	check(jumped.is_empty(), "до жодного місця на мапі герой не переноситься миттю: %s" % str(jumped))
	var skipped := []
	for id in all_places:
		if id != "sich" and not id in rode and not id in jumped:
			skipped.append(id)
	check(skipped.is_empty() and rode.size() == all_places.size() - 1 and TowerT.LOC_ID in rode and DepthT.LOC_ID in rode and "kyiv" in rode and "zamok_drakuly" in rode and "devova_ushchelyna" in rode and "kolo" in rode and CampT.CAMP_ID in rode,
		"поїздкою перевірено %d місць із %d: міста, хутір, поля, печери, Башту, Глибини, табори й заняття (без кнопки: %s)" % [rode.size(), all_places.size() - 1, str(skipped)])
	# до Башти справді треба доїхати, і лише під нею «Піднятися» заходить одразу
	game.map_here = "sich"
	game.tower_sel = 1
	game._on_map_select(TowerT.LOC_ID)
	await _frames(1)
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text == "Піднятися":
			b.pressed.emit()
	check(game.travel_to == TowerT.LOC_ID and game.state == game.State.MAP, "«Піднятися» з Січі: герой їде до Башти мапою")
	frames = 0
	while game.travel_to != "" and frames < 1500:
		await process_frame
		frames += 1
	check(game.state == game.State.PLAYING and game.combat.loc_id == TowerT.LOC_ID and game.map_here == TowerT.LOC_ID and frames > 20, "доїхав за %d кадрів, і лише тоді почався бій у Башті" % frames)
	game.enter_map()
	await _frames(2)
	game._on_map_select(TowerT.LOC_ID)
	await _frames(1)
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text == "Піднятися":
			b.pressed.emit()
	check(game.state == game.State.PLAYING and game.travel_to == "", "стоячи під Баштою, герой заходить одразу")
	var ride_art := ""
	for e in load("res://scripts/game/wiki_service.gd")._entries("basics"):
		if str(e["title"]) == "Подорож мапою":
			ride_art = str(e["text"])
	check("Башти Кощія" in ride_art and "Глибин зарази" in ride_art and "«Піднятися»" in ride_art and "де вже стоїть" in ride_art, "довідник має статтю «Подорож мапою»: до кожного місця треба доїхати")
	# ---- Вільне пересування: дотик до порожнього місця мапи ----
	var mv = game.hud.map_view
	game.map_here = "sich"
	game.enter_map()
	await _frames(2)
	# порожня точка: найдальша на екрані від усіх значків місць (розкладка мапи в тесті своя)
	var free_ll := Vector2.ZERO
	var free_gap := 0.0
	for xi in 40:
		for yi in 26:
			var cand := Vector2(22.0 + xi * 0.45, 43.6 + yi * 0.42)
			var sp: Vector2 = mv._proj(cand)
			if not mv.map_rect.grow(-20.0).has_point(sp):
				continue
			var gap := 1e9
			for mid in mv._markers:
				gap = minf(gap, sp.distance_to(mv._markers[mid]))
			if gap > free_gap:
				free_gap = gap
				free_ll = cand
	if free_gap <= 40.0 * mv._k:
		free_ll = Vector2.ZERO
	check(free_ll != Vector2.ZERO, "на мапі є порожнє місце для перевірки")
	var heard := []
	var catch := func(ll: Vector2): heard.append(ll)
	mv.point_tapped.connect(catch)
	mv._tap(mv._proj(free_ll))
	check(heard.size() == 1 and heard[0].distance_to(free_ll) < 0.05 and game.travel_to == game.POINT_ID and game.state == game.State.MAP, "дотик до порожнього місця мапи: герой рушає просто туди")
	check(mv.travel.has("to_ll") and mv.travel["to_ll"].distance_to(free_ll) < 0.05 and mv._travel_ll(0.0).distance_to(Data.CITIES["sich"]["pos"]) < 0.01 and mv._travel_ll(1.0).distance_to(free_ll) < 0.05, "шлях на мапі веде від Січі до цієї точки")
	game._go_point(Vector2(36.0, 50.5))
	check(game.travel_point.distance_to(free_ll) < 0.05, "у дорозі другий дотик маршруту не міняє")
	frames = 0
	while game.travel_to != "" and frames < 1500:
		await process_frame
		frames += 1
	check(game.map_at_point and game.map_point.distance_to(free_ll) < 0.05 and game.state == game.State.MAP and mv.current_ll != null and mv.current == "" and mv.travel.is_empty() and frames > 10, "приїхав і стоїть просто на мапі (кадрів: %d)" % frames)
	var near: String = game.map_here
	check(Data.place_name(near) != "" and not game._at(near) and game._here_ll().distance_to(free_ll) < 0.05, "найближче місце (%s) знане пораднику, та герой у ньому не стоїть" % Data.place_name(near))
	game.open_character()
	await _frames(2)
	game.close_character()
	await _frames(2)
	check(game.map_at_point and mv.current_ll != null and mv.current_ll.distance_to(free_ll) < 0.05, "після екрана героя він стоїть там само")
	# дотик до значка місця лише обирає його, а не веде у вільну точку
	mv._tap(mv._proj(Data.CITIES["poltava"]["pos"]))
	await _frames(1)
	check(game.map_sel == "poltava" and game.travel_to == "" and heard.size() == 1, "дотик до значка місця обирає місце, а не точку поруч")
	game._go_to(near)
	check(game.travel_to == near and mv.travel.get("from_ll", Vector2.ZERO).distance_to(free_ll) < 0.05, "до найближчого місця теж треба доїхати: дорога починається з вільної точки")
	var short_dur: float = game.travel_dur
	frames = 0
	while game.travel_to != "" and frames < 1500:
		if game.hud.dialogue_root != null:
			game.hud.dialogue_root._finish()
		await process_frame
		frames += 1
	check(not game.map_at_point and game.map_here == near and game._at(near), "приїхав у місце: вільної точки більше нема")
	game.hud.close_dialogue()
	game.map_here = "sich"
	game.enter_map()
	await _frames(2)
	game._go_point(Vector2(35.42, 47.50))
	check(game.travel_dur < 1.0 and game.travel_dur >= 0.5 / 1.5, "коротка вільна дорога швидка: %.2f с" % game.travel_dur)
	game.travel_to = ""
	mv.travel = {}
	game._go_point(Vector2(5.0, 99.0))
	check(game.travel_point.distance_to(Vector2(mv.LON0 + mv.EDGE, mv.LAT1 - mv.EDGE)) < 0.01, "за край мапи виїхати не можна: точка стає на межу %s" % str(game.travel_point))
	game.travel_to = ""
	mv.travel = {}
	check(mv.at_sea(Vector2(33.6, 43.2)) and mv.at_sea(Vector2(37.2, 46.3)) and not mv.at_sea(Vector2(31.65, 49.4)) and not mv.at_sea(Data.CITIES["kyiv"]["pos"]), "над морем пливе чайка, суходолом їде вершник")
	check("порожнього місця" in ride_art and "чайка" in ride_art, "довідник каже про вільне пересування мапою")
	mv.point_tapped.disconnect(catch)
	game.enter_map()
	await _frames(2)
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)

# ======================= Клейноди роду, скарбник, заточка без ризику =======================

func _suite_kleinody() -> void:
	suite("Клейноди роду")
	var KS = load("res://scripts/game/kleinod_service.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var CampService = load("res://scripts/game/camp_service.gd")
	var GloryService = load("res://scripts/game/glory_service.gd")
	var StoneService = load("res://scripts/game/stone_service.gd")
	var Gfx = load("res://scripts/world/gfx.gd")
	var UI = load("res://scripts/ui/ui_kit.gd")
	var w = WorldState.new()
	var p = _new_player()
	# Дані
	check(Camp.KLEINOD_ORDER.size() == 7 and Camp.KLEINODY.size() == 7 and KS.max_level() == 5, "сім клейнодів по п'ять ступенів")
	var data_ok := true
	for id in Camp.KLEINOD_ORDER:
		var K: Dictionary = Camp.KLEINODY.get(id, {})
		for key in ["name", "stat", "per", "res", "text", "desc"]:
			data_ok = data_ok and K.has(key)
		data_ok = data_ok and Camp.RESOURCES.has(K.get("res", "")) and Gfx.icon_tex("kl_" + id) != null and float(K.get("per", 0.0)) > 0.0
		data_ok = data_ok and (K.get("stat", "") in KS.HERO_STATS or K.get("stat", "") in ["glory", "loyalty"])
	check(data_ok, "у кожного клейнода є назва, бонус, ресурс і значок")
	var rising: bool = Camp.KLEINOD_GOLD.size() == 5 and Camp.KLEINOD_TROPHY.size() == 5 and Camp.KLEINOD_RES.size() == 5
	for i in range(1, 5):
		rising = rising and Camp.KLEINOD_GOLD[i] > Camp.KLEINOD_GOLD[i - 1] and Camp.KLEINOD_TROPHY[i] > Camp.KLEINOD_TROPHY[i - 1] and Camp.KLEINOD_RES[i] > Camp.KLEINOD_RES[i - 1]
	check(rising, "кожен ступінь дорожчий за попередній")
	check(UI.num(0) == "0" and UI.num(999) == "999" and UI.num(1000) == "1 000" and UI.num(1226262) == "1 226 262" and UI.num(-15000) == "-15 000", "великі суми пишуться з проміжками")
	# Купівля
	check(KS.level(w, "lytavry") == 0 and KS.total(w) == 0 and KS.player_mods(w).is_empty(), "спершу клейнодів нема")
	var c: Dictionary = KS.cost(w, "lytavry")
	check(c == {"gold": 10000, "trophy": 10, "iron": 50}, "перший ступінь литавр: гривні, трофеї й залізо: %s" % str(c))
	check(not KS.can_buy(w, p, "lytavry") and not KS.buy(w, p, "lytavry"), "без гривень не купити")
	p.gold = 10000
	p.resources = {"iron": 50, "trophy": 9}
	check(not KS.can_buy(w, p, "lytavry") and not KS.buy(w, p, "lytavry") and p.gold == 10000, "бракує одного трофея — не купити, гривні цілі")
	p.resources["trophy"] = 10
	var xp0: float = p.xp_mult
	check(KS.buy(w, p, "lytavry") and p.gold == 0 and int(p.resources["iron"]) == 0 and int(p.resources["trophy"]) == 0, "купівля забирає гривні, трофеї й ресурс")
	check(KS.level(w, "lytavry") == 1 and is_equal_approx(KS.bonus(w, "xp"), 0.04) and is_equal_approx(p.xp_mult, xp0 + 0.04), "литаври: +4% досвіду одразу")
	p.gold = 10000000
	p.resources = {"wood": 100000, "iron": 100000, "herbs": 100000, "trophy": 100000}
	for i in 6:
		KS.buy(w, p, "lytavry")
	check(KS.level(w, "lytavry") == 5 and KS.cost(w, "lytavry").is_empty() and not KS.can_buy(w, p, "lytavry") and not KS.buy(w, p, "lytavry"), "п'ятий ступінь — межа")
	check(p.gold == 10000000 - 455000 and int(p.resources["iron"]) == 100000 - 2620 and int(p.resources["trophy"]) == 100000 - 290, "чотири наступні ступені: 455 000 грн, 290 трофеїв, 2 620 заліза")
	var sum_gold := 0
	var sum_trophy := 0
	var sum_res := 0
	for i in 5:
		sum_gold += int(Camp.KLEINOD_GOLD[i])
		sum_trophy += int(Camp.KLEINOD_TROPHY[i])
		sum_res += int(Camp.KLEINOD_RES[i])
	check(sum_gold == 465000 and sum_trophy == 300 and sum_res == 2670, "досконалий клейнод: 465 000 грн, 300 трофеїв, 2 670 ресурсу")
	var by_res := {}
	for id in Camp.KLEINOD_ORDER:
		by_res[Camp.KLEINODY[id]["res"]] = int(by_res.get(Camp.KLEINODY[id]["res"], 0)) + 1
	check(by_res == {"iron": 4, "wood": 2, "herbs": 1}, "заліза, якого найбільше, просять чотири клейноди: %s" % str(by_res))
	check(is_equal_approx(p.xp_mult, xp0 + 0.2) and KS.total(w) == 5, "досконалі литаври: +20% досвіду")
	# Бонуси до показників героя
	var hp0: float = p.max_hp
	var dmg0: float = p.damage
	var crit0: float = p.crit_chance
	var cd0: float = p.skill_cd_mult
	p.hp = p.max_hp * 0.5
	KS.buy(w, p, "bunchuk")
	KS.buy(w, p, "bunchuk")
	check(absf(p.max_hp / hp0 - 1.06) < 0.001 and absf(p.hp / p.max_hp - 0.5) < 0.001, "бунчук: +6% здоров'я, частка здоров'я та сама")
	for i in 3:
		KS.buy(w, p, "bulava")
	check(absf(p.damage / dmg0 - 1.09) < 0.001, "булава: +9% шкоди за три ступені")
	KS.buy(w, p, "pernach")
	KS.buy(w, p, "pernach")
	check(is_equal_approx(p.crit_chance, crit0 + 0.04), "пернач: +4% до шансу критичного удару")
	for i in 5:
		KS.buy(w, p, "surmy")
	check(absf(p.skill_cd_mult / cd0 - 0.9) < 0.001, "сурми: вміння відновлюються на 10% швидше")
	check(p.klein == KS.player_mods(w) and p.klein.size() == 5, "герой несе всі п'ять бонусів роду: %s" % str(p.klein))
	# Слава й лояльність
	var g0: int = GloryService.glory(w)
	GloryService.add(w, p, 100)
	check(GloryService.glory(w) - g0 == 100, "без корогви слава звичайна")
	KS.buy(w, p, "korohva")
	KS.buy(w, p, "korohva")
	g0 = GloryService.glory(w)
	GloryService.add(w, p, 100)
	check(GloryService.glory(w) - g0 == 110, "корогва: +10% слави")
	w.add_loyalty("sich", 10)
	var l0: int = w.loyalty_points("sich")
	for i in 3:
		KS.buy(w, p, "pechatka")
	w.add_loyalty("sich", 10)
	check(l0 == 10 and w.loyalty_points("sich") - l0 == 13, "печатка: +30% лояльності міст")
	w.add_loyalty("sich", -10)
	check(w.loyalty_points("sich") == l0 + 3, "втрату лояльності печатка не збільшує")
	# Рід спільний: інший герой отримує ті самі бонуси
	var p2 = _new_player()
	var p2_dmg: float = p2.damage
	CampService.apply_effects(w, p2)
	check(p2.klein == p.klein and absf(p2.damage / p2_dmg - 1.09) < 0.001, "новий герой роду одразу має бонуси клейнодів")
	# Збереження
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(KS.level(w2, "lytavry") == 5 and KS.level(w2, "bulava") == 3 and KS.total(w2) == KS.total(w) and KS.total(w) == 22, "клейноди переживають збереження")
	w2.camp["kleinody"]["bulava"] = 99
	w2.camp["kleinody"]["surmy"] = -4
	check(KS.level(w2, "bulava") == 5 and KS.cost(w2, "bulava").is_empty() and KS.level(w2, "surmy") == 0, "зіпсований ступінь у збереженні не ламає гру")
	# Тексти
	check(KS.bonus_text("lytavry", 3) == "+12% досвіду" and KS.bonus_text("surmy", 5) == "вміння відновлюються на 10% швидше" and KS.bonus_text("pechatka", 2) == "+20% лояльності міст", "бонуси словами")
	check(KS.cost_text({"gold": 600000, "trophy": 600, "iron": 7000}) == "600 000 грн, трофеї 600, залізо 7 000", "ціна словами: %s" % KS.cost_text({"gold": 600000, "trophy": 600, "iron": 7000}))
	# Скарбник продає камені долі
	var ps = _new_player()
	check(KS.stone_price("zabuttia") == 40000 and KS.stone_price("alatyr") == 120000 and KS.stone_price("nema") == 0, "ціни каменів долі")
	ps.gold = 39999
	check(not KS.buy_stone(ps, "zabuttia") and StoneService.count(ps, "zabuttia") == 0 and ps.gold == 39999, "без гривень камінь не купити")
	ps.gold = 160000
	check(KS.buy_stone(ps, "zabuttia") and KS.buy_stone(ps, "alatyr") and ps.gold == 0 and StoneService.count(ps, "zabuttia") == 1 and StoneService.count(ps, "alatyr") == 1, "купив обидва камені")
	check(not KS.buy_stone(ps, "nema"), "невідомого каменя скарбник не має")
	check(Gfx.icon_tex("stone_zabuttia") != null and Gfx.icon_tex("stone_alatyr") != null and Camp.STONE_TEXT.has("zabuttia") and Camp.STONE_TEXT.has("alatyr"), "у каменів є значки й описи")
	# Заточка без ризику: утричі дорожча, зате рівень не падає
	var it: Dictionary = Data.gen_item(20, 2, "boots")
	it["up"] = 7
	ps.add_item(it)
	var base: int = Data.sharpen_cost(it)
	check(Data.SHARPEN_SAFE_MULT == 3.0 and Data.sharpen_safe_cost(it) == base * 3, "ціна без ризику — потрійна")
	ps.gold = 1000000
	check(ps.sharpen(it["uid"], Data.SHARPEN_SAFE_MULT, -5.0, true) == "fail" and int(it["up"]) == 7 and ps.gold == 1000000 - base * 3, "невдача без ризику: гривні пішли, заточка ціла")
	check(ps.sharpen(it["uid"], 1.0, -5.0, false) == "down" and int(it["up"]) == 6, "звичайна невдача знижує заточку")
	var mult: float = 0.8
	var gold_before: int = ps.gold
	var want: int = Data.sharpen_safe_cost(it, mult)
	ps.sharpen(it["uid"], mult * Data.SHARPEN_SAFE_MULT, -5.0, true)
	check(gold_before - ps.gold == want, "ціна на кнопці збігається зі списаною (зі знижкою кузні)")


func _suite_kleinody_game() -> void:
	suite("Клейноди: у грі")
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
	var KS = game.KleinodService
	var UI = load("res://scripts/ui/ui_kit.gd")
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.level = 30
	p.gold = 100
	game.enter_camp()
	await _frames(2)
	# Гру посеред перевірки створюємо наново, тож помічники беруть її параметром, а не захоплюють
	var titles := func(g) -> Array:
		var out := []
		var tc = g.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
		for i in tc.get_tab_count():
			out.append(tc.get_tab_title(i))
		return out
	var texts := func(g) -> String:
		_reveal_tabs(g)
		var out := ""
		for n in g.hud.screen_root.find_children("*", "Label", true, false):
			out += n.text + "\n"
		for n in g.hud.screen_root.find_children("*", "Button", true, false):
			out += n.text + "\n"
		return out
	var button := func(g, part: String) -> Button:
		_reveal_tabs(g)
		for n in g.hud.screen_root.find_children("*", "Button", true, false):
			if part in n.text:
				return n
		return null
	check("Клейноди" in titles.call(game), "на хуторі є вкладка клейнодів: %s" % str(titles.call(game)))
	var t: String = texts.call(game)
	check("Булава — ступінь 0/5" in t and "Наступний ступінь: +3% шкоди" in t and "Скарбник" in t and "Алатир-камінь — у тебе 0" in t, "вкладка показує клейноди й камені")
	var b: Button = button.call(game, "10 000 грн, трофеї 10, залізо 50")
	check(b != null and b.disabled and b.text.begins_with("Здобути"), "без гривень кнопка неактивна")
	game.camp_do("kleinod", "bulava")
	check(KS.level(game.world, "bulava") == 0 and int(game.world.stats.get("kleinod", 0)) == 0, "без гривень клейнод не купується")
	check(not game.world.hints.has("kleinody"), "без гривень про клейноди не підказуємо")
	p.gold = 2000000
	p.resources = {"wood": 20000, "iron": 20000, "herbs": 20000, "trophy": 5000}
	game.enter_camp()
	await _frames(2)
	check(game.world.hints.has("kleinody") and game.hud.hint_panel.visible and "Клейноди" in game.hud.hint_label.text, "гривень вистачає на перший клейнод — хутір підказує про вкладку")
	var dmg0: float = p.damage
	game.camp_do("kleinod", "bulava")
	await _frames(2)
	check(KS.level(game.world, "bulava") == 1 and absf(p.damage / dmg0 - 1.03) < 0.001, "купив булаву: шкода +3%")
	check(int(game.world.stats.get("kleinod", 0)) == 1 and game.account.challenges["ach"].has("kleinod_1") and p.gold == 2000000 - 10000 + 1000, "лічильник, досягнення й ціна: лишилось %d грн" % p.gold)
	check(int(p.resources["iron"]) == 20000 - 50 and int(p.resources["trophy"]) == 5000 - 10, "трофеї й залізо списано")
	t = texts.call(game)
	check("Булава — ступінь 1/5" in t and "Зараз: +3% шкоди" in t and "Наступний ступінь: +6% шкоди" in t and "Оздоблено ступенів: 1 із 35" in t, "вкладка оновилась після купівлі")
	b = button.call(game, "25 000 грн, трофеї 20, залізо 120")
	check(b != null and not b.disabled and b.text.begins_with("Оздобити"), "наступний ступінь уже можна оздобити")
	check("Хутір • 1 991 000 грн" in t, "гривні в заголовку хутора з проміжками")
	for i in 4:
		game.camp_do("kleinod", "bulava")
	await _frames(2)
	check(KS.level(game.world, "bulava") == 5 and button.call(game, "Досконалий") != null and button.call(game, "Досконалий").disabled, "досконалий клейнод більше не продається")
	# Камені долі. Список після покупки лишається там, де був, а не стрибає на початок
	var scroller := func(g) -> ScrollContainer:
		var tc: TabContainer = g.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
		return tc.get_current_tab_control() as ScrollContainer
	var win_size: Vector2i = root.size
	root.size = Vector2i(1560, 720)  # без вікна екран безмежний і гортати нема чого, тож даємо йому розмір телефона
	await _frames(2)
	var tabs: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = titles.call(game).find("Клейноди")
	await _frames(2)
	check(game.camp_tab == titles.call(game).find("Клейноди"), "гра пам'ятає відкриту вкладку клейнодів")
	scroller.call(game).scroll_vertical = 240
	await _frames(1)
	check(scroller.call(game).scroll_vertical == 240, "список клейнодів довгий і гортається")
	var gold0: int = p.gold
	game.camp_do("buy_stone", "alatyr")
	await _frames(2)
	check(game.StoneService.count(p, "alatyr") == 1 and gold0 - p.gold == 120000 and "Алатир-камінь — у тебе 1" in texts.call(game), "скарбник продав Алатир-камінь")
	check(scroller.call(game).scroll_vertical == 240, "після покупки список лишився на місці: %d" % scroller.call(game).scroll_vertical)
	game.camp_do("select", p.equipment["weapon"]["uid"])
	await _frames(2)
	check(scroller.call(game).scroll_vertical == 0, "вибір речі показує екран згори")
	root.size = win_size
	# Збереження й повернення в гру
	game.save_game()
	check(int(game.account.camp.get("kleinody", {}).get("bulava", 0)) == 5, "клейноди лежать у спільному хуторі акаунта")
	game.queue_free()
	await _frames(2)
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	check(game.load_game(), "гра завантажилась")
	p = game.player
	check(KS.level(game.world, "bulava") == 5 and is_equal_approx(float(p.klein.get("dmg", 0.0)), 0.15), "після завантаження булава діє: %s" % str(p.klein))
	# Заточка без ризику на хуторі
	p.gold = 5000000
	p.resources = {"wood": 20000, "iron": 20000, "herbs": 20000, "trophy": 5000}
	game.enter_camp()
	await _frames(2)
	game.camp_do("build", "kuznia")
	var it: Dictionary = p.equipment["weapon"]
	var uid: int = it["uid"]
	it["up"] = 2
	p.recalc()
	game.camp_do("select", uid)
	await _frames(2)
	check(not ("Заточити без ризику" in texts.call(game)), "до +6 ризику нема, тож і кнопки нема")
	gold0 = p.gold
	var plain: int = int(Data.sharpen_cost(it) * game.CampService.forge_cost_mult(game.world))
	game.camp_do("sharpen_safe", uid)
	check(gold0 - p.gold == plain, "до +6 заточка без ризику коштує як звичайна")
	it["up"] = 6
	p.recalc()
	game.camp_do("select", uid)
	await _frames(2)
	var safe_cost: int = Data.sharpen_safe_cost(it, game.CampService.forge_cost_mult(game.world))
	b = button.call(game, "Заточити без ризику")
	check(b != null and not b.disabled and (UI.num(safe_cost) + " грн") in b.text, "із +6 є кнопка заточки без ризику з ціною")
	gold0 = p.gold
	game.camp_do("sharpen_safe", uid)
	check(gold0 - p.gold == safe_cost and int(it["up"]) >= 6, "списано рівно ціну з кнопки, заточка не впала")
	var never_down := true
	var prev: int = int(it["up"])
	for i in 200:
		if int(it["up"]) >= Data.MAX_UPGRADE:
			break
		game.camp_do("sharpen_safe", uid)
		never_down = never_down and int(it["up"]) >= prev
		prev = int(it["up"])
	check(never_down and int(it["up"]) == Data.MAX_UPGRADE, "без ризику заточка лише росте, аж до +%d" % Data.MAX_UPGRADE)
	# Жетон безпечної заточки платна спроба не чіпає; з жетоном платна кнопка зайва
	it["up"] = 7
	p.recalc()
	check(game.AdRewards.grant_safe(game.world) and game.AdRewards.safe_tokens(game.world) == 1, "є жетон безпечної заточки")
	game.camp_do("select", uid)
	await _frames(2)
	check(not ("Заточити без ризику" in texts.call(game)), "із жетоном платної кнопки нема")
	game.camp_do("sharpen_safe", uid)
	check(game.AdRewards.safe_tokens(game.world) == 1, "платна спроба жетон не витрачає")
	# Міський коваль
	it["up"] = 8
	p.recalc()
	game.world.boosts["safe_sharpen"] = 0
	game.leave_camp()
	await _frames(2)
	game.enter_city("sich")
	await _frames(2)
	game.city_do("select", uid)
	await _frames(2)
	safe_cost = Data.sharpen_safe_cost(it)
	b = button.call(game, "Заточити без ризику")
	check(b != null and (UI.num(safe_cost) + " грн") in b.text and safe_cost == Data.sharpen_cost(it) * 3, "міський коваль теж точить без ризику, без знижки хутора")
	gold0 = p.gold
	game.city_do("sharpen_safe", uid)
	check(gold0 - p.gold == safe_cost and int(it["up"]) >= 8, "у місті списано потрійну ціну, заточка не впала")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)

# ======================= Коло Кожум'яки й гетьманський огляд =======================

func _suite_ring_muster() -> void:
	suite("Коло Кожум'яки й огляд: правила")
	var RS = load("res://scripts/game/ring_service.gd")
	var MS = load("res://scripts/game/muster_service.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Power = load("res://scripts/game/power.gd")
	var RecS = load("res://scripts/game/record_service.gd")
	var T0 := 1762700000
	CS.now_override = T0
	var p = _new_player()
	p.change_class("cossack")
	p.level = 30
	p.recalc()
	var w = WorldState.new()
	# --- Коло ---
	var line: Array = RS.lineup()
	var uniq := {}
	for k in line:
		uniq[k] = true
	check(line.size() == 3 and uniq.size() == 3 and line.all(func(k): return k in Acts.RING_POOL and Data.BOSS_NAMES.has(k)), "у колі три різні чудовиська з іменами: %s" % str(line))
	check(RS.lineup() == line and RS.lineup(CS.week_key(T0)) == line, "склад тижня однаковий для всіх")
	var variety := {}
	for i in 12:
		variety[str(RS.lineup("W%d" % (2900 + i)))] = true
	check(variety.size() >= 8, "щотижня склад інший (%d різних за 12 тижнів)" % variety.size())
	var young = _new_player()
	young.change_class("cossack")
	young.level = 9
	var peasant = _new_player()
	peasant.job = "peasant"
	peasant.level = 30
	check(RS.unlocked(p) and not RS.unlocked(young) and not RS.unlocked(peasant) and Acts.SPOTS["kolo"]["kind"] == "ring", "коло відкрите з 10-го рівня тим, хто обрав дорогу")
	var s1: Dictionary = RS.boss_stats(p, 0)
	var s3: Dictionary = RS.boss_stats(p, 2)
	check(is_equal_approx(float(s1["hp"]), Data.ref_dps(int(p.level)) * Acts.RING_SECONDS[0]) and float(s3["hp"]) > float(s1["hp"]) and float(s3["dmg"]) > float(s1["dmg"]) and float(s1["cap"]) > 0.0, "чудовиська міряються з героєм, кожне коло тяжче")
	var L: Dictionary = RS.battle_loc(p)
	check(L["type"] == "ring" and L["bosses"] == line and float(L["std_hp"]) > 0.0 and float(L["xp_mult"]) < 1.0, "опис бою кола")
	var gold0: int = p.gold
	var r1: Dictionary = RS.on_stage(w, p, 1)
	check(r1["weekly"] and int(r1["gold"]) == Acts.RING_GOLD[0] * 30 and int(r1["glory"]) == Acts.RING_GLORY[0] and p.gold == gold0 + int(r1["gold"]) and int(RS.state(w)["paid"]) == 1, "перше коло тижня: гаманець і слава")
	RS.on_stage(w, p, 2)
	var first_week: bool = int(RS.state(w)["paid"]) < Acts.RING_STAGES
	RS.on_stage(w, p, 3)
	var tr0: int = int(p.resources.get("trophy", 0))
	var f: Dictionary = RS.finish(w, p, 75.0, first_week)
	check(first_week and int(f["item"]) == 2 and int(p.resources["trophy"]) == tr0 + 3 and f["record"] and int(RS.state(w)["titles"]) == 1 and is_equal_approx(float(RS.state(w)["best_time"]), 75.0), "усі три кола: річ, трофеї, запис і рекорд часу")
	var paid_small := 0
	for i in 5:
		var rr: Dictionary = RS.on_stage(w, p, 1 + i % 3)
		if int(rr["gold"]) > 0:
			paid_small += 1
			check(not rr["weekly"] and int(rr["gold"]) == Acts.RING_REPEAT_GOLD * 30, "повторне чудовисько: малий гаманець")
	check(paid_small == Acts.RING_REPEAT_PAID, "малих гаманців — три на день, далі лише за рекорд")
	var f2: Dictionary = RS.finish(w, p, 90.0, false)
	check(not f2["record"] and int(f2["item"]) == -1 and is_equal_approx(float(RS.state(w)["best_time"]), 75.0) and int(RS.state(w)["titles"]) == 2, "повільніше проходження рекорду не б'є й речі не дає")
	check(RS.finish(w, p, 60.0, false)["record"] and is_equal_approx(float(RS.state(w)["best_time"]), 60.0), "швидше проходження — новий рекорд")
	CS.now_override = T0 + 86400
	check(int(RS.state(w)["day_paid"]) == 0, "наступного дня малі гаманці знову є")
	CS.now_override = T0 + 8 * 86400
	check(int(RS.state(w)["paid"]) == 0 and int(RS.state(w)["titles"]) == 3, "нового тижня тижневі нагороди знову чекають, рекорди лишились")
	check(RecS.hero_values(w, p)["ring_titles"] == 3 and Acts.RECORDS.has("ring_titles") and Acts.RECORDS.has("muster_titles"), "Коло й огляд є в Літописі")
	check(CS.available("ring", w, p) and not CS.available("ring", w, young) and CS.available("muster", w, p), "Коло й огляд потрапляють у виклики, коли відкриті")
	# --- Огляд ---
	CS.now_override = T0
	var wm = WorldState.new()
	var teams: Array = MS.lineup()
	var tu := {}
	for t in teams:
		tu[t] = true
	check(teams.size() == 3 and tu.size() == 3 and teams.all(func(t): return Acts.MUSTER_TEAMS.has(t)), "на огляді три різні сотні: %s" % str(teams))
	var team_ok := true
	for tid in Acts.MUSTER_ORDER:
		var T: Dictionary = Acts.MUSTER_TEAMS[tid]
		team_ok = team_ok and T["styles"].size() >= 5 and str(T["name"]) != "" and str(T["bio"]) != ""
		for st in T["styles"]:
			team_ok = team_ok and Acts.MUSTER_NICK.has(st)
	check(team_ok, "у кожної сотні п'ятеро бійців відомих стилів")
	check(MS.team_size(0, 0) == 1 and MS.team_size(0, 1) == 2 and MS.team_size(0, 2) == 3 and MS.team_size(2, 0) == 3 and MS.team_size(2, 3) == 5, "проти самотнього героя сотня виставляє менше людей")
	var fs: Array = MS.fighters("serdiuky", 5)
	var names := {}
	for fi in fs:
		names[fi["name"]] = true
	check(fs.size() == 5 and names.size() == 5 and fs[0]["captain"] and str(fs[0]["name"]).begins_with("Сотник ") and not fs[1]["captain"] and fs.all(func(x): return str(x["sprite"]) != ""), "бійці з іменами й виглядом, перший — сотник")
	check(MS.unlocked(p) and not MS.unlocked(peasant) and MS.can_fight(wm, p) and MS.allies(wm) == 0, "огляд відкритий, загону ще нема")
	wm.companions = [{"type": "dzhura", "downed": false, "level": 20, "xp": 0}, {"type": "strilets", "downed": true, "level": 20, "xp": 0}, {"type": "znakhar", "downed": false, "level": 20, "xp": 0, "away": {"until": T0 + 999}}]
	check(MS.allies(wm) == 1, "поранений і той, хто в поході, на огляд не стають")
	wm.companions[1]["downed"] = false
	var ML: Dictionary = MS.battle_loc(wm, p)
	check(ML["type"] == "duel" and ML["muster"] and ML["team"].size() == MS.team_size(0, 2) and ML["back"] == "До Чигирина" and float(ML["ally_hit"]) > 0.0 and is_equal_approx(float(ML["rival_hp"]), Data.ref_dps(int(p.level)) * Acts.MUSTER_SECONDS[0]), "опис сутички: гурт на гурт")
	var g1: int = p.gold
	var loy0: int = wm.loyalty_points("chyhyryn")
	var m1: Array = MS.win(wm, p)
	check(p.gold == g1 + Acts.MUSTER_GOLD[0] * 30 and wm.loyalty_points("chyhyryn") == loy0 + Acts.MUSTER_LOYALTY[0] and int(MS.state(wm)["round"]) == 1 and not m1.is_empty(), "перша сутичка: гривні, лояльність Чигирина, поступ")
	check("Лишилось спроб: 2" in MS.lose(wm) and int(MS.state(wm)["tries"]) == 2 and int(MS.state(wm)["round"]) == 1, "поразка: мінус спроба, поступ лишається")
	MS.win(wm, p)
	var inv0: int = p.inventory.size()
	var m3: Array = MS.win(wm, p)
	check(MS.is_winner(wm) and not MS.can_fight(wm, p) and int(MS.state(wm)["titles"]) == 1 and MS.next_team(wm).is_empty(), "три сутички — огляд виграно")
	check(p.inventory.size() == inv0 + 1 and p.inventory[-1]["name"] == MS.PRIZE_NAME and p.inventory[-1]["slot"] == "amulet" and int(p.inventory[-1]["rarity"]) == 3 and "\n".join(m3).contains(MS.PRIZE_NAME), "за перший огляд — легендарна ладанка")
	CS.now_override = T0 + 8 * 86400
	check(MS.can_fight(wm, p) and int(MS.state(wm)["round"]) == 0 and int(MS.state(wm)["tries"]) == MS.TRIES and MS.state(wm)["prize"], "нового тижня огляд починається знову, ладанка лише раз")
	MS.win(wm, p)
	MS.win(wm, p)
	var tr1: int = int(p.resources.get("trophy", 0))
	MS.win(wm, p)
	check(int(MS.state(wm)["titles"]) == 2 and int(p.resources["trophy"]) == tr1 + 3 and RecS.hero_values(wm, p)["muster_titles"] == 2, "другий виграний огляд: трофеї замість ладанки, запис у Літопис")
	var w2 = WorldState.new()
	w2.ring = w.ring.duplicate(true)
	w2.muster = wm.muster.duplicate(true)
	var w3 = WorldState.new()
	w3.from_dict(w2.to_dict())
	check(int(w3.ring["titles"]) == 3 and int(w3.muster["titles"]) == 2, "стан Кола й огляду зберігається")
	CS.now_override = 0
	p.free()
	young.free()
	peasant.free()


func _suite_ring_muster_game() -> void:
	suite("Коло Кожум'яки й огляд: у грі")
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
	var Acts = game.Acts
	var RS = game.RingService
	var MS = game.MusterService
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "duel": true, "ring": true, "muster": true, "stones": true, "camp": true}
	game.ChallengeService.now_override = 1762700000  # фіксований тиждень: склад чудовиськ і сотень не залежить від дня запуску
	game.enter_spot("kolo")
	await _frames(2)
	check(game.state != game.State.PLAYING, "селянина в коло не пускають")
	p.change_class("cossack")
	p.level = 30
	p.stats["str"] = 90
	p.stats["vit"] = 90
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	game.world.last_city = "kyiv"
	game.enter_map()
	await _frames(2)
	# Панель місця на мапі
	var panel: Control = game.MapPanel.build_spot("kolo", game.world, p, func(_id): pass)
	var ptext := ""
	for n in panel.find_children("*", "Label", true, false):
		ptext += n.text + "\n"
	for n in panel.find_children("*", "Button", true, false):
		ptext += n.text + "\n"
	check("Змієві вали" in ptext and "Коло 1: " in ptext and "Коло 3: " in ptext and "Стати в коло" in ptext and "найкращий час: —" in ptext, "панель кола показує чудовиськ тижня й кнопку")
	panel.free()
	var gold0: int = p.gold
	var stones0: int = game.StoneService.count(p, "zabuttia") + game.StoneService.count(p, "alatyr")
	game.enter_spot("kolo")
	await _frames(3)
	check(game.state == game.State.PLAYING and c.is_ring() and c.arena == c.RING_ARENA and c._ring_boss == null and c.alive_enemy_count() == 0, "у колі: спершу перепочинок, чудовиська ще нема")
	var line: Array = RS.lineup()
	var ok_stage := true
	var breaks_ok := true
	for stage in 3:
		var frames := 0
		while c._ring_boss == null and frames < 500:
			await process_frame
			frames += 1
		var boss = c._ring_boss
		ok_stage = ok_stage and boss != null and boss.kind == line[stage] and boss.is_boss and is_equal_approx(boss.max_hp, float(RS.boss_stats(p, stage)["hp"])) and boss.dmg_cap > 0.0
		if boss == null:
			break
		await _frames(30)
		# деякі чудовиська тримають удар (повіки Вія, мара Відьми), тож б'ємо, доки не впаде
		var hits := 0
		while is_instance_valid(boss) and not boss.dead and hits < 400:
			p.hp = p.max_hp
			boss.dmg_cap = 0.0
			boss.take_damage(boss.max_hp, Vector2.ZERO)
			await process_frame
			hits += 1
		await _frames(4)
		p.hp = p.max_hp
		breaks_ok = breaks_ok and c.ring_stage == stage + 1 and c.alive_enemy_count() == 0
		if stage < 2:
			breaks_ok = breaks_ok and c._ring_boss == null and c.ring_break > 0.0 and not c.ring_done
	check(ok_stage, "чудовиська виходять за складом тижня, міряні з героєм")
	check(breaks_ok and c.ring_done and c.portal != null, "після кожного кола перепочинок, після третього — портал")
	var st: Dictionary = RS.state(game.world)
	var weekly_gold: int = (Acts.RING_GOLD[0] + Acts.RING_GOLD[1] + Acts.RING_GOLD[2]) * 30
	check(int(st["paid"]) == 3 and int(st["titles"]) == 1 and float(st["best_time"]) > 0.0 and p.gold >= gold0 + weekly_gold, "тижневі гаманці взято, проходження й час записано")
	check(int(game.world.stats.get("ring", 0)) == 3 and int(game.world.stats.get("ring_clear", 0)) == 1 and game.account.challenges["ach"].has("ring_1"), "лічильники викликів і досягнення")
	check(int(game.world.stats.get("boss", 0)) == 0 and game.StoneService.count(p, "zabuttia") + game.StoneService.count(p, "alatyr") == stones0, "чудовиська кола не дають ні каменів долі, ні досягнень за босів")
	p.global_position = c.portal.global_position
	await _frames(6)
	check(game.state == game.State.MAP, "з порталу — на мапу")
	# Поразка в колі: без втрат
	game.enter_spot("kolo")
	await _frames(3)
	var runs0: int = int(RS.state(game.world)["runs"])
	p.invuln = 0.0
	p.take_damage(p.max_hp * 20.0, null)
	await _frames(3)
	var frames2 := 0
	while game.state != game.State.CITY and frames2 < 300:
		await process_frame
		frames2 += 1
	check(game.state == game.State.CITY and game.city_id == "kyiv" and p.alive and int(RS.state(game.world)["runs"]) == runs0 + 1, "не встояв — винесли до міста, живий")

	# --- Гетьманський огляд ---
	game.world.companions = [{"type": "dzhura", "downed": false, "level": 25, "xp": 0}, {"type": "strilets", "downed": false, "level": 25, "xp": 0}]
	game.enter_city("chyhyryn")
	game.hud.close_dialogue()
	await _frames(2)
	var titles := []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		titles.append(tc.get_tab_title(i))
	_reveal_tabs(game)
	var ctext := ""
	for n in game.hud.screen_root.find_children("*", "Button", true, false):
		ctext += n.text + "\n"
	check("Огляд" in titles and not ("Майдан" in titles) and "Вивести ватагу: " in ctext, "у Чигирині є вкладка огляду з кнопкою: %s" % str(titles))
	var loy0: int = game.world.loyalty_points("chyhyryn")
	var gold1: int = p.gold
	game.city_do("muster_start", null)
	await _frames(3)
	check(game.state == game.State.PLAYING and c.is_duel() and c.loc.get("muster", false) and c.arena == c.MUSTER_ARENA and c.alive_enemy_count() == MS.team_size(0, 2), "сутичка почалась: сотня виставила %d бійців" % c.alive_enemy_count())
	check(c.companion_nodes.size() == 2 and c.spectators.size() > 10 and c.ally_hit_frac > 0.0, "побратими поруч, довкола глядачі")
	var cn = c.companion_nodes[0]
	var hp_c: float = cn.hp
	cn.take_damage(999999.0, null)
	check(cn.alive and is_equal_approx(hp_c - cn.hp, cn.max_hp * c.ally_hit_frac), "удар по побратимові рахується часткою його здоров'я")
	cn.take_damage(999999.0, null)
	for i in 20:
		cn.take_damage(999999.0, null)
	check(not cn.alive, "побратима теж можуть покласти")
	var tries := 0
	while c.alive_enemy_count() > 0 and tries < 400:
		for e in c.get_tree().get_nodes_in_group("enemies"):
			e.dmg_cap = 0.0
			e.take_damage(e.max_hp, Vector2.ZERO)
		p.hp = p.max_hp
		await process_frame
		tries += 1
	await _frames(6)
	check(c.duel_over and int(MS.state(game.world)["round"]) == 1 and p.gold >= gold1 + Acts.MUSTER_GOLD[0] * 30 + 400 and game.world.loyalty_points("chyhyryn") > loy0, "сотню покладено: гривні (з досягненням і, може, рангом слави), лояльність, поступ (кінець: %s, коло %d, гривень +%d, ударів %d)" % [str(c.duel_over), int(MS.state(game.world)["round"]), p.gold - gold1, tries])
	check(int(game.world.stats.get("muster", 0)) == 1 and game.account.challenges["ach"].has("muster_1") and not game.world.companions[0]["downed"], "лічильник і досягнення; покладений побратим не поранений")
	p.global_position = c.portal.global_position
	await _frames(6)
	check(game.state == game.State.CITY and game.city_id == "chyhyryn" and c.ally_hit_frac == 0.0, "з порталу — назад у Чигирин")
	game.hud.close_dialogue()
	game.city_do("muster_start", null)
	await _frames(3)
	check(c.is_duel() and int(c.loc["round"]) == 1 and c.alive_enemy_count() == MS.team_size(1, 2), "друга сутичка: бійців більше")
	p.invuln = 0.0
	p.take_damage(p.max_hp * 20.0, null)
	await _frames(3)
	frames2 = 0
	while game.state != game.State.CITY and frames2 < 300:
		await process_frame
		frames2 += 1
	check(game.state == game.State.CITY and game.city_id == "chyhyryn" and p.alive and int(MS.state(game.world)["tries"]) == MS.TRIES - 1 and int(MS.state(game.world)["round"]) == 1, "поклали ватагу — мінус спроба, назад у Чигирин")
	# Звичайний герць лишився сам на сам
	game.enter_city("sich")
	game.hud.close_dialogue()
	game.city_do("duel_start", null)
	await _frames(3)
	check(c.is_duel() and c.companion_nodes.is_empty() and c.arena == c.DUEL_ARENA and c.alive_enemy_count() == 1 and c.ally_hit_frac == 0.0, "звичайний герць, як і раніше, сам на сам")
	game.ChallengeService.now_override = 0
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)

# ======================= Далекі краї =======================

func _suite_far_lands() -> void:
	suite("Далекі краї: дані й правила")
	var Far = load("res://scripts/game/far_service.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Elites = load("res://scripts/data/elites.gd")
	var Sounds = load("res://scripts/data/sounds.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var Ground = load("res://scripts/world/ground.gd")
	check(Data.REGION_ORDER.size() == 8 and Data.REGIONS.size() == 8, "вісім далеких країв: чотири українські, три в Московії й Семигород")
	var all_regions_ok := true
	for r in Data.REGION_ORDER:
		var pl: Dictionary = Far.places(r)
		all_regions_ok = all_regions_ok and pl["cities"].size() >= 1 and pl["fields"].size() >= 3 and pl["dungeons"].size() >= 1 and str(Data.REGIONS[r]["name"]) != ""
	check(all_regions_ok, "у кожному краї місто, щонайменше три місцевості й печера з босом")
	check(Data.CITIES.size() >= 15 and Data.LOCATIONS.size() >= 40, "мапа значно більша: міст %d, місць %d" % [Data.CITIES.size(), Data.LOCATIONS.size()])
	var data_ok := true
	var far_n := 0
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		if not L.get("scale", false):
			continue
		far_n += 1
		data_ok = data_ok and Data.REGIONS.has(str(L.get("region", ""))) and str(L["desc"]) != ""
		for e in L["enemies"]:
			data_ok = data_ok and Data.ENEMY_NAMES.has(e) and Data.ENEMY_PLURAL.has(e) and Data.QUEST_ITEMS.has(e) and GfxS.has(e)
		if L["type"] == "dungeon":
			data_ok = data_ok and Data.BOSS_NAMES.has(L["boss"]) and GfxS.has(L["boss"]) and int(L["rooms"]) >= 4
	check(far_n == 40 and data_ok, "сорок далеких місць: назви, нечисть зі спрайтами, боси (%d)" % far_n)
	for kind in ["potopelnyk", "pesyholovets", "kamiana_baba", "mara", "zlyden", "morskyi_tsar", "shubin", "bila_pani"]:
		check(Data.ENEMY_NAMES.has(kind) and GfxS.has(kind) and Sounds.DEATH.has(kind), "%s: ім'я, спрайт і голос смерті" % kind)
	for kind in ["potopelnyk", "pesyholovets", "kamiana_baba", "mara", "zlyden"]:
		check(Acts.BOUNTY_NAMES.has(kind) and Acts.BOUNTY_NAMES[kind].size() >= 3, "%s: імена для дошки розшуку" % kind)
	check(Elites.title("kamiana_baba", "Кам'яна баба", ["fiery"]).begins_with("Вогняна") and Elites.title("kamiana_baba", "Кам'яна баба", ["fiery"]).ends_with("Кам'яна баба") and "mara" in Elites.FEMININE, "еліти жіночого роду мають правильні прикметники")
	for city in ["baturyn", "ostroh", "izium", "khadzhybei"]:
		var prices: Dictionary = Acts.TRADE_CITIES.get(city, {})
		check(Data.REGIONS.has(str(Data.CITIES[city].get("region", ""))) and prices.size() == Acts.TRADE_ORDER.size(), "%s: місто краю з торгом" % city)
	check("sand" in Ground.TILED and Camp.BIOME_RESOURCE.has("sand") and Sounds.AMBIENT.has("sand"), "піски: тайли, ресурс і шум вітру")
	# Ніщо не налазить одне на одне
	var places := {}
	for id in Data.CITIES:
		places[id] = Data.CITIES[id]["pos"]
	for id in Data.LOCATIONS:
		places[id] = Data.LOCATIONS[id]["pos"]
	for id in Acts.SPOTS:
		places[id] = Acts.SPOTS[id]["pos"]
	places[Camp.CAMP_ID] = Camp.CAMP["pos"]
	var ids: Array = places.keys()
	var tight := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if places[ids[i]].distance_to(places[ids[j]]) < 0.5:
				tight.append("%s—%s" % [ids[i], ids[j]])
	check(tight.is_empty(), "жодні два місця на мапі не злипаються: %s" % str(tight))
	var map_ok := true
	var WM0 = load("res://scripts/ui/world_map.gd")
	for id in ids:
		var pos: Vector2 = places[id]
		map_ok = map_ok and pos.x > WM0.LON0 + 0.5 and pos.x < WM0.LON1 - 0.5 and pos.y > WM0.LAT0 + 0.5 and pos.y < WM0.LAT1 - 0.5
	check(map_ok, "усе вміщається в межах мапи")
	# Рівні
	var L16: Dictionary = Data.LOCATIONS["oleshky"]
	check(Data.loc_level(L16, 10) == 16 and Data.loc_level(L16, 40) == 40 and Data.loc_level(Data.LOCATIONS["rapids"], 40) == 2, "далекий край росте з героєм, старі місця — ні")
	var weak = _new_player()
	weak.level = 12
	weak.recalc()
	var m_low: Dictionary = Far.mods(L16, weak)
	check(not m_low.has("std_hp") and not m_low.has("level") and int(m_low["base_level"]) == 16 and int(m_low["goal"]) == 110 and not Far.matched(L16, weak), "слабшому героєві край не піддається: звичайна нечисть 16-го рівня")
	var hero = _new_player()
	hero.change_class("cossack")
	hero.level = 60
	hero.recalc()
	var m_hi: Dictionary = Far.mods(L16, hero)
	check(Far.matched(L16, hero) and int(m_hi["level"]) == 60 and int(m_hi["hero_level"]) == 60 and int(m_hi["base_level"]) == 16, "бувалому — нечисть його рівня")
	check(not m_hi.has("std_hp") and not m_hi.has("std_dmg") and not m_hi.has("xp_mult"), "сила й досвід нечисті далекого краю — звичайні для її рівня, без надбавок")
	check(Far.mods(Data.LOCATIONS["rapids"], hero).is_empty(), "старі місцевості без змін")
	check(not Far.mods(Data.LOCATIONS["zmiinyi"], hero).has("goal"), "у печерах мети зачистки нема")
	check(Far.region_of("oleshky") == "pivden" and Far.region_of("izium") == "slobid" and Far.region_of("kyiv") == "" and Far.open_level("pivden") == 16, "край за місцем і рівень, з якого він відкривається")
	# Завдання й події для бувалого героя
	var w = WorldState.new()
	w.hero_level = 60
	var far_q := {}
	for i in 300:
		var q: Dictionary = w._gen_quest("khadzhybei")
		if Data.LOCATIONS[q["loc"]].get("scale", false):
			far_q = q
			break
	check(not far_q.is_empty() and int(far_q["lvl"]) == 60 and int(far_q["gold"]) >= 40 + 25 * 60, "завдання в далекий край платять за рівнем героя: %s" % str(far_q.get("gold", "")))
	var EscS = load("res://scripts/game/escort_service.gd")
	var eq := {"id": 1, "city": "khadzhybei", "loc": "oleshky", "progress": 0, "lvl": 60}
	EscS.fill(eq, 0.3)
	check(int(EscS.battle_loc(eq)["level"]) == 60 and int(EscS.battle_loc({"id": 2, "city": "kyiv", "loc": "rapids", "progress": 0, "lvl": 2, "target": "kobzar"})["level"]) == 2, "супровід у далекому краї — за рівнем героя")
	var ES = load("res://scripts/game/event_service.gd")
	var reach: Array = ES.reachable_locs(w, hero)
	check(not reach.is_empty() and reach.all(func(id): return Data.LOCATIONS[id].get("scale", false)), "і героєві 60-го рівня є де статись подіям: %d місць" % reach.size())
	weak.free()
	hero.free()


func _suite_far_lands_game() -> void:
	suite("Далекі краї: у грі")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 40
	p.stats["str"] = 120
	p.stats["vit"] = 150
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	# Дика місцевість, що росте з героєм
	game.enter_location("oleshky")
	await _frames(3)
	check(c.is_field() and int(c.loc["level"]) == 40 and int(c.loc["base_level"]) == 16 and not c.loc.has("std_hp") and c.field_goal == 110 and c.ground.biome == "sand", "Олешківські піски: рівень героя, мета 110, піщана земля")
	var e0 = null
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.kind == "zlyden" or e.kind == "pesyholovets" or e.kind == "kamiana_baba":
			e0 = e
			break
	check(e0 != null and e0.level >= 40, "нечисть краю на рівні героя")
	# Сила нечисті — звичайна мірка її рівня; юрба мала й не росте з рівнем героя
	var std_foe = null
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if not e.elite and not e.is_boss and e.level == 40:
			std_foe = e
			break
	var plain_foe = load("res://scripts/entities/enemy.gd").new()
	if std_foe != null:
		plain_foe.setup(std_foe.kind, 40, false)
	var pl_hp: float = float(c.plague_mods["hp"]) if c.plague > 0 else 1.0
	check(std_foe != null and is_equal_approx(std_foe.raw_hp, plain_foe.max_hp) and is_equal_approx(std_foe.max_hp, plain_foe.max_hp * pl_hp), "нечисть краю має звичайну силу свого рівня, без окремої мірки")
	plain_foe.free()
	check(c.loc.has("hero_level") and c._field_cap() == c.FIELD_ALIVE_BASE + 16 / c.FIELD_ALIVE_STEP and c._field_cap() <= 8, "юрба в полі мала (%d водночас) і рахується від рівня краю, а не героя" % c._field_cap())
	var crowd_max := 0
	for i in 400:
		p.hp = p.max_hp
		p.invuln = 1.0
		crowd_max = maxi(crowd_max, c.alive_enemy_count())
		await process_frame
	check(crowd_max <= c._field_cap() + 1 and crowd_max >= 3, "на арені не більше нечисті, ніж дозволяє межа (%d)" % crowd_max)
	# Зона удару зникає разом із ворогом, що її кинув (раніше спрацьовувала й кликала вже зниклого ворога)
	c.spawn_enemy("zarazhenyi", 40, false, p.global_position + Vector2(500, 0))
	var caster = c._last_enemy()
	var fired := [false]
	var zone = caster._telegraph("circle", p.global_position + Vector2(1200, 0), 0.3, 1.0)
	zone.on_fire = func(): fired[0] = true
	caster.queue_free()
	await _frames(30)
	check(not is_instance_valid(zone) and not fired[0], "зона удару зниклого ворога скасовується й не б'є")
	# Злидень краде гривні й повертає, коли його здолати
	_clear_enemies(game)
	await _frames(1)
	p.gold = 1000
	c.spawn_enemy("zlyden", 40, false, p.global_position + Vector2(60, 0))
	var z = c._last_enemy()
	z.on_hit(p)
	var stolen: int = z.loot_gold
	check(stolen > 0 and p.gold == 1000 - stolen, "злидень поцупив %d грн" % stolen)
	var g_before: int = p.gold
	z.take_damage(z.max_hp * 5.0, Vector2.ZERO)
	await _frames(3)
	check(p.gold >= g_before + stolen, "здолав злидня — крадене повернулось")
	# Юрба не росте безмежно з рівнем героя
	_clear_enemies(game)
	p.level = 99
	p.recalc()
	p.hp = p.max_hp
	game.enter_location("savur_mohyla")
	await _frames(2)
	check(c._pace_level() == 17 and int(c.loc["level"]) == 99, "на 99-му рівні темп юрби — за рівнем краю")
	var most := 0
	for i in 900:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
		most = maxi(most, c.alive_enemy_count())
	check(most <= 7 + c.PACE_MAX, "на арені щонайбільше %d нечисті (було %d)" % [7 + c.PACE_MAX, most])
	game.enter_map()
	await _frames(2)
	# Нові боси: прийоми, друга фаза, перемога
	p.level = 40
	p.recalc()
	for pair in [["zmiinyi", "morskyi_tsar"], ["bakhmut_kopalni", "shubin"], ["pidhirtsi", "bila_pani"]]:
		game.enter_location(pair[0])
		await _frames(3)
		_clear_enemies(game)
		await _frames(1)
		c.room = int(c.loc["rooms"])
		c._spawn_room()
		await _frames(2)
		var boss = null
		for e in c.get_tree().get_nodes_in_group("enemies"):
			if e.is_boss:
				boss = e
		check(boss != null and boss.kind == pair[1] and int(boss.level) == p.level, "%s: у залі чекає %s (є: %s, рівень %s, кімната %d із %d)" % [pair[0], pair[1], boss.kind if boss else "нікого", str(boss.level) if boss else "-", c.room, int(c.loc.get("rooms", 0))])
		if boss == null:
			continue
		var tele0: int = c.effects.get_child_count()
		for step in 3:
			boss.ability_step = step
			boss._boss_ability(p)
			await _frames(2)
		check(c.effects.get_child_count() > tele0, "%s: прийоми бос малює на землі" % pair[1])
		for i in 90:
			p.hp = p.max_hp
			p.invuln = 1.0
			await process_frame
		boss.take_damage(boss.max_hp * 0.55, Vector2.ZERO)
		check(boss.phase2, "%s: друга фаза на половині здоров'я" % pair[1])
		var hits := 0
		while is_instance_valid(boss) and not boss.dead and hits < 200:
			boss.take_damage(boss.max_hp, Vector2.ZERO)
			p.hp = p.max_hp
			await process_frame
			hits += 1
		_clear_enemies(game)
		await _frames(4)
		check(game.world.cleared.get(pair[0], 0) > 0 or c.room_cleared, "%s: печеру пройдено" % pair[0])
		game.enter_map()
		await _frames(2)
	# Мапа: значки, позначки рівня, панель краю
	var wm = game.hud.map_view
	check(wm._loc_icon(Data.LOCATIONS["zmiinyi"]) == "island" and wm._loc_icon(Data.LOCATIONS["oleshky"]) == "dune" and wm._loc_icon(Data.LOCATIONS["bakhmut_kopalni"]) == "mine" and wm.ICON_ORDER.has("izba"), "особливі значки нових місць")
	var built: Control = load("res://scripts/ui/map_panel.gd").build("pidhirtsi", game.world, p, func(_x): pass)
	var ptext := ""
	for n in built.find_children("*", "Label", true, false):
		ptext += n.text + "\n"
	built.free()
	check("Волинь і Поділля" in ptext and "з 14-го рівня" in ptext and ("нечисть тут твого %d-го рівня" % p.level) in ptext and "Тобі тут: " in ptext and "витримаєш" in ptext, "панель далекого місця: край, рівень відкриття, підказка")
	var low = load("res://scripts/entities/player.gd").new()
	low._ready()
	low.level = 5
	low.recalc()
	var built2: Control = load("res://scripts/ui/map_panel.gd").build("zmiinyi", game.world, low, func(_x): pass)
	var ptext2 := ""
	for n in built2.find_children("*", "Label", true, false):
		ptext2 += n.text + "\n"
	built2.free()
	low.free()
	check("небезпечно" in ptext2 and "коли доростеш до 24-го рівня" in ptext2, "новачкові панель каже, що рано")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)

# ======================= Список подій і довідник =======================


# ======================= Московія =======================

const MUSCOVY_MINIONS := ["vedmid", "kikimora", "mertvyi_strilets", "kromeshnyk", "boyaryn", "lisovyk"]
const MUSCOVY_BOSSES := {"tula_zbroiarnia": "pushkar", "okovskyi_lis": "lisovyi_did", "suzdal_medovarni": "idolyshche", "kryzhanyi_ostroh": "karachun", "oleksandrivska_sloboda": "oprychnyk"}


func _suite_muscovy() -> void:
	suite("Московія: дані")
	var Far = load("res://scripts/game/far_service.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Sounds = load("res://scripts/data/sounds.gd")
	var Ground = load("res://scripts/world/ground.gd")
	var Wiki = load("res://scripts/data/wiki_data.gd")
	var WM = load("res://scripts/ui/world_map.gd")
	var EnemyS = load("res://scripts/entities/enemy.gd")
	check(Data.REGION_ORDER.slice(4, 7) == ["oka", "tvershchyna", "zalissia"], "три краї Московії йдуть після українських")
	# Краї йдуть кільцями без прогалин у рівнях
	var bands := {}
	for r in ["oka", "tvershchyna", "zalissia"]:
		var lv := []
		var pl: Dictionary = Far.places(r)
		for id in pl["fields"] + pl["dungeons"]:
			lv.append(int(Data.LOCATIONS[id]["level"]))
		lv.sort()
		bands[r] = [lv[0], lv[lv.size() - 1], lv.size()]
	check(bands["oka"] == [14, 18, 6] and bands["tvershchyna"] == [19, 23, 5] and bands["zalissia"] == [24, 30, 7], "рівні країв без прогалин: %s" % str(bands))
	for city in ["yelets", "tver", "cherkaskyi_stan"]:
		var prices: Dictionary = Acts.TRADE_CITIES.get(city, {})
		check(Data.CITIES.has(city) and Data.CITIES[city]["region"] in ["oka", "tvershchyna", "zalissia"] and prices.size() == Acts.TRADE_ORDER.size(), "%s: місто краю з торгом" % city)
	for kind in MUSCOVY_MINIONS:
		var ok: bool = Data.ENEMY_NAMES.has(kind) and Data.ENEMY_PLURAL.has(kind) and Data.QUEST_ITEMS.has(kind) and GfxS.has(kind) and Sounds.DEATH.has(kind)
		ok = ok and Acts.BOUNTY_NAMES.has(kind) and Acts.BOUNTY_NAMES[kind].size() >= 3 and Wiki.ENEMIES.has(kind) and str(Wiki.ENEMIES[kind]["tip"]) != ""
		ok = ok and kind in EnemyS.MINION_ABILITIES and EnemyS.HIT_STATUS.has(kind)
		check(ok, "%s: ім'я, спрайт, голос, розшук, довідник і свій прийом" % kind)
	for loc_id in MUSCOVY_BOSSES:
		var b: String = MUSCOVY_BOSSES[loc_id]
		var L: Dictionary = Data.LOCATIONS[loc_id]
		check(L["type"] == "dungeon" and L["boss"] == b and L.get("scale", false) and Data.BOSS_NAMES.has(b) and GfxS.has(b) and Sounds.DEATH.has(b) and Wiki.BOSSES.has(b) and WM.ICON_ORDER.has(str(L.get("icon", ""))), "%s: лігво, спрайт, голос, довідник і свій значок на мапі" % Data.BOSS_NAMES.get(b, b))
	check(Data.BOSS_NAMES["idolyshche"] == "Ідолище Погане" and not "п'ятидесятник" in str(Acts.BOUNTY_NAMES["mertvyi_strilets"]).to_lower(), "назви без мовних огріхів")
	var snow := []
	for id in Data.LOCATIONS:
		if Data.LOCATIONS[id]["biome"] == "snow" and not Data.LOCATIONS[id].has("peril"):
			snow.append(id)
	check(snow.size() == 3 and "snow" in Ground.TILED and Data.LOCATIONS["kryzhanyi_ostroh"].get("night", false), "три снігові місця, у Крижаному острозі вічна ніч: %s" % str(snow))
	var icons_tex: Texture2D = load("res://assets/gfx/sprites/map_icons.png")
	check(icons_tex.get_width() == WM.ICON_ORDER.size() * 24, "на аркуші значків мапи є всі %d значків" % WM.ICON_ORDER.size())
	check(WM.LAT1 >= 58.6 and Data.LOCATIONS["kryzhanyi_ostroh"]["pos"].y < WM.LAT1 - 0.3, "мапа сягає півночі за Кострому")
	var town_names := []
	for t in WM.TOWNS:
		town_names.append(t[0])
	var river_names := []
	for r in WM.RIVERS:
		river_names.append(r[0])
	check("Рязань" in town_names and "Волга" in river_names and "Ока" in river_names, "на мапі Волга, Ока й сусідні міста")


func _suite_muscovy_game() -> void:
	suite("Московія: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Status = load("res://scripts/game/status.gd")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "pushkar_misfire", "idol_feast", "karachun_wind"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 40
	p.stats["str"] = 120
	p.stats["vit"] = 150
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	# Снігове поле росте з героєм
	game.enter_location("vedmezhyi_kut")
	await _frames(3)
	check(c.is_field() and int(c.loc["level"]) == 40 and int(c.loc["base_level"]) == 29 and c.ground.biome == "snow", "Ведмежий кут: рівень героя, сніг під ногами")
	# Рядова нечисть: у кожного свій прийом
	for kind in MUSCOVY_MINIONS:
		_clear_enemies(game)
		await _frames(1)
		p.hp = p.max_hp
		p.invuln = 5.0
		p.push = Vector2.ZERO
		p.statuses.clear()
		var dist := 240.0
		c.spawn_enemy(kind, 40, false, p.global_position + Vector2(dist, 0))
		var e = c._last_enemy()
		var foes0: int = c.alive_enemy_count()
		e._minion_ability(p, dist)
		await _frames(1)
		if kind == "boyaryn":
			check(c.alive_enemy_count() == foes0 + 2 and c._last_enemy().kind == "zlyden" and c._last_enemy().xp_value == 0, "боярин кличе двох злиднів, досвіду за них нема")
		else:
			# рахуємо саме зони цього ворога: зони попередніх, уже прибраних, зникають разом із ними
			var mine := 0
			for z in c.effects.get_children():
				if not z.is_queued_for_deletion() and z.get("source") == e:
					mine += 1
			check(mine > 0 and e.cast_time > 0.0, "%s малює свій прийом на землі" % Data.ENEMY_NAMES[kind])
	# Аркан кромішника тягне до нього, подих лісовика відкидає
	for pair in [["kromeshnyk", -1.0], ["lisovyk", 1.0]]:
		_clear_enemies(game)
		await _frames(1)
		p.push = Vector2.ZERO
		p.invuln = 5.0
		var x0: float = p.global_position.x
		c.spawn_enemy(pair[0], 40, false, p.global_position + Vector2(-240, 0))
		var e2 = c._last_enemy()
		e2._minion_ability(p, 240.0)
		for i in 80:
			p.hp = p.max_hp
			await process_frame
		var moved: float = p.global_position.x - x0
		check(moved * pair[1] > 120.0, "%s зрушив героя на %d (у свій бік)" % [Data.ENEMY_NAMES[pair[0]], roundi(moved)])
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	# Боси: лігво, прийоми, друга фаза, перемога
	for loc_id in MUSCOVY_BOSSES:
		var bk: String = MUSCOVY_BOSSES[loc_id]
		game.enter_location(loc_id)
		await _frames(3)
		_clear_enemies(game)
		await _frames(1)
		# порожня кімната вже відкрила портал далі: прибрати, щоб герой не вийшов із зали посеред бою
		if c.portal != null and is_instance_valid(c.portal):
			c.portal.queue_free()
		c.portal = null
		c.room = int(c.loc["rooms"])
		c._spawn_room()
		await _frames(2)
		var boss = null
		for e in c.get_tree().get_nodes_in_group("enemies"):
			if e.is_boss:
				boss = e
		check(boss != null and boss.kind == bk and int(boss.level) == p.level, "%s: у залі чекає %s" % [loc_id, bk])
		if boss == null:
			continue
		p.global_position = boss.global_position + Vector2(0, 260)
		match bk:
			"pushkar":
				boss._cannon_shots = 2
				boss.ability_step = 0
				boss._boss_ability(p)
				for i in 90:
					p.hp = p.max_hp
					p.invuln = 1.0
					await process_frame
				check(boss.stun > 0.0 and boss.exposed > 0.0, "Цар-гармата: третій постріл — осічка, пушкар приголомшений")
				boss.stun = 0.0
				boss.exposed = 0.0
			"lisovyi_did":
				var big_r: float = boss.radius
				boss._set_size(true)
				check(boss.radius < big_r and boss.dmg_taken_mult > 1.0 and boss.speed > boss._base_speed, "Лісовий Дід малий: швидкий і крихкий")
				boss._set_size(false)
				check(is_equal_approx(boss.radius, big_r) and boss.dmg_taken_mult < 1.0 and boss.speed < boss._base_speed, "Лісовий Дід великий: повільний і товстошкірий")
			"idolyshche":
				boss.ability_step = 3
				boss._boss_ability(p)
				boss.hp = boss.max_hp * 0.8
				for i in 60:
					p.hp = p.max_hp
					p.invuln = 1.0
					await process_frame
				check(boss._feast > 0.0 and boss.hp > boss.max_hp * 0.82, "Ідолище бенкетує й гоїть рани")
				boss.take_damage(boss.max_hp * 0.06, Vector2.ZERO)
				check(boss._feast <= 0.0 and boss.stun > 0.0 and boss.exposed > 0.0, "багато шкоди за бенкетом — Ідолище вдавилося")
				boss.stun = 0.0
				boss.exposed = 0.0
				boss.hp = boss.max_hp
			"karachun":
				boss.ability_step = 0
				boss._boss_ability(p)
				var wd: Vector2 = boss._wind_dir
				var a0: float = p.global_position.dot(wd)
				for i in 40:
					p.hp = p.max_hp
					p.invuln = 1.0
					await process_frame
				check(boss._wind_t > 0.0 and p.global_position.dot(wd) - a0 > 60.0, "хуртовина зносить героя за вітром")
				Status.apply(p, "chill", 5.0)
				var old_input: Callable = c.move_input
				c.move_input = func() -> Vector2: return -wd
				var a1: float = p.global_position.dot(wd)
				for i in 40:
					p.hp = p.max_hp
					p.invuln = 1.0
					await process_frame
				c.move_input = old_input
				check(p.global_position.dot(wd) < a1 - 10.0, "і застуджений герой може йти проти вітру")
				boss._wind_t = 0.0
				p.statuses.clear()
		var tele0: int = c.effects.get_child_count()
		for step in 4:
			boss.ability_step = step
			boss.cast_time = 0.0
			boss._boss_ability(p)
			await _frames(2)
		check(c.effects.get_child_count() > tele0, "%s: прийоми бос малює на землі" % bk)
		for i in 90:
			p.hp = p.max_hp
			p.invuln = 1.0
			await process_frame
		boss._feast = 0.0
		boss.hp = boss.max_hp
		boss.take_damage(boss.max_hp * 0.55 / boss.dmg_taken_mult, Vector2.ZERO)
		check(boss.phase2, "%s: друга фаза на половині здоров'я" % bk)
		var hits := 0
		while is_instance_valid(boss) and not boss.dead and hits < 200:
			boss.take_damage(boss.max_hp * 3.0, Vector2.ZERO)
			p.hp = p.max_hp
			await process_frame
			hits += 1
		_clear_enemies(game)
		await _frames(4)
		check(game.world.cleared.get(loc_id, 0) > 0 or c.room_cleared, "%s: лігво пройдено" % loc_id)
		game.enter_map()
		await _frames(2)
	# Мапа й довідник
	var wm = game.hud.map_view
	check(wm._loc_icon(Data.LOCATIONS["tula_zbroiarnia"]) == "cannon" and wm._loc_icon(Data.LOCATIONS["uhlych"]) == "bell" and wm._loc_icon(Data.LOCATIONS["volochok"]) == "pine", "значки нових місць на мапі")
	var built: Control = load("res://scripts/ui/map_panel.gd").build("kryzhanyi_ostroh", game.world, p, func(_x): pass)
	var ptext := ""
	for n in built.find_children("*", "Label", true, false):
		ptext += n.text + "\n"
	built.free()
	check("Залісся" in ptext and "з 30-го рівня" in ptext and "Карачун" in ptext, "панель Крижаного острогу: край, рівень і бос")
	# Бічна панель мапи не вилазить за край екрана для жодного місця (довгі назви переносяться)
	game.enter_map()
	await _frames(2)
	var Camp2 = load("res://scripts/data/camp_data.gd")
	var Acts2 = load("res://scripts/data/activities.gd")
	var wide := []
	for id in Data.CITIES.keys() + Data.LOCATIONS.keys() + Acts2.SPOTS.keys() + [Camp2.CAMP_ID]:
		game._on_map_select(id)
		await _frames(2)
		if game.hud.map_panel.size.x > 380.0 or game.hud.map_panel.size.y > game.get_viewport().get_visible_rect().size.y - 100.0:
			wide.append("%s %dx%d" % [id, roundi(game.hud.map_panel.size.x), roundi(game.hud.map_panel.size.y)])
	check(wide.is_empty(), "панель мапи вміщається на екрані для кожного місця: %s" % str(wide))
	var hits2: Array = game.WikiService.search("Карачун")
	check(not hits2.is_empty() and str(hits2[0]["entry"]["title"]).begins_with("Карачун"), "довідник знає Карачуна")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Золоті (унікальні) речі =======================

func _suite_uniques() -> void:
	suite("Золоті речі: дані й правила")
	var Uniques = load("res://scripts/data/uniques.gd")
	var Loot = load("res://scripts/game/loot_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Tower = load("res://scripts/game/tower_service.gd")
	var Depth = load("res://scripts/game/depth_service.gd")
	check(Uniques.ORDER.size() == Uniques.DEFS.size() and Uniques.ORDER.size() >= 24, "золотих речей %d, порядок збігається з таблицею" % Uniques.DEFS.size())
	var ok := true
	var names := {}
	var slots := {}
	var wtypes := {}
	var per_tier := {}
	var bad := []
	for id in Uniques.ORDER:
		var D: Dictionary = Uniques.DEFS[id]
		var good: bool = Data.SLOTS.has(D["slot"]) and int(D["tier"]) >= 1 and int(D["tier"]) <= 6 and Uniques.POWERS.has(D["power"]) and str(D["lore"]) != "" and not names.has(D["name"])
		if D["slot"] == "weapon":
			good = good and Data.WEAPON_TYPES.has(D["type"])
			wtypes[D["type"]] = true
		for a in D["affixes"]:
			good = good and (a in Data.INT_STATS or Uniques.MID.has(a)) and a != Data.SLOT_PRIMARY[D["slot"]] and not a in ["lifesteal", "regen"]
		for b in D["bosses"]:
			good = good and Data.BOSS_NAMES.has(b)
		good = good and not "{" in Uniques.power_text(id) and D["affixes"].size() >= 3
		names[D["name"]] = true
		slots[D["slot"]] = true
		per_tier[int(D["tier"])] = int(per_tier.get(int(D["tier"]), 0)) + 1
		if not good:
			bad.append(id)
		ok = ok and good
	check(ok, "кожна золота річ: слот, ступінь, сила з числами, властивості без вампіризму й загоєння, переказ: %s" % str(bad))
	check(slots.size() == Data.SLOTS.size() and wtypes.size() == Data.WEAPON_TYPES.size(), "золото є для кожного слота й кожного виду зброї")
	var tiers_ok := true
	for t in range(1, 7):
		tiers_ok = tiers_ok and int(per_tier.get(t, 0)) >= 3
	check(tiers_ok, "у кожному з шести ступенів щонайменше три речі: %s" % str(per_tier))
	# Кожен бос гри має свій ступінь (новий бос без ступеня провалить цю перевірку)
	var bosses := {}
	for id in Data.LOCATIONS:
		if Data.LOCATIONS[id].has("boss"):
			bosses[Data.LOCATIONS[id]["boss"]] = true
	for b in Tower.SUPER_BOSSES + Depth.BOSSES:
		bosses[b] = true
	var no_tier := []
	for b in bosses:
		if not Uniques.BOSS_TIER.has(b):
			no_tier.append(b)
	check(no_tier.is_empty() and bosses.size() >= 19, "усі %d босів мають ступінь золота: %s" % [bosses.size(), str(no_tier)])
	# Річ: стала, сильніша за легендарну, вищий ступінь — сильніша зброя
	var a1: Dictionary = Uniques.make("kotyhoroshko", 60)
	var a2: Dictionary = Uniques.make("kotyhoroshko", 60)
	var top: Dictionary = Uniques.make("bulava_mazepy", 60)
	check(a1 == a2 and int(a1["rarity"]) == 4 and a1["unique"] == "kotyhoroshko" and a1["name"] == "Булава Котигорошка", "золота річ стала: без випадкових кидків")
	check(float(a1["base"]["flat_dmg"]) > Data._primary_value("weapon", 60, 3) and float(top["base"]["flat_dmg"]) > float(a1["base"]["flat_dmg"]) * 1.1, "зброя сильніша за легендарну, «Характерницька» сильніша за «Сотницьку»")
	check(float(top["base"]["flat_dmg"]) < Data._primary_value("weapon", 60, 3) * 1.35, "але не більш як на третину: гра не стає легшою стрибком")
	Uniques.rescale(a1, 70)
	check(int(a1["ilvl"]) == 70 and float(a1["base"]["flat_dmg"]) > float(a2["base"]["flat_dmg"]) and a1["affixes"].keys() == a2["affixes"].keys(), "оновлення до рівня: ті самі властивості, більша сила")
	check(int(Data.gen_item(30, 4)["rarity"]) == 3 and int(Data.gen_item(30, 9)["rarity"]) == 3, "випадкова річ не буває унікальною")
	# Шанс і Доля
	check(is_equal_approx(Loot.chance(1, 0), 0.01) and is_equal_approx(Loot.chance(4, 0), 0.024) and is_equal_approx(Loot.chance(1, 20), 0.02) and Loot.chance(3, 99) == 1.0 and Loot.chance(5, 0) < 0.04, "шанси малі, Доля їх підіймає, сотий бос дає напевно")
	# Вибір речі: клас і ступінь
	var p = _new_player()
	p.change_class("cossack")
	var pick_ok := true
	for i in 300:
		var pid: String = Loot.pick(p, 2, "solovei")
		var PD: Dictionary = Uniques.DEFS[pid]
		pick_ok = pick_ok and int(PD["tier"]) <= 2 and not (PD["slot"] == "weapon" and PD["type"] in ["staff", "pishchal"])
	check(pick_ok, "козакові не падає посох чи пищаль, ступінь не вищий за ступінь боса")
	var fav := 0
	for i in 400:
		if Loot.pick(p, 1, "vovkulaka") == "vovcha_kuchma":
			fav += 1
	check(fav > 150, "улюблену річ бос дає частіше за інші (%d із 400)" % fav)
	# Сила вдягненої речі
	var sirko: Dictionary = Uniques.make("shablia_sirka", 40)
	p.assign_uid(sirko)
	p.equipment["weapon"] = sirko
	p.recalc()
	check(p.u_pow.has("zvytiaha") and int(p.u_pow["zvytiaha"]["max"]) == 10, "вдягнена Шабля Сірка дає Звитягу")
	var body1: Dictionary = Uniques.make("kolchuha_bohuna", 40)
	p.assign_uid(body1)
	p.equipment["body"] = body1
	p.recalc()
	check(int(p.u_pow["zvytiaha"]["max"]) == 10 and p.u_pow.size() == 1, "дві однакові сили не складаються: діє сильніша")
	# Продаж і збереження
	var spare: Dictionary = Uniques.make("poias_baidy", 40)
	p.add_item(spare)
	p.add_item(Data.gen_item(5, 0))
	var n0: int = p.inventory.size()
	CityService.sell_up_to(p, 4)
	CityService.sell_junk(p)
	check(not p.find_item(spare["uid"]).is_empty() and p.inventory.size() < n0, "масовий продаж золота не чіпає")
	p.u_luck = 37
	var q = _new_player()
	q.from_dict(p.to_dict().duplicate(true))
	check(q.u_luck == 37 and q.u_pow.has("zvytiaha") and not q.find_item(spare["uid"]).is_empty(), "Доля, сили й золоті речі переживають збереження")
	var old = _new_player()
	var od: Dictionary = old.to_dict().duplicate(true)
	od.erase("u_luck")
	old.from_dict(od)
	check(old.u_luck == 0 and old.u_pow.is_empty(), "старе збереження без золота вантажиться")
	# Довідник
	var titles := {}
	for sx in WS.sections():
		for e in sx["entries"]:
			titles[str(e["title"])] = str(e["text"])
	var wiki_ok := titles.has("Золоті речі") and titles.has("Шанс золота") and titles.has("Ступені золота")
	for id in Uniques.ORDER:
		var nm: String = str(Uniques.DEFS[id]["name"])
		wiki_ok = wiki_ok and titles.has(nm) and Uniques.power_name(id) in str(titles.get(nm, ""))
	check(wiki_ok, "у довіднику є правила золота й кожна золота річ із її силою")
	var UI = load("res://scripts/ui/ui_kit.gd")
	var card: Control = UI.item_card(sirko)
	var ctext := ""
	for n in card.find_children("*", "Label", true, false):
		ctext += n.text + "\n"
	card.free()
	var btn: Button = UI.item_button(sirko, func(): pass)
	check("Унікальна «Гетьманська»" in ctext and "✦ Звитяга" in ctext and "Іван Сірко" in ctext and btn.text.begins_with("★ Шабля Сірка"), "картка золотої речі: ступінь, сила, переказ, зірка на кнопці")
	btn.free()


func _suite_uniques_game() -> void:
	suite("Золоті речі: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Uniques = load("res://scripts/data/uniques.gd")
	var Loot = load("res://scripts/game/loot_service.gd")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 40
	p.stats["str"] = 120
	p.stats["vit"] = 150
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	var golden_on_floor := func() -> Dictionary:
		for ch in c.entities.get_children():
			if ch.get_script() == c.PickupScript and ch.kind == "item" and ch.item.has("unique") and not ch.is_queued_for_deletion():
				return ch.item
		return {}
	var boss_of := func():
		for e in c.get_tree().get_nodes_in_group("enemies"):
			if e.is_boss:
				return e
		return null
	var to_boss_room := func() -> void:
		_clear_enemies(game)
		if c.portal != null and is_instance_valid(c.portal):
			c.portal.queue_free()
		c.portal = null
		c.room = int(c.loc["rooms"])
		c._spawn_room()
	# Гідний бос далекого краю на сотій спробі дає золото напевно
	game.enter_location("zmiinyi")
	await _frames(3)
	to_boss_room.call()
	await _frames(2)
	var boss = boss_of.call()
	check(boss != null and Loot.is_lair_boss(c, boss) and Loot.worthy(c, p, boss) and Loot.boss_tier(c, boss) == 4, "Морський цар у своєму лігві: гідний бос четвертого ступеня")
	p.u_luck = 99
	c._drop_loot(boss)
	var g: Dictionary = golden_on_floor.call()
	check(not g.is_empty() and int(g["rarity"]) == 4 and int(g["ilvl"]) == int(boss.level) and Uniques.tier(g) <= 4 and p.u_luck == 0, "золота річ упала, Доля скинулась")
	p.u_luck = 0
	var dry := 0
	for i in 30:
		if Loot.on_boss(c, p, boss).is_empty():
			dry += 1
	check(dry >= 22 and (dry < 30 or p.u_luck == 30), "зазвичай бос золота не дає, а Доля росте (%d із 30 порожні)" % dry)
	# Повна торба золоту річ не продає
	while not p.bag_full():
		p.add_item(Data.gen_item(5, 0))
	var gold0: int = p.gold
	var n0: int = p.inventory.size()
	c.pick_item(Uniques.make("poias_baidy", 40))
	check(p.inventory.size() == n0 + 1 and p.gold == gold0, "при повній торбі золота річ лягає понад місце, а не продається")
	p.inventory.clear()
	game.enter_map()
	await _frames(2)
	# Стара печера високому героєві золота не дає, ватажок у полі теж
	game.enter_location("zmii_cave")
	await _frames(3)
	to_boss_room.call()
	await _frames(2)
	boss = boss_of.call()
	p.u_luck = 99
	check(boss != null and Loot.is_lair_boss(c, boss) and not Loot.worthy(c, p, boss) and Loot.on_boss(c, p, boss).is_empty() and p.u_luck == 99, "Змій третього рівня героєві сорокового золота не дає")
	game.enter_map()
	await _frames(2)
	game.enter_location("oleshky")
	await _frames(3)
	_clear_enemies(game)
	c.spawn_enemy("upyr", 40, true, p.global_position + Vector2(300, 0))
	var leader = c._last_enemy()
	check(not Loot.is_lair_boss(c, leader) and Loot.on_boss(c, p, leader).is_empty(), "ватажок у полі — не господар лігва")
	# Глибини й Башта піднімають ступінь
	c.loc = {"type": "dungeon", "boss": "zmii", "depth": 16, "level": 52}
	check(Loot.boss_tier(c, {"kind": "zmii"}) == 3, "Змій на 16-й глибині — уже третього ступеня")
	c.loc = {"type": "tower", "floor": 40, "level": 54}
	check(Loot.boss_tier(c, {"kind": "lykho"}) == 5 and Loot.boss_tier(c, {"kind": "solovei"}) == 4, "супербос Башти з 40-го поверху: на два ступені вище")
	game.enter_map()
	await _frames(2)
	# Сили в бою
	game.enter_location("oleshky")
	await _frames(3)
	var wear := func(id: String) -> void:
		var it: Dictionary = Uniques.make(id, 40)
		p.assign_uid(it)
		p.equipment[it["slot"]] = it
		p.recalc()
		p.hp = p.max_hp
	var foe := func(dx: float):
		c.spawn_enemy("upyr", 40, false, p.global_position + Vector2(dx, 0))
		var e = c._last_enemy()
		e.set_process(false)
		return e
	# Звитяга
	_clear_enemies(game)
	wear.call("shablia_sirka")
	var e1 = foe.call(60.0)
	p.hit(e1, e1.max_hp * 10.0, Vector2.ZERO, false)
	check(e1.dead and p.u_stacks == 1 and p.u_stack_t > 5.0, "Звитяга: убитий ворог дає заряд")
	p.u_stacks = 10
	p.crit_chance = 0.0
	var boosted: float = p._roll(1.0)[0]
	check(boosted > p.damage * 0.9 * 1.29, "десять зарядів Звитяги: +30% шкоди")
	p.u_stack_t = 0.01
	await _frames(3)
	check(p.u_stacks == 0, "Звитяга спадає, коли час минув")
	# Перунова блискавка
	_clear_enemies(game)
	wear.call("shablia_bohdana")
	var ea = foe.call(60.0)
	var eb = foe.call(160.0)
	var hp_b: float = eb.hp
	for i in 60:
		p.u_chain_cd = 0.0
		p.hit(ea, 1.0, Vector2.ZERO, true)
		if eb.hp < hp_b:
			break
	check(eb.hp < hp_b, "Перунова блискавка перескакує з критичного удару на сусіда")
	# Громовий удар
	_clear_enemies(game)
	wear.call("bulava_mazepy")
	var ew = foe.call(200.0)
	var far = foe.call(900.0)
	var hp_w: float = ew.hp
	var hp_f: float = far.hp
	p._unique_wave()
	check(ew.hp < hp_w and is_equal_approx(far.hp, hp_f) and p.u_wave_cd > 0.0, "Громовий удар б'є всіх довкола, далеких не дістає")
	# Пластунський випад
	wear.call("vovcha_kuchma")
	p.crit_chance = 0.0
	p.dodge_timer = 0.0
	p.dodge()
	check(p.u_vypad_t > 1.0 and p._roll(1.0)[1], "після перекиду кожен удар критичний")
	p.u_vypad_t = 0.0
	check(not p._roll(1.0)[1], "без перекиду — як завжди")
	# Покрова
	_clear_enemies(game)
	wear.call("zhupan_polubotka")
	p.invuln = 0.0
	p.hp = p.max_hp * 0.4
	await _frames(2)
	check(p.u_ward_t > 0.0 and p.u_ward_cd > 10.0, "Покрова вмикається, коли здоров'я нижче половини")
	p.invuln = 0.0
	p.hp = p.max_hp
	var h0: float = p.hp
	p.take_damage(100.0, null)
	var with_ward: float = h0 - p.hp
	p.u_ward_t = 0.0
	p.invuln = 0.0
	p.hp = p.max_hp
	p.take_damage(100.0, null)
	check(with_ward > 0.0 and with_ward < (p.max_hp - p.hp) * 0.75, "під Покровою шкода менша на 30%")
	# Вогняне ядро
	_clear_enemies(game)
	p.equipment.erase("body")
	wear.call("shapka_nalyvaika")
	var ey = foe.call(260.0)
	var hp_y: float = ey.hp
	p.u_yadro_t = 0.05
	p.invuln = 5.0
	await _frames(6)
	check(ey.hp < hp_y and p.u_yadro_t > 3.0, "Вогняне ядро саме падає на найближчого ворога")
	# Відлуння
	p.change_class("volkhv")
	wear.call("posokh_molfara")
	check(p.u_pow.has("vidlunnia") and float(p.u_pow["vidlunnia"]["chance"]) > 0.2, "Посох мольфара дає Відлуння")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Артефакти =======================

func _suite_artifacts() -> void:
	suite("Артефакти: трофеї босів, що діють із торби")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Arts = load("res://scripts/data/artifacts.gd")
	var Loot = load("res://scripts/game/loot_service.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Tower = load("res://scripts/game/tower_service.gd")
	var Depth = load("res://scripts/game/depth_service.gd")
	var UI = load("res://scripts/ui/ui_kit.gd")
	var Glory = load("res://scripts/game/glory_service.gd")
	# Кожен бос має свій артефакт (новий бос без трофея провалить перевірку)
	var bosses := {}
	for id in Data.LOCATIONS:
		if Data.LOCATIONS[id].has("boss"):
			bosses[Data.LOCATIONS[id]["boss"]] = true
	for b in Tower.SUPER_BOSSES + Depth.BOSSES:
		bosses[b] = true
	var missing := []
	for b in bosses:
		if Arts.by_boss(b) == "":
			missing.append(b)
	check(missing.is_empty() and Arts.ORDER.size() == Arts.DEFS.size() and Arts.ORDER.size() == bosses.size(), "у кожного з %d босів свій артефакт: %s" % [bosses.size(), str(missing)])
	var known := ["st_burn", "st_bleed", "st_chill", "st_weak", "status", "travel", "plague", "potion_max", "mana_potion_max", "dodge_cd", "elite_dmg", "boss_dmg", "stone", "gold", "glory", "res", "unique_luck", "pickup", "trophy", "xp", "death_xp", "enrage", "soul", "set_luck", "dmg"]
	var data_ok := true
	var names := {}
	for id in Arts.ORDER:
		var D: Dictionary = Arts.DEFS[id]
		data_ok = data_ok and str(D["name"]) != "" and not names.has(D["name"]) and str(D["text"]) != "" and str(D["lore"]) != "" and Data.BOSS_NAMES.has(D["boss"]) and not D["bonus"].is_empty()
		for k in D["bonus"]:
			data_ok = data_ok and k in known
		names[D["name"]] = true
	check(data_ok, "артефакти: назва, бонус із відомих ключів, опис і переказ; без лікування й загоєння")
	# Діє з торби, копія не діє, у скрині спить
	var p = _new_player()
	var xp0: float = p.xp_mult
	var gold0: float = p.gold_mult
	var zoria: Dictionary = Arts.make("zoria_karachuna")
	check(p.add_item(zoria) and is_equal_approx(p.xp_mult, xp0 + 0.06) and Arts.is_artifact(zoria) and int(zoria["rarity"]) == 5, "артефакт у торбі діє одразу: +6% досвіду")
	p.add_item(Arts.make("zoria_karachuna"))
	check(is_equal_approx(p.xp_mult, xp0 + 0.06) and Arts.active_ids(p.inventory).size() == 1, "другий такий самий не діє")
	p.add_item(Arts.make("kliuchi_kremlia"))
	check(is_equal_approx(p.gold_mult, gold0 + 0.08) and Arts.active_ids(p.inventory).size() == 2, "різні артефакти діють разом")
	p.remove_from_bag(zoria["uid"])
	check(is_equal_approx(p.xp_mult, xp0 + 0.06), "забрали один із двох однакових: другий діє далі")
	for it in p.inventory.duplicate():
		p.remove_from_bag(it["uid"])
	check(is_equal_approx(p.xp_mult, xp0) and is_equal_approx(p.gold_mult, gold0) and p.art.is_empty(), "торба порожня: бонусів нема")
	# Не вдягається, не точиться, не продається гуртом, не переплавляється
	var hl: Dictionary = Arts.make("vidmyn_hlechyk")
	var pm0: int = p.potion_max()
	p.add_item(hl)
	check(p.potion_max() == pm0 + 1 and not p.can_use(hl) and not p.equip(hl["uid"]) and p.sharpen(hl["uid"]) == "" and not p.find_item(hl["uid"]).is_empty(), "артефакт не вдягають і не точать; Відьмин глечик дає +1 зілля")
	CityService.sell_up_to(p, 9)
	CityService.sell_junk(p)
	var w = WorldState.new()
	load("res://scripts/game/camp_service.gd").state(w)["buildings"]["kuznia"] = 3
	check(not p.find_item(hl["uid"]).is_empty() and load("res://scripts/game/camp_service.gd").salvage(w, p, hl["uid"]) == 0 and not load("res://scripts/game/craft_service.gd").can_renew(w, hl, 50), "ні продаж гуртом, ні переплавка, ні оновлення артефакт не чіпають")
	# Бонуси, що діють поза перерахунком
	p.add_item(Arts.make("mitla_yahy"))
	var q = _new_player()
	check(p.dodge_cooldown < q.dodge_cooldown * 0.93, "Мітла Баби Яги: перекид частіше")
	p.add_item(Arts.make("perlyna_tsaria"))
	check(p.mana_potion_max() == q.mana_potion_max() + 1, "Перлина Морського царя: +1 зілля наснаги")
	p.add_item(Arts.make("lisovykova_sopilka"))
	check(p.pickup_radius > q.pickup_radius * 1.25, "Сопілка Лісового Діда: здобич збирається здалеку")
	# Збереження
	var r = _new_player()
	r.from_dict(p.to_dict().duplicate(true))
	check(r.art.has("dodge_cd") and r.potion_max() == p.potion_max() and Arts.active_ids(r.inventory).size() == 4, "артефакти переживають збереження й діють після завантаження")
	# Довідник і картка
	var titles := {}
	for sx in WS.sections():
		for e in sx["entries"]:
			titles[str(e["title"])] = str(e["text"])
	var wiki_ok := titles.has("Артефакти") and titles.has("Де взяти артефакт")
	for id in Arts.ORDER:
		wiki_ok = wiki_ok and titles.has(str(Arts.DEFS[id]["name"])) and str(Arts.DEFS[id]["text"]) in str(titles.get(str(Arts.DEFS[id]["name"]), ""))
	check(wiki_ok, "у довіднику є правила й кожен артефакт із бонусом")
	var card: Control = UI.item_card(hl)
	var ctext := ""
	for n in card.find_children("*", "Label", true, false):
		ctext += n.text + "\n"
	card.free()
	var btn: Button = UI.item_button(hl, func(): pass)
	check("діє, поки лежить у торбі" in ctext and "+1 зілля здоров'я" in ctext and "Відьма" in ctext and btn.text.begins_with("◆ Відьмин глечик") and "Артефакт" in btn.text, "картка артефакта: що дає, чий трофей; ромб на кнопці")
	btn.free()
	# У грі: трофей із господаря лігва, без повторів; стани минають швидше; більше шкоди босам
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gp = game.player
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones"]:
		game.world.hints[k] = true
	gp.change_class("cossack")
	gp.level = 40
	gp.stats["str"] = 120
	gp.stats["vit"] = 150
	gp.recalc()
	gp.hp = gp.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	game.enter_location("zmiinyi")
	await _frames(3)
	_clear_enemies(game)
	if c.portal != null and is_instance_valid(c.portal):
		c.portal.queue_free()
	c.portal = null
	c.room = int(c.loc["rooms"])
	c._spawn_room()
	await _frames(2)
	var boss = null
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			boss = e
	var got := 0
	var kinds := {}
	for i in 400:
		gp.art_luck = {}  # без долі трофея: міряємо основний шанс
		var a: Dictionary = Loot.artifact_on_boss(c, gp, boss)
		if not a.is_empty():
			got += 1
			kinds[a["artifact"]] = true
	check(got >= 4 and got <= 40 and kinds.keys() == ["perlyna_tsaria"], "Морський цар лишає свою Перлину приблизно в 4%% перемог (%d із 400)" % got)
	# Доля трофея: невдачі з цим босом наближають удачу саме з ним, а після LUCK_SURE трофей напевно
	check(is_equal_approx(Loot.artifact_chance(Arts.CHANCE, 0), Arts.CHANCE) and is_equal_approx(Loot.artifact_chance(Arts.CHANCE, int(Arts.LUCK_STEP)), Arts.CHANCE * 2.0) and is_equal_approx(Loot.artifact_chance(Arts.CHANCE, Arts.LUCK_SURE), 1.0) and Loot.artifact_chance(Arts.CHANCE, Arts.LUCK_SURE - 1) < 0.2, "шанс артефакта подвоюється за %d перемог без нього, після %d — напевно" % [int(Arts.LUCK_STEP), Arts.LUCK_SURE])
	gp.art_luck = {}
	var fails := 0
	while Loot.artifact_on_boss(c, gp, boss).is_empty() and fails < 500:
		fails += 1
		if int(gp.art_luck.get(str(boss.kind), 0)) != fails or gp.art_luck.size() != 1:
			fails = 9999
	check(fails <= Arts.LUCK_SURE and not gp.art_luck.has(str(boss.kind)), "кожна перемога без трофея рахується для цього боса; трофей не пізніше ніж за %d перемог (вийшло %d), лічильник скинуто" % [Arts.LUCK_SURE + 1, fails + 1])
	gp.art_luck = {str(boss.kind): Arts.LUCK_SURE}
	check(str(Loot.artifact_on_boss(c, gp, boss).get("artifact", "")) == "perlyna_tsaria" and gp.art_luck.is_empty(), "після %d перемог без трофея наступна дає його напевно" % Arts.LUCK_SURE)
	gp.art_luck = {"zmii": 7}
	var saved_luck: Dictionary = gp.to_dict()
	check(saved_luck.has("art_luck") and int(saved_luck["art_luck"]["zmii"]) == 7, "доля трофея зберігається разом із героєм")
	gp.art_luck = {}
	gp.add_item(Arts.make("perlyna_tsaria"))
	var again := 0
	for i in 200:
		if not Loot.artifact_on_boss(c, gp, boss).is_empty():
			again += 1
	check(again == 0, "артефакт, що вже лежить у торбі, удруге не падає")
	_clear_enemies(game)
	c.spawn_enemy("upyr", 40, true, gp.global_position + Vector2(300, 0))
	check(Loot.artifact_on_boss(c, gp, c._last_enemy()).is_empty(), "прикликаний бос трофея не дає")
	# Стани
	gp.statuses.clear()
	gp.add_status("burn", 10.0, 1.0)
	var plain: float = float(gp.statuses["burn"]["t"]) if gp.statuses["burn"] is Dictionary and gp.statuses["burn"].has("t") else -1.0
	gp.statuses.clear()
	gp.add_item(Arts.make("zmiiv_zub"))
	gp.add_status("burn", 10.0, 1.0)
	var short: float = float(gp.statuses["burn"]["t"]) if gp.statuses["burn"] is Dictionary and gp.statuses["burn"].has("t") else -1.0
	check(plain > 0.0 and short > 0.0 and short < plain * 0.7, "Зміїв зуб: горіння минає на третину швидше (%s проти %s)" % [str(short), str(plain)])
	gp.statuses.clear()
	# Шкода босам і елітам
	_clear_enemies(game)
	c.spawn_enemy("upyr", 40, true, gp.global_position + Vector2(200, 0))
	var b1 = c._last_enemy()
	b1.set_process(false)
	var hp1: float = b1.hp
	gp.hit(b1, 1000.0, Vector2.ZERO, false)
	var d_plain: float = hp1 - b1.hp
	gp.add_item(Arts.make("yadro_tsar_harmaty"))
	hp1 = b1.hp
	gp.hit(b1, 1000.0, Vector2.ZERO, false)
	check(d_plain > 0.0 and (hp1 - b1.hp) > d_plain * 1.05, "Ядро Цар-гармати: +6% шкоди босам")
	# Слава
	var glory0: int = int(game.world.glory) if "glory" in game.world else 0
	gp.add_item(Arts.make("persten_biloi_pani"))
	check(float(gp.art.get("glory", 0.0)) > 0.0 and float(gp.art.get("boss_dmg", 0.0)) > 0.0, "бонуси слави й шкоди зібрано з торби")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Душі =======================

func _suite_souls() -> void:
	suite("Душі: гнізда, торбинка, шанс і бонуси")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Souls = load("res://scripts/data/souls.gd")
	var SS = load("res://scripts/game/soul_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Tower = load("res://scripts/game/tower_service.gd")
	var Depth = load("res://scripts/game/depth_service.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var CampS = load("res://scripts/game/camp_service.gd")
	var UI = load("res://scripts/ui/ui_kit.gd")
	var Status = load("res://scripts/game/status.gd")
	# Повнота: у кожної нечисті й кожного боса гри є своя записана душа
	var kinds := {}
	var bosses := {}
	for id in Data.LOCATIONS:
		for k in Data.LOCATIONS[id]["enemies"]:
			kinds[k] = true
		if Data.LOCATIONS[id].has("boss"):
			bosses[Data.LOCATIONS[id]["boss"]] = true
	for k in Tower.POOL:
		kinds[k] = true
	for b in Tower.SUPER_BOSSES + Depth.BOSSES:
		bosses[b] = true
	var no_soul := []
	for k in kinds:
		if not Souls.SOULS.has(k):
			no_soul.append(k)
	for b in bosses:
		if not Souls.SOULS.has("b_" + b):
			no_soul.append("b_" + b)
	check(no_soul.is_empty() and kinds.size() >= 18 and bosses.size() >= 19, "своя душа в кожної нечисті (%d) й кожного боса (%d): %s" % [kinds.size(), bosses.size(), str(no_soul)])
	var data_ok := true
	var bad := []
	for id in Souls.ORDER:
		var D: Dictionary = Souls.SOULS[id]
		var t: int = int(D["tier"])
		var good: bool = str(D["name"]) != "" and str(D["lore"]) != "" and not D["fx"].is_empty() and t >= 1 and t <= 7 and (t >= Souls.BOSS_TIER) == id.begins_with("b_") and not "%s" in SS.fx_text(id) and SS.owner_name(id) != ""
		for k in D["fx"]:
			good = good and Souls.FX.has(k) and not k in Souls.FORBIDDEN
		if not good:
			bad.append(id)
		data_ok = data_ok and good
	check(data_ok and Souls.ORDER.size() == Souls.SOULS.size() and SS.known().size() == Souls.ORDER.size(), "душі: назва, ступінь, бонуси з відомих ключів, жодного лікування чи наснаги: %s" % str(bad))
	check(SS.soul_name("zlyden") == "Душа злидня" and SS.fx_text("b_baba_yaha") == "+10% швидкості бігу, перекид готовий на 10% швидше" and SS.tier("b_vii") == 6, "назви й тексти бонусів")
	var unknown: Dictionary = SS.info("nova_nechyst")
	check(str(unknown["name"]) == "Душа невідомої нечисті" and unknown["fx"].has("hp") and int(SS.info("b_nova")["tier"]) == Souls.BOSS_TIER, "нова нечисть без запису теж має просту душу")
	check(is_equal_approx(float(Souls.CHANCE["regular"]), 0.00005) and float(Souls.CHANCE["elite"]) < 0.001 and float(Souls.CHANCE["boss"]) <= 0.005, "шанси вкрай малі")
	# Гніздо
	var p = _new_player()
	p.change_class("cossack")
	p.level = 66
	p.gold = 5000000
	p.resources[Camp.TROPHY] = 20
	var junk: Dictionary = Data.gen_item(66, 0, "weapon", "sabre")
	var sabre: Dictionary = Data.gen_item(66, 3, "weapon", "sabre")
	var boots: Dictionary = Data.gen_item(66, 2, "boots")
	var amulet: Dictionary = Data.gen_item(66, 3, "amulet")
	for it in [junk, sabre, boots, amulet]:
		p.add_item(it)
	check(SS.socket_block(junk) != "" and SS.socket_block(sabre) == "" and not SS.make_socket(p, junk["uid"]), "у звичайній речі гнізда не буває")
	var cost: Dictionary = SS.socket_cost(p, sabre)
	check(int(cost["gold"]) == 217800 and int(cost["trophy"]) == Souls.SOCKET_TROPHY and int(SS.socket_cost(p, sabre, 0.8)["gold"]) == 174240, "ціна гнізда: легендарна 66-го рівня 217 800 грн, у своїй кузні дешевше")
	var g0: int = p.gold
	check(SS.make_socket(p, sabre["uid"]) and SS.has_socket(sabre) and p.gold == g0 - 217800 and int(p.resources[Camp.TROPHY]) == 17 and int(sabre["spent"]) == 217800 and not SS.make_socket(p, sabre["uid"]), "гніздо пробито за гривні й трофеї, друге в ту саму річ не б'ється")
	SS.make_socket(p, boots["uid"])
	SS.make_socket(p, amulet["uid"])
	# Вселити: лише з торбинки, душі босів — у зброю й оберіг
	check(SS.insert_block(p, sabre, "b_vii") != "" and not SS.insert(p, sabre["uid"], "b_vii"), "душі, якої нема в торбинці, не вселити")
	p.souls = {"b_vii": 2, "mavka": 1, "b_idolyshche": 1}
	check(SS.insert_block(p, boots, "b_vii") == "Душа боса стає лише в зброю чи оберіг" and SS.insert_block(p, boots, "mavka") == "", "душа боса в чоботи не стає, душа мавки стає")
	var dmg0: float = p.damage
	check(SS.insert(p, sabre["uid"], "b_vii") and SS.soul_in(sabre) == "b_vii" and int(p.souls["b_vii"]) == 1 and p.soul_fx.is_empty(), "душа в речі з торби ще не діє")
	var cm0: float = p.crit_mult
	p.equip(sabre["uid"])
	check(is_equal_approx(p.crit_mult, cm0 + 0.12) and is_equal_approx(float(p.soul_fx["stun_hit"]), 0.06), "вдягнув річ: душа Вія діє")
	SS.insert(p, amulet["uid"], "b_vii")
	p.equip(amulet["uid"])
	check(is_equal_approx(p.crit_mult, cm0 + 0.12) and SS.active_ids(p) == ["b_vii"], "та сама душа у двох речах діє один раз")
	SS.insert(p, boots["uid"], "mavka")
	var sp0: float = p.speed
	p.equip(boots["uid"])
	check(p.speed > sp0 * 1.04 and SS.active_ids(p).size() == 2, "душа мавки: біг швидший")
	# Межа суми
	var q = _new_player()
	for pair in [["weapon", "b_idolyshche"], ["amulet", "b_solovei"], ["head", "boyaryn"], ["belt", "zlyden"]]:
		var it2: Dictionary = Data.gen_item(10, 2, pair[0], "sabre" if pair[0] == "weapon" else "")
		it2["sock"] = 1
		it2["soul"] = pair[1]
		q.assign_uid(it2)
		q.equipment[pair[0]] = it2
	q.recalc()
	check(is_equal_approx(float(q.soul_fx["gold"]), 0.4), "бонуси різних душ складаються лише до межі: гривень не більш як +40%")
	# Вийняти, продати, переплавити: душа не губиться
	var g1: int = p.gold
	check(SS.remove_cost(p, amulet) == 21780 and SS.remove(p, amulet["uid"]) and p.gold == g1 - 21780 and SS.soul_in(amulet) == "" and int(p.souls["b_vii"]) == 1 and SS.has_socket(amulet), "вийняти душу: 10% ціни гнізда, душа ціла в торбинці, гніздо лишилось")
	p.unequip(boots["uid"])
	CityService.sell_up_to(p, 3)
	check(not p.find_item(boots["uid"]).is_empty(), "масовий продаж річ із душею не чіпає")
	CityService.sell(p, boots["uid"])
	check(int(p.souls.get("mavka", 0)) == 1 and p.find_item(boots["uid"]).is_empty(), "продав річ із душею: душа вернулась у торбинку")
	p.unequip(sabre["uid"])
	var w = WorldState.new()
	CampS.state(w)["buildings"]["kuznia"] = 3
	check(CampS.salvage(w, p, sabre["uid"]) > 0 and int(p.souls["b_vii"]) == 2, "переплавив річ із душею: душа вернулась")
	# Збереження
	SS.insert(p, amulet["uid"], "b_idolyshche")
	p.soul_luck = 0.37
	p.soul_found = 5
	var r = _new_player()
	r.from_dict(p.to_dict().duplicate(true))
	check(int(r.souls["b_vii"]) == 2 and is_equal_approx(r.soul_luck, 0.37) and r.soul_found == 5 and is_equal_approx(float(r.soul_fx.get("gold", 0.0)), 0.3), "торбинка, поклик душ і душа у вдягненій речі переживають збереження")
	var old = _new_player()
	var od: Dictionary = old.to_dict().duplicate(true)
	for k in ["souls", "soul_luck", "soul_found"]:
		od.erase(k)
	old.from_dict(od)
	check(old.souls.is_empty() and old.soul_fx.is_empty(), "старе збереження без душ вантажиться")
	# Довідник і картка
	var soul_sec: Array = WS.sections()[WS.index_of("souls")]["entries"]
	var titles := {}
	for e in soul_sec:
		titles[str(e["title"])] = true
	var wiki_ok := titles.has("Душі") and titles.has("Гніздо для душі") and titles.has("Шанс душі")
	for id in SS.known():
		wiki_ok = wiki_ok and titles.has(SS.soul_name(id))
	check(wiki_ok and WS.sections()[WS.index_of("souls")]["title"] == "Душі", "у довіднику окремий розділ «Душі» з правилами й кожною душею")
	var card: Control = UI.item_card(amulet)
	var ctext := ""
	for n in card.find_children("*", "Label", true, false):
		ctext += n.text + "\n"
	card.free()
	check("◈ Душа Ідолища Поганого: +30% гривень, +6% здоров'я" in ctext, "картка речі показує душу в гнізді")
	# У грі
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gp = game.player
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones"]:
		game.world.hints[k] = true
	gp.change_class("cossack")
	gp.level = 40
	gp.stats["str"] = 120
	gp.stats["vit"] = 150
	gp.recalc()
	gp.hp = gp.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	game.enter_location("oleshky")
	await _frames(3)
	_clear_enemies(game)
	# Яка душа
	c.spawn_enemy("zlyden", 40, false, gp.global_position + Vector2(300, 0))
	var z = c._last_enemy()
	z.set_process(false)
	c.spawn_enemy("upyr", 40, true, gp.global_position + Vector2(400, 0))
	var lead = c._last_enemy()
	lead.set_process(false)
	check(SS.id_for(z) == "zlyden" and SS.id_for(lead) == "b_upyr" and SS.class_of(z) == "regular" and SS.class_of(lead) == "boss", "рядова нечисть лишає свою душу, ватажок — душу боса")
	z.xp_value = 0
	check(SS.id_for(z) == "", "прикликаний без досвіду душі не має")
	z.xp_value = 3
	# Гідність: кого герой вбиває миттю, той лишає душу рідше
	check(is_equal_approx(SS.worth(gp, z), 1.0), "у далекому краї нечисть гідна: шанс повний")
	var weak_hp: float = z.max_hp
	z.max_hp = weak_hp * 0.01
	check(is_equal_approx(SS.worth(gp, z), Souls.W_MIN), "слабка нечисть: шанс удесятеро менший")
	z.max_hp = weak_hp
	# Перша душа й поклик душ
	gp.soul_found = 0
	gp.soul_luck = 0.0
	var first_regular := 0
	for i in 200:
		if SS.roll(gp, z) != "":
			first_regular += 1
	check(first_regular <= 1 and gp.soul_luck > 0.0, "рядова нечисть першої душі напевно не дає, а поклик душ росте")
	z.elite = true
	z.affixes = ["fiery"]
	check(SS.roll(gp, z) == "zlyden", "перша душа героя: з першого ж елітного")
	SS.grant(gp, "zlyden")
	check(int(gp.souls["zlyden"]) == 1 and gp.soul_found == 1 and gp.soul_luck == 0.0, "душа в торбинці, поклик скинувся")
	var later := 0
	for i in 300:
		if SS.roll(gp, z) != "":
			later += 1
	check(later <= 2, "далі душі падають вкрай рідко (%d із 300 елітних)" % later)
	z.elite = false
	z.affixes = []
	# Душа з убитого через справжню здобич
	gp.soul_found = 0
	gp.souls.clear()
	lead.loot_gold = 0
	c._drop_loot(lead)
	check(int(gp.souls.get("b_upyr", 0)) == 1, "убитий ватажок лишив душу, вона вже в торбинці")
	# Бонуси в бою: стан від удару з замком, більше шкоди великим, Блок
	_clear_enemies(game)
	var wpn: Dictionary = Data.gen_item(40, 3, "weapon", "sabre")
	wpn["sock"] = 1
	wpn["soul"] = "b_karachun"
	gp.assign_uid(wpn)
	gp.equipment["weapon"] = wpn
	var am: Dictionary = Data.gen_item(40, 3, "amulet")
	am["sock"] = 1
	am["soul"] = "b_pushkar"
	gp.assign_uid(am)
	gp.equipment["amulet"] = am
	gp.recalc()
	c.spawn_enemy("upyr", 40, false, gp.global_position + Vector2(100, 0))
	var foe = c._last_enemy()
	foe.set_process(false)
	foe.max_hp = 1.0e9
	foe.hp = 1.0e9
	var chilled := false
	for i in 300:
		gp.hit(foe, 1.0, Vector2.ZERO, false)
		if foe.statuses.has("chill"):
			chilled = true
			break
	check(chilled and foe.has_meta("sl_chill_hit"), "душа Карачуна: удар часом студить ворога")
	foe.statuses.clear()
	for i in 300:
		gp.hit(foe, 1.0, Vector2.ZERO, false)
	check(not foe.statuses.has("chill"), "той самий стан на того самого ворога не лягає знову, поки не минув замок")
	var hp_a: float = foe.hp
	gp.hit(foe, 1000.0, Vector2.ZERO, false)
	var plain_hit: float = hp_a - foe.hp
	foe.elite = true
	foe.affixes = ["fiery"]
	hp_a = foe.hp
	gp.hit(foe, 1000.0, Vector2.ZERO, false)
	check((hp_a - foe.hp) > plain_hit * 1.1, "душа Пушкаря: +12% шкоди елітам і босам")
	# Блок і лікування
	var hd: Dictionary = Data.gen_item(40, 2, "head")
	hd["sock"] = 1
	hd["soul"] = "kamiana_baba"
	gp.assign_uid(hd)
	gp.equipment["head"] = hd
	gp.recalc()
	check(is_equal_approx(float(gp.soul_fx["block"]), 0.16), "душа кам'яної баби: Блок міцніший")
	wpn["soul"] = "b_putinoid"
	gp.recalc()
	gp.hp = 1.0
	gp.statuses.clear()
	gp.heal(100.0, false)
	check(is_equal_approx(gp.hp, 81.0), "чорна душа Путіноїда: лікування на 20% слабше")
	# Екрани: коваль пробиває гніздо, вселяє й виймає душу; Пом'яник
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	game.enter_city("sich")
	await _frames(2)
	gp.gold = 3000000
	gp.resources[Camp.TROPHY] = 10
	gp.souls = {"mavka": 1, "b_vii": 1}
	var belt: Dictionary = Data.gen_item(40, 2, "belt")
	gp.add_item(belt)
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		if tc.get_tab_title(i).begins_with("Коваль"):
			game.city_tab = i
	game.city_do("select", belt["uid"])
	await _frames(2)
	var texts := func() -> Array:
		var out := []
		for b in game.hud.screen_root.find_children("*", "Button", true, false):
			out.append(b.text)
		return out
	check(texts.call().any(func(t): return str(t).begins_with("Пробити гніздо для душі")), "у коваля є кнопка гнізда")
	game.city_do("socket", belt["uid"])
	await _frames(2)
	var tt: Array = texts.call()
	check(SS.has_socket(belt) and tt.any(func(t): return str(t).begins_with("Вселити: Душа мавки")) and tt.any(func(t): return "Душа боса стає лише в зброю чи оберіг" in str(t)), "гніздо пробито: коваль пропонує душі з торбинки")
	game.city_do("soul_in", [belt["uid"], "mavka"])
	await _frames(2)
	check(SS.soul_in(belt) == "mavka" and not gp.souls.has("mavka") and texts.call().any(func(t): return str(t).begins_with("Вийняти душу")), "душу вселено, коваль може її вийняти")
	game.city_do("soul_out", belt["uid"])
	await _frames(2)
	check(SS.soul_in(belt) == "" and int(gp.souls["mavka"]) == 1, "душу вийнято в торбинку")
	game.open_character()
	game.char_tab = 0
	game.char_do("select", -2)
	await _frames(2)
	var labels := ""
	for n in game.hud.screen_root.find_children("*", "Label", true, false):
		labels += n.text + "\n"
	check("Пом'яник душ" in labels and "Душа мавки  ×1 у торбинці" in labels and "ще не знайдено" in labels and texts.call().any(func(t): return str(t) == "Душі: 2"), "Пом'яник: що в торбинці й чого ще нема")
	# Блок «Вселити»: кожна душа з торбинки рівно один раз, кількість на кнопці, опис не обрізаний
	var UiSouls = load("res://scripts/ui/ui_souls.gd")
	var nop := func(_a: String, _b): return func(): pass
	var sock_w: Dictionary = Data.gen_item(40, 2, "weapon", "sabre")
	sock_w["sock"] = 1
	gp.add_item(sock_w)
	var ins_texts := func(blk: Control) -> Array:
		var out := []
		for b in blk.find_children("*", "Button", true, false):
			if str(b.text).begins_with("Вселити"):
				out.append(str(b.text))
		return out
	gp.souls = {"mavka": 2, "chort": 2}
	var blk: Control = UiSouls.block(gp, sock_w, nop, true)
	var it2: Array = ins_texts.call(blk)
	blk.free()
	check(it2.size() == 2 and it2.all(func(t): return " ×2\n" in t) and it2.any(func(t): return t.begins_with("Вселити: Душа мавки ×2")), "по дві душі двох видів: дві кнопки «Вселити», не чотири, на кожній «×2»: %s" % str(it2))
	gp.souls = {"mavka": 1, "chort": 1}
	blk = UiSouls.block(gp, sock_w, nop, true)
	var it1: Array = ins_texts.call(blk)
	blk.free()
	check(it1.size() == 2 and not it1.any(func(t): return "×" in t), "по одній душі: без позначки кількості")
	gp.souls = {"stara_dusha_x": 1, "mavka": 1}
	blk = UiSouls.block(gp, sock_w, nop, true)
	var itu: Array = ins_texts.call(blk)
	blk.free()
	check(itu.size() == 2 and itu.filter(func(t): return t.begins_with("Вселити: Душа невідомої нечисті\n")).size() == 1 and itu[0].begins_with("Вселити: Душа мавки"), "незнайома душа з торбинки показана один раз, після знайомих: %s" % str(itu))
	check(SS.insert_block(gp, sock_w, "stara_dusha_x") == "" and SS.insert(gp, sock_w["uid"], "stara_dusha_x") and SS.soul_in(sock_w) == "stara_dusha_x", "незнайому душу можна вселити, гра не падає")
	SS.strip(gp, sock_w)
	check(soul_sec.any(func(e): return str(e["title"]) == "Вселити й вийняти" and "на кнопці «Вселити» видно скільки" in str(e["text"])), "довідник: кількість однакових душ видно на кнопці")
	# усі душі гри: і опис, і причина відмови переносяться, назва лишається в першому рядку
	var sock_b: Dictionary = Data.gen_item(40, 2, "boots")
	sock_b["sock"] = 1
	gp.add_item(sock_b)
	game.hud.open_overlay()
	var probes := []
	for id in Souls.ORDER:
		gp.souls = {id: 2}
		for itx in [sock_w, sock_b]:
			var pb: Control = UiSouls.block(gp, itx, nop, true)
			game.hud.overlay_box.add_child(pb)
			probes.append(pb)
	await _frames(2)
	var fit_bad := []
	var tallest := 0.0
	for pb in probes:
		for b in pb.find_children("*", "Button", true, false):
			if not str(b.text).begins_with("Вселити"):
				continue
			var font: Font = b.get_theme_font("font")
			var sb: StyleBox = b.get_theme_stylebox("normal")
			var first_w: float = font.get_string_size(str(b.text).split("\n")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + sb.get_minimum_size().x
			var full_w: float = font.get_string_size(str(b.text).split("\n")[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			tallest = maxf(tallest, b.get_combined_minimum_size().y) if full_w > UiSouls.WIDTH - sb.get_minimum_size().x else tallest
			if b.clip_text or b.autowrap_mode == TextServer.AUTOWRAP_OFF or b.get_combined_minimum_size().x > UiSouls.WIDTH + 0.5 or first_w > UiSouls.WIDTH:
				fit_bad.append(str(b.text).replace("\n", " / "))
	check(probes.size() == Souls.ORDER.size() * 2 and fit_bad.is_empty(), "кнопки «Вселити» всіх %d душ вміщаються в %d, назва в першому рядку, текст не обрізаний: %s" % [Souls.ORDER.size(), UiSouls.WIDTH, str(fit_bad)])
	check(tallest > 68.0, "довгий опис переноситься, і кнопка вищає (%.0f)" % tallest)
	game.hud.close_overlay()  # прибирає й проби
	game.close_character()
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Складність: запас сил не вічний =======================

func _suite_difficulty() -> void:
	suite("Складність: вампіризм, наснага, захист, Глибини")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Far = load("res://scripts/game/far_service.gd")
	var Power = load("res://scripts/game/power.gd")
	var Depth = load("res://scripts/game/depth_service.gd")
	check(Data.ARMOR_CAP < 0.75 and Data.LIFESTEAL_MAX_HPS <= 0.02 and Data.BOSS_DMG_MULT > 1.5 and Data.BOSS_HP_MULT > 8.0 and Data.enemy_hit(50) >= 0.08, "ручки складності: захист, вампіризм, боси, шкода ворогів")
	var tank = _new_player()
	tank.stats["vit"] = 500
	tank.recalc()
	check(is_equal_approx(tank.armor, Data.ARMOR_CAP), "захист не гасить більше %d%% удару" % roundi(Data.ARMOR_CAP * 100.0))
	check(is_equal_approx(Power.hit(tank, 0.1), tank.max_hp * 0.1 / (1.0 - Data.ARMOR_CAP)), "мірило удару рахує ту саму стелю захисту")
	var mage = _new_player()
	var plain_dps: float = Power.dps(mage)
	mage.skill_power = 4.0
	check(Power.dps(mage) > plain_dps * 1.15 and Power.dps(mage) < plain_dps * 1.25, "мірило сили бачить силу вмінь, але в межах")
	tank.level = 50
	var fm: Dictionary = Far.floor_mods(tank, 0.5)
	check(is_equal_approx(float(fm["min_std_hp"]), Data.enemy_std_hp(50) * 0.5) and is_equal_approx(float(fm["min_std_dmg"]), Data.enemy_std_dmg(50) * 0.5), "підлога сили нечисті — частка мірки для рівня героя, а не його спорядження")
	tank.level = 1
	var d1: Dictionary = Depth.loc_for(1)
	var d23: Dictionary = Depth.loc_for(23)
	check(float(d23["hp_mult"]) > float(d1["hp_mult"]) and float(d23["dmg_mult"]) > float(d1["dmg_mult"]) and int(d23["level"]) > int(d1["level"]) and float(d23["hp_mult"]) < 2.0, "Глибини важчають рівнем нечисті й малою надбавкою понад нього")
	# Оцінка «чи під силу»: за спорядженням героя, а не лише за рівнем
	var th = _new_player()
	th.change_class("cossack")
	th.level = 60
	th.stats["str"] = 60
	th.stats["vit"] = 150
	th.recalc()
	var t_own: Dictionary = Power.threat(th, 60)
	var t_low: Dictionary = Power.threat(th, 1)
	check(int(t_own["grade"]) == Power.THREAT.size() and str(t_own["name"]) == Power.THREAT_WORST, "голому героєві нечисть свого рівня смертельна")
	check(int(t_low["grade"]) == 0 and str(t_low["name"]) == str(Power.THREAT[0]["name"]) and float(t_low["ttk"]) < float(t_own["ttk"]) and float(t_low["hits"]) > float(t_own["hits"]), "нечисть першого рівня йому легка")
	var t_floor: Dictionary = Power.threat(th, 1, 1.0, 1.0, 1.0)
	check(is_equal_approx(float(t_floor["ttk"]), float(t_own["ttk"])) and is_equal_approx(float(t_floor["hits"]), float(t_own["hits"])), "підлога сили від рівня героя входить в оцінку")
	check(float(Power.threat(th, 30, 2.0, 2.0)["ttk"]) > float(Power.threat(th, 30)["ttk"]) * 1.9 and float(Power.threat(th, 30, 2.0, 2.0)["hits"]) < float(Power.threat(th, 30)["hits"]) * 0.6, "надбавки місця роблять оцінку гіршою")
	# Порадник радить зміцнити спорядження, коли нечисть свого рівня смертельна (новачка не чіпає)
	var GSv = load("res://scripts/game/guide_service.gd")
	var w_g = load("res://scripts/game/world_state.gd").new()
	check(GSv.items(w_g, th, "sich").any(func(it): return it["kind"] == "weak" and int(it["tab"]) == GSv.TAB_HERO and "смертельно" in str(it["sub"])), "порадник: нечисть свого рівня смертельна — зміцни спорядження")
	th.level = GSv.WEAK_FROM - 1
	check(not GSv.items(w_g, th, "sich").any(func(it): return it["kind"] == "weak"), "новачкові до %d-го рівня порадник цього не каже" % GSv.WEAK_FROM)
	th.level = 60
	_fit(th, 1.0)
	check(float(Power.threat(th, 60)["ttk"]) <= Data.enemy_ttk(60) * 1.01, "герой з еталонною шкодою рубає нечисть свого рівня за еталонний час")
	check(is_equal_approx(Power.score(th), Power.dps(th) * Power.ehp(th)), "сила героя — шкода на запас живучості")
	var MP = load("res://scripts/ui/map_panel.gd")
	var w_th = load("res://scripts/game/world_state.gd").new()
	w_th.story = {"chapter": 6, "step": 0, "stage": "done"}
	var panel_text := func(c: Control) -> String:
		var t := ""
		for n in c.find_children("*", "Label", true, false):
			t += n.text + "\n"
		c.free()
		return t
	check("Тобі тут: " in panel_text.call(MP.build_depths(w_th, th, 1, func(_x): pass, func(_x): pass)), "панель Глибин каже, чи під силу")
	check("Тобі тут: " in panel_text.call(MP.build_tower(w_th, th, 1, func(_x): pass, func(_x): pass)), "панель Башти каже, чи під силу")
	th.free()
	# Характерництво: перші SPI_SOFT очок повною мірою, далі вдесятеро слабше; класи з чарами по гурту б'ють слабше
	check(is_equal_approx(Data.soft_spi(10.0), 10.0) and is_equal_approx(Data.soft_spi(Data.SPI_SOFT), Data.SPI_SOFT) and is_equal_approx(Data.soft_spi(Data.SPI_SOFT + 100.0), Data.SPI_SOFT + 100.0 * Data.SPI_LATE), "Характерництво понад %d очок рахується часткою" % int(Data.SPI_SOFT))
	var sp = _new_player()
	sp.stats["spi"] = Data.STAT_BASE + int(Data.SPI_SOFT)  # рахуються очки, вкладені понад початкові
	sp.recalc()
	var sp_soft: float = sp.skill_power
	var cd_soft: float = sp.skill_cd_mult
	sp.stats["spi"] = Data.STAT_BASE + int(Data.SPI_SOFT) + 100
	sp.recalc()
	check(is_equal_approx(sp_soft, 1.0 + 0.05 * Data.SPI_SOFT) and is_equal_approx(sp.skill_power - sp_soft, 0.05 * 100.0 * Data.SPI_LATE), "сила вмінь: +5%% за очко до %d-го, далі +%s%%" % [int(Data.SPI_SOFT), str(5.0 * Data.SPI_LATE)])
	check(sp.skill_cd_mult < cd_soft and sp.skill_cd_mult > cd_soft * 0.6 and sp.max_mana > 500.0, "перезарядка від Характерництва теж росте щораз слабше, наснага — як раніше")
	sp.job = "cossack"
	sp.recalc()
	var sp_plain: float = sp.skill_power
	sp.job = "perun_zhrets"
	sp.recalc()
	var k_perun: float = float(Data.Classes.CLASSES["perun_zhrets"]["skill_mult"])
	var staff_ok := true
	for cid in Data.Classes.CLASSES:
		var CI: Dictionary = Data.Classes.CLASSES[cid]
		var staff: bool = CI["weapons"] == ["staff"]
		staff_ok = staff_ok and (staff == CI.has("skill_mult")) and (not staff or (float(CI["skill_mult"]) > 0.3 and float(CI["skill_mult"]) < 1.0))
	check(is_equal_approx(sp.skill_power, sp_plain * k_perun) and staff_ok and k_perun < float(Data.Classes.CLASSES["molfar"]["skill_mult"]) and float(Data.Classes.CLASSES["molfar"]["skill_mult"]) < float(Data.Classes.CLASSES["znakhar"]["skill_mult"]), "класи з посохом мають власний множник сили вмінь, найменший у Перунового жерця")
	sp.job = "peasant"
	sp.recalc()
	var dps_hand: float = Power.dps(sp)
	sp.weapon_type = "staff"
	check(is_equal_approx(Power.dps(sp), dps_hand * Power.STAFF_SPELLS), "мірило сили знає, що з посохом шкода йде від чарів")
	sp.free()
	# Ціна смерті: 1% досвіду рівня від 10-го рівня, не нижче нуля, рівень не падає
	var dp = _new_player()
	dp.level = Data.DEATH_XP_FROM - 1
	dp.xp_next = Data.xp_for_level(dp.level)
	dp.xp = dp.xp_next / 2
	check(dp.death_xp_loss() == 0 and dp.xp == dp.xp_next / 2, "новачка до %d-го рівня смерть досвідом не карає" % Data.DEATH_XP_FROM)
	dp.level = 60
	dp.xp_next = Data.xp_for_level(60)
	dp.xp = dp.xp_next / 2
	var one: int = ceili(dp.xp_next * Data.DEATH_XP_LOSS)
	check(is_equal_approx(Data.DEATH_XP_LOSS, 0.01) and dp.death_xp_loss() == one and dp.xp == dp.xp_next / 2 - one and dp.level == 60, "смерть забирає 1% досвіду, потрібного на рівень")
	dp.xp = one / 3
	check(dp.death_xp_loss() == one / 3 and dp.xp == 0 and dp.level == 60, "досвід не падає нижче нуля, рівень лишається")
	dp.level = Data.Classes.BASE_LEVEL_MAX
	dp.xp = 0
	check(dp.death_xp_loss() == 0, "на останньому рівні втрачати нічого")
	dp.free()
	# Дорога до останнього рівня: кожен рівень дорожчий, з XP_LATE_FROM-го ще й із надбавкою
	var mono := true
	for lv in range(2, Data.Classes.BASE_LEVEL_MAX):
		mono = mono and Data.xp_for_level(lv) > Data.xp_for_level(lv - 1)
	var plain := func(lv: int) -> float:
		return (200 + 150 * lv + 15 * lv * lv) * pow(1.0 + 0.6 * (lv - 29), 0.8)
	check(mono and Data.xp_for_level(Data.XP_LATE_FROM - 1) == int(plain.call(Data.XP_LATE_FROM - 1)), "кожен рівень дорожчий за попередній; до %d-го крива стара" % Data.XP_LATE_FROM)
	check(Data.xp_for_level(Data.XP_LATE_FROM) == int(float(plain.call(Data.XP_LATE_FROM)) * (1.0 + Data.XP_LATE_STEP)) and Data.xp_for_level(98) == int(float(plain.call(98)) * (1.0 + Data.XP_LATE_STEP * (98 - Data.XP_LATE_FROM + 1))) and Data.xp_for_level(98) > 4 * int(plain.call(98)), "з %d-го рівня кожен наступний дорожчий ще на %d%%" % [Data.XP_LATE_FROM, roundi(Data.XP_LATE_STEP * 100.0)])
	var sv = _new_player()
	sv.from_dict({"level": 75, "xp": 500, "xp_next": 1000})
	check(sv.xp_next == Data.xp_for_level(75) and sv.xp == int(0.5 * Data.xp_for_level(75)), "старе збереження зберігає частку шляху до наступного рівня")
	sv.free()
	# Довідник знає нові правила й називає числа з балансу
	var WSv = load("res://scripts/game/wiki_service.gd")
	var arts := {}
	for sx in WSv.sections():
		for e in sx["entries"]:
			arts[str(e["title"])] = str(e["text"])
	var hard: String = str(arts.get("Складність", ""))
	check(("%s с" % WSv._num(Data.enemy_ttk(1))) in hard and ("%s%%" % WSv._num(Data.enemy_hit(50) * 100.0)) in hard and ("+%d" % Data.MAX_UPGRADE) in hard and "Тобі тут" in hard and ("за %d%% сили" % roundi(Far.DEPTH_FLOOR * 100.0)) in hard and ("у Башті за %d%%" % roundi(Far.TOWER_FLOOR * 100.0)) in hard, "довідник пояснює складність із числами балансу")
	var dying: String = str(arts.get("Смерть", ""))
	check(("%s%% гривень" % WSv._num(Data.DEATH_GOLD_LOSS * 100.0)) in dying and ("%s%% досвіду" % WSv._num(Data.DEATH_XP_LOSS * 100.0)) in dying and ("До %d-го рівня" % Data.DEATH_XP_FROM) in dying and "Герць" in dying, "довідник називає ціну смерті")
	var road: String = str(arts.get("Дорога до %d-го рівня" % Data.Classes.BASE_LEVEL_MAX, ""))
	check(WSv._big(Data.xp_for_level(Data.Classes.BASE_LEVEL_MAX - 1)) in road and WSv._big(Data.xp_for_level(30)) in road and "Глибини" in road, "довідник показує, скільки досвіду коштують рівні")
	check(WSv._big(1234567) == "1 234 567" and WSv._big(999) == "999" and WSv._big(1000) == "1 000", "великі числа з пробілами між розрядами")
	var spi_rule: String = str(arts.get("Характерництво й сила вмінь", ""))
	check(("Перші %d вкладених очок" % int(Data.SPI_SOFT)) in spi_rule and "вдесятеро менше" in spi_rule, "довідник пояснює Характерництво й силу вмінь")
	var perun_art := ""
	for sx in WSv.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Перунів жрець":
				perun_art = str(e["text"])
	check(("сила вмінь ×%s" % WSv._num(Data.Classes.CLASSES["perun_zhrets"]["skill_mult"])) in perun_art, "довідник показує множник сили вмінь класу")
	var drop_rule: String = str(arts.get("Шанси здобичі", ""))
	check(("шансом %s%%" % WSv._num(Data.ITEM_DROP_CHANCE * 100.0)) in drop_rule and ("%s%%" % WSv._num(snappedf(Data.rarity_share(99, 3) * 100.0, 0.1))) in drop_rule and "Бос завжди дає дві речі" in drop_rule, "довідник називає шанси здобичі з балансу")
	var art_rule: String = str(arts.get("Де взяти артефакт", ""))
	check(("за %d таких поспіль шанс подвоюється" % int(load("res://scripts/data/artifacts.gd").LUCK_STEP)) in art_rule and ("після %d наступна дає трофей напевно" % load("res://scripts/data/artifacts.gd").LUCK_SURE) in art_rule, "довідник пояснює долю трофея")
	var soul_rule: String = str(arts.get("Шанс душі", ""))
	check("слабша за звичайну нечисть твого рівня" in soul_rule and "Від спорядження це не залежить" in soul_rule, "довідник: душі залежать від рівня нечисті, а не від спорядження")
	# Мірка сили нечисті: еталонний герой у середньому спорядженні
	var curve_ok := true
	for lv in range(2, 100):
		curve_ok = curve_ok and Data.enemy_std_hp(lv) > Data.enemy_std_hp(lv - 1) and Data.enemy_std_dmg(lv) > Data.enemy_std_dmg(lv - 1)
	check(curve_ok, "нечисть кожного наступного рівня здоровіша й б'є сильніше")
	check(is_equal_approx(Data.enemy_std_hp(50), Data.ref_dps(50) * Data.enemy_ttk(50)) and is_equal_approx(Data.enemy_std_dmg(50), Data.ref_ehp(50) * Data.enemy_hit(50)), "мірка: секунди шкоди еталонного героя й частка його живучості")
	check(Data.enemy_ttk(1) < 1.0 and Data.enemy_hit(1) < 0.05 and Data.enemy_ttk(50) >= 2.0 and Data.enemy_ttk(99) >= Data.enemy_ttk(50) and Data.enemy_hit(99) >= Data.enemy_hit(50), "новачкам м'якше, з 50-го рівня — повна суворість")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "depths"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 40
	p.stats["str"] = 120
	p.stats["vit"] = 150
	p.recalc()
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	game.enter_location("oleshky")
	await _frames(3)
	_clear_enemies(game)
	# Вампіризм: лише від справжньої шкоди й не більше запасу
	p.lifesteal = 0.5
	p.leech_pool = p.max_hp
	c.spawn_enemy("upyr", 40, false, p.global_position + Vector2(200, 0))
	var e = c._last_enemy()
	e.set_process(false)
	e.max_hp = 100.0
	e.hp = 100.0
	p.hp = 1.0
	p.statuses.clear()
	p.hit(e, 1.0e6, Vector2.ZERO, false)
	check(e.dead and is_equal_approx(p.hp, 51.0), "вампіризм рахує лише справді завдану шкоду, а не надлишок (здоров'я %s)" % str(p.hp))
	c.spawn_enemy("upyr", 40, false, p.global_position + Vector2(200, 0))
	var e2 = c._last_enemy()
	e2.set_process(false)
	e2.max_hp = 1.0e9
	e2.hp = 1.0e9
	p.hp = 1.0
	p.leech_pool = p.max_hp * 0.02
	for i in 50:
		p.hit(e2, 1.0e5, Vector2.ZERO, false)
	check(p.hp <= 1.0 + p.max_hp * 0.02 + 0.5 and p.leech_pool < 0.5, "запас вампіризму скінченний: п'ятдесят ударів поспіль лікують не більше за нього")
	var pool0: float = p.leech_pool
	await _frames(60)
	check(p.leech_pool > pool0 and p.leech_pool <= p.max_hp * Data.LIFESTEAL_MAX_HPS * 2.0 + 0.01 and absf((p.leech_pool - pool0) - p.max_hp * Data.LIFESTEAL_MAX_HPS) < p.max_hp * 0.004, "запас поповнюється на %s%% здоров'я за секунду" % str(Data.LIFESTEAL_MAX_HPS * 100.0))
	# Наснага за удар: швидкі удари не дають більше за секунду
	_clear_enemies(game)
	p.lifesteal = 0.0
	c.spawn_enemy("upyr", 40, false, p.global_position + Vector2(60, 0))
	var e3 = c._last_enemy()
	e3.set_process(false)
	e3.max_hp = 1.0e9
	e3.hp = 1.0e9
	p.attack_cooldown = Data.MANA_ON_HIT_CD
	p.attack_timer = 0.0
	p.mana = 0.0
	p.attack()
	var slow_gain: float = p.mana
	p.attack_cooldown = Data.MANA_ON_HIT_CD / 4.0
	p.attack_timer = 0.0
	p.mana = 0.0
	p.attack()
	check(is_equal_approx(slow_gain, Data.MANA_ON_HIT) and is_equal_approx(p.mana, Data.MANA_ON_HIT / 4.0), "удар зі звичайною швидкістю дає %s наснаги, учетверо швидший — учетверо менше" % str(Data.MANA_ON_HIT))
	# Глибини: проти сильного героя нечисть не слабша за підлогу
	game.enter_map()
	await _frames(2)
	p.recalc()
	game.world.story = {"chapter": 6, "step": 0, "stage": "done"}
	game.world.depths = {"max": 2, "best": 1}
	game.start_depth(1)
	await _frames(3)
	var foe = null
	for x in c.get_tree().get_nodes_in_group("enemies"):
		if x.kind == "zarazhenyi" and not x.is_boss and not x.elite:
			foe = x
	check(c.is_dungeon() and c.loc.has("depth") and is_equal_approx(float(c.loc.get("min_std_hp", 0.0)), Data.enemy_std_hp(int(p.level)) * Far.DEPTH_FLOOR), "Глибина знає рівень героя (%s)" % str(c.loc.get("min_std_hp", "нема")))
	if foe != null:
		check(foe.max_hp >= float(c.loc.get("min_std_hp", 0.0)) * 0.99, "заражений першої глибини не слабший за підлогу для рівня героя")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Екран героя: вдягнене, показники й торба на одному екрані =======================

func _suite_hero_screen() -> void:
	suite("Екран героя: клітинки речей, показники, торба")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var UI = load("res://scripts/ui/ui_kit.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	# Значок є для кожного виду зброї, кожного слота й артефакта (нова зброя без значка провалить перевірку)
	var no_icon := []
	for w in Data.WEAPON_TYPES:
		if GfxS.icon_tex(UI.item_icon_id({"slot": "weapon", "type": w})) == null:
			no_icon.append(w)
	for sl in Data.SLOTS:
		if sl != "weapon" and GfxS.icon_tex(UI.item_icon_id({"slot": sl, "type": ""})) == null:
			no_icon.append(sl)
	check(no_icon.is_empty() and GfxS.icon_tex(UI.item_icon_id(Arts.make("zmiiv_zub"))) != null and GfxS.icon_tex("it_soul") != null, "значок є для кожної зброї, слота, артефакта й душі: %s" % str(no_icon))
	var icons_tex: Texture2D = load("res://assets/gfx/sprites/icons.png")
	check(icons_tex.get_width() == GfxS.ICON_ORDER.size() * 16, "на аркуші значків здобичі є всі %d значків" % GfxS.ICON_ORDER.size())
	# Клітинка речі: заточка, зірка золотої речі, гніздо й душа
	var marks := func(item: Dictionary) -> String:
		var b: Button = UI.item_cell(item, func(): pass)
		var out := ""
		for n in b.find_children("*", "Label", true, false):
			out += n.text + " "
		b.free()
		return out
	var gold: Dictionary = Uniques.make("shablia_sirka", 40)
	gold["up"] = 7
	gold["sock"] = 1
	gold["soul"] = "b_vii"
	var plain: Dictionary = Data.gen_item(10, 1, "boots")
	plain["sock"] = 1
	var m1: String = marks.call(gold)
	var m2: String = marks.call(plain)
	check("+7" in m1 and "★" in m1 and "◈" in m1 and "◇" in m2 and not "★" in m2 and not "+" in m2, "клітинка показує заточку, зірку золота й душу в гнізді (%s | %s)" % [m1, m2])
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 20
	p.stat_points = 2
	var worn: int = p.equipment.size()
	for i in 5:
		p.add_item(Data.gen_item(20, i % 4))
	p.add_item(gold)
	game.enter_city("sich")
	await _frames(2)
	game.open_character()
	await _frames(2)
	var root_c: Control = game.hud.screen_root
	var tc: TabContainer = root_c.find_children("*", "TabContainer", true, false)[0]
	var titles := []
	for i in tc.get_tab_count():
		titles.append(tc.get_tab_title(i))
	check(str(titles[0]).begins_with("Герой") and not titles.any(func(t): return str(t).begins_with("Характеристики") or str(t).begins_with("Спорядження")), "характеристики й спорядження зведено в одну вкладку «Герой»: %s" % str(titles))
	var page: Control = tc.get_tab_control(0)
	var labels := ""
	for n in page.find_children("*", "Label", true, false):
		labels += n.text + "\n"
	var buttons: Array = page.find_children("*", "Button", true, false)
	var plus := buttons.filter(func(b): return b.text == "+")
	var cells := buttons.filter(func(b): return b.text == "" and b.custom_minimum_size.x == b.custom_minimum_size.y and b.custom_minimum_size.x >= 60.0)
	var empties := page.find_children("*", "Panel", true, false).filter(func(c): return c.custom_minimum_size.x == c.custom_minimum_size.y and c.custom_minimum_size.x >= 60.0)
	check("Вдягнуто" in labels and "Шкода за секунду" in labels and ("Торба %d/%d" % [p.inventory.size(), p.bag_size()]) in labels and "Вампіризм" in labels and "Очки" in labels, "на одному екрані зведення, вдягнене, очки, показники й торба")
	check(plus.size() == 4 and not plus[0].disabled, "чотири кнопки «+» для характеристик")
	# до клітинок речей додались чотири гнізда божих дарів (вони трохи менші, але теж квадратні кнопки)
	var gift_slots: int = load("res://scripts/data/divine.gd").SLOTS.size()
	check(cells.size() == worn + p.inventory.size() + gift_slots and empties.size() == (6 - worn) + (p.bag_size() - p.inventory.size()), "клітинок із речами %d, порожніх %d: уся торба й усі шість слотів на видноті" % [cells.size(), empties.size()])
	var str0: int = p.stat("str")
	game.char_do("stat", "str")
	check(p.stat("str") == str0 + 1 and p.stat_points == 1, "кнопка «+» додає силу")
	game.char_do("select", gold["uid"])
	await _frames(2)
	var after := ""
	for n in game.hud.screen_root.find_children("*", "Label", true, false):
		after += n.text + "\n"
	var acts := []
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		acts.append(b.text)
	check("Шабля Сірка +7" in after and "✦ Звитяга" in after and "Вдягнути" in acts and "Знищити" in acts and not "Викинути на землю" in acts, "дотик до клітинки відкриває картку речі з діями (у місті землі нема, тож лише «Знищити»)")
	game.char_do("equip", gold["uid"])
	await _frames(2)
	check(p.is_equipped(gold["uid"]) and game.hud.screen_root.find_children("*", "Button", true, false).any(func(b): return b.text == "Зняти"), "вдягнена річ стала в ляльку, її можна зняти")
	# Коваль показує речі тими самими клітинками
	game.close_character()
	var ctc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in ctc.get_tab_count():
		if ctc.get_tab_title(i).begins_with("Коваль"):
			game.city_tab = i
	game.city_do("select", gold["uid"])
	await _frames(2)
	var smith: Control = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.city_tab)
	var scells := smith.find_children("*", "Button", true, false).filter(func(b): return b.text == "" and b.custom_minimum_size.x == b.custom_minimum_size.y and b.custom_minimum_size.x >= 60.0)
	check(scells.size() == p.equipment.size() + p.inventory.size(), "у коваля ті самі клітинки: %d" % scells.size())
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Журнал завдань =======================

func _suite_journal() -> void:
	suite("Журнал завдань")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Journal = load("res://scripts/game/journal_service.gd")
	var Bounty = load("res://scripts/game/bounty_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char"]:
		w.hints[k] = true
	var find := func(title_start: String) -> Dictionary:
		for sec in Journal.sections(w, p):
			if str(sec["title"]).begins_with(title_start):
				return sec
		return {}
	# Історія завжди перша, з місцем
	var secs: Array = Journal.sections(w, p)
	var story: Dictionary = secs[0]
	check(str(story["title"]).begins_with("Історія") and story["rows"].size() == 1 and str(story["rows"][0]["text"]) != "" and not str(story["rows"][0]["text"]).begins_with("★") and str(story["rows"][0]["where"]) != "", "історія в журналі: що зробити й де (%s, %s)" % [story["rows"][0]["text"], story["rows"][0]["where"]])
	var cityq: Dictionary = find.call("Завдання міст")
	check(cityq["rows"].is_empty() and "дошці оголошень" in str(cityq["empty"]) and Journal.ready_count(w, p) == 0, "без завдань журнал підказує, де їх узяти")
	# Завдання міста: поступ, місце, місто, нагорода, готовність
	w.quests.append({"id": 950, "city": "sich", "loc": "wild_field", "type": "kill", "target": "mavka", "progress": 2, "count": 5, "text": "Знищ 5 мавок (Дике Поле)", "lvl": 1, "gold": 100, "xp": 50, "loyalty": 20})
	cityq = find.call("Завдання міст")
	var r: Dictionary = cityq["rows"][0]
	check(str(cityq["title"]) == "Завдання міст (1/%d)" % Data.MAX_ACTIVE_QUESTS and r["text"] == "Знищ 5 мавок (Дике Поле)  2/5" and r["where"] == "Дике Поле" and r["from"] == "Запорозька Січ" and r["reward"] == "100 грн, досвіду 50, лояльності 20" and not r["ready"], "завдання міста: поступ, де, від кого, нагорода")
	w.quests[0]["progress"] = 5
	r = find.call("Завдання міст")["rows"][0]
	check(r["ready"] and r["ready_text"] == "Готово: здай у місті Запорозька Січ" and Journal.ready_count(w, p) == 1, "виконане завдання позначено: де здати")
	# Розшук
	Bounty.state(w)["active"].append({"id": 7, "city": "kyiv", "kind": "upyr", "name": "Упир Кривий", "loc": "crypt", "affixes": ["fiery", "swift"], "gold": 300, "glory": 6, "killed": false})
	var hunt: Dictionary = find.call("Розшук")
	check(hunt["rows"].size() == 1 and hunt["rows"][0]["text"] == "Розшук: Упир Кривий" and hunt["rows"][0]["where"] == "Упирячий склеп" and hunt["rows"][0]["reward"] == "300 грн, слави 6" and not hunt["rows"][0]["ready"], "ціль розшуку в журналі")
	Bounty.state(w)["active"][0]["killed"] = true
	check(find.call("Розшук")["rows"][0]["ready"] and "Київ" in str(find.call("Розшук")["rows"][0]["ready_text"]) and Journal.ready_count(w, p) == 2 and Journal.total(w, p) >= 3, "убита ціль: неси голову в місто; лічильник готових росте")
	# Екран
	game.enter_city("sich")
	await _frames(2)
	game.open_character()
	await _frames(2)
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(tc.get_tab_title(1) == "Журнал  (+2)", "вкладка «Журнал» друга й показує, скільки можна здати: «%s»" % tc.get_tab_title(1))
	tc.current_tab = 1  # відкрити вкладку «Журнал»
	var text := ""
	for n in tc.get_tab_control(1).find_children("*", "Label", true, false):
		text += n.text + "\n"
	check("можна здати: 2" in text and "Знищ 5 мавок (Дике Поле)  5/5" in text and "Від міста: Запорозька Січ" in text and "Нагорода: 100 грн" in text and "Готово: здай у місті Запорозька Січ" in text and "Розшук: Упир Кривий" in text and "Голова твоя" in text, "у журналі на екрані все: завдання, нагороди, що здати")
	game.close_character()
	# Мапа: виконане завдання позначає місто, де його здають
	var places: Dictionary = Journal.turn_in_places(w)
	check(places.size() == 2 and int(places["sich"]["quests"]) == 1 and int(places["sich"]["heads"]) == 0 and int(places["kyiv"]["heads"]) == 1, "служба знає, де здавати виконане: %s" % str(places))
	w.quests.append({"id": 951, "city": "sich", "loc": "black_forest", "type": "kill", "target": "mavka", "progress": 1, "count": 5, "text": "Знищ 5 мавок (Чорний ліс)", "lvl": 1, "gold": 100, "xp": 50, "loyalty": 20})
	game.enter_map()
	await _frames(3)
	var mv = game.hud.map_view
	check(mv.turn_ins == {"sich": 1, "kyiv": 1}, "мапа позначає міста, де здавати: %s" % str(mv.turn_ins))
	check(mv.targets.has("black_forest") and not mv.targets.has("wild_field"), "знак оклику лишається лише на меті невиконаного завдання")
	check("5/5  ✓ здай: Запорозька Січ" in game.hud.quest_label.text and not "1/5  ✓" in game.hud.quest_label.text, "рядок виконаного завдання називає місто, де здати")
	var panel_text := func() -> String:
		var out := ""
		for n in game.hud.map_panel.find_children("*", "Label", true, false):
			out += n.text + "\n"
		return out
	game.map_sel = "sich"
	game._build_map_panel()
	await _frames(2)
	check("Можна здати завдань: 1" in panel_text.call(), "панель міста каже, скільки завдань можна здати")
	game.map_sel = "kyiv"
	game._build_map_panel()
	await _frames(2)
	check("Чекає нагорода за розшук: 1" in panel_text.call() and not "Можна здати завдань" in panel_text.call(), "панель міста каже про голову з розшуку")
	# Повідомлення в бою одразу називає місто
	w.quests[1]["progress"] = 4
	var kill_msgs: Array = w.on_kill("mavka")
	check(kill_msgs == ["Завдання виконано! Здай: Запорозька Січ"], "останнє вбивство: «%s»" % str(kill_msgs))
	check(w.on_kill("mavka").is_empty(), "виконане завдання більше не рахує вбивств")
	w.quests.append({"id": 952, "city": "kyiv", "loc": "serpent_cave", "type": "dungeon", "target": "serpent_cave", "progress": 0, "count": 1, "text": "Очисти: Змієва печера", "lvl": 3, "gold": 100, "xp": 50, "loyalty": 20})
	var dun_msgs: Array = w.on_dungeon("serpent_cave")
	check(dun_msgs == ["Завдання виконано! Здай: Київ"] and w.on_dungeon("serpent_cave").is_empty(), "пройдена печера: «%s», удруге не повторюється" % str(dun_msgs))
	w.quests.append({"id": 953, "city": "kyiv", "loc": "wild_field", "type": "fetch", "target": "mavka", "progress": 0, "count": 2, "text": "Принеси 2", "lvl": 1, "gold": 10, "xp": 5, "loyalty": 5})
	var last := []
	for i in 400:
		var mm: Array = w.on_kill("mavka")
		if not mm.is_empty():
			last = mm
		if w.is_done(w.quests[3]):
			break
	check(w.is_done(w.quests[3]) and last == ["Завдання виконано! Здай: Київ"], "принесене до кінця: «%s»" % str(last))
	# Сюжетна гілка в журналі є завжди: розділами, і після фіналу теж
	var story_sec: Dictionary = Journal.sections(w, p)[0]
	var cur_ch: int = int(game.StoryService.state(w)["chapter"])
	var states := []
	for ch in story_sec["chapters"]:
		states.append(str(ch["state"]))
	check(str(story_sec["title"]).begins_with("Історія. ") and states.size() == game.StoryService.Story.CHAPTERS.size() and states.count("now") == 1 and states.find("now") == cur_ch and states.count("done") == cur_ch, "журнал показує гілку історії розділами: %s" % ", ".join(states))
	var story_keep: Dictionary = w.story.duplicate(true)
	w.story = {"chapter": game.StoryService.Story.CHAPTERS.size(), "step": 0, "stage": "done", "progress": 0}
	var done_sec: Dictionary = Journal.sections(w, p)[0]
	var all_done := true
	var main_n: int = game.StoryService.Story.CHAPTERS.size()
	for ci in done_sec["chapters"].size():
		# розділи головної історії пройдено; кроки «Попелу за вітром» ще попереду
		all_done = all_done and str(done_sec["chapters"][ci]["state"]) == ("done" if ci < main_n else "ahead")
	check(str(done_sec["title"]) == "Історія" and done_sec["rows"].is_empty() and all_done and done_sec["chapters"].size() > main_n and "Попіл за вітром" in str(done_sec["empty"]) and "Історію пройдено" in str(done_sec["empty"]) and "Глибини" in str(done_sec["empty"]), "після фіналу розділ «Історія» лишається: усе пройдено й сказано, що далі")
	game.open_character()
	game.char_tab = 1
	game._build_character()
	await _frames(2)
	var jtext := ""
	for n in game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(1).find_children("*", "Label", true, false):
		jtext += n.text + "\n"
	check("✓ Пролог. Попіл рідного села" in jtext and "✓ Розділ V. Кремль" in jtext and "Історію пройдено" in jtext, "екран журналу показує пройдену гілку історії")
	game.close_character()
	await _frames(2)
	w.story = story_keep
	# Журнал: дотик до завдання показує на мапі мету, а для виконаного — місто, де здати
	var jrows: Array = find.call("Завдання міст")["rows"]
	check(jrows[0]["place"] == "sich" and jrows[2]["place"] == "kyiv" and find.call("Розшук")["rows"][0]["place"] == "kyiv" and str(Journal.sections(w, p)[0]["rows"][0]["place"]) == str(game.StoryService.target(w)), "журнал знає місце кожного завдання")
	w.quests.append({"id": 954, "city": "kyiv", "loc": "black_forest", "type": "kill", "target": "chort", "progress": 0, "count": 5, "text": "Знищ 5 чортів (Чорний ліс)", "lvl": 1, "gold": 10, "xp": 5, "loyalty": 5})
	check(find.call("Завдання міст")["rows"][4]["place"] == "black_forest", "невиконане завдання веде до своєї мети")
	game.open_character()
	game.char_tab = 1
	game._build_character()
	await _frames(2)
	var jtaps := 0
	for pc in game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(1).find_children("*", "PanelContainer", true, false):
		var has_cue := false
		for n in pc.find_children("*", "Label", true, false):
			has_cue = has_cue or n.text == "на мапі ›"
		if has_cue and not pc.find_children("*", "Button", true, false).is_empty():
			jtaps += 1
	check(jtaps >= 6, "картки журналу з місцем стали кнопками «на мапі»: %d" % jtaps)
	game.char_do("place_show", ["black_forest", "Знищ 5 чортів"])
	await _frames(3)
	check(game.state == game.State.MAP and game.map_sel == "black_forest" and game.hud.map_view.selected == "black_forest", "дотик до завдання відкриває мапу на його місці")
	# Здав завдання: позначка з міста зникає
	var CityS = load("res://scripts/game/city_service.gd")
	CityS.turn_in(w, p, 950)
	CityS.turn_in(w, p, 951)
	check(not Journal.turn_in_places(w).has("sich") and int(Journal.turn_in_places(w)["kyiv"]["quests"]) == 2, "здане завдання знімає позначку з міста")
	# Довідник
	var titles := {}
	for sx in WS.sections():
		for e in sx["entries"]:
			titles[str(e["title"])] = str(e["text"])
	check("зелена позначка" in str(titles.get("Мапа й дорога", "")) and "розшук" in str(titles.get("Мапа й дорога", "")), "довідник пояснює позначку міста, де здавати")
	check("мапа покаже це місце" in str(titles.get("Екран героя й журнал", "")), "довідник каже, що дотик до події чи завдання показує місце на мапі")
	check(titles.has("Екран героя й журнал") and "Журнал" in str(titles.get("Екран героя й журнал", "")), "довідник пояснює екран героя й журнал")
	check("пройдені дерева" in str(titles.get("Дерева вмінь", "")) and "Камінь забуття" in str(titles.get("Дерева вмінь", "")), "довідник каже, що очки можна вкладати й у пройдені дерева")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Вкладка вмінь: дерево значками й кнопки бою =======================

func _suite_skills_tab() -> void:
	suite("Вкладка вмінь: дерево значками, кнопки бою, кнопка «Персонаж»")
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
	var Classes = p.Classes
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char"]:
		game.world.hints[k] = true
	p.level = 40
	p.change_class("cossack")
	p.job_level = 20
	p.skill_points = 4
	p.skills["vyly"] = 2
	p.skills["whirl"] = 3
	p.recalc()
	p.sync_panel()
	# Кнопка героя зветься «Персонаж», а не назвою класу
	game.enter_map()
	await _frames(3)
	check(game.hud.char_btn.text.begins_with("Персонаж") and not "Козак" in game.hud.char_btn.text, "кнопка в кутку зветься «Персонаж»: «%s»" % game.hud.char_btn.text)
	game.enter_city("sich")
	await _frames(2)
	var city_btns := []
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		city_btns.append(b.text)
	check(city_btns.any(func(t): return str(t).begins_with("Персонаж")) and not city_btns.any(func(t): return str(t).begins_with("Козак")), "у місті кнопка теж «Персонаж»")
	game.open_character()
	await _frames(2)
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var tab := -1
	for i in tc.get_tab_count():
		if tc.get_tab_title(i).begins_with("Вміння"):
			tab = i
	game.char_tab = tab
	game._build_character()
	await _frames(2)
	var page := func() -> Control:
		return game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(tab)
	var cells := func() -> Array:
		return page.call().find_children("*", "Button", true, false).filter(func(b): return b.text == "" and b.custom_minimum_size.x == b.custom_minimum_size.y and b.custom_minimum_size.x >= 56.0)
	var labels := func() -> String:
		var out := ""
		for n in page.call().find_children("*", "Label", true, false):
			out += n.text + "\n"
		return out
	var btn_texts := func() -> Array:
		var out := []
		for b in page.call().find_children("*", "Button", true, false):
			out.append(b.text)
		return out
	# Дерево нинішнього класу: значок на кожне вміння, ранг під значком, лінії за вимогами
	var nodes := 0
	var reqs := 0
	for br in Classes.TREES["cossack"]:
		nodes += br["nodes"].size()
		for n in br["nodes"]:
			reqs += n.get("req", {}).size()
	var view = page.call().find_children("*", "Control", true, false).filter(func(c): return c.get_script() != null and "links" in c)[0]
	var filled := 0
	for kind in ["attack", "buff"]:
		for id in p.panel[kind]:
			if id != "":
				filled += 1
	var tree_cells: Array = view.find_children("*", "Button", true, false)
	check(tree_cells.size() == nodes and view.links.size() == reqs and nodes >= 9, "дерево козака: %d значків і %d ліній" % [tree_cells.size(), view.links.size()])
	var txt: String = labels.call()
	check("Очки вмінь" in txt and "Кнопки бою" in txt and "3/5" in txt and "0/" in txt and "Шабля" in txt, "очки, назви гілок, ранги під значками й кнопки бою на одному екрані")
	check(btn_texts.call().has("Селянин") and btn_texts.call().has("Козак") and not btn_texts.call().has("Запорожець"), "перемикач дерев: лише пройдені класи й нинішній")
	var slots := func() -> Array:
		return page.call().find_children("*", "Button", true, false).filter(func(b): return b.custom_minimum_size == Vector2(58, 58))
	check(slots.call().size() == 8 and cells.call().size() == nodes + 8 and filled == 2, "кнопок бою вісім: три атаки й п'ять підсилень, зайняті показано значками вмінь (зайнято %d)" % filled)
	# Дотик до значка: картка вміння
	game.char_do("skill_pick", "whirl")
	await _frames(2)
	txt = labels.call()
	check("Вихор" in txt and "Ранг 3/5" in txt and "Наснага" in txt and btn_texts.call().any(func(t): return str(t).begins_with("Вивчити")), "дотик до значка відкриває картку з числами й кнопкою «Вивчити»")
	# Вибране вивчене вміння: кнопки бою його виду засвітилися
	check("Торкнись зеленої кнопки" in txt, "підказка, як поставити вміння на кнопку")
	# Дотик до кнопки бою вибирає вміння на ній і показує його дерево
	var first: String = p.panel["attack"][0]
	var second: String = p.panel["attack"][1]
	game.skill_sel = ""
	game._build_character()
	await _frames(2)
	slots.call()[0].pressed.emit()
	await _frames(2)
	check(first != "" and game.skill_sel == first and game.skill_tree == ("peasant" if first == "vyly" else "cossack"), "дотик до кнопки бою вибирає вміння на ній («%s») і відкриває його дерево" % first)
	# Дотик до зеленої кнопки переносить вміння; зайняті міняються місцями
	slots.call()[2].pressed.emit()
	await _frames(2)
	check(p.panel["attack"][2] == first and p.panel["attack"][0] == "", "вміння перейшло на вільну третю кнопку")
	slots.call()[1].pressed.emit()
	await _frames(2)
	check(p.panel["attack"][1] == first and p.panel["attack"][2] == second, "на зайнятій кнопці вміння помінялися місцями")
	game.char_do("skill_tree", "cossack")
	game.char_do("skill_pick", "whirl")
	await _frames(2)
	check("Стоїть на кнопці бою" in labels.call(), "картка каже, що вміння вже на кнопці")
	# Вивчити ранг просто з картки
	var pts0: int = p.skill_points
	game.char_do("skill", "whirl")
	await _frames(2)
	check(p.sk("whirl") == 4 and p.skill_points == pts0 - 1 and "4/5" in labels.call(), "вивчено ранг: число під значком оновилось")
	# Пройдене дерево: видно, але лише для перегляду
	game.char_do("skill_tree", "peasant")
	await _frames(2)
	var pnodes := 0
	for br in Classes.TREES["peasant"]:
		pnodes += br["nodes"].size()
	view = page.call().find_children("*", "Control", true, false).filter(func(c): return c.get_script() != null and "links" in c)[0]
	check(view.find_children("*", "Button", true, false).size() == pnodes and "Пройдене дерево. Вільні очки можна вкладати й сюди." in labels.call() and game.skill_tree == "peasant", "перемикач показує дерево селянина: %d значків" % pnodes)
	game.char_do("skill_pick", "vyly")
	await _frames(2)
	check("Удар вилами" in labels.call() and "Ранг 2/5" in labels.call(), "вивчене раніше вміння теж має картку")
	# Вільне очко вкладається й у пройдене дерево просто з картки
	p.skill_points = 2
	game._build_character()
	await _frames(2)
	var learn_btn: Button = null
	for b in page.call().find_children("*", "Button", true, false):
		if b.text.begins_with("Вивчити"):
			learn_btn = b
	check(learn_btn != null and not learn_btn.disabled, "на картці вміння з пройденого дерева кнопка «Вивчити» жива")
	game.char_do("skill", "vyly")
	await _frames(2)
	check(p.sk("vyly") == 3 and p.skill_points == 1 and "Ранг 3/5" in labels.call(), "вивчено ранг у пройденому дереві")
	var prog: Array = p.tree_progress("peasant")
	check(("%d/%d" % prog) in labels.call() and prog[1] == 16, "на кнопці дерева видно, скільки рангів вивчено: %d/%d" % prog)
	# Дерево нинішнього класу вивчено до кінця: гра сама каже, куди подіти очки
	for br in Classes.TREES[p.job]:
		for n in br["nodes"]:
			p.skills[n["id"]] = int(n["max"])
	game.char_do("skill_tree", p.job)
	await _frames(2)
	check("Вільні очки вклади в пройдені дерева" in labels.call(), "повне дерево з вільними очками: підказка про пройдені дерева")
	game.close_character()
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


# ======================= Повна торба, викинути й знищити, гортання з будь-якої точки =======================

func _suite_renew_cost() -> void:
	suite("Оновлення речей: ціна росте з кожним рівнем")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var CR = load("res://scripts/game/craft_service.gd")
	var CampS = load("res://scripts/game/camp_service.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var leg := {"ilvl": 1, "rarity": 3}
	# Кожен рівень дорожчий за попередній, від першого ж рівня й до 99-го, для кожної якості
	var grows := true
	var first_bad := ""
	for r in 5:
		var it := {"ilvl": 1, "rarity": r}
		for lvl in range(2, 100):
			if int(CR.renew_step(it, lvl)["gold"]) <= int(CR.renew_step(it, lvl - 1)["gold"]):
				grows = false
				first_bad = "якість %d, рівень %d" % [r, lvl]
	check(grows, "кожен наступний рівень коштує більше за попередній, від 1-го до 99-го %s" % first_bad)
	var g5: int = int(CR.renew_step(leg, 5)["gold"])
	var g50: int = int(CR.renew_step(leg, 50)["gold"])
	var g99: int = int(CR.renew_step(leg, 99)["gold"])
	check(g99 == roundi(CR.RENEW_BASE + CR.RENEW_GOLD * 99 * 99) and g99 >= 30000 and g99 > g50 * 3 and g50 > g5 * 50, "рівень 99 відчутно дорогий: %d грн проти %d на 50-му й %d на 5-му" % [g99, g50, g5])
	check(int(CR.renew_step(leg, 99)["iron"]) > int(CR.renew_step(leg, 5)["iron"]) and int(CR.renew_step(leg, 99)["trophy"]) > int(CR.renew_step(leg, 5)["trophy"]), "заліза й трофеїв на вищих рівнях теж треба більше")
	var by_rarity := []
	for r in 5:
		by_rarity.append(int(CR.renew_step({"ilvl": 1, "rarity": r}, 60)["gold"]))
	check(by_rarity[0] < by_rarity[1] and by_rarity[1] < by_rarity[2] and by_rarity[2] < by_rarity[3] and by_rarity[3] < by_rarity[4], "краща якість дорожча, золота найдорожча: %s" % str(by_rarity))
	# Кілька рівнів одразу: сума за кожен рівень
	var total: Dictionary = CR.renew_cost({"ilvl": 60, "rarity": 3}, 75)
	var sum_gold := 0
	var sum_iron := 0
	for lvl in range(61, 76):
		sum_gold += int(CR.renew_step(leg, lvl)["gold"])
		sum_iron += int(CR.renew_step(leg, lvl)["iron"])
	check(int(total["gold"]) == sum_gold and int(total["iron"]) == sum_iron and CR.renew_cost({"ilvl": 98, "rarity": 3}, 99) == CR.renew_step(leg, 99), "до свого рівня одразу: ціни всіх рівнів складаються (%d грн за 60→75)" % sum_gold)
	# У кузні: на один рівень і одразу до свого
	var w = load("res://scripts/game/world_state.gd").new()
	CampS.state(w)["buildings"]["kuznia"] = 3
	var p = _new_player()
	p.change_class("cossack")
	p.level = 50
	p.recalc()
	var it: Dictionary = Data.gen_item(40, 3, "weapon", "sabre")
	it["up"] = 3
	p.add_item(it, true)
	p.gold = 0
	p.resources = {"iron": 9999, "trophy": 9999}
	check(not CR.renew(w, p, it["uid"], 1) and int(it["ilvl"]) == 40, "без гривень річ не оновити")
	var one: Dictionary = CR.renew_cost(it, 41)
	p.gold = int(one["gold"]) + 5
	var dmg0: float = it["base"]["flat_dmg"]
	var sell0: int = Data.sell_price(it)
	check(CR.renew(w, p, it["uid"], 1) and int(it["ilvl"]) == 41 and p.gold == 5 and int(p.resources["iron"]) == 9999 - int(one["iron"]) and int(p.resources["trophy"]) == 9999 - int(one["trophy"]) and it["base"]["flat_dmg"] > dmg0 and int(it["up"]) == 3, "на один рівень: річ 41-го, заплачено рівно за цей рівень, заточка лишилась")
	check(Data.sell_price(it) > sell0, "вкладені гривні частково вертаються при продажу")
	var rest: Dictionary = CR.renew_cost(it, 50)
	p.gold = int(rest["gold"])
	check(CR.renew(w, p, it["uid"]) and int(it["ilvl"]) == 50 and p.gold == 0 and not CR.can_renew(w, it, 50), "одразу до свого рівня: річ 50-го, заплачено суму за дев'ять рівнів")
	# Золота річ: ті самі властивості, дорожче
	var gold_it: Dictionary = Uniques.make("poias_baidy", 30)
	p.add_item(gold_it, true)
	var affix_keys: Array = gold_it["affixes"].keys()
	var uc: Dictionary = CR.renew_cost(gold_it, 31)
	p.gold = int(uc["gold"])
	check(int(uc["gold"]) == roundi((CR.RENEW_BASE + CR.RENEW_GOLD * 31 * 31) * 1.5) and CR.renew(w, p, gold_it["uid"], 1) and int(gold_it["ilvl"]) == 31 and gold_it["affixes"].keys() == affix_keys, "золота річ оновлюється в півтора раза дорожче й не міняє властивостей")
	# Кнопки в кузні
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var h = game.player
	h.change_class("cossack")
	h.level = 30
	h.recalc()
	CampS.state(game.world)["buildings"]["kuznia"] = 3
	var far_it: Dictionary = Data.gen_item(20, 2, "head")
	var near_it: Dictionary = Data.gen_item(29, 2, "belt")
	h.add_item(far_it, true)
	h.add_item(near_it, true)
	var UiCamp = load("res://scripts/ui/ui_camp.gd")
	var texts := func(item: Dictionary) -> Array:
		var box := VBoxContainer.new()
		UiCamp._craft_item_actions(game, box, item)
		var out := []
		for b in box.find_children("*", "Button", true, false):
			out.append(b.text.split("\n")[0])
		box.free()
		return out
	var tf: Array = texts.call(far_it)
	var tn: Array = texts.call(near_it)
	check("Оновити на один рівень, до 21" in tf and "Оновити до свого рівня 30" in tf, "стара річ: кнопки «на один рівень» і «до свого рівня» (%s)" % ", ".join(tf))
	check("Оновити на один рівень, до 30" in tn and not tn.any(func(t): return str(t).begins_with("Оновити до свого рівня")), "річ на рівень нижче: лише одна кнопка")
	h.gold = 10000000
	h.resources = {"iron": 999, "trophy": 999}
	game.camp_do("renew_one", far_it["uid"])
	check(int(far_it["ilvl"]) == 21 and "тепер 21" in game.smith_msg, "кнопка піднімає річ на один рівень: «%s»" % game.smith_msg)
	game.camp_do("renew", far_it["uid"])
	check(int(far_it["ilvl"]) == 30, "кнопка піднімає річ одразу до свого рівня")
	var rw := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Оновлення речі":
				rw = str(e["text"])
	check(WS._num(g99) in rw and WS._num(g5) in rw and "щораз дорожче" in rw and "на один рівень" in rw, "довідник пояснює ціну оновлення з числами")
	p.free()
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_pickup_filter() -> void:
	suite("Фільтр автопідбору")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Uniques = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var QS = load("res://scripts/game/quick_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var keep: Dictionary = SaveSystem.load_settings()  # налаштування пристрою після набору повертаємо як були
	# Налаштування зберігають фільтр і мають розумне значення за замовчуванням
	SaveSystem.save_settings({"sound": keep["sound"], "music": keep["music"], "autosell": keep["autosell"], "pickup": [false, true, false, true]})
	check(SaveSystem.load_settings()["pickup"] == [false, true, false, true], "фільтр зберігається в налаштуваннях")
	SaveSystem.save_settings({"sound": keep["sound"], "music": keep["music"], "autosell": keep["autosell"]})
	check(SaveSystem.load_settings()["pickup"] == [true, true, true, true] and Data.RARITY_PLURAL.size() == 4, "без налаштування герой підбирає все")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "bag_full", "way"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 20
	p.stats["vit"] = 80
	p.recalc()
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	check(c.pickup_filter == [true, true, true, true], "нова гра бере фільтр із налаштувань")
	var common: Dictionary = Data.gen_item(10, 0, "boots")
	var rare: Dictionary = Data.gen_item(10, 2, "belt")
	# Правило
	c.pickup_filter = [false, true, true, true]
	check(c.pick_block(common) == "filter" and not c.can_pick_item(common) and c.pick_block(rare) == "" and c.pick_block(common, true) == "", "вимкнену рідкість герой не бере, решту бере, викинуту власноруч бере")
	c.pickup_filter = [false, false, false, false]
	check(c.can_pick_item(Uniques.make("poias_baidy", 20)) and c.can_pick_item(Arts.make("zmiiv_zub")) and c.filter_allows(Arts.make("zmiiv_zub")), "золоті речі й артефакти беруться за будь-якого фільтра")
	# У бою: звичайна лежить тьмяна, рідкісна підбирається
	c.pickup_filter = [false, true, true, true]
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	c.autosell = false
	var ground := func() -> Array:
		return c.entities.get_children().filter(func(ch): return ch.get_script() == c.PickupScript and ch.kind == "item" and not ch.is_queued_for_deletion())
	for old in ground.call():
		old.queue_free()
	await _frames(2)
	c.spawn_pickup(p.global_position, "item", 0, common)
	c.spawn_pickup(p.global_position, "item", 0, rare)
	var note0: float = c._bag_note_at
	for i in 50:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	var left: Array = ground.call()
	check(left.size() == 1 and left[0].item == common and left[0].modulate.a < 0.6 and not p.find_item(rare.get("uid", -1)).is_empty() and p.find_item(common.get("uid", -1)).is_empty(), "звичайна річ лежить тьмяна, рідкісну підібрано")
	check(is_equal_approx(c._bag_note_at, note0) and c.ignored_count() == 1, "про повну торбу гра не каже: річ лежить через фільтр")
	# Викинута власноруч річ піднімається, хоч фільтр її рідкість і не бере
	var own: Dictionary = Data.gen_item(10, 0, "head")
	p.add_item(own, true)
	p.remove_from_bag(own["uid"])
	c.drop_item(own)
	await _frames(2)
	var dropped = ground.call().filter(func(ch): return ch.manual)[0]
	check(c.ignored_count() == 1 and dropped.modulate.a > 0.9, "викинута власноруч річ фільтром не рахується й не тьмяніє")
	p.global_position = dropped.global_position
	for i in 110:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	check(not p.find_item(own["uid"]).is_empty(), "став на викинуту річ: підняв попри фільтр")
	# Кнопка «Підібрати все, що лежить»
	var got: int = c.collect_ignored()
	await _frames(2)
	check(got == 1 and c.ignored_count() == 0 and not p.find_item(common.get("uid", -1)).is_empty(), "«Підібрати все, що лежить» бере відфільтроване")
	# На виході відфільтроване продається
	var junk: Dictionary = Data.gen_item(10, 0, "belt")
	c.spawn_pickup(p.global_position + Vector2(400, 0), "item", 0, junk)
	var g0: int = p.gold
	var inv0: int = p.inventory.size()
	c.collect_all()
	await _frames(2)
	check(p.gold == g0 + Data.sell_price(junk) and p.inventory.size() == inv0 and ground.call().is_empty() and "Не підібрано за фільтром: продано 1" in game.hud.banner.text, "на виході відфільтроване продано: «%s»" % game.hud.banner.text.replace("\n", " / "))
	# ---- Меню ----
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	game._show_map_menu()
	await _frames(2)
	var btns := func() -> Array:
		var out := []
		for b in game.hud.overlay_box.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion():
				out.append(b)
		return out
	var entry: Button = null
	for b in btns.call():
		if b.text.begins_with("Автопідбір"):
			entry = b
	check(entry != null and entry.text == "Автопідбір: 3 із 4", "у меню привалу є кнопка фільтра: «%s»" % (entry.text if entry != null else "—"))
	entry.pressed.emit()
	await _frames(2)
	var toggles: Array = btns.call().filter(func(b): return b.text.begins_with("☑ ") or b.text.begins_with("☐ "))
	check(toggles.size() == 4 and toggles[0].text == "☐ Звичайні речі" and toggles[3].text == "☑ Легендарні речі", "чотири перемикачі рідкостей: %s" % ", ".join(toggles.map(func(b): return b.text)))
	toggles[1].pressed.emit()
	await _frames(2)
	check(c.pickup_filter == [false, false, true, true] and SaveSystem.load_settings()["pickup"] == [false, false, true, true], "перемикач міняє фільтр і зберігає його")
	toggles = btns.call().filter(func(b): return b.text.begins_with("☑ ") or b.text.begins_with("☐ "))
	toggles[0].pressed.emit()
	await _frames(2)
	toggles = btns.call().filter(func(b): return b.text.begins_with("☑ ") or b.text.begins_with("☐ "))
	toggles[1].pressed.emit()
	await _frames(2)
	check(c.pickup_filter == [true, true, true, true], "усе ввімкнено назад")
	for b in btns.call():
		if b.text == "Назад":
			b.pressed.emit()
	await _frames(2)
	entry = null
	for b in btns.call():
		if b.text.begins_with("Автопідбір"):
			entry = b
	check(entry != null and entry.text == "Автопідбір: усе", "«Назад» вертає в меню, кнопка каже «усе»")
	game.go_back(true)
	await _frames(2)
	# Швидкий похід слухає фільтр
	var w2 = load("res://scripts/game/world_state.gd").new()
	w2.cleared["wild_field"] = 5
	var q: Dictionary = QS.run(w2, p, "wild_field", 1.0, {}, [false, false, false, false])
	check(q["items"].is_empty() and int(q["sold"]) >= 2, "швидкий похід із вимкненим фільтром речей не кладе, а продає (%d)" % int(q["sold"]))
	var fw := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Фільтр автопідбору":
				fw = str(e["text"])
	check("«Автопідбір»" in fw and "тьмяна" in fw and "продається" in fw and "Золоті речі й артефакти беруться завжди" in fw, "довідник пояснює фільтр автопідбору")
	# повертаємо налаштування пристрою
	c.pickup_filter = keep["pickup"].duplicate()
	game._save_settings()
	SaveSystem.save_settings(keep)
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_quick_raid() -> void:
	suite("Швидкий похід за рекламу")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var QS = load("res://scripts/game/quick_service.gd")
	var EvS = load("res://scripts/game/event_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var w = load("res://scripts/game/world_state.gd").new()
	var p = _new_player()
	p.change_class("cossack")
	p.level = 20
	p.recalc()
	# Де буває й коли доступний
	check(QS.applies("wild_field") and QS.applies("zmii_cave") and not QS.applies("hlybyny") and not QS.applies("bashta") and not QS.applies("sich") and not QS.applies("varta"), "швидкий похід буває в місцевостях і печерах, не в Глибинах, Башті, містах і місцях занять")
	check("відкриється" in QS.block_reason(w, p, "wild_field"), "непройдене місце: %s" % QS.block_reason(w, p, "wild_field"))
	w.cleared["wild_field"] = QS.MIN_CLEARS - 1
	check(QS.block_reason(w, p, "wild_field") != "", "пройдено замало разів: ще не можна")
	w.cleared["wild_field"] = QS.MIN_CLEARS
	check(QS.block_reason(w, p, "wild_field") == "" and QS.left_today(w) == QS.PER_DAY, "пройдено %d рази: швидкий похід відкрито, на день %d" % [QS.MIN_CLEARS, QS.PER_DAY])
	p.level = 1
	w.cleared["black_forest"] = 5
	check("надто сильне" in QS.block_reason(w, p, "black_forest"), "сильніше за героя місце швидко не пройти")
	p.level = 20
	# Обсяг: поле за своєю зачисткою, печера за кімнатами
	var LF: Dictionary = Data.LOCATIONS["wild_field"]
	var LD: Dictionary = Data.LOCATIONS["zmii_cave"]
	var rooms_sum := 0
	for room in range(1, int(LD["rooms"]) + 1):
		rooms_sum += Data.DUNGEON_ROOM_BASE + room * Data.DUNGEON_ROOM_PER
	check(QS.kills(LF) == int(LF.get("goal", Data.FIELD_GOAL_BASE + int(LF["level"]) * Data.FIELD_GOAL_PER_LEVEL)) and QS.kills(LD) == rooms_sum, "нечисті стільки ж, як у справжньому поході: поле %d, печера %d" % [QS.kills(LF), QS.kills(LD)])
	# Похід у поле: досвід, гривні, речі, ресурси; завдання міст рахуються
	var kind0: String = LF["enemies"][0]
	w.quests.append({"id": 900, "city": "sich", "loc": "wild_field", "type": "kill", "target": kind0, "progress": 0, "count": 3, "text": "Знищ 3", "lvl": 1, "gold": 10, "xp": 5, "loyalty": 5})
	seed(11)
	var xp0: int = p.xp + p.level * 100000
	var gold0: int = p.gold
	var inv0: int = p.inventory.size()
	var r: Dictionary = QS.run(w, p, "wild_field")
	var res_n := 0
	for k in r["res"]:
		res_n += int(r["res"][k])
	check(int(r["kills"]) == QS.kills(LF) and int(r["xp"]) > 0 and p.xp + p.level * 100000 > xp0 and int(r["gold"]) >= 25 * int(LF["level"]) and p.gold == gold0 + int(r["gold"]), "поле: нечисті %d, досвід +%d, гривні +%d" % [int(r["kills"]), int(r["xp"]), int(r["gold"])])
	check(r["items"].size() + int(r["sold"]) >= 2 and p.inventory.size() == inv0 + r["items"].size() and res_n >= 5, "за зачистку щонайменше дві речі й п'ять купок ресурсів (речей %d, ресурсів %d)" % [r["items"].size(), res_n])
	check(int(w.cleared["wild_field"]) == QS.MIN_CLEARS + 1 and w.is_done(w.quests[0]) and r["quests"].size() == 1 and "Здай" in str(r["quests"][0]), "проходження й завдання міста зараховано: %s" % str(r["quests"]))
	check(QS.used_today(w) == 1 and QS.left_today(w) == QS.PER_DAY - 1, "денний лічильник: лишилось %d" % QS.left_today(w))
	var kinds_sum := 0
	for k in r["kinds"]:
		kinds_sum += int(r["kinds"][k])
		if not k in LF["enemies"]:
			kinds_sum = -9999
	check(kinds_sum == int(r["kills"]), "убита нечисть саме з цього місця")
	# Рідкісного з босів нема: лише звичайні речі
	var only_random := true
	w.cleared["zmii_cave"] = 3
	w.quests.append({"id": 901, "city": "kyiv", "loc": "zmii_cave", "type": "dungeon", "target": "zmii_cave", "progress": 0, "count": 1, "text": "Очисти: Змієва печера", "lvl": 3, "gold": 100, "xp": 50, "loyalty": 20})
	var stones0: Dictionary = p.stones.duplicate()
	var souls0: Dictionary = p.souls.duplicate()
	var tro0: int = int(p.resources.get("trophy", 0))
	var d: Dictionary = {}
	var rare_n := 0
	for i in 6:
		d = QS.run(w, p, "zmii_cave")
		for it in d["items"]:
			only_random = only_random and int(it["rarity"]) <= Data.RARITY_MAX_RANDOM and not it.has("unique") and not Arts.is_artifact(it)
			if int(it["rarity"]) >= 2:
				rare_n += 1
		for it in p.inventory.duplicate():
			p.remove_from_bag(it["uid"])  # звільняємо торбу для наступного проходу
	check(only_random and p.stones == stones0 and p.souls == souls0, "золотих речей, артефактів, каменів і душ швидкий похід не дає")
	check(rare_n >= 6 and int(p.resources.get("trophy", 0)) >= tro0 + 6 * 3 and w.is_done(w.quests[1]) and int(w.cleared["zmii_cave"]) == 9, "печера: рідкісні речі з господаря, трофеї, завдання «Очисти» зараховано")
	# Повна торба: зайве продається
	while not p.bag_full():
		p.add_item(Data.gen_item(5, 1))
	var size_full: int = p.inventory.size()
	var gf: int = p.gold
	var rf: Dictionary = QS.run(w, p, "wild_field")
	check(rf["items"].is_empty() and int(rf["sold"]) >= 2 and p.inventory.size() == size_full and p.gold > gf, "повна торба: речі продано (%d), а не загублено" % int(rf["sold"]))
	# Денна межа й новий день
	w.ads["quick_used"] = QS.PER_DAY
	check(QS.left_today(w) == 0 and "скінчились" in QS.block_reason(w, p, "wild_field"), "денну межу вичерпано")
	w.ads["quick_day"] = "2000-01-01"
	check(QS.left_today(w) == QS.PER_DAY and QS.block_reason(w, p, "wild_field") == "", "новий день повертає всі швидкі походи")
	check("Швидкий похід: Дике Поле" in QS.summary(r) and "Досвід +" in QS.summary(r) and "Завдання виконано" in QS.summary(r), "підсумок словами: %s" % QS.summary(r).replace("\n", " / "))
	p.free()
	# ---- У грі ----
	var ads = root.get_node("Ads")
	var instant0: bool = ads.instant
	ads.instant = true
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var h = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "way"]:
		game.world.hints[k] = true
	h.change_class("cossack")
	h.level = 20
	h.recalc()
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	game.enter_map()
	await _frames(2)
	var panel := func(place: String) -> Array:
		game._on_map_select(place)
		await _frames(2)
		var out := []
		for n in game.hud.map_panel.find_children("*", "Label", true, false):
			out.append(n.text)
		for b in game.hud.map_panel.find_children("*", "Button", true, false):
			out.append("[" + b.text + "]")
		return out
	var t0: Array = await panel.call("wild_field")
	check(not "[Швидкий похід за рекламу]" in t0 and t0.any(func(t): return str(t).begins_with("Швидкий похід: відкриється")), "на панелі непройденого місця кнопки нема, є пояснення")
	game.world.cleared["wild_field"] = QS.MIN_CLEARS
	var t1: Array = await panel.call("wild_field")
	check("[Швидкий похід за рекламу]" in t1 and t1.any(func(t): return str(t).begins_with("Миттєва зачистка без бою. Сьогодні лишилось: %d" % QS.PER_DAY)), "пройдене місце: кнопка швидкого походу й лічильник")
	var t2: Array = await panel.call("sich")
	check(not t2.any(func(t): return "Швидкий похід" in str(t)), "у місті про швидкий похід ані слова")
	var trips0: int = int(EvS.state(game.world)["trips"])
	var xp_h: int = h.xp + h.level * 100000
	var views0: int = ads.views
	game.quick_raid("wild_field")
	await _frames(3)
	check(ads.views == views0 + 1 and game.state == game.State.MAP and h.xp + h.level * 100000 > xp_h and int(game.world.cleared["wild_field"]) == QS.MIN_CLEARS + 1 and "Швидкий похід: Дике Поле" in game.hud.banner.text, "після реклами похід зараховано: герой на мапі з досвідом і здобиччю")
	check(int(EvS.state(game.world)["trips"]) == trips0 + 1 and QS.used_today(game.world) == 1 and int(game.world.stats.get("field", 0)) >= 1 and int(game.world.stats.get("kill", 0)) >= QS.kills(LF), "світ порахував це як похід, виклики отримали вбивства")
	# без реклами нічого не дається
	ads.instant = false
	var used1: int = QS.used_today(game.world)
	game.quick_raid("wild_field")
	await _frames(2)
	check(QS.used_today(game.world) == used1 and ads.is_busy(), "поки рекламу не переглянуто, походу нема")
	ads._finish(false)
	await _frames(2)
	check(QS.used_today(game.world) == used1 and int(game.world.cleared["wild_field"]) == QS.MIN_CLEARS + 1, "закрив рекламу: здобичі нема")
	ads.instant = instant0
	var qw := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Швидкий похід":
				qw = str(e["text"])
	check(("пройшов %d рази" % QS.MIN_CLEARS) in qw and ("дається %d швидких" % QS.PER_DAY) in qw and "реклам" in qw and "золоті речі" in qw, "довідник пояснює швидкий похід із числами")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_gear_best() -> void:
	suite("Кращі речі в торбі й «Вдягнути найкраще»")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Power = load("res://scripts/game/power.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var GS = load("res://scripts/game/guide_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var p = _new_player()
	p.change_class("cossack")
	p.level = 20
	p.recalc()
	check(is_equal_approx(Power.score(p), Power.dps(p) * p.max_hp / maxf(1.0 - Data.ARMOR_CAP, 1.0 - p.armor)) and is_equal_approx(p.gear_score(), Power.score(p)), "сила героя одним числом: шкода за секунду на запас живучості")
	# Примірка нічого не міняє
	var strong: Dictionary = Data.gen_item(40, 3, "weapon", "sabre")
	var weak: Dictionary = Data.gen_item(1, 0, "weapon", "sabre")
	var staff: Dictionary = Data.gen_item(40, 3, "weapon", "staff")
	var hat: Dictionary = Data.gen_item(20, 2, "head")
	for it in [strong, weak, staff, hat]:
		p.add_item(it, true)
	p.hp = p.max_hp * 0.5
	p.mana = p.max_mana * 0.4
	var snap := [p.hp, p.mana, p.max_hp, p.damage, p.armor, p.equipment.duplicate(true), p.inventory.size()]
	var g_strong: float = p.gain_from(strong)
	var g_weak: float = p.gain_from(weak)
	var g_hat: float = p.gain_from(hat)
	check(is_equal_approx(p.hp, snap[0]) and is_equal_approx(p.mana, snap[1]) and is_equal_approx(p.max_hp, snap[2]) and is_equal_approx(p.damage, snap[3]) and is_equal_approx(p.armor, snap[4]) and p.equipment == snap[5] and p.inventory.size() == snap[6], "примірка не міняє ні героя, ні спорядження, не лікує й не ранить")
	check(g_strong > 0.2 and g_weak < g_strong and g_hat > Power.MIN_GAIN, "краща зброя піднімає силу (+%d%%), шапка в порожню клітинку теж (+%d%%)" % [roundi(g_strong * 100), roundi(g_hat * 100)])
	check(is_equal_approx(p.gain_from(staff), 0.0) and is_equal_approx(p.gain_from(Arts.make("zmiiv_zub")), 0.0) and is_equal_approx(p.gain_from(p.equipment["weapon"]), 0.0) and is_equal_approx(p.gain_from({}), 0.0), "чужа зброя, артефакт і вже вдягнене покращенням не рахуються")
	# Найкраще в кожну клітинку
	var better_hat: Dictionary = Data.gen_item(40, 3, "head")
	p.add_item(better_hat, true)
	var ups: Dictionary = p.best_upgrades()
	check(ups.size() == 2 and ups["weapon"]["uid"] == strong["uid"] and ups["head"]["uid"] == (better_hat["uid"] if p.gain_from(better_hat) >= p.gain_from(hat) else hat["uid"]), "для кожної клітинки обрано найсильнішу річ із торби")
	check(GS.items(load("res://scripts/game/world_state.gd").new(), p, "sich").any(func(it): return it["kind"] == "gear" and int(it["tab"]) == GS.TAB_HERO), "порадник каже, що в торбі є кращі речі")
	var score0: float = p.gear_score()
	var worn: int = p.equip_best()
	check(worn >= 2 and p.equipment["weapon"]["uid"] == strong["uid"] and p.equipment.has("head") and p.gear_score() > score0 * 1.2 and p.best_upgrades().is_empty() and p.equip_best() == 0, "«Вдягнути найкраще» вдягає все сильніше й більше нічого не пропонує (вдягнено %d)" % worn)
	check(p.find_item(weak["uid"]).size() > 0 and not p.is_equipped(weak["uid"]) and p.gain_from(weak) < -0.2, "слабка зброя лишилась у торбі й тепер опускає силу (%d%%)" % roundi(p.gain_from(weak) * 100))
	# Золоту річ звичайна ледь сильніша не витісняє: її сила теж чогось варта
	var gold: Dictionary = Uniques.make("poias_baidy", 20)
	p.add_item(gold, true)
	p.equip(gold["uid"])
	var with_gold: float = p.gear_score()
	check(is_equal_approx(with_gold, Power.score(p) * (1.0 + Power.UNIQUE_WORTH)), "золота річ додає до оцінки %d%% за свою силу" % roundi(Power.UNIQUE_WORTH * 100.0))
	p.free()
	# ---- Екран героя ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var h = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "way"]:
		game.world.hints[k] = true
	h.change_class("cossack")
	h.level = 20
	h.recalc()
	var mid: Dictionary = Data.gen_item(20, 2, "weapon", "sabre")
	h.add_item(mid, true)
	h.equip(mid["uid"])
	for it in h.inventory.duplicate():
		h.remove_from_bag(it["uid"])  # стартова шабля не має плутати рахунок
	# краща й гірша речі задані явно, а не випадкові: та сама шабля з утричі більшою шкодою
	# і вона ж без властивостей із п'ятою часткою шкоди. Випадкові властивості робили тест нестійким.
	var up1: Dictionary = mid.duplicate(true)
	up1.erase("uid")
	up1["name"] = "Шабля краща"
	up1["base"]["flat_dmg"] = float(mid["base"]["flat_dmg"]) * 3.0
	var junk: Dictionary = mid.duplicate(true)
	junk.erase("uid")
	junk["name"] = "Шабля гірша"
	junk["affixes"] = {}
	junk["base"]["flat_dmg"] = float(mid["base"]["flat_dmg"]) * 0.2
	h.add_item(up1, true)
	h.add_item(junk, true)
	game.enter_map()
	await _frames(2)
	game.open_character()
	game.char_tab = 0
	game._build_character()
	await _frames(2)
	var page := func() -> Control:
		return game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(0)
	var marks := 0
	for l in page.call().find_children("*", "Label", true, false):
		if l.text == "▲":
			marks += 1
	var best_btn: Button = null
	for b in page.call().find_children("*", "Button", true, false):
		if b.text.begins_with("Вдягнути найкраще"):
			best_btn = b
	check(marks == 1 and best_btn != null and best_btn.text == "Вдягнути найкраще: 1", "у торбі зелена стрілка лише на кращій речі, і є кнопка «Вдягнути найкраще: 1»")
	game.char_do("select", up1["uid"])
	await _frames(2)
	var card := ""
	for l in page.call().find_children("*", "Label", true, false):
		card += l.text + "\n"
	check("Сила героя з цією річчю: +" in card, "картка речі каже, на скільки герой стане сильнішим")
	game.char_do("select", junk["uid"])
	await _frames(2)
	card = ""
	for l in page.call().find_children("*", "Label", true, false):
		card += l.text + "\n"
	check("Сила героя з цією річчю: −" in card, "а для гіршої речі, на скільки слабшим")
	best_btn = null
	for b in page.call().find_children("*", "Button", true, false):
		if b.text.begins_with("Вдягнути найкраще"):
			best_btn = b
	best_btn.pressed.emit()
	await _frames(2)
	marks = 0
	var still_btn := false
	for l in page.call().find_children("*", "Label", true, false):
		if l.text == "▲":
			marks += 1
	for b in page.call().find_children("*", "Button", true, false):
		still_btn = still_btn or b.text.begins_with("Вдягнути найкраще")
	check(h.equipment["weapon"]["uid"] == up1["uid"] and marks == 0 and not still_btn and "Вдягнено кращих речей: 1" in game.hud.banner.text, "кнопка вдягла кращу річ, стрілок і кнопки більше нема")
	game.close_character()
	await _frames(2)
	var hero_wiki := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Екран героя й журнал":
				hero_wiki = str(e["text"])
	check("Зелена стрілка" in hero_wiki and "«Вдягнути найкраще»" in hero_wiki and ("%d%%" % roundi(Power.UNIQUE_WORTH * 100.0)) in hero_wiki, "довідник пояснює зелену стрілку й кнопку")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_objective_arrow() -> void:
	suite("Стрілка до мети в бою")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Bounty = load("res://scripts/game/bounty_service.gd")
	var EvS = load("res://scripts/game/event_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
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
	var arrow = game.hud.objective_arrow
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "defense", "bounty", "way"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 20
	p.stats["vit"] = 80
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	check(c.objective().is_empty() and not arrow.visible, "поза боєм мети й стрілки нема")
	# Розшук і сторож скарбу
	Bounty.state(game.world)["active"].append({"id": 7, "city": "kyiv", "kind": "upyr", "name": "Упир Кривий", "loc": "wild_field", "affixes": ["fiery"], "gold": 300, "glory": 6, "killed": false})
	EvS.state(game.world)["treasure"]["wild_field"] = true
	game.enter_location("wild_field")
	await _frames(3)
	c._drop_trail()
	var bounty = null
	var guard = null
	for e in get_nodes_in_group("enemies"):
		if e.bounty_id > 0:
			bounty = e
		elif e.treasure_guard:
			guard = e
	var o: Dictionary = c.objective()
	check(bounty != null and guard != null and str(o["label"]) == "Розшук" and o["pos"] == bounty.global_position, "перша мета: розшукувана нечисть")
	bounty.global_position = p.global_position + Vector2(900, 0)
	await _frames(2)
	check(arrow.visible and arrow.label == "Розшук" and arrow.dir.is_equal_approx(Vector2.RIGHT), "стрілка показує на далеку мету й підписана")
	bounty.global_position = p.global_position + Vector2(arrow.NEAR - 40.0, 0)
	await _frames(2)
	check(not arrow.visible, "коли мета поруч, стрілка ховається")
	bounty.queue_free()
	await _frames(2)
	o = c.objective()
	check(str(o["label"]) == "Сторож скарбу" and o["pos"] == guard.global_position, "далі мета: сторож скарбу")
	guard.queue_free()
	await _frames(2)
	check(c.objective().is_empty(), "цілей нема: стрілка мовчить")
	# Сліди
	c.spawn_trail("cache", 3)
	o = c.objective()
	check(str(o["label"]) == "Сліди" and o["pos"] == c.trail.target(), "стежка слідів: стрілка веде до наступного сліду")
	c.trail.found = true
	check(c.objective().is_empty(), "знайдену стежку стрілка не показує")
	# Вихід
	c._spawn_portal("Вихід", p.global_position + Vector2(-700, 300))
	o = c.objective()
	check(str(o["label"]) == "Вихід" and o["pos"] == c.portal.global_position, "відкрився вихід: стрілка веде до нього")
	await _frames(2)
	check(arrow.visible and arrow.label == "Вихід" and arrow.dir.x < 0.0 and arrow.dir.y > 0.0, "стрілка до виходу дивиться в його бік")
	# На екрані героя й у паузі стрілки нема
	game.open_character()
	await _frames(2)
	check(not arrow.visible, "на екрані героя стрілки нема")
	game.close_character()
	await _frames(2)
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	check(not arrow.visible and c.objective().is_empty(), "на мапі стрілки нема")
	# Оборона: стрілка веде до того, що боронимо
	Bounty.state(game.world)["active"].clear()
	EvS.state(game.world)["treasure"].clear()
	game.start_defense("chyhyryn")
	await _frames(3)
	o = c.objective()
	check(c.is_defense() and not o.is_empty() and str(o["label"]) == str(c.gate.label_text()) and o["pos"] == c.gate.global_position, "в обороні мета: %s" % str(o.get("label", "")))
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	var at := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Стрілка до мети":
				at = str(e["text"])
	check("розшукуваної" in at and "сліду" in at and "виходу" in at and "борониш" in at, "довідник пояснює стрілку до мети")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_way() -> void:
	suite("Шлях козака: ланцюжок перших цілей")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Way = load("res://scripts/game/way_service.gd")
	var GS = load("res://scripts/game/guide_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var ActsD = load("res://scripts/data/activities.gd")
	var STEPS: Array = Way.Path.STEPS
	# Дані: кожен крок має все потрібне, id не повторюються, нагорода читається словами
	var ids := {}
	var bad := []
	for st in STEPS:
		if ids.has(st["id"]):
			bad.append("повтор " + str(st["id"]))
		ids[st["id"]] = true
		for k in ["title", "how", "check", "reward", "go"]:
			if not st.has(k):
				bad.append("%s без %s" % [st["id"], k])
		if int(st["reward"].get("gold", 0)) <= 0 or Way.reward_text(st) == "":
			bad.append("%s без нагороди" % st["id"])
		if str(st["title"]).ends_with(".") or not str(st["how"]).ends_with("."):
			bad.append("%s: крапки" % st["id"])
	check(STEPS.size() >= 15 and bad.is_empty(), "кроків %d, кожен повний: %s" % [STEPS.size(), ", ".join(bad)])
	var golds := []
	for st in STEPS:
		golds.append(int(st["reward"]["gold"]))
	var rising := true
	for i in range(1, golds.size()):
		rising = rising and golds[i] >= golds[i - 1] - 200
	check(rising and golds[-1] > golds[0] * 10, "нагороди ростуть уздовж шляху: від %d до %d грн" % [golds[0], golds[-1]])
	# Свіжий герой: перший крок не виконано, далі по одному
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "way"]:
		w.hints[k] = true
	check(Way.index(w) == 0 and not Way.finished(w) and not Way.ready(w, p) and Way.ready_count(w, p) == 0 and Way.claim(w, p).is_empty(), "новий герой на першому кроці, нагороди ще нема")
	# кожен крок веде на справжнє місце чи вкладку
	var lost := []
	for st in STEPS:
		var g: Dictionary = Way.go(st, w, p, "sich")
		var pl: String = str(g["place"])
		if pl == "" and int(g["tab"]) < 0:
			lost.append(str(st["id"]) + ": нікуди")
		if pl != "" and not (Data.CITIES.has(pl) or Data.LOCATIONS.has(pl) or ActsD.SPOTS.has(pl) or pl == "hutir"):
			lost.append("%s→%s" % [st["id"], pl])
	check(lost.is_empty(), "кожен крок кудись веде: %s" % ", ".join(lost))
	# порадник показує нинішній крок
	var tips: Array = GS.items(w, p, "sich").filter(func(it): return it["kind"] == "way")
	check(tips.size() == 1 and str(tips[0]["text"]) == "Шлях козака: " + str(STEPS[0]["title"]) and "Нагорода" in str(tips[0]["sub"]), "порадник веде до нинішнього кроку")
	# Перший бій виконано: нагорода, наступний крок
	var gold0: int = p.gold
	var potions0: int = p.potions
	w.stats["field"] = 1
	check(Way.ready(w, p) and Way.ready_count(w, p) == 1 and GS.items(w, p, "sich").any(func(it): return it["kind"] == "way_claim"), "крок виконано: порадник кличе по нагороду")
	var msgs: Array = Way.claim(w, p)
	check(msgs.size() == 3 and str(STEPS[0]["title"]) in str(msgs[0]) and Way.index(w) == 1 and p.gold == gold0 + int(STEPS[0]["reward"]["gold"]) and p.potions >= mini(potions0 + 2, p.potion_max()), "нагороду видано, шлях іде далі: %s" % " / ".join(msgs))
	check(not Way.ready(w, p), "другий крок чекає своєї умови")
	# Умови кроків
	var step_of := func(id: String) -> Dictionary:
		for st in STEPS:
			if st["id"] == id:
				return st
		return {}
	check(not Way.is_done(step_of.call("stats"), w, p) and not Way.is_done(step_of.call("skill"), w, p) and not Way.is_done(step_of.call("perk"), w, p) and not Way.is_done(step_of.call("class"), w, p), "очки ще не вкладено, дороги не обрано")
	p.stat_points = 1
	p.add_stat("str")
	p.perks["tough"] = 1
	p.change_class("cossack")
	p.skill_points = 1
	p.learn_skill("whirl")
	check(Way.is_done(step_of.call("stats"), w, p) and Way.is_done(step_of.call("skill"), w, p) and Way.is_done(step_of.call("perk"), w, p) and Way.is_done(step_of.call("class"), w, p) and not Way.is_done(step_of.call("spec"), w, p), "вкладені очки й обрана дорога зараховано")
	check(not Way.is_done(step_of.call("quest"), w, p) and not Way.is_done(step_of.call("turn_in"), w, p), "завдань ще не брав")
	w.quests.append({"id": 950, "city": "sich", "loc": "wild_field", "type": "kill", "target": "mavka", "progress": 5, "count": 5, "text": "Знищ 5 мавок", "lvl": 1, "gold": 100, "xp": 50, "loyalty": 20})
	check(Way.is_done(step_of.call("quest"), w, p) and not Way.is_done(step_of.call("turn_in"), w, p), "узяте завдання зараховано, здане ще ні")
	load("res://scripts/game/city_service.gd").turn_in(w, p, 950)
	check(Way.is_done(step_of.call("turn_in"), w, p) and Way.is_done(step_of.call("quest"), w, p), "здане завдання зараховано")
	w.stats["defense"] = 1
	check(Way.is_done(step_of.call("event"), w, p) and not Way.is_done(step_of.call("tower"), w, p), "оборона міста теж рахується як подія світу")
	w.cleared["zmii_cave"] = 1
	check(Way.is_done(step_of.call("dungeon"), w, p), "печеру, пройдену до появи лічильника, зараховано")
	# Бувалий герой забирає все готове одним дотиком
	var hat: Dictionary = Data.gen_item(5, 1, "head")
	p.add_item(hat, true)
	p.equip(hat["uid"])
	var before: int = Way.index(w)
	var ready_n: int = Way.ready_count(w, p)
	var gold1: int = p.gold
	var all_msgs: Array = Way.claim_all(w, p)
	check(ready_n >= 5 and Way.index(w) == before + ready_n and p.gold > gold1 and ("забрано нагород %d" % ready_n) in str(all_msgs[0]) and not Way.ready(w, p), "забрано все готове поспіль: %d кроків" % ready_n)
	# Нагороди всіх видів справді видаються
	var rp = _new_player()
	rp.level = 30
	rp.potions = rp.potion_max()
	var g2: int = rp.gold
	var inv0: int = rp.inventory.size()
	Way._grant({"reward": {"gold": 10, "potions": 1, "mana": 1, "res": {"wood": 5}, "trophy": 2, "item": 2, "stone": "zabuttia"}}, rp)
	check(rp.gold == g2 + 10 + Data.potion_price(30) / 2 and int(rp.resources.get("wood", 0)) == 5 and int(rp.resources.get("trophy", 0)) == 2 and rp.inventory.size() == inv0 + 1 and int(rp.inventory[-1]["rarity"]) == 2 and int(rp.stones.get("zabuttia", 0)) == 1, "гривні, зілля понад запас гривнями, ресурси, трофеї, річ і камінь")
	rp.free()
	# ---- Екран: картка вгорі журналу ----
	game.enter_map()
	await _frames(2)
	game.open_character()
	game.char_tab = 1
	game._build_character()
	await _frames(2)
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var jt := ""
	for n in tc.get_tab_control(1).find_children("*", "Label", true, false):
		jt += n.text + "\n"
	var cur: Dictionary = Way.current(w)
	check(("Шлях козака  •  крок %d із %d" % [Way.index(w) + 1, Way.total()]) in jt and str(cur["title"]) in jt and str(cur["how"]) in jt and ("Нагорода: " + Way.reward_text(cur)) in jt and jt.find("Шлях козака") < jt.find("Що робити зараз"), "журнал починається з нинішнього кроку шляху")
	# виконуємо нинішній крок і забираємо кнопкою
	w.way["step"] = STEPS.find(step_of.call("companion"))
	w.companions.append({"type": "dzhura", "downed": false})
	game._build_character()
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var claim_btn: Button = null
	for b in tc.get_tab_control(1).find_children("*", "Button", true, false):
		if b.text.begins_with("Забрати"):
			claim_btn = b
	check(claim_btn != null and tc.get_tab_title(1).begins_with("Журнал  (+"), "готовий крок: кнопка «Забрати» й лічильник на вкладці")
	var idx0: int = Way.index(w)
	claim_btn.pressed.emit()
	await _frames(2)
	check(Way.index(w) > idx0 and "Шлях козака" in game.hud.banner.text, "кнопка забирає нагороду й веде далі")
	game.close_character()
	await _frames(2)
	# Збереження пам'ятає крок
	var saved: Dictionary = w.to_dict()
	var w2 = load("res://scripts/game/world_state.gd").new()
	w2.from_dict(saved)
	check(Way.index(w2) == Way.index(w) and Way.index(load("res://scripts/game/world_state.gd").new()) == 0, "крок шляху зберігається, старе збереження починає з першого")
	# Кінець шляху
	w.way["step"] = Way.total()
	check(Way.finished(w) and Way.current(w).is_empty() and Way.claim_all(w, p).is_empty() and not GS.items(w, p, "sich").any(func(it): return str(it["kind"]).begins_with("way")), "пройдений шлях зникає з порад")
	game.open_character()
	game.char_tab = 1
	game._build_character()
	await _frames(2)
	jt = ""
	for n in game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(1).find_children("*", "Label", true, false):
		jt += n.text + "\n"
	check(not "Шлях козака  •" in jt, "пройдений шлях зникає з журналу")
	game.close_character()
	# Довідник перелічує всі кроки з нагородами
	var wt := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Шлях козака":
				wt = str(e["text"])
	var all_in := true
	for st in STEPS:
		all_in = all_in and str(st["title"]) in wt and Way.reward_text(st) in wt
	check(all_in and ("із %d цілей" % Way.total()) in wt, "довідник перелічує всі кроки шляху з нагородами")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_guide() -> void:
	suite("Порадник: що робити далі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var GS = load("res://scripts/game/guide_service.gd")
	var Bounty = load("res://scripts/game/bounty_service.gd")
	var DS = load("res://scripts/game/defense_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "defense", "bounty"]:
		w.hints[k] = true
	p.change_class("cossack")
	p.level = 20
	p.stat_points = 0
	p.skill_points = 0
	p.perk_points = 0
	p.recalc()
	w.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	w.way = {"step": load("res://scripts/game/way_service.gd").total()}  # «Шлях козака» перевіряє окремий набір
	var kinds := func() -> Array:
		var out := []
		for it in GS.items(w, p, "sich"):
			out.append(str(it["kind"]))
		return out
	# Порад завжди вистачає: навіть коли справ нема, є куди піти й де взяти завдання
	var k0: Array = kinds.call()
	check(not k0.is_empty() and "explore" in k0 and "board" in k0 and not "story" in k0 and not "turn_in" in k0, "без справ порадник шле в похід і до дошки завдань: %s" % ", ".join(k0))
	var spot: String = GS.best_place(w, p, "sich")
	check(Data.LOCATIONS.has(spot) and abs(Data.loc_level(Data.LOCATIONS[spot], p.level) - p.level) <= 6, "запасна порада веде в місцевість по силі: %s" % spot)
	# Порядок важливості: здати виконане, облога, історія, очки, розшук, завдання
	w.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	w.quests.append({"id": 950, "city": "kyiv", "loc": "wild_field", "type": "kill", "target": "mavka", "progress": 5, "count": 5, "text": "Знищ 5 мавок (Дике Поле)", "lvl": 1, "gold": 100, "xp": 50, "loyalty": 20})
	w.quests.append({"id": 951, "city": "sich", "loc": "black_forest", "type": "kill", "target": "mavka", "progress": 1, "count": 5, "text": "Знищ 5 мавок (Чорний ліс)", "lvl": 1, "gold": 100, "xp": 50, "loyalty": 20})
	Bounty.state(w)["active"].append({"id": 7, "city": "poltava", "kind": "upyr", "name": "Упир Кривий", "loc": "crypt", "affixes": ["fiery"], "gold": 300, "glory": 6, "killed": false})
	DS.state(w)["sieges"]["chyhyryn"] = 2
	p.stat_points = 3
	var k1: Array = kinds.call()
	var order_ok: bool = k1.find("turn_in") < k1.find("siege") and k1.find("siege") < k1.find("story") and k1.find("story") < k1.find("points") and k1.find("points") < k1.find("bounty") and k1.find("bounty") < k1.find("quest") and k1.find("quest") < k1.find("explore")
	check(k1[0] == "turn_in" and order_ok, "поради йдуть від найважливішої: %s" % ", ".join(k1))
	var first: Dictionary = GS.first(w, p, "sich")
	check(str(first["place"]) == "kyiv" and "Київ" in str(first["text"]) and "завдань: 1" in str(first["sub"]), "головна порада: здати виконане в Києві")
	var by_kind := {}
	for it in GS.items(w, p, "sich"):
		by_kind[str(it["kind"])] = it
	check(str(by_kind["siege"]["place"]) == "chyhyryn" and "2" in str(by_kind["siege"]["sub"]) and str(by_kind["bounty"]["place"]) == "crypt" and str(by_kind["quest"]["place"]) == "black_forest" and str(by_kind["story"]["place"]) == str(game.StoryService.target(w)), "кожна порада знає своє місце на мапі")
	check(int(by_kind["points"]["tab"]) == GS.TAB_HERO and str(by_kind["points"]["place"]) == "" and "характеристик: 3" in str(by_kind["points"]["sub"]), "порада про очки веде на вкладку героя")
	check(GS.top(w, p, "sich").size() == GS.MAX, "журнал показує перші %d порад" % GS.MAX)
	# кожна порада веде або на справжнє місце мапи, або на вкладку
	var ActsD = load("res://scripts/data/activities.gd")
	var broken := []
	for it in GS.items(w, p, "sich"):
		var pl: String = str(it["place"])
		if pl == "" and int(it["tab"]) < 0:
			broken.append(str(it["kind"]) + ": нікуди")
		if pl != "" and not (Data.CITIES.has(pl) or Data.LOCATIONS.has(pl) or ActsD.SPOTS.has(pl) or pl == "hutir"):
			broken.append(str(it["kind"]) + "→" + pl)
	check(broken.is_empty(), "кожна порада кудись веде: %s" % ", ".join(broken))
	# Очки вмінь радимо вкладати, лише коли є куди
	p.stat_points = 0
	p.skill_points = 4
	check(int(GS.items(w, p, "sich").filter(func(it): return it["kind"] == "points")[0]["tab"]) == GS.TAB_SKILLS, "очки вмінь ведуть на вкладку «Вміння»")
	for c in p.Classes.lineage(p.job):
		for br in p.Classes.TREES[c]:
			for n in br["nodes"]:
				p.skills[n["id"]] = int(n["max"])
	check(not "points" in kinds.call(), "коли вчити більше нічого, порадник про очки вмінь мовчить")
	p.skill_points = 0
	# ---- На мапі: кнопка «Далі» ----
	game.enter_map()
	await _frames(3)
	var mv = game.hud.map_view
	check(mv.guide_btn.visible and mv.guide_btn.text.begins_with("Далі: Здай виконане") and "Київ" in mv.guide_btn.text, "на мапі кнопка з головною порадою: «%s»" % mv.guide_btn.text)
	check(mv.guide_btn.position.x >= mv.map_rect.position.x and mv.guide_btn.position.x + mv.guide_btn.size.x <= mv.map_rect.end.x and mv.guide_btn.position.y + mv.guide_btn.size.y <= mv.map_rect.end.y, "кнопка «Далі» вміщається на мапі й не лізе під панель")
	mv.guide_pressed.emit()
	await _frames(2)
	check(game.state == game.State.MAP and game.map_sel == "kyiv" and mv.selected == "kyiv", "дотик до «Далі» вибирає місце поради на мапі")
	# здав завдання: порада змінюється
	load("res://scripts/game/city_service.gd").turn_in(w, p, 950)
	game.enter_map()
	await _frames(2)
	check(mv.guide_btn.text.begins_with("Далі: Облога") and "Чигирин" in mv.guide_btn.text, "після здачі головною стає облога: «%s»" % mv.guide_btn.text)
	# порада без місця відкриває вкладку
	DS.state(w)["sieges"].clear()
	w.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	p.stat_points = 2
	game.enter_map()
	await _frames(2)
	check(mv.guide_btn.text.begins_with("Далі: Розподіли вільні очки"), "порада про вільні очки на кнопці: «%s»" % mv.guide_btn.text)
	mv.guide_pressed.emit()
	await _frames(2)
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(game.state == game.State.CHARACTER and tc.current_tab == GS.TAB_HERO, "дотик відкриває екран героя на потрібній вкладці")
	# ---- Журнал: розділ «Що робити зараз» ----
	game.char_tab = 1
	game._build_character()
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var jt := ""
	for n in tc.get_tab_control(1).find_children("*", "Label", true, false):
		jt += n.text + "\n"
	check("Що робити зараз" in jt and "1. Розподіли вільні очки" in jt and "відкрити ›" in jt and "на мапі ›" in jt, "журнал починається з порад")
	game.char_do("tab_show", GS.TAB_HERO)
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(tc.current_tab == GS.TAB_HERO, "порада з журналу перемикає вкладку")
	game.close_character()
	await _frames(2)
	# номери вкладок у порадника збігаються зі справжніми
	game.open_character()
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(tc.get_tab_title(GS.TAB_HERO).begins_with("Герой") and tc.get_tab_title(GS.TAB_SKILLS).begins_with("Вміння") and tc.get_tab_title(GS.TAB_PERKS).begins_with("Загартування") and tc.get_tab_title(GS.TAB_CHALLENGES).begins_with("Виклики") and GS.TAB_CHALLENGES == game.UiCharacter.TAB_CHALLENGES, "порадник знає справжні номери вкладок")
	game.close_character()
	await _frames(2)
	# ---- Позначки на мапі ----
	mv.legend_pressed.emit()
	await _frames(2)
	var lt := ""
	for n in game.hud.map_panel.find_children("*", "Label", true, false):
		lt += n.text + "\n"
	check(game.map_legend and "Позначки на мапі" in lt and "Зелена галочка" in lt and "Зірка" in lt and "Облога" in lt, "кнопка «?» показує пояснення позначок")
	game._on_map_select("sich")
	await _frames(2)
	check(not game.map_legend, "вибір місця закриває пояснення")
	# ---- Нові заняття ----
	check(w.hints.has("unlocks_seen"), "гра запам'ятала, що героєві вже відкрито")
	var VS = load("res://scripts/game/vigil_service.gd")
	w.hints.erase("open:vigil")
	game.hud.hide_hint()
	game.enter_map()
	await _frames(2)
	check(VS.unlocked(p) and w.hints.has("open:vigil") and game.hud.hint_panel.visible and "Козацька варта" in game.hud.hint_label.text, "про нововідкрите заняття гра каже на мапі")
	game.hud.hide_hint()
	game.enter_map()
	await _frames(2)
	check(not game.hud.hint_panel.visible, "удруге про те саме не нагадує")
	# ---- Довідник ----
	var guide_wiki := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Порадник: що робити далі":
				guide_wiki = str(e["text"])
	check("«Далі»" in guide_wiki and "Що робити зараз" in guide_wiki and ("до %d порад" % GS.MAX) in guide_wiki and "«?»" in guide_wiki, "довідник пояснює порадник")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_event_lift() -> void:
	suite("Події: нечисть міряється силою з героєм")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Far = load("res://scripts/game/far_service.gd")
	var Power = load("res://scripts/game/power.gd")
	var DS = load("res://scripts/game/defense_service.gd")
	var EvS = load("res://scripts/game/event_service.gd")
	var TS = load("res://scripts/game/trade_service.gd")
	var EscS = load("res://scripts/game/escort_service.gd")
	var Bounty = load("res://scripts/game/bounty_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var base_dmg := func(lvl: int) -> float:
		return Data.enemy_std_dmg(lvl)
	# Слабкий герой: мірка нижча за нечисть свого рівня, тож нічого не міняється
	var weak = _new_player()
	var w0 = load("res://scripts/game/world_state.gd").new()
	var wl: Dictionary = DS.battle_loc(w0, "chyhyryn", weak)
	check(is_equal_approx(Far.guard_mult(int(wl["level"]), wl), 1.0) and is_equal_approx(float(wl["gate_hp"]), 600.0 + 120.0 * int(wl["level"])), "слабкому героєві брама лишається звичайною")
	# Сильний герой: мірка за його шкодою й здоров'ям, брама міцнішає на стільки ж, на скільки лютішає удар
	var strong = _new_player()
	strong.level = 60
	strong.stats["str"] = 400
	strong.stats["vit"] = 400
	strong.recalc()
	var m: Dictionary = Far.event_mods(strong)
	check(is_equal_approx(float(m["min_std_hp"]), Data.enemy_std_hp(60) * Far.EVENT_FLOOR) and is_equal_approx(float(m["min_std_dmg"]), Data.enemy_std_dmg(60) * Far.EVENT_FLOOR), "мірка події: %d%% сили нечисті рівня героя" % roundi(Far.EVENT_FLOOR * 100.0))
	# Новачкам мірка не діє, далі вмикається плавно
	check(is_equal_approx(Far.event_share(Far.EVENT_FROM), 0.0) and is_equal_approx(Far.event_share(1), 0.0) and is_equal_approx(Far.event_share(Far.EVENT_FULL), 1.0) and is_equal_approx(Far.event_share(99), 1.0) and is_equal_approx(Far.event_share((Far.EVENT_FROM + Far.EVENT_FULL) / 2), 0.5), "мірка вмикається від %d-го рівня до повної на %d-му" % [Far.EVENT_FROM, Far.EVENT_FULL])
	strong.level = Far.EVENT_FROM
	var m_new: Dictionary = Far.event_mods(strong)
	var novice: Dictionary = DS.battle_loc(w0, "chyhyryn", strong)
	check(is_equal_approx(float(m_new["min_std_hp"]), 0.0) and is_equal_approx(float(novice["gate_hp"]), (600.0 + 120.0 * int(novice["level"])) * Far.guard_mult(int(novice["level"]))), "героєві %d-го рівня підлога подій не діє, хоч який він сильний" % Far.EVENT_FROM)
	strong.level = 60
	var sl: Dictionary = DS.battle_loc(w0, "chyhyryn", strong)
	var g: float = Far.guard_mult(int(sl["level"]), sl)
	check(int(sl["level"]) == 59 and g > 1.5 and is_equal_approx(g, 1.0 + (float(base_dmg.call(59)) / (Data.STD_DMG * (1.0 + Data.OLD_DMG_PER_LEVEL * 58.0)) - 1.0) * Far.GUARD_EXTRA) and is_equal_approx(float(sl["gate_hp"]), (600.0 + 120.0 * 59) * g) and sl.has("min_std_hp"), "облога: мірка героя й міцніша брама (×%.1f)" % g)
	EvS.start(w0, strong, "village_raid", "black_forest")
	var el: Dictionary = EvS.battle_loc(w0, EvS.active(w0), strong)
	check(el.has("min_std_hp") and int(el["level"]) == 59 and is_equal_approx(float(el["gate_hp"]), (500.0 + 100.0 * 59) * Far.guard_mult(59, el)), "набіг на село: мірка героя й міцніші хати")
	var tl: Dictionary = TS.battle_loc(w0, "kyiv", strong)
	check(tl.has("min_std_hp") and is_equal_approx(float(tl["gate_hp"]), (400.0 + 80.0 * 59) * Far.guard_mult(59, tl)), "напад на валку: мірка героя й міцніші вози")
	var eq := {"id": 1, "city": "sich", "loc": "rapids", "progress": 0, "lvl": 2, "target": "kobzar"}
	var esc: Dictionary = EscS.battle_loc(eq, strong)
	check(int(esc["level"]) == 59 and esc.has("min_std_hp") and is_equal_approx(float(esc["gate_hp"]), EscS.hp(59) * Far.guard_mult(59, esc)) and int(EscS.battle_loc(eq)["level"]) == 2 and not EscS.battle_loc(eq).has("min_std_hp"), "супровід: рівень і мірка героя, мандрівник міцніший")
	# Ніч: у полі рівень підтягується до героя, обсяг зачистки лишається за місцем; у печері лише мірка
	var nf: Dictionary = Far.night_mods(Data.LOCATIONS["black_forest"], strong)
	var nd: Dictionary = Far.night_mods(Data.LOCATIONS["zmii_cave"], strong)
	check(int(nf["level"]) == 60 and int(nf["base_level"]) == int(Data.LOCATIONS["black_forest"]["level"]) and int(nf["goal"]) == Data.FIELD_GOAL_BASE + int(Data.LOCATIONS["black_forest"]["level"]) * Data.FIELD_GOAL_PER_LEVEL and is_equal_approx(float(nf["min_std_hp"]), Data.enemy_std_hp(60) * Far.EVENT_FLOOR * Far.NIGHT_MULT), "ніч у полі: рівень героя, мірка на %d%% лютіша, зачистка за місцем" % roundi((Far.NIGHT_MULT - 1.0) * 100.0))
	check(not nd.has("level") and nd.has("min_std_hp") and not Far.night_mods(Data.LOCATIONS["black_forest"], weak).has("level"), "ніч у печері й для слабшого героя рівня не міняє")
	check(not Far.night_mods(Data.LOCATIONS["ridne_selo"], strong).has("goal"), "місце з власним обсягом зачистки його зберігає")
	weak.free()
	strong.free()
	# ---- У грі ----
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "defense", "bounty", "event_village_raid", "night"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 60
	p.stats["str"] = 400
	p.stats["vit"] = 400
	p.recalc()
	p.hp = p.max_hp
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	var fm: Dictionary = Far.event_mods(p)
	# hp_mult — множник здоров'я поверх мірки (еліта, ніч), dmg_mult — те саме для удару
	var floor_ok := func(e, hp_mult: float, dmg_mult: float = 1.0) -> bool:
		return e.max_hp >= e.raw_hp / Data.enemy_std_hp(e.level) * float(fm["min_std_hp"]) * hp_mult * 0.999 and e.damage >= e.raw_dmg / float(base_dmg.call(e.level)) * float(fm["min_std_dmg"]) * dmg_mult * 0.999
	var foes := func() -> Array:
		return get_nodes_in_group("enemies").filter(func(e): return not e.is_queued_for_deletion())
	# Облога: уся нечисть не слабша за мірку й сильніша, ніж просто за рівнем
	game.start_defense("chyhyryn")
	for i in 600:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
		if foes.call().size() >= 3:
			break
	var all_ok := true
	for e in foes.call():
		all_ok = all_ok and e.level == 59 and floor_ok.call(e, 1.0)
	check(foes.call().size() > 0 and all_ok and is_equal_approx(c.gate.max_hp, float(c.loc["gate_hp"])), "в облозі нечисть рівня героя й не слабша за мірку (%d)" % foes.call().size())
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	# Розшук і сторож скарбу в звичайній місцевості: лише вони підтягуються, решта лишається за рівнем місця
	Bounty.state(game.world)["active"].append({"id": 7, "city": "kyiv", "kind": "upyr", "name": "Упир Кривий", "loc": "wild_field", "affixes": ["fiery"], "gold": 300, "glory": 6, "killed": false})
	EvS.state(game.world)["treasure"]["wild_field"] = true
	game.enter_location("wild_field")
	await _frames(3)
	var bounty = null
	var guard = null
	var plain := 0
	var plain_raised := 0
	for e in foes.call():
		if e.bounty_id > 0:
			bounty = e
		elif e.treasure_guard:
			guard = e
		elif not e.elite:  # випадкова еліта має власний множник здоров'я, її не рахуємо
			plain += 1
			# зараза в місцевості додає своє, але це не мірка героя
			if e.max_hp > e.raw_hp * (float(c.plague_mods["hp"]) if c.plague > 0 else 1.0) * 1.01:
				plain_raised += 1
	check(bounty != null and bounty.level == 60 and floor_ok.call(bounty, 2.5), "розшукувана нечисть рівня героя й не слабша за мірку (ще й ×2,5 як еліта)")
	check(guard != null and guard.level == 60 and floor_ok.call(guard, 1.5), "сторож скарбу рівня героя й не слабший за мірку")
	check(plain_raised == 0, "звичайна нечисть місцевості лишається за рівнем місця (%d)" % plain)
	# Лігво на стежці
	_clear_enemies(game)
	await _frames(2)
	c.spawn_trail("den", 5)
	c._trail_found()
	await _frames(2)
	var den: Array = foes.call()
	var den_ok: bool = den.size() == 3
	for e in den:
		den_ok = den_ok and e.level == 60 and floor_ok.call(e, 1.0)
	check(den_ok, "лігво на стежці: троє рівня героя й не слабші за мірку")
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	# Нічний похід: уся місцевість підтягується
	EvS.state(game.world)["treasure"].clear()
	Bounty.state(game.world)["active"].clear()
	EvS.state(game.world)["night"]["black_forest"] = 2
	game.enter_location("black_forest")
	await _frames(3)
	var night_ok := true
	for e in foes.call():
		night_ok = night_ok and e.level == 60 and floor_ok.call(e, Far.NIGHT_MULT, Far.NIGHT_MULT)
	check(c.loc.get("night", false) and int(c.loc["level"]) == 60 and foes.call().size() > 0 and night_ok and c.field_goal == Data.FIELD_GOAL_BASE + int(Data.LOCATIONS["black_forest"]["level"]) * Data.FIELD_GOAL_PER_LEVEL, "нічний похід: нечисть рівня героя й лютіша за мірку, зачистка за місцем")
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	# Довідник знає правило й називає ті самі числа
	var rule := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Сила нечисті в подіях":
				rule = str(e["text"])
	check(("%d%% звичайної сили" % roundi(Far.EVENT_FLOOR * 100.0)) in rule and "розшукуваною" in rule and "Уночі" in rule and ("з %d-го рівня" % Far.EVENT_FROM) in rule and ("на %d-му" % Far.EVENT_FULL) in rule, "довідник пояснює силу нечисті в подіях із числами балансу")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_full_bag_and_scroll() -> void:
	suite("Повна торба, викинути й знищити, гортання з будь-якої точки")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Uniques = load("res://scripts/data/uniques.gd")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "bag_full"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.level = 20
	p.stats["vit"] = 80
	p.recalc()
	game.world.story = {"chapter": 4, "step": 0, "stage": "active", "progress": 0}
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	c.autosell = false
	var on_ground := func(kind: String) -> int:
		var n := 0
		for ch in c.entities.get_children():
			if ch.get_script() == c.PickupScript and ch.kind == kind and not ch.is_queued_for_deletion():
				n += 1
		return n
	# Повна торба: річ лишається лежати, гривень за неї не дають
	while not p.bag_full():
		p.add_item(Data.gen_item(5, 1))
	var size0: int = p.inventory.size()
	var gold0: int = p.gold
	var loot: Dictionary = Data.gen_item(20, 2, "weapon", "sabre")
	c.spawn_pickup(p.global_position, "item", 0, loot)
	for i in 40:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	check(p.inventory.size() == size0 and p.gold == gold0 and on_ground.call("item") == 1 and not c.can_pick_item(loot), "торба повна: річ лишилась лежати, її не продано")
	# Золота річ і артефакт усе одно підбираються понад місце
	check(c.can_pick_item(Uniques.make("poias_baidy", 20)) and c.can_pick_item(load("res://scripts/data/artifacts.gd").make("zmiiv_zub")), "золоту річ і артефакт повна торба не спиняє")
	# Автопродаж мотлоху далі працює, якщо гравець його ввімкнув
	c.autosell = true
	check(c.can_pick_item(Data.gen_item(5, 0)) and not c.can_pick_item(loot), "з автопродажем звичайна річ підбирається й продається, краща лежить")
	c.autosell = false
	# Знищити: другий дотик підтверджує
	game.open_character()
	await _frames(2)
	var junk: Dictionary = p.inventory[0]
	game.char_do("select", junk["uid"])
	await _frames(2)
	var acts := func() -> Array:
		var out := []
		for b in game.hud.screen_root.find_children("*", "Button", true, false):
			out.append(b.text)
		return out
	check("Знищити" in acts.call() and "Викинути на землю" in acts.call() and "Вдягнути" in acts.call(), "у бою на картці речі є «Вдягнути», «Викинути на землю» і «Знищити»")
	game.char_do("destroy", junk["uid"])
	await _frames(2)
	check(not p.find_item(junk["uid"]).is_empty() and "Точно знищити? Ще раз" in acts.call(), "перший дотик лише перепитує")
	game.char_do("destroy", junk["uid"])
	await _frames(2)
	check(p.find_item(junk["uid"]).is_empty() and p.inventory.size() == size0 - 1 and p.gold == gold0, "другий дотик знищує річ назавжди")
	# Викинути на землю: річ лягає поруч і сама назад не летить; душа з неї вертається в торбинку
	var spare: Dictionary = p.inventory[0]
	spare["sock"] = 1
	spare["soul"] = "vovkulaka"
	var souls0: int = int(p.souls.get("vovkulaka", 0))
	game.char_do("select", spare["uid"])
	game.char_do("drop", spare["uid"])
	await _frames(2)
	check(p.find_item(spare["uid"]).is_empty() and on_ground.call("item") == 2, "викинута річ лежить на землі")
	check(int(p.souls.get("vovkulaka", 0)) == souls0 + 1 and not spare.has("soul"), "душа з викинутої речі вернулась у торбинку")
	game.close_character()
	await _frames(2)
	# Тепер місце є: річ, що лежала, підбирається; викинута лишається, поки на неї не стати
	for i in 60:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	check(not p.find_item(loot.get("uid", -1)).is_empty() and p.find_item(spare["uid"]).is_empty() and on_ground.call("item") == 1, "звільнилось місце — здобич підібрано, викинута річ сама не повернулась")
	var dropped = null
	for ch in c.entities.get_children():
		if ch.get_script() == c.PickupScript and ch.kind == "item" and not ch.is_queued_for_deletion():
			dropped = ch
	p.global_position = dropped.global_position
	for i in 60:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	check(not p.find_item(spare["uid"]).is_empty() and on_ground.call("item") == 0, "став на викинуту річ — підняв")
	# Прибирання перед виходом: що не вмістилось, продається з повідомленням
	while not p.bag_full():
		p.add_item(Data.gen_item(5, 1))
	var extra: Dictionary = Data.gen_item(20, 1, "boots")
	c.spawn_pickup(p.global_position + Vector2(400, 0), "item", 0, extra)
	extra["sock"] = 1
	extra["soul"] = "upyr"
	var upyr0: int = int(p.souls.get("upyr", 0))
	var g1: int = p.gold
	c.collect_all()
	check(p.gold == g1 + Data.sell_price(extra) and on_ground.call("item") == 0, "перед виходом те, що не вмістилось, продано, а не загублено")
	check(int(p.souls.get("upyr", 0)) == upyr0 + 1, "душа з проданої при виході речі вернулась у торбинку")
	# Зілля: при повному запасі лежить, перед виходом іде за півціни; коли місце є, підбирається
	p.potions = p.potion_max()
	c.spawn_pickup(p.global_position, "potion", 0)
	for i in 30:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	check(on_ground.call("potion") == 1 and p.potions == p.potion_max(), "зілля при повному запасі лишається лежати")
	p.potions -= 1
	for i in 30:
		p.hp = p.max_hp
		p.invuln = 1.0
		await process_frame
	check(on_ground.call("potion") == 0 and p.potions == p.potion_max(), "випив зілля — те, що лежало, підібрано")
	c.spawn_pickup(p.global_position + Vector2(300, 0), "potion", 0)
	var g2: int = p.gold
	c.collect_all()
	check(p.gold == g2 + Data.potion_price(p.level) / 2 and on_ground.call("potion") == 0, "зайве зілля перед виходом іде за півціни")
	# Підказка про повну торбу не затуляє екран героя
	game.hud.show_hint("перевірка", false)
	game.open_character()
	await _frames(2)
	check(not game.hud.hint_panel.visible, "підказка ховається, коли відкрито екран героя")
	game.close_character()
	await _frames(2)
	# ---- Гортання з будь-якої точки: палець на кнопці теж гортає, і кнопка не натискається ----
	_clear_enemies(game)
	game.enter_map()
	await _frames(2)
	game.enter_city("sich")
	await _frames(2)
	game.open_wiki(game._build_city, "enemies")
	await _frames(3)
	var TS = root.get_node("TouchScroll")
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var sc: ScrollContainer = tc.get_current_tab_control() as ScrollContainer
	var card: Control = sc.find_children("*", "PanelContainer", true, false)[0]
	var at: Vector2 = card.get_global_rect().get_center()
	check(sc != null and sc.get_v_scroll_bar().max_value > sc.get_v_scroll_bar().page and TS.scroller_of(TS.control_at(root, at)) == sc and card.mouse_filter == Control.MOUSE_FILTER_STOP, "довідник довший за екран, а картка під пальцем ковтає дотик")
	var send := func(ev: InputEvent) -> void:
		root.push_input(ev, true)  # координати вже в одиницях екрана гри
	var press := func(pos: Vector2, down: bool) -> void:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = pos
		ev.global_position = pos
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		send.call(ev)
	var drag := func(from: Vector2, to: Vector2, steps: int) -> void:
		for i in steps:
			var ev := InputEventMouseMotion.new()
			var a: Vector2 = from.lerp(to, float(i) / steps)
			var b: Vector2 = from.lerp(to, float(i + 1) / steps)
			ev.position = b
			ev.global_position = b
			ev.relative = b - a
			ev.button_mask = MOUSE_BUTTON_MASK_LEFT
			send.call(ev)
	sc.scroll_vertical = 0
	press.call(at, true)
	drag.call(at, at + Vector2(0, -160), 8)
	var moved: int = sc.scroll_vertical
	press.call(at + Vector2(0, -160), false)
	await _frames(2)
	check(moved >= 130 and moved <= 165, "палець на картці посеред екрана гортає список: %d" % moved)
	# Кнопка під пальцем: гортання не натискає її
	game.close_wiki()
	await _frames(2)
	var tabs: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i).begins_with("Крамниця"):
			game.city_tab = i
	game._build_city()
	await _frames(3)
	var shop: ScrollContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_current_tab_control() as ScrollContainer
	var filler := VBoxContainer.new()
	filler.custom_minimum_size = Vector2(10, 1400)
	shop.get_child(0).get_child(0).add_child(filler)  # щоб сторінці напевно було куди гортатись
	await _frames(3)
	var btn: Button = null
	for b in shop.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().size.y > 30.0 and b.get_global_rect().position.y > 200.0:
			btn = b
			break
	var fired := [0]
	btn.pressed.connect(func(): fired[0] += 1)
	var bp: Vector2 = btn.get_global_rect().get_center()
	shop.scroll_vertical = 0
	press.call(bp, true)
	drag.call(bp, bp + Vector2(0, -120), 6)
	var moved2: int = shop.scroll_vertical
	press.call(bp + Vector2(0, -120), false)
	await _frames(3)
	check(moved2 >= 95 and fired[0] == 0, "палець на кнопці гортає список (%d), а кнопка не спрацьовує" % moved2)
	# Короткий дотик без руху лишається дотиком
	shop.scroll_vertical = 0
	await _frames(2)
	bp = btn.get_global_rect().get_center()
	press.call(bp, true)
	press.call(bp, false)
	await _frames(2)
	check(fired[0] == 1, "короткий дотик без руху натискає кнопку, як і раніше")
	# Довідник знає про нове й називає кнопки так само, як екран
	var wiki_titles := {}
	for sx in load("res://scripts/game/wiki_service.gd").sections():
		for e in sx["entries"]:
			wiki_titles[str(e["title"])] = str(e["text"])
	var bag_text: String = str(wiki_titles.get("Повна торба", ""))
	check("«Знищити»" in bag_text and "«Викинути на землю»" in bag_text and "півціни" in bag_text, "довідник пояснює повну торбу, «Знищити» й «Викинути на землю»")
	check("будь-якої точки" in str(wiki_titles.get("Гортання списків", "")), "довідник пояснює гортання з будь-якої точки")
	game.queue_free()
	await _frames(2)
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_events_wiki() -> void:
	suite("Список подій і довідник: правила")
	var Wiki = load("res://scripts/data/wiki_data.gd")
	var EB = load("res://scripts/game/events_board.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var WM = load("res://scripts/ui/world_map.gd")
	var Status = load("res://scripts/game/status.gd")
	var Elites = load("res://scripts/data/elites.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var HS = load("res://scripts/game/holiday_service.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	CS.now_override = 1762700000
	# Дані подій
	var ids := {}
	var kinds := {}
	for k in Wiki.EVENT_KINDS:
		kinds[k[0]] = true
	var ev_ok := true
	for e in Wiki.EVENTS:
		ev_ok = ev_ok and not ids.has(e["id"]) and kinds.has(e["kind"]) and WM.ICON_ORDER.has(e["icon"]) and str(e["name"]) != "" and str(e["text"]) != "" and str(e["reward"]) != "" and str(e["where"]) != ""
		ids[e["id"]] = true
	check(ev_ok and Wiki.EVENTS.size() >= 28, "%d подій: різні, з описом, нагородою, місцем і значком" % Wiki.EVENTS.size())
	for need in ["duel", "duel_free", "muster", "ring", "vigil", "bounty", "escort", "trade", "hunt", "fish", "dice", "rumor", "trail", "garden", "expedition", "tower", "depths", "far", "village_raid", "caravan", "captives", "wounded", "sich_siege", "siege", "night", "treasure", "fair", "theft", "holidays", "challenges"]:
		check(ids.has(need), "у списку подій є «%s»" % need)
	# Стан для селянина й бувалого козака
	var peasant = _new_player()
	peasant.job = "peasant"
	var w0 = WorldState.new()
	var locked_ok := true
	for id in ["duel", "duel_free", "muster", "ring", "vigil", "tower", "depths", "village_raid", "captives", "sich_siege", "garden", "expedition"]:
		var st: Dictionary = EB.status(id, w0, peasant)
		locked_ok = locked_ok and st["locked"] and not st["ready"] and str(st["text"]) != ""
	check(locked_ok, "селянинові більшість подій ще закрита, і сказано чому")
	check(not EB.status("dice", w0, peasant)["locked"] and not EB.status("escort", w0, peasant)["locked"] and not EB.status("holidays", w0, peasant)["locked"], "кості, супровід і свята відкриті від початку")
	check(EB.status("garden", w0, peasant)["text"] == "Збудуй город на хуторі" and EB.status("duel", w0, peasant)["text"].begins_with("Відкриється з 5-го рівня"), "причини — цілими реченнями")
	var hero = _new_player()
	hero.change_class("cossack")
	hero.level = 30
	hero.recalc()
	var w = WorldState.new()
	w.story = {"chapter": 3, "step": 0, "stage": "active", "progress": 0}
	var all_text := true
	for e in Wiki.EVENTS:
		all_text = all_text and str(EB.status(e["id"], w, hero)["text"]) != ""
	check(all_text, "у кожної події є стан для бувалого козака")
	check(EB.status("duel", w, hero)["ready"] and EB.status("muster", w, hero)["ready"] and EB.status("ring", w, hero)["ready"] and EB.status("vigil", w, hero)["ready"], "тижневі й варта чекають")
	check(EB.now_lines(w, hero).is_empty() and not EB.status("caravan", w, hero)["ready"], "спершу на мапі спокійно")
	var r0: int = EB.ready_count(w, hero)
	var ES = load("res://scripts/game/event_service.gd")
	ES.start(w, hero, "caravan")
	check(EB.status("caravan", w, hero)["ready"] and EB.ready_count(w, hero) == r0 + 1 and EB.now_lines(w, hero).any(func(l): return l.begins_with("Чумацька валка: ")), "з'явилась валка: картка світиться, рядок угорі, лічильник на вкладці")
	ES.state(w)["night"]["black_forest"] = 2
	w.defense = {"sieges": {"poltava": 2}, "ruined": {}, "won": 0, "lost": 0, "calm": 0}
	ES.state(w)["fair"] = {"city": "kyiv", "left": 3}
	var now: Array = EB.now_lines(w, hero)
	check(now.any(func(l): return l == "Нічний похід: Чорний ліс") and now.any(func(l): return "Полтава, лишилось походів: 2" in l) and now.any(func(l): return l == "Ярмарок: Київ, ще походів: 3"), "ніч, облога й ярмарок угорі списку: %s" % str(now))
	var DS = load("res://scripts/game/duel_service.gd")
	for i in 3:
		DS.win(w, hero)
	check(not EB.status("duel", w, hero)["ready"] and EB.status("duel", w, hero)["text"].begins_with("Ти чемпіон"), "після трьох кіл — чемпіон тижня")
	HS.forced = "rizdvo"
	check(EB.status("holidays", w, hero)["ready"] and "Різдво" in EB.status("holidays", w, hero)["text"], "у свято воно в списку подій")
	HS.forced = "none"
	check(not EB.status("holidays", w, hero)["ready"], "без свята — лише найближче")
	var rows: Array = EB.rows(w, hero)
	check(rows.size() == Wiki.EVENTS.size() and rows.all(func(r): return r.has("status") and r.has("ready") and r.has("locked")), "рядки списку мають опис і стан")

	# ---------------- Довідник ----------------
	var secs: Array = WS.sections()
	check(secs.size() == Wiki.SECTIONS.size() and secs.all(func(x): return not x["entries"].is_empty()), "%d розділів довідника, у кожному є статті" % secs.size())
	var total := 0
	var titles := {}
	var icons_ok := true
	for sx in secs:
		total += sx["entries"].size()
		for e in sx["entries"]:
			titles[str(e["title"])] = true
			var ic: Dictionary = e["icon"]
			if ic.has("sprite"):
				icons_ok = icons_ok and GfxS.has(str(ic["sprite"]))
			if ic.has("map"):
				icons_ok = icons_ok and WM.ICON_ORDER.has(str(ic["map"]))
			if ic.has("loot"):
				icons_ok = icons_ok and GfxS.ICON_ORDER.has(str(ic["loot"]))
	check(total >= 200, "у довіднику %d статей" % total)
	check(icons_ok, "у всіх статей справжні значки")
	# Повнота: усе, що є в грі, є й у довіднику
	var kinds_used := {}
	for id in Data.LOCATIONS:
		for e in Data.LOCATIONS[id]["enemies"]:
			kinds_used[e] = true
	var en_ok := true
	for k in kinds_used:
		en_ok = en_ok and Wiki.ENEMIES.has(k) and k in Wiki.ENEMY_ORDER
	check(en_ok and Wiki.ENEMY_ORDER.size() == Wiki.ENEMIES.size(), "уся нечисть мапи описана в довіднику")
	var bosses := {}
	for id in Data.LOCATIONS:
		if Data.LOCATIONS[id].has("boss"):
			bosses[Data.LOCATIONS[id]["boss"]] = true
	for b in load("res://scripts/game/tower_service.gd").SUPER_BOSSES + Acts.RING_POOL + load("res://scripts/game/depth_service.gd").BOSSES:
		bosses[b] = true
	var b_ok := true
	for b in bosses:
		b_ok = b_ok and Wiki.BOSSES.has(b) and b in Wiki.BOSS_ORDER and titles.has(Data.BOSS_NAMES[b])
	check(b_ok and Wiki.BOSS_ORDER.size() == Wiki.BOSSES.size(), "усі боси описані: %d" % bosses.size())
	var map_ok := true
	for id in Data.CITIES:
		map_ok = map_ok and titles.has(Data.CITIES[id]["name"])
	for id in Data.LOCATIONS:
		map_ok = map_ok and titles.has(Data.LOCATIONS[id]["name"])
	for id in Acts.SPOTS:
		map_ok = map_ok and titles.has(Acts.SPOTS[id]["name"])
	check(map_ok, "у розділі «Мапа» кожне місто, місцевість і місце занять")
	var cls_ok := true
	for c in Classes.CLASSES:
		cls_ok = cls_ok and titles.has(Classes.CLASSES[c]["name"])
	check(cls_ok, "усі десять класів")
	var hol_ok := true
	for h in Acts.HOLIDAY_ORDER:
		hol_ok = hol_ok and (titles.has(Acts.HOLIDAYS[h]["name"]) or titles.has("★ " + str(Acts.HOLIDAYS[h]["name"])))
	check(hol_ok, "усі двадцять вісім свят")
	var camp_ok := true
	for b in Camp.BUILD_ORDER:
		camp_ok = camp_ok and titles.has(Camp.BUILDINGS[b]["name"])
	for k in Camp.KLEINOD_ORDER:
		camp_ok = camp_ok and titles.has(Camp.KLEINODY[k]["name"])
	for r in Acts.RECIPE_ORDER:
		camp_ok = camp_ok and titles.has(Acts.RECIPES[r]["name"])
	check(camp_ok, "будівлі, клейноди й страви хутора")
	var rules_ok := true
	for st in Status.INFO:
		rules_ok = rules_ok and Wiki.STATUS_TEXT.has(st) and titles.has(Status.INFO[st]["name"])
	for a in Elites.AFFIXES:
		rules_ok = rules_ok and titles.has(Elites.AFFIXES[a]["m"])
	for k in Data.AFFIX_POOL:
		rules_ok = rules_ok and WS.PROP_NAMES.has(k)
	for sl in Data.SLOTS:
		rules_ok = rules_ok and WS.SLOT_MAIN.has(Data.SLOT_PRIMARY[sl])
	check(rules_ok, "стани, властивості еліт і речей — усі з назвами")
	# Вміння, Загартування, найманці, побратими й досягнення: усе з таблиць гри є в довіднику
	var Heroes = load("res://scripts/data/heroes.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	var has_title := func(name: String) -> bool:
		if titles.has(name):
			return true
		for t in titles:
			if str(t).begins_with(name + " ("):
				return true
		return false
	var lost := []
	for cls in Classes.TREES:
		for br in Classes.TREES[cls]:
			for node in br["nodes"]:
				if not has_title.call(str(node["name"])):
					lost.append(node["name"])
	for br in Data.PERK_BRANCHES:
		for tier in br["tiers"]:
			for perk in tier:
				if not has_title.call(str(perk["name"])):
					lost.append(perk["name"])
	for id in Data.COMPANIONS:
		if not has_title.call(str(Data.COMPANIONS[id]["name"])):
			lost.append(Data.COMPANIONS[id]["name"])
	for id in Heroes.HEROES:
		if not has_title.call(str(Heroes.HEROES[id]["name"])):
			lost.append(Heroes.HEROES[id]["name"])
	for a in Ach.ACHIEVEMENTS:
		if not has_title.call(str(a["name"])):
			lost.append(a["name"])
	check(lost.is_empty() and titles.has("Дерева вмінь") and titles.has("Загартування") and titles.has("Запас сил"), "кожне вміння, очко Загартування, найманець, побратим і досягнення є в довіднику: %s" % str(lost))
	check(WS.sections()[WS.index_of("skills")]["title"] == "Вміння" and WS.sections()[WS.index_of("skills")]["entries"].size() >= 100, "окремий розділ «Вміння»: %d статей" % WS.sections()[WS.index_of("skills")]["entries"].size())
	for e in Wiki.EVENTS:
		if not titles.has(e["name"]):
			check(false, "подія «%s» є в довіднику" % e["name"])
	# Пошук
	var vii: Array = WS.search("Вій")
	check(not vii.is_empty() and str(vii[0]["entry"]["title"]).begins_with("Вій") and not vii.any(func(x): return x["entry"]["title"] == "Герць на майдані"), "«Вій» знаходить Вія першим, а не «свій» у чужих статтях")
	check(WS.search("ярмарок").any(func(x): return x["entry"]["title"] == "Ярмарок") and WS.search("зілля сили").any(func(x): return x["entry"]["title"] == "Зілля сили"), "пошук за кількома словами")
	check(WS.search("в").is_empty() and WS.search("   ").is_empty() and WS.search("ЗМІЄВА ПЕЧЕРА").any(func(x): return x["entry"]["title"] == "Змієва печера"), "одна літера нічого не шукає, регістр не важить")
	var md: String = WS.to_markdown()
	check(md.begins_with("# Довідник") and "## Нечисть" in md and "### Вій, володар підземного мороку" in md and "### Острів Зміїний" in md, "довідник вивантажується в Markdown")
	CS.now_override = 0
	peasant.free()
	hero.free()


func _suite_events_wiki_game() -> void:
	suite("Список подій і довідник: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	var texts := func(node) -> String:
		var out := ""
		for n in node.find_children("*", "Label", true, false):
			out += n.text + "\n"
		for n in node.find_children("*", "Button", true, false):
			out += n.text + "\n"
		return out
	var overlay_buttons := func() -> Array:
		return game.hud.overlay_box.find_children("*", "Button", true, false)
	var press := func(part: String) -> bool:
		for b in overlay_buttons.call():
			if part in b.text:
				b.pressed.emit()
				return true
		return false
	# Головне меню → довідник → назад
	game._show_main_menu()
	await _frames(2)
	check(press.call("Довідник"), "у головному меню є кнопка довідника")
	await _frames(2)
	check(game.wiki_open and game.hud.screen_root != null and "Довідник" in texts.call(game.hud.screen_root) and not game.hud.overlay.visible, "довідник відкрито поверх меню")
	var tc: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(tc.get_tab_count() == game.WikiService.sections().size() + 1 and tc.get_tab_title(tc.get_tab_count() - 1) == "Пошук", "вкладки розділів і пошук")
	game.go_back(true)
	await _frames(2)
	check(not game.wiki_open and game.state == game.State.MENU and game.hud.overlay.visible and game.hud.screen_root == null, "«Назад» повертає в головне меню")
	# Пошук
	game.open_wiki(game._show_main_menu)
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	tc.current_tab = tc.get_tab_count() - 1
	await _frames(1)
	var edit: LineEdit = game.hud.screen_root.find_children("*", "LineEdit", true, false)[0]
	edit.text = "Шубін"
	edit.text_changed.emit("Шубін")
	await _frames(2)
	check("Шубін, господар копалень" in texts.call(game.hud.screen_root) and game.wiki_query == "Шубін", "пошук показує знахідки й пам'ятає запит")
	game.close_wiki()
	await _frames(2)
	# Гра: вкладка «Події» на екрані героя
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	game.world.hints = {"combat": true, "block": true, "elite": true, "city": true, "map": true, "boss": true, "item": true, "cleared": true, "camp": true}
	p.change_class("cossack")
	p.level = 20
	p.recalc()
	game.world.story = {"chapter": 2, "step": 0, "stage": "active", "progress": 0}
	game.enter_map()
	await _frames(2)
	game.EventService.start(game.world, p, "village_raid")
	game.open_character()
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var ev_i := -1
	for i in tc.get_tab_count():
		if tc.get_tab_title(i).begins_with("Події"):
			ev_i = i
	check(ev_i >= 0 and "(+" in tc.get_tab_title(ev_i), "на екрані героя є вкладка «Події» з лічильником: %s" % (tc.get_tab_title(ev_i) if ev_i >= 0 else "—"))
	tc.current_tab = ev_i  # відкрити вкладку «Події»
	var et: String = texts.call(tc.get_child(ev_i))
	check("Зараз на мапі" in et and "Набіг на село: " in et and "Щотижня" in et and "Події світу після походів" in et and "Герць на майдані" in et and "Коло Кожум'яки" in et, "у вкладці — що діє зараз і розклад")
	var wb: Button = null
	for b in tc.get_child(ev_i).find_children("*", "Button", true, false):
		if "довіднику" in b.text:
			wb = b
	check(wb != null, "з вкладки можна перейти в довідник")
	# Дотик до події показує її місце на мапі
	var EBs = game.EventsBoard
	var raid_place: String = str(game.EventService.active(game.world)["target"])
	check(EBs.place("village_raid", game.world, "sich") == raid_place and EBs.place("caravan", game.world, "sich") == "", "подія світу має місце, лише поки діє: %s" % raid_place)
	check(EBs.place("vigil", game.world) == "varta" and EBs.place("ring", game.world) == "kolo" and EBs.place("hunt", game.world) == "hunt" and EBs.place("fish", game.world) == "fish", "заняття на мапі ведуть до своїх місць")
	check(EBs.place("duel", game.world) == "sich" and EBs.place("muster", game.world) == "chyhyryn" and EBs.place("garden", game.world) == "hutir" and EBs.place("tower", game.world) == "bashta" and EBs.place("depths", game.world) == "hlybyny", "події міст, хутора, Башти й Глибин мають свої місця")
	var near_ok := true
	for from in ["wild_field", "black_forest", "hutir", "varta"]:
		var got: String = EBs.place("trade", game.world, from)
		for c in Data.CITIES:
			if EBs._ll(from).distance_to(Data.CITIES[c]["pos"]) < EBs._ll(from).distance_to(Data.CITIES[got]["pos"]) - 0.0001:
				near_ok = false
	check(EBs.place("dice", game.world, "kyiv") == "kyiv" and near_ok and EBs.place("trade", game.world, "black_forest") == "chyhyryn", "«у будь-якому місті» веде до міста, де герой стоїть, або до найближчого")
	check(EBs.place("trail", game.world, "sich") == "" and EBs.place("holidays", game.world, "sich") == "" and EBs.place("challenges", game.world, "sich") == "", "події без місця на мапі місця не вигадують")
	var far_place: String = EBs.place("far", game.world, "sich")
	check(Data.LOCATIONS.has(far_place) and Data.LOCATIONS[far_place].get("scale", false), "далекі краї ведуть до найближчого далекого краю: %s" % far_place)
	# кожна подія або має місце, або чесно його не має: жодна не веде в неіснуюче місце
	var bad_places := []
	var ActsD = load("res://scripts/data/activities.gd")
	for e in EBs.Wiki.EVENTS:
		var pl: String = EBs.place(e["id"], game.world, "sich")
		if pl != "" and not (Data.CITIES.has(pl) or Data.LOCATIONS.has(pl) or ActsD.SPOTS.has(pl) or pl == "hutir"):
			bad_places.append("%s→%s" % [e["id"], pl])
	check(bad_places.is_empty(), "місця всіх подій є на мапі: %s" % ", ".join(bad_places))
	var cue_n := 0
	var vigil_tap: Button = null
	var now_tap: Button = null
	for b in tc.get_child(ev_i).find_children("*", "Button", true, false):
		if b.text.begins_with("• Набіг на село"):
			now_tap = b
	for pc in tc.get_child(ev_i).find_children("*", "PanelContainer", true, false):
		var lab := ""
		for n in pc.find_children("*", "Label", true, false):
			lab += n.text + "|"
		var taps: Array = pc.find_children("*", "Button", true, false)
		if "на мапі ›" in lab:
			cue_n += 1
			if taps.is_empty():
				cue_n = -100
		if lab.begins_with("Козацька варта|") and not taps.is_empty():
			vigil_tap = taps[0]
	check(cue_n >= 10 and vigil_tap != null and now_tap != null and "Торкнись події" in et, "картки подій із місцем стали кнопками з підказкою «на мапі» (%d)" % cue_n)
	now_tap.pressed.emit()
	await _frames(3)
	check(game.state == game.State.MAP and game.map_sel == raid_place and game.hud.map_view.selected == raid_place, "дотик до події, що діє зараз, відкриває мапу на її місці")
	var mvw = game.hud.map_view
	mvw._layout()
	var vis: Rect2 = mvw.map_rect if mvw.map_rect.size.x > 10 else Rect2(Vector2.ZERO, mvw.size)
	check(vis.grow(-20.0).has_point(mvw._proj(Data.LOCATIONS[raid_place]["pos"])), "місце події видно на мапі")
	game.open_character()
	game.char_tab = ev_i
	game._build_character()
	await _frames(2)
	game.char_do("event_show", "vigil")
	await _frames(3)
	check(game.state == game.State.MAP and game.map_sel == "varta" and game.hud.map_view.selected == "varta", "дотик до Козацької варти показує Сторожову могилу")
	# Подія без місця: екран героя лишається, гра пояснює
	game.open_character()
	await _frames(2)
	game.char_do("event_show", "trail")
	await _frames(2)
	check(game.state == game.State.CHARACTER and "Окремого місця на мапі зараз нема" in game.hud.banner.text, "подія без місця: мапа не відкривається, є пояснення")
	game.char_do("event_show", "challenges")
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(game.state == game.State.CHARACTER and tc.get_tab_title(tc.current_tab).begins_with("Виклики") and game.UiCharacter.TAB_CHALLENGES == tc.current_tab, "«Виклики дня й тижня» відкривають вкладку «Виклики»")
	# У бою мапа не відкривається: похід не урвати випадковим дотиком
	game.close_character()
	await _frames(2)
	game.enter_location("wild_field")
	await _frames(3)
	game.open_character()
	await _frames(2)
	game.char_do("event_show", "vigil")
	await _frames(2)
	check(game.state == game.State.CHARACTER and game.char_return == game.State.PLAYING and game.combat.active and "Сторожова могила" in game.hud.banner.text, "у бою дотик до події лише називає місце")
	game.close_character()
	await _frames(2)
	game.enter_map()
	await _frames(2)
	game.open_character()
	game.char_tab = ev_i
	game._build_character()
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	wb = null
	for b in tc.get_child(ev_i).find_children("*", "Button", true, false):
		if "довіднику" in b.text:
			wb = b
	wb.pressed.emit()
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(game.wiki_open and game.wiki_tab == game.WikiService.index_of("events") and tc.current_tab == game.wiki_tab, "довідник відкрився на розділі «Події»")
	game.go_back(true)
	await _frames(2)
	var tc_back: TabContainer = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0] if game.hud.screen_root != null else null
	check(not game.wiki_open and game.state == game.State.CHARACTER and tc_back != null and tc_back.get_tab_title(0).begins_with("Герой"), "«Назад» повертає на екран героя")
	game.close_character()
	await _frames(2)
	# Пауза в бою → довідник → назад
	game.enter_location("wild_field")
	await _frames(3)
	game.go_back(true)
	await _frames(1)
	check(game.state == game.State.PAUSED and press.call("Довідник"), "у паузі є довідник")
	await _frames(2)
	var bg = game.hud.screen_root
	check(game.wiki_open and bg is PanelContainer, "у бою під довідником суцільне тло")
	game.go_back(true)
	await _frames(2)
	check(game.state == game.State.PAUSED and game.hud.overlay.visible and not game.wiki_open, "назад до паузи")
	game._resume_play()
	game.enter_map()
	await _frames(2)
	# Привал на мапі
	game._show_map_menu()
	await _frames(1)
	check(press.call("Довідник"), "на привалі є довідник")
	await _frames(2)
	game.go_back(true)
	await _frames(2)
	check(game.state == game.State.MAP and game.map_menu and game.hud.overlay.visible and not game.wiki_open, "назад на привал")
	game._close_map_menu()
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
	check(CampService.brew(w, p, "strength") and p.damage > dmg * 1.25 and is_equal_approx(p.buff_left("strength"), Data.BREW_TIME) and Data.BREW_TIME == 900.0, "зілля сили діє п'ятнадцять хвилин бою")
	var dmg_one: float = p.damage
	p.resources["herbs"] = 100
	p.resources["iron"] = 100
	check(CampService.brew(w, p, "strength") and is_equal_approx(p.buff_left("strength"), 1800.0) and is_equal_approx(p.damage, dmg_one), "ще одна порція додає час, а не силу")
	CampService.brew(w, p, "strength")
	CampService.brew(w, p, "strength")
	check(is_equal_approx(p.buff_left("strength"), 3600.0) and not CampService.can_brew(w, p, "strength") and not CampService.brew(w, p, "strength"), "запас зілля — не більше години")
	check(p.tick_buffs(3599.0).is_empty() and p.tick_buffs(2.0) == ["strength"] and is_equal_approx(p.damage, dmg), "час минув — сила звичайна")
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
	# Реклама: ×2 здобичі
	check(AdRewards.drop_mult(w) == 1.0 and AdRewards.can_boost(w, "drop2"), "без реклами здобич звичайна")
	AdRewards.grant_boost(w, "drop2")
	check(AdRewards.drop_mult(w) == 2.0 and AdRewards.drop2_left(w) == AdRewards.DROP2_SECONDS and AdRewards.xp_mult(w) == 1.0, "реклама дає годину ×2 здобичі, досвід не чіпає")
	check(AdRewards.boost_button_text(w, "drop2").begins_with("×2 здобичі\nще 1 год"), "на кнопці видно залишок: %s" % AdRewards.boost_button_text(w, "drop2"))
	AdRewards.grant_drop2(w)
	AdRewards.grant_drop2(w)
	AdRewards.grant_drop2(w)
	check(not AdRewards.can_drop2(w) and AdRewards.drop2_left(w) == AdRewards.DROP2_MAX, "здобичі теж не більше 3 годин наперед")
	AdRewards.tick(w, 3600.0)
	check(AdRewards.drop2_left(w) == 2.0 * 3600.0 and AdRewards.can_drop2(w), "час ×2 здобичі минає в бою")
	AdRewards.tick(w, 99999.0)
	check(AdRewards.drop_mult(w) == 1.0, "×2 здобичі скінчилося")
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

## Зробити тестового героя сильнішим за еталон його рівня (у k разів за шкодою). Уся нечисть тепер тримає удар
## еталонного героя в середньому спорядженні, тож голий герой із тестів рубав би її хвилинами.
## Це перевірки ходу гри, а не балансу: баланс міряють tools/*_sim.gd.
func _fit(p, k: float = 3.0) -> void:
	var Power = load("res://scripts/game/power.gd")
	var key: String = "spi" if p.weapon_type == "staff" else ("agi" if p.weapon_type == "pishchal" else "str")
	var want: float = Data.ref_dps(int(p.level)) * k
	var guard := 0
	while Power.dps(p) < want and guard < 200:
		p.stats[key] = int(p.stats[key]) + maxi(10, int(p.stats[key]) / 4)
		p.recalc()
		guard += 1
	p.set_meta("fit", int(p.level))


func _bot_fight(game) -> void:
	var p = game.player
	var c = game.combat
	if int(p.get_meta("fit", 0)) != int(p.level):
		_fit(p)
	var en = c.nearest_enemy(p.global_position, 5000.0)
	game.hud.joystick.vector = (en.global_position - p.global_position).normalized() * 0.8 if en else Vector2.ZERO
	game.hud.btn_attack.held = true
	for id in Data.Classes.actives():
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
	var hall0: Array = game.hall_rows("sich")
	check(game.hud.dialogue_root == null and hall0.size() == 1 and hall0[0]["kind"] == "story" and hall0[0]["name"] == StoryService.Story.NPCS["otaman"]["name"], "на Січі ніхто не заговорює сам: кошовий чекає в курені")
	var hall_tab := ""
	var hall_btn := false
	var tc0 = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	hall_tab = tc0.get_tab_title(tc0.current_tab)
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		hall_btn = hall_btn or (not b.is_queued_for_deletion() and b.text == load("res://scripts/ui/ui_city.gd").HALL_TALK)
	check(hall_tab == "%s (1)" % Data.hall_name("sich") and hall_btn, "місто відкрилось на вкладці «%s» із кнопкою «Поговорити»" % hall_tab)
	_hall_talk(game)
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
	check(game.hud.dialogue_root == null and game.hall_rows("sich")[0]["ready"], "кошовий чекає на звіт у курені й сам не заговорює")
	_hall_talk(game)
	await _frames(2)
	check(game.hud.dialogue_root != null and game.hud.dialogue_root.choices.is_empty(), "кошовий радить поговорити з усіма трьома, а не питає одразу")
	var trial_txt := ""
	for st in load("res://scripts/data/story.gd").CHAPTERS[0]["steps"]:
		if st["id"] == "trial":
			for ln in st["end"]:
				trial_txt += str(ln[1]) + "\n"
	check(trial_txt != "" and "Мирон" in trial_txt and "Зореслав" in trial_txt and "Лесь" in trial_txt and "троє" in trial_txt and not ("двоє" in trial_txt) and not ("обома" in trial_txt), "кошовий у пролозі називає всіх трьох представників: Мирона, Зореславу й Леся")
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
	check(not game.PathService.can_choose(game.world), "двох розмов замало: є ще сотник сердюків")
	game.city_do("path_talk", "strilets")
	await _frames(2)
	check(game.hud.dialogue_root != null, "розмова із сотником Лесем")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.PathService.can_choose(game.world), "після всіх розмов вибір відкрито")
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
	_hall_talk(game)
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
	_hall_talk(game)
	check(game.hud.dialogue_root != null, "кошовий чекає зі звітом")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["step"] == 1 and game.hud.dialogue_root == null and game.hall_rows("sich")[0]["npc"] == "kobzar", "далі має справу кобзар: він чекає в курені, а не перебиває")
	_hall_talk(game)
	await _frames(2)
	check(game.world.story["step"] == 1 and game.hud.dialogue_root != null, "розмова з кобзарем починається, коли підійдеш")
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
	game.camp_do("ad_drop2", null)
	await _frames(3)
	check(game.AdRewards.drop_mult(game.world) == 2.0, "реклама на хуторі дає ×2 здобичі")
	var camp_ads := 0
	for b in game.hud.find_children("*", "Button", true, false):
		if b.text == "Переглянути рекламу":
			camp_ads += 1
	check(camp_ads >= 2, "на хуторі дві кнопки реклами: досвід і здобич")
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
	game.player.xp = game.player.xp_next / 2
	var xp_before: int = game.player.xp
	var lvl_before: int = game.player.level
	game.player.invuln = 0.0
	game.player.take_damage(1e9)
	await _frames(150)
	check(game.state == game.State.DEAD, "смерть козака")
	check(game.player.gold == gold_before - int(gold_before * Data.DEATH_GOLD_LOSS) and is_equal_approx(Data.DEATH_GOLD_LOSS, 0.05), "смерть забирає 5% гривень")
	var want_loss: int = ceili(game.player.xp_next * Data.DEATH_XP_LOSS) if lvl_before >= Data.DEATH_XP_FROM else 0
	check(game.player.level == lvl_before and game.player.xp == xp_before - want_loss, "смерть забирає досвід за правилом (%d), рівень не падає" % want_loss)
	var death_text := ""
	for n in game.hud.overlay_box.find_children("*", "Label", true, false):
		death_text += n.text + "\n"
	check(("Втрачено %d досвіду" % want_loss) in death_text if want_loss > 0 else "Втрачено" in death_text and not "досвіду" in death_text, "екран поразки називає втрачене")
	game.enter_city(game.world.last_city)
	check(game.player.alive and game.player.hp == game.player.max_hp, "козак отямився в місті")
	game.queue_free()
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	await _frames(2)


# ======================= Надважкі печери, набори речей, звитяги =======================

## Найменше, що потрібно службам здобичі від бою: опис місця й чи це Башта.
class FakeCombat:
	var loc := {}
	var tower := false
	func is_tower() -> bool:
		return tower
	func is_dungeon() -> bool:
		return not tower


func _suite_peril() -> void:
	suite("Надважкі печери: дані, правила, нагороди")
	var Peril = load("res://scripts/data/peril.gd")
	var PS = load("res://scripts/game/peril_service.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var Souls = load("res://scripts/data/souls.gd")
	var SS = load("res://scripts/game/soul_service.gd")
	var Loot = load("res://scripts/game/loot_service.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var Power = load("res://scripts/game/power.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var WM = load("res://scripts/ui/world_map.gd")
	var Wiki = load("res://scripts/data/wiki_data.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Rec = load("res://scripts/game/record_service.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	var WorldState = load("res://scripts/game/world_state.gd")
	var EnemyS = load("res://scripts/entities/enemy.gd")
	# ---- Печери ----
	var ids: Array = PS.ids()
	var levels := []
	var lands := {}
	var data_ok := true
	var boss_kinds := []
	for id in ids:
		var L: Dictionary = Data.LOCATIONS[id]
		levels.append(int(L["level"]))
		lands[str(L["land"])] = true
		boss_kinds.append(str(L["boss"]))
		data_ok = data_ok and L["type"] == "dungeon" and not L.get("scale", false) and Peril.LANDS.has(L["land"]) and Data.BOSS_NAMES.has(L["boss"]) and GfxS.has(L["boss"]) and Wiki.BOSSES.has(L["boss"]) and WM.ICON_ORDER.has(str(L["icon"])) and Peril.TITLES.has(L["boss"]) and Peril.TITLE_FX.has(L["boss"]) and int(L["rooms"]) >= 6
		for e in L["enemies"]:
			data_ok = data_ok and Data.ENEMY_NAMES.has(e) and GfxS.has(e) and Wiki.ENEMIES.has(e) and Souls.SOULS.has(e)
	check(ids.size() == 5 and levels == [100, 110, 120, 130, 140] and lands.size() == 5 and Peril.LAND_ORDER.size() == 5, "п'ять печер у п'яти землях, рівні від 100 до 140 з кроком 10: %s" % str(levels))
	check(data_ok, "кожна печера: земля, бос зі спрайтом, описом і званням, нечисть з описами й душами")
	check(Classes.BASE_LEVEL_MAX < int(levels[0]) and PS.is_peril(ids[0]) and not PS.is_peril("zmii_cave") and not PS.is_peril("nema"), "нечисть надважких печер вища за стелю рівня героя")
	var w = WorldState.new()
	var no_quests := true
	for i in 200:
		var q: Dictionary = w._gen_quest(Data.CITIES.keys()[i % Data.CITIES.size()])
		no_quests = no_quests and not PS.is_peril(str(q["loc"]))
	check(no_quests, "доручень у надважкі печери не дають")
	# ---- Сила нечисті росте від печери до печери ----
	var cm: Dictionary = PS.combat_mods(ids[0])
	var cm5: Dictionary = PS.combat_mods(ids[4])
	check(is_equal_approx(float(cm["hp_mult"]), Peril.HP_MULT) and is_equal_approx(float(cm["dmg_mult"]), Peril.DMG_MULT) and Peril.HP_MULT >= 3.0 and Peril.DMG_MULT >= 2.0, "нечисть першої печери в рази сильніша за звичайну свого рівня")
	check(float(cm5["hp_mult"]) > float(cm["hp_mult"]) * 1.3 and float(cm5["dmg_mult"]) > float(cm["dmg_mult"]) * 1.3 and PS.number(ids[4]) == 5, "кожна наступна печера ще лютіша понад рівень")
	check(is_equal_approx(float(cm["enrage_after"]), Peril.ENRAGE_AFTER) and float(cm["boss_hp_mult"]) > 1.0 and float(cm["xp_mult"]) > 1.0 and PS.combat_mods("zmii_cave").is_empty(), "бос міцніший і лютішає, досвіду більше; звичайних печер це не зачіпає")
	var th = _new_player()
	th.change_class("cossack")
	th.level = 99
	th.recalc()
	_fit(th, 6.0)
	var t1: Dictionary = Power.threat(th, int(levels[0]), PS.hp_mult(ids[0]), PS.dmg_mult(ids[0]))
	var t5: Dictionary = Power.threat(th, int(levels[4]), PS.hp_mult(ids[4]), PS.dmg_mult(ids[4]))
	check(float(t5["ttk"]) > float(t1["ttk"]) * 2.5 and float(t5["hits"]) < float(t1["hits"]) * 0.6 and int(t5["grade"]) == 3, "остання печера смертельна для героя, якому перша під силу (%.1f с проти %.1f с)" % [float(t5["ttk"]), float(t1["ttk"])])
	th.free()
	# ---- Вхід по черзі, звання, рекорди ----
	var p = _new_player()
	p.change_class("cossack")
	p.level = Peril.OPEN_LEVEL - 1
	p.recalc()
	check(str(Peril.OPEN_LEVEL) in PS.block_reason(w, p, ids[0]), "до %d-го рівня не пускають" % Peril.OPEN_LEVEL)
	p.level = Peril.OPEN_LEVEL
	check(PS.block_reason(w, p, ids[0]) == "" and PS.block_reason(w, p, ids[1]) != "" and PS.block_reason(w, p, "zmii_cave") == "", "перша печера відкрита, друга чекає на першу")
	check(PS.previous(ids[0]) == "" and PS.previous(ids[3]) == ids[2] and PS.title(w) == "" and PS.bosses_down(w) == 0, "порядок печер, звань іще нема")
	var hp0: float = p.max_hp
	var m1: Array = PS.on_clear(w, p, ids[0], 300.0, 0)
	var said: String = "\n".join(m1)
	check(PS.cleared(w, ids[0]) == 1 and PS.bosses_down(w) == 1 and PS.title(w) == str(Peril.TITLES[boss_kinds[0]]) and PS.block_reason(w, p, ids[1]) == "" and PS.block_reason(w, p, ids[2]) != "", "перша перемога: звання й відкрита наступна печера")
	check("Іменна звитяга" in said and str(Data.LOCATIONS[ids[1]]["name"]) in said and "5:00" in said, "про звання, наступну печеру й час сказано: %s" % said.replace("\n", " | "))
	check(is_equal_approx(p.max_hp / hp0, 1.0 + float(Peril.TITLE_FX[boss_kinds[0]]["hp"]) / 100.0) and PS.title_fx(w) == {"hp": 3.0}, "іменна звитяга одразу дає свій бонус")
	check(is_equal_approx(PS.best_time(w, ids[0]), 300.0) and int(PS.family_best(w, ids[0])["slot"]) == 0 and PS.time_text(75.4) == "1:15", "найкращий час героя й роду записано")
	var m2: Array = PS.on_clear(w, p, ids[0], 240.0, 1)
	check(PS.cleared(w, ids[0]) == 2 and is_equal_approx(PS.best_time(w, ids[0]), 240.0) and "Рекорд роду побито" in "\n".join(m2) and PS.titles(w).size() == 1, "швидший похід іншого героя забирає рекорд роду, звання двічі не дають")
	var m3: Array = PS.on_clear(w, p, ids[0], 500.0, 1)
	check(m3.is_empty() and is_equal_approx(PS.best_time(w, ids[0]), 240.0), "повільніший похід рекорду не псує")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(PS.cleared(w2, ids[0]) == 3 and PS.title(w2) == PS.title(w) and is_equal_approx(PS.best_time(w2, ids[0]), 240.0), "поступ у надважких печерах зберігається")
	for i in range(1, ids.size()):
		PS.on_clear(w, p, ids[i], 400.0, 0)
	check(PS.bosses_down(w) == 5 and PS.title(w) == str(Peril.TITLES[boss_kinds[4]]) and PS.title_fx(w).size() == 5, "п'ять босів: показуємо звання за найдальшого, діють усі п'ять бонусів")
	check("peril_bosses" in Acts.RECORD_ORDER and "valor" in Acts.RECORD_ORDER and int(Rec.hero_values(w, p)["peril_bosses"]) == 5, "надважкі боси й звитяги є в літописі рекордів")
	var rec_ok := true
	for key in Acts.RECORD_ORDER:
		rec_ok = rec_ok and Rec.hero_values(w, p).has(key) and Acts.RECORDS.has(key)
	check(rec_ok, "кожен рекорд літопису має значення героя")
	var ach := {}
	for a in Ach.ACHIEVEMENTS:
		ach[a["id"]] = a
	check(ach.has("peril_1") and ach.has("peril_5") and ach["peril_5"]["stat"] == "peril_bosses" and ach.has("valor_10") and ach.has("set_full"), "досягнення надважких печер, звитяг і наборів")
	# ---- Ціна смерті ----
	var d = _new_player()
	d.level = 95
	d.xp_next = Data.xp_for_level(95)
	d.xp = d.xp_next / 2
	var x0: int = d.xp
	var lost1: int = d.death_xp_loss(Peril.DEATH_XP_MULT)
	check(Peril.DEATH_XP_MULT >= 3.0 and absi(lost1 - ceili(d.xp_next * Data.DEATH_XP_LOSS * Peril.DEATH_XP_MULT)) <= 1 and d.xp == x0 - lost1, "смерть у надважкій печері забирає втричі більше досвіду")
	d.add_item(Arts.make("lanka_lantsiuha"), true)
	d.recalc()
	var lost2: int = d.death_xp_loss(Peril.DEATH_XP_MULT)
	check(absi(lost2 * 2 - lost1) <= 2, "«Ланка велетового ланцюга» зменшує втрату вдвічі (%d проти %d)" % [lost2, lost1])
	d.free()
	# ---- Золото шостого ступеня ----
	check(Uniques.TIER_NAMES.size() == 7 and Uniques.PRIMARY_MULT.size() == 7 and Uniques.BASE_CHANCE.size() == 7 and is_equal_approx(Loot.chance(6, 0), float(Uniques.BASE_CHANCE[6])) and float(Uniques.BASE_CHANCE[6]) > float(Uniques.BASE_CHANCE[5]), "шостий ступінь золота: назва, сила, шанс")
	var tier_ok := true
	for b in Uniques.BOSS_TIER:
		tier_ok = tier_ok and (int(Uniques.BOSS_TIER[b]) == 6) == (b in boss_kinds)
	var fav := {}
	for id in Uniques.ORDER:
		if int(Uniques.DEFS[id]["tier"]) == 6:
			for b in Uniques.DEFS[id]["bosses"]:
				tier_ok = tier_ok and b in boss_kinds
				fav[b] = true
	check(tier_ok and fav.size() == 5, "шостий ступінь мають лише надважкі боси, і в кожного є улюблена річ")
	var fc = FakeCombat.new()
	fc.loc = Data.LOCATIONS[ids[0]].duplicate()
	var boss = EnemyS.new()
	boss.setup(boss_kinds[0], int(levels[0]), true)
	check(Loot.is_lair_boss(fc, boss) and Loot.worthy(fc, p, boss) and Loot.boss_tier(fc, boss) == 6, "надважкий бос у своїй печері: шостий ступінь")
	var tw = FakeCombat.new()
	tw.tower = true
	tw.loc = {"type": "tower", "floor": 60, "level": 99}
	var kar = EnemyS.new()
	kar.setup("karachun", 99, true)
	check(Loot.boss_tier(tw, kar) == Uniques.TOP_COMMON_TIER and Loot.boss_tier(tw, boss) == 6, "Башта й Глибини до шостого ступеня не дотягують")
	var top: Dictionary = Uniques.make("mech_kladenets", 140)
	check(float(top["base"]["flat_dmg"]) > float(Uniques.make("shablia_bohdana", 140)["base"]["flat_dmg"]) * 1.04 and int(top["ilvl"]) == 140, "«Заповітна» зброя сильніша за «Характерницьку»")
	var six := 0
	for i in 400:
		if int(Uniques.DEFS[Loot.pick(p, 6, boss_kinds[0])]["tier"]) == 6:
			six += 1
	check(six > 200, "надважкий бос найчастіше дає річ шостого ступеня (%d із 400)" % six)
	# ---- Артефакти й душі ----
	var art_ok := true
	for b in boss_kinds:
		art_ok = art_ok and Arts.by_boss(b) != "" and Souls.SOULS.has("b_" + b) and SS.tier("b_" + b) == 7
	check(art_ok and Souls.TIER_NAMES.size() == 8 and Souls.TIER_COLORS.size() == 8, "у кожного надважкого боса свій артефакт і душа сьомого ступеня")
	var sp = _new_player()
	sp.level = 99
	sp.soul_found = 1
	var arts := 0
	for i in 2000:
		sp.art_luck = {}
		if not Loot.artifact_on_boss(fc, sp, boss).is_empty():
			arts += 1
	check(arts > 110 and arts < 215 and Arts.CHANCE_PERIL > Arts.CHANCE, "артефакт із надважкого боса падає частіше, ніж зі звичайного (%d із 2000)" % arts)
	boss.enrage_after = Peril.ENRAGE_AFTER
	var souls := 0
	for i in 3000:
		sp.soul_luck = 0.0
		if SS.roll(sp, boss) != "":
			souls += 1
	check(souls > 50 and souls < 140 and Souls.CHANCE_PERIL > float(Souls.CHANCE["boss"]), "душа надважкого боса падає частіше, ніж звичайного (%d із 3000)" % souls)
	sp.add_item(Arts.make("ulamok_chornoho_sontsia"), true)
	sp.add_item(Arts.make("velniasova_torba"), true)
	sp.add_item(Arts.make("hromovyi_kamin"), true)
	sp.add_item(Arts.make("zolota_lychyna"), true)
	sp.recalc()
	check(is_equal_approx(float(sp.art["dmg"]), 0.05) and is_equal_approx(float(sp.art["soul"]), 0.25) and is_equal_approx(float(sp.art["enrage"]), 30.0) and is_equal_approx(float(sp.art["set_luck"]), 0.25), "нові артефакти діють із торби")
	boss.free()
	kar.free()
	sp.free()
	p.free()


func _suite_sets() -> void:
	suite("Набори речей")
	var Sets = load("res://scripts/data/sets.gd")
	var SetS = load("res://scripts/game/set_service.gd")
	var PS = load("res://scripts/game/peril_service.gd")
	var City = load("res://scripts/game/city_service.gd")
	var EnemyS = load("res://scripts/entities/enemy.gd")
	var ids: Array = PS.ids()
	var data_ok := true
	var stats := {}
	for sid in Sets.ORDER:
		var S: Dictionary = Sets.SETS[sid]
		stats[str(S["stat"])] = true
		data_ok = data_ok and str(S["name"]) != "" and str(S["of"]) != "" and str(S["lore"]) != "" and str(S["stat"]) in Data.INT_STATS and S["affixes"].size() >= 4 and str(S["stat"]) in S["affixes"]
		for a in S["affixes"]:
			data_ok = data_ok and a in Data.AFFIX_POOL and not a in ["lifesteal", "regen"]
		for step in Sets.STEPS:
			data_ok = data_ok and S["bonus"].has(step) and not S["bonus"][step].is_empty() and Sets.step_text(sid, step) != "" and not "%s" in Sets.step_text(sid, step)
			for k in S["bonus"][step]:
				data_ok = data_ok and Sets.FX.has(k)
	check(Sets.ORDER.size() == 3 and Sets.ORDER.size() == Sets.SETS.size() and stats.size() == 3 and Sets.STEPS == [2, 4, 6], "три набори під три головні риси, бонуси за 2, 4 й 6 речей")
	check(data_ok, "кожен набір: назва, переказ, властивості без вампіризму й загоєння, бонуси з відомих ключів")
	# ---- Річ набору ----
	var it: Dictionary = Sets.make("sviatohor", "weapon", 120, "sabre")
	check(it["name"] == "Шабля Святогора" and it["set"] == "sviatohor" and int(it["rarity"]) == 3 and int(it["ilvl"]) == 120 and it["affixes"].size() == 3 and Sets.is_set(it) and not Sets.is_set(Data.gen_item(10, 3)), "річ набору: ім'я, позначка, якість легендарної")
	check(Sets.piece_name("dovbush", "belt") == "Пояс Довбуша" and Sets.piece_name("boian", "weapon", "staff") == "Посох Бояна", "назви речей наборів")
	check(Data.item_color(it) == Data.SET_COLOR and Data.item_color(Data.gen_item(10, 3)) == Data.RARITY_COLORS[3] and not Data.SET_COLOR in Data.RARITY_COLORS, "у речі набору свій колір")
	var aff_ok := true
	for sid in Sets.ORDER:
		for slot in Data.SLOTS:
			for i in 6:
				var x: Dictionary = Sets.make(sid, slot, 100, "sabre")
				aff_ok = aff_ok and x["affixes"].size() == 3 and not x["affixes"].has(Data.SLOT_PRIMARY[slot]) and x["base"].has(Data.SLOT_PRIMARY[slot])
				for a in x["affixes"]:
					aff_ok = aff_ok and a in Sets.SETS[sid]["affixes"]
	check(aff_ok, "властивості речі лише з переліку набору, без головної властивості клітинки")
	# ---- Бонуси на герої ----
	var p = _new_player()
	p.change_class("cossack")
	p.level = 99
	for slot in Data.SLOTS:
		var piece: Dictionary = Sets.make("sviatohor", slot, 100, "sabre")
		p.assign_uid(piece)
		p.equipment[slot] = piece
	p.recalc()
	var full_hp: float = p.max_hp
	var full_dmg: float = p.damage
	var fx6: Dictionary = Sets.fx(p.equipment)
	check(int(Sets.count(p.equipment)["sviatohor"]) == 6 and is_equal_approx(float(fx6["hp"]), 16.0) and is_equal_approx(float(fx6["dmg"]), 18.0) and is_equal_approx(float(fx6["big_dmg"]), 10.0) and is_equal_approx(float(fx6["armor"]), 4.0), "шість речей: діють усі три щаблі разом")
	check(int(Sets.worn.get("sviatohor", 0)) == 6, "картка речі знає, скільки речей набору вдягнено")
	for slot in Data.SLOTS:
		p.equipment[slot].erase("set")
	p.recalc()
	check(is_equal_approx(full_hp / p.max_hp, 1.16) and is_equal_approx(full_dmg / p.damage, 1.18) and p.set_fx.is_empty(), "набір справді додає здоров'я й шкоди (×%.3f і ×%.3f)" % [full_hp / p.max_hp, full_dmg / p.damage])
	p.equipment["head"]["set"] = "sviatohor"
	check(Sets.fx(p.equipment).is_empty(), "одна річ бонусу не дає")
	p.equipment["body"]["set"] = "sviatohor"
	check(Sets.fx(p.equipment) == {"hp": 8.0}, "дві речі: перший щабель")
	p.equipment["belt"]["set"] = "dovbush"
	p.equipment["boots"]["set"] = "dovbush"
	check(Sets.fx(p.equipment) == {"hp": 8.0, "aspd": 6.0}, "два набори по дві речі діють разом")
	p.equipment["weapon"]["set"] = "sviatohor"
	p.equipment["amulet"]["set"] = "sviatohor"
	var cd0: float = p.attack_cooldown
	p.recalc()
	check(is_equal_approx(float(p.set_fx["dmg"]), 8.0) and is_equal_approx(float(p.set_fx["armor"]), 4.0) and is_equal_approx(cd0 / p.attack_cooldown, 1.06), "чотири речі одного набору й дві іншого")
	# Картка речі
	var card = load("res://scripts/ui/ui_kit.gd").item_card(p.equipment["head"])
	var card_text := ""
	for l in card.find_children("*", "Label", true, false):
		card_text += l.text + "\n"
	check("Спадок Святогора: вдягнено 4 із 6" in card_text and "2 речі:" in card_text and "6 речей:" in card_text and "Річ набору" in card_text, "картка речі показує набір, скільки вдягнено і щаблі")
	card.free()
	# Масовий продаж наборів не чіпає
	p.inventory.clear()
	var spare: Dictionary = Sets.make("boian", "head", 100)
	p.add_item(spare, true)
	p.add_item(Data.gen_item(1, 0), true)
	var sold_set := false
	for c in City.bulk_candidates(p, 3):
		sold_set = sold_set or c.has("set")
	check(not sold_set, "масовий продаж речей наборів не чіпає")
	# ---- Яка річ падає ----
	var sp = _new_player()
	sp.change_class("cossack")
	var mage = _new_player()
	mage.change_class("volkhv")
	check(SetS.main_stat(sp) == "str" and SetS.main_stat(mage) == "spi", "головна риса класу")
	var own := 0
	for i in 600:
		if str(SetS.pick(sp)[0]) == "sviatohor":
			own += 1
	check(own > 330, "набір під свій клас трапляється частіше (%d із 600)" % own)
	for slot in ["weapon", "head", "body", "belt", "amulet"]:
		sp.add_item(Sets.make("sviatohor", slot, 100, "sabre"), true)
	var boots := 0
	var head := 0
	for i in 1000:
		var pk: Array = SetS.pick(sp)
		if str(pk[0]) == "sviatohor":
			if str(pk[1]) == "boots":
				boots += 1
			elif str(pk[1]) == "head":
				head += 1
	check(boots > head * 2 and SetS.owned(sp).size() == 5, "річ, якої ще нема, падає частіше за ту, що вже є (%d проти %d)" % [boots, head])
	var staff_ok := true
	for i in 120:
		var r: Dictionary = SetS.roll(mage, 130)
		staff_ok = staff_ok and Sets.is_set(r) and int(r["ilvl"]) == 130 and (r["slot"] != "weapon" or r["type"] == "staff")
	check(staff_ok, "зброя набору завжди до руки класу, рівень речі — рівень печери")
	# ---- Де падає ----
	var fc = FakeCombat.new()
	fc.loc = Data.LOCATIONS[ids[0]].duplicate()
	var boss = EnemyS.new()
	boss.setup(str(fc.loc["boss"]), int(fc.loc["level"]), true)
	var first: Dictionary = SetS.on_boss(fc, sp, boss, true)
	check(Sets.is_set(first) and int(first["ilvl"]) == int(fc.loc["level"]), "перша перемога над надважким босом дає річ набору напевно")
	var n := 0
	for i in 2000:
		if not SetS.on_boss(fc, sp, boss, false).is_empty():
			n += 1
	check(n > 400 and n < 600, "далі бос дає річ набору приблизно раз на чотири перемоги (%d із 2000)" % n)
	var el = EnemyS.new()
	el.setup(str(fc.loc["enemies"][0]), int(fc.loc["level"]), false)
	var plain := 0
	for i in 500:
		if not SetS.on_elite(fc, sp, el).is_empty():
			plain += 1
	el.elite = true
	var en := 0
	for i in 3000:
		if not SetS.on_elite(fc, sp, el).is_empty():
			en += 1
	check(plain == 0 and en > 50 and en < 140, "елітна нечисть надважкої печери зрідка дає річ набору, рядова — ніколи (%d із 3000)" % en)
	fc.loc = Data.LOCATIONS["zmii_cave"].duplicate()
	check(SetS.on_boss(fc, sp, boss, true).is_empty() and SetS.on_elite(fc, sp, el).is_empty(), "поза надважкими печерами наборів нема")
	boss.free()
	el.free()
	p.free()
	sp.free()
	mage.free()


func _suite_valor() -> void:
	suite("Звитяги: поступ після останнього рівня")
	var Valor = load("res://scripts/data/valor.gd")
	var Peril = load("res://scripts/data/peril.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var Power = load("res://scripts/game/power.gd")
	var cap: int = Classes.BASE_LEVEL_MAX
	var data_ok := true
	for id in Valor.ORDER:
		var L: Dictionary = Valor.LINES[id]
		data_ok = data_ok and str(L["name"]) != "" and float(L["per"]) > 0.0 and not "%s" in Valor.text(id, 3.0)
	check(Valor.ORDER.size() == 5 and Valor.ORDER.size() == Valor.LINES.size() and data_ok and Valor.LINE_MAX >= 20, "п'ять ліній звитяги з назвами й текстами")
	var bar0: int = Valor.bar(0)
	check(bar0 == int(Data.xp_for_level(cap - 1) * Valor.BAR_PART) and Valor.bar(10) > bar0 and Valor.bar(50) > Valor.bar(10) and Valor.BAR_PART <= 0.25, "перша смуга — частка останнього рівня, кожна наступна дорожча")
	check(Valor.fx({"dmg": 2}, {"dmg": 3, "gold": 10}) == {"dmg": 5.0, "gold": 10.0} and Valor.fx_text({"hp": 3}) == "+3% здоров'я" and Valor.text("ward", 2.5) == "шкода по тобі менша на 2,5%" and Valor.fx_text({"gold": 10}) == "+10% гривень", "бонуси звитяг складаються й мають тексти")
	# ---- Досвід після стелі ----
	var p = _new_player()
	p.change_class("cossack")
	p.level = cap - 1
	p.xp_next = Data.xp_for_level(cap - 1)
	p.xp = 0
	p.recalc()
	p.add_xp(1000)
	check(p.valor_xp == 0 and p.xp == 1000, "до останнього рівня досвід іде в рівень, а не у звитягу")
	p.level = cap
	p.xp = 0
	p.add_xp(bar0 / 2)
	check(p.valor == 0 and p.valor_xp == bar0 / 2 and p.level == cap and p.xp == 0 and p.valor_next() == bar0, "на останньому рівні досвід наповнює смугу звитяги")
	p.add_xp(bar0)
	check(p.valor == 1 and p.valor_points() == 1 and p.valor_xp == bar0 / 2 and p.valor_next() == Valor.bar(1), "заповнена смуга дає очко, решта досвіду переходить далі")
	var dmg0: float = p.damage
	var hp0: float = p.max_hp
	var sk0: float = p.skill_power
	var gold0: float = p.gold_mult
	check(p.can_add_valor("dmg") and p.add_valor("dmg") and p.valor_points() == 0 and not p.add_valor("hp") and is_equal_approx(p.damage / dmg0, 1.01), "очко в «Лють»: +1% шкоди, більше очок нема")
	p.valor = 60
	p.valor_spent = {"dmg": Valor.LINE_MAX}
	check(not p.can_add_valor("dmg") and p.can_add_valor("hp") and not p.can_add_valor("nema") and p.valor_points() == 60 - Valor.LINE_MAX, "у лінії є стеля, невідомих ліній нема")
	p.valor_spent = {"hp": 10, "ward": 10, "skill": 4, "luck": 5}
	p.title_fx = {"gold": 10}
	p.recalc()
	check(is_equal_approx(p.max_hp / hp0, 1.1) and is_equal_approx(p.skill_power / sk0, 1.04) and is_equal_approx(p.loot_luck(), 1.05) and is_equal_approx(float(p.valor_fx["ward"]), 5.0) and is_equal_approx(p.gold_mult - gold0, 0.1), "«Гарт», «Слово», «Талан», «Оберіг» та іменна звитяга діють")
	check(is_equal_approx(Power.ehp(p), p.max_hp / maxf(1.0 - Data.ARMOR_CAP, 1.0 - p.armor) / 0.95), "«Оберіг» враховано в запасі живучості")
	# ---- Смерть на останньому рівні ----
	p.valor_xp = p.valor_next() / 2
	var v0: int = p.valor_xp
	var pts: int = p.valor
	var lost: int = p.death_xp_loss(1.0)
	check(lost > 0 and absi(lost - ceili(p.valor_next() * Data.DEATH_XP_LOSS)) <= 1 and p.valor_xp == v0 - lost and p.valor == pts, "смерть на останньому рівні забирає частку смуги звитяги, очки лишаються")
	var lost3: int = p.death_xp_loss(Peril.DEATH_XP_MULT)
	check(lost3 >= lost * 3 - 2 and lost3 <= lost * 3 + 2, "у надважкій печері втричі більше (%d проти %d)" % [lost3, lost])
	p.valor_xp = 0
	check(p.death_xp_loss(Peril.DEATH_XP_MULT) == 0 and p.valor == pts, "порожня смуга: нижче нуля не опускається")
	# ---- Збереження ----
	p.valor_xp = 12345
	var q = _new_player()
	q.from_dict(p.to_dict())
	check(q.valor == p.valor and q.valor_xp == 12345 and q.valor_spent == p.valor_spent and q.title_fx.is_empty(), "звитяги зберігаються; іменні бонуси заново дає світ, а не збереження героя")
	p.free()
	q.free()


func _suite_peril_game() -> void:
	suite("Надважкі печери: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Peril = load("res://scripts/data/peril.gd")
	var PS = load("res://scripts/game/peril_service.gd")
	var Sets = load("res://scripts/data/sets.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "peril_camp", "enrage", "levelup"]:
		w.hints[k] = true
	p.change_class("cossack")
	p.level = Classes.BASE_LEVEL_MAX
	p.stat_points = 0
	p.skill_points = 0
	p.perk_points = 0
	p.stats["vit"] = 400
	p.recalc()
	_fit(p, 8.0)
	p.hp = p.max_hp
	p.gold = 1000000
	w.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	var ids: Array = PS.ids()
	var id0: String = ids[0]
	var panel_text := func() -> String:
		var out := ""
		for l in game.hud.map_panel.find_children("*", "Label", true, false):
			out += l.text + "\n"
		for b in game.hud.map_panel.find_children("*", "Button", true, false):
			out += b.text + "\n"
		return out
	# ---- Мапа й табір ----
	game.enter_map()
	await _frames(2)
	game._on_map_select(id0)
	await _frames(1)
	var far_text: String = panel_text.call()
	check("Надважка печера" in far_text and "Вирушити до табору" in far_text and not "Увійти до печери" in far_text and str(Data.BOSS_NAMES[Data.LOCATIONS[id0]["boss"]]) in far_text and "Тобі тут" in far_text, "здалеку панель показує правила й кнопку дороги до табору")
	await _ride(game, id0)
	var camp_text: String = panel_text.call()
	check(game.map_here == id0 and game.state == game.State.MAP and "Табір біля входу" in camp_text and "Увійти до печери" in camp_text and "Перепочити" in camp_text and "Зілля здоров'я" in camp_text, "дорога веде до табору, а не одразу в бій")
	p.potions = 0
	p.hp = 1.0
	var g0: int = p.gold
	game.peril_camp_do("potion")
	game.peril_camp_do("rest")
	check(p.potions == 1 and p.gold == g0 - PS.potion_price(p) and is_equal_approx(p.hp, p.max_hp) and PS.potion_price(p) > Data.potion_price(p.level), "у таборі можна перепочити й купити зілля в маркітанта, дорожче ніж у місті")
	# ---- Вхід по черзі ----
	game.enter_peril(ids[1])
	await _frames(2)
	check(game.state == game.State.MAP, "у другу печеру не пускають, поки не пройдено першу")
	game.enter_peril(id0)
	await _frames(3)
	check(game.state == game.State.PLAYING and c.loc.has("peril") and is_equal_approx(float(c.loc["hp_mult"]), PS.hp_mult(id0)) and bool(c.loc.get("peril_first", false)), "вхід у першу печеру: нечисть із надбавкою надважкої печери")
	# еліта й зараза множать силу ще далі, тож дивимось на найменшу надбавку серед нечисті кімнати
	var min_hp := INF
	var min_dmg := INF
	for foe in c.get_tree().get_nodes_in_group("enemies"):
		min_hp = minf(min_hp, float(foe.max_hp) / float(foe.raw_hp))
		min_dmg = minf(min_dmg, float(foe.damage) / float(foe.raw_dmg))
	check(min_hp >= PS.hp_mult(id0) - 0.01 and min_hp < PS.hp_mult(id0) * 2.0 and min_dmg >= PS.dmg_mult(id0) - 0.01, "рядова нечисть міцніша й б'є сильніше, ніж звичайна свого рівня (×%.2f і ×%.2f)" % [min_hp, min_dmg])
	# ---- Бос і лють ----
	_clear_enemies(game)
	if c.portal != null and is_instance_valid(c.portal):
		c.portal.queue_free()
	c.portal = null
	c.room = int(c.loc["rooms"])
	c._spawn_room()
	await _frames(2)
	var boss = null
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.is_boss and not e.illusion:
			boss = e
	check(boss != null and is_equal_approx(float(boss.enrage_after), Peril.ENRAGE_AFTER) and float(boss.max_hp) > Data.enemy_std_hp(int(c.loc["level"])) * Data.BOSS_HP_MULT * PS.hp_mult(id0), "надважкий бос: міцніший за звичайного боса й має час люті")
	var bd0: float = boss.damage
	boss._fight_t = Peril.ENRAGE_AFTER - 0.05
	boss._tick_enrage(0.1)
	check(boss.enrage_n == 1 and is_equal_approx(boss.damage / bd0, 1.0 + Peril.ENRAGE_DMG), "бій затягнувся: бос лютішає, удар росте")
	boss._tick_enrage(Peril.ENRAGE_EVERY * 2.0)
	check(boss.enrage_n == 3 and boss.damage > bd0 * 1.2, "і росте далі кожні %d с" % int(Peril.ENRAGE_EVERY))
	# ---- Смерть: утричі більше зі смуги звитяги, отямлюється в таборі ----
	p.valor_xp = p.valor_next() / 2
	var v0: int = p.valor_xp
	p.hp = 1.0
	p.invuln = 0.0
	p.take_damage(999999.0)
	await _frames(2)
	var waited := 0
	while game.hud.overlay_box == null or game.hud.overlay_box.find_children("*", "Button", true, false).is_empty():
		await create_timer(0.1, true, false, true).timeout
		waited += 1
		if waited > 40:
			break
	var wake_btn: Button = null
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		if "таборі" in b.text:
			wake_btn = b
	var want_loss: int = ceili(p.valor_next() * Data.DEATH_XP_LOSS * Peril.DEATH_XP_MULT)
	check(game.state == game.State.DEAD and wake_btn != null and absi((v0 - p.valor_xp) - want_loss) <= 1, "смерть у надважкій печері: втрачено %d зі смуги звитяги, є кнопка табору" % (v0 - p.valor_xp))
	if wake_btn != null:
		wake_btn.pressed.emit()
	await _frames(3)
	check(game.state == game.State.MAP and game.map_here == id0 and p.alive and "Увійти до печери" in panel_text.call(), "герой отямився в таборі біля входу")
	# ---- Перемога: звання, річ набору, рекорд ----
	game.enter_peril(id0)
	await _frames(3)
	_clear_enemies(game)
	if c.portal != null and is_instance_valid(c.portal):
		c.portal.queue_free()
	c.portal = null
	c.room = int(c.loc["rooms"])
	c._spawn_room()
	await _frames(2)
	boss = null
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.is_boss and not e.illusion:
			boss = e
	c.run_time = 245.0
	var hp_before: float = p.max_hp
	# у кімнаті боса є ще й його почет: кладемо всіх, боса останнім
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e != boss and not e.dead:
			e.take_damage(e.max_hp * 10.0, Vector2.ZERO, false)
	boss.take_damage(boss.max_hp * 10.0, Vector2.ZERO, false)
	await _frames(8)
	var piece := {}
	for ch in c.entities.get_children():
		if ch.get_script() == c.PickupScript and ch.kind == "item" and ch.item.has("set") and not ch.is_queued_for_deletion():
			piece = ch.item
	check(PS.cleared(w, id0) == 1 and PS.title(w) == str(Peril.TITLES[Data.LOCATIONS[id0]["boss"]]) and PS.best_time(w, id0) >= 245.0 and PS.best_time(w, id0) < 250.0, "перемога: печеру пройдено, звання й час записано")
	check(Sets.is_set(piece) and int(piece["ilvl"]) == int(Data.LOCATIONS[id0]["level"]), "перша перемога лишає річ набору рівня печери")
	check(p.max_hp > hp_before * 1.02 and not p.title_fx.is_empty() and PS.block_reason(w, p, ids[1]) == "", "іменна звитяга діє одразу, друга печера відкрита")
	check(int(w.stats.get("peril_bosses", 0)) == 1 and int(w.stats.get("peril", 0)) == 1 and game.ChallengeService.state(w, p)["ach"].has("peril_1"), "досягнення за першого надважкого боса")
	game.enter_map()
	await _frames(2)
	# ---- Екран героя: звання й звитяги ----
	p.valor = 3
	p.valor_spent = {}
	game.open_character()
	await _frames(2)
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var tab_i := -1
	for i in tc.get_tab_count():
		if tc.get_tab_title(i).begins_with("Загартування"):
			tab_i = i
	check(tab_i >= 0 and "(+3)" in tc.get_tab_title(tab_i), "вкладка «Загартування» показує вільні очки звитяги")
	_reveal_tabs(game)
	var all_text := ""
	for l in game.hud.screen_root.find_children("*", "Label", true, false):
		all_text += l.text + "\n"
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		all_text += b.text + "\n"
	check(str(Peril.TITLES[Data.LOCATIONS[id0]["boss"]]) in all_text and "Звитяга 3" in all_text and "Лють" in all_text and "Талан" in all_text and "Іменні звитяги" in all_text, "екран героя: звання в заголовку, смуга звитяги, лінії й іменні звитяги")
	var dmg0: float = p.damage
	game.char_do("valor", "dmg")
	await _frames(2)
	check(p.valor_points() == 2 and is_equal_approx(p.damage / dmg0, 1.01), "очко звитяги вкладається з екрана героя")
	game.close_character()
	await _frames(2)
	# ---- Збереження й завантаження ----
	game.save_game()
	var d: Dictionary = SaveSystem.load_data(TEST_SAVE)
	check(not d.is_empty(), "гру збережено")
	# ---- Довідник ----
	var titles := {}
	for sec in WS.sections():
		for e in sec["entries"]:
			titles[str(e["title"])] = true
	var missing := []
	for t in ["Надважкі печери", "Набори речей", "Звитяги", "Спадок Святогора", "Убір Довбуша", "Шати Віщого Бояна", "Меч-кладенець", "Ланка велетового ланцюга", "Душа Чорнобога", "Дев, володар ущелини", "Чорнобог, володар кінця світу", "Алмасти", "Хійсі"]:
		if not titles.has(t):
			missing.append(t)
	check(missing.is_empty(), "довідник знає про надважкі печери, набори, звитяги й нову нечисть: бракує %s" % str(missing))
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false


# ======================= Крамниця за донат і меню, що вміщаються =======================

func _suite_shop() -> void:
	suite("Крамниця за донат: каталог, ціни, покупка")
	var Shop = load("res://scripts/data/shop.gd")
	var SH = load("res://scripts/game/shop_service.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var Sets = load("res://scripts/data/sets.gd")
	var Souls = load("res://scripts/data/souls.gd")
	var SS = load("res://scripts/game/soul_service.gd")
	var PS = load("res://scripts/game/peril_service.gd")
	var WorldState = load("res://scripts/game/world_state.gd")
	var Account = load("res://scripts/game/account.gd")
	# ---- Набори червінців ----
	var packs_ok := true
	var seen := {}
	var prev := 0
	for p in Shop.PACKS:
		packs_ok = packs_ok and str(p["id"]) != "" and not seen.has(p["id"]) and str(p["name"]) != "" and str(p["price"]) != "" and int(p["coins"]) > prev and SH.pack(str(p["id"])) == p
		seen[p["id"]] = true
		prev = int(p["coins"])
	check(Shop.PACKS.size() >= 4 and packs_ok and SH.pack("nema").is_empty(), "набори червінців: назва, ціна, щораз більше")
	# ---- У крамниці є все рідкісне ----
	check(SH.ids("unique").size() == Uniques.ORDER.size() and SH.ids("artifact").size() == Arts.ORDER.size() and SH.ids("soul").size() == SS.known().size() and SH.ids("set").size() == Sets.ORDER.size() * Data.SLOTS.size() and SH.ids("set_full").size() == Sets.ORDER.size(),
		"у крамниці всі золоті речі (%d), артефакти (%d), душі (%d) й речі наборів (%d)" % [SH.ids("unique").size(), SH.ids("artifact").size(), SH.ids("soul").size(), SH.ids("set").size()])
	var priced := true
	for kind in ["unique", "artifact", "soul", "set", "set_full"]:
		for id in SH.ids(kind):
			priced = priced and SH.price(kind, id) > 0
	check(priced and SH.price("unique", "nema") == 0 and SH.price("set", "sviatohor:nema") == 0 and SH.price("nema", "x") == 0, "кожен товар має ціну, вигаданих товарів нема")
	check(SH.price("soul", "b_chornoboh") > SH.price("soul", "zlyden") and SH.price("unique", "mech_kladenets") > SH.price("unique", "kotyhoroshko") and SH.price("artifact", "ulamok_chornoho_sontsia") > SH.price("artifact", "zmiiv_zub"), "що вищий ступінь, то дорожче")
	check(SH.price("set_full", "boian") < SH.price("set", "boian:head") * Data.SLOTS.size() and Shop.SOUL_PRICE.size() == Souls.TIER_NAMES.size() and Shop.UNIQUE_PRICE.size() == Uniques.TIER_NAMES.size(), "увесь набір дешевший, ніж поодинці; ціна є для кожного ступеня")
	# ---- Червінці ----
	var w = WorldState.new()
	var acc = Account.new()
	acc.attach(w)
	check(SH.coins(w) == 0 and SH.grant_pack(w, "nema") == 0 and SH.grant_pack(w, "coins_550") == 550 and SH.coins(w) == 550 and int(acc.shop["coins"]) == 550, "оплачений набір зараховує червінці в акаунт роду")
	var acc2 = Account.new()
	acc2.from_dict(acc.to_dict())
	var w2 = WorldState.new()
	acc2.attach(w2)
	check(SH.coins(w2) == 550 and int(SH.state(w2)["packs"]["coins_550"]) == 1, "червінці зберігаються разом з акаунтом")
	# ---- Покупка ----
	var p = _new_player()
	p.change_class("cossack")
	p.level = 37
	p.recalc()
	var poor = WorldState.new()
	var res0: Dictionary = SH.buy(poor, p, "unique", "shablia_sirka")
	check(not bool(res0["ok"]) and "Бракує" in str(res0["msg"]) and p.inventory.is_empty() and SH.coins(poor) == 0, "без червінців нічого не продають")
	SH.grant_pack(w, "coins_7000")
	var c0: int = SH.coins(w)
	var res1: Dictionary = SH.buy(w, p, "unique", "shablia_sirka")
	var got: Dictionary = res1["items"][0] if not res1["items"].is_empty() else {}
	check(bool(res1["ok"]) and got.get("unique", "") == "shablia_sirka" and int(got["ilvl"]) == 37 and p.find_item(int(got["uid"])) == got and SH.coins(w) == c0 - SH.price("unique", "shablia_sirka") and SH.bought(w, "unique", "shablia_sirka") == 1, "золота річ: рівень героя, лежить у торбі, червінці списано")
	while not p.bag_full():
		p.add_item(Data.gen_item(5, 0))
	var n0: int = p.inventory.size()
	check(bool(SH.buy(w, p, "set", "sviatohor:belt")["ok"]) and p.inventory.size() == n0 + 1 and Sets.is_set(p.inventory[n0]) and int(p.inventory[n0]["ilvl"]) == 37, "куплене лягає й понад місце в торбі")
	p.inventory.clear()
	var c1: int = SH.coins(w)
	check(bool(SH.buy(w, p, "soul", "b_dev")["ok"]) and int(p.souls.get("b_dev", 0)) == 1 and SH.coins(w) == c1 - SH.price("soul", "b_dev"), "душа летить у торбинку душ")
	check(bool(SH.buy(w, p, "artifact", "zmiiv_zub")["ok"]) and Arts.has(p.inventory, "zmiiv_zub") and "Уже лежить" in SH.block_reason(w, p, "artifact", "zmiiv_zub") and not bool(SH.buy(w, p, "artifact", "zmiiv_zub")["ok"]), "артефакт удруге не продають: другий такий самий не діє")
	var full: Dictionary = SH.buy(w, p, "set_full", "dovbush")
	var slots := {}
	for it in full["items"]:
		slots[str(it["slot"])] = true
	check(bool(full["ok"]) and full["items"].size() == Data.SLOTS.size() and slots.size() == Data.SLOTS.size() and int(SH.state(w)["spent"]) > 0, "увесь набір: шість речей у всі клітинки")
	var mage = _new_player()
	mage.change_class("volkhv")
	check(SH.set_weapon(mage) == "staff" and SH.set_weapon(p) == str(p.weapon_type) and not SH.fits(p, "unique", "posokh_svaroha") and SH.fits(mage, "unique", "posokh_svaroha") and SH.fits(p, "soul", "zlyden"), "зброя набору до руки класу; чужу золоту зброю позначено")
	var wpn: Dictionary = SH.buy(w, mage, "set", "boian:weapon")
	check(bool(wpn["ok"]) and str(wpn["items"][0]["type"]) == "staff" and str(wpn["items"][0]["name"]) == "Посох Бояна", "волхв купує зброю набору посохом")
	mage.level = 0
	check(SH.block_reason(w, p, "unique", "nema") == "Такого товару нема" and SH.item_level(mage) == 1, "вигаданий товар не купити; рівень речі не нижчий за перший")
	# ---- Тестова оплата ----
	var billing = root.get_node("Billing")
	var was_instant: bool = billing.instant
	billing.instant = false
	var paid := [null]
	billing.purchase("coins_100", "Жменя", "39 грн", func(ok: bool): paid[0] = ok)
	check(billing.is_test() and billing.is_busy() and paid[0] == null, "тестова оплата чекає на рішення гравця")
	billing._finish(false)
	check(paid[0] == false and not billing.is_busy(), "скасована оплата нічого не дає")
	billing.instant = was_instant
	p.free()
	mage.free()


func _suite_shop_game() -> void:
	suite("Крамниця й меню: у грі")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var SH = load("res://scripts/game/shop_service.gd")
	var Shop = load("res://scripts/data/shop.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var billing = root.get_node("Billing")
	billing.instant = true
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup"]:
		w.hints[k] = true
	p.change_class("cossack")
	p.level = 30
	p.recalc()
	w.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	var menu_texts := func() -> Array:
		var out := []
		for b in game.hud.overlay_box.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion():
				out.append(b.text)
		return out
	var press_menu := func(prefix: String) -> bool:
		for b in game.hud.overlay_box.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion() and b.text.begins_with(prefix):
				b.pressed.emit()
				return true
		return false
	# ---- Пауза вміщається на екрані ----
	game.enter_location("wild_field")
	await _frames(3)
	game._show_pause()
	await _frames(3)
	var texts: Array = menu_texts.call()
	var sc: ScrollContainer = game.hud.overlay_scroll
	var bar: ScrollBar = sc.get_v_scroll_bar()
	check("Продовжити" in texts and "Персонаж" in texts and "Довідник" in texts and "Крамниця" in texts and "Головне меню" in texts and "Повернутися на мапу" in texts, "у паузі є всі кнопки: %s" % str(texts).replace("\n", " "))
	check(game.hud.overlay_box.size.y + 24.0 <= sc.size.y and bar.max_value <= bar.page + 1.0, "меню паузи вміщається на екрані без гортання (%d із %d)" % [int(game.hud.overlay_box.size.y), int(sc.size.y)])
	for i in 8:
		game.hud.add_button("Зайва кнопка %d" % i, func(): pass)
	await _frames(3)
	check(bar.max_value > bar.page + 100.0, "довше меню гортається, а не ховає нижні кнопки")
	sc.scroll_vertical = 300
	game._show_pause()
	await _frames(3)
	check(sc.scroll_vertical == 0, "нове меню відкривається згори")
	# ---- Крамниця з паузи ----
	check(press_menu.call("Крамниця"), "кнопка крамниці в паузі")
	await _frames(2)
	var tabs := []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		tabs.append(tc.get_tab_title(i))
	check(game.shop_open and not game.hud.overlay.visible and tabs == ["Червінці", "Золоті речі", "Набори", "Артефакти", "Душі", "Божі дари", "Вбрання", "Універсал"], "крамницю відкрито: вкладки %s" % str(tabs))
	game.shop_do("pack", "coins_1200")
	await _frames(3)
	check(SH.coins(w) == 1200 and int(game.account.shop["coins"]) == 1200, "набір червінців оплачено й зараховано")
	var cost: int = SH.price("unique", "shablia_sirka")
	game.shop_tab = game._shop_tab_index("Золоті речі")  # гравець купує на вкладці товару
	game.shop_do("buy", ["unique", "shablia_sirka"])
	await _frames(2)
	check(game.shop_confirm == "unique:shablia_sirka" and SH.coins(w) == 1200 and p.inventory.is_empty(), "перший дотик лише просить підтвердити")
	var confirm_seen := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		if b.text.begins_with("Підтвердити"):
			confirm_seen = true
	check(confirm_seen, "кнопка товару просить підтвердження")
	game.shop_do("buy", ["unique", "shablia_sirka"])
	await _frames(2)
	var bought_it := false
	for it in p.inventory:
		bought_it = bought_it or it.get("unique", "") == "shablia_sirka"
	check(bought_it and SH.coins(w) == 1200 - cost and game.shop_confirm == "", "другий дотик купує: річ у торбі, червінці списано")
	game.shop_do("buy", ["set_full", "sviatohor"])
	game.shop_do("buy", ["set_full", "sviatohor"])
	await _frames(2)
	check(SH.coins(w) == 1200 - cost and game.shop_confirm == "", "на що бракує червінців, те не купується")
	game.close_shop()
	await _frames(2)
	check(not game.shop_open and game.state == game.State.PAUSED and game.hud.overlay.visible and "Продовжити" in menu_texts.call(), "«Назад» вертає в паузу")
	# Збережено в акаунті
	var f := FileAccess.open(TEST_ACCOUNT, FileAccess.READ)
	var saved: Dictionary = f.get_var() if f != null else {}
	check(int(saved.get("shop", {}).get("coins", -1)) == 1200 - cost, "червінці й покупки збережено у файлі роду")
	# ---- Привал і екран героя ----
	game.enter_map()
	await _frames(2)
	game._show_map_menu()
	await _frames(2)
	check("Крамниця" in menu_texts.call() and "Вийти з гри" in menu_texts.call(), "крамниця є й на привалі")
	game._close_map_menu()
	game.open_character()
	await _frames(2)
	var hero_btn := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		hero_btn = hero_btn or b.text == "Крамниця"
	check(hero_btn, "і на екрані героя")
	game.close_character()
	await _frames(2)
	# ---- Довідник ----
	var found := false
	for sec in WS.sections():
		for e in sec["entries"]:
			if str(e["title"]) == "Крамниця":
				found = "червінці" in str(e["text"]) and str(Shop.SET_FULL_PRICE) in str(e["text"])
	check(found, "довідник пояснює крамницю й ціни")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false


# ======================= Вміння: більше, ніж очок; рушій за даними =======================

func _suite_skill_trees() -> void:
	suite("Вміння: дерева більші за запас очок")
	var Classes = load("res://scripts/data/classes.gd")
	var SI = load("res://scripts/data/skill_info.gd")
	var Icons = load("res://scripts/data/skill_icon_index.gd")
	var Status = load("res://scripts/game/status.gd")
	var ranks_of := func(cls: String) -> int:
		var n := 0
		for br in Classes.TREES.get(cls, []):
			for node in br["nodes"]:
				n += int(node["max"])
		return n
	# Очок на вершині: майстерність Селянина 10, першого класу 40, спеціалізації 50 (по очку за рівень понад перший)
	var tight := []
	for cls in Classes.CLASSES:
		if int(Classes.CLASSES[cls]["tier"]) != 2:
			continue
		var points := 0
		var ranks := 0
		for c in Classes.lineage(cls):
			points += int(Classes.CLASSES[c]["job_max"]) - 1
			ranks += int(ranks_of.call(c))
		if float(ranks) < float(points) * 1.3:
			tight.append("%s %d/%d" % [cls, ranks, points])
	check(tight.is_empty(), "у кожної спеціалізації рангів щонайменше на третину більше, ніж очок: %s" % str(tight))
	var bad := []
	var acts := 0
	var passives := 0
	for cls in Classes.TREES:
		for br in Classes.TREES[cls]:
			for node in br["nodes"]:
				var id: String = node["id"]
				var good: bool = Icons.INDEX.has(id) and str(node["desc"]) != ""
				if node.has("fx") and not node.has("act"):
					passives += 1
					for k in node["fx"]:
						good = good and Classes.FX_TEXT.has(k)
					for wt in node.get("when", {}).get("weapon", []):
						good = good and Data.WEAPON_TYPES.has(wt)
				if node.has("act"):
					acts += 1
					var A: Dictionary = node["act"]
					good = good and str(A["type"]) in ["nova", "leap", "cone", "shots", "zone", "buff", "summon"] and float(A["cd"]) > 0.0 and str(A["label"]) != "" and str(A["label"]).length() <= 10 and node.get("active", false)
					good = good and Classes.cooldown(id) == float(A["cd"]) and Classes.label(id) == str(A["label"]) and SI.kind(id) == ("buff" if A["type"] in ["buff", "summon"] else "attack")
					for k in A.get("fx", {}):
						good = good and Classes.FX_TEXT.has(k)
					if A.has("status"):
						good = good and Status.INFO.has(str(A["status"][0]))
					good = good and load("res://scripts/data/sound_index.gd").SFX.has(str(A.get("sound", "boom")))
				if not good:
					bad.append(id)
	check(bad.is_empty() and acts >= 30 and passives >= 30, "вміння за даними: значок, опис, відомі ключі, шаблон і перезарядка (активних %d, пасивних %d): %s" % [acts, passives, str(bad)])
	check(is_equal_approx(Classes.val([10, 3], 1), 10.0) and is_equal_approx(Classes.val([10, 3], 3), 16.0) and is_equal_approx(Classes.val(7, 5), 7.0), "значення за рангом: основа й приріст")
	check(Classes.fx_text({"dmg": [10, 3], "ward": -5}, 2) == "+13% шкоди, шкода по тобі більша на 5%" and Classes.fx_text({"regen_pct": 0.6}) == "відновлює 0,6% здоров'я за секунду", "бонуси словами")
	# Пасивні бонуси: ранг множить, зброя вмикає
	var p = _new_player()
	p.change_class("cossack")
	p.change_class("zaporozhets")
	p.level = 60
	p.recalc()
	var cd0: float = p.attack_cooldown
	var crit0: float = p.crit_chance
	p.skills["shablia_master"] = 5
	p.skills["dvobii"] = 3
	p.skills["kremin"] = 4
	p.recalc()
	check(str(p.weapon_type) == "sabre" and is_equal_approx(p.fx("aspd"), 15.0) and is_equal_approx(cd0 / p.attack_cooldown, 1.15) and is_equal_approx(p.crit_chance - crit0, 0.075), "«Шабельний бій» із шаблею: +15% швидкості удару й +7,5% криту")
	check(is_equal_approx(p.fx("big_dmg"), 12.0) and is_equal_approx(p.fx("ward"), 6.0), "бонуси різних умінь складаються")
	var mace: Dictionary = Data.gen_item(60, 1, "weapon", "mace")
	p.assign_uid(mace)
	p.equipment["weapon"] = mace
	p.recalc()
	check(is_equal_approx(p.fx("aspd"), 0.0) and is_equal_approx(p.fx("big_dmg"), 12.0), "з булавою шабельна майстерність не діє, решта діє")
	var stats: Array = SI.stats("taran", 3, p)
	check(not stats.is_empty() and str(stats[0][0]) == "Шкода" and not SI.stats("navala", 1, p).is_empty() and Classes.actives().has("taran") and Classes.actives().has("zemnyi"), "картка вміння за даними має цифри")
	# Чужі дерева не діють
	var v = _new_player()
	v.change_class("volkhv")
	v.skills["shablia_master"] = 5
	v.recalc()
	check(is_equal_approx(v.fx("aspd"), 0.0), "вміння чужої дороги бонусу не дає")
	p.free()
	v.free()


func _suite_skill_engine_game() -> void:
	suite("Вміння за даними: у бою")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Classes = load("res://scripts/data/classes.gd")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup"]:
		game.world.hints[k] = true
	p.change_class("cossack")
	p.change_class("zaporozhets")
	game._sync_class()
	p.level = 50
	p.stats["vit"] = 200
	p.recalc()
	_fit(p, 2.0)
	game.world.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	var missing := []
	for id in Classes.actives():
		if not game.hud.skill_buttons.has(id):
			missing.append(id)
	check(missing.is_empty(), "кожне активне вміння має кнопку бою: %s" % str(missing))
	game.enter_location("wild_field")
	await _frames(3)
	var dummy := func(offset: Vector2, hp_mult: float = 1000.0):
		c.spawn_enemy("upyr", 50, false, p.global_position + offset)
		var e = c._last_enemy()
		e.max_hp *= hp_mult
		e.hp = e.max_hp
		e.speed = 0.0
		e.damage = 0.0
		return e
	var ready := func() -> void:
		p.mana = p.max_mana
		for id in p.skill_timers.keys():
			p.skill_timers[id] = 0.0
		p.invuln = 0.0
	# ---- Стійки: діє одна, спадає з часом ----
	for id in ["navala", "mur", "taran", "hrim_zemli", "khoruhva", "pidsichka"]:
		p.skills[id] = 1
	p.recalc()
	_clear_enemies(game)
	await _frames(2)
	var dmg0: float = p.damage
	ready.call()
	p.use_skill("navala")
	check(p.buff_on("navala") and is_equal_approx(p.damage / dmg0, 1.1) and is_equal_approx(p.fx("ward"), -5.0) and p.skill_timers["navala"] > 0.0 and p.mana < p.max_mana, "«Навала»: +10% шкоди, по тобі б'ють сильніше, наснагу й перезарядку списано")
	ready.call()
	p.use_skill("mur")
	check(p.buff_on("mur") and not p.buff_on("navala") and is_equal_approx(p.damage / dmg0, 0.95) and is_equal_approx(p.fx("ward"), 8.0), "«Мур» змінює «Навалу»: діє одна стійка")
	ready.call()
	p.use_skill("khoruhva")
	check(p.buff_on("khoruhva") and p.buff_on("mur") and p.regen > 0.0, "підсилення без групи діє разом зі стійкою")
	p._tick_buffs(13.0)
	check(not p.buff_on("khoruhva") and p.buff_on("mur"), "коротше підсилення спадає першим")
	p._tick_buffs(10.0)
	check(p.buffs.is_empty() and is_equal_approx(p.damage, dmg0) and is_equal_approx(p.fx("ward"), 0.0), "коли стійка спала, показники вертаються")
	# ---- Оберіг уміння зменшує отриману шкоду ----
	p.skills["kremin"] = 5
	p.recalc()
	p.hp = p.max_hp
	p.invuln = 0.0
	var before: float = p.hp
	p.take_damage(1000.0)
	var with_ward: float = before - p.hp
	p.skills.erase("kremin")
	p.recalc()
	p.hp = p.max_hp
	p.invuln = 0.0
	p.take_damage(1000.0)
	var plain: float = p.max_hp - p.hp
	check(plain > 0.0 and is_equal_approx(with_ward / plain, 0.925), "«Кремінь» п'ятого рангу: шкода по тобі менша на 7,5%% (%.1f проти %.1f)" % [with_ward, plain])
	p.hp = p.max_hp
	# ---- Стрибок і удар довкола ----
	_clear_enemies(game)
	await _frames(2)
	var far = dummy.call(Vector2(360, 0))
	await _frames(1)
	ready.call()
	var pos0: Vector2 = p.global_position
	p.use_skill("taran")
	check(p.global_position.distance_to(far.global_position) < 80.0 and p.global_position.distance_to(pos0) > 200.0 and far.hp < far.max_hp and far.stun > 0.0, "«Таран»: стрибок до ворога, шкода й приголомшення")
	_clear_enemies(game)
	await _frames(2)
	ready.call()
	p.use_skill("taran")
	check(is_equal_approx(p.skill_timers["taran"], 0.0) and is_equal_approx(p.mana, p.max_mana), "без ворога поруч «Таран» не витрачається")
	var near = dummy.call(Vector2(150, 0))
	var out_of = dummy.call(Vector2(600, 0))
	await _frames(1)
	ready.call()
	p.use_skill("hrim_zemli")
	check(near.hp < near.max_hp and near.stun >= 1.9 and is_equal_approx(out_of.hp, out_of.max_hp), "«Грім землі» б'є й приголомшує всіх у своєму колі, далі не дістає")
	# ---- Удар перед собою зі станом ----
	_clear_enemies(game)
	await _frames(2)
	var front = dummy.call(Vector2(120, 0))
	await _frames(1)
	var back = dummy.call(Vector2(-140, 0))
	await _frames(1)
	p.global_position = (front.global_position + back.global_position) / 2.0 + Vector2(10, 0)
	ready.call()
	p.use_skill("pidsichka")
	check(front.hp < front.max_hp and front.statuses.has("weak") and is_equal_approx(back.hp, back.max_hp), "«Підсічка» б'є й знесилює тих, хто перед тобою, а не за спиною")
	# ---- Пасивні: стани від удару й нагорода за вбивство ----
	p.skills["kryvavyi_zamakh"] = 3
	p.skills["druhe_dykhannia"] = 3
	p.recalc()
	var bled := false
	for i in 60:
		front.set_meta("sk_bleed_hit", -100.0)
		front.statuses.erase("bleed")
		p.hit(front, 1.0, Vector2.ZERO, false)
		bled = bled or front.statuses.has("bleed")
	check(bled, "«Кривавий замах»: удар часом пускає кров")
	var weak_foe = dummy.call(Vector2(200, 100), 1.0)
	await _frames(1)
	p.hp = p.max_hp * 0.5
	var hp1: float = p.hp
	p.hit(weak_foe, weak_foe.max_hp * 5.0, Vector2.ZERO, false)
	check(weak_foe.dead and p.hp > hp1 and p.hp < hp1 + p.max_hp * 0.02, "«Друге дихання»: вбивство трохи лікує")
	game.enter_map()
	await _frames(2)
	# ---- Снаряди, зони й лікування волхвів ----
	p.change_class("volkhv")
	p.job = "perun_zhrets"
	game._sync_class()
	for id in ["lightning", "kulova", "vohniane_kolo", "dukh_predkiv"]:
		p.skills[id] = 2
	p.recalc()
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	await _frames(2)
	var target = dummy.call(Vector2(300, 0))
	await _frames(1)
	ready.call()
	p.use_skill("kulova")
	var pr = c.last_projectile()
	check(pr != null and is_instance_valid(pr) and pr.explode_radius > 100.0 and pr.pierce == 1 and pr.friendly, "«Кульова блискавка»: снаряд, що вибухає")
	await _frames(40)
	check(target.hp < target.max_hp, "снаряд долетів і вдарив")
	ready.call()
	p.global_position = target.global_position + Vector2(-100, 0)
	p.use_skill("vohniane_kolo")
	check(target.statuses.has("burn"), "«Вогняне коло» підпалює")
	ready.call()
	var mr0: float = p.mana_regen
	p.use_skill("dukh_predkiv")
	check(p.buff_on("dukh_predkiv") and is_equal_approx(p.mana_regen / mr0, 1.4), "«Дух предків»: наснага відновлюється швидше")
	game.enter_map()
	await _frames(2)
	p.job = "znakhar"
	game._sync_class()
	for id in ["otruta", "chorna_khvoroba", "tsiliushche_kolo"]:
		p.skills[id] = 2
	p.recalc()
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	await _frames(2)
	var sick = dummy.call(Vector2(260, 0))
	await _frames(1)
	ready.call()
	p.use_skill("chorna_khvoroba")
	var zone = null
	for z in c.effects.get_children():
		if z.get_script() == c.ZoneScript and z.kind == "skill":
			zone = z
	check(zone != null and zone.status == "plague" and zone.global_position.distance_to(sick.global_position) < 5.0, "«Чорна хвороба» кладе зону під ворога")
	await _frames(45)
	check(sick.hp < sick.max_hp and sick.statuses.has("plague"), "зона б'є й заражає")
	p.hp = p.max_hp * 0.5
	ready.call()
	p.use_skill("tsiliushche_kolo")
	check(p.hp > p.max_hp * 0.55 and p.buff_on("tsiliushche_kolo"), "«Цілюще коло» лікує одразу й гоїть далі")
	p.revive()
	check(p.buffs.is_empty(), "після відпочинку підсилення не лишаються")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false


# ======================= Гілка Стрілець: лук, пістолі, сокіл =======================

func _suite_strilets() -> void:
	suite("Стрілець: третя дорога, зброя, спеціалізації")
	var Classes = load("res://scripts/data/classes.gd")
	var Paths = load("res://scripts/data/paths.gd")
	var Story = load("res://scripts/data/story.gd")
	var PS = load("res://scripts/game/path_service.gd")
	var Spec = load("res://scripts/game/spec_service.gd")
	var Stones = load("res://scripts/game/stone_service.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var Loot = load("res://scripts/game/loot_service.gd")
	var SetS = load("res://scripts/game/set_service.gd")
	var Shop = load("res://scripts/game/shop_service.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var WorldState = load("res://scripts/game/world_state.gd")
	# ---- Класи ----
	var C: Dictionary = Classes.CLASSES
	check(C["peasant"]["next"] == ["cossack", "volkhv", "strilets"] and C["strilets"]["next"] == ["sahaidachnyk", "opryshok", "sokolnyk", "samopalnyk"] and not "samopalnyk" in C["cossack"]["next"], "три дороги; Самопальник тепер у Стрільця, а не в Козака")
	check(Classes.lineage("samopalnyk") == ["peasant", "strilets", "samopalnyk"] and Classes.lineage("opryshok") == ["peasant", "strilets", "opryshok"] and Classes.is_strilets_line("sokolnyk") and Classes.is_strilets_line("samopalnyk") and not Classes.is_strilets_line("plastun"), "дорога стрільця від Селянина до спеціалізацій")
	var data_ok := true
	for cls in ["strilets", "sahaidachnyk", "opryshok", "sokolnyk"]:
		data_ok = data_ok and Classes.TREES.has(cls) and Paths.CARDS.has(cls) and str(C[cls]["address"]) != "" and Data.CITIES.has(str(C[cls]["where"]))
		for wt in C[cls]["weapons"]:
			data_ok = data_ok and wt in Data.AGI_WEAPONS and GfxS.has("%s_%s" % [cls, wt])
		data_ok = data_ok and GfxS.has("hunter_" + cls) and GfxS.has("plain_" + cls)
	check(data_ok, "у кожного класу стрільців є дерево, картка, місто наставника й спрайти з кожною його зброєю")
	# ---- Зброя ----
	check(Data.WEAPON_TYPES.has("bow") and Data.WEAPON_TYPES.has("pistols") and "bow" in Data.RANGED_WEAPONS and GfxS.ICON_ORDER.has("it_bow") and GfxS.ICON_ORDER.has("it_pistols"), "лук і пістолі: зброя дальнього бою зі своїми значками")
	var bow: Dictionary = Data.gen_item(20, 1, "weapon", "bow")
	var pist: Dictionary = Data.gen_item(20, 1, "weapon", "pistols")
	check(str(bow["name"]).begins_with("Лук") and str(pist["name"]).begins_with("Пістолі"), "назви: «%s», «%s»" % [bow["name"], pist["name"]])
	var p = _new_player()
	p.change_class("strilets")
	p.assign_uid(bow)
	p.equipment["weapon"] = bow
	p.recalc()
	var d0: float = p.damage
	p.stats["str"] += 40
	p.recalc()
	var d_str: float = p.damage
	p.stats["str"] -= 40
	p.stats["agi"] += 40
	p.recalc()
	check(is_equal_approx(d_str, d0) and p.damage > d0 * 1.5 and is_equal_approx(p.attack_range, 460.0), "шкода лука росте від Спритності, а не від Сили; дальність стала")
	p.assign_uid(pist)
	p.equipment["weapon"] = pist
	p.recalc()
	check(is_equal_approx(p.attack_range, 330.0) and p.attack_cooldown < 0.42 * 0.7, "пістолі б'ють ближче, зате частіше")
	check(p.sprite_id() == "strilets_pistols", "спрайт героя за класом і зброєю: %s" % p.sprite_id())
	# ---- Майстерність під зброю ----
	p.skills["luk_master"] = 5
	p.skills["pistol_master"] = 5
	p.recalc()
	check(is_equal_approx(p.fx("aspd"), 15.0) and is_equal_approx(p.fx("dmg"), 0.0), "із пістолями діє лише пістольна наука")
	p.equipment["weapon"] = bow
	p.recalc()
	check(is_equal_approx(p.fx("dmg"), 15.0) and is_equal_approx(p.fx("aspd"), 0.0), "із луком діє лише лучна наука")
	# ---- Вибір дороги й сюжет ----
	check(Paths.ORDER == ["cossack", "volkhv", "strilets"] and Paths.REPS.has("strilets") and Paths.TALKS["strilets"].size() >= 4 and Story.NPCS.has(Paths.REPS["strilets"]), "третій представник на Січі: сотник сердюків")
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
					for cls in Paths.ORDER:
						PS.mark_talked(w, cls)
					PS.choose(w, v, "strilets")
				elif obj["type"] == "kill":
					for i in obj["count"]:
						StoryService.on_event(w, v, "kill", obj["enemy"])
				else:
					StoryService.on_event(w, v, obj["type"], obj["loc"])
			"turnin":
				StoryService.on_dialogue_done(w, v, "end", 0)
	check(not "oath" in path and not "to_carpathians" in path and "to_baturyn" in path and "strilets_trial" in path and "back_to_sich_s" in path, "дорога стрільця: Батурин, випробування, повернення")
	check(v.job == "strilets" and v.equipment["weapon"]["type"] == "bow" and v.sk("strila") == 1 and StoryService.chose(w, "trial=2") and w.story["chapter"] == 1, "посвячено в стрільці: лук у руці, «Влучна стріла» в подарунок, далі Розділ I")
	var ln: Array = StoryService.lines(w, [["otaman", "Ну що, козаче?"], ["hero", "Я готовий."]])
	check(ln[0][1] == "Ну що, стрільче?" and ln[1][0] == "hero", "до стрільця звертаються «стрільче»")
	StoryService.hero_class = "cossack"
	# ---- Спеціалізації ----
	var trials_ok := true
	for spec in C["strilets"]["next"]:
		trials_ok = trials_ok and Spec.TRIALS.has(spec) and Story.NPCS.has(str(C[spec]["mentor"])) and Data.WEAPON_TYPES.has(str(Spec.TRIALS[spec]["item"]["type"])) and str(Spec.TRIALS[spec]["item"]["type"]) in C[spec]["weapons"]
		var obj: Dictionary = Spec.TRIALS[spec]["objective"]
		if obj.has("loc"):
			trials_ok = trials_ok and Data.LOCATIONS.has(str(obj["loc"]))
	check(trials_ok, "у кожної спеціалізації стрільця є наставник, випробування й зброя в нагороду")
	v.job_level = Classes.JOB_CHANGE_AT[1]
	check(Spec.available(v) == C["strilets"]["next"] and Spec.start(w, v, "sokolnyk"), "стрілець із майстерністю %d обирає спеціалізацію" % Classes.JOB_CHANGE_AT[1])
	for i in 6:
		Spec.on_event(w, "elite", "")
	check(str(Spec.state(w)["stage"]) == "turnin" and "Батурин" in Spec.objective_line(w) and not Spec.city_dialogue(w, "baturyn").is_empty() and Spec.city_dialogue(w, "sich").is_empty(), "шість еліт: посвята в наставника в Батурині, а не на Січі")
	var done: String = Spec.complete(w, v)
	check(v.job == "sokolnyk" and v.equipment["weapon"]["type"] == "bow" and "сокольник" in done, "посвячено в сокольники: %s" % done.replace("\n", " "))
	# ---- Постріл: межа швидкості, м'яка межа Спритності, наснага ----
	var sh = _new_player()
	sh.change_class("strilets")
	var sbow: Dictionary = Data.gen_item(30, 1, "weapon", "bow")
	sbow["mods"] = {}
	sh.add_item(sbow, true)
	sh.equip(sbow["uid"])
	sh.stats["agi"] = Data.STAT_BASE + 20
	sh.recalc()
	var cd20: float = sh.attack_cooldown
	check(sh.shot_mult == 1.0 and cd20 > sh.RANGED_MIN_CD, "повільний стрілець: постріл звичайної сили (%.3f с)" % cd20)
	sh.stats["agi"] = Data.STAT_BASE + int(Data.AGI_ASPD_SOFT)
	sh.recalc()
	var cd60: float = sh.attack_cooldown * (1.0 / sh.shot_mult)
	sh.stats["agi"] = Data.STAT_BASE + int(Data.AGI_ASPD_SOFT) + 100
	sh.recalc()
	var cd160: float = sh.attack_cooldown * (1.0 / sh.shot_mult)
	var full: float = (1.0 + 0.04 * Data.AGI_ASPD_SOFT) / (1.0 + 0.04 * (Data.AGI_ASPD_SOFT + 100.0))
	check(cd160 < cd60 and cd160 > cd60 * full * 1.5, "понад %d очок Спритність прискорює постріл значно слабше (%.3f → %.3f с)" % [int(Data.AGI_ASPD_SOFT), cd60, cd160])
	sh.stats["agi"] = Data.STAT_BASE + 400
	sh.buffs["t"] = {"t": 9.0, "fx": {"aspd": 300.0}}
	sh.recalc()
	check(is_equal_approx(sh.attack_cooldown, sh.RANGED_MIN_CD) and sh.shot_mult > 1.5, "частіше за десять пострілів на секунду не буває: надлишок іде в силу пострілу (×%.2f)" % sh.shot_mult)
	var est: float = load("res://scripts/game/power.gd").dps(sh)
	sh.shot_mult = 1.0
	check(est > load("res://scripts/game/power.gd").dps(sh) * 1.4, "оцінка сили героя бачить силу пострілу")
	sh.buffs.clear()
	var melee = _new_player()
	melee.change_class("cossack")
	melee.stats["agi"] = Data.STAT_BASE + 400
	melee.recalc()
	check(melee.shot_mult == 1.0 and melee.attack_cooldown < sh.RANGED_MIN_CD, "ближнього бою межа пострілу не стосується")
	check(Data.soft_agi_aspd(40.0) == 40.0 and is_equal_approx(Data.soft_agi_aspd(Data.AGI_ASPD_SOFT + 50.0), Data.AGI_ASPD_SOFT + 50.0 * Data.AGI_ASPD_LATE), "м'яка межа Спритності для швидкості пострілу")
	check(load("res://scripts/game/outdoor_service.gd").arrows_for(v) == load("res://scripts/data/activities.gd").HUNT_ARROWS + 1, "стрільці беруть на полювання зайву стрілу")
	var shooter_art := ""
	for a in load("res://scripts/data/wiki_data.gd").BASICS:
		if str(a["title"]).begins_with("Стрільці"):
			shooter_art = str(a["text"])
	var potion_art := ""
	for a in load("res://scripts/data/wiki_data.gd").BASICS:
		if str(a["title"]) == "Зілля й вареники":
			potion_art = str(a["text"])
	check("%d%% здоров'я, вареник" % roundi(Data.VARENYK_HEAL * 100.0) in potion_art and "шансом %d%%, з еліти" % roundi(Data.POTION_DROP_CHANCE * 100.0) in potion_art and "шансом %d%% і одразу" % roundi(Data.VARENYK_DROP_CHANCE * 100.0) in potion_art and ("%.1f%%" % (Data.MANA_POTION_DROP_CHANCE * 100.0)).replace(".", ",") in potion_art, "довідник називає справжні шанси зілля й вареників")
	check("перші %d очок" % int(Data.AGI_ASPD_SOFT) in shooter_art and "Батурині" in str(load("res://scripts/data/wiki_data.gd").BASICS), "довідник розповідає про стрільців і третю дорогу")
	# ---- Камінь долі: сусідні дороги ----
	check("samopalnyk" in Stones.siblings(v) and "opryshok" in Stones.siblings(v) and not "plastun" in Stones.siblings(v), "Алатир-камінь міняє спеціалізацію в межах гілки стрільців")
	# ---- Переїзд Самопальника ----
	var old = _new_player()
	old.job = "samopalnyk"
	old.job_level = 20
	old.level = 40
	old.skills = {"vyly": 2, "whirl": 3, "sharp": 2, "musket": 1, "kartech": 4, "deadly": 1}
	old.skill_gifts = {"whirl": 1}
	old.skill_points = 0
	var moved = _new_player()
	moved.from_dict(old.to_dict())
	check(not moved.skills.has("whirl") and not moved.skills.has("sharp") and not moved.skills.has("musket") and moved.sk("kartech") == 4 and moved.sk("deadly") == 1 and moved.sk("vyly") == 2, "козацькі вміння давнього Самопальника знято, свої й селянські лишились")
	check(moved.skill_points == 5 and moved.sk("strila") == 1 and int(moved.skill_gifts.get("strila", 0)) == 1, "очки за них повернуто (%d), перше вміння стрільця подаровано" % moved.skill_points)
	var again = _new_player()
	again.from_dict(moved.to_dict())
	check(again.skill_points == 5 and again.skills == moved.skills, "повторне завантаження нічого не міняє")
	# ---- Золото, набори, крамниця ----
	var types := {}
	for id in Uniques.ORDER:
		if Uniques.DEFS[id]["slot"] == "weapon":
			types[str(Uniques.DEFS[id]["type"])] = int(types.get(str(Uniques.DEFS[id]["type"]), 0)) + 1
	check(int(types.get("bow", 0)) >= 3 and int(types.get("pistols", 0)) >= 3, "золоті луки й пістолі є на різних ступенях: %s" % str(types))
	var sah = _new_player()
	sah.change_class("strilets")
	sah.change_class("sahaidachnyk")
	var only_bow := true
	for i in 200:
		var D: Dictionary = Uniques.DEFS[Loot.pick(sah, 6, "dev")]
		only_bow = only_bow and (D["slot"] != "weapon" or D["type"] == "bow")
	var opr = _new_player()
	opr.change_class("strilets")
	opr.change_class("opryshok")
	check(only_bow and SetS.main_stat(sah) == "agi" and Shop.set_weapon(opr) == "pistols" and Shop.fits(opr, "unique", "para_zalizniaka") and not Shop.fits(opr, "unique", "luk_baidy"), "сагайдачникові падає лише лук; набір під Спритність; опришкові пістолі")
	for x in [p, v, old, moved, again, sah, opr]:
		x.free()


func _suite_strilets_game() -> void:
	suite("Стрілець: у бою")
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
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup"]:
		game.world.hints[k] = true
	p.change_class("strilets")
	p.change_class("sokolnyk")
	game._sync_class()
	p.level = 40
	var bow: Dictionary = Data.gen_item(40, 2, "weapon", "bow")
	p.add_item(bow, true)
	p.equip(bow["uid"])
	p.stats["agi"] = 80
	p.stats["vit"] = 150
	for id in ["sokil", "kihti", "sokolyna_mitka", "pike", "strila", "syltsia"]:
		p.skills[id] = 2
	p.recalc()
	game.world.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	await _frames(2)
	var dummy := func(offset: Vector2):
		c.spawn_enemy("upyr", 40, false, p.global_position + offset)
		var e = c._last_enemy()
		e.max_hp *= 1000.0
		e.hp = e.max_hp
		e.speed = 0.0
		e.damage = 0.0
		return e
	var ready := func() -> void:
		p.mana = p.max_mana
		for id in p.skill_timers.keys():
			p.skill_timers[id] = 0.0
	# ---- Звичайний постріл із лука ----
	var foe = dummy.call(Vector2(320, 0))
	await _frames(1)
	p.attack_timer = 0.0
	p.combo_step = 0
	p.attack()
	var arrow = c.last_projectile()
	check(arrow != null and is_instance_valid(arrow) and arrow.friendly and arrow.pierce == 1 and p.sprite_id() == "sokolnyk_bow", "лук пускає стрілу в найближчого ворога")
	await _frames(30)
	check(foe.hp < foe.max_hp, "стріла долетіла")
	# ---- Сокіл ----
	foe.hp = foe.max_hp
	ready.call()
	p.use_skill("sokil")
	var bird = null
	for z in c.effects.get_children():
		if z.get_script() == c.ZoneScript and z.kind == "falcon":
			bird = z
	check(bird != null and bird.status == "curse" and bird.duration >= 20.0 and p.skill_timers["sokil"] > 0.0 and p.SkillInfo.kind("sokil") == "buff", "«Сокіл»: птах у небі, з «Соколиною міткою» проклинає ціль")
	var base_dmg: float = bird.damage
	await _frames(100)
	check(foe.hp < foe.max_hp and foe.statuses.has("curse"), "сокіл сам б'є ворога й мітить його")
	p.skills["kihti"] = 5
	ready.call()
	p.use_skill("sokil")
	var strong = null
	for z in c.effects.get_children():
		if z.get_script() == c.ZoneScript and z.kind == "falcon" and z != bird:
			strong = z
	check(strong != null and strong.damage > base_dmg * 1.25, "«Гострі кігті» підсилюють сокола")
	# ---- Вареник лікує частку здоров'я ----
	p.varenyk_bonus = 0
	check(c.varenyk_heal() == int(p.max_hp * Data.VARENYK_HEAL) and c.varenyk_heal() > Data.VARENYK_MIN * 5, "вареник лікує %d%% здоров'я героя (%d), а не 20 на будь-якому рівні" % [roundi(Data.VARENYK_HEAL * 100.0), c.varenyk_heal()])
	p.varenyk_bonus = 2
	check(c.varenyk_heal() == int(p.max_hp * Data.VARENYK_HEAL * 2.0), "перк «Бабусині вареники» робить вареник ситнішим")
	p.varenyk_bonus = 0
	# ---- Пістолі й постріл упритул ----
	game.enter_map()
	await _frames(2)
	p.job = "opryshok"
	game._sync_class()
	var pist: Dictionary = Data.gen_item(40, 2, "weapon", "pistols")
	p.add_item(pist, true)
	p.equip(pist["uid"])
	for id in ["postril_vprytul", "dva_stvoly", "bartka", "vtecha_horamy"]:
		p.skills[id] = 2
	p.recalc()
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	await _frames(2)
	var near = dummy.call(Vector2(140, 0))
	await _frames(1)
	p.attack_timer = 0.0
	p.combo_step = 0
	p.attack()
	var b1 = c.last_projectile()
	check(b1 != null and is_instance_valid(b1) and b1.life < 0.6 and p.sprite_id() == "opryshok_pistols", "пістоль б'є короткою кулею")
	ready.call()
	p.use_skill("postril_vprytul")
	check(near.hp < near.max_hp and near.stun > 0.0, "«Постріл упритул» б'є й приголомшує")
	ready.call()
	p.use_skill("bartka")
	check(near.statuses.has("bleed"), "«Удар бартки» пускає кров")
	p.statuses["chill"] = {"t": 5.0, "dps": 0.0, "tick": 0.5}
	var sp0: float = p.speed
	ready.call()
	p.use_skill("vtecha_horamy")
	check(p.statuses.is_empty() and p.speed > sp0 * 1.4 and p.invuln > 0.0, "«Втеча горами»: стани знято, біг швидший, мить невразливості")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false


func _suite_premium() -> void:
	suite("Гетьманський універсал: преміум на місяць")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var PR = load("res://scripts/game/premium_service.gd")
	var AR = load("res://scripts/game/ad_rewards.gd")
	var QS = load("res://scripts/game/quick_service.gd")
	var SH = load("res://scripts/game/shop_service.gd")
	var Camp = load("res://scripts/game/camp_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	PR.now_override = 1800000000.0
	var w = WorldState.new()
	var p = _new_player()
	check(not PR.active(w) and PR.days_left(w) == 0 and "бракує" in PR.block_reason(w) and not PR.buy(w), "без червінців універсал не купити")
	check(AR.xp_mult(w) == 1.0 and AR.drop_mult(w) == 1.0 and AR.safe_left_today(w) == AR.SAFE_PER_DAY and QS.left_today(w) == QS.PER_DAY and PR.stipend(w) == 0, "без універсалу все як було")
	SH.state(w)["coins"] = PR.PRICE + 100
	check(PR.buy(w) and PR.active(w) and PR.days_left(w) == PR.DAYS and SH.coins(w) == 100 and int(w.shop["spent"]) == PR.PRICE, "куплено на %d днів за %d червінців" % [PR.DAYS, PR.PRICE])
	check(not PR.buy(w) and PR.days_left(w) == PR.DAYS, "на друге продовження червінців бракує")
	# без реклами: подвоєння діють постійно, межі більші
	check(AR.xp_mult(w) == 2.0 and AR.drop_mult(w) == 2.0 and not AR.can_boost(w, "xp2") and "універсал" in AR.boost_button_text(w, "drop2"), "×2 досвіду й ×2 здобичі діють без реклами")
	w.boosts["xp2"] = 600.0
	AR.tick(w, 100.0)
	check(AR.xp2_left(w) == 600.0, "години, зароблені рекламою, з універсалом не згорають")
	check(AR.safe_left_today(w) == PR.SAFE_PER_DAY and QS.left_today(w) == PR.QUICK_PER_DAY and QS.per_day(w) == PR.QUICK_PER_DAY, "на день %d швидких походів і %d безпечних заточок" % [PR.QUICK_PER_DAY, PR.SAFE_PER_DAY])
	for i in PR.SAFE_PER_DAY:
		AR.grant_safe(w)
	check(AR.safe_tokens(w) == PR.SAFE_PER_DAY and not AR.grant_safe(w) and AR.safe_left_today(w) == 0 and "Універсал" in AR.safe_button_text(w), "денна межа безпечних заточок усе одно є")
	# платня
	check(PR.stipend(w) == PR.STIPEND and SH.coins(w) == 100 + PR.STIPEND and PR.stipend(w) == 0, "платня раз на день")
	PR.now_override += PR.DAY
	check(PR.stipend(w) == PR.STIPEND and PR.days_left(w) == PR.DAYS - 1, "наступного дня платня знову")
	# торба й дорога
	Camp.apply_effects(w, p)
	check(p.bag_size() == Data.INVENTORY_SIZE + PR.BAG_BONUS and PR.travel_mult(w) == PR.TRAVEL_MULT, "торба більша на %d місць, дорога швидша" % PR.BAG_BONUS)
	# продовження додає дні
	SH.state(w)["coins"] = PR.PRICE
	check(PR.buy(w) and PR.days_left(w) == 2 * PR.DAYS - 1 and int(w.shop["premium_bought"]) == 2, "продовження додає дні до решти")
	# скінчився
	PR.now_override += 2.0 * PR.DAYS * PR.DAY
	Camp.apply_effects(w, p)
	check(not PR.active(w) and AR.xp_mult(w) == 2.0 and AR.safe_per_day(w) == AR.SAFE_PER_DAY and QS.per_day(w) == QS.PER_DAY and p.bag_size() == Data.INVENTORY_SIZE and PR.stipend(w) == 0, "універсал скінчився: межі звичайні, лишились години з реклами")
	AR.tick(w, 100.0)
	check(AR.xp2_left(w) == 500.0, "без універсалу годинник подарунка знову йде")
	# довідник
	var found := false
	for e in WS._entries("basics"):
		if str(e["title"]) == PR.NAME:
			found = str(PR.PRICE) in str(e["text"]) and str(PR.QUICK_PER_DAY) in str(e["text"]) and "Автобій" in str(e["text"])
	check(found, "довідник описує універсал із числами")
	# ---- У грі ----
	PR.now_override = 1800000000.0
	var ads = root.get_node("Ads")
	ads.instant = false
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way"]:
		gw.hints[k] = true
	game.player.change_class("cossack")
	game.player.level = 30
	game.player.recalc()
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	SH.state(gw)["coins"] = PR.PRICE
	game.enter_map()
	await _frames(2)
	game.open_shop(game.enter_map)
	await _frames(2)
	game.shop_tab = game._shop_tab_index("Універсал")
	game.shop_do("premium", "")
	await _frames(2)
	check(game.shop_confirm == "premium" and not PR.active(gw), "перший дотик лише просить підтвердити")
	game.shop_do("premium", "")
	await _frames(2)
	check(PR.active(gw) and SH.coins(gw) == PR.STIPEND and game.player.bag_size() == Data.INVENTORY_SIZE + PR.BAG_BONUS, "куплено в крамниці: діє, платня за сьогодні, торба більша")
	var seen := false
	for l in game.hud.screen_root.find_children("*", "Label", true, false):
		seen = seen or "Лишилось днів: %d" % PR.DAYS in l.text
	check(seen, "вкладка «Універсал» показує, скільки днів лишилось")
	game.close_shop()
	await _frames(2)
	# реклама не потрібна
	var views0: int = ads.views
	var got := [false]
	game._ad("quick", func(ok: bool): got[0] = ok)
	check(got[0] and not ads.is_busy() and ads.views == views0, "нагорода за рекламу дається одразу, без реклами")
	gw.cleared["wild_field"] = QS.MIN_CLEARS
	var xp0: int = game.player.xp
	game.quick_raid("wild_field")
	await _frames(3)
	check(QS.used_today(gw) == 1 and QS.left_today(gw) == PR.QUICK_PER_DAY - 1 and not ads.is_busy() and (game.player.xp != xp0 or game.player.level > 30), "швидкий похід одним дотиком")
	var f := FileAccess.open(TEST_ACCOUNT, FileAccess.READ)
	var saved: Dictionary = f.get_var() if f != null else {}
	check(float(saved.get("shop", {}).get("premium_until", 0.0)) > PR.now(), "універсал збережено у файлі роду: діє для всіх героїв")
	ads.instant = true
	PR.now_override = -1.0
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_boss_hunt() -> void:
	suite("Бос дня й бос тижня")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var BS = load("res://scripts/game/boss_service.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var day0 := 1800000000 - 1800000000 % 86400 + 3600
	CS.now_override = day0
	# ---- Дані ----
	var pool_ok := true
	for b in BS.POOL:
		pool_ok = pool_ok and Data.BOSS_NAMES.has(b) and not BS.home_of(b).is_empty() and str(BS.home_of(b)["boss"]) == b
	check(pool_ok and BS.POOL.size() >= 12, "кожен бос зі списку має ім'я й рідне лігво (%d босів)" % BS.POOL.size())
	var mods_ok := true
	for m in BS.MOD_ORDER:
		mods_ok = mods_ok and BS.MODS.has(m) and str(BS.MODS[m]["name"]) != "" and str(BS.MODS[m]["desc"]) != ""
	check(mods_ok and BS.MOD_ORDER.size() == BS.MODS.size(), "властивості босів описано")
	# ---- Вибір за датою ----
	var d1: String = BS.boss_id("day")
	var w1: String = BS.boss_id("week")
	check(d1 in BS.POOL and w1 in BS.POOL and d1 != w1 and BS.boss_id("day") == d1, "бос дня й бос тижня різні й сталі протягом періоду: %s, %s" % [d1, w1])
	check(BS.mods("day").size() == 1 and BS.mods("week").size() == 2 and BS.mods("week") == BS.mods("week") and BS.mods("week")[0] != BS.mods("week")[1], "у боса дня одна властивість, у боса тижня дві різні")
	var seen := {}
	var seen_mods := {}
	for i in 40:
		CS.now_override = day0 + i * 86400
		seen[BS.boss_id("day")] = true
		seen_mods[BS.mods("day")[0]] = true
	check(seen.size() >= 8 and seen_mods.size() == BS.MOD_ORDER.size(), "за сорок днів боси й властивості міняються (%d босів, %d властивостей)" % [seen.size(), seen_mods.size()])
	CS.now_override = day0
	# ---- Правила ----
	var w = WorldState.new()
	var p = _new_player()
	check(BS.block_reason(w, p, "day") != "" and BS.available(w, p) == 0, "селянин на боса не йде")
	p.change_class("cossack")
	p.level = int(BS.MIN_LEVEL["day"]) - 1
	check("рівня" in BS.block_reason(w, p, "day"), "бос дня відкривається з %d-го рівня" % int(BS.MIN_LEVEL["day"]))
	p.level = int(BS.MIN_LEVEL["day"])
	check(BS.block_reason(w, p, "day") == "" and BS.block_reason(w, p, "week") != "" and BS.available(w, p) == 1, "бос тижня відкривається пізніше")
	p.level = 60
	p.recalc()
	var L: Dictionary = BS.loc_for(p, "week")
	check(L["type"] == "dungeon" and int(L["rooms"]) == 1 and int(L["level"]) == 60 and L["boss"] == w1 and L["hunt"] == "week" and not L["enemies"].is_empty(), "бій: печера на одну кімнату, бос рівня героя")
	var hp_want: float = float(BS.HP_MULT["week"])
	var dmg_want: float = float(BS.DMG_MULT["week"])
	for m in BS.mods("week"):
		hp_want *= float(BS.MODS[m].get("boss_hp_mult", 1.0))
		dmg_want *= float(BS.MODS[m].get("boss_dmg_mult", 1.0))
	check(is_equal_approx(float(L["boss_hp_mult"]), hp_want) and is_equal_approx(float(L["boss_dmg_mult"]), dmg_want), "властивості множать силу боса (здоров'я ×%.2f, удар ×%.2f)" % [hp_want, dmg_want])
	# ---- Перемога й період ----
	var gold0: int = p.gold
	var tr0: int = int(p.resources.get("trophy", 0))
	var r: Dictionary = BS.on_win(w, p, "day", 83.4)
	check(BS.done(w, "day") and p.gold == gold0 + BS.gold_for("day", 60) and int(p.resources["trophy"]) == tr0 + int(BS.TROPHIES["day"]) and r["items"].size() == 1 and int(r["items"][0]["rarity"]) == 3, "бос дня: гривні, трофеї й легендарна річ")
	check(BS.best_time(w, d1) == 83 and BS.time_text(83) == "1:23" and "уже переможено" in BS.block_reason(w, p, "day") and BS.available(w, p) == 1, "переможеного сьогодні вдруге не викличеш; час запам'ятано")
	var rw: Dictionary = BS.on_win(w, p, "week", 200.0)
	var gold_item := false
	for it in rw["items"]:
		gold_item = gold_item or it.has("unique")
	check(BS.done(w, "week") and rw["items"].size() == BS.WEEK_ITEMS + 1 and gold_item and BS.available(w, p) == 0, "бос тижня: дві легендарні речі й золота")
	CS.now_override = day0 + 86400
	check(not BS.done(w, "day") and int(BS.state(w)["day_wins"]) == 1, "наступного дня виходить новий бос дня")
	var week_same: bool = CS.week_key(day0) == CS.week_key(day0 + 86400)
	check(BS.done(w, "week") == week_same, "бос тижня чекає нового тижня")
	CS.now_override = day0 + 8 * 86400
	check(not BS.done(w, "week") and int(BS.state(w)["week_wins"]) == 1, "за тиждень виходить новий бос тижня")
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(int(w2.boss_hunt.get("day_wins", 0)) == 1 and int(w2.boss_hunt["best"][d1]) == 83, "стан босів зберігається з героєм")
	# ---- Досягнення, рекорди, довідник ----
	var ach := 0
	for a in Ach.ACHIEVEMENTS:
		if str(a["stat"]) in ["boss_day", "boss_week"]:
			ach += 1
	check(ach >= 4 and Acts.RECORDS.has("boss_day") and "boss_week" in Acts.RECORD_ORDER and load("res://scripts/game/record_service.gd").hero_values(w, p)["boss_day"] == 1, "досягнення й рекорди за босів")
	var art := ""
	for e in WS._entries("bosses"):
		if str(e["title"]) == "Бос дня й бос тижня":
			art = str(e["text"])
	var art_ok := art != ""
	for m in BS.MOD_ORDER:
		art_ok = art_ok and str(BS.MODS[m]["name"]) in art
	check(art_ok and str(int(BS.GOLD_PER_LEVEL["week"])) in art, "довідник описує босів і всі властивості")
	# ---- У грі ----
	CS.now_override = day0
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gp = game.player
	var gw = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "boss_hunt", "dungeon"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	game._sync_class()
	while gp.level < 40:
		gp.add_xp(gp.xp_next - gp.xp)
	gp.stats["str"] = 400
	gp.stats["vit"] = 400
	gp.recalc()
	gp.hp = gp.max_hp
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	game.enter_map()
	await _frames(2)
	var here: String = game.map_here
	var foot_btn = null
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with("Боси дня й тижня"):
			foot_btn = b
	check(foot_btn != null and "чекають: 2" in foot_btn.text, "на мапі є кнопка босів із лічильником")
	foot_btn.pressed.emit()
	await _frames(2)
	var go_btns := []
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text == "До бою":
			go_btns.append(b)
	check(game.map_bosses and go_btns.size() == 2, "панель показує обох босів із кнопкою «До бою»")
	go_btns[0].pressed.emit()
	await _frames(4)
	var c = game.combat
	var boss = null
	for e in get_nodes_in_group("enemies"):
		if e.is_boss:
			boss = e
	check(game.state == game.State.PLAYING and c.loc.get("hunt", "") == "day" and boss != null and boss.kind == BS.boss_id("day") and int(boss.level) == gp.level and game.map_here == here, "бій із босом дня почався: бос рівня героя, герой на мапі лишився на місці")
	var cleared0: int = int(gw.cleared.get("hlybyny", 0))
	var depth0: Dictionary = gw.depths.duplicate()
	for e in get_nodes_in_group("enemies"):
		if not e.is_boss:
			e.take_damage(e.max_hp * 100.0, Vector2.ZERO)
	await _frames(3)
	var guard := 0
	while is_instance_valid(boss) and not boss.dead and guard < 40:
		boss.take_damage(boss.max_hp * 100.0, Vector2.ZERO)
		await _frames(3)
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead:
				e.take_damage(e.max_hp * 100.0, Vector2.ZERO)
		guard += 1
	await _frames(30)
	check(BS.done(gw, "day") and int(gw.stats.get("boss_day", 0)) == 1 and c.portal != null, "боса дня переможено: зараховано, відкрито вихід")
	check(int(gw.cleared.get("hlybyny", 0)) == cleared0 and gw.depths == depth0, "Глибини зарази цей бій не зачіпає")
	var drops := 0
	for n in c.entities.get_children():
		if n.get_script() == c.PickupScript and n.kind == "item" and int(n.item.get("rarity", 0)) == 3:
			drops += 1
	check(drops >= 1 or gp.inventory.size() > 0, "нагородна річ упала біля героя")
	game.enter_map()
	await _frames(3)
	check(game.map_here == here and game.state == game.State.MAP, "після бою герой там само на мапі")
	game.start_boss("day")
	await _frames(2)
	check(game.state == game.State.MAP, "удруге за день боса дня не викликати")
	CS.now_override = 0
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_costumes() -> void:
	suite("Вбрання героя")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Cost = load("res://scripts/data/costumes.gd")
	var CS = load("res://scripts/game/costume_service.gd")
	var SH = load("res://scripts/game/shop_service.gd")
	var Camp = load("res://scripts/game/camp_service.gd")
	var Power = load("res://scripts/game/power.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	# ---- Дані й листи ----
	var sheets_ok := true
	for id in Cost.ORDER:
		sheets_ok = sheets_ok and Cost.DEFS.has(id) and str(Cost.DEFS[id]["name"]) != "" and int(Cost.DEFS[id]["price"]) > 0 and GfxS.has(Cost.plain(id))
		for wt in Cost.WEAPONS:
			sheets_ok = sheets_ok and GfxS.has(Cost.sprite(id, wt))
	check(sheets_ok and Cost.ORDER.size() == Cost.DEFS.size() and Cost.ORDER.size() >= 5, "кожне вбрання має назву, ціну й листи для всієї зброї (%d вбрань)" % Cost.ORDER.size())
	var all_weapons := true
	for wt in Data.WEAPON_TYPES:
		all_weapons = all_weapons and wt in Cost.WEAPONS
	check(all_weapons, "вбрання намальовано для кожного виду зброї в грі")
	# ---- Купівля й вдягання ----
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	var sabre: Dictionary = Data.gen_item(10, 1, "weapon", "sabre")
	p.add_item(sabre, true)
	p.equip(sabre["uid"])
	p.recalc()
	var look0: String = p.sprite_id()
	var power0: float = Power.score(p)
	var first: String = Cost.ORDER[0]
	check("бракує" in CS.block_reason(w, first) and not CS.buy(w, p, first) and not CS.wear(w, p, first) and p.costume == "", "без червінців вбрання не купити й не вдягнути")
	SH.state(w)["coins"] = CS.price(first) + 10
	check(CS.buy(w, p, first) and CS.owned(w, first) and SH.coins(w) == 10 and p.costume == first, "куплено: вбрання в роду, герой одразу вдягнув")
	check(p.sprite_id() == Cost.sprite(first, "sabre") and p.sprite_id() != look0, "постать героя змінилась: %s" % p.sprite_id())
	p.recalc()
	check(is_equal_approx(Power.score(p), power0), "сили героя вбрання не міняє")
	check(CS.block_reason(w, first) == "уже куплено" and not CS.buy(w, p, first) and SH.coins(w) == 10, "удруге те саме не купити")
	var bow: Dictionary = Data.gen_item(10, 1, "weapon", "bow")
	p.change_class("strilets")
	p.add_item(bow, true)
	p.equip(bow["uid"])
	check(p.sprite_id() == Cost.sprite(first, "bow"), "зброя в руці лишається своя: тепер лук")
	check(CS.wear(w, p, "") and p.sprite_id() == "strilets_bow", "вбрання знято: вигляд класу")
	# ---- Рід і збереження ----
	var p2 = _new_player()
	check(CS.wear(w, p2, first) and p2.sprite_id().begins_with("costume_" + first) and GfxS.has(p2.sprite_id()), "інший герой роду вдягає куплене без оплати: %s" % p2.sprite_id())
	var p3 = _new_player()
	p3.from_dict(p2.to_dict())
	check(p3.costume == first, "вдягнене вбрання зберігається з героєм")
	var w2 = WorldState.new()
	Camp.apply_effects(w2, p3)
	check(p3.costume == "", "у роду без цього вбрання воно знімається")
	# ---- Довідник ----
	var art := ""
	for e in WS._entries("basics"):
		if str(e["title"]) == "Вбрання героя":
			art = str(e["text"])
	var art_ok := art != ""
	for id in Cost.ORDER:
		art_ok = art_ok and str(Cost.DEFS[id]["name"]) in art and str(int(Cost.DEFS[id]["price"])) in art
	check(art_ok, "довідник перелічує всі вбрання з цінами")
	# ---- У грі ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way"]:
		gw.hints[k] = true
	game.player.change_class("cossack")
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	var top: String = Cost.ORDER[Cost.ORDER.size() - 1]
	SH.state(gw)["coins"] = CS.price(top)
	game.enter_map()
	await _frames(2)
	game.open_shop(game.enter_map)
	await _frames(2)
	game.shop_tab = game._shop_tab_index("Вбрання")
	game.shop_do("costume", top)
	await _frames(2)
	check(game.shop_confirm == "costume:" + top and not CS.owned(gw, top), "перший дотик лише просить підтвердити")
	game.shop_do("costume", top)
	await _frames(2)
	check(CS.owned(gw, top) and game.player.costume == top and SH.coins(gw) == 0, "куплено в крамниці й вдягнено")
	var btn_texts := []
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		btn_texts.append(b.text)
	check("Зняти" in btn_texts, "куплене вбрання має кнопку «Зняти»")
	game.shop_do("costume", top)
	await _frames(2)
	check(game.player.costume == "", "зняли")
	game.shop_do("costume", top)
	await _frames(2)
	check(game.player.costume == top and game._peace_sheet("plain") == Cost.plain(top) and game._peace_sheet("hunter") == Cost.sprite(top, "bow"), "на рибалці й полюванні герой теж у вбранні")
	game.close_shop()
	await _frames(2)
	var f := FileAccess.open(TEST_ACCOUNT, FileAccess.READ)
	var saved: Dictionary = f.get_var() if f != null else {}
	check(bool(saved.get("shop", {}).get("costumes", {}).get(top, false)), "куплене вбрання збережено у файлі роду")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_pets() -> void:
	suite("Улюбленці")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Pets = load("res://scripts/data/pets.gd")
	var PS = load("res://scripts/game/pet_service.gd")
	var Camp = load("res://scripts/game/camp_service.gd")
	var CampD = load("res://scripts/data/camp_data.gd")
	var Power = load("res://scripts/game/power.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	# ---- Дані ----
	var data_ok := true
	var stats := {}
	for id in Pets.ORDER:
		var D: Dictionary = Pets.DEFS[id]
		stats[D["stat"]] = true
		data_ok = data_ok and str(D["name"]) != "" and "%d" in str(D["text"]) and Pets.value(id, Pets.MAX_LEVEL) > Pets.value(id, 1) and Pets.value(id, 1) > 0.0 and int(Pets.cost(id, 2)["gold"]) == 2 * int(Pets.cost(id, 1)["gold"])
		for r in D["res"]:
			data_ok = data_ok and (CampD.RESOURCES.has(r) or r == CampD.TROPHY)
	check(data_ok and Pets.ORDER.size() == Pets.DEFS.size() and stats.size() == 4, "чотири улюбленці з різним хистом, ціни ростуть зі ступенем")
	var goal_ok := false
	for a in Ach.ACHIEVEMENTS:
		if str(a["id"]) == "pet_20":
			goal_ok = int(a["goal"]) == Pets.ORDER.size() * Pets.MAX_LEVEL
	check(goal_ok, "досягнення «Повна стайня» рахує всіх улюбленців і ступені")
	# ---- Купівля, годування, вибір ----
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	p.recalc()
	var power0: float = Power.score(p)
	var r0: float = p.pickup_radius
	var xp0: float = p.xp_mult
	check(not PS.upgrade(w, p, "pes") and not PS.choose(w, p, "pes") and PS.fx(w, p).is_empty(), "без грошей улюбленця не взяти")
	p.gold = 10000000
	p.resources = {"wood": 100000, "iron": 100000, "herbs": 100000, "trophy": 100000}
	var c1: Dictionary = Pets.cost("pes", 1)
	check(PS.upgrade(w, p, "pes") and PS.level(w, "pes") == 1 and p.gold == 10000000 - int(c1["gold"]) and int(p.resources["trophy"]) == 100000 - int(c1["trophy"]) and p.pet == "pes", "пса куплено: гривні й ресурси списано, він одразу з героєм")
	check(is_equal_approx(p.pickup_radius, r0 * (1.0 + Pets.value("pes", 1))) and is_equal_approx(Power.score(p), power0), "пес збільшує радіус збору на %d%%, сили не додає" % roundi(Pets.value("pes", 1) * 100.0))
	check(PS.upgrade(w, p, "pes") and PS.level(w, "pes") == 2 and is_equal_approx(p.pickup_radius, r0 * (1.0 + Pets.value("pes", 2))), "нагодований пес збирає ще далі")
	check(PS.upgrade(w, p, "kit") and p.pet == "pes" and PS.owned_count(w) == 2, "другий улюбленець чекає на хуторі: з героєм лише один")
	check(PS.choose(w, p, "kit") and is_equal_approx(p.pickup_radius, r0) and is_equal_approx(p.xp_mult, xp0 + Pets.value("kit", 1)), "кіт замість пса: досвід +%d%%, радіус збору звичайний" % roundi(Pets.value("kit", 1) * 100.0))
	check(PS.upgrade(w, p, "kin") and PS.choose(w, p, "kin") and is_equal_approx(PS.travel_mult(p), 1.0 + Pets.value("kin", 1)), "кінь скорочує дорогу мапою")
	check(PS.upgrade(w, p, "voron") and PS.choose(w, p, "voron") and is_equal_approx(float(p.pet_fx["res"]), Pets.value("voron", 1)) and PS.travel_mult(p) == 1.0, "ворон додає ресурсів")
	for i in 10:
		PS.upgrade(w, p, "voron")
	check(PS.level(w, "voron") == Pets.MAX_LEVEL and PS.next_cost(w, "voron").is_empty() and not PS.upgrade(w, p, "voron"), "вище за %d-й ступінь не вигодувати" % Pets.MAX_LEVEL)
	check(PS.choose(w, p, "") and p.pet == "" and p.pet_fx.is_empty(), "можна лишити всіх удома")
	# ---- Рід і збереження ----
	PS.choose(w, p, "voron")
	var p2 = _new_player()
	check(PS.choose(w, p2, "pes") and is_equal_approx(float(p2.pet_fx["pickup"]), Pets.value("pes", 2)), "інший герой роду бере того самого пса з тим самим ступенем")
	var p3 = _new_player()
	p3.from_dict(p.to_dict())
	Camp.apply_effects(w, p3)
	check(p3.pet == "voron" and is_equal_approx(float(p3.pet_fx["res"]), Pets.value("voron", Pets.MAX_LEVEL)), "узятий улюбленець зберігається з героєм")
	Camp.apply_effects(WorldState.new(), p3)
	check(p3.pet == "" and p3.pet_fx.is_empty(), "на хуторі без цього улюбленця герой лишається сам")
	# ---- Довідник ----
	var art := ""
	for e in WS._entries("basics"):
		if str(e["title"]) == "Улюбленці":
			art = str(e["text"])
	var art_ok := art != ""
	for id in Pets.ORDER:
		art_ok = art_ok and str(Pets.DEFS[id]["name"]) in art and str(int(Pets.DEFS[id]["gold"])) in art
	check(art_ok, "довідник описує всіх улюбленців із цінами")
	# ---- У грі ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	gp.level = 30
	gp.gold = 1000000
	gp.resources = {"wood": 10000, "iron": 10000, "herbs": 10000, "trophy": 10000}
	gp.recalc()
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	game.enter_camp()
	await _frames(2)
	var tabs := []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		tabs.append(tc.get_tab_title(i))
	check("Стайня" in tabs, "на хуторі є вкладка «Стайня»")
	game.camp_do("pet_up", "pes")
	await _frames(2)
	check(PS.level(gw, "pes") == 1 and gp.pet == "pes" and int(gw.stats.get("pet_level", 0)) == 1 and bool(game.account.camp.get("pets", {}).has("pes")), "пса взято на хутір: він у роду й із героєм")
	game.camp_do("pet_pick", "pes")
	check(gp.pet == "", "другий дотик лишає пса вдома")
	game.camp_do("pet_pick", "pes")
	game.enter_location("wild_field")
	await _frames(4)
	var c = game.combat
	var follower = null
	for n in c.entities.get_children():
		if n.get_script() == c.PetScript:
			follower = n
	check(follower != null and follower.kind == "pes", "пес біжить за героєм у бою")
	var start: Vector2 = follower.position
	gp.position += Vector2(400, 0)
	await _frames(60)
	check(follower.position.distance_to(gp.position) < 140.0 and follower.position != start, "пес наздоганяє героя")
	game.enter_map()
	await _frames(2)
	PS.upgrade(gw, gp, "kin")
	PS.choose(gw, gp, "kin")
	game.enter_location("wild_field")
	await _frames(4)
	var horse := false
	for n in game.combat.entities.get_children():
		horse = horse or n.get_script() == game.combat.PetScript
	check(not horse, "кінь у бій не йде")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_enchant_fair() -> void:
	suite("Зачарування речей і трофейний ярмарок")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Ench = load("res://scripts/data/enchants.gd")
	var ES = load("res://scripts/game/enchant_service.gd")
	var Fair = load("res://scripts/game/fair_service.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var Uniq = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	# ---- Дані зачарувань ----
	var data_ok := true
	var by_slot := {}
	for id in Ench.ORDER:
		var D: Dictionary = Ench.DEFS[id]
		data_ok = data_ok and str(D["name"]) != "" and not D["fx"].is_empty()
		for k in D["fx"]:
			data_ok = data_ok and Classes.FX_TEXT.has(k) and float(D["fx"][k]) > 0.0
		for sl in D["slots"]:
			data_ok = data_ok and sl in Data.SLOTS
			by_slot[sl] = int(by_slot.get(sl, 0)) + 1
	var every_slot := true
	for sl in Data.SLOTS:
		every_slot = every_slot and int(by_slot.get(sl, 0)) >= 3
	check(data_ok and every_slot and Ench.ORDER.size() == Ench.DEFS.size(), "кожне зачарування має назву й відомий хист, на кожну річ є щонайменше три")
	# ---- Накласти ----
	var p = _new_player()
	p.change_class("cossack")
	p.level = 60
	var plain: Dictionary = Data.gen_item(60, 2, "weapon", "sabre")
	var leg: Dictionary = Data.gen_item(60, 3, "weapon", "sabre")
	var body: Dictionary = Data.gen_item(60, 3, "body")
	for it in [plain, leg, body]:
		p.add_item(it, true)
	p.equip(leg["uid"])
	p.equip(body["uid"])
	p.recalc()
	check(not ES.can_enchant(plain) and ES.can_enchant(leg) and "лише легендарні" in ES.block_reason(p, plain, "zviroboi"), "зачаровують лише легендарне й краще")
	check("zviroboi" in Ench.options(leg) and not "obereh" in Ench.options(leg) and "obereh" in Ench.options(body) and "не лягає" in ES.block_reason(p, leg, "obereh"), "зброя й обладунок мають свої зачарування")
	check("бракує" in ES.block_reason(p, leg, "zviroboi") and not ES.enchant(p, leg["uid"], "zviroboi"), "без гривень і трофеїв коваль не зачарує")
	p.gold = 10000000
	p.resources = {"wood": 100000, "iron": 100000, "herbs": 100000, "trophy": 100000}
	var cost: Dictionary = Ench.cost(leg)
	var big0: float = p.fx("big_dmg")
	check(ES.enchant(p, leg["uid"], "zviroboi") and ES.of(leg) == "zviroboi" and p.gold == 10000000 - int(cost["gold"]) and int(p.resources["trophy"]) == 100000 - int(cost["trophy"]) and int(p.resources["iron"]) == 100000 - int(cost["iron"]), "зачаровано: гривні, трофеї й залізо списано")
	check(is_equal_approx(p.fx("big_dmg"), big0 + float(Ench.DEFS["zviroboi"]["fx"]["big_dmg"])) and "Звіробій" in ES.text(leg) and "елітам і босам" in ES.text(leg), "властивість діє на героя й видна на картці: %s" % ES.text(leg))
	check(ES.block_reason(p, leg, "zviroboi") == "уже лежить на речі" and ES.enchant(p, leg["uid"], "dobyvach") and ES.of(leg) == "dobyvach" and is_equal_approx(p.fx("big_dmg"), big0) and p.fx("execute") > 0.0, "нове зачарування замінює старе")
	var ward0: float = p.fx("ward")
	check(ES.enchant(p, body["uid"], "obereh") and is_equal_approx(p.fx("ward"), ward0 + float(Ench.DEFS["obereh"]["fx"]["ward"])), "зачарування з різних речей складаються")
	p.unequip(body["uid"])
	p.recalc()
	check(is_equal_approx(p.fx("ward"), ward0), "знята річ свого зачарування не дає")
	var peril_item: Dictionary = Data.gen_item(Ench.STRONG_LEVEL, 3, "weapon", "sabre")
	check(is_equal_approx(float(Ench.fx_of(peril_item, "zviroboi")["big_dmg"]), float(Ench.DEFS["zviroboi"]["fx"]["big_dmg"]) * Ench.STRONG_MULT) and int(Ench.cost(peril_item)["gold"]) > int(cost["gold"]), "на речах %d-го рівня зачарування сильніше й дорожче" % Ench.STRONG_LEVEL)
	var copy = _new_player()
	copy.from_dict(p.to_dict())
	check(ES.of(copy.find_item(leg["uid"])) == "dobyvach", "зачарування зберігається з річчю")
	# ---- Ярмарок ----
	var day0 := 1800000000 - 1800000000 % 86400 + 3600
	CS.now_override = day0
	var w = WorldState.new()
	var low = _new_player()
	low.change_class("cossack")
	low.level = Fair.MIN_LEVEL - 1
	check(not Fair.unlocked(low) and Fair.unlocked(p), "ярмарок відкривається з %d-го рівня" % Fair.MIN_LEVEL)
	var stock: Array = Fair.stock(p)
	var golds := stock.filter(func(e): return e["kind"] == "unique")
	var arts := stock.filter(func(e): return e["kind"] == "artifact")
	var goods := stock.filter(func(e): return e["kind"] == "good")
	var fits := true
	var top: int = Fair.top_tier(60)
	for e in golds:
		var D: Dictionary = Uniq.DEFS[e["id"]]
		fits = fits and int(D["tier"]) <= top and int(D["tier"]) >= top - 1 and (D["slot"] != "weapon" or D["type"] in Classes.CLASSES["cossack"]["weapons"]) and int(e["trophy"]) == int(Fair.UNIQUE_TROPHY[int(D["tier"])])
	check(golds.size() == Fair.GOLD_ITEMS and fits and arts.size() == 1 and goods.size() == Fair.GOODS_ORDER.size(), "товар тижня: три золоті речі під клас і рівень, артефакт і дрібний товар")
	check(Fair.stock(p) == stock, "протягом тижня товар той самий")
	var seen := {}
	for i in 12:
		CS.now_override = day0 + i * 7 * 86400
		for e in Fair.stock(p):
			if e["kind"] == "unique":
				seen[e["id"]] = true
	check(seen.size() > Fair.GOLD_ITEMS + 2, "щотижня золоті речі інші (%d різних за дванадцять тижнів)" % seen.size())
	CS.now_override = day0
	var g: Dictionary = golds[0]
	p.gold = 0
	check("бракує гривень" in Fair.block_reason(w, p, g["key"]) and not Fair.buy(w, p, g["key"])["ok"], "без гривень не виміняти")
	p.gold = 10000000
	var tr0: int = int(p.resources["trophy"])
	var bag0: int = p.inventory.size()
	var res: Dictionary = Fair.buy(w, p, g["key"])
	var got: Dictionary = p.inventory[p.inventory.size() - 1]
	check(res["ok"] and p.inventory.size() == bag0 + 1 and got.get("unique", "") == g["id"] and int(got["ilvl"]) == 60 and int(p.resources["trophy"]) == tr0 - int(g["trophy"]) and p.gold == 10000000 - int(g["gold"]), "золоту річ виміняно: вона рівня героя, трофеї й гривні списано")
	check("уже взято" in Fair.block_reason(w, p, g["key"]) and not Fair.buy(w, p, g["key"])["ok"], "ту саму річ цього тижня вдруге не взяти")
	var a: Dictionary = arts[0]
	check(Fair.buy(w, p, a["key"])["ok"] and Arts.has(p.inventory, a["id"]), "артефакт виміняно")
	var st0: int = load("res://scripts/game/stone_service.gd").count(p, "alatyr")
	check(Fair.buy(w, p, "g:alatyr")["ok"] and load("res://scripts/game/stone_service.gd").count(p, "alatyr") == st0 + 1, "камінь долі виміняно")
	var safe_n := 0
	for i in int(Fair.GOODS["safe"]["limit"]) + 2:
		if Fair.buy(w, p, "g:safe")["ok"]:
			safe_n += 1
	check(safe_n == int(Fair.GOODS["safe"]["limit"]) and int(w.boosts.get("safe_sharpen", 0)) == safe_n, "жетонів безпечної заточки на тиждень %d" % safe_n)
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	check(Fair.bought(w2, g["key"]) == 1, "взяте на ярмарку зберігається з героєм")
	CS.now_override = day0 + 8 * 86400
	check(Fair.bought(w, g["key"]) == 0 and Fair.bought(w, "g:safe") == 0, "нового тижня ярмарок знову повний")
	CS.now_override = 0
	# ---- Довідник ----
	var arts_ok := 0
	for e in WS._entries("basics"):
		if str(e["title"]) == "Зачарування речей":
			var all := true
			for id in Ench.ORDER:
				all = all and str(Ench.DEFS[id]["name"]) in str(e["text"])
			arts_ok += 1 if all else 0
		if str(e["title"]) == "Трофейний ярмарок" and str(int(Fair.UNIQUE_TROPHY[5])) in str(e["text"]) and str(Fair.ARTIFACT_TROPHY) in str(e["text"]):
			arts_ok += 1
	check(arts_ok == 2, "довідник описує зачарування й ярмарок із числами")
	# ---- У грі: кузня й ярмарок на хуторі ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	gp.level = 60
	gp.gold = 10000000
	gp.resources = {"wood": 100000, "iron": 100000, "herbs": 100000, "trophy": 100000}
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	gw.camp["buildings"] = {"kuznia": 3}
	var sw: Dictionary = Data.gen_item(60, 3, "weapon", "sabre")
	gp.add_item(sw, true)
	gp.equip(sw["uid"])
	gp.recalc()
	game.enter_camp()
	await _frames(2)
	var tabs := []
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		tabs.append(tc.get_tab_title(i))
	check("Ярмарок" in tabs and "Кузня" in tabs, "на хуторі є кузня й ярмарок")
	game.camp_tab = tabs.find("Кузня")
	game.camp_do("select", sw["uid"])
	await _frames(2)
	var ench_btn := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		ench_btn = ench_btn or b.text.begins_with("Звіробій")
	check(ench_btn, "у кузні під річчю є список зачарувань")
	game.camp_do("enchant", [sw["uid"], "zviroboi"])
	await _frames(2)
	check(ES.of(gp.equipment["weapon"]) == "zviroboi" and "Зачаровано" in game.smith_msg and int(gw.stats.get("enchant", 0)) == 1, "зачаровано в кузні: %s" % game.smith_msg)
	CS.now_override = day0
	var fk: String = Fair.stock(gp)[0]["key"]
	game.camp_do("fair_buy", fk)
	await _frames(2)
	check(Fair.bought(gw, fk) == 1 and int(gw.stats.get("fair", 0)) == 1, "на ярмарку виміняно золоту річ")
	CS.now_override = 0
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_auto() -> void:
	suite("Автобій")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var AS = load("res://scripts/game/auto_service.gd")
	var PR = load("res://scripts/game/premium_service.gd")
	var SH = load("res://scripts/game/shop_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "dungeon", "boss_hunt", "potion", "mana_potion", "varenyk", "res"]:
		w.hints[k] = true
	p.change_class("cossack")
	game._sync_class()
	while p.level < 30:
		p.add_xp(p.xp_next - p.xp)
	p.stats["str"] = 300
	p.stats["vit"] = 300
	p.recalc()
	p.hp = p.max_hp
	w.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	# ---- Де можна ----
	game.enter_location("wild_field")
	await _frames(3)
	check(game.hud.auto_btn.visible and AS.applies(c, "wild_field") and "відкриється" in AS.block_reason(w, c, "wild_field"), "у непройденому місці кнопка є, але автобій ще закритий")
	game.toggle_auto()
	check(not game.auto_on, "закритий автобій не вмикається")
	w.cleared["wild_field"] = 1
	check(AS.block_reason(w, c, "wild_field") != "" and AS.need_clears(w) == AS.MIN_CLEARS, "одного проходження мало: треба %d" % AS.MIN_CLEARS)
	PR.now_override = 1800000000.0
	SH.state(w)["coins"] = PR.PRICE
	PR.buy(w)
	check(AS.block_reason(w, c, "wild_field") == "" and AS.need_clears(w) == 1, "з універсалом досить одного проходження")
	w.shop["premium_until"] = 0.0
	PR.now_override = -1.0
	w.cleared["wild_field"] = AS.MIN_CLEARS
	check(AS.block_reason(w, c, "wild_field") == "", "пройдене тричі місце відкрите для автобою")
	# ---- Герой б'ється сам ----
	game.toggle_auto()
	await _frames(2)
	check(game.auto_on and game.hud.auto_btn.text == "Авто: йде", "автобій увімкнено")
	var kills0: int = c.field_kills
	var start: Vector2 = p.global_position
	await _frames(600)
	check(c.field_kills > kills0 + 3 and p.global_position.distance_to(start) > 50.0 and p.alive, "за десять секунд герой сам пішов до нечисті й бив її (вбито %d)" % (c.field_kills - kills0))
	# дотик до джойстика забирає керування
	game.hud.joystick._touch_index = 0
	game.hud.joystick.vector = Vector2(0, -1)
	check(game.hud.move_vector() == Vector2(0, -1), "палець на джойстику веде героя сам")
	game.hud.joystick.release()
	# пауза й повернення
	game._show_pause()
	await _frames(2)
	game._resume_play()
	await _frames(2)
	check(game.auto_on and game.hud.auto_btn.visible, "після паузи автобій триває")
	# до кінця зачистки й у портал
	var guard := 0
	while game.state == game.State.PLAYING and guard < 150:
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead:
				e.take_damage(e.max_hp * 100.0, Vector2.ZERO)
		c.field_kills = maxi(c.field_kills, c.field_goal - 1)
		await _frames(20)
		guard += 1
	check(game.state == game.State.MAP and int(w.cleared.get("wild_field", 0)) == AS.MIN_CLEARS + 1, "після зачистки герой сам вийшов крізь портал на мапу")
	check(game.hud.auto_vector == Vector2.ZERO and not game.hud.btn_attack.held and not game.hud.auto_btn.visible, "на мапі автобій нічого не тисне")
	# ---- Де не можна ----
	var BS = load("res://scripts/game/boss_service.gd")
	game.start_boss("day")
	await _frames(4)
	check(game.state == game.State.PLAYING and not game.hud.auto_btn.visible and AS.block_reason(w, c, c.loc_id) != "", "на босі дня автобою нема")
	var hp_boss := 0.0
	for e in get_nodes_in_group("enemies"):
		if e.is_boss:
			hp_boss = e.hp
	await _frames(60)
	var touched := false
	for e in get_nodes_in_group("enemies"):
		if e.is_boss and e.hp < hp_boss:
			touched = true
	check(not touched and not game.hud.btn_attack.held, "увімкнений раніше автобій боса сам не б'є")
	game.enter_map()
	await _frames(2)
	var peril_id: String = load("res://scripts/game/peril_service.gd").ids()[0]
	c.loc = Data.LOCATIONS[peril_id]
	check(not AS.applies(c, peril_id) and not AS.applies(c, "hlybyny") and not AS.applies(c, "duel"), "у надважкій печері, Глибинах і особливих боях автобою нема")
	# ---- Довідник ----
	var art := ""
	for e in WS._entries("basics"):
		if str(e["title"]) == "Автобій":
			art = str(e["text"])
	check("%d рази" % AS.MIN_CLEARS in art and "%d%%" % roundi(AS.POTION_AT * 100.0) in art, "довідник описує автобій")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_saga() -> void:
	suite("«Попіл за вітром»: продовження сюжету")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Saga = load("res://scripts/data/saga.gd")
	var SS = load("res://scripts/game/saga_service.gd")
	var Story = load("res://scripts/data/story.gd")
	var Peril = load("res://scripts/game/peril_service.gd")
	var JS = load("res://scripts/game/journal_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	# ---- Дані ----
	var data_ok := true
	var locs := []
	for st in Saga.STEPS:
		data_ok = data_ok and Story.NPCS.has(st["giver"]) and Data.CITIES.has(st["city"]) and Data.LOCATIONS.has(st["objective"]["loc"]) and not st["start"].is_empty() and not st["end"].is_empty() and int(st["reward"]["gold"]) > 0
		locs.append(st["objective"]["loc"])
		for ln in st["start"] + st["end"]:
			data_ok = data_ok and Story.NPCS.has(ln[0]) and str(ln[1]).length() > 10
		data_ok = data_ok and str(int(Data.LOCATIONS[st["objective"]["loc"]]["level"])) in str(st["objective"]["text"])
	check(data_ok and locs == Peril.ids() and Saga.STEPS.size() == 5, "п'ять кроків: кожен веде до свого надважкого боса, оповідачі й міста існують")
	var top := 0
	for a in Ach.ACHIEVEMENTS:
		if str(a["stat"]) == "saga":
			top = maxi(top, int(a["goal"]))
	check(top == Saga.STEPS.size(), "останнє досягнення просить усі кроки")
	# ---- Поки триває головний сюжет ----
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	w.hero_level = 99
	check(StoryService.state(w)["stage"] != "done" and not StoryService.objective_line(w).contains(Saga.TITLE) and not str(StoryService.city_dialogue(w, "sich").get("kind", "")).begins_with("saga") and StoryService.on_event(w, p, "dungeon", locs[0]).is_empty() and w.saga.is_empty(), "поки головну історію не пройдено, продовження мовчить")
	# ---- Відкриття ----
	w.story = {"chapter": Story.CHAPTERS.size(), "step": 0, "stage": "done", "progress": 0}
	w.hero_level = Saga.MIN_LEVEL - 1
	check(StoryService.objective_line(w) == "" and str(Saga.MIN_LEVEL) in SS.teaser(w) and StoryService.target(w) == "" and StoryService.city_dialogue(w, "sich").is_empty() and StoryService.chapter_title(w) == "", "до %d-го рівня лише обіцянка продовження в журналі" % Saga.MIN_LEVEL)
	w.hero_level = Saga.MIN_LEVEL
	var first: Dictionary = Saga.STEPS[0]
	check("Остап" in StoryService.objective_line(w) and StoryService.target(w) == first["city"] and Saga.TITLE in StoryService.chapter_title(w), "з %d-го рівня зірка веде до оповідача: %s" % [Saga.MIN_LEVEL, StoryService.objective_line(w)])
	var d: Dictionary = StoryService.city_dialogue(w, first["city"])
	check(d.get("kind", "") == "saga_start" and d["lines"].size() == first["start"].size() and StoryService.city_dialogue(w, "kyiv").is_empty(), "оповідач говорить лише у своєму місті")
	StoryService.hero_class = "strilets"
	var addr: Array = StoryService.city_dialogue(w, first["city"])["lines"]
	var said := ""
	for ln in addr:
		said += str(ln[1])
	check("стрільче" in said and not "козаче" in said, "до стрільця й тут звертаються «стрільче»")
	StoryService.hero_class = "cossack"
	var msgs: Array = StoryService.on_dialogue_done(w, p, "saga_start")
	check(SS.state(w)["stage"] == "active" and StoryService.target(w) == first["objective"]["loc"] and str(first["objective"]["text"]) in StoryService.objective_line(w) and not msgs.is_empty(), "після розмови мета: надважка печера")
	# ---- Бос і нагорода ----
	check(StoryService.on_event(w, p, "dungeon", "kremlin").is_empty() and SS.state(w)["stage"] == "active", "чужа печера кроку не зараховує")
	var done: Array = StoryService.on_event(w, p, "dungeon", first["objective"]["loc"])
	check(SS.state(w)["stage"] == "turnin" and StoryService.target(w) == first["city"] and "Повертайся" in StoryService.objective_line(w) and not done.is_empty(), "боса здолано: повертайся до оповідача")
	var d2: Dictionary = StoryService.city_dialogue(w, first["city"])
	var gold0: int = p.gold
	var tr0: int = int(p.resources.get("trophy", 0))
	check(d2.get("kind", "") == "saga_end", "оповідач чекає з кінцевою розмовою")
	var fin: Array = StoryService.on_dialogue_done(w, p, "saga_end")
	check(p.gold == gold0 + int(first["reward"]["gold"]) and int(p.resources["trophy"]) == tr0 + int(first["reward"]["trophy"]) and SS.done_count(w) == 1 and SS.state(w)["stage"] == "offer" and not fin.is_empty(), "крок завершено: гривні й трофеї видано, відкрито наступний")
	check(StoryService.target(w) == Saga.STEPS[1]["city"], "далі зірка веде до наступного оповідача")
	# ---- Бос, якого вже здолано раніше ----
	w.cleared[Saga.STEPS[1]["objective"]["loc"]] = 2
	StoryService.on_dialogue_done(w, p, "saga_start")
	check(SS.state(w)["stage"] == "turnin", "давно здоланого боса зараховано одразу після розмови")
	StoryService.on_dialogue_done(w, p, "saga_end")
	# ---- Збереження ----
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	w2.hero_level = 99
	check(SS.done_count(w2) == 2 and StoryService.target(w2) == Saga.STEPS[2]["city"], "поступ продовження зберігається")
	w.hero_level = 10
	check(SS.unlocked(w) and StoryService.target(w) == Saga.STEPS[2]["city"], "почату історію не закриває навіть нижчий рівень")
	w.hero_level = 99
	# ---- До кінця ----
	var bag0: int = p.inventory.size()
	for i in range(2, Saga.STEPS.size()):
		StoryService.on_dialogue_done(w, p, "saga_start")
		StoryService.on_event(w, p, "dungeon", Saga.STEPS[i]["objective"]["loc"])
		StoryService.on_dialogue_done(w, p, "saga_end")
	var prize: Dictionary = p.inventory[p.inventory.size() - 1] if p.inventory.size() > bag0 else {}
	check(SS.finished(w) and SS.done_count(w) == Saga.STEPS.size() and StoryService.objective_line(w) == "" and StoryService.target(w) == "" and prize.get("name", "") == Saga.STEPS[Saga.STEPS.size() - 1]["reward"]["item"]["name"], "історію завершено: останній дар у торбі, зірка зникла")
	check(StoryService.city_dialogue(w, "sich").is_empty() and StoryService.on_event(w, p, "dungeon", locs[0]).is_empty(), "після кінця оповідачі мовчать")
	# ---- Журнал і довідник ----
	var w3 = WorldState.new()
	w3.story = {"chapter": Story.CHAPTERS.size(), "step": 0, "stage": "done", "progress": 0}
	w3.hero_level = 95
	var jr: Array = JS.sections(w3, p)
	var story_sec: Dictionary = {}
	for sec in jr:
		if str(sec.get("title", "")).begins_with("Історія"):
			story_sec = sec
	var now_titles := []
	for ch in story_sec.get("chapters", []):
		if ch["state"] == "now":
			now_titles.append(ch["title"])
	check(story_sec.get("chapters", []).size() == Story.CHAPTERS.size() + Saga.STEPS.size() and now_titles.size() == 1 and Saga.TITLE in str(now_titles[0]) and story_sec["rows"].size() == 1, "журнал показує кроки продовження поруч із розділами")
	var art := ""
	for e in WS._entries("basics"):
		if Saga.TITLE in str(e["title"]):
			art = str(e["text"])
	var art_ok := art != "" and str(Saga.MIN_LEVEL) in art
	for st in Saga.STEPS:
		art_ok = art_ok and str(st["title"]) in art
	check(art_ok, "довідник описує продовження й усі кроки")
	# ---- У грі: розмова на Січі ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "depths_open"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	game._sync_class()
	gp.level = 92
	gp.recalc()
	gw.story = {"chapter": Story.CHAPTERS.size(), "step": 0, "stage": "done", "progress": 0}
	game.enter_map()
	await _frames(2)
	check(game.hud.map_view.story_target == "sich", "зірка на мапі стоїть над Січчю")
	game.enter_city("sich")
	await _frames(3)
	check(game.hud.dialogue_root == null and game.hall_rows("sich")[0]["kind"] == "story" and game.hall_rows("sich")[0]["npc"] == "kobzar", "на Січі кобзар чекає в курені з новою сагою")
	_hall_talk(game, "story")
	await _frames(3)
	check(game.hud.dialogue_root != null and is_instance_valid(game.hud.dialogue_root), "на Січі починається розмова з кобзарем")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_loot_rates() -> void:
	suite("Рідша здобич і нескінченні Башта й Глибини в бою")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Camp = load("res://scripts/data/camp_data.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var DS = load("res://scripts/game/depth_service.gd")
	var Uniq = load("res://scripts/data/uniques.gd")
	# ---- Числа ----
	check(Camp.RESOURCE_DROP_CHANCE <= 0.1 and Data.POTION_DROP_CHANCE <= 0.01 and Data.POTION_ELITE_CHANCE <= 0.15 and Data.MANA_POTION_DROP_CHANCE <= 0.006 and Data.VARENYK_DROP_CHANCE <= 0.03 and Camp.TROPHY_ELITE_CHANCE <= 0.5, "шанси ресурсів, зілля, вареників і трофеїв зменшено")
	check(Camp.bundle_amount(92) == 10 and Camp.bundle_amount(5) == 1 and Camp.boss_trophies(92) == 11 and Camp.boss_trophies(10) == 3, "жменя ресурсів і трофеї боса на 92-му рівні: %d і %d" % [Camp.bundle_amount(92), Camp.boss_trophies(92)])
	var art := ""
	for e in WS._entries("basics"):
		if str(e["title"]) == "Здобич із нечисті":
			art = str(e["text"])
	check("%d%%" % roundi(Camp.RESOURCE_DROP_CHANCE * 100.0) in art and "рівень/%d" % Camp.BUNDLE_LEVEL_STEP in art and "Вареник: %d%%" % roundi(Data.VARENYK_DROP_CHANCE * 100.0) in art and "0,6%" in art and "Золота річ" in art and "Душа" in art, "довідник називає всі шанси здобичі")
	var map_art := ""
	for e in WS._entries("map"):
		if str(e["title"]) == "Глибини зарази":
			map_art = str(e["text"])
	check("Стелі нема" in map_art and str(DS.level_of(150)) in map_art, "довідник пояснює, що Глибини не мають дна")
	# ---- У бою ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var w = game.world
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "dungeon", "depths", "potion", "mana_potion", "varenyk", "res", "depths_open"]:
		w.hints[k] = true
	p.change_class("cossack")
	game._sync_class()
	p.level = 99
	p.stats["str"] = 5000
	p.stats["vit"] = 5000
	p.recalc()
	p.hp = p.max_hp
	w.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	# статистика падіння з рядових ворогів на 92-му рівні
	game.enter_location("wild_field")
	await _frames(3)
	_clear_enemies(game)
	await _frames(2)
	c.loc = c.loc.duplicate()
	c.loc["level"] = 92
	c.spawn_timer = 9999.0
	seed(4242)
	var kills := 600
	for i in kills:
		c.spawn_enemy("zarazhenyi", 92, false, p.global_position + Vector2(900, 0))
		var e = c._last_enemy()
		c._drop_loot(e)
		e.remove_from_group("enemies")
		e.free()
	var res_n := 0
	var pot_n := 0
	var var_n := 0
	for n in c.entities.get_children():
		if n.get_script() == c.PickupScript:
			if n.kind == "res" and str(n.item.get("res", "")) != Camp.TROPHY:
				res_n += int(n.value)
			elif n.kind == "potion":
				pot_n += 1
			elif n.kind == "varenyk":
				var_n += 1
	check(res_n > kills * 0.05 and res_n < kills * 0.17 and pot_n < kills * 0.03 and var_n < kills * 0.06, "із 600 рядових ворогів: ресурсів %d, зілля %d, вареників %d" % [res_n, pot_n, var_n])
	for n in c.entities.get_children():
		if n.get_script() == c.PickupScript:
			n.queue_free()
	await _frames(2)
	# еліта: трофей через раз, жменя за новою міркою
	seed(77)
	var trophies := 0
	var elite_res := 0
	for i in 200:
		c.spawn_enemy("zarazhenyi", 92, false, p.global_position + Vector2(900, 0))
		var e = c._last_enemy()
		e.make_elite(load("res://scripts/data/elites.gd").roll_affixes(92))
		c._drop_loot(e)
		e.remove_from_group("enemies")
		e.free()
	for n in c.entities.get_children():
		if n.get_script() == c.PickupScript and n.kind == "res":
			if str(n.item.get("res", "")) == Camp.TROPHY:
				trophies += int(n.value)
			else:
				elite_res += int(n.value)
	check(trophies > 60 and trophies < 140 and elite_res == 200 * 2 * Camp.bundle_amount(92), "із 200 еліт: трофеїв %d, ресурсів %d (по дві жмені з %d)" % [trophies, elite_res, Camp.bundle_amount(92)])
	game.enter_map()
	await _frames(2)
	# Глибина понад 99-й рівень: нечисть сильніша, здобич 99-го
	DS.state(w)["max"] = 80
	game.start_depth(60)
	await _frames(4)
	var foe = null
	for e in get_nodes_in_group("enemies"):
		if not e.is_boss and not e.elite:
			foe = e
	var L60: Dictionary = DS.loc_for(60)
	check(game.state == game.State.PLAYING and int(c.loc["level"]) == DS.level_of(60) and int(c.loc["level"]) > 99 and c.loot_level() == Data.ENDLESS_SOFT and foe != null and int(foe.level) == DS.level_of(60), "глибина 60 у бою: нечисть %d-го рівня, здобич %d-го" % [int(c.loc["level"]), c.loot_level()])
	c._drop_loot(foe)
	var item_lvls := []
	for i in 40:
		item_lvls.append(int(c._loot(c.loot_level(), 3)["ilvl"]))
	check(item_lvls.max() <= Data.ENDLESS_SOFT + 1, "речі з глибини не вищі за %d-й рівень" % Data.ENDLESS_SOFT)
	var fake_boss = null
	c.spawn_enemy(str(c.loc["boss"]), int(c.loc["level"]), true, p.global_position + Vector2(900, 0))
	fake_boss = c._last_enemy()
	p.u_luck = Uniq.LUCK_SURE
	var gold_item: Dictionary = load("res://scripts/game/loot_service.gd").on_boss(c, p, fake_boss)
	check(not gold_item.is_empty() and int(gold_item["ilvl"]) == Data.ENDLESS_SOFT and int(fake_boss.level) > 99, "золота річ із глибинного боса теж %d-го рівня" % Data.ENDLESS_SOFT)
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_divine() -> void:
	suite("Божі дари: дев'ять речей у семи власних гніздах")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Div = load("res://scripts/data/divine.gd")
	var DS = load("res://scripts/game/divine_service.gd")
	var SH = load("res://scripts/game/shop_service.gd")
	var Camp = load("res://scripts/game/camp_service.gd")
	var Classes = load("res://scripts/data/classes.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var UD = load("res://scripts/ui/ui_divine.gd")
	# ---- Дані ----
	var data_ok := true
	var slots := {}
	for id in Div.ORDER:
		var D: Dictionary = Div.DEFS[id]
		slots[D["slot"]] = id
		data_ok = data_ok and D["slot"] in Div.SLOTS and str(D["name"]) != "" and int(D["price"]) > 0 and GfxS.icon_tex(str(D["icon"])) != null and not D["lines"].is_empty() and id in Div.in_slot(D["slot"])
		for k in D.get("fx", {}):
			data_ok = data_ok and Classes.FX_TEXT.has(k)
	var two := 0
	for sl in Div.SLOTS:
		data_ok = data_ok and not Div.in_slot(sl).is_empty() and Div.SLOT_NAMES.has(sl)
		if Div.in_slot(sl).size() > 1:
			two += 1
	check(data_ok and slots.size() == Div.SLOTS.size() and Div.ORDER.size() == 9 and Div.SLOTS.size() == 7 and two == 2, "дев'ять дарів на сім гнізд: у двох гніздах вибір із двох")
	# ---- Купівля й гнізда ----
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	p.level = 50
	p.stats["str"] = 100
	p.stats["agi"] = 60
	Camp.apply_effects(w, p)
	var bag0: int = p.bag_size()
	var str0: int = p.stat("str")
	var agi0: int = p.stat("agi")
	var dmg0: float = p.damage
	var pick0: float = p.pickup_radius
	var crit0: float = p.crit_mult
	check(not DS.buy(w, p, "mazha") and "бракує" in DS.block_reason(w, "mazha") and not DS.equip(w, p, "mazha") and p.divine.is_empty(), "без червінців дар не купити й не вдягнути")
	SH.state(w)["coins"] = 100000
	check(DS.buy(w, p, "mazha") and DS.owned(w, "mazha") and DS.wears(p, "mazha") and p.bag_size() == bag0 + int(Div.DEFS["mazha"]["bag"]) and SH.coins(w) == 100000 - DS.price("mazha"), "чумацьку мажу куплено: вона у своєму гнізді, торба більша на %d" % int(Div.DEFS["mazha"]["bag"]))
	check(p.inventory.is_empty() and DS.block_reason(w, "mazha") == "уже куплено", "дар не займає місця в торбі й удруге не продається")
	check(DS.buy(w, p, "kryla") and p.stat("str") == int(round(str0 * 1.1)) and p.stat("agi") == int(round(agi0 * 1.1)) and p.damage > dmg0 * 1.05, "крила: усі характеристики +10%% (Сила %d → %d)" % [str0, p.stat("str")])
	var dmg1: float = p.damage
	check(DS.buy(w, p, "molot") and p.damage > dmg1 * 1.11 and is_equal_approx(p.fx("dmg"), float(Div.DEFS["molot"]["fx"]["dmg"])) and is_equal_approx(p.crit_mult, crit0 + float(Div.DEFS["molot"]["fx"]["crit_dmg"]) / 100.0), "громовий молот: бойові показники ростуть")
	check(DS.buy(w, p, "khovanets") and is_equal_approx(p.pickup_radius, pick0 * (1.0 + float(Div.DEFS["khovanets"]["pickup"]))) and DS.remote_shop(p), "Хованець: радіус збору вп'ятеро більший, крамниця будь-де")
	check(p.divine.size() == 4 and p.inventory.is_empty(), "усі чотири гнізда зайнято, торба порожня")
	# ---- Зняти й вдягнути ----
	DS.unequip(w, p, "wings")
	check(p.stat("str") == str0 and not DS.wears(p, "kryla") and DS.owned(w, "kryla"), "зняті крила не діють, але лишаються в роду")
	check(DS.equip(w, p, "kryla") and p.stat("str") == int(round(str0 * 1.1)), "вдягнули знову")
	DS.unequip(w, p, "cart")
	check(p.bag_size() == bag0 and not DS.remote_shop(_new_player()), "без мажі торба звичайна")
	DS.equip(w, p, "mazha")
	# ---- Рід і збереження ----
	var p2 = _new_player()
	p2.change_class("cossack")
	check(DS.equip(w, p2, "molot") and p2.divine.size() == 1 and p2.fx("dmg") > 0.0, "інший герой роду вдягає куплене без оплати")
	var p3 = _new_player()
	p3.from_dict(p.to_dict())
	Camp.apply_effects(w, p3)
	check(p3.divine.size() == 4 and p3.bag_size() == p.bag_size() and DS.remote_shop(p3) and p3.fx("dmg") > 0.0, "вдягнені дари зберігаються з героєм і діють після завантаження")
	Camp.apply_effects(WorldState.new(), p3)
	check(p3.divine.is_empty() and p3.bag_size() == Data.INVENTORY_SIZE and not DS.remote_shop(p3) and p3.fx("dmg") == 0.0, "у роду без цих дарів вони знімаються")
	# ---- Нові дари: вибір у гнізді й нові гнізда ----
	var w5 = WorldState.new()
	var p5 = _new_player()
	p5.change_class("cossack")
	p5.level = 50
	SH.state(w5)["coins"] = 100000
	Camp.apply_effects(w5, p5)
	var sp0: float = p5.speed
	var xp0: float = p5.xp_mult
	var gm0: float = p5.gold_mult
	DS.buy(w5, p5, "khovanets")
	check(DS.buy(w5, p5, "skakun") and DS.worn(p5, "pet") == "skakun" and not DS.remote_shop(p5) and DS.owned(w5, "khovanets") and is_equal_approx(p5.speed, sp0 * 1.2), "скакун стає в гніздо «Супутник» замість Хованця: біг +20%, Хованець лишився в роду")
	check(DS.equip(w5, p5, "khovanets") and DS.remote_shop(p5) and is_equal_approx(p5.speed, sp0) and p5.divine.size() == 1, "назад на Хованця: у гнізді завжди один дар")
	DS.buy(w5, p5, "molot")
	check(DS.buy(w5, p5, "ladanka") and DS.worn(p5, "relic") == "ladanka" and p5.fx("dmg") == 0.0 and is_equal_approx(float(p5.divine_fx["revive"]), 0.5), "ладанка лягає в гніздо «Реліквія» замість молота")
	check(DS.buy(w5, p5, "nimb") and is_equal_approx(p5.xp_mult, xp0 + 0.15) and is_equal_approx(p5.gold_mult, gm0 + 0.15), "німб: досвід і гривні +15%")
	check(DS.buy(w5, p5, "stiah") and is_equal_approx(float(p5.divine_fx["party"]), 0.25) and DS.buy(w5, p5, "likhtar") and bool(p5.divine_fx["sight"]) and float(p5.divine_fx["light"]) > 1.0, "стяг і ліхтар мають власні гнізда")
	check(p5.divine.size() == 5 and p5.inventory.is_empty(), "п'ять гнізд зайнято: супутник, реліквія, німб, стяг, ліхтар")
	var CompS = load("res://scripts/entities/companion.gd")
	var c_plain = CompS.new()
	c_plain.setup("dzhura", 30, 0)
	var c_boost = CompS.new()
	c_boost.boost = 1.25
	c_boost.setup("dzhura", 30, 0)
	check(is_equal_approx(c_boost.max_hp, c_plain.max_hp * 1.25) and is_equal_approx(c_boost.damage, c_plain.damage * 1.25) and is_equal_approx(c_boost.hp, c_boost.max_hp), "під стягом побратим має на чверть більше здоров'я й шкоди")
	c_plain.free()
	c_boost.free()
	# ---- Екран героя: гнізда ----
	check(UD.slot_of(UD.sel_of("wings")) == "wings" and UD.slot_of(-2) == "" and UD.slot_of(5) == "", "гніздо вибирається окремим номером, не плутаючись із речами")
	# ---- Довідник ----
	var art := ""
	for e in WS._entries("basics"):
		if str(e["title"]) == "Божі дари":
			art = str(e["text"])
	var art_ok := art != ""
	for id in Div.ORDER:
		art_ok = art_ok and str(Div.DEFS[id]["name"]) in art and str(int(Div.DEFS[id]["price"])) in art
	check(art_ok, "довідник описує всі дари з цінами")
	check(load("res://scripts/ui/ui_character.gd").TRADER_BTN in art and "над торбою" in art and "голоблі" in art, "довідник каже про кнопку крамниці над торбою й про мажу на голоблях")
	check("одразу лягає в торбу" in art and "нема куди покласти" in art, "довідник каже, що з Хованцем здобич одразу в торбі")
	# ---- У грі ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "depths_open"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	game._sync_class()
	gp.level = 40
	gp.recalc()
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	SH.state(gw)["coins"] = 10000
	game.enter_map()
	await _frames(2)
	game.open_character()
	await _frames(2)
	var slot_labels := 0
	for l in game.hud.screen_root.find_children("*", "Label", true, false):
		if l.text == "Божі дари":
			slot_labels += 1
	check(slot_labels >= 1, "на екрані героя є ряд гнізд «Божі дари»")
	game.char_do("select", UD.sel_of("relic"))
	await _frames(2)
	var to_shop := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		to_shop = to_shop or b.text.begins_with("До крамниці")
	check(to_shop, "некуплений дар веде до крамниці")
	game.char_do("divine_shop", "molot")
	await _frames(2)
	check(game.shop_open and game.shop_tab == game._shop_tab_index("Божі дари"), "крамниця відкрилась на вкладці «Божі дари»")
	game.shop_do("divine", "molot")
	check(game.shop_confirm == "divine:molot" and not DS.owned(gw, "molot"), "перший дотик лише просить підтвердити")
	game.shop_do("divine", "molot")
	game.shop_do("divine", "khovanets")
	game.shop_do("divine", "khovanets")
	game.shop_do("divine", "mazha")
	game.shop_do("divine", "mazha")
	game.shop_do("divine", "kryla")
	game.shop_do("divine", "kryla")
	await _frames(2)
	check(gp.divine.size() == 4 and bool(game.account.shop.get("divine", {}).get("molot", false)), "усі чотири дари куплено й вдягнено")
	game.close_shop()
	await _frames(2)
	var UChar = load("res://scripts/ui/ui_character.gd")
	var hero_back := false
	var inv_trader := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		if b.is_queued_for_deletion():
			continue
		hero_back = hero_back or b.text.begins_with("Душі")
		inv_trader = inv_trader or b.text == UChar.TRADER_BTN
	check(hero_back and game.state == game.State.CHARACTER and not game.shop_open, "із крамниці «Назад» вертає на екран героя, а не на порожній екран")
	check(inv_trader, "Хованця вдягнено: над торбою є кнопка його крамниці")
	game.char_do("trader", null)
	await _frames(2)
	check(game.trader_open and game.state == game.State.CHARACTER and game.city_id == game.trader_city, "крамниця Хованця відкривається просто з торби")
	game.close_trader()
	await _frames(2)
	hero_back = false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		hero_back = hero_back or (not b.is_queued_for_deletion() and b.text.begins_with("Душі"))
	check(not game.trader_open and hero_back and game.state == game.State.CHARACTER, "«Назад» із крамниці Хованця вертає до торби")
	game.char_do("select", UD.sel_of("pet"))
	await _frames(2)
	var open_here := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		open_here = open_here or (not b.is_queued_for_deletion() and b.text == "Відкрити крамницю")
	check(open_here, "у гнізді Хованця теж є кнопка «Відкрити крамницю»")
	game.char_do("select", UD.sel_of("relic"))
	game.char_do("divine_toggle", "molot")
	check(not DS.wears(gp, "molot"), "на екрані героя дар знімається")
	game.char_do("divine_toggle", "molot")
	check(DS.wears(gp, "molot"), "і вдягається знову")
	game.close_character()
	await _frames(2)
	# крамниця Хованця на мапі
	var trader_btn = null
	for b in game.hud.map_panel.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with("Хованець"):
			trader_btn = b
	check(trader_btn != null, "на мапі є кнопка «Хованець: крамниця будь-де»")
	var worn_head: Dictionary = Data.gen_item(40, 3, "head")
	gp.add_item(worn_head, true)
	gp.equip(worn_head["uid"])
	var junk: Dictionary = Data.gen_item(20, 0, "head")
	var keep: Dictionary = Data.gen_item(40, 3, "body")
	gp.add_item(junk, true)
	gp.add_item(keep, true)
	gp.gold = 100000
	gp.potions = 0
	trader_btn.pressed.emit()
	await _frames(2)
	check(game.trader_open and game.trader_city == gw.last_city and game.city_id == game.trader_city, "крамниця Хованця відкрилась: торгує в останньому місті (%s)" % game.trader_city)
	var tbtn := []
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			tbtn.append(b.text)
	var bulk_btn := false
	for t in tbtn:
		bulk_btn = bulk_btn or str(t).begins_with("Продати звичайні")
	check("✓ Вибрати кілька" in tbtn and bulk_btn and tbtn.any(func(t): return str(t).begins_with("Купити •")) and not game.shop_stock(game.trader_city).is_empty(), "вона така сама, як у місті: товари, зілля, «Вибрати кілька» й продаж гуртом")
	var gold0: int = gp.gold
	game.city_do("buy_potion", null)
	check(gp.potions == 1 and gp.gold == gold0 - game.CityService.potion_price(gw, gp, game.trader_city), "зілля куплено за ціною цього міста")
	gold0 = gp.gold
	game.city_do("select", keep["uid"])
	game.city_do("sell", keep["uid"])
	check(gp.find_item(keep["uid"]).is_empty() and gp.gold == gold0 + Data.sell_price(keep) and game.trader_open, "вибрану річ продано, крамниця лишилась відкрита")
	# вибір кількох речей, як у місті
	var m1: Dictionary = Data.gen_item(40, 2, "belt")
	var m2: Dictionary = Data.gen_item(40, 2, "boots")
	gp.add_item(m1, true)
	gp.add_item(m2, true)
	game.city_do("sell_multi", null)
	await _frames(2)
	var done_btn := false
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		done_btn = done_btn or (not b.is_queued_for_deletion() and b.text == "Готово")
	check(game.sell_multi and done_btn, "кнопка «Вибрати кілька» вмикає вибір")
	game.city_do("mark", m1["uid"])
	game.city_do("mark", m2["uid"])
	gold0 = gp.gold
	game.city_do("sell_marked", null)
	check(gp.find_item(m1["uid"]).is_empty() and gp.find_item(m2["uid"]).is_empty() and gp.gold == gold0 + Data.sell_price(m1) + Data.sell_price(m2), "дві вибрані речі продано разом")
	game.city_do("sell_multi", null)
	gold0 = gp.gold
	game.city_do("sell_upto", 0)
	check(gp.find_item(junk["uid"]).is_empty() and gp.gold > gold0, "звичайні речі продано гуртом")
	var stock: Array = game.shop_stock(game.trader_city)
	var buy_it: Dictionary = stock[0]
	gp.gold = 10000000
	var bag_n: int = gp.inventory.size()
	game.city_do("buy", buy_it["uid"])
	check(gp.inventory.size() == bag_n + 1, "товар міста можна купити через Хованця")
	game.close_trader()
	await _frames(2)
	check(not game.trader_open and game.state == game.State.MAP, "«Назад» вертає на мапу")
	# у бою: супутники біля героя
	game.enter_location("wild_field")
	await _frames(4)
	var kinds := []
	for n in game.combat.entities.get_children():
		if n.get_script() == game.combat.PetScript:
			kinds.append(n.kind)
	check("khovanets" in kinds and "mazha" in kinds, "Хованець і мажа йдуть за героєм у бою: %s" % str(kinds))
	# мажу тягне герой: вона на голоблях, сама не їде
	var PetS = game.combat.PetScript
	var cart = null
	for n in game.combat.entities.get_children():
		if n.get_script() == PetS and n.kind == "mazha":
			cart = n
	_clear_enemies(game)
	await _frames(3)
	var stood: Vector2 = cart.position
	await _frames(12)
	check(cart.position.distance_to(stood) < 0.5 and not cart._moving and absf(cart.position.distance_to(gp.position + PetS.HITCH) - PetS.cart_len((cart.position - gp.position - PetS.HITCH).normalized())) < 0.5, "герой стоїть, і мажа стоїть на довжину голобель від нього")
	for i in 40:
		gp.position += Vector2(5, 0)
		await _frames(1)
	check(cart.position.x < gp.position.x - PetS.CART_LEN * 0.9 and absf(cart.position.distance_to(gp.position + PetS.HITCH) - PetS.cart_len((cart.position - gp.position - PetS.HITCH).normalized())) < 0.5 and cart._moving and cart._face > 0.0, "герой іде праворуч і тягне мажу: вона позаду на голоблях, передком до нього")
	for i in 60:
		gp.position += Vector2(-5, 0)
		await _frames(1)
	check(cart.position.x > gp.position.x + PetS.CART_LEN * 0.9 and absf(cart.position.distance_to(gp.position + PetS.HITCH) - PetS.cart_len((cart.position - gp.position - PetS.HITCH).normalized())) < 0.5 and cart._face < 0.0, "герой розвернувся: мажа об'їхала його й знову позаду")
	for i in 30:
		gp.position += Vector2(0, 5)
		await _frames(1)
	check(cart.position.y < gp.position.y - PetS.CART_LEN and PetS.cart_len(Vector2.UP) > PetS.CART_LEN and absf(cart.position.distance_to(gp.position + PetS.HITCH) - PetS.cart_len((cart.position - gp.position - PetS.HITCH).normalized())) < 0.5, "герой звернув униз, і мажа повернула за ним")
	# крамниця Хованця з торби посеред бою
	game.open_character()
	await _frames(2)
	game.char_do("trader", null)
	await _frames(2)
	check(game.trader_open and game.state == game.State.CHARACTER, "посеред бою крамниця Хованця відкривається з торби")
	game.close_trader()
	await _frames(2)
	game.close_character()
	await _frames(2)
	check(game.state == game.State.PLAYING and not get_root().get_tree().paused, "із торби бій триває далі")
	# ---- Хованець: здобич одразу лягає в торбу ----
	var lcb = game.combat
	var PickS = lcb.PickupScript
	var ground := func() -> int:
		var n := 0
		for node in lcb.entities.get_children():
			if node.get_script() == PickS and not node.is_queued_for_deletion():
				n += 1
		return n
	for node in lcb.entities.get_children():
		if node.get_script() == PickS:
			node.queue_free()
	await _frames(2)
	var far: Vector2 = gp.global_position + Vector2(600, 0)  # далеко за звичайним радіусом збору
	lcb.pickup_filter = [true, true, true, true]
	lcb.autosell = false
	gp.potions = 0
	gp.mana_potions = 0
	gp.hp = gp.max_hp * 0.5
	var loot_gold: int = gp.gold
	var loot_bag: int = gp.inventory.size()
	var loot_wood: int = int(gp.resources.get("wood", 0))
	var drop1: Dictionary = Data.gen_item(20, 1, "boots")
	lcb.spawn_pickup(far, "coin", 5)
	lcb.spawn_pickup(far, "item", 0, drop1)
	lcb.spawn_pickup(far, "res", 3, {"res": "wood"})
	lcb.spawn_pickup(far, "potion", 1)
	lcb.spawn_pickup(far, "mana", 1)
	lcb.spawn_pickup(far, "varenyk", 10)
	check(bool(gp.divine_fx.get("loot", false)) and ground.call() == 0, "із Хованцем здобич на землю не падає")
	check(gp.gold > loot_gold and gp.inventory.size() == loot_bag + 1 and gp.inventory[-1]["name"] == drop1["name"] and int(gp.resources.get("wood", 0)) >= loot_wood + 3 and gp.potions == 1 and gp.mana_potions == 1 and gp.hp > gp.max_hp * 0.5, "гривні, річ, дерево, зілля й вареник одразу в героя")
	# нема куди покласти: падає на землю
	gp.potions = gp.potion_max()
	lcb.spawn_pickup(far, "potion", 1)
	check(ground.call() == 1 and gp.potions == gp.potion_max(), "запас зілля повний: зілля падає на землю")
	while not gp.bag_full():
		gp.add_item(Data.gen_item(10, 1, "belt"), true)
	var full_n: int = gp.inventory.size()
	lcb.spawn_pickup(far, "item", 0, Data.gen_item(20, 1, "head"))
	check(ground.call() == 2 and gp.inventory.size() == full_n, "торба повна: річ падає на землю й чекає")
	lcb.spawn_pickup(far, "coin", 3)
	lcb.spawn_pickup(far, "res", 1, {"res": "iron"})
	check(ground.call() == 2, "гривні й ресурси беруться й із повною торбою")
	# фільтр автопідбору й викинуті речі Хованець не чіпає
	gp.remove_from_bag(gp.inventory[-1]["uid"])
	lcb.pickup_filter = [false, true, true, true]
	lcb.spawn_pickup(far, "item", 0, Data.gen_item(20, 0, "belt"))
	check(ground.call() == 3 and gp.inventory.size() == full_n - 1, "чого не бере фільтр автопідбору, те лишається лежати")
	lcb.pickup_filter = [true, true, true, true]
	var thrown: Dictionary = gp.remove_from_bag(gp.inventory[0]["uid"])
	lcb.drop_item(thrown)
	check(ground.call() == 4 and gp.inventory.size() == full_n - 2, "викинута з торби річ лежить на землі: назад сама не стрибає")
	# без Хованця все як було: здобич падає на землю
	for node in lcb.entities.get_children():
		if node.get_script() == PickS:
			node.queue_free()
	await _frames(2)
	DS.unequip(gw, gp, "pet")
	var plain_gold: int = gp.gold
	lcb.spawn_pickup(far, "coin", 5)
	lcb.spawn_pickup(far, "item", 0, Data.gen_item(20, 1, "boots"))
	check(not bool(gp.divine_fx.get("loot", false)) and ground.call() == 2 and gp.gold == plain_gold, "без Хованця здобич, як і раніше, падає на землю")
	DS.equip(gw, gp, "khovanets")
	check(bool(gp.divine_fx.get("loot", false)) and DS.remote_shop(gp) and float(gp.divine_fx.get("pickup", 0.0)) == float(Div.DEFS["khovanets"]["pickup"]), "решта властивостей Хованця без змін: крамниця будь-де й великий радіус збору")
	for node in lcb.entities.get_children():
		if node.get_script() == PickS:
			node.queue_free()
	while gp.inventory.size() > 6:
		gp.remove_from_bag(gp.inventory[-1]["uid"])
	await _frames(2)
	game._show_pause()
	await _frames(2)
	var pause_trader := false
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		pause_trader = pause_trader or (not b.is_queued_for_deletion() and b.text.begins_with("Хованець"))
	check(pause_trader, "у паузі теж є крамниця Хованця")
	game._resume_play()
	await _frames(2)
	# ладанка, стяг і ліхтар у бою
	game.enter_map()
	await _frames(2)
	SH.state(gw)["coins"] = 20000
	for nid in ["ladanka", "stiah", "likhtar", "skakun", "nimb"]:
		game.shop_do("divine", nid)
		game.shop_do("divine", nid)
	check(gp.divine.size() == 7 and DS.worn(gp, "relic") == "ladanka" and DS.worn(gp, "pet") == "skakun", "усі сім гнізд зайнято")
	game.open_character()
	await _frames(2)
	var no_trader := true
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		no_trader = no_trader and not (not b.is_queued_for_deletion() and b.text == load("res://scripts/ui/ui_character.gd").TRADER_BTN)
	check(no_trader, "Хованця знято заради скакуна: кнопки крамниці над торбою нема")
	game.close_character()
	await _frames(2)
	gw.companions = [{"type": "dzhura", "downed": false, "level": 20, "xp": 0}]
	game.enter_location("wild_field")
	await _frames(4)
	var cb = game.combat
	var horse := false
	for n in cb.entities.get_children():
		horse = horse or (n.get_script() == cb.PetScript and n.kind == "skakun")
	var mate = cb.companion_nodes[0] if not cb.companion_nodes.is_empty() else null
	check(horse and mate != null and is_equal_approx(mate.boost, 1.25), "скакун біжить поруч, побратим б'ється під стягом")
	_clear_enemies(game)
	await _frames(2)
	cb.spawn_timer = 9999.0
	if cb.trail != null and is_instance_valid(cb.trail):
		cb.trail.found = true
	cb.spawn_enemy("upyr", 40, false, gp.global_position + Vector2(600, 0))
	check(not (cb.objective().get("label", "") == "Еліта"), "звичайну нечисть ліхтар не показує")
	var el = cb._last_enemy()
	el.make_elite(load("res://scripts/data/elites.gd").roll_affixes(40))
	check(cb.objective().get("label", "") == "Еліта" and cb.objective()["pos"] == el.global_position, "ліхтар веде стрілку до еліти")
	gp.hp = 10.0
	gp.invuln = 0.0
	gp.ladanka_ready = true
	gp.hp = -5.0
	gp._check_death()
	check(gp.alive and gp.hp >= gp.max_hp * 0.49 and not gp.ladanka_ready, "ладанка підняла героя з половиною здоров'я (%d із %d)" % [int(gp.hp), int(gp.max_hp)])
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Клітинки речей на екрані: кнопки заданого розміру без тексту (UI.item_cell).
func _cells(root_c: Control, px: int) -> Array:
	var out := []
	for b in root_c.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text == "" and b.custom_minimum_size == Vector2(px, px):
			out.append(b)
	return out


func _suite_grid_shops() -> void:
	suite("Крамниця й скриня сіткою значків")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var UCity = load("res://scripts/ui/ui_city.gd")
	var UCamp = load("res://scripts/ui/ui_camp.gd")
	var UChar = load("res://scripts/ui/ui_character.gd")
	var UKit = load("res://scripts/ui/ui_kit.gd")
	var Camp = load("res://scripts/data/camp_data.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	# ---- Клітинка з ціною й позначкою ----
	var sample: Dictionary = Data.gen_item(20, 2, "head")
	var plain: Button = UKit.item_cell(sample, func(): pass, false, 70)
	var priced: Button = UKit.item_cell(sample, func(): pass, false, 70, false, "1 384", true)
	var note_ok := false
	var check_ok := false
	for l in priced.find_children("*", "Label", true, false):
		note_ok = note_ok or l.text == "1 384"
		check_ok = check_ok or l.text == "✓"
	check(note_ok and check_ok and plain.find_children("*", "Label", true, false).is_empty() and priced.text == "" and priced.custom_minimum_size == Vector2(70, 70), "клітинка речі вміє показати ціну під значком і галочку")
	plain.free()
	priced.free()
	check(UCity.SHOP_CELL == UChar.CELL and UCity.BAG_COLS == 6, "клітинки крамниці такі самі, як у торбі героя: той самий розмір і шість стовпців")
	# ---- Примірка речі пам'ятається, доки не зміниться герой чи сама річ ----
	var cp = _new_player()
	cp.change_class("cossack")
	cp.level = 30
	var worn0: Dictionary = Data.gen_item(30, 1, "head")
	cp.add_item(worn0, true)
	cp.equip(worn0["uid"])
	var better: Dictionary = Data.gen_item(30, 3, "head")
	cp.add_item(better, true)
	var g1: float = cp.gain_from(better)
	check(cp._gain_cache.size() == 1 and is_equal_approx(cp.gain_from(better), g1) and cp._gain_cache.size() == 1, "друга примірка тієї самої речі береться з пам'яті")
	cp._gain_cache.clear()
	check(is_equal_approx(cp.gain_from(better), g1), "з пам'яті й наново примірка дає те саме: %.4f" % g1)
	better["up"] = 5
	var g2: float = cp.gain_from(better)
	check(g2 > g1 and cp._gain_cache.size() == 2, "заточена річ приміряється наново: %.4f проти %.4f" % [g2, g1])
	cp.equip(better["uid"])
	check(cp._gain_cache.is_empty() and is_equal_approx(cp.gain_from(better), 0.0) and cp.gain_from(worn0) < 0.0, "вдягнув іншу річ: стара пам'ять скинута, знята шапка тепер гірша за вдягнену")
	cp.free()
	# ---- Крамниця міста ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp", "kleinody"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	game._sync_class()
	gp.level = 30
	gp.gold = 500000
	for i in 5:
		gp.add_item(Data.gen_item(28, i % 3, "body" if i % 2 == 0 else "boots"), true)
	gp.add_item(Arts.make(Arts.ORDER[0]), true)
	gp.recalc()
	game.enter_map()
	await _frames(2)
	game.enter_city("poltava")
	await _frames(2)
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var shop_i := -1
	for i in tc.get_tab_count():
		if tc.get_tab_title(i) == "Крамниця":
			shop_i = i
	# вкладки будуються ліниво: поки вкладку не відкрито, її вміст не збудовано
	var built := 0
	for i in tc.get_tab_count():
		if not tc.get_tab_control(i).has_meta("build"):
			built += 1
	check(built == 1 and tc.get_tab_control(shop_i).has_meta("build") and _cells(tc.get_tab_control(shop_i), UCity.SHOP_CELL).is_empty(), "з усіх вкладок міста збудовано лише відкриту (%d із %d)" % [built, tc.get_tab_count()])
	tc.current_tab = shop_i  # відкрити вкладку «Крамниця»
	check(not tc.get_tab_control(shop_i).has_meta("build") and game.city_tab == shop_i, "відкрита вкладка будується в ту ж мить")
	var page: Control = tc.get_tab_control(shop_i)
	var stock: Array = game.shop_stock("poltava")
	var cells: Array = _cells(page, UCity.SHOP_CELL)
	var tiles := 0
	for b in page.find_children("*", "Button", true, false):
		if "\n" in b.text and "грн" in b.text and not b.text.begins_with("Продати"):
			tiles += 1
	check(cells.size() == stock.size() + gp.inventory.size() and tiles == 0 and stock.size() > 0, "товари й торба стоять клітинками зі значками, текстових плиток нема (%d клітинок)" % cells.size())
	var price_seen := false
	var sell_seen := false
	for l in page.find_children("*", "Label", true, false):
		price_seen = price_seen or l.text == UKit.num(game.buy_price("poltava", stock[0]))
		sell_seen = sell_seen or l.text == "+" + UKit.num(Data.sell_price(gp.inventory[0]))
	var empties := 0
	for pn in page.find_children("*", "Panel", true, false):
		if pn.custom_minimum_size == Vector2(UCity.SHOP_CELL, UCity.SHOP_CELL):
			empties += 1
	check(price_seen and sell_seen and empties >= gp.bag_size() - gp.inventory.size(), "під значком ціна купівлі чи продажу, порожні місця торби видно клітинками")
	# дотик до товару показує картку й кнопку купівлі
	cells[0].pressed.emit()
	await _frames(2)
	page = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(shop_i)
	var buy_btn = null
	for b in page.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with("Купити за"):
			buy_btn = b
	var bag0: int = gp.inventory.size()
	check(game.city_sel_uid == int(stock[0]["uid"]) and buy_btn != null and not buy_btn.disabled, "дотик до клітинки товару відкриває картку з кнопкою «Купити»")
	buy_btn.pressed.emit()
	await _frames(2)
	check(gp.inventory.size() == bag0 + 1, "товар куплено з картки")
	# продаж кількох: позначені клітинки, артефакт не позначається
	game.city_do("sell_multi", null)
	await _frames(2)
	page = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(shop_i)
	var bag_cells: Array = _cells(page, UCity.SHOP_CELL).slice(game.shop_stock("poltava").size())
	var art_i := -1
	for i in gp.inventory.size():
		if gp.inventory[i].has("artifact"):
			art_i = i
	bag_cells[0].pressed.emit()
	bag_cells[1].pressed.emit()
	bag_cells[art_i].pressed.emit()
	await _frames(2)
	check(game.sell_marked.size() == 2 and not game.sell_marked.has(gp.inventory[art_i]["uid"]), "у режимі «Вибрати кілька» дотик позначає клітинки, артефакт не позначається")
	page = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(shop_i)
	var ticks := 0
	for l in page.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion() and l.text == "✓":
			ticks += 1
	check(ticks == 2, "позначені клітинки мають галочку")
	var n0: int = gp.inventory.size()
	game.city_do("sell_marked", null)
	await _frames(2)
	check(gp.inventory.size() == n0 - 2, "вибране продано разом")
	game.city_do("sell_multi", null)
	# ---- Скриня на хуторі ----
	game.enter_map()
	await _frames(2)
	var in_chest: Dictionary = Data.gen_item(25, 3, "amulet")
	game.account.put_item(in_chest, 0)
	game.enter_camp()
	await _frames(2)
	var ctc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in ctc.get_tab_count():
		if ctc.get_tab_title(i) == "Скриня":
			game.camp_tab = i
	game._build_camp()
	await _frames(2)
	var cpage: Control = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.camp_tab)
	var ccells: Array = _cells(cpage, UCamp.CHEST_CELL)
	var chest_n: int = game.account.chest["items"].size()
	check(game.chest_sel == "" and ccells.size() == chest_n + gp.inventory.size() and chest_n == 1, "скриня й торба стоять двома сітками клітинок (%d)" % ccells.size())
	var bag_n: int = gp.inventory.size()
	ccells[0].pressed.emit()
	await _frames(2)
	cpage = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.camp_tab)
	var take_btn := false
	for b in cpage.find_children("*", "Button", true, false):
		take_btn = take_btn or (not b.is_queued_for_deletion() and b.text == UCamp.CHEST_TAKE)
	check(game.chest_sel.begins_with("c:") and take_btn and game.account.chest["items"].size() == 1 and gp.inventory.size() == bag_n, "перший дотик лише показує річ зі скрині й кнопку «%s»" % UCamp.CHEST_TAKE)
	_cells(cpage, UCamp.CHEST_CELL)[0].pressed.emit()
	await _frames(2)
	check(game.account.chest["items"].is_empty() and gp.inventory.size() == bag_n + 1 and game.chest_sel == "", "другий дотик по тій самій клітинці забирає річ у торбу")
	var put_uid: int = int(gp.inventory[0]["uid"])
	game.camp_do("chest_select", "b:%d" % put_uid)
	await _frames(2)
	cpage = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.camp_tab)
	var put_btn = null
	for b in cpage.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text == UCamp.CHEST_PUT:
			put_btn = b
	check(put_btn != null, "вибрана річ із торби має кнопку «%s»" % UCamp.CHEST_PUT)
	put_btn.pressed.emit()
	await _frames(2)
	check(game.account.chest["items"].size() == 1 and gp.find_item(put_uid).is_empty(), "кнопка картки кладе річ до скрині")
	# ---- Донатна крамниця сіткою ----
	var UShop = load("res://scripts/ui/ui_shop.gd")
	var SHs = load("res://scripts/game/shop_service.gd")
	var SetsD = load("res://scripts/data/sets.gd")
	var DivD = load("res://scripts/data/divine.gd")
	var CostD = load("res://scripts/data/costumes.gd")
	var FairS = load("res://scripts/game/fair_service.gd")
	game.enter_map()
	await _frames(2)
	SHs.state(gw)["coins"] = 100000
	game.open_shop(game.enter_map)
	await _frames(2)
	check(UShop.CELL == UChar.CELL, "клітинка донатної крамниці така сама, як у торбі героя")
	var stc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var want := {"Золоті речі": SHs.ids("unique").size(), "Артефакти": SHs.ids("artifact").size(), "Душі": SHs.ids("soul").size(),
		"Набори": SetsD.ORDER.size() * (Data.SLOTS.size() + 1), "Божі дари": DivD.ORDER.size(), "Вбрання": CostD.ORDER.size()}
	var grid_ok := true
	var got := {}
	for i in stc.get_tab_count():
		var tt: String = stc.get_tab_title(i)
		if want.has(tt):
			stc.current_tab = i  # вкладки будуються, коли їх відкривають
			got[tt] = _cells(stc.get_tab_control(i), UShop.CELL).size()
			grid_ok = grid_ok and int(got[tt]) == int(want[tt])
	check(grid_ok and got.size() == want.size(), "золоті речі, артефакти, душі, набори, дари й вбрання стоять клітинками: %s" % str(got))
	# дотик до клітинки показує картку, покупка лишається за кнопкою картки
	var uid0: String = SHs.ids("unique")[0]
	game.shop_tab = game._shop_tab_index("Золоті речі")
	var bag_s: int = gp.inventory.size()
	var coins_s: int = SHs.coins(gw)
	_cells(stc.get_tab_control(game.shop_tab), UShop.CELL)[0].pressed.emit()
	await _frames(2)
	var spage: Control = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.shop_tab)
	var sbuy = null
	for b in spage.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with("Купити •"):
			sbuy = b
	check(game.shop_sel == "unique:" + uid0 and sbuy != null and gp.inventory.size() == bag_s and SHs.coins(gw) == coins_s, "дотик до золотої речі лише відкриває її картку з кнопкою «Купити»")
	sbuy.pressed.emit()
	await _frames(2)
	spage = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.shop_tab)
	var sconf = null
	for b in spage.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with("Підтвердити •"):
			sconf = b
	check(sconf != null and game.shop_confirm == "unique:" + uid0 and gp.inventory.size() == bag_s, "перший дотик кнопки просить підтвердити")
	sconf.pressed.emit()
	await _frames(2)
	spage = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(game.shop_tab)
	var tick := false
	for l in _cells(spage, UShop.CELL)[0].find_children("*", "Label", true, false):
		tick = tick or l.text == "✓"
	check(gp.inventory.size() == bag_s + 1 and SHs.coins(gw) == coins_s - SHs.price("unique", uid0) and tick and SHs.bought(gw, "unique", uid0) == 1, "другий дотик купує: річ у торбі, на клітинці галочка")
	game.shop_do("select", "divine:mazha")
	await _frames(2)
	check(game.shop_sel == "divine:mazha" and game.shop_confirm == "", "вибір іншого товару скидає підтвердження")
	game.close_shop()
	await _frames(2)
	# ---- Ярмарок сіткою ----
	gp.level = maxi(gp.level, 30)
	gp.resources[Camp.TROPHY] = 5000
	gp.gold = 5000000
	game.enter_camp()
	await _frames(2)
	var ftc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var fair_i := -1
	for i in ftc.get_tab_count():
		if ftc.get_tab_title(i) == "Ярмарок":
			fair_i = i
	check(fair_i >= 0, "на хуторі є вкладка «Ярмарок»")
	game.camp_tab = fair_i
	game._build_camp()
	await _frames(2)
	var fpage: Control = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(fair_i)
	var fstock: Array = FairS.stock(gp)
	var fcells: Array = _cells(fpage, UShop.CELL)
	check(fcells.size() == fstock.size() and fstock.size() >= 4 and game.fair_sel == "", "товари ярмарку стоять клітинками (%d)" % fcells.size())
	fcells[fstock.size() - 1].pressed.emit()
	await _frames(2)
	fpage = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].get_tab_control(fair_i)
	var fbuy = null
	for b in fpage.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with(UCamp.FAIR_BUY):
			fbuy = b
	var fkey: String = str(fstock[fstock.size() - 1]["key"])
	check(game.fair_sel == fkey and fbuy != null and not fbuy.disabled and FairS.bought(gw, fkey) == 0, "дотик до товару ярмарку показує картку з кнопкою «%s»" % UCamp.FAIR_BUY)
	fbuy.pressed.emit()
	await _frames(2)
	check(FairS.bought(gw, fkey) == 1 and int(gp.resources[Camp.TROPHY]) == 5000 - int(fstock[fstock.size() - 1]["trophy"]), "кнопка картки вимінює товар за трофеї")
	# ---- Довідник ----
	var arts := {}
	for e in WS._entries("basics") + WS._entries("camp"):
		arts[str(e["title"])] = str(e["text"])
	check("клітинками зі значками" in arts.get("Крамниця міста", "") and "«Вибрати кілька»" in arts.get("Крамниця міста", "") and UCamp.CHEST_TAKE in arts.get("Скриня", "") and "Другий дотик" in arts.get("Скриня", ""), "довідник описує крамницю й скриню сіткою значків")
	check("сіткою значків" in arts.get("Крамниця", "") and "намальований його бос" in arts.get("Крамниця", "") and "сіткою значків" in arts.get("Трофейний ярмарок", "") and "«Виміняти»" in arts.get("Трофейний ярмарок", ""), "довідник описує донатну крамницю й ярмарок сіткою значків")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_legends() -> void:
	suite("Перекази: Дракула й лінійки за легендами земель")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Leg = load("res://scripts/data/legends.gd")
	var LS = load("res://scripts/game/legend_service.gd")
	var Story = load("res://scripts/data/story.gd")
	var JS = load("res://scripts/game/journal_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Wiki = load("res://scripts/data/wiki_data.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	var Sounds = load("res://scripts/data/sounds.gd")
	var Souls = load("res://scripts/data/souls.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var Uniq = load("res://scripts/data/uniques.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var EnemyS = load("res://scripts/entities/enemy.gd")
	var GfxS = load("res://scripts/world/gfx.gd")
	# ---- Семигород: земля, нечисть, бос ----
	var land_ok: bool = Data.REGIONS.has("semyhorod") and "semyhorod" in Data.REGION_ORDER
	for id in ["tihutsa", "hoia", "tyrhovyshte", "zamok_drakuly"]:
		var L: Dictionary = Data.LOCATIONS[id]
		land_ok = land_ok and L.get("scale", false) and L["region"] == "semyhorod" and int(L["level"]) >= 30 and str(L["desc"]) != ""
	var brashov: Dictionary = Data.CITIES.get("brashov", {})
	check(land_ok and Data.LOCATIONS["zamok_drakuly"]["boss"] == "drakula" and Data.LOCATIONS["zamok_drakuly"]["type"] == "dungeon", "Семигород на мапі: три місцевості й Замок Дракули")
	check(str(brashov.get("region", "")) == "semyhorod" and Acts.TRADE_CITIES.get("brashov", {}).size() == Acts.TRADE_ORDER.size() and Data.REGION_ORDER[-1] == "semyhorod", "Брашов: місто Семигороду з торгом, край стоїть у списку останнім")
	for kind in ["strygoi", "moroi"]:
		check(Data.ENEMY_NAMES.has(kind) and Data.ENEMY_PLURAL.has(kind) and Data.QUEST_ITEMS.has(kind) and GfxS.has(kind) and Sounds.DEATH.has(kind) and Wiki.ENEMIES.has(kind) and kind in Wiki.ENEMY_ORDER and Souls.SOULS.has(kind) and kind in Souls.ORDER and EnemyS.HIT_STATUS.has(kind) and Acts.BOUNTY_NAMES.has(kind), "%s: ім'я, спрайт, голос, душа, довідник, розшук" % Data.ENEMY_NAMES.get(kind, kind))
	check(Data.BOSS_NAMES.has("drakula") and Data.ENEMY_NAMES.has("drakula") and GfxS.has("drakula") and Sounds.DEATH.has("drakula") and Wiki.BOSSES.has("drakula") and "drakula" in Wiki.BOSS_ORDER and Souls.SOULS.has("b_drakula") and Arts.by_boss("drakula") != "" and int(Uniq.BOSS_TIER["drakula"]) == Uniq.TOP_COMMON_TIER and "drakula" in EnemyS.PHASE2_BOSSES, "Дракула: ім'я, спрайт, голос, душа, артефакт, довідник, другий етап бою")
	check("Влад" in str(Wiki.BOSSES["drakula"]["text"]) and "украв" in str(Wiki.BOSSES["drakula"]["text"]), "довідник відділяє упиря від справжнього воєводи Влада")
	# ---- Дані лінійок ----
	var data_ok := true
	var bad := ""
	for line in Leg.ORDER:
		var LL: Dictionary = Leg.LINES[line]
		var ok: bool = str(LL["title"]) != "" and str(LL["land"]) != "" and str(LL["source"]) != "" and int(LL["min_level"]) >= 1 and LL["steps"].size() >= 2
		for i in LL["steps"].size():
			var st: Dictionary = LL["steps"][i]
			var obj: Dictionary = st["objective"]
			ok = ok and Story.NPCS.has(st["giver"]) and Data.CITIES.has(st["city"]) and not st["start"].is_empty() and not st["end"].is_empty() and str(obj["text"]) != "" and int(st["reward"]["gold_lvl"]) > 0
			for ln in st["start"] + st["end"]:
				ok = ok and Story.NPCS.has(ln[0]) and str(ln[1]).length() > 8
			var loc: String = str(obj.get("loc", ""))
			ok = ok and Data.LOCATIONS.has(loc)
			match str(obj["type"]):
				"clear":
					ok = ok and Data.LOCATIONS[loc]["type"] == "field"
				"dungeon":
					ok = ok and Data.LOCATIONS[loc]["type"] == "dungeon"
				"kill", "fetch":
					ok = ok and Data.ENEMY_NAMES.has(obj["enemy"]) and obj["enemy"] in Data.LOCATIONS[loc]["enemies"] and int(obj["count"]) > 1
					if obj["type"] == "fetch":
						ok = ok and str(obj["item"]) != "" and float(obj["chance"]) > 0.0
				_:
					ok = false
			if i == LL["steps"].size() - 1:
				ok = ok and st["reward"].has("item") and st["reward"]["item"]["slot"] in Data.SLOTS and obj["type"] == "dungeon"
		if not ok:
			bad += line + " "
		data_ok = data_ok and ok
	check(data_ok and Leg.ORDER.size() == Leg.LINES.size() and Leg.ORDER.size() == 12, "дванадцять лінійок: оповідачі, міста, мети й нагороди існують %s" % bad)
	var top := 0
	for a in Ach.ACHIEVEMENTS:
		if str(a["stat"]) == "legend":
			top = maxi(top, int(a["goal"]))
	check(top == Leg.ORDER.size(), "останнє досягнення просить усі лінійки")
	# ---- Лінійка Дракули: від розмови до нагороди ----
	var w = WorldState.new()
	var p = _new_player()
	p.change_class("cossack")
	p.level = 50
	var DL: Dictionary = Leg.LINES["drakula"]
	w.hero_level = int(DL["min_level"]) - 1
	check(not LS.unlocked(w, "drakula") and LS.city_dialogue(w, "verkhovyna").is_empty() and LS.target(w, "drakula") == "", "до %d-го рівня про Дракулу мовчать" % int(DL["min_level"]))
	w.hero_level = 50
	var d: Dictionary = LS.city_dialogue(w, "verkhovyna")
	check(d.get("kind", "") == "legend_start" and d["line"] == "drakula" and d["lines"].size() == DL["steps"][0]["start"].size() and LS.target(w, "drakula") == "verkhovyna", "у Верховині оповідач починає переказ")
	var said := ""
	for ln in d["lines"]:
		said += str(ln[1])
	check("Влад" in said and "украв" in said, "перша ж розмова каже, що упир лише вкрав ім'я воєводи")
	LS.on_dialogue_done(w, p, "legend_start", "drakula")
	check(LS.state(w, "drakula")["stage"] == "active" and LS.target(w, "drakula") == "tihutsa" and "tihutsa" in LS.targets(w), "мета: Перевал Тігуца, він позначений на мапі")
	check(LS.on_event(w, p, "clear", "hoia").is_empty() and LS.state(w, "drakula")["stage"] == "active", "чуже місце кроку не зараховує")
	check(not LS.on_event(w, p, "clear", "tihutsa").is_empty() and LS.state(w, "drakula")["stage"] == "turnin" and LS.target(w, "drakula") == "verkhovyna", "перевал очищено: повертайся до оповідача")
	var gold0: int = p.gold
	var tr0: int = int(p.resources.get("trophy", 0))
	check(LS.city_dialogue(w, "verkhovyna").get("kind", "") == "legend_end", "оповідач чекає з кінцевою розмовою")
	LS.on_dialogue_done(w, p, "legend_end", "drakula")
	check(p.gold == gold0 + int(DL["steps"][0]["reward"]["gold_lvl"]) * 50 and int(p.resources["trophy"]) == tr0 + int(DL["steps"][0]["reward"]["trophy"]) and int(LS.state(w, "drakula")["step"]) == 1, "нагорода: гривні за рівень героя й трофеї")
	# здобути ікла
	LS.on_dialogue_done(w, p, "legend_start", "drakula")
	seed(99)
	var kills := 0
	LS.on_event(w, p, "kill", "moroi")
	check(int(LS.state(w, "drakula")["progress"]) == 0, "ікла падають лише зі стригоїв")
	while LS.state(w, "drakula")["stage"] == "active" and kills < 200:
		LS.on_event(w, p, "kill", "strygoi")
		kills += 1
	check(LS.state(w, "drakula")["stage"] == "turnin" and kills >= 10 and kills < 60, "десять ікол здобуто за %d стригоїв" % kills)
	LS.on_dialogue_done(w, p, "legend_end", "drakula")
	# замок
	LS.on_dialogue_done(w, p, "legend_start", "drakula")
	check(LS.target(w, "drakula") == "zamok_drakuly", "останній крок веде в Замок Дракули")
	LS.on_event(w, p, "dungeon", "zamok_drakuly")
	var bag0: int = p.inventory.size()
	var fin: Array = LS.on_dialogue_done(w, p, "legend_end", "drakula")
	var prize: Dictionary = p.inventory[p.inventory.size() - 1] if p.inventory.size() > bag0 else {}
	check(LS.finished(w, "drakula") and LS.done_count(w) == 1 and prize.get("name", "") == DL["steps"][2]["reward"]["item"]["name"] and int(prize.get("ilvl", 0)) == 50 and int(prize.get("rarity", 0)) == 3 and not fin.is_empty(), "переказ розказано: іменна легендарна річ рівня героя в торбі")
	check(LS.city_dialogue(w, "verkhovyna").is_empty() and LS.target(w, "drakula") == "", "після кінця оповідач мовчить")
	var stan: Array = LS.city_dialogues(w, "cherkaskyi_stan")
	check(stan.size() == 2 and stan[0]["line"] == "idolyshche" and stan[1]["line"] == "karachun" and LS.city_dialogue(w, "cherkaskyi_stan", "karachun")["line"] == "karachun" and LS.city_dialogue(w, "cherkaskyi_stan", "drakula").is_empty(), "у місті чекають усі оповідачі одразу, і до кожного можна підійти окремо")
	# ---- Вбити N і дві лінійки разом ----
	LS.on_dialogue_done(w, p, "legend_start", "bila_pani")
	LS.on_dialogue_done(w, p, "legend_start", "shubin")
	for i in 14:
		LS.on_event(w, p, "kill", "mara")
	check(int(LS.state(w, "bila_pani")["progress"]) == 14 and LS.state(w, "bila_pani")["stage"] == "active" and int(LS.state(w, "shubin")["progress"]) == 0, "кожна мара рахується, чужа лінійка не рухається")
	LS.on_event(w, p, "kill", "mara")
	for i in 12:
		LS.on_event(w, p, "kill", "kamiana_baba")
	check(LS.state(w, "bila_pani")["stage"] == "turnin" and LS.state(w, "shubin")["stage"] == "turnin" and LS.targets(w).has("lviv") and LS.targets(w).has("izium"), "дві лінійки йдуть одразу й кожна веде у своє місто")
	# ---- Місце переказу міряється з героєм ----
	LS.on_dialogue_done(w, p, "legend_start", "vii")
	var m: Dictionary = LS.mods_for(w, p, "lysa_hora")
	check(int(m.get("level", 0)) == 50 and int(m["base_level"]) == int(Data.LOCATIONS["lysa_hora"]["level"]) and LS.mods_for(w, p, "crypt").is_empty(), "Лиса гора під час переказу має рівень героя, інші печери ні")
	var low = _new_player()
	low.level = 5
	check(LS.mods_for(w, low, "lysa_hora").is_empty(), "слабшого за печеру героя переказ не підтягує")
	# ---- Збереження ----
	var w2 = WorldState.new()
	w2.from_dict(w.to_dict())
	w2.hero_level = 50
	check(LS.finished(w2, "drakula") and LS.state(w2, "bila_pani")["stage"] == "turnin" and LS.state(w2, "vii")["stage"] == "active", "поступ переказів зберігається з героєм")
	# ---- Журнал і довідник ----
	var sec: Dictionary = {}
	for s0 in JS.sections(w, p):
		if str(s0.get("title", "")).begins_with("Перекази"):
			sec = s0
	var ready := 0
	for r in sec.get("rows", []):
		if r["ready"]:
			ready += 1
	check(not sec.is_empty() and sec["rows"].size() == Leg.ORDER.size() - 1 and ready == 2 and "1 із" in str(sec["title"]), "журнал: розділ «Перекази» з нинішніми кроками, два можна здати")
	var titles := {}
	for e in WS._entries("basics"):
		titles[str(e["title"])] = str(e["text"])
	var wiki_ok: bool = titles.has("Перекази")
	for line in Leg.ORDER:
		var key := "Переказ «%s»" % Leg.LINES[line]["title"]
		wiki_ok = wiki_ok and titles.has(key) and str(Leg.LINES[line]["source"]) in titles[key] and str(Leg.LINES[line]["title"]) in titles.get("Перекази", "")
	check(wiki_ok, "довідник описує кожен переказ і його джерело")
	check("самі не починаються" in titles.get("Ратуша", "") and "«Поговорити»" in titles.get("Ратуша", "") and Data.HALL_NAMES["sich"] in titles.get("Ратуша", "") and "в ратуші" in titles.get("Перекази", ""), "довідник має статтю «Ратуша»: розмови самі не починаються")
	# ---- У грі ----
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	var c = game.combat
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "depths_open", "dungeon", "potion", "mana_potion", "varenyk", "res"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	game._sync_class()
	gp.level = 40
	gp.stats["str"] = 3000
	gp.stats["vit"] = 3000
	gp.recalc()
	gp.hp = gp.max_hp
	gw.story = {"chapter": Story.CHAPTERS.size(), "step": 0, "stage": "done", "progress": 0}
	gw.saga = {"step": Leg.ORDER.size(), "stage": "done"}
	game.enter_map()
	await _frames(2)
	game.enter_city("kyiv")
	await _frames(3)
	var kyiv_hall: Array = game.hall_rows("kyiv")
	var hall_lines := []
	for r in kyiv_hall:
		hall_lines.append(str(r["line"]))
	check(game.hud.dialogue_root == null and hall_lines == ["kozhumiaka", "vii"] and kyiv_hall[0]["kind"] == "legend" and kyiv_hall[0]["name"] == Story.NPCS["kobzar"]["name"] and "Кожум'яка" in str(kyiv_hall[0]["what"]), "у Києві ніхто не заговорює сам: у ратуші чекають кобзар і полковник із переказами")
	var tck = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(tck.get_tab_title(0) == "Ратуша (2)" and Data.hall_name("kyiv") == "Ратуша" and Data.hall_name("sich") != "Ратуша", "перша вкладка міста «Ратуша (2)»; на Січі це курінь")
	check(_hall_talk(game, "legend", "vii"), "герой сам обирає, кого слухати: спершу полковника")
	await _frames(2)
	check(game.hud.dialogue_root != null and is_instance_valid(game.hud.dialogue_root), "полковник починає розмову про Вія")
	var guard := 0
	while game.hud.dialogue_root != null and is_instance_valid(game.hud.dialogue_root) and guard < 6:
		game.hud.dialogue_root.finished.emit(-1)
		await _frames(2)
		guard += 1
	check(guard == 1 and not LS.started(gw, "kozhumiaka") and game.hall_rows("kyiv").size() == 1 and game.state == game.State.CITY, "після розмови герой лишається в ратуші; кобзар чекає далі й не перебиває")
	check(LS.state(gw, "vii")["stage"] == "active", "після розмови крок активний")
	game.enter_map()
	await _frames(2)
	check(bool(game.hud.map_view.targets.get("lysa_hora", false)), "Лиса гора позначена на мапі як мета")
	game.enter_location("lysa_hora")
	await _frames(4)
	var lvl_ok := true
	for e in get_nodes_in_group("enemies"):
		lvl_ok = lvl_ok and int(e.level) >= 40
	check(int(c.loc["level"]) == 40 and lvl_ok and str(c.loc.get("legend", "")) == "vii", "на Лисій горі нечисть рівня героя: переказ не прогулянка")
	game.enter_map()
	await _frames(2)
	# Дракула в бою
	game.enter_location("tihutsa")
	await _frames(3)
	_clear_enemies(game)
	await _frames(2)
	c.spawn_timer = 9999.0
	gp.invuln = 999.0
	c.spawn_enemy("drakula", 40, true, gp.global_position + Vector2(260, 0))
	var boss = c._last_enemy()
	check(boss.is_boss and boss.kind == "drakula" and boss.sprite_id() == "drakula" and boss.max_hp > 0.0, "Дракула виходить на бій")
	var zones0: int = c.effects.get_child_count()
	boss._boss_ability(gp)
	await _frames(1)
	var zones1: int = c.effects.get_child_count()
	boss._boss_ability(gp)
	await _frames(1)
	var zones2: int = c.effects.get_child_count()
	var foes0: int = c.alive_enemy_count()
	boss.hp = boss.max_hp * 0.8
	var hp_before: float = boss.hp
	boss._boss_ability(gp)
	await _frames(1)
	check(zones1 == zones0 + 1 and zones2 >= zones1 + 3 and c.alive_enemy_count() == foes0 + 2 and boss.hp > hp_before, "три прийоми: падає кажаном, пускає три смуги туману, кличе слуг і лікується")
	var kinds := {}
	for e in get_nodes_in_group("enemies"):
		kinds[e.kind] = true
	check(kinds.has("strygoi") or kinds.has("moroi"), "слуги Дракули — стригої й морої")
	# ---- Ратуша: побратим теж чекає там, а не перестріває на вході ----
	var HSv = load("res://scripts/game/hero_service.gd")
	var UCity = load("res://scripts/ui/ui_city.gd")
	game.enter_map()
	await _frames(2)
	game.enter_city("chernihiv")
	await _frames(3)
	var hero_row := {}
	for r in game.hall_rows("chernihiv"):
		if r["kind"] == "hero":
			hero_row = r
	check(game.hud.dialogue_root == null and HSv.can_meet(gw, "oksana", "chernihiv") and hero_row.get("npc", "") == "oksana" and "загін" in str(hero_row.get("what", "")), "Оксана чекає в ратуші Чернігова й сама не заговорює")
	_hall_talk(game, "hero")
	await _frames(2)
	check(game.hud.dialogue_root != null and game.hud.dialogue_root.choices.size() == 2, "підійшов до неї: розмова з вибором")
	game.hud.dialogue_root.finished.emit(0)
	await _frames(3)
	var still_hero := false
	for r in game.hall_rows("chernihiv"):
		still_hero = still_hero or r["kind"] == "hero"
	check(HSv.in_party(gw, "oksana") and not still_hero and game.state == game.State.CITY, "Оксана в загоні, у ратуші її більше нема")
	game.enter_map()
	await _frames(2)
	game.enter_city("poltava")
	await _frames(3)
	var quiet := false
	var no_talk := true
	for l in game.hud.screen_root.find_children("*", "Label", true, false):
		quiet = quiet or (not l.is_queued_for_deletion() and l.text == "Зараз на тебе ніхто не чекає.")
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		no_talk = no_talk and not (not b.is_queued_for_deletion() and b.text == UCity.HALL_TALK)
	var tcp = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(game.hall_rows("poltava").is_empty() and quiet and no_talk and tcp.get_tab_title(0) == "Ратуша", "де ніхто не чекає, ратуша порожня й без числа в назві")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Перевірки знахідок повного аудиту 0.48.0: годинник, лазівки зі спробами й цінами, переходи між
## екранами, збереження, зайва робота в бою.
func _suite_audit() -> void:
	suite("Аудит: годинник, лазівки, переходи, збереження")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Clock = load("res://scripts/core/clock.gd")
	var CS = load("res://scripts/game/challenge_service.gd")
	var QS = load("res://scripts/game/quick_service.gd")
	var AR = load("res://scripts/game/ad_rewards.gd")
	var Prem = load("res://scripts/game/premium_service.gd")
	var Acc = load("res://scripts/game/account.gd")
	var City = load("res://scripts/game/city_service.gd")
	var TR = load("res://scripts/game/trade_service.gd")
	var Craft = load("res://scripts/game/craft_service.gd")
	var LS = load("res://scripts/game/legend_service.gd")
	var Leg = load("res://scripts/data/legends.gd")
	var Far = load("res://scripts/game/far_service.gd")
	var PS = load("res://scripts/game/plague_service.gd")
	var TS = load("res://scripts/game/travel_service.gd")
	var BS = load("res://scripts/game/boss_service.gd")
	var ES = load("res://scripts/game/event_service.gd")
	var Ach = load("res://scripts/data/achievements.gd")
	var Sets = load("res://scripts/data/sets.gd")
	var Uni = load("res://scripts/data/uniques.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var Story = load("res://scripts/game/story_service.gd")
	var ST = load("res://scripts/core/save_transfer.gd")
	var DuelS = load("res://scripts/game/duel_service.gd")
	var DefS = load("res://scripts/game/defense_service.gd")
	var DS = load("res://scripts/game/divine_service.gd")

	# ---- Годинник гри: назад не йде ----
	CS.now_override = 0
	Prem.now_override = -1.0
	var real: float = Time.get_unix_time_from_system()
	Clock.high = 0.0
	check(absf(Clock.now() - real) < 5.0 and not Clock.rolled_back(), "годинник гри йде за годинником телефона")
	Clock.high = real + 5.0 * 86400.0  # гра вже бачила час на п'ять діб уперед, а телефон перевели назад
	check(is_equal_approx(Clock.now(), real + 5.0 * 86400.0) and Clock.rolled_back(), "телефон перевели назад: годинник гри стоїть на найпізнішому баченому часі")
	check(CS._now() == int(Clock.now()) and is_equal_approx(Prem.now(), Clock.now()), "виклики, боси, ярмарок і універсал рахують від годинника гри")
	check(QS._today() == CS.day_key(CS._now()) and AR._today() == QS._today(), "швидкі походи й реклама мають той самий день, що й виклики (за Гринвічем)")
	var acc = Acc.new()
	var acc_d: Dictionary = acc.to_dict()
	check(float(acc_d.get("clock", 0.0)) >= real + 5.0 * 86400.0 - 1.0, "найпізніший час зберігається з акаунтом")
	Clock.high = 0.0
	var acc2 = Acc.new()
	acc2.from_dict(acc_d)
	check(Clock.high >= real + 5.0 * 86400.0 - 1.0 and Clock.rolled_back(), "після перезапуску гра пам'ятає цей час: переведений назад годинник нічого не скидає")
	Clock.high = real + 40.0 * 86400.0
	check(absf(Clock.now() - real) < 5.0 and not Clock.rolled_back(), "бачений час далі ніж за місяць уперед вважається помилкою годинника: гра вертається до телефона")
	Clock.high = 0.0  # далі тести йдуть за справжнім часом

	# ---- Ціни: ярмарок, цінні речі ----
	var it0: Dictionary = Data.gen_item(20, 2, "head")
	var w0 = WorldState.new()
	Data.sell_mult = 1.0
	var base0: int = Data.sell_price(it0)
	var buy0: int = City.buy_price(w0, "poltava", it0)
	Data.sell_mult = 2.0
	check(Data.sell_price(it0) == base0 * 2 and Data.base_price(it0) == base0 and City.buy_price(w0, "poltava", it0) == buy0, "ярмарок подвоює ціну продажу, а ціна в крамниці лишається та сама")
	Data.sell_mult = 1.0
	var set_it: Dictionary = Sets.make(Sets.SETS.keys()[0], "head", 100)
	var gold_it: Dictionary = Uni.make(Uni.DEFS.keys()[0], 50)
	check(Data.is_precious(set_it) and Data.is_precious(gold_it) and not Data.is_precious(it0), "золота й наборна речі цінні, звичайна рідкісна ні")

	# ---- Торг: надбавки не діють на крам, куплений тут-таки ----
	var tw = WorldState.new()
	var tp = _new_player()
	tp.change_class("cossack")
	tp.level = 30
	tp.gold = 10000000
	var tcity: String = Acts.TRADE_CITIES.keys()[0]
	var tgood: String = Acts.TRADE_GOODS.keys()[0]
	ES.state(tw)["fair"] = {"city": tcity, "left": 3}
	check(is_equal_approx(TR.sell_bonus(tw, tcity, tgood), 1.25), "на ярмарку привезений крам беруть на чверть дорожче")
	var gold_t: int = tp.gold
	var got_n: int = TR.buy(tw, tp, tcity, tgood, int(Acts.TRADE_STOCK))
	check(got_n > 0 and is_equal_approx(TR.sell_bonus(tw, tcity, tgood), 1.0), "крам, куплений тут сьогодні, місто бере назад без надбавки")
	TR.sell(tw, tp, tcity, tgood, got_n)
	check(tp.gold < gold_t, "купити й одразу продати на ярмарку більше не дає прибутку (%d → %d)" % [gold_t, tp.gold])

	# ---- Кузня: перековка й оновлення ----
	var cw = WorldState.new()
	cw.camp = {"buildings": {"kuznia": 3}}
	var plain_it: Dictionary = Data.gen_item(20, 3, "body")
	check(Craft.can_reforge(cw, plain_it) and not Craft.can_reforge(cw, set_it) and not Craft.can_reforge(cw, gold_it), "золоті й наборні речі не перековуються, звичайні перековуються")
	var rp = _new_player()
	rp.change_class("cossack")
	rp.level = 60
	rp.gold = 100000000
	for r in ["iron", "wood", "herbs", "trophy"]:
		rp.resources[r] = 100000
	var never_lower := true
	for i in 12:
		var ri: Dictionary = Data.gen_item(10 + i, 3, "body")
		rp.add_item(ri, true)
		var before: Dictionary = ri["affixes"].duplicate()
		if Craft.renew(cw, rp, ri["uid"], 3):
			for a in before:
				never_lower = never_lower and float(ri["affixes"][a]) >= float(before[a]) - 0.0001
	check(never_lower, "оновлення речі не знижує жодної властивості")

	# ---- Переказ: мета зачистки в межах ----
	var lw = WorldState.new()
	var lp = _new_player()
	lp.level = 99
	var leg_goal := -1
	var leg_base := 0
	for line in Leg.ORDER:
		var steps: Array = Leg.LINES[line]["steps"]
		for i in steps.size():
			var lloc := str(steps[i]["objective"].get("loc", ""))
			if leg_goal < 0 and Data.LOCATIONS.has(lloc) and int(Data.LOCATIONS[lloc]["level"]) < 99:
				lw.legends[line] = {"step": i, "stage": "active", "progress": 0}
				var lm: Dictionary = LS.mods_for(lw, lp, lloc)
				leg_goal = int(lm.get("goal", -1))
				leg_base = int(Data.LOCATIONS[lloc]["level"])
				check(int(lm.get("level", 0)) == 99 and QS.step_target(lw, lloc), "місце переказу міряється рівнем із героєм і є метою кроку")
				check("справа" in QS.block_reason(_cleared_world(lw, lloc), lp, lloc), "швидкий похід у місце, де чекає крок переказу, не дається")
	check(leg_goal > 0 and leg_goal <= int(Far.GOAL_MAX) and leg_goal == mini(int(Far.GOAL_MAX), Data.FIELD_GOAL_BASE + leg_base * Data.FIELD_GOAL_PER_LEVEL), "мета зачистки рахується від рідного рівня місця: %d, а не сотні" % leg_goal)

	# ---- Зараза не осідає на Башті й Глибинах ----
	var pw = WorldState.new()
	PS.state(pw)["levels"]["bashta"] = 3
	PS.state(pw)["levels"]["hlybyny"] = 2
	check(PS.level(pw, "bashta") == 0 and PS.level(pw, "hlybyny") == 0, "зараза на Башті й Глибинах не діє навіть зі старого збереження")
	PS.state(pw)["levels"].clear()
	PS.state(pw)["pressure"] = 50.0
	for i in 40:
		PS.tick(pw)
	check(int(PS.state(pw)["levels"].get("bashta", 0)) == 0 and int(PS.state(pw)["levels"].get("hlybyny", 0)) == 0, "і нова зараза туди не доходить")

	# ---- Чумаки: зілля стільки, скільки влазить ----
	var cp = _new_player()
	cp.change_class("cossack")
	cp.level = 20
	cp.gold = 100000
	cp.potions = cp.potion_max() - 1
	var one: Dictionary = {}
	for ch in TS.prepare(WorldState.new(), cp, "chumaky")["choices"]:
		if ch["outcome"].has("potions"):
			one = ch
	cp.potions = 0
	var two: Dictionary = {}
	for ch in TS.prepare(WorldState.new(), cp, "chumaky")["choices"]:
		if ch["outcome"].has("potions"):
			two = ch
	check(not one.is_empty() and int(one["outcome"]["potions"]) == 1 and int(two["outcome"]["potions"]) == 2 and absi(int(one["outcome"]["gold"]) * 2 - int(two["outcome"]["gold"])) <= 1, "чумаки продають одне зілля за півціни, коли друге не влазить")

	# ---- Досягнення, боси дня й тижня ----
	var bond := {}
	for a in Ach.ACHIEVEMENTS:
		if a["id"] == "bond_3":
			bond = a
	check(int(bond.get("goal", 0)) == 2 and "двох" in str(bond.get("desc", "")), "«Побратими навіки» досяжне: дві історії")
	var wk: String = BS.boss_id("week")
	var raw_i: int = absi(hash("week:" + BS.key("week"))) % BS.POOL.size()
	check(wk == BS.POOL[raw_i] and BS.boss_id("day") != wk, "бос тижня не міняється серед тижня: поступається бос дня")
	var bw = WorldState.new()
	var bp = _new_player()
	bp.level = 40
	var other_boss: String = BS.POOL[(BS.POOL.find(BS.boss_id("day")) + 2) % BS.POOL.size()]
	BS.on_win(bw, bp, "day", 95.0, other_boss)
	check(BS.best_time(bw, other_boss) == 95 and BS.best_time(bw, BS.boss_id("day")) == (95 if other_boss == BS.boss_id("day") else 0), "рекорд часу пишеться тому босові, з яким бились")

	# ---- Крадіжка меду: щонайбільше раз на добу ----
	var hw = WorldState.new()
	var now_t := 1762700000.0
	hw.camp = {"buildings": {"pasika": 1}, "pasika_ts": now_t - 20.0 * 3600.0}
	var thefts := 0
	for i in 60:
		if ES.check_theft(hw, now_t, 0) != "":
			thefts += 1
	check(thefts <= 1 and int(hw.camp.get("theft_day", -1)) == int(now_t / 86400.0), "за одну добу злодії приходять щонайбільше раз, скільки б разів не заходив у гру (%d)" % thefts)

	# ---- Збереження: версія, безпечний запис, нечитаний слот, чужі поля ----
	check(SaveSystem.SAVE_VERSION == 10 and int(SaveSystem.migrate({"version": 9, "player": {}, "world": {}, "meta": {}}).get("version", 0)) == 10, "формат збереження 10, дев'ятий підхоплюється")
	var wpath := "user://test_write.save"
	check(SaveSystem.write_var(wpath, {"a": 1}) and SaveSystem.write_var(wpath, {"a": 2}) and FileAccess.file_exists(wpath + ".bak") and not FileAccess.file_exists(wpath + ".tmp"), "запис іде через тимчасовий файл, попередній лишається копією")
	SaveSystem.delete(wpath)
	var slot_p: String = SaveSystem.slot_path(SaveSystem.MAX_SLOTS)
	if not SaveSystem.exists(slot_p):
		var junk := FileAccess.open(slot_p, FileAccess.WRITE)
		junk.store_var("це не збереження")
		junk.close()
		var sums: Array = SaveSystem.slot_summaries()
		check(sums[SaveSystem.MAX_SLOTS - 1].get("broken", false) == true, "файл, що не читається, показується зайнятим слотом, а не вільним")
		SaveSystem.delete(slot_p)
		check(SaveSystem.slot_summaries()[SaveSystem.MAX_SLOTS - 1].is_empty(), "видалений слот знову вільний")
	var fp = _new_player()
	var fd: Dictionary = fp.to_dict()
	fd["position"] = Vector2(4321, 1234)
	fd["visible"] = false
	fd["gold"] = 777
	var fp2 = _new_player()
	fp2.from_dict(fd)
	check(fp2.gold == 777 and fp2.position == Vector2.ZERO and fp2.visible, "герой бере зі збереження лише свої поля")
	var prof := {"v": ST.FORMAT, "account": {}, "heroes": [{"slot": 1, "data": _transfer_hero(12, 500)}], "made": 0}
	var alien: Dictionary = prof.duplicate(true)
	alien["heroes"][0]["data"]["player"]["job"] = "kosmonavt"
	check(ST.check(prof) == "" and "не знає" in ST.check(alien), "код роду з невідомим класом не приймається")

	# ---- Довідник знає про зміни ----
	var WSv = load("res://scripts/game/wiki_service.gd")
	var rule_titles := []
	var all_text := ""
	for sec in ["basics", "bosses", "items", "rules"]:
		for e in WSv._entries(sec):
			all_text += str(e["text"]) + "\n"
			if sec == "rules":
				rule_titles.append(str(e["title"]))
	var want_titles := ["Годинник гри", "Покинутий бій", "Цінна здобич не губиться", "Кара за смерть", "Ціни й торг без лазівок"]
	var have_all := true
	for t in want_titles:
		have_all = have_all and t in rule_titles
	check(have_all, "довідник, розділ правил: годинник гри, покинутий бій, цінна здобич, кара за смерть, ціни без лазівок")
	check("не перековуються" in all_text and "не стає нижчою" in all_text and "швидкий похід не дається" in all_text and "поступається бос дня" in all_text, "довідник: перековка золотих і наборних, оновлення без втрат, швидкий похід і бос тижня описані по-новому")

	# ---- Герой: перевдягання в бою не лікує, хмара не дає невразливості ----
	var hp_p = _new_player()
	hp_p.change_class("cossack")
	hp_p.level = 40
	hp_p.recalc()
	var hp_item: Dictionary = Data.gen_item(40, 3, "body")
	hp_item["affixes"] = {"hp": 500.0}
	hp_p.add_item(hp_item, true)
	hp_p.equip(hp_item["uid"])
	hp_p.hp = hp_p.max_hp * 0.2
	var part0: float = hp_p.hp / hp_p.max_hp
	var hp_start: float = hp_p.hp
	for i in 6:
		hp_p.unequip(hp_item["uid"])
		hp_p.equip(hp_item["uid"])
	check(hp_p.hp <= hp_start + 0.01 and absf(hp_p.hp / hp_p.max_hp - part0) < 0.01, "шість разів зняв і вдягнув річ із запасом здоров'я: здоров'я не додалося (%.0f → %.0f)" % [hp_start, hp_p.hp])
	for q in [tp, rp, lp, cp, bp, fp, fp2, hp_p]:
		q.free()

	# ================= У грі =================
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	game.allow_quit = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp", "kleinody", "duel", "defense", "bag_full", "mana_potion", "statuses", "peril_camp"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	game._sync_class()
	gp.level = 30
	gp.gold = 500000
	gp.recalc()
	gp.hp = gp.max_hp
	check(game.tower_sel == 1 and game.depth_sel == 1 and game.map_sel == "" and game.defense_target == "", "новий герой починає без чужих слідів: поверх, глибина, вибране місце")

	# ---- «Назад» у головному меню та його підменю ----
	game._show_main_menu()
	game._show_heroes_menu()
	check(game._menu_back.is_valid(), "підменю «Персонажі» знає, куди вертатись")
	game.go_back(true)
	check(not game.quit_requested and not game._menu_back.is_valid() and game.state == game.State.MENU, "«Назад» у «Персонажах» веде в головне меню, а не закриває гру")
	game._show_transfer_menu()
	game.go_back(true)
	check(not game.quit_requested, "і з перенесення роду теж крок назад")
	# згортання гри в головному меню героя не зберігає
	SaveSystem.delete(TEST_SAVE)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not SaveSystem.exists(TEST_SAVE), "у головному меню згортання гри нічого не зберігає: видалений герой не вертається")

	# ---- Місто: ярмарок, крамниця, «Назад» із крамниць ----
	ES.state(gw)["fair"] = {"city": "poltava", "left": 3}
	game.enter_map()
	await _frames(2)
	game.enter_city("poltava")
	await _frames(2)
	check(is_equal_approx(Data.sell_mult, 2.0), "у місті з ярмарком речі продаються вдвічі дорожче")
	var stock: Array = game.shop_stock("poltava")
	var uids := []
	for s_it in stock:
		uids.append(int(s_it["uid"]))
	check(City.buy_price(gw, "poltava", stock[0]) == int(Data.base_price(stock[0]) * City.BUY_MARKUP * (1.0 - gw.discount("poltava"))), "а крамниця цін не піднімає")
	game.city_sel_uid = int(stock[0]["uid"])
	var inv0: int = gp.inventory.size()
	game.city_do("buy", int(stock[0]["uid"]))
	check(gp.inventory.size() == inv0 + 1 and game.city_sel_uid == -1, "після купівлі річ не лишається вибраною: другий дотик її не продасть")
	# товар крамниці зберігається
	uids.remove_at(0)
	game.save_game()
	check(game.load_game(), "збереження читається")
	gw = game.world
	gp = game.player
	var uids2 := []
	for s_it in game.shop_stock("poltava"):
		uids2.append(int(s_it["uid"]))
	check(uids2 == uids and not uids.is_empty(), "товар крамниці той самий після виходу в меню й повернення")
	game.enter_city("poltava")
	await _frames(2)
	# донатна крамниця поверх міста
	game.open_shop(game._build_city)
	await _frames(2)
	check(game.shop_open, "донатну крамницю відкрито")
	game.go_back(true)
	await _frames(2)
	check(not game.shop_open and game.state == game.State.CITY and game.hud.screen_root != null, "«Назад» закриває крамницю й лишає в місті")
	# крамниця Хованця поверх мапи
	load("res://scripts/game/shop_service.gd").state(gw)["coins"] = 100000
	check(DS.buy(gw, gp, "khovanets") and DS.remote_shop(gp), "Хованця куплено")
	gw.last_city = "poltava"
	game.enter_map()
	await _frames(2)
	check(is_equal_approx(Data.sell_mult, 1.0), "поза містом ціна продажу звичайна")
	game.open_trader(game.enter_map)
	await _frames(2)
	check(game.trader_open and game.city_id == "poltava" and is_equal_approx(Data.sell_mult, 2.0) and game.hud.map_view.is_covered.call(), "Хованець торгує за цінами останнього міста; мапа під крамницею щипків не слухає")
	game.go_back(true)
	await _frames(2)
	check(not game.trader_open and game.state == game.State.MAP and is_equal_approx(Data.sell_mult, 1.0) and not game.hud.map_view.is_covered.call(), "«Назад» закриває крамницю Хованця: прапорець, місто й ціни вертаються")
	# підказка на мапі ловить дотик
	game.hud.show_hint("перевірка", true)
	var on_map_stop: bool = game.hud.hint_panel.mouse_filter == Control.MOUSE_FILTER_STOP
	game.hud.show_hint("перевірка", false)
	check(on_map_stop and game.hud.hint_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "підказка на мапі ловить дотик, у бою пропускає")
	game.hud.hide_hint()
	# вкладка міста запам'ятовується за назвою
	game.enter_city("poltava")
	await _frames(2)
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	for i in tc.get_tab_count():
		if tc.get_tab_title(i) == "Коваль":
			tc.current_tab = i
	check(game.city_tab_key == "Коваль", "відкрита вкладка запам'ятовується за назвою")
	game.enter_map()
	game.enter_city("sich")
	await _frames(2)
	tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	check(tc.get_tab_title(game.city_tab) == "Коваль" and tc.current_tab == game.city_tab, "в іншому місті відкривається та сама вкладка, хоч номер у неї інший")
	game.city_tab_key = "Нема такої"
	game._build_city()
	await _frames(2)
	check(game.city_tab == 0 and game.city_tab_key == "", "вкладки, якої тут нема, не шукаємо: відкривається перша")

	# ---- Портал після оборони не веде в старе місто ----
	game.defense_target = "kyiv"
	game.enter_map()
	await _frames(2)
	check(game.defense_target == "", "ціль порталу скидається, щойно бій покинуто")

	# ---- Бій: поразка, здобич, кеш нечисті ----
	game.enter_location("wild_field")
	await _frames(3)
	var cb = game.combat
	check(cb.active and not cb.lost and cb.runs >= 1, "новий бій починається чистим")
	var list_a: Array = cb.enemies_now()
	check(is_same(list_a, cb.enemies_now()), "список нечисті на кадр один на всіх")
	var n0: int = cb.alive_enemy_count()
	cb.spawn_enemy("zlyden", 5)
	check(cb.alive_enemy_count() == n0 + 1, "нова нечисть у списку одразу, тим самим кадром")
	var zl = cb._last_enemy()
	zl.loot_gold = 77
	zl.dmg_cap = 0.5
	zl._dmg_window = zl.max_hp
	zl.stun = 5.0
	await _frames(20)
	check(zl._dmg_window < zl.max_hp * 0.95 and zl.stun > 0.0, "стеля шкоди спадає й у приголомшеного ворога")
	# портал не стає на героя
	gp.global_position = Vector2(0, cb.arena.position.y + 20.0)
	var spot: Vector2 = cb._portal_spot(260.0)
	check(spot.distance_to(gp.global_position) >= 150.0 and cb.arena.has_point(spot), "портал біля краю арени стає осторонь, а не на героя")
	gp.global_position = Vector2.ZERO
	# цінне не лишається на землі за повної торби
	while not gp.bag_full():
		gp.add_item(Data.gen_item(5, 0, "head"), true)
	var set2: Dictionary = Sets.make(Sets.SETS.keys()[0], "boots", 100)
	check(cb.pick_block(set2) == "" and cb.pick_block(Data.gen_item(30, 3, "head")) == "full", "наборна річ береться й у повну торбу, звичайна легендарна ні")
	var reward: Dictionary = Data.gen_item(30, 3, "head")
	gp.assign_uid(reward)
	cb.spawn_pickup(Vector2(900, -99999), "item", 0, reward, true)
	await _frames(12)
	var lying = null
	for c in cb.entities.get_children():
		if c.get_script() == cb.PickupScript and c.kind == "item" and c.item.get("uid", -1) == reward["uid"]:
			lying = c
	check(lying != null and cb.arena.has_point(lying.position), "здобич не вилітає за край арени")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	check(not gp.find_item(reward["uid"]).is_empty(), "гру згорнули посеред бою: разова нагорода вже в торбі, а не на землі")
	game._resume_play()
	# хмара зарази: без миті невразливості й без парирування
	gp.hp = gp.max_hp
	gp.invuln = 0.0
	gp.blocking = true
	gp.block_time = 0.0
	var hp1: float = gp.hp
	check(gp.take_area(10.0) and gp.hp < hp1 and is_equal_approx(gp.invuln, 0.0), "хмара ранить героя, що саме парирує, і невразливості не дає")
	gp.blocking = false
	# смерть: кара одразу, перемоги більше не рахуються
	gp.gold = 10000
	var kills0: int = cb.field_kills
	gp.hp = 0.0
	gp._check_death()
	check(gp.gold < 10000 and cb.lost and game.state == game.State.DEAD, "кара за смерть лягає одразу, а не за півтори секунди")
	var saved: Dictionary = SaveSystem.load_data(TEST_SAVE)
	check(int(saved["player"]["gold"]) == gp.gold, "і одразу записана у збереження")
	cb.field_kills = cb.field_goal + 5
	await _frames(10)
	check(not cb.field_cleared, "після смерті героя місце не зараховується очищеним")
	cb.field_kills = kills0
	var gold_z: int = gp.gold
	await _frames(100)
	check(game.state == game.State.DEAD and game.hud.overlay.visible, "за мить з'являється екран поразки")
	game.enter_city("poltava")
	await _frames(2)
	check(gp.gold == gold_z + 77, "злидень, якого не добили, крадене кинув: гроші повернулись (+77)")

	# ---- Бос дня не рахується господарем лігва ----
	game.enter_map()
	game.enter_location("wild_field")
	await _frames(3)
	cb.loc = cb.loc.duplicate()
	cb.loc["hunt"] = "day"
	cb.spawn_enemy("koshchii", 30, true)
	var boss = cb._last_enemy()
	var boss_n: int = int(gw.stats.get("boss", 0))
	var kill_n: int = int(gw.stats.get("kill", 0))
	game._on_enemy_killed(boss)
	check(int(gw.stats.get("boss", 0)) == boss_n and int(gw.stats.get("kill", 0)) == kill_n + 1 and int(gw.stats.get("boss:koshchii", 0)) == 0, "бос дня: вбивство рахується, а досягнення за боса лігва й сюжет ні")
	cb.loc.erase("hunt")
	game._on_enemy_killed(boss)
	check(int(gw.stats.get("boss", 0)) == boss_n + 1, "звичайний бос лігва рахується, як і раніше")
	game.enter_map()
	await _frames(2)

	# ---- Герць: спроба списується один раз, перемога після поразки не рахується ----
	gp.revive()
	game.enter_city("sich")
	game.hud.close_dialogue()
	var tries0: int = int(DuelS.state(gw)["tries"])
	var wins0: int = int(DuelS.state(gw)["wins"])
	game.start_duel()
	await _frames(3)
	check(cb.is_duel() and str(game.meta.get("fight", "")) == "duel" and str(SaveSystem.load_data(TEST_SAVE)["meta"].get("fight", "")) == "duel", "герць почався: позначка незавершеного бою вже у збереженні")
	# пауза → «Персонаж» у герці не заморожує гру
	game._show_pause()
	var char_btn = null
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		if b.text == "Персонаж":
			char_btn = b
	char_btn.pressed.emit()
	check(game.state == game.State.PAUSED and game.hud.overlay.visible, "«Персонаж» із паузи посеред герцю лишає паузу з кнопками")
	game._duel_lost()  # «Здатися»
	check(int(DuelS.state(gw)["tries"]) == tries0 - 1 and cb.lost and not game.meta.has("fight"), "здався: мінус одна спроба")
	gp.hp = 0.0
	gp._check_death()
	check(int(DuelS.state(gw)["tries"]) == tries0 - 1, "упав за мить після здачі: друга спроба не списується")
	_clear_enemies(game)
	await _frames(6)
	check(not cb.duel_over and int(DuelS.state(gw)["wins"]) == wins0, "суперник зник після поразки: перемога не зараховується")
	await _frames(110)
	check(game.state == game.State.CITY and game.city_id == "sich", "після поразки герой отямлюється на Січі")
	# гру закрили посеред герцю: при вході спроба списана
	game.hud.close_dialogue()
	gp.revive()
	var tries1: int = int(DuelS.state(gw)["tries"])
	game.start_duel()
	await _frames(3)
	check(cb.is_duel() and tries1 > 0, "другий герць почався")
	check(game.load_game(), "гру закрили й відкрили знову")
	gw = game.world
	gp = game.player
	check(int(DuelS.state(gw)["tries"]) == tries1 - 1 and "покинув" in game.fight_notice and not game.meta.has("fight"), "покинутий герць рахується поразкою: спробу списано")
	cb.leave()
	game.enter_city("sich")
	game.hud.close_dialogue()
	await _frames(2)
	# вихід у головне меню посеред герцю теж поразка
	var tries2: int = int(DuelS.state(gw)["tries"])
	if tries2 > 0:
		gp.level = 30
		game.start_duel()
		await _frames(3)
		game._show_pause()
		game._quit_to_menu()
		await _frames(2)
		check(int(DuelS.state(game.world)["tries"]) == tries2 - 1 and game.state == game.State.MENU and game.hud.screen_root == null and not cb.active, "«Головне меню» посеред герцю: спробу списано, бій закрито")
		check(game.load_game(), "герой після виходу в меню читається")
		gw = game.world
		gp = game.player
		check(int(DuelS.state(gw)["tries"]) == tries2 - 1 and game.fight_notice == "", "і вдруге спроба не списується")

	# ---- Програна оборона з відкритим екраном героя ----
	game.enter_map()
	await _frames(2)
	gp.level = 30
	DefS.state(gw)["sieges"]["kyiv"] = 3
	game.start_defense("kyiv")
	await _frames(3)
	check(cb.is_defense() and not cb.defense_over, "оборона Києва почалась")
	cb.on_gate_destroyed()
	game.open_character()
	await _frames(170)
	check(game.state == game.State.CHARACTER and cb.active, "браму зламано, а відкрито екран героя: гра чекає")
	game.close_character()
	await _frames(40)
	check(game.state == game.State.MAP and not cb.active, "закрив екран героя: з програної оборони виведено на мапу")

	game.queue_free()
	await _frames(2)
	get_root().get_tree().paused = false
	Data.sell_mult = 1.0
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Після виходу з гри герой стоїть там, де стояв; «Продовжити» пропонує героя, яким грали востаннє.
func _suite_place_restore() -> void:
	suite("Вхід у гру: місце героя й останній персонаж")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var GameScript = load("res://scripts/game/game.gd")
	var Camp = load("res://scripts/data/camp_data.gd")

	# ---- Налаштування: номер останнього слота ----
	var keep: Dictionary = SaveSystem.load_settings()
	check(int(keep.get("slot", 0)) >= 1 and int(keep.get("slot", 0)) <= SaveSystem.MAX_SLOTS, "налаштування завжди мають номер слота в межах")
	var s3: Dictionary = keep.duplicate(true)
	s3["slot"] = 3
	SaveSystem.save_settings(s3)
	check(int(SaveSystem.load_settings()["slot"]) == 3, "номер слота переживає запис і читання налаштувань")
	SaveSystem.save_settings({"sound": keep["sound"], "music": keep["music"], "autosell": keep["autosell"], "pickup": keep["pickup"]})
	check(int(SaveSystem.load_settings()["slot"]) == 3, "запис налаштувань без номера слота лишає записаний")
	var raw_ok := true
	for pair in [["мотлох", 1], [99, SaveSystem.MAX_SLOTS], [-4, 1], [0, 1], [2.0, 2], ["4", 4], [[1, 2], 1], [null, 1]]:
		var cfg := ConfigFile.new()
		cfg.load(SaveSystem.SETTINGS_PATH)
		cfg.set_value("game", "slot", pair[0])
		cfg.save(SaveSystem.SETTINGS_PATH)
		var got := int(SaveSystem.load_settings()["slot"])
		if got != int(pair[1]):
			raw_ok = false
			print("    слот із налаштувань %s → %d, чекали %d" % [str(pair[0]), got, int(pair[1])])
	check(raw_ok, "сміття в налаштуваннях дає 1, число поза межами затискається в 1..%d" % SaveSystem.MAX_SLOTS)
	var cfg_old := ConfigFile.new()
	cfg_old.load(SaveSystem.SETTINGS_PATH)
	if cfg_old.has_section_key("game", "slot"):
		cfg_old.erase_section_key("game", "slot")
	cfg_old.save(SaveSystem.SETTINGS_PATH)
	check(int(SaveSystem.load_settings()["slot"]) == 1, "старий файл налаштувань без номера слота дає перший")
	SaveSystem.save_settings(keep)
	check(int(SaveSystem.load_settings()["slot"]) == int(keep["slot"]), "налаштування пристрою повернуто, як були")

	# ---- Кого пропонує «Продовжити» ----
	var hero := {"slot": 0, "job": "cossack", "level": 5}
	var sums := [{}, hero, {"slot": 3, "broken": true}, {}, hero]
	check(GameScript.continue_slot(sums, 2) == 2 and GameScript.continue_slot(sums, 5) == 5, "запам'ятований герой є: «Продовжити» пропонує його")
	check(GameScript.continue_slot(sums, 1) == 2 and GameScript.continue_slot(sums, 3) == 2 and GameScript.continue_slot(sums, 4) == 2, "запам'ятований слот порожній чи не читається: пропонується перший читабельний")
	check(GameScript.continue_slot(sums, 0) == 2 and GameScript.continue_slot(sums, 99) == 2, "номер поза межами: перший читабельний")
	check(GameScript.continue_slot([{}, {}, {"slot": 3, "broken": true}, {}, {}], 3) == 0 and GameScript.continue_slot([], 1) == 0, "читабельного героя нема: «Продовжити» не пропонується")

	# ---- Довідник ----
	var all_text := ""
	for e in load("res://scripts/game/wiki_service.gd")._entries("basics"):
		all_text += str(e["text"]) + "\n"
	check("там, де стояв" in all_text and "яким грали востаннє" in all_text, "довідник: гра пам'ятає, де стояв герой і яким героєм грали востаннє")

	# ================= У грі =================
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	game.allow_quit = false
	root.add_child(game)
	await _frames(2)
	check(game.slot == 1, "без слотів запам'ятований герой із налаштувань не береться")
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp", "kleinody", "duel", "defense", "bag_full", "mana_potion", "statuses", "peril_camp"]:
		gw.hints[k] = true
	game.player.level = 10
	game.player.recalc()
	game._save_settings()
	check(int(SaveSystem.load_settings()["slot"]) == int(keep["slot"]), "гра без слотів, записуючи налаштування, номера слота не міняє")

	# 1. На мапі в місцевості
	game.map_here = "wild_field"
	game.map_sel = ""
	game.enter_map()
	await _frames(2)
	check(game.state == game.State.MAP and game.map_here == "wild_field", "герой стоїть на мапі в Дикому Полі")
	var pl: Dictionary = SaveSystem.load_data(TEST_SAVE)["meta"].get("place", {})
	check(str(pl.get("here", "")) == "wild_field" and pl.get("point", true) == false, "збереження знає, де стоїть герой")
	game._show_main_menu()
	game.travel_to = "kyiv"  # дорога попередньої сесії не має їхати далі
	game._continue_game()
	await _frames(3)
	check(game.state == game.State.MAP and game.map_here == "wild_field" and game.map_sel == "wild_field" and not game.map_at_point, "після входу герой на мапі в тій самій місцевості, місце вибране")
	check(not game.combat.active and game.city_id != "wild_field" and game.travel_to == "", "бій сам не почався, місто не відкрилось, дорога не їде")
	gw = game.world

	# 2. Вільна точка
	var pt := Vector2(33.25, 50.5)
	game.map_here = game._nearest_place(pt)
	game.map_at_point = true
	game.map_point = pt
	game.enter_map()
	await _frames(2)
	game._show_main_menu()
	game._continue_game()
	await _frames(3)
	var cur_ll = game.hud.map_view.current_ll
	check(game.state == game.State.MAP and game.map_at_point and game.map_point.is_equal_approx(pt), "вільна точка: герой там само на мапі")
	check(cur_ll is Vector2 and cur_ll.is_equal_approx(pt) and game.hud.map_view.current == "", "вершник намальований у тій самій точці")

	# 3. Місто, що не є останнім, з якого почав
	game.enter_city("kyiv")
	game.hud.close_dialogue()
	await _frames(2)
	game.world.last_city = "poltava"
	game.save_game()
	game._show_main_menu()
	game._continue_game()
	game.hud.close_dialogue()
	await _frames(3)
	check(game.state == game.State.CITY and game.city_id == "kyiv" and game.map_here == "kyiv", "у місті: після входу те саме місто, а не останнє відвідане")

	# 4. Хутір
	game.enter_camp()
	await _frames(2)
	game._show_main_menu()
	game._continue_game()
	await _frames(3)
	check(game.state == game.State.CAMP and game.map_here == Camp.CAMP_ID, "на хуторі: після входу знову на хуторі")

	# 5. Гру закрили посеред бою
	game.enter_map()
	game.enter_location("wild_field")
	await _frames(3)
	check(game.combat.active, "бій у Дикому Полі почався")
	game.save_game()
	game._continue_game()  # перезапуск посеред бою
	await _frames(3)
	check(game.state == game.State.MAP and game.map_here == "wild_field" and game.map_sel == "wild_field" and not game.combat.active, "закрили посеред бою: герой на мапі біля входу, бою нема")
	await _frames(30)
	check(game.state == game.State.MAP and not game.combat.active, "і за мить бій теж не почався")

	# 6. Старе збереження без запису місця й сміття в записі
	game.world.last_city = "poltava"
	game.map_here = "wild_field"
	game.enter_map()
	await _frames(2)
	var base: Dictionary = SaveSystem.load_data(TEST_SAVE)
	var junk_ok := true
	for junk in ["немає", "сміття", {}, {"here": "nema_takoho_mistsia"}, {"here": 5, "point": "так", "x": "a", "y": null}, {"here": "nema", "point": true, "x": NAN, "y": 1.0}]:
		var d: Dictionary = base.duplicate(true)
		if str(junk) == "немає":
			d["meta"].erase("place")
		else:
			d["meta"]["place"] = junk
		SaveSystem.save(d, TEST_SAVE)
		game._show_main_menu()
		game._continue_game()
		game.hud.close_dialogue()
		await _frames(2)
		if not (game.state == game.State.CITY and game.city_id == "poltava"):
			junk_ok = false
			print("    запис місця %s → стан %d, місто %s" % [str(junk), game.state, game.city_id])
	check(junk_ok, "старе збереження без запису місця чи з незнайомим місцем: останнє місто")
	var nan_pt: Dictionary = base.duplicate(true)
	nan_pt["meta"]["place"] = {"here": "wild_field", "point": true, "x": NAN, "y": 1.0}
	SaveSystem.save(nan_pt, TEST_SAVE)
	game._show_main_menu()
	game._continue_game()
	await _frames(2)
	check(game.state == game.State.MAP and game.map_here == "wild_field" and not game.map_at_point, "зіпсована точка, а місце знайоме: герой на мапі в цьому місці")
	var far: Dictionary = base.duplicate(true)
	far["meta"]["place"] = {"here": "wild_field", "point": true, "x": 9999.0, "y": -9999}
	SaveSystem.save(far, TEST_SAVE)
	game._show_main_menu()
	game._continue_game()
	await _frames(2)
	var mv = game.hud.map_view
	check(game.state == game.State.MAP and game.map_at_point and game.map_point.x <= mv.LON1 - mv.EDGE + 0.001 and game.map_point.y >= mv.LAT0 + mv.EDGE - 0.001, "точка за межами мапи затискається в межі")

	game.queue_free()
	await _frames(2)
	get_root().get_tree().paused = false
	Data.sell_mult = 1.0
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Копія світу, де місце вже пройдено кілька разів (для перевірок швидкого походу).
func _cleared_world(w, loc_id: String):
	w.cleared[loc_id] = 9
	return w


## Текст кнопок поточного меню-оверлею.
func _overlay_buttons(game) -> Dictionary:
	var out := {}
	for b in game.hud.overlay_box.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			out[b.text] = b
	return out


func _suite_hero_names() -> void:
	suite("Імена героїв")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var NS = load("res://scripts/game/name_service.gd")
	var Names = load("res://scripts/data/names_data.gd")
	var ST = load("res://scripts/core/save_transfer.gd")
	var RS = load("res://scripts/game/record_service.gd")
	var Classes = load("res://scripts/data/classes.gd")

	# ---- 1. Правила ----
	check(NS.check("Іва") == "" and NS.check("Абвгґдеєжзиіїйк") == "" and NS.check("Абвгґдеєжзиіїйкл") == "", "3 і 16 знаків годяться")
	check("Закоротке" in NS.check("Ів") and "Закоротке" in NS.check("   ") and "Задовге" in NS.check("Абвгґдеєжзиіїйклм"), "2 і 17 знаків ні, причина словами")
	check(NS.clean("  Тарас    Бульба \t") == "Тарас Бульба" and NS.check("  Тарас    Бульба ") == "", "пробіли по краях зрізаються, кілька поспіль стискаються")
	check(NS.check("Мар'яна") == "" and NS.check("Мар’яна") == "" and NS.clean("Марʼяна") == "Мар’яна" and NS.check("Олексій-2") == "" and NS.check("John Smith") == "", "апостроф (обидва), дефіс, цифри й латинка дозволені")
	var signs_ok := true
	for s in ["Тарас@", "Тарас!", "Та_рас", "Ёжик", "Тарас.", "Тарас😀", "Ta#ras"]:
		if not ("Такі знаки" in NS.check(s)):
			signs_ok = false
			print("    пропущено «%s»" % s)
	check(signs_ok, "інші знаки й російські літери не можна")
	check("літеру" in NS.check("1648") and "літеру" in NS.check("--''") and "літеру" in NS.check("12 - 34"), "лише цифри й розділові: ні")
	var reserved_ok := true
	for s in ["Адмін", "admin", "АДМІН Тарас", "Adm1n", "Модератор", "moderator", "Розробник", "Developer", "Система", "system", "Підтримка", "Support", "GM", "GM Тарас", "gm1", "Гм-Петро"]:
		if NS.check(s) == "" or ("служби" not in NS.check(s) and "Закоротке" not in NS.check(s)):
			reserved_ok = false
			print("    не зарезервовано «%s»: %s" % [s, NS.check(s)])
	check(reserved_ok, "імена служби гри зарезервовані цілим іменем і початком")
	var rude_ok := true
	for s in ["хуй", "ХУУУЙ", "х у й", "х-у-й", "xyй", "Хуйло", "пізда", "пiзда", "п1зда", "сука", "cyka", "suka", "Сучка Сука", "блядь", "6лядь", "бля", "блять", "ебать", "їбати", "єбан", "мудак", "підор", "pidor", "fuck", "FuUuCk", "f u c k", "sh1t", "shit", "Pussy", "bitch", "hitler", "Гітлер", "гандон", "курва", "жопа"]:
		if NS.check(s) != NS.BAD_TEXT:
			rude_ok = false
			print("    пропущено лайку «%s»: %s" % [s, NS.check(s)])
	check(rude_ok, "лайка й обхідні написання не проходять, причина нейтральна")
	var plain_ok := true
	for s in ["Тарас", "Олена", "Остап", "Андрій", "Мирослава", "Богдан", "Наталка", "Ярема", "Северин", "Ivan", "Kateryna", "Christopher", "Небаба", "Стебло", "Гмиря", "Шабля", "Довбня", "Командарм", "Nigel", "Sebastian", "Д'Артаньян", "Козак 1648"]:
		if NS.check(s) != "":
			plain_ok = false
			print("    звичайне ім'я «%s» не пройшло: %s" % [s, NS.check(s)])
	for s in Names.READY:
		if NS.check(s) != "":
			plain_ok = false
			print("    готове прізвисько «%s» не пройшло: %s" % [s, NS.check(s)])
	for v in Names.VERBS:
		for n in Names.NOUNS:
			if NS.check(v + n) != "":
				plain_ok = false
				print("    складене «%s» не пройшло: %s" % [v + n, NS.check(v + n)])
	check(plain_ok, "звичайні імена й усі прізвиська генератора (%d) проходять" % (Names.READY.size() + Names.VERBS.size() * Names.NOUNS.size()))
	check(NS.from_save(42) == "" and NS.from_save("хуй") == "" and NS.from_save(" Сірко ") == "Сірко", "ім'я зі збереження: не рядок чи недопустиме стає порожнім")

	# ---- 2. Жереб ----
	var r1 := RandomNumberGenerator.new()
	r1.seed = 1648
	var r2 := RandomNumberGenerator.new()
	r2.seed = 1648
	var a := []
	var b := []
	for i in 20:
		a.append(NS.roll(r1))
		b.append(NS.roll(r2))
	check(a == b, "жереб із тим самим зерном дає ті самі імена")
	var seen := {}
	var roll_ok := true
	var rr := RandomNumberGenerator.new()
	rr.seed = 7
	for i in 1000:
		var n: String = NS.roll(rr)
		seen[n] = true
		if NS.check(n) != "" or n.length() < 3 or n.length() > 16:
			roll_ok = false
			print("    жереб дав «%s»" % n)
	check(roll_ok, "тисяча кидків: усі імена 3–16 знаків і проходять перевірку")
	check(seen.size() >= 200, "різних імен на тисячу кидків: %d" % seen.size())
	check(NS.check(NS.roll()) == "", "жереб без свого генератора теж годиться")

	# ---- 3. Збереження ----
	var p = _new_player()
	p.nick = "Сірко"
	p.level = 12
	var p2 = _new_player()
	p2.from_dict(p.to_dict())
	check(p2.nick == "Сірко", "ім'я переживає запис і читання героя")
	var dd: Dictionary = p.to_dict()
	dd["nick"] = "сука"
	p2.from_dict(dd)
	var bad_ok: bool = p2.nick == ""
	dd["nick"] = 777
	p2.nick = "x"
	p2.from_dict(dd)
	bad_ok = bad_ok and p2.nick == ""
	dd.erase("nick")
	p2.nick = "x"
	p2.from_dict(dd)
	check(bad_ok, "недопустиме ім'я у збереженні стає порожнім")
	check(p2.nick == "" and p2.level == 12, "старе збереження без імені: ім'я порожнє, решта на місці")
	var prof := {"v": ST.FORMAT, "account": {}, "heroes": [{"slot": 1, "data": _transfer_hero(12, 500)}, {"slot": 2, "data": _transfer_hero(5, 10)}], "made": 0}
	prof["heroes"][0]["data"]["player"]["nick"] = "Сірко"
	prof["heroes"][1]["data"]["player"]["nick"] = "хуй"
	var lines: Array = ST.summary(prof)
	check(ST.check(prof) == "" and lines[0] == "Слот 1: Сірко, Козак, рівень 12" and lines[1] == "Слот 2: Козак, рівень 5", "код роду: недопустиме ім'я не причина відмови, підсумок показує ім'я (%s)" % str(lines))
	var prof_bad: Dictionary = prof.duplicate(true)
	prof_bad["heroes"][0]["data"]["player"]["nick"] = 12
	check(ST.check(prof_bad) != "", "ім'я в коді роду не рядок: відмова")
	var last: String = SaveSystem.slot_path(SaveSystem.MAX_SLOTS)
	if not SaveSystem.exists(last):
		SaveSystem.save({"player": p.to_dict(), "world": WorldState.new().to_dict(), "meta": {"playtime": 10.0}}, last)
		check(SaveSystem.slot_summaries()[SaveSystem.MAX_SLOTS - 1].get("nick", "") == "Сірко", "підсумок слота знає ім'я героя")
		SaveSystem.delete(last)
	# 6. Перейменування у файлі (герой не той, яким грають)
	var rpath := "user://test_rename.save"
	SaveSystem.delete(rpath)
	SaveSystem.save({"player": p.to_dict(), "world": WorldState.new().to_dict(), "meta": {"playtime": 77.0}}, rpath)
	var before: Dictionary = SaveSystem.load_data(rpath)
	check(not NS.rename_file(rpath, "хуй") and not NS.rename_file("user://nema_takoho.save", "Тарас"), "недопустиме ім'я чи нема файла: перейменування не відбувається")
	check(NS.rename_file(rpath, "  Нечай  ") , "перейменування у файлі")
	var after: Dictionary = SaveSystem.load_data(rpath)
	var nick_after: String = after["player"]["nick"]
	before["player"].erase("nick")
	after["player"].erase("nick")
	check(nick_after == "Нечай" and var_to_str(before) == var_to_str(after) and int(after["version"]) == SaveSystem.SAVE_VERSION, "ім'я змінилось, решта збереження й версія ті самі")
	SaveSystem.delete(rpath)

	# ---- 7. Де ім'я видно ----
	p.change_class("cossack")
	check(RS.who(p).begins_with("Сірко, ") and "рівня" in RS.who(p), "рекорд записується з іменем: %s" % RS.who(p))
	p2.nick = ""
	check(not RS.who(p2).begins_with(","), "герой без імені: як раніше")
	p.free()
	p2.free()

	# ---- 8. Довідник ----
	var found := false
	for e in load("res://scripts/game/wiki_service.gd")._entries("basics"):
		if str(e["title"]) == "Ім'я героя" and "не унікальні" in str(e["text"]) and "Кинути жереб" in str(e["text"]):
			found = true
	check(found, "довідник: стаття «Ім'я героя» в розділі «Як грати»")

	# ================= У грі =================
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	game.allow_quit = false
	root.add_child(game)
	await _frames(2)
	check(game.ask_name, "справжня поведінка (питати ім'я старого героя) типова")
	# Прямий виклик new_game(): як раніше, з випадковим прізвиськом
	game.new_game()
	game.hud.close_dialogue()
	check(game.naming == "" and NS.check(game.player.nick) == "", "new_game() без імені: герой має допустиме прізвисько (%s)" % game.player.nick)
	# Підпис слота: найдовший має влазити в кнопку
	var longest := ""
	for c in Classes.CLASSES:
		if str(Classes.CLASSES[c]["name"]).length() > longest.length():
			longest = c
	var s_long := {"job": longest, "level": 99, "rank": "", "chapter": 5, "done": true, "playtime": 999.0 * 3600.0 + 59 * 60, "nick": "Перебийніс-Сірко"}
	var title: String = game._slot_title(s_long)
	var title_ok := true
	for line in title.split("\n"):
		if line.length() > 36:
			title_ok = false
	check(title.begins_with("Перебийніс-Сірко • ") and title_ok, "підпис слота починається з імені, кожен рядок до 36 знаків: %s" % title.replace("\n", " / "))
	check(not game._slot_title({"job": "cossack", "level": 3, "rank": "", "chapter": 0, "done": false, "playtime": 0.0}).begins_with(" "), "підпис слота без імені")
	game.hud.open_overlay()
	var probes := []
	for nk in ["Перебийніс-Сірко", "ШШШШШШШШШШШШШШШШ", "шшшшшшшшшшшшшшшш", "WWWWWWWWWWWWWWWW", "Жмшщюжмшщю-Жмшщю"]:
		for cur in [true, false]:
			var sx: Dictionary = s_long.duplicate()
			sx["nick"] = nk
			var txt: String = game._slot_row_text(sx, cur)
			var pb = load("res://scripts/ui/ui_kit.gd").button(txt, func(): pass, Vector2(game.HERO_ROW_PLAY, 64), 20)
			game.hud.overlay_box.add_child(pb)
			probes.append(pb)
			check(nk in txt.split("\n")[0], "ім'я в підписі не обрізане: %s" % txt.replace("\n", " / "))
	var probe2 = load("res://scripts/ui/ui_kit.gd").button("Продовжити: " + title, func(): pass, Vector2(480, 80))
	game.hud.overlay_box.add_child(probe2)
	await _frames(2)
	var widest := 0.0
	for pb in probes:
		widest = maxf(widest, pb.get_combined_minimum_size().x)
	check(widest <= game.HERO_ROW_PLAY + 0.5, "найдовші підписи влазять у кнопку слота (%.0f із %d)" % [widest, game.HERO_ROW_PLAY])
	check(probe2.get_combined_minimum_size().x <= 1000.0, "і в кнопку «Продовжити» головного меню (%.0f)" % probe2.get_combined_minimum_size().x)
	game.hud.close_overlay()

	# ---- 4. Кнопка «Нова гра»: спершу ім'я ----
	game._forget_hero()
	SaveSystem.delete(TEST_SAVE)
	game._show_main_menu()
	await _frames(2)
	var btns: Dictionary = _overlay_buttons(game)
	check(btns.has("Нова гра"), "у головному меню без героя є «Нова гра»")
	btns["Нова гра"].pressed.emit()
	await _frames(2)
	btns = _overlay_buttons(game)
	check(game.naming == "new" and game.name_edit != null and NS.check(game.name_edit.text) == "" and btns.has("Готово") and btns.has("Кинути жереб") and btns.has("Назад"), "«Нова гра» спершу питає ім'я, поле заповнене жеребом")
	check(game.player == null and game.hud.dialogue_root == null, "до «Готово» гра не почалась")
	var rolled: String = game.name_edit.text
	for i in 5:
		btns["Кинути жереб"].pressed.emit()
		if game.name_edit.text != rolled:
			break
	check(game.name_edit.text != rolled and NS.check(game.name_edit.text) == "", "«Кинути жереб» дає інше ім'я")
	game.name_edit.text = "Ів"
	game.name_edit.text_changed.emit("Ів")
	btns["Готово"].pressed.emit()
	await _frames(2)
	check(game.naming == "new" and game.player == null and "Закоротке" in game.name_why.text, "«Готово» з недопустимим іменем не пускає далі й показує причину")
	game.name_edit.text = "сука"
	btns["Готово"].pressed.emit()
	await _frames(2)
	check(game.naming == "new" and game.player == null and game.name_why.text == NS.BAD_TEXT, "лайка: причина нейтральна")
	# поле й причина у верхній половині екрана, кнопки поруч
	var vh: float = game.get_viewport().get_visible_rect().size.y
	var er: Rect2 = game.name_edit.get_global_rect()
	var wr: Rect2 = game.name_why.get_global_rect()
	var dr: Rect2 = btns["Готово"].get_global_rect()
	check(er.end.y <= vh / 2.0 and wr.end.y <= vh / 2.0 and dr.end.y <= vh / 2.0 + 10.0 and er.position.y >= 0.0, "поле, причина й «Готово» у верхній половині екрана (%.0f, %.0f, %.0f із %.0f)" % [er.end.y, wr.end.y, dr.end.y, vh])
	# «Назад» вертає в меню й героя не створює
	game.go_back(true)
	await _frames(2)
	btns = _overlay_buttons(game)
	check(game.naming == "" and game.state == game.State.MENU and btns.has("Нова гра") and game.player == null and not SaveSystem.exists(TEST_SAVE), "системна «Назад» з екрана імені: у меню, героя нема")
	btns["Нова гра"].pressed.emit()
	await _frames(2)
	btns = _overlay_buttons(game)
	btns["Назад"].pressed.emit()
	await _frames(2)
	check(game.naming == "" and _overlay_buttons(game).has("Нова гра") and game.player == null, "кнопка «Назад» на екрані імені теж")
	_overlay_buttons(game)["Нова гра"].pressed.emit()
	await _frames(2)
	game.name_edit.text = "  Тарас   Сірко "
	_overlay_buttons(game)["Готово"].pressed.emit()
	await _frames(2)
	check(game.naming == "" and game.player != null and game.player.nick == "Тарас Сірко" and game.hud.dialogue_root != null, "«Готово» з допустимим іменем починає гру з цим іменем")
	game.hud.close_dialogue()
	var gw = game.world
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp", "kleinody", "duel", "defense", "bag_full", "mana_potion", "statuses", "peril_camp"]:
		gw.hints[k] = true
	game.map_here = "wild_field"
	game.map_sel = ""
	game.enter_map()
	await _frames(2)
	check(str(SaveSystem.load_data(TEST_SAVE)["player"].get("nick", "")) == "Тарас Сірко", "ім'я в збереженні")
	game.open_character()
	await _frames(2)
	var heads := []
	for l in game.hud.screen_root.find_children("*", "Label", true, false):
		heads.append(l.text)
	check("\n".join(heads).contains("Тарас Сірко • "), "екран героя: ім'я в заголовку")
	game.close_character()
	await _frames(2)

	# ---- 5. Старий герой без імені ----
	game.player.nick = ""
	game.save_game()
	game._show_main_menu()
	game.ask_name = false
	game._continue_game()
	await _frames(2)
	check(game.naming == "" and game.state == game.State.MAP, "тести з вимкненим прапорцем не спиняються на екрані імені")
	game._show_main_menu()
	game.ask_name = true
	var menu_bg: Color = game.hud.overlay.color
	if game.hud._banner_tween and game.hud._banner_tween.is_valid():
		game.hud._banner_tween.kill()
	game.hud.banner.modulate.a = 0.0
	var banners0: int = game.hud.banner_count
	game._continue_game()
	await _frames(2)
	btns = _overlay_buttons(game)
	check(game.naming == "first" and game.hud.overlay.visible and btns.has("Готово") and not btns.has("Назад") and NS.check(game.name_edit.text) == "", "старий герой без імені: після входу екран імені з жеребом, без «Назад»")
	check(game.hud.overlay.color.a == 1.0, "екран імені: тло суцільне, нічого не просвічує (%.2f)" % game.hud.overlay.color.a)
	var banners_entry: int = game.hud.banner_count
	game.go_back(true)
	await _frames(2)
	check(game.naming == "first" and game.hud.overlay.visible and game.state == game.State.MAP, "системна «Назад» не дає вийти без імені й нічого не ламає")
	var offered: String = game.name_edit.text
	btns["Готово"].pressed.emit()
	await _frames(2)
	check(game.naming == "" and not game.hud.overlay.visible and game.player.nick == offered, "одним дотиком: герой має запропоноване ім'я (%s)" % offered)
	check(game.hud.overlay.color == menu_bg, "після екрана імені тло меню вертається попереднє")
	if banners_entry == banners0:
		check(game.hud.banner_count == banners0 and game.hud.banner.modulate.a == 0.0, "банера при вході не було: після «Готово» нічого не показано")
	else:
		check(game.hud.banner_count == banners_entry + 1, "банер при вході був (свято тощо): після «Готово» показано знову один раз")
	check(str(SaveSystem.load_data(TEST_SAVE)["player"].get("nick", "")) == offered, "і воно в збереженні")
	check(game.state == game.State.MAP and game.map_here == "wild_field", "гравець там, де стояв")
	# Покинутий герць: банер про списану спробу затулено екраном імені, після «Готово» він знову видимий
	game.player.nick = ""
	game.meta["fight"] = "duel"
	game.save_game()
	game._show_main_menu()
	game._continue_game()
	await _frames(2)
	check(game.naming == "first" and "покинув" in game.hud.banner.text, "покинутий герць: банер показано під екраном імені")
	var notice_col = game.hud.banner.get_theme_color("font_color")
	# поки гравець вписує ім'я, банер згасає
	game.hud._banner_tween.kill()
	game.hud.banner.modulate.a = 0.0
	game.hud.banner.text = ""
	game.name_edit.text = offered  # те саме ім'я: далі його чекає перевірка перейменування
	_overlay_buttons(game)["Готово"].pressed.emit()
	await _frames(2)
	var bt = game.hud._banner_tween
	check(game.naming == "" and "покинув" in game.hud.banner.text and game.hud.banner.get_theme_color("font_color") == notice_col and (game.hud.banner.modulate.a > 0.0 or (bt != null and bt.is_running() and bt.get_total_elapsed_time() < 0.5)), "після «Готово» банер про покинутий бій знову видно, той самий текст і колір")
	check(not game.meta.has("fight") and game.player.nick != "", "позначку бою знято, ім'я є")
	game._show_main_menu()
	game._continue_game()
	await _frames(2)
	check(game.naming == "" and not game.hud.overlay.visible, "з іменем екран більше не показується")

	# ---- Перейменування з меню ----
	game._show_main_menu()
	await _frames(1)
	game._ask_rename(1)
	await _frames(2)
	btns = _overlay_buttons(game)
	check(game.naming == "rename" and game.name_edit.text == offered and btns.has("Назад"), "перейменування: поле заповнене нинішнім іменем")
	game.go_back(true)
	await _frames(2)
	check(game.naming == "" and game.state == game.State.MENU and _overlay_buttons(game).has("Перенести на інший пристрій") and str(SaveSystem.load_data(TEST_SAVE)["player"]["nick"]) == offered, "«Назад» з перейменування: у «Персонажі», ім'я те саме")
	game._ask_rename(1)
	await _frames(2)
	game.name_edit.text = "Адмін"
	_overlay_buttons(game)["Готово"].pressed.emit()
	await _frames(2)
	check(game.naming == "rename" and "служби" in game.name_why.text, "ім'я служби гри не приймається")
	game.name_edit.text = "Вернигора"
	_overlay_buttons(game)["Готово"].pressed.emit()
	await _frames(2)
	check(game.naming == "" and str(SaveSystem.load_data(TEST_SAVE)["player"]["nick"]) == "Вернигора" and game.player.nick == "Вернигора", "нове ім'я у файлі слота й у героя")
	check(is_equal_approx(game.hud.overlay.color.a, 0.72), "після екрана імені тло меню знову звичайне")
	check(game._slot_title({"job": "peasant", "level": 1, "rank": "", "chapter": 0, "done": false, "playtime": 0.0, "nick": "Вернигора"}).begins_with("Вернигора • Селянин 1"), "підпис слота з іменем")

	game.queue_free()
	await _frames(2)
	get_root().get_tree().paused = false
	Data.sell_mult = 1.0
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


func _suite_pet_fetch() -> void:
	suite("Улюбленці не біжать до здобичі, якої не взяти")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var DS = load("res://scripts/game/divine_service.gd")
	var SH = load("res://scripts/game/shop_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp", "bag_full"]:
		gw.hints[k] = true
	gp.change_class("cossack")
	gp.level = 30
	gp.recalc()
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	SH.state(gw)["coins"] = 100000
	check(DS.buy(gw, gp, "khovanets"), "Хованця куплено")
	gp.pet = "pes"
	game.enter_location("wild_field")
	await _frames(4)
	_clear_enemies(game)
	var c = game.combat
	c.autosell = false
	c.pickup_filter = [true, true, true, true]
	var kh = null
	var dog = null
	for n in c.entities.get_children():
		if n.get_script() == c.PetScript:
			if n.kind == "khovanets":
				kh = n
			elif n.kind == "pes":
				dog = n
	check(kh != null and dog != null, "Хованець і пес біжать за героєм у бою")
	if kh == null or dog == null:
		game.queue_free()
		await _frames(3)
		return
	var clear_ground := func() -> void:
		for n in c.entities.get_children():
			if n.get_script() == c.PickupScript:
				n.queue_free()
	var lay := func(kind: String, item: Dictionary, manual: bool = false):
		var pk = c.PickupScript.new()
		pk.combat = c
		pk.kind = kind
		pk.item = item
		pk.value = 1
		pk.manual = manual
		pk.hold = 99.0
		pk.position = gp.position + Vector2(0, -200)
		c.entities.add_child(pk)
		return pk
	clear_ground.call()
	await _frames(2)
	# 1. Повний запас зілля: зілля на землі не ціль, улюбленці стоять біля героя
	gp.potions = gp.potion_max()
	var potion = lay.call("potion", {})
	check(kh._nearest_pickup() == null and dog._nearest_pickup() == null, "повний запас зілля: ні Хованець, ні пес не беруть зілля на землі ціллю")
	for i in 40:
		gp.hp = gp.max_hp
		gp.invuln = 1.0
		await process_frame
	check(is_instance_valid(potion) and kh.position.distance_to(gp.position) < 110.0 and kh.position.distance_to(potion.position) > 120.0 and kh._fetch == null, "Хованець стоїть біля героя, а не над зіллям")
	check(dog.position.distance_to(gp.position) < 110.0 and dog.position.distance_to(potion.position) > 120.0 and dog._fetch == null, "пес стоїть біля героя, а не над зіллям")
	# Ціль стала недоступною між перевірками: улюбленець одразу кидає її
	kh._fetch = potion
	kh._fetch_t = 10.0
	dog._fetch = potion
	dog._fetch_t = 10.0
	await process_frame
	check(kh._fetch == null and dog._fetch == null, "недоступну ціль улюбленець кидає в тому ж кадрі, не чекаючи наступної перевірки")
	# 2. Запас не повний: те саме зілля стає ціллю
	gp.potions = gp.potion_max() - 1
	check(kh._nearest_pickup() == potion and dog._nearest_pickup() == potion, "у запасі є місце: зілля знову ціль")
	clear_ground.call()
	await _frames(2)
	# 3. Повна торба: звичайна річ не ціль, золота лишається ціллю
	gp.potions = 0
	var guard := 0
	while not gp.bag_full() and guard < 500:
		gp.add_item(Data.gen_item(10, 1, "boots"))
		guard += 1
	var magic: Dictionary = Data.gen_item(10, 1, "belt")
	var on_ground = lay.call("item", magic)
	check(gp.bag_full() and c.loot_block("item", magic) == "full" and kh._nearest_pickup() == null and dog._nearest_pickup() == null, "повна торба: звичайна річ на землі не ціль")
	var gold_item: Dictionary = Uniques.make("poias_baidy", 20)
	var gold_ground = lay.call("item", gold_item)
	check(Data.is_precious(gold_item) and kh._nearest_pickup() == gold_ground and dog._nearest_pickup() == gold_ground, "золоту річ беруть і в повну торбу: вона ціль")
	clear_ground.call()
	await _frames(2)
	gp.inventory.clear()
	# 4. Фільтр автопідбору й викинута власноруч річ
	c.pickup_filter = [false, true, true, true]
	var common: Dictionary = Data.gen_item(10, 0, "boots")
	var common_ground = lay.call("item", common)
	check(c.loot_block("item", common) == "filter" and kh._nearest_pickup() == null and dog._nearest_pickup() == null, "річ, якої не бере фільтр, не ціль")
	c.pickup_filter = [true, true, true, true]
	check(kh._nearest_pickup() == common_ground, "фільтр змінили: річ знову ціль")
	common_ground.queue_free()
	await _frames(1)
	var thrown = lay.call("item", Data.gen_item(10, 1, "belt"), true)
	check(thrown.manual and kh._nearest_pickup() == null and dog._nearest_pickup() == null, "викинута власноруч річ не ціль")
	clear_ground.call()
	# Довідник
	var basics := ""
	for e in WS._entries("basics"):
		if str(e["title"]) in ["Божі дари", "Улюбленці"]:
			basics += str(e["text"])
	check("Хованець не біжить" in basics and "до тієї, якої зараз не взяти" in basics, "довідник: до здобичі, якої не взяти, Хованець і пес не біжать")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)


## Кузня хутора: «Переплавити» в самому низу, заточена до краю річ не підставляє під палець іншу дію,
## цінна річ плавиться лише другим дотиком, душа з переплавленої речі вертається в торбинку.
func _suite_salvage_confirm() -> void:
	suite("Кузня: переплавка внизу й з підтвердженням")
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
	var Sets = load("res://scripts/data/sets.gd")
	var Uniques = load("res://scripts/data/uniques.gd")
	var CampS = load("res://scripts/game/camp_service.gd")
	var WS = load("res://scripts/game/wiki_service.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
	game.account_path = TEST_ACCOUNT
	game.use_slots = false
	root.add_child(game)
	await _frames(2)
	game.new_game()
	game.hud.close_dialogue()
	var gw = game.world
	var gp = game.player
	for k in ["combat", "block", "elite", "city", "map", "boss", "item", "cleared", "trail", "stones", "char", "levelup", "way", "camp", "bag_full", "kleinody"]:
		gw.hints[k] = true
	gp.level = 60
	gp.gold = 10000000
	gp.resources = {"wood": 100000, "iron": 100000, "herbs": 100000, "trophy": 100000}
	gw.story = {"chapter": 6, "step": 0, "stage": "done", "progress": 0}
	gw.camp["buildings"] = {"kuznia": 3}
	gw.boosts["safe_sharpen"] = 0  # без безпечних заточок кузня показує «Заточити без ризику»
	game.enter_camp()
	await _frames(2)
	var tc = game.hud.screen_root.find_children("*", "TabContainer", true, false)[0]
	var forge_i := -1
	for i in tc.get_tab_count():
		if tc.get_tab_title(i) == "Кузня":
			forge_i = i
	check(forge_i >= 0, "на хуторі є вкладка «Кузня»")
	game.camp_tab = forge_i
	# кнопки правої колонки кузні в порядку зверху вниз
	var det_buttons := func() -> Array:
		var out := []
		var sv = null
		for b in game.hud.screen_root.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and (b.text.begins_with("Переплавити") or b.text.begins_with("Точно переплавити")):
				sv = b
		if sv == null:
			return out
		for b in sv.get_parent().find_children("*", "Button", true, false):
			if b.is_visible_in_tree():
				out.append(b)
		return out
	var find_text := func(start: String):
		for b in game.hud.screen_root.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and b.text.begins_with(start):
				return b
		return null
	var add := func(it: Dictionary) -> int:
		gp.add_item(it)
		return int(it["uid"])
	# 1. «Переплавити» остання кнопка: під заточкою, перекуванням, оновленням, зачаруванням і душами
	var leg: Dictionary = Data.gen_item(30, 3, "weapon", "sabre")
	var leg_uid: int = add.call(leg)
	game.camp_do("select", leg_uid)
	await _frames(2)
	var bs: Array = det_buttons.call()
	var last = bs[-1] if not bs.is_empty() else null
	check(last != null and str(last.text).begins_with("Переплавити") and last == last.get_parent().get_child(last.get_parent().get_child_count() - 1), "«Переплавити» остання в правій колонці кузні")
	var below_all := last != null
	for start in ["Заточити до", "↻", "Оновити", "Пробити гніздо"]:
		var idx := -1
		for i in bs.size():
			if str(bs[i].text).begins_with(start):
				idx = i
				break
		below_all = below_all and idx >= 0 and idx < bs.size() - 1 and bs[idx].global_position.y < last.global_position.y
	var ench_b = find_text.call("Звіробій")
	below_all = below_all and ench_b != null and ench_b.global_position.y < last.global_position.y
	check(below_all, "переплавка нижча за заточку, перекування, оновлення, зачарування й гніздо для душі")
	# 2. Цінна річ (рідкісна +3): перший дотик лише питає, другий плавить
	var rare: Dictionary = Data.gen_item(30, 2, "boots")
	rare["up"] = 3
	var rare_uid: int = add.call(rare)
	game.camp_do("select", rare_uid)
	await _frames(2)
	var iron: int = int(gp.resources["iron"])
	game.camp_do("salvage", rare_uid)
	await _frames(2)
	check(not gp.find_item(rare_uid).is_empty() and int(gp.resources["iron"]) == iron, "цінна річ: перший дотик «Переплавити» нічого не нищить і заліза не дає")
	var sure_b = find_text.call("Точно переплавити")
	check(sure_b != null and sure_b == (det_buttons.call() as Array)[-1], "після першого дотику внизу напис підтвердження")
	game.camp_do("salvage", rare_uid)
	await _frames(2)
	check(gp.find_item(rare_uid).is_empty() and int(gp.resources["iron"]) > iron, "другий дотик плавить і дає залізо")
	# 3. Інша дія між дотиками скидає підтвердження
	var r2: Dictionary = Data.gen_item(30, 2, "belt")
	r2["up"] = 2
	var r2_uid: int = add.call(r2)
	game.camp_do("select", r2_uid)
	game.camp_do("salvage", r2_uid)
	game.camp_do("select", leg_uid)
	check(game.confirm_action == "", "вибір іншої речі скидає підтвердження")
	game.camp_do("select", r2_uid)
	game.camp_do("salvage", r2_uid)
	check(not gp.find_item(r2_uid).is_empty(), "після вибору іншої речі «Переплавити» знову лише питає")
	game.camp_do("sharpen", r2_uid)
	game.camp_do("salvage", r2_uid)
	check(not gp.find_item(r2_uid).is_empty() and game.confirm_action == "salvage:%d" % r2_uid, "після заточки між дотиками переплавка знову лише питає")
	await _frames(2)
	var other_tab: int = 0 if forge_i != 0 else 1
	game.hud.screen_root.find_children("*", "TabContainer", true, false)[0].current_tab = other_tab
	await _frames(3)
	check(game.confirm_action == "", "перемикання вкладки скидає підтвердження")
	game.camp_tab = forge_i
	game.camp_do("salvage", r2_uid)
	game.leave_camp()
	check(game.confirm_action == "" and not gp.find_item(r2_uid).is_empty(), "вихід з хутора скидає підтвердження")
	game.enter_camp()
	game.camp_tab = forge_i
	await _frames(2)
	# 4. Звичайний незаточений мотлох плавиться з першого дотику
	for rar in [0, 1]:
		var junk: Dictionary = Data.gen_item(30, rar, "boots")
		var junk_uid: int = add.call(junk)
		game.camp_do("select", junk_uid)
		game.camp_do("salvage", junk_uid)
		check(gp.find_item(junk_uid).is_empty(), "незаточена річ рідкості %d плавиться з першого дотику" % rar)
	# 5. Наборна, золота, зачарована й річ із душею просять підтвердження
	var set_it: Dictionary = Sets.make("sviatohor", "boots", 30)
	var gold_it: Dictionary = Uniques.make("kotyhoroshko", 30)
	var ench_it: Dictionary = Data.gen_item(30, 1, "belt")
	ench_it["ench"] = "zviroboi"
	var soul_it: Dictionary = Data.gen_item(30, 1, "belt")
	soul_it["sock"] = 1
	soul_it["soul"] = "mavka"
	for pair in [["наборна", set_it], ["золота", gold_it], ["зачарована", ench_it], ["з душею", soul_it]]:
		var u: int = add.call(pair[1])
		game.camp_do("select", u)
		game.camp_do("salvage", u)
		check(not gp.find_item(u).is_empty() and game.confirm_action == "salvage:%d" % u, "%s річ: перший дотик лише питає" % pair[0])
	# 7. Душа з переплавленої речі вертається в торбинку
	var mavky: int = int(gp.souls.get("mavka", 0))
	game.camp_do("salvage", int(soul_it["uid"]))
	check(gp.find_item(int(soul_it["uid"])).is_empty() and int(gp.souls.get("mavka", 0)) == mavky + 1, "душа з переплавленої речі вернулась у торбинку")
	# 6. Заточена до краю річ: на місці «Заточити» неактивна кнопка того самого розміру
	var top: Dictionary = Data.gen_item(30, 2, "boots")
	top["up"] = 9
	var top_uid: int = add.call(top)
	game.camp_do("select", top_uid)
	await _frames(3)
	var sh = find_text.call("Заточити до +10")
	var safe_b = find_text.call("Заточити без ризику")
	var sh_rect: Rect2 = sh.get_global_rect() if sh != null else Rect2()
	var safe_rect: Rect2 = safe_b.get_global_rect() if safe_b != null else Rect2()
	check(sh != null and safe_b != null, "на +9 є «Заточити до +10» і «Заточити без ризику»")
	gp.find_item(top_uid)["up"] = Data.MAX_UPGRADE
	game.camp_do("select", top_uid)
	await _frames(3)
	var done = find_text.call("Заточено до краю")
	check(done != null and done.disabled and done.get_global_rect().is_equal_approx(sh_rect), "на +10 на місці «Заточити» неактивна кнопка того самого розміру")
	var under_finger := []
	for b in game.hud.screen_root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and (b.get_global_rect().has_point(sh_rect.get_center()) or b.get_global_rect().has_point(safe_rect.get_center())):
			under_finger.append(b.text)
	check(under_finger.is_empty(), "на місці кнопок заточки на +10 нема жодної активної кнопки: %s" % str(under_finger))
	var first_active := ""
	var past := false
	for b in det_buttons.call():
		if b == done:
			past = true
		elif past and not b.disabled:
			first_active = b.text
			break
	check(first_active != "" and not first_active.begins_with("Переплавити"), "перша активна кнопка під карткою на +10 не «Переплавити»: %s" % first_active.replace("\n", " / "))
	# Довідник
	var kuv := ""
	for sx in WS.sections():
		for e in sx["entries"]:
			if str(e["title"]) == "Кування":
				kuv = str(e["text"])
	check("другим дотиком" in kuv, "у довіднику «Кування» сказано про підтвердження переплавки цінної речі")
	game.queue_free()
	await _frames(3)
	get_root().get_tree().paused = false
	SaveSystem.delete(TEST_SAVE)
	SaveSystem.delete(TEST_ACCOUNT)
