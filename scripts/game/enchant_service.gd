extends RefCounted
## Зачарування речей (див. Enchants): чи можна, скільки коштує, накласти й порахувати для героя.
## Зачарування лежить у самій речі: item["ench"] = id.

const Data := preload("res://scripts/data/data.gd")
const Enchants := preload("res://scripts/data/enchants.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Camp := preload("res://scripts/data/camp_data.gd")


static func can_enchant(item: Dictionary) -> bool:
	return not item.is_empty() and not item.has("artifact") and int(item.get("rarity", 0)) >= Enchants.MIN_RARITY


static func of(item: Dictionary) -> String:
	return str(item.get("ench", ""))


## Напис для картки речі ("" — зачарування нема).
static func text(item: Dictionary) -> String:
	var id := of(item)
	if not Enchants.has(id):
		return ""
	return "%s: %s" % [Enchants.def(id)["name"], Classes.fx_text(Enchants.fx_of(item, id))]


static func can_pay(player, cost: Dictionary) -> bool:
	if int(player.gold) < int(cost["gold"]):
		return false
	for r in cost:
		if r != "gold" and int(player.resources.get(r, 0)) < int(cost[r]):
			return false
	return true


static func cost_text(cost: Dictionary) -> String:
	var parts := ["%d грн" % int(cost["gold"])]
	for r in ["iron", "wood", "herbs", "trophy"]:
		if int(cost.get(r, 0)) > 0:
			parts.append("%s %d" % [Camp.res_name(r), int(cost[r])])
	return ", ".join(parts)


## Чому не можна накласти ("" — можна).
static func block_reason(player, item: Dictionary, id: String) -> String:
	if not can_enchant(item):
		return "зачаровують лише легендарні, золоті й наборні речі"
	if not id in Enchants.options(item):
		return "на цю річ таке не лягає"
	if of(item) == id:
		return "уже лежить на речі"
	if not can_pay(player, Enchants.cost(item)):
		return "бракує гривень чи ресурсів"
	return ""


## Накласти зачарування на річ героя (за uid). Старе зникає.
static func enchant(player, uid: int, id: String) -> bool:
	var item: Dictionary = player.find_item(uid)
	if item.is_empty() or block_reason(player, item, id) != "":
		return false
	var cost := Enchants.cost(item)
	player.gold -= int(cost["gold"])
	for r in cost:
		if r != "gold":
			player.resources[r] = int(player.resources.get(r, 0)) - int(cost[r])
	item["ench"] = id
	player.recalc()
	return true


## Усі зачарування вдягнених речей разом: {ключ: значення}.
static func fx_of_equipment(equipment: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipment:
		var it: Dictionary = equipment[slot]
		var fx := Enchants.fx_of(it, of(it))
		for k in fx:
			out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out
