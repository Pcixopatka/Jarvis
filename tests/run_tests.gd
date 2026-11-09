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
	await _suite_gameplay()
	await _suite_moves()
	await _suite_defense_battle()
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
	var skill_ids = {}
	for b in Data.SKILL_BRANCHES:
		for n in b["nodes"]:
			check(not skill_ids.has(n["id"]), "дубль вміння " + n["id"])
			skill_ids[n["id"]] = true
	for b in Data.SKILL_BRANCHES:
		for n in b["nodes"]:
			for r in n["req"]:
				check(skill_ids.has(r), "вміння %s вимагає невідоме %s" % [n["id"], r])
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
	check(p.skill_points == gained and p.perk_points == gained, "очки вмінь і перків")
	var dmg = p.damage
	check(p.add_stat("str") and p.damage > dmg, "сила збільшує шкоду")
	# Усі вміння й перки до максимуму
	p.skill_points = 99
	p.perk_points = 99
	for i in 6:
		for b in Data.SKILL_BRANCHES:
			for n in b["nodes"]:
				p.learn_skill(n["id"])
		for b in Data.PERK_BRANCHES:
			for t in b["tiers"]:
				for pk in t:
					p.learn_perk(pk["id"])
	for b in Data.SKILL_BRANCHES:
		for n in b["nodes"]:
			check(p.sk(n["id"]) == n["max"], "вміння %s на максимумі" % n["id"])
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
	var p = _new_player()
	var w = WorldState.new()
	var gold0 = p.gold
	p.rank = "peasant"
	p.skills = {}
	check(StoryService.state(w)["stage"] == "active" and StoryService.current(w)["id"] == "village", "пролог: одразу бій за рідне село")
	check(not StoryService.intro(w).is_empty(), "пролог: кобзар розповідає вступ")
	check(StoryService.city_dialogue(w, "kyiv").is_empty(), "у чужому місті розмови немає")
	check(StoryService.target(w) == "ridne_selo" and StoryService.objective_line(w) != "", "зірка й рядок мети")
	check(p.is_peasant() and not p.can_learn_skill(Data.SKILL_BRANCHES[0]["nodes"][0]), "селянин не вчить козацьких умінь")
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
			if obj["type"] in ["clear", "dungeon", "visit"]:
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
		total_steps += ch["steps"].size()
	check(steps_done == total_steps, "усі %d кроків (пройдено %d)" % [total_steps, steps_done])
	var names = []
	for it in p.inventory:
		names.append(it["name"])
	check("Козацька шабля" in names, "шабля за посвяту")
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
	check(StoryService.chronicle(w).size() == 7, "у літописі 7 виборів (%d)" % StoryService.chronicle(w).size())
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
	p.rank = "peasant"
	w.travel = {"cooldown": 0, "seen": {}}
	var none := true
	for i in 30:
		if not TS.roll(w, p).is_empty():
			none = false
	check(none, "селянин до посвяти пригод не має")
	p.rank = "cossack"
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
	poor.rank = "cossack"
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
	p.rank = "cossack"
	p.stats["str"] = 60
	p.stats["vit"] = 60
	p.skills = {"whirl": 3, "lightning": 3}
	p.recalc()
	p.hp = p.max_hp
	game.world.hints = {"combat": true, "block": true, "defense": true, "elite": true, "city": true, "map": true, "boss": true, "item": true}
	game.world.defense = {"sieges": {"chyhyryn": 3}, "ruined": {}, "won": 0, "lost": 0, "calm": 3}
	game.world.story = {"chapter": 1, "step": 3, "stage": "active", "progress": 0}
	game._go_to("chyhyryn")
	await _frames(2)
	check(game.state == game.State.PLAYING and game.combat.is_defense() and game.combat.gate != null, "обложене місто — одразу бій біля брами")
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
	# Поразка: браму зламано
	game.world.defense["sieges"]["kyiv"] = 2
	game._go_to("kyiv")
	await _frames(2)
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
	p.rank = "cossack"
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
	check(game.world.story["step"] == 2 and game.hud.dialogue_root != null, "кошовий пропонує посвяту")
	game.hud.dialogue_root._finish()
	await _frames(2)
	for i in 8:
		game._story_event("kill", "zarazhenyi")
	game.enter_city("sich")
	await _frames(2)
	check(game.hud.dialogue_root != null, "посвята: урочиста розмова")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(not p.is_peasant() and p.sk("whirl") == 1 and game.world.story["chapter"] == 1, "посвячено в козаки — розділ I")
	check(game.hud.dialogue_root != null, "розділ I: кошовий одразу кличе")
	game.hud.dialogue_root._finish()
	await _frames(2)
	check(game.world.story["stage"] == "active" and game.hud.map_view != null, "після розмови сюжет активний")
	# Сильний козак, щоб тест ішов швидко й стабільно
	p.stats["str"] = 40
	p.stats["vit"] = 40
	p.skills = {"whirl": 3, "lightning": 3, "musket": 2}
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
