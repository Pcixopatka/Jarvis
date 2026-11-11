extends RefCounted
## Швидкий похід: місце, яке герой уже проходив кілька разів, зачищається миттю, без бою.
## Плата за це — перегляд реклами (див. Game.quick_raid). Здобич рахується тими самими шансами,
## що й у бою (Combat._drop_loot), але рідкісне з босів тут не падає: золоті речі, артефакти,
## камені долі й душі дає лише справжній бій. Зараза, ніч, розшук і скарб у швидкому поході не діють.
## Стан денної межі — world.ads["quick_day"], world.ads["quick_used"].

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Elites := preload("res://scripts/data/elites.gd")
const FarService := preload("res://scripts/game/far_service.gd")
const Premium := preload("res://scripts/game/premium_service.gd")

const MIN_CLEARS := 3  # скільки разів треба пройти місце по-справжньому, щоб відкрився швидкий похід
const PER_DAY := 10  # швидких походів на день

static var _xp_cache := {}


static func _today() -> String:
	return Time.get_date_string_from_system()


static func used_today(world) -> int:
	return int(world.ads.get("quick_used", 0)) if str(world.ads.get("quick_day", "")) == _today() else 0


## Скільки швидких походів на день: з Гетьманським універсалом більше.
static func per_day(world) -> int:
	return Premium.QUICK_PER_DAY if Premium.active(world) else PER_DAY


static func left_today(world) -> int:
	return maxi(0, per_day(world) - used_today(world))


## Чи буває в цьому місці швидкий похід узагалі: звичайна місцевість чи печера, не Глибини, не Башта й не надважка печера.
static func applies(loc_id: String) -> bool:
	if not Data.LOCATIONS.has(loc_id):
		return false
	var L: Dictionary = Data.LOCATIONS[loc_id]
	return L["type"] in ["field", "dungeon"] and not L.get("endless", false) and not L.has("peril")


## Чому швидкий похід зараз недоступний ("" — доступний).
static func block_reason(world, player, loc_id: String) -> String:
	if not applies(loc_id):
		return "тут його не буває"
	var times: int = int(world.cleared.get(loc_id, 0))
	if times < MIN_CLEARS:
		return "відкриється, коли пройдеш це місце %d рази (зараз %d)" % [MIN_CLEARS, times]
	if int(Data.LOCATIONS[loc_id]["level"]) > int(player.level):
		return "місце ще надто сильне для тебе"
	if left_today(world) <= 0:
		return "на сьогодні скінчились, завтра буде ще %d" % per_day(world)
	return ""


## Досвід із ворога цього виду й рівня (як у бою).
static func _xp_of(kind: String, level: int, boss: bool) -> int:
	var key := "%s:%d:%s" % [kind, level, boss]
	if not _xp_cache.has(key):
		var e = load("res://scripts/entities/enemy.gd").new()
		e.setup(kind, level, boss)
		_xp_cache[key] = int(e.xp_value)
		e.free()
	return int(_xp_cache[key])


## Скільки нечисті в місці: зачистка поля чи всі кімнати печери (без боса).
static func kills(L: Dictionary) -> int:
	if L["type"] == "dungeon":
		var n := 0
		for room in range(1, int(L["rooms"]) + 1):
			n += Data.DUNGEON_ROOM_BASE + room * Data.DUNGEON_ROOM_PER
		return n
	return int(L.get("goal", mini(FarService.GOAL_MAX, Data.FIELD_GOAL_BASE + int(L["level"]) * Data.FIELD_GOAL_PER_LEVEL)))


## Провести швидкий похід: видати здобич і зарахувати його. Повертає підсумок:
## {"name", "kills", "elites", "xp", "gold", "items": [речі в торбі], "sold", "res": {назва: скільки},
##  "trophy", "potions", "mana", "quests": [повідомлення про виконані завдання], "kinds": {вид: вбито}}
## drop_boost — реклама «×2 здобичі», festive — святкові надбавки (HolidayService.combat_mods()),
## pickup — фільтр автопідбору (Combat.pickup_filter): рідкості, яких він не бере, одразу продаються.
static func run(world, player, loc_id: String, drop_boost: float = 1.0, festive: Dictionary = {}, pickup: Array = []) -> Dictionary:
	var L: Dictionary = Data.LOCATIONS[loc_id]
	var lvl: int = Data.loc_level(L, int(player.level))
	var dungeon: bool = L["type"] == "dungeon"
	var out := {"name": str(L["name"]), "kills": 0, "elites": 0, "xp": 0, "gold": 0, "items": [], "sold": 0,
		"res": {}, "trophy": 0, "potions": 0, "mana": 0, "quests": [], "kinds": {}}
	var loot := []  # речі, які треба покласти в торбу
	var coin_gold := 0
	var plain_gold := 0  # гривні за зачистку: без частки з монет
	var xp := 0
	var trophy_bonus: int = player.pk("h_trophy") + int(player.art.get("trophy", 0)) + int(festive.get("trophy", 0))
	var loot_mult: float = (1.0 + float(festive.get("loot", 0.0))) * drop_boost
	var enemies: Array = L["enemies"]
	for i in kills(L):
		var kind: String = enemies[randi() % enemies.size()]
		var exp_one: int = maxi(1, _xp_of(kind, lvl, false))
		out["kills"] += 1
		out["kinds"][kind] = int(out["kinds"].get(kind, 0)) + 1
		for m in world.on_kill(kind):
			if str(m).begins_with("Завдання виконано") and not m in out["quests"]:
				out["quests"].append(m)
		if randf() < Elites.CHANCE:
			out["elites"] += 1
			var part: int = maxi(1, exp_one * Elites.XP_MULT / 3)
			xp += part * 3
			coin_gold += Data.coin_gold(part) * 3
			if randf() < Elites.ITEM_CHANCE * loot_mult:
				loot.append(_item(lvl, Data.roll_rarity(lvl, 1), festive))
			_bundle(out, player, L, roundi(2 * drop_boost), festive)
			out["trophy"] += 1 + trophy_bonus
			if randf() < 0.3 and player.add_potion():
				out["potions"] += 1
			continue
		xp += exp_one
		coin_gold += Data.coin_gold(exp_one)
		if randf() < Camp.RESOURCE_DROP_CHANCE * drop_boost:
			_res(out, player, _roll_resource(L), _res_amount(1, player, festive))
		if randf() < Data.POTION_DROP_CHANCE and player.add_potion():
			out["potions"] += 1
		if randf() < Data.MANA_POTION_DROP_CHANCE * (2.0 if player.is_volkhv() else 1.0) and player.add_mana_potion():
			out["mana"] += 1
		if randf() < Data.ITEM_DROP_CHANCE * loot_mult:
			loot.append(_item(lvl, Data.roll_rarity(lvl), festive))
	if dungeon:
		# господар печери: звичайна здобич боса, без золота, артефактів, каменів і душ
		var bxp: int = maxi(1, _xp_of(str(L["boss"]), lvl, true))
		var bpart: int = maxi(1, bxp / 10)
		xp += bpart * 10
		coin_gold += Data.coin_gold(bpart) * 10
		for i in (3 if drop_boost > 1.0 else 2):
			loot.append(_item(lvl + 1, Data.roll_rarity(lvl, 2), festive))
		if player.add_potion():
			out["potions"] += 1
		out["trophy"] += 3 + lvl / 5 + trophy_bonus
		plain_gold += 40 * lvl
		_bundle(out, player, L, 7, festive)
		for m in world.on_dungeon(loc_id):
			if not m in out["quests"]:
				out["quests"].append(m)
	else:
		plain_gold += 25 * lvl
		for i in 2:
			loot.append(_item(lvl, Data.roll_rarity(lvl, 1), festive))
		xp += 6 * lvl * 2
		coin_gold += 6 * Data.coin_gold(lvl * 2)
		_bundle(out, player, L, 5, festive)
		world.cleared[loc_id] = int(world.cleared.get(loc_id, 0)) + 1
	# видати
	var gold0: int = player.gold
	player.add_gold(coin_gold + plain_gold)
	player.add_xp(xp)
	out["xp"] = xp
	if int(out["trophy"]) > 0:
		player.resources[Camp.TROPHY] = int(player.resources.get(Camp.TROPHY, 0)) + int(out["trophy"])
	for it in loot:
		var r: int = int(it["rarity"])
		var wanted: bool = r >= pickup.size() or bool(pickup[r])
		if wanted and player.add_item(it):
			out["items"].append(it)
		else:
			player.gold += Data.sell_price(it)  # фільтр не бере або торба повна: продано, як при виході з місця
			out["sold"] += 1
	out["gold"] = int(player.gold) - gold0
	# зарахувати день
	if str(world.ads.get("quick_day", "")) != _today():
		world.ads["quick_day"] = _today()
		world.ads["quick_used"] = 0
	world.ads["quick_used"] = int(world.ads.get("quick_used", 0)) + 1
	return out


static func _item(ilvl: int, rarity: int, festive: Dictionary) -> Dictionary:
	if rarity < 3 and randf() < float(festive.get("rare", 0.0)):
		rarity += 1
	return Data.gen_item(ilvl, rarity)


static func _res_amount(n: int, player, festive: Dictionary) -> int:
	return int(round(n * (1.0 + float(festive.get("res", 0.0)) + float(player.art.get("res", 0.0)))))


static func _roll_resource(L: Dictionary) -> String:
	if randf() < 0.7:
		return str(Camp.BIOME_RESOURCE.get(L.get("biome", "steppe"), "wood"))
	return Camp.RESOURCES.keys()[randi() % Camp.RESOURCES.size()]


static func _res(out: Dictionary, player, res: String, amount: int) -> void:
	if randf() < 0.15 * player.pk("h_eye"):
		amount *= 2  # Зіркий погляд (Загартування)
	player.resources[res] = int(player.resources.get(res, 0)) + amount
	out["res"][res] = int(out["res"].get(res, 0)) + amount


static func _bundle(out: Dictionary, player, L: Dictionary, n: int, festive: Dictionary) -> void:
	for i in n:
		_res(out, player, _roll_resource(L), _res_amount(1 + int(L["level"]) / 4, player, festive))


## Підсумок словами для банера.
static func summary(r: Dictionary) -> String:
	var lines := ["Швидкий похід: %s" % r["name"], "Знищено нечисті: %d. Досвід +%d, гривні +%d" % [int(r["kills"]), int(r["xp"]), int(r["gold"])]]
	var got := []
	if not r["items"].is_empty():
		got.append("речей у торбу: %d" % r["items"].size())
	if int(r["sold"]) > 0:
		got.append("продано зайвого: %d" % int(r["sold"]))
	var res_n := 0
	for k in r["res"]:
		res_n += int(r["res"][k])
	if res_n > 0:
		got.append("ресурсів: %d" % res_n)
	if int(r["trophy"]) > 0:
		got.append("трофеїв: %d" % int(r["trophy"]))
	if int(r["potions"]) + int(r["mana"]) > 0:
		got.append("зілля: %d" % (int(r["potions"]) + int(r["mana"])))
	if not got.is_empty():
		lines.append("Здобич: " + ", ".join(got))
	for m in r["quests"]:
		lines.append(str(m))
	return "\n".join(lines)
