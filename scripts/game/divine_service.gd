extends RefCounted
## Божі дари (див. Divine): купівля за червінці, вдягання у власні гнізда й підрахунок того, що вони дають.
## Куплене лежить у роду (world.shop["divine"]), вдягнене записане в героя (player.divine = {гніздо: id}).
## Що дари дають героєві, лягає в player.divine_fx (CampService.apply_effects), у збереження не йде.

const Divine := preload("res://scripts/data/divine.gd")
const Shop := preload("res://scripts/data/shop.gd")
const SkillInfo := preload("res://scripts/data/skill_info.gd")

# Авто-бафи Німба: бафи з нижньої панелі бою вмикаються самі
const AUTO_STEP := 0.25  # як часто перевіряти (с): чотири рази на секунду, не щокадру
const AUTO_NEAR := 600.0  # нечисть ближча за це (приблизно пів екрана телефона) вважається «поруч»
const AUTO_HEAL_AT := 0.6  # лікувальні вміння вмикаються самі лише нижче цієї частки здоров'я

## Чи продаються дари зараз. Типове значення в Divine.ON_SALE; тести можуть перемкнути.
static var on_sale: bool = Divine.ON_SALE
const OFF_TEXT := "зараз не продається"


static func owned(world, id: String) -> bool:
	return bool(world.shop.get("divine", {}).get(id, false))


## Чи є в роду хоч один дар.
static func owns_any(world) -> bool:
	for id in Divine.ORDER:
		if owned(world, id):
			return true
	return false


## Чи показувати гнізда дарів на екрані героя: коли дари продаються або хоч один уже куплено.
static func shown(world) -> bool:
	return on_sale or owns_any(world)


static func worn(player, slot: String) -> String:
	return str(player.divine.get(slot, ""))


static func wears(player, id: String) -> bool:
	return Divine.has(id) and worn(player, str(Divine.DEFS[id]["slot"])) == id


static func price(id: String) -> int:
	return int(Divine.DEFS[id]["price"]) if Divine.has(id) else 0


## Чому не можна купити ("" — можна).
static func block_reason(world, id: String) -> String:
	if not Divine.has(id):
		return "такого дару нема"
	if owned(world, id):
		return "уже куплено"
	if not on_sale:
		return OFF_TEXT
	var coins: int = int(world.shop.get("coins", 0))
	if coins < price(id):
		return "бракує %d %s" % [price(id) - coins, Shop.COIN_SHORT]
	return ""


## Купити дар для всього роду. Герой, що купив, одразу його вдягає.
static func buy(world, player, id: String) -> bool:
	if block_reason(world, id) != "":
		return false
	var s: Dictionary = world.shop
	s["coins"] = int(s.get("coins", 0)) - price(id)
	s["spent"] = int(s.get("spent", 0)) + price(id)
	if not s.has("divine"):
		s["divine"] = {}
	s["divine"][id] = true
	player.divine[str(Divine.DEFS[id]["slot"])] = id
	apply(world, player)
	return true


## Вдягнути куплений дар у його гніздо.
static func equip(world, player, id: String) -> bool:
	if not owned(world, id):
		return false
	player.divine[str(Divine.DEFS[id]["slot"])] = id
	apply(world, player)
	return true


static func unequip(world, player, slot: String) -> void:
	player.divine.erase(slot)
	apply(world, player)


## Що дають вдягнені дари: {"bag", "stats", "pickup", "shop", "xp", "gold", "revive", "party", "sight", "light", "auto_buffs", "fx": {ключ: значення}}.
static func fx_of(world, player) -> Dictionary:
	var out := {"bag": 0, "stats": 0.0, "pickup": 0.0, "shop": false, "loot": false, "xp": 0.0, "gold": 0.0, "revive": 0.0,
		"party": 0.0, "sight": false, "light": 1.0, "auto_buffs": false, "fx": {}}
	for slot in player.divine.keys():
		var id: String = str(player.divine[slot])
		if not Divine.has(id) or not owned(world, id) or str(Divine.DEFS[id]["slot"]) != str(slot):
			continue
		var D: Dictionary = Divine.DEFS[id]
		out["bag"] = int(out["bag"]) + int(D.get("bag", 0))
		out["stats"] = float(out["stats"]) + float(D.get("stats", 0.0))
		out["pickup"] = float(out["pickup"]) + float(D.get("pickup", 0.0))
		out["shop"] = bool(out["shop"]) or bool(D.get("shop", false))
		out["loot"] = bool(out["loot"]) or bool(D.get("loot", false))
		out["xp"] = float(out["xp"]) + float(D.get("xp", 0.0))
		out["gold"] = float(out["gold"]) + float(D.get("gold", 0.0))
		out["revive"] = maxf(float(out["revive"]), float(D.get("revive", 0.0)))
		out["party"] = float(out["party"]) + float(D.get("party", 0.0))
		out["sight"] = bool(out["sight"]) or bool(D.get("sight", false))
		out["light"] = maxf(float(out["light"]), float(D.get("light", 1.0)))
		out["auto_buffs"] = bool(out["auto_buffs"]) or bool(D.get("auto_buffs", false))
		for k in D.get("fx", {}):
			out["fx"][k] = float(out["fx"].get(k, 0.0)) + float(D["fx"][k])
	return out


## Перерахувати героя: чужі чи некуплені дари знімаються, решта діє.
static func apply(world, player) -> void:
	for slot in player.divine.keys():
		var id: String = str(player.divine[slot])
		if not Divine.has(id) or not owned(world, id) or str(Divine.DEFS[id]["slot"]) != str(slot):
			player.divine.erase(slot)
	player.divine_fx = fx_of(world, player)
	player.bag_divine = int(player.divine_fx["bag"])
	player.recalc()


## Чи може герой торгувати будь-де (вдягнений Хованець).
static func remote_shop(player) -> bool:
	return bool(player.divine_fx.get("shop", false))


## Чи має герой дар авто-бафів (вдягнений Німб), байдуже до перемикача.
static func has_auto_buffs(player) -> bool:
	return bool(player.divine_fx.get("auto_buffs", false))


## Чи діють авто-бафи зараз: дар вдягнено й перемикач героя ввімкнено.
static func auto_buffs_on(player) -> bool:
	return has_auto_buffs(player) and bool(player.auto_buffs)


## Крок авто-бафів у бою. Раз на AUTO_STEP секунд перебирає комірки бафів зліва направо й тисне те,
## що готове й на що вистачає наснаги, коли поруч є жива нечисть. Лікування чекає, поки здоров'я
## впаде нижче AUTO_HEAL_AT. Атаки не чіпає. Наснагу перевіряє сам, тож напис «Бракує наснаги» не спливає.
static func auto_buff_tick(player, combat, delta: float) -> void:
	player.auto_buff_t -= delta
	if player.auto_buff_t > 0.0:
		return
	player.auto_buff_t = AUTO_STEP
	if not auto_buffs_on(player) or not player.alive or player.petrified > 0.0 or combat == null or not combat.active:
		return
	if combat.nearest_enemy(player.global_position, AUTO_NEAR) == null:
		return
	player.sync_panel()
	for id in player.panel["buff"]:
		if id == "" or player.sk(id) <= 0 or float(player.skill_timers.get(id, 0.0)) > 0.0 or player.mana < player.skill_cost(id):
			continue
		if SkillInfo.heals(id) and player.hp >= player.max_hp * AUTO_HEAL_AT:
			continue
		player.use_skill(id)
