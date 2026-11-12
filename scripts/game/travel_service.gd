extends RefCounted
## Події в дорозі: коли козак вирушає з мапи в місцевість, іноді трапляється пригода.
## Подія — це розмова з вибором. Ризик кожного варіанта кидається заздалегідь, тож відповідь
## одразу каже, чим усе скінчилося, а apply() застосовує вже відомий наслідок.
##
## Наслідок (outcome): gold, xp, potions, hp_pct (частка здоров'я, може бути від'ємна), heal_full,
## res {ресурс: к-сть}, loyalty {місто: очки}, trip (підсилення на час бою, див. Data.INSPIRED_TIME), sharpen (+1 заточки зброї).

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")

const CHANCE := 0.3
const COOLDOWN := 2  # стільки походів без пригод після кожної
## Пригоди, які вміє prepare(), і варіанти вибору кожної: у data/road_events.json мусять бути саме вони, з
## саме такими «choices» (перевіряє GameDB.problems()). Котра пригода трапиться — кидок за порядком файлу таблиці.
const CHOICES := {
	"chumaky": ["potions_two", "potions_one", "wood", "bye"], "gonets": ["potion", "carry", "pass"],
	"zasidka": ["fight", "sneak_ok", "sneak_fail"], "kobzar": ["listen", "hurry"], "viz": ["search_ok", "search_trap", "leave"],
	"koval": ["sharpen", "no"], "bizhentsi": ["bread", "road", "pass"], "shynok": ["supper", "ride"], "vovky": ["fire", "fight"],
}


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
	var kinds := GameDB.ids("road_events")
	var id: String = kinds[randi() % kinds.size()]
	s["seen"][id] = int(s["seen"].get(id, 0)) + 1
	return prepare(world, player, id)


static func _city_name(id: String) -> String:
	return Data.city(id)["name"]


static func _random_city(player) -> String:
	var ids := []
	for id in Data.city_ids():
		if int(Data.city(id)["level"]) <= player.level + 2:
			ids.append(id)
	return ids[randi() % ids.size()]


## Готує подію: текст, варіанти (лише ті, на які вистачає) та їхні наслідки. Тексти й мовець — запис
## data/road_events.json; які варіанти є, їхні ціни й наслідки — тут (CHOICES).
static func prepare(world, player, id: String) -> Dictionary:
	var lvl: int = player.level
	var ev := {"id": id, "lines": [], "choices": []}
	var ch: Array = ev["choices"]
	match id:
		"chumaky":
			# зілля стільки, скільки влазить у запас (до двох), і плата за стільки ж
			var fit: int = clampi(player.potion_max() - player.potions, 0, 2)
			var price := int(Data.potion_price(lvl) * 1.5 * maxi(fit, 1) / 2.0)
			ev["lines"] = [_line(id)]
			if player.gold >= price and player.potions < player.potion_max():
				ch.append(_choice(id, "potions_two" if fit >= 2 else "potions_one", {"gold": -price, "potions": fit}, [price]))
			var wood := int(player.resources.get("wood", 0))
			if wood >= 3:
				var g := wood * (3 + lvl)
				ch.append(_choice(id, "wood", {"gold": g, "res": {"wood": -wood}}, [wood, g]))
			ch.append(_choice(id, "bye", {}))
		"gonets":
			var city := _random_city(player)
			ev["lines"] = [_line(id, [_city_name(city)])]
			if player.potions > 0:
				ch.append(_choice(id, "potion", {"potions": -1, "loyalty": {city: 60}, "xp": 30 * lvl}, null, [_city_name(city)]))
			ch.append(_choice(id, "carry", {"gold": 20 + 12 * lvl, "loyalty": {city: 20}}))
			ch.append(_choice(id, "pass", {}))
		"zasidka":
			ev["lines"] = [_line(id)]
			ch.append(_choice(id, "fight", {"hp_pct": -0.25, "xp": 60 * lvl, "gold": 15 * lvl}))
			if randf() < 0.5:
				ch.append(_choice(id, "sneak_ok", {}))
			else:
				ch.append(_choice(id, "sneak_fail", {"hp_pct": -0.15}))
		"kobzar":
			ev["lines"] = [_line(id)]
			ch.append(_choice(id, "listen", {"trip": "inspired", "heal_full": true}))
			ch.append(_choice(id, "hurry", {}))
		"viz":
			ev["lines"] = [_line(id)]
			if randf() < 0.7:
				var r: String = Camp.resources()[randi() % Camp.resources().size()]
				var n := 3 + lvl / 3
				ch.append(_choice(id, "search_ok", {"res": {r: n}, "gold": 10 + 5 * lvl}, null, [Camp.res_name(r).to_lower()]))
			else:
				ch.append(_choice(id, "search_trap", {"hp_pct": -0.2}))
			ch.append(_choice(id, "leave", {}))
		"koval":
			ev["lines"] = [_line(id)]
			var w: Dictionary = player.equipment.get("weapon", {})
			var cost := Data.sharpen_cost(w) if not w.is_empty() else 0
			if not w.is_empty() and int(w["up"]) < Data.MAX_UPGRADE and player.gold >= cost:
				ch.append(_choice(id, "sharpen", {"gold": -cost, "sharpen": true}, [cost]))
			ch.append(_choice(id, "no", {}))
		"bizhentsi":
			var city := _random_city(player)
			ev["lines"] = [_line(id, [_city_name(city)])]
			if player.gold >= 30:
				ch.append(_choice(id, "bread", {"gold": -30, "loyalty": {city: 50}, "xp": 20 * lvl}))
			ch.append(_choice(id, "road", {"loyalty": {"sich": 25}}))
			ch.append(_choice(id, "pass", {}))
		"shynok":
			var price := 10 + 6 * lvl
			ev["lines"] = [_line(id)]
			if player.gold >= price:
				ch.append(_choice(id, "supper", {"gold": -price, "heal_full": true, "potions": 1}, [price]))
			ch.append(_choice(id, "ride", {}))
		"vovky":
			ev["lines"] = [_line(id)]
			if int(player.resources.get("wood", 0)) >= 2:
				ch.append(_choice(id, "fire", {"res": {"wood": -2}}))
			ch.append(_choice(id, "fight", {"hp_pct": -0.2, "xp": 40 * lvl}))
	return ev


## Репліка пригоди: [мовець, текст]; args — що підставити в текст (%s, %d).
static func _line(id: String, args = null) -> Array:
	var R: Dictionary = GameDB.row("road_events", id)
	return [R["speaker"], R["text"] % args if args != null else R["text"]]


## Варіант вибору: текст і відповідь із запису (choices.<key>), наслідок — від коду.
static func _choice(id: String, key: String, outcome: Dictionary, text_args = null, reply_args = null) -> Dictionary:
	var C: Dictionary = GameDB.row("road_events", id)["choices"][key]
	return {"text": C["text"] % text_args if text_args != null else C["text"], "reply": C["reply"] % reply_args if reply_args != null else C["reply"],
		"outcome": outcome}


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
			parts.append("%+d %s" % [int(outcome["res"][r]), Camp.res_name(r).to_lower()])
	if outcome.has("loyalty"):
		for city in outcome["loyalty"]:
			world.add_loyalty(city, int(outcome["loyalty"][city]))
			parts.append("%s +%d лояльності" % [Data.city(city)["name"], int(outcome["loyalty"][city])])
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
