extends RefCounted
## Дошка розшуку: у містах висять оголошення про іменовану нечисть у навколишніх місцевостях.
## Узяв — ціль з'являється на місцевості (еліта з властивостями, удвічі міцніша); убив — неси голову
## в те саме місто по гривні, славу й лояльність. Стан — world.bounties:
##   {"boards": {місто: {"born": вік, "list": [оголошення]}}, "active": [оголошення], "age": походів, "next_id": n, "done": n}
## Оголошення: {"id", "city", "kind", "name", "loc", "affixes", "gold", "glory", "killed"}.

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const Elites := preload("res://scripts/data/elites.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")

static var MIN_LEVEL: int  # рівень місцевості, з якого буває розшук


## Числа-правила вище лежать у data/settings.json (запис «bounty»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("bounty")
	MIN_LEVEL = S["min_level"]


static func state(world) -> Dictionary:
	var s: Dictionary = world.bounties
	if s.is_empty():
		s["boards"] = {}
		s["active"] = []
		s["age"] = 0
		s["next_id"] = 1
		s["done"] = 0
	return s


static func unlocked(player) -> bool:
	return player.level >= MIN_LEVEL


## Похід скінчився: дошки старішають.
static func tick(world) -> void:
	var s := state(world)
	s["age"] = int(s["age"]) + 1


## Місцевості для оголошень цього міста: дикі місця поруч за рівнем і не надто сильні для героя.
static func candidates(city: String, player) -> Array:
	var lvl: int = int(Data.city(city)["level"])
	var out := []
	for id in Data.place_ids():
		var L: Dictionary = Data.place(id)
		if L["type"] != "field" or L.get("endless", false):
			continue
		var l: int = int(L["level"])
		if l >= lvl - 3 and l <= lvl + 3 and l <= player.level + 3 and l >= MIN_LEVEL - 2:
			out.append(id)
	if out.is_empty():
		# Нічого поруч — беремо найближчу за рівнем дику місцевість
		var best := ""
		var best_d := 999
		for id in Data.place_ids():
			var L: Dictionary = Data.place(id)
			if L["type"] != "field" or L.get("endless", false):
				continue
			var d: int = absi(int(L["level"]) - lvl)
			if d < best_d:
				best_d = d
				best = id
		out.append(best)
	return out


static func _gen(world, city: String, player) -> Dictionary:
	var s := state(world)
	var locs := candidates(city, player)
	var loc: String = locs[randi() % locs.size()]
	var L: Dictionary = Data.place(loc)
	var kinds: Array = L["enemies"].filter(func(k): return not GameDB.bounty_names(k).is_empty())
	var kind: String = kinds[randi() % kinds.size()] if not kinds.is_empty() else "vovkulaka"
	var names: Array = GameDB.bounty_names(kind)
	var keys := Elites.affix_ids().duplicate()
	keys.shuffle()
	var n := 3 if int(L["level"]) >= 12 else 2
	var id: int = int(s["next_id"])
	s["next_id"] = id + 1
	return {"id": id, "city": city, "kind": kind, "name": names[randi() % names.size()], "loc": loc,
		"affixes": keys.slice(0, n), "gold": 60 + 25 * maxi(int(L["level"]), player.level), "glory": 6 if n == 2 else 10, "killed": false}


## Дошка міста (оновлюється кожні BOUNTY_REFRESH походів; узяті оголошення на дошку не повертаються).
static func board(world, city: String, player) -> Array:
	var s := state(world)
	if not unlocked(player):
		return []
	var b: Dictionary = s["boards"].get(city, {})
	if b.is_empty() or int(s["age"]) - int(b["born"]) >= Acts.BOUNTY_REFRESH:
		var list := []
		for i in Acts.BOUNTY_BOARD:
			var bt := _gen(world, city, player)
			for attempt in 6:
				if not _name_taken(world, list, bt["name"]):
					break
				bt = _gen(world, city, player)
			list.append(bt)
		b = {"born": int(s["age"]), "list": list}
		s["boards"][city] = b
	return b["list"]


static func _name_taken(world, list: Array, name: String) -> bool:
	for b in list + state(world)["active"]:
		if b["name"] == name:
			return true
	return false


static func can_take(world) -> bool:
	return state(world)["active"].size() < Acts.BOUNTY_ACTIVE


static func take(world, city: String, id: int, player) -> bool:
	if not can_take(world):
		return false
	var list: Array = board(world, city, player)
	for i in list.size():
		if int(list[i]["id"]) == id:
			state(world)["active"].append(list[i])
			list.remove_at(i)
			return true
	return false


static func drop(world, id: int) -> void:
	var act: Array = state(world)["active"]
	for i in act.size():
		if int(act[i]["id"]) == id:
			act.remove_at(i)
			return


## Узяті оголошення цього міста (щоб показати на його дошці).
static func mine(world, city: String) -> Array:
	return state(world)["active"].filter(func(b): return b["city"] == city)


## Ціль, що ходить у цій місцевості ({} — нема). Рівень цілі — не нижчий за героя.
static func target_at(world, loc: String) -> Dictionary:
	for b in state(world)["active"]:
		if b["loc"] == loc and not b["killed"]:
			return b
	return {}


## Доповнення до опису місцевості для бою.
static func mods_for(world, loc: String, player) -> Dictionary:
	var b := target_at(world, loc)
	if b.is_empty():
		return {}
	var info: Dictionary = b.duplicate()
	info["level"] = maxi(int(Data.place(loc)["level"]) + 1, player.level)
	return {"bounty": info}


## Місцевості з живими цілями — для позначок на мапі.
static func targets(world) -> Array:
	var out := []
	for b in state(world)["active"]:
		if not b["killed"]:
			out.append(b["loc"])
	return out


## Ціль убито в бою. Повертає повідомлення ("" — це була не ціль розшуку).
static func on_kill(world, id: int) -> String:
	for b in state(world)["active"]:
		if int(b["id"]) == id and not b["killed"]:
			b["killed"] = true
			return "%s — голова твоя!\nНеси її в місто %s по нагороду" % [b["name"], Data.place_name(b["city"])]
	return ""


## Здати голову в місті. Повертає повідомлення (порожньо — нема чого здавати).
static func turn_in(world, player, id: int) -> Array:
	var s := state(world)
	var act: Array = s["active"]
	for i in act.size():
		var b: Dictionary = act[i]
		if int(b["id"]) != id or not b["killed"]:
			continue
		act.remove_at(i)
		s["done"] = int(s["done"]) + 1
		player.gold += int(b["gold"])
		world.add_loyalty(b["city"], 30)
		var msgs := ["Розшук закрито: %s. +%d грн, +%d слави, +30 лояльності" % [b["name"], b["gold"], b["glory"]]]
		msgs.append_array(GloryService.add(world, player, int(b["glory"])))
		return msgs
	return []


## Опис властивостей цілі для оголошення: «підпалює, тримає удар».
static func traits(b: Dictionary) -> String:
	var parts := []
	for a in b["affixes"]:
		parts.append(Elites.affix(a)["desc"])
	return ", ".join(parts)
