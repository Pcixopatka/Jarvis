extends RefCounted
## Душі: хто яку лишає, з яким шансом, гнізда в речах, торбинка душ героя й сума бонусів.
## Таблиці душ — data/souls.json, soul_effects.json, soul_tiers.json (див. Souls); тут лише правила.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const Souls := preload("res://scripts/data/souls.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Elites := preload("res://scripts/data/elites.gd")
const FarService := preload("res://scripts/game/far_service.gd")

static var _base_hp := {}


# ======================= Яка душа =======================

## id душі ворога ("" — душі нема: примара, прикликаний без досвіду).
static func id_for(e) -> String:
	if e.illusion or int(e.xp_value) <= 0:
		return ""
	if e.is_boss and GameDB.has_boss(e.kind):
		return "b_" + str(e.kind)
	return str(e.kind)


## Опис душі. Для нечисті, якої ще нема в таблиці, збирає просту душу, щоб нова істота не лишилась без неї.
static func info(id: String) -> Dictionary:
	if Souls.has(id):
		return Souls.def(id)
	var boss := id.begins_with("b_")
	var kind := id.substr(2) if boss else id
	var who: String = str(GameDB.boss_name(kind, "")) if boss else str(GameDB.mob_name(kind, ""))
	return {"name": ("Душа: %s" % who) if who != "" else "Душа невідомої нечисті", "tier": Souls.BOSS_TIER if boss else 2,
		"fx": {"hp": 9 if boss else 4}, "lore": "Цієї нечисті ще нема в Пом'янику."}


static func soul_name(id: String) -> String:
	return str(info(id)["name"])


static func tier(id: String) -> int:
	return int(info(id)["tier"])


static func color(id: String) -> Color:
	return Souls.tier_color(clampi(tier(id), 1, Souls.max_tier()))


## Бонуси душі словами: «+5% швидкості бігу, перекид готовий на 8% швидше».
static func fx_text(id: String) -> String:
	var parts := []
	var fx: Dictionary = info(id)["fx"]
	for k in fx:
		parts.append(str(Souls.fx(k)["text"]) % str(int(fx[k])))
	return ", ".join(parts)


## Чия це душа: назва нечисті чи боса.
static func owner_name(id: String) -> String:
	if id.begins_with("b_"):
		return str(GameDB.boss_name(id.substr(2), ""))
	return str(GameDB.mob_name(id, ""))


## Душі, чия нечисть справді є в грі (таблицю можна доповнити наперед).
static func known() -> Array:
	var out := []
	for id in Souls.ids():
		if owner_name(id) != "":
			out.append(id)
	return out


# ======================= Шанс =======================

static func class_of(e) -> String:
	if e.is_boss:
		return "boss"
	if int(e.bounty_id) > 0 or e.treasure_guard:
		return "named"
	return "elite" if e.elite else "regular"


static func _hp_of(kind: String, boss: bool) -> float:
	var key := ("b_" if boss else "") + kind
	if not _base_hp.has(key):
		var e = load("res://scripts/entities/enemy.gd").new()
		e.setup(kind, 1, boss)
		_base_hp[key] = maxf(1.0, float(e.max_hp))
		e.free()
	return float(_base_hp[key])


## Гідність ворога: 1, якщо він не слабший за звичайну нечисть рівня героя (Data.enemy_std_hp).
## Слабша нечисть із давно пройдених місць лишає душу рідше, тож легкі місця не стають копальнею душ.
## Від спорядження героя гідність не залежить: краще вдягнений бере душі так само часто, лише швидше.
static func worth(player, e) -> float:
	var std: float = float(e.max_hp) / _hp_of(str(e.kind), e.is_boss) * _hp_of("zarazhenyi", false)
	if e.elite:
		std /= float(Elites.HP_MULT)
	return clampf(std / Data.enemy_std_hp(int(player.level)), Souls.W_MIN_BOSS if e.is_boss else Souls.W_MIN, 1.0)


## Нечисть упала: чи лишає вона душу. Повертає id душі або "". Веде поклик душ героя.
static func roll(player, e) -> String:
	var id := id_for(e)
	if id == "":
		return ""
	var cls := class_of(e)
	if Souls.FIRST_LEVEL > 0 and int(player.soul_found) == 0 and int(player.level) >= Souls.FIRST_LEVEL and cls != "regular":
		return id  # перша душа героя: щоб нове одразу трапилось на очі
	var p: float = float(Souls.CHANCE[cls]) * worth(player, e)
	if e.is_boss and float(e.enrage_after) > 0.0:
		p = Souls.CHANCE_PERIL  # надважкий бос у своїй печері
	p *= (1.0 + float(player.art.get("soul", 0.0))) * player.loot_luck()  # артефакт «Велнясова торба» і звитяга «Талан»
	if randf() < p * (1.0 + minf(Souls.PITY_MAX, float(player.soul_luck))):
		return id
	player.soul_luck = float(player.soul_luck) + p
	return ""


## Душа дісталась героєві: у торбинку.
static func grant(player, id: String) -> void:
	player.souls[id] = int(player.souls.get(id, 0)) + 1
	player.soul_found = int(player.soul_found) + 1
	player.soul_luck = 0.0


# ======================= Гнізда =======================

static func has_socket(item: Dictionary) -> bool:
	return int(item.get("sock", 0)) > 0


static func soul_in(item: Dictionary) -> String:
	return str(item.get("soul", ""))


## Чому в речі не можна пробити гніздо ("" — можна).
static func socket_block(item: Dictionary) -> String:
	if item.is_empty() or not Data.slots().has(item.get("slot", "")):
		return "У цій речі гнізда не буває"
	if has_socket(item):
		return "Гніздо вже є"
	if int(item["rarity"]) < 1:
		return "У звичайній речі душа не тримається"
	return ""


## Ціна гнізда: за рівнем речі чи героя (що більше) і рідкістю.
static func socket_cost(player, item: Dictionary, cost_mult: float = 1.0) -> Dictionary:
	var lv: int = maxi(int(item["ilvl"]), int(player.level))
	return {"gold": int(maxi(200, int(20.0 * lv * lv * (1.0 + 0.5 * mini(int(item["rarity"]), 4)))) * cost_mult), "trophy": Souls.SOCKET_TROPHY}


static func can_pay(player, cost: Dictionary) -> bool:
	return int(player.gold) >= int(cost["gold"]) and int(player.resources.get(Camp.TROPHY, 0)) >= int(cost["trophy"])


static func make_socket(player, uid: int, cost_mult: float = 1.0) -> bool:
	var it: Dictionary = player.find_item(uid)
	if socket_block(it) != "":
		return false
	var cost := socket_cost(player, it, cost_mult)
	if not can_pay(player, cost):
		return false
	player.gold -= int(cost["gold"])
	player.resources[Camp.TROPHY] = int(player.resources.get(Camp.TROPHY, 0)) - int(cost["trophy"])
	it["sock"] = 1
	it["spent"] = int(it.get("spent", 0)) + int(cost["gold"])
	return true


## Чому душу не можна вселити в цю річ ("" — можна).
static func insert_block(player, item: Dictionary, id: String) -> String:
	if not has_socket(item):
		return "У речі нема гнізда"
	if soul_in(item) != "":
		return "Гніздо зайняте"
	if int(player.souls.get(id, 0)) <= 0:
		return "Такої душі в торбинці нема"
	if tier(id) >= Souls.BOSS_TIER and not item["slot"] in Souls.BOSS_SLOTS:
		return "Душа боса стає лише в зброю чи оберіг"
	return ""


static func insert(player, uid: int, id: String) -> bool:
	var it: Dictionary = player.find_item(uid)
	if it.is_empty() or insert_block(player, it, id) != "":
		return false
	player.souls[id] = int(player.souls[id]) - 1
	if int(player.souls[id]) <= 0:
		player.souls.erase(id)
	it["soul"] = id
	player.recalc()
	return true


static func remove_cost(player, item: Dictionary, cost_mult: float = 1.0) -> int:
	return int(int(socket_cost(player, item, cost_mult)["gold"]) * Souls.REMOVE_PART)


## Вийняти душу з речі (за гривні): вона ціла вертається в торбинку.
static func remove(player, uid: int, cost_mult: float = 1.0) -> bool:
	var it: Dictionary = player.find_item(uid)
	if it.is_empty() or soul_in(it) == "":
		return false
	var cost := remove_cost(player, it, cost_mult)
	if int(player.gold) < cost:
		return false
	player.gold -= cost
	strip(player, it)
	player.recalc()
	return true


## Річ іде геть (продаж, переплавка, викинули): душа вертається в торбинку. Повертає, чи була душа.
static func strip(player, item: Dictionary) -> bool:
	var id := soul_in(item)
	if id == "":
		return false
	player.souls[id] = int(player.souls.get(id, 0)) + 1
	item.erase("soul")
	return true


# ======================= Бонуси =======================

## Які душі діють: лише у вдягнених речах, кожна душа один раз.
static func active_ids(player) -> Array:
	var out := []
	for slot in Data.slots():
		if player.equipment.has(slot):
			var id := soul_in(player.equipment[slot])
			if id != "" and not id in out:
				out.append(id)
	return out


## Сума бонусів душ героя частками (0,05 = 5%), уже з межами.
static func fx_of(player) -> Dictionary:
	var sum := {}
	for id in active_ids(player):
		var fx: Dictionary = info(id)["fx"]
		for k in fx:
			sum[k] = float(sum.get(k, 0.0)) + float(fx[k])
	var out := {}
	for k in sum:
		out[k] = minf(float(sum[k]), float(Souls.fx(k)["cap"])) / 100.0
	return out


## Скільки душ у торбинці.
static func pouch_count(player) -> int:
	var n := 0
	for id in player.souls:
		n += int(player.souls[id])
	return n
