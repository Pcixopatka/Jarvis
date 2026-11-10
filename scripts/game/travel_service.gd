extends RefCounted
## Події в дорозі: коли козак вирушає з мапи в місцевість, іноді трапляється пригода.
## Подія — це розмова з вибором. Ризик кожного варіанта кидається заздалегідь, тож відповідь
## одразу каже, чим усе скінчилося, а apply() застосовує вже відомий наслідок.
##
## Наслідок (outcome): gold, xp, potions, hp_pct (частка здоров'я, може бути від'ємна), heal_full,
## res {ресурс: к-сть}, loyalty {місто: очки}, trip (підсилення на час бою, див. Data.INSPIRED_TIME), sharpen (+1 заточки зброї).

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

const CHANCE := 0.3
const COOLDOWN := 2  # стільки походів без пригод після кожної
const EVENTS := ["chumaky", "gonets", "zasidka", "kobzar", "viz", "koval", "bizhentsi", "shynok", "vovky"]


static func state(world) -> Dictionary:
	if world.travel.is_empty():
		world.travel = {"cooldown": 1, "seen": {}}
	return world.travel


## Чи станеться пригода цього разу. Повертає готову подію або {}.
static func roll(world, player) -> Dictionary:
	if player.is_peasant():
		return {}
	var s := state(world)
	if int(s["cooldown"]) > 0:
		s["cooldown"] = int(s["cooldown"]) - 1
		return {}
	if randf() >= CHANCE:
		return {}
	s["cooldown"] = COOLDOWN
	var id: String = EVENTS[randi() % EVENTS.size()]
	s["seen"][id] = int(s["seen"].get(id, 0)) + 1
	return prepare(world, player, id)


static func _city_name(id: String) -> String:
	return Data.CITIES[id]["name"]


static func _random_city(player) -> String:
	var ids := []
	for id in Data.CITIES:
		if int(Data.CITIES[id]["level"]) <= player.level + 2:
			ids.append(id)
	return ids[randi() % ids.size()]


## Готує подію: текст, варіанти (лише ті, на які вистачає) та їхні наслідки.
static func prepare(world, player, id: String) -> Dictionary:
	var lvl: int = player.level
	var ev := {"id": id, "lines": [], "choices": []}
	var ch: Array = ev["choices"]
	match id:
		"chumaky":
			var price := int(Data.potion_price(lvl) * 1.5)
			ev["lines"] = [["chumak", "Гей, козаче! Везем сіль із Криму, а в возі — дещо й для вашого брата. Купуй, поки дешево!"]]
			if player.gold >= price and player.potions < player.potion_max():
				ch.append({"text": "Два зілля за %d грн" % price, "reply": "Бери, бери. На здоров'я, щоб не знадобились!",
					"outcome": {"gold": -price, "potions": 2}})
			var wood := int(player.resources.get("wood", 0))
			if wood >= 3:
				var g := wood * (3 + lvl)
				ch.append({"text": "Продати дерево (%d) за %d грн" % [wood, g], "reply": "Дерево в степу на вагу золота. Тримай гривні!",
					"outcome": {"gold": g, "res": {"wood": -wood}}})
			ch.append({"text": "Щасливої дороги!", "reply": "І тобі, козаче. Хай воли не стають!", "outcome": {}})
		"gonets":
			var city := _random_city(player)
			ev["lines"] = [["gonets", "Козаче... На мене напали заражені. Лист до %s... не довезу..." % _city_name(city)]]
			if player.potions > 0:
				ch.append({"text": "Віддати йому зілля", "reply": "Дякую... Я довезу. %s не забуде, хто врятував гонця." % _city_name(city),
					"outcome": {"potions": -1, "loyalty": {city: 60}, "xp": 30 * lvl}})
			ch.append({"text": "Довезу лист сам", "reply": "Ось він. Там обіцяли винагороду гінцеві...",
				"outcome": {"gold": 20 + 12 * lvl, "loyalty": {city: 20}}})
			ch.append({"text": "Проїхати мимо", "reply": "...", "outcome": {}})
		"zasidka":
			ev["lines"] = [["doroha", "Із придорожніх кущів вискакують заражені! Їх небагато, але бій буде лютий."]]
			ch.append({"text": "Прийняти бій!", "reply": "Покотилися голови! Ти поранений, та трофеї того варті.",
				"outcome": {"hp_pct": -0.25, "xp": 60 * lvl, "gold": 15 * lvl}})
			if randf() < 0.5:
				ch.append({"text": "Обійти манівцями", "reply": "Тихо, як миша, ти проскочив повз. Ніхто й не помітив.", "outcome": {}})
			else:
				ch.append({"text": "Обійти манівцями", "reply": "Не вдалося — наздогнали біля броду! Ледве відбився.",
					"outcome": {"hp_pct": -0.15}})
		"kobzar":
			ev["lines"] = [["kobzar", "Сідай до вогню, козаче. Заграю тобі думу про тих, хто йшов цим шляхом до тебе."]]
			ch.append({"text": "Послухати думу", "reply": "Струни дзвенять — і серце горить. У цьому поході рука буде твердою!",
				"outcome": {"trip": "inspired", "heal_full": true}})
			ch.append({"text": "Ніколи, поспішаю", "reply": "Іди, іди. Пісня почекає.", "outcome": {}})
		"viz":
			ev["lines"] = [["doroha", "Серед степу стоїть покинутий віз. Під рогожею щось є... або хтось."]]
			if randf() < 0.7:
				var r: String = Camp.RESOURCES.keys()[randi() % Camp.RESOURCES.size()]
				var n := 3 + lvl / 3
				ch.append({"text": "Обшукати віз", "reply": "Добра знахідка: %s і трохи гривень!" % Camp.RESOURCES[r].to_lower(),
					"outcome": {"res": {r: n}, "gold": 10 + 5 * lvl}})
			else:
				ch.append({"text": "Обшукати віз", "reply": "Пастка! Із-під рогожі вилетіла хмара зарази.",
					"outcome": {"hp_pct": -0.2}})
			ch.append({"text": "Не чіпати", "reply": "Береженого Бог береже.", "outcome": {}})
		"koval":
			ev["lines"] = [["koval", "Мандрівний коваль, до послуг! Твоя шабля просить точила — чую аж звідси."]]
			var w: Dictionary = player.equipment.get("weapon", {})
			var cost := Data.sharpen_cost(w) if not w.is_empty() else 0
			if not w.is_empty() and int(w["up"]) < Data.MAX_UPGRADE and player.gold >= cost:
				ch.append({"text": "Нагострити (+1) за %d грн" % cost, "reply": "Ось! Тепер вона й волосину на льоту розітне.",
					"outcome": {"gold": -cost, "sharpen": true}})
			ch.append({"text": "Дякую, не треба", "reply": "Як знаєш. Тупа шабля — півбіди, а от тупа голова...", "outcome": {}})
		"bizhentsi":
			var city := _random_city(player)
			ev["lines"] = [["bizhenka", "Козаче, ми з-під %s тікаємо. Зараза спалила хату, діти голодні..." % _city_name(city)]]
			if player.gold >= 30:
				ch.append({"text": "Дати 30 грн на хліб", "reply": "Хай тобі Бог помагає! Усім розкажемо, який ти.",
					"outcome": {"gold": -30, "loyalty": {city: 50}, "xp": 20 * lvl}})
			ch.append({"text": "Показати дорогу на Січ", "reply": "На Січ? Там нас приймуть? Дякуємо, козаче!",
				"outcome": {"loyalty": {"sich": 25}}})
			ch.append({"text": "Проїхати мимо", "reply": "...", "outcome": {}})
		"shynok":
			var price := 10 + 6 * lvl
			ev["lines"] = [["chumak", "Заходь до шинку, козаче! Вареники з сиром, юшка гаряча — все для тебе."]]
			if player.gold >= price:
				ch.append({"text": "Повечеряти (%d грн)" % price, "reply": "Ох і вареники! Сили — хоч гори вертай. І зілля в дорогу дали.",
					"outcome": {"gold": -price, "heal_full": true, "potions": 1}})
			ch.append({"text": "Їхати далі", "reply": "Ну, як знаєш. Голодний козак — злий козак!", "outcome": {}})
		"vovky":
			ev["lines"] = [["doroha", "Ніч. До табору підкрадається вовча зграя — очі світяться в темряві."]]
			if int(player.resources.get("wood", 0)) >= 2:
				ch.append({"text": "Розпалити вогонь вище (2 дерева)", "reply": "Вовки покрутились біля вогню й пішли. Ніч минула спокійно.",
					"outcome": {"res": {"wood": -2}}})
			ch.append({"text": "Відбиватися шаблею", "reply": "До світанку рубався з вовками. Покусаний, та живий — і досвіду набрався.",
				"outcome": {"hp_pct": -0.2, "xp": 40 * lvl}})
	return ev


## Застосовує наслідок вибору. Повертає короткий підсумок для банера ("" якщо нічого).
static func apply(world, player, outcome: Dictionary) -> String:
	var parts := []
	if outcome.has("gold"):
		player.gold = maxi(0, player.gold + int(outcome["gold"]))
		parts.append("%+d грн" % int(outcome["gold"]))
	if outcome.has("potions"):
		var n := int(outcome["potions"])
		player.potions = clampi(player.potions + n, 0, player.potion_max())
		parts.append("%+d зілля" % n)
	if outcome.has("xp"):
		player.add_xp(int(outcome["xp"]))
		parts.append("+%d досвіду" % int(outcome["xp"]))
	if outcome.has("res"):
		for r in outcome["res"]:
			player.resources[r] = maxi(0, int(player.resources.get(r, 0)) + int(outcome["res"][r]))
			parts.append("%+d %s" % [int(outcome["res"][r]), Camp.RESOURCES[r].to_lower()])
	if outcome.has("loyalty"):
		for city in outcome["loyalty"]:
			world.add_loyalty(city, int(outcome["loyalty"][city]))
			parts.append("%s +%d лояльності" % [Data.CITIES[city]["name"], int(outcome["loyalty"][city])])
	if outcome.get("heal_full", false):
		player.hp = player.max_hp
		parts.append("здоров'я відновлено")
	if outcome.has("hp_pct"):
		player.hp = clampf(player.hp + player.max_hp * float(outcome["hp_pct"]), 1.0, player.max_hp)
		parts.append("%d%% здоров'я" % roundi(float(outcome["hp_pct"]) * 100))
	if outcome.has("trip"):
		player.add_buff(outcome["trip"], Data.INSPIRED_TIME)
		parts.append("натхнення на %d хв бою: +15%% шкоди й досвіду" % int(Data.INSPIRED_TIME / 60.0))
	if outcome.get("sharpen", false):
		var w: Dictionary = player.equipment.get("weapon", {})
		if not w.is_empty():
			w["up"] = mini(Data.MAX_UPGRADE, int(w["up"]) + 1)
			player.recalc()
			parts.append("%s +%d" % [w["name"], w["up"]])
	return ", ".join(parts)
