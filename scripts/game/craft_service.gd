extends RefCounted
## Крафт у кузні хутора:
##  • кування нової речі обраного виду й якості (з заліза, дерева/трав і трофеїв);
##  • перекування однієї властивості речі (решта лишається);
##  • оновлення улюбленої речі до свого рівня (сюжетна шабля не застаріває).
## Трофеї (player.resources["trophy"]) падають з еліт, босів і за виграні облоги.

const Data := preload("res://scripts/data/data.gd")
const CampService := preload("res://scripts/game/camp_service.gd")

const TIER_NAMES := ["Звичайна", "Добротна", "Рідкісна", "Легендарна"]
const TIER_KUZNIA := [1, 1, 2, 3]  # потрібний рівень кузні для якості
const TIER_MULT := [0.6, 1.0, 2.5, 6.0]
const TIER_TROPHY := [0, 0, 2, 6]
## Що кувати: [слот, тип зброї]
const RECIPES := [["weapon", "sabre"], ["weapon", "mace"], ["weapon", "pike"], ["head", ""], ["body", ""], ["belt", ""], ["boots", ""], ["amulet", ""]]


static func recipe_name(slot: String, type: String) -> String:
	return Data.WEAPON_TYPES[type]["name"] if slot == "weapon" else Data.SLOT_NAMES[slot]


## Ціна кування: {"gold", "iron", "wood", "herbs", "trophy"}.
static func forge_cost(slot: String, tier: int, lvl: int) -> Dictionary:
	var m: float = TIER_MULT[tier]
	var cost := {"gold": int((30 + 15 * lvl) * m), "iron": int((4 + lvl / 2) * m), "wood": 0, "herbs": 0, "trophy": TIER_TROPHY[tier]}
	if slot == "amulet":
		cost["herbs"] = int((3 + lvl / 3) * m)
	else:
		cost["wood"] = int((2 + lvl / 3) * m)
	return cost


static func can_pay(player, cost: Dictionary) -> bool:
	if player.gold < int(cost.get("gold", 0)):
		return false
	for r in ["iron", "wood", "herbs", "trophy"]:
		if int(player.resources.get(r, 0)) < int(cost.get(r, 0)):
			return false
	return true


static func _pay(player, cost: Dictionary) -> void:
	player.gold -= int(cost.get("gold", 0))
	for r in ["iron", "wood", "herbs", "trophy"]:
		player.resources[r] = int(player.resources.get(r, 0)) - int(cost.get(r, 0))


static func tier_open(world, tier: int) -> bool:
	return CampService.level(world, "kuznia") >= TIER_KUZNIA[tier]


## Викувати річ. Повертає її або {} (не вистачає / кузня мала / торба повна).
static func forge(world, player, slot: String, type: String, tier: int) -> Dictionary:
	if not tier_open(world, tier) or player.inventory.size() >= player.bag_size():
		return {}
	var cost := forge_cost(slot, tier, player.level)
	if not can_pay(player, cost):
		return {}
	_pay(player, cost)
	var it := Data.gen_item(player.level, tier, slot, type)
	player.add_item(it)
	return it


# ---------- Перекування властивості ----------

static func reforge_cost(item: Dictionary) -> Dictionary:
	return {"gold": 20 + 8 * int(item["ilvl"]) * (1 + int(item["rarity"])), "herbs": 3, "trophy": 1}


static func can_reforge(world, item: Dictionary) -> bool:
	return CampService.level(world, "kuznia") >= 2 and not item["affixes"].is_empty()


## Нова властивість замість обраної (із тих, яких у речі ще немає). Повертає id нової або "".
static func reforge(world, player, uid: int, affix: String) -> String:
	var it: Dictionary = player.find_item(uid)
	if it.is_empty() or not can_reforge(world, it) or not it["affixes"].has(affix):
		return ""
	var cost := reforge_cost(it)
	if not can_pay(player, cost):
		return ""
	var pool: Array = Data.AFFIX_POOL.duplicate()
	pool.erase(Data.SLOT_PRIMARY[it["slot"]])
	for a in it["affixes"]:
		pool.erase(a)
	if pool.is_empty():
		return ""
	_pay(player, cost)
	var fresh: String = pool[randi() % pool.size()]
	it["affixes"].erase(affix)
	it["affixes"][fresh] = Data._roll_value(fresh, int(it["ilvl"]), int(it["rarity"]))
	player.recalc()
	return fresh


# ---------- Оновлення до свого рівня ----------

static func renew_cost(item: Dictionary, lvl: int) -> Dictionary:
	var gap := maxi(1, lvl - int(item["ilvl"]))
	return {"gold": (25 + 10 * lvl) * gap / 2 + 50, "iron": 3 + gap * 2, "trophy": 2 + int(item["rarity"])}


static func can_renew(world, item: Dictionary, lvl: int) -> bool:
	return CampService.level(world, "kuznia") >= 3 and int(item["ilvl"]) < lvl


## Ті самі властивості, але сила — як у речі рівня козака. Заточка зберігається.
static func renew(world, player, uid: int) -> bool:
	var it: Dictionary = player.find_item(uid)
	if it.is_empty() or not can_renew(world, it, player.level):
		return false
	var cost := renew_cost(it, player.level)
	if not can_pay(player, cost):
		return false
	_pay(player, cost)
	if it.has("unique"):
		# золота річ не перекидає властивості: вони сталі, росте лише сила
		load("res://scripts/data/uniques.gd").rescale(it, player.level)
		player.recalc()
		return true
	it["ilvl"] = player.level
	var primary: String = Data.SLOT_PRIMARY[it["slot"]]
	it["base"] = {primary: Data._primary_value(it["slot"], player.level, int(it["rarity"]))}
	for a in it["affixes"].keys():
		it["affixes"][a] = Data._roll_value(a, player.level, int(it["rarity"]))
	player.recalc()
	return true
