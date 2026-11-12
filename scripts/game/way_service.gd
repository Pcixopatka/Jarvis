extends RefCounted
## «Шлях козака»: правила ланцюжка перших цілей. Кроки — у WayData.
## (PathService — це інше: вибір дороги Козак, Стрілець чи Волхв.)
## Герой іде кроками по черзі: виконав умову, забрав нагороду, побачив наступний.
## Бувалий герой, у якого багато вже зроблено, забирає все готове одним дотиком.

const Data := preload("res://scripts/data/data.gd")
const Path := preload("res://scripts/data/way_data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

const TAB_JOURNAL := 1


static func _svc(name: String):
	return load("res://scripts/game/%s.gd" % name)


static func state(world) -> Dictionary:
	if world.way.is_empty():
		world.way = {"step": 0}
	return world.way


static func total() -> int:
	return Path.STEPS.size()


## Номер нинішнього кроку (0..total). total — шлях пройдено.
static func index(world) -> int:
	return clampi(int(state(world)["step"]), 0, total())


static func finished(world) -> bool:
	return index(world) >= total()


## Нинішній крок або порожній словник, коли шлях пройдено.
static func current(world) -> Dictionary:
	return {} if finished(world) else Path.STEPS[index(world)]


# ======================= Умови =======================

static func _stat(world, name: String) -> int:
	return int(world.stats.get(name, 0))


## Чи виконано умову кроку.
static func is_done(step: Dictionary, world, player) -> bool:
	var c: Dictionary = step["check"]
	if c.has("stat"):
		var n := _stat(world, str(c["stat"]))
		if c.has("or"):
			n += _stat(world, str(c["or"]))
		# герої, що грали до появи лічильника, не мають проходити вже пройдене
		match str(c["stat"]):
			"field":
				n += world.cleared.size()
			"dungeon":
				for id in world.cleared:
					if Data.is_place(id) and Data.place(id)["type"] == "dungeon":
						n += 1
			"boss":
				for k in world.stats:
					if str(k).begins_with("boss:"):
						n += int(world.stats[k])
		return n >= int(c["n"])
	if c.has("equip"):
		return player.equipment.size() >= int(c["equip"])
	if c.has("spent"):
		match str(c["spent"]):
			"stat":
				for k in player.stats:
					if int(player.stats[k]) - Data.STAT_BASE - int(player.stat_gifts.get(k, 0)) > 0:
						return true
				return false
			"skill":
				for id in player.skills:
					if int(player.skills[id]) > int(player.skill_gifts.get(id, 0)):
						return true
				return false
			"perk":
				return not player.perks.is_empty()
	if c.has("quests"):
		return not world.quests.is_empty() or not world.loyalty.is_empty()
	if c.has("loyalty"):
		for city in world.loyalty:
			if int(world.loyalty[city]) > 0:
				return true
		return false
	if c.has("companions"):
		return world.companions.size() >= int(c["companions"])
	if c.has("camp"):
		return int(_svc("camp_service").built_count(world)) >= int(c["camp"])
	if c.has("tier"):
		return int(player.class_info()["tier"]) >= int(c["tier"])
	return false


## Чи можна вже забрати нагороду за нинішній крок.
static func ready(world, player) -> bool:
	var st := current(world)
	return not st.is_empty() and is_done(st, world, player)


## Скільки кроків поспіль уже виконано, починаючи з нинішнього.
static func ready_count(world, player) -> int:
	var n := 0
	for i in range(index(world), total()):
		if not is_done(Path.STEPS[i], world, player):
			break
		n += 1
	return n


# ======================= Нагорода =======================

## Нагорода словами: «400 грн, дерева 20».
static func reward_text(step: Dictionary) -> String:
	var r: Dictionary = step["reward"]
	var parts := []
	if int(r.get("gold", 0)) > 0:
		parts.append("%d грн" % int(r["gold"]))
	if int(r.get("potions", 0)) > 0:
		parts.append("зілля: %d" % int(r["potions"]))
	if int(r.get("mana", 0)) > 0:
		parts.append("зілля наснаги: %d" % int(r["mana"]))
	for res in r.get("res", {}):
		parts.append("%s: %d" % [Camp.res_name(res).to_lower(), int(r["res"][res])])
	if int(r.get("trophy", 0)) > 0:
		parts.append("трофеї: %d" % int(r["trophy"]))
	if r.has("item"):
		parts.append("%s річ" % Data.rarity_name(int(r["item"])).to_lower())
	if r.has("stone"):
		parts.append(str(_svc("stone_service").NAMES[r["stone"]]))
	return ", ".join(parts)


static func _grant(step: Dictionary, player) -> void:
	var r: Dictionary = step["reward"]
	player.gold += int(r.get("gold", 0))
	# зілля понад запас не пропадає: що не вмістилось, лягає гривнями за півціни
	for i in int(r.get("potions", 0)):
		if not player.add_potion():
			player.gold += Data.potion_price(player.level) / 2
	for i in int(r.get("mana", 0)):
		if not player.add_mana_potion():
			player.gold += Data.mana_potion_price(player.level) / 2
	for res in r.get("res", {}):
		player.resources[res] = int(player.resources.get(res, 0)) + int(r["res"][res])
	if int(r.get("trophy", 0)) > 0:
		player.resources[Camp.TROPHY] = int(player.resources.get(Camp.TROPHY, 0)) + int(r["trophy"])
	if r.has("item"):
		player.add_item(Data.gen_item(maxi(1, int(player.level)), int(r["item"])), true)  # нагорода лягає й понад місце
	if r.has("stone"):
		_svc("stone_service").grant(player, str(r["stone"]))


## Забрати нагороду за нинішній крок. Повертає рядки для гравця (порожньо — ще не виконано).
static func claim(world, player) -> Array:
	if not ready(world, player):
		return []
	var st := current(world)
	_grant(st, player)
	state(world)["step"] = index(world) + 1
	var msgs := ["Шлях козака: %s" % st["title"], "Нагорода: %s" % reward_text(st)]
	if finished(world):
		msgs.append("Шлях козака пройдено!")
	else:
		msgs.append("Далі: %s" % current(world)["title"])
	return msgs


## Забрати все, що вже виконано поспіль. Повертає короткий підсумок.
static func claim_all(world, player) -> Array:
	var n := 0
	var gold0: int = player.gold
	var last := []
	while ready(world, player):
		last = claim(world, player)
		n += 1
	if n == 0:
		return []
	if n == 1:
		return last
	var msgs := ["Шлях козака: забрано нагород %d" % n, "Гривень: +%d, решта в торбі й на хуторі" % (int(player.gold) - gold0)]
	msgs.append("Шлях козака пройдено!" if finished(world) else "Далі: %s" % current(world)["title"])
	return msgs


# ======================= Куди йти =======================

## Куди веде крок: {"place": id для мапи або "", "tab": вкладка екрана героя або -1}.
static func go(step: Dictionary, world, player, here: String = "") -> Dictionary:
	var g: Dictionary = step.get("go", {})
	if g.has("tab"):
		return {"place": "", "tab": int(g["tab"])}
	var place := str(g.get("place", ""))
	match place:
		"city":
			place = str(_svc("events_board")._near_city(here))
		"spot":
			place = str(_svc("guide_service").best_place(world, player, here))
		"dungeon":
			place = _dungeon(player)
	return {"place": place, "tab": -1 if place != "" else TAB_JOURNAL}


## Печера, що під силу герою: найвищого рівня серед не сильніших за нього (або найлегша).
static func _dungeon(player) -> String:
	var best := ""
	var best_lvl := -1
	var easiest := ""
	var easiest_lvl := 9999
	for id in Data.place_ids():
		var L: Dictionary = Data.place(id)
		if L["type"] != "dungeon" or L.get("endless", false) or L.get("scale", false) or L.has("peril"):
			continue
		var lvl := int(L["level"])
		if lvl < easiest_lvl:
			easiest_lvl = lvl
			easiest = id
		if lvl <= int(player.level) and lvl > best_lvl:
			best_lvl = lvl
			best = id
	return best if best != "" else easiest
