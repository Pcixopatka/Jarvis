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

var failures = 0
var checks = 0
var _suite = ""


func _initialize() -> void:
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
	await _suite_gameplay()
	await _suite_moves()
	await _suite_defense_battle()
	await _suite_mage_battle()
	await _suite_spec_battle()
	await _suite_volkhv_specs()
	await _suite_depth_battle()
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
			check(q["type"] in ["kill", "fetch", "dungeon"], "тип завдання")
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
	for i in 6:
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
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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


func _suite_travel_ride() -> void:
	suite("Подорож мапою")
	SaveSystem.delete(TEST_SAVE)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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
func _ride(game, id: String) -> void:
	if game.state != game.State.MAP:
		game.enter_map()
		await _frames(2)
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
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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


func _suite_gameplay() -> void:
	suite("Сценарій гри")
	SaveSystem.delete(TEST_SAVE)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = TEST_SAVE
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
	await _frames(2)
