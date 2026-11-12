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
	return Data.weapon_name(type) if slot == "weapon" else Data.slot_name(slot)


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


## Перековуються всі речі з властивостями, золоті й наборні теж. Наборна лишається в наборі,
## а золота при оновленні зберігає перекований бонус (див. Uniques.rescale).
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
	var pool: Array = Data.affix_pool().duplicate()
	pool.erase(Data.slot_primary(it["slot"]))
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

## Кожен рівень речі коштує окремо й щораз дорожче: гривні ростуть як квадрат рівня, від першого ж рівня.
## Так підняти річ із 98-го на 99-й рівень відчутно б'є по кишені, а з 4-го на 5-й ще ні.
## RENEW_RARITY — множник за якість: звичайна, добротна, рідкісна, легендарна, золота.
const RENEW_BASE := 20
const RENEW_GOLD := 4.0
const RENEW_RARITY := [0.4, 0.6, 0.8, 1.0, 1.5]


## Ціна підняти річ на один рівень, до рівня level з попереднього.
static func renew_step(item: Dictionary, level: int) -> Dictionary:
	var r: int = clampi(int(item["rarity"]), 0, RENEW_RARITY.size() - 1)
	return {"gold": roundi((RENEW_BASE + RENEW_GOLD * level * level) * float(RENEW_RARITY[r])),
		"iron": 2 + level / 5, "trophy": 1 + level / 40 + r / 3}


## Ціна підняти річ до рівня lvl: сума за кожен рівень від її нинішнього.
static func renew_cost(item: Dictionary, lvl: int) -> Dictionary:
	var out := {"gold": 0, "iron": 0, "trophy": 0}
	for level in range(int(item["ilvl"]) + 1, maxi(lvl, int(item["ilvl"]) + 1) + 1):
		var st := renew_step(item, level)
		for k in out:
			out[k] += int(st[k])
	return out


static func can_renew(world, item: Dictionary, lvl: int) -> bool:
	return CampService.level(world, "kuznia") >= 3 and int(item["ilvl"]) < lvl and not item.has("artifact")


## Ті самі властивості, але сила — як у речі вищого рівня. Заточка зберігається.
## levels — на скільки рівнів підняти (0 — одразу до рівня козака).
static func renew(world, player, uid: int, levels: int = 0) -> bool:
	var it: Dictionary = player.find_item(uid)
	if it.is_empty() or not can_renew(world, it, player.level):
		return false
	var target: int = int(player.level) if levels <= 0 else mini(int(player.level), int(it["ilvl"]) + levels)
	var cost := renew_cost(it, target)
	if not can_pay(player, cost):
		return false
	_pay(player, cost)
	it["spent"] = int(it.get("spent", 0)) + int(cost["gold"])
	if it.has("unique"):
		# золота річ: властивості з опису дістають силу нового рівня, перекована не зникає
		load("res://scripts/data/uniques.gd").rescale(it, target)
		player.recalc()
		return true
	it["ilvl"] = target
	var primary: String = Data.slot_primary(it["slot"])
	it["base"] = {primary: Data._primary_value(it["slot"], target, int(it["rarity"]))}
	for a in it["affixes"].keys():
		# властивість кидається наново, та нижчою за нинішню не стає: оновлення річ не псує
		# досвід і гривні не вище стелі, навіть якщо нинішнє значення чомусь було більшим
		it["affixes"][a] = Data.cap_affix(a, maxf(float(it["affixes"][a]), Data._roll_value(a, target, int(it["rarity"]))))
	player.recalc()
	return true
