extends RefCounted
## Спеціалізації: випробування в наставників. Стан — world.spec_trial:
##   {"spec": id класу, "stage": "active"/"turnin", "progress": n}
## Козак, що доріс до «change_at» свого класу (40-ї майстерності), іде на Січ, обирає наставника у вкладці «Наставники»,
## проходить випробування й повертається — наставник посвячує в спеціалізацію.
## Самі випробування (розмови, мета, зброя від наставника) — data/spec_trials.json.

const Classes := preload("res://scripts/data/classes.gd")
const Data := preload("res://scripts/data/data.gd")

const GameDB := preload("res://scripts/core/game_db.gd")


## Випробування спеціалізації (data/spec_trials.json): start, objective, end, item; {} — нема такого.
static func trial(spec: String) -> Dictionary:
	return GameDB.row("spec_trials", spec)


static func has_trial(spec: String) -> bool:
	return GameDB.table("spec_trials").has(spec)


static func state(world) -> Dictionary:
	return world.spec_trial


## Спеціалізації, які зараз відкриті для героя (порожньо, якщо ще рано).
static func available(player) -> Array:
	if not player.can_change_class():
		return []
	return player.class_info()["next"].filter(func(c): return has_trial(c))


static func start(world, player, spec: String) -> bool:
	if not spec in available(player):
		return false
	world.spec_trial = {"spec": spec, "stage": "active", "progress": 0}
	return true


static func objective(world) -> Dictionary:
	var s := state(world)
	if s.is_empty():
		return {}
	return trial(s["spec"])["objective"]


## Подія в поході. elite — чи вбитий ворог був елітою.
static func on_event(world, type: String, arg: String) -> Array:
	var s := state(world)
	if s.is_empty() or s["stage"] != "active":
		return []
	var obj := objective(world)
	var done := false
	match type:
		"clear", "dungeon":
			done = obj["type"] == type and obj["loc"] == arg
		"kill":
			if obj["type"] == "kill" and obj["enemy"] == arg:
				s["progress"] = int(s["progress"]) + 1
				done = int(s["progress"]) >= int(obj["count"])
		"elite":
			if obj["type"] == "elite":
				s["progress"] = int(s["progress"]) + 1
				done = int(s["progress"]) >= int(obj["count"])
	if not done:
		return []
	s["stage"] = "turnin"
	var mentor: String = Classes.info(s["spec"])["mentor"]
	return [{"text": "Випробування пройдено!\nНаставник чекає: %s" % Data.place_name(str(Classes.info(s["spec"])["where"])), "big": true, "mentor": mentor}]


## Розмова-посвята на Січі, коли випробування пройдене: {"spec", "lines"} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	var s := state(world)
	if s.is_empty() or s["stage"] != "turnin" or city != Classes.info(s["spec"])["where"]:
		return {}
	return {"spec": s["spec"], "lines": trial(s["spec"])["end"]}


## Посвята: новий клас, зброя від наставника. Повертає текст для банера.
static func complete(world, player) -> String:
	var s := state(world)
	if s.is_empty() or s["stage"] != "turnin":
		return ""
	var spec: String = s["spec"]
	var t: Dictionary = trial(spec)
	player.change_class(spec)
	var it := Data.gen_item(maxi(player.level, 1), 2, "weapon", t["item"]["type"])
	it["name"] = t["item"]["name"]
	if not player.add_item(it):
		player.inventory.append(it)
	player.equip(it["uid"])
	world.spec_trial = {}
	return "Ти — %s!\nОтримано: %s" % [Classes.info(spec)["name"].to_lower(), it["name"]]


static func objective_line(world) -> String:
	var s := state(world)
	if s.is_empty():
		return ""
	if s["stage"] == "turnin":
		return "◆ Повертайся до наставника (%s): посвята в %s" % [Data.place_name(str(Classes.info(s["spec"])["where"])), Classes.info(s["spec"])["name"].to_lower()]
	var obj := objective(world)
	var line: String = "◆ " + obj["text"]
	if obj.has("count"):
		line += " %d/%d" % [s["progress"], obj["count"]]
	return line


static func target(world) -> String:
	var s := state(world)
	if s.is_empty():
		return ""
	if s["stage"] == "turnin":
		return Classes.info(s["spec"])["where"]
	return objective(world).get("loc", "")
