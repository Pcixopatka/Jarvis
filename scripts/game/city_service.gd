extends RefCounted
## Логіка міста без інтерфейсу: крамниця, ціни, найм, заточка, здача завдань.
## Чисті функції над станом світу й героя — їх легко тестувати і в майбутньому перенести на сервер.

const Data := preload("res://scripts/data/data.gd")
const Party := preload("res://scripts/game/party.gd")
const CampService := preload("res://scripts/game/camp_service.gd")

const SHOP_SIZE := 6
const BUY_MARKUP := 4.0


static func shop_stock(world, player: Player, city: String) -> Array:
	if not world.shops.has(city) or world.shop_dirty.get(city, true):
		var C: Dictionary = Data.CITIES[city]
		var loyal: int = world.loyalty_level(city)
		var ilvl: int = maxi(C["level"], player.level - 1) + loyal
		var stock := []
		for i in SHOP_SIZE:
			stock.append(player.assign_uid(Data.gen_item(ilvl, Data.roll_rarity(C["level"] + loyal * 3))))
		world.shops[city] = stock
		world.shop_dirty[city] = false
	return world.shops[city]


static func buy_price(world, city: String, item: Dictionary) -> int:
	return int(Data.sell_price(item) * BUY_MARKUP * (1.0 - world.discount(city)))


static func hire_price(world, player: Player, city: String, type: String) -> int:
	return int(Data.COMPANIONS[type]["cost"] * (1.0 - world.discount(city)) * (1.0 + 0.3 * (player.level - 1)))


static func can_hire(world, player: Player, city: String, type: String) -> bool:
	var info: Dictionary = Data.COMPANIONS[type]
	return world.loyalty_level(city) >= info["loyalty"] \
		and player.gold >= hire_price(world, player, city, type) \
		and world.companions.size() < party_size(world) \
		and not world.has_companion(type)


static func party_size(world) -> int:
	return CampService.party_size(world)


static func buy(world, player: Player, city: String, uid: int) -> bool:
	var stock := shop_stock(world, player, city)
	for i in stock.size():
		var it: Dictionary = stock[i]
		if it["uid"] == uid:
			var price := buy_price(world, city, it)
			if player.gold >= price and player.add_item(it):
				player.gold -= price
				stock.remove_at(i)
				return true
			return false
	return false


static func sell(player: Player, uid: int) -> int:
	var it: Dictionary = player.remove_from_bag(uid)
	if it.is_empty():
		return 0
	var g := Data.sell_price(it)
	player.gold += g
	return g


static func sell_junk(player: Player) -> int:
	var total := 0
	for it in player.inventory.duplicate():
		if it["rarity"] == 0:
			total += sell(player, it["uid"])
	return total


static func hire(world, player: Player, city: String, type: String) -> bool:
	if not can_hire(world, player, city, type):
		return false
	player.gold -= hire_price(world, player, city, type)
	world.companions.append(Party.new_member(type, player.level))
	return true


static func potion_price(world, player: Player, city: String) -> int:
	return int(Data.potion_price(player.level) * (1.0 - world.discount(city)))


static func buy_potion(world, player: Player, city: String) -> bool:
	var price := potion_price(world, player, city)
	if player.gold < price or player.potions >= player.potion_max():
		return false
	player.gold -= price
	player.potions += 1
	return true


static func dismiss(world, index: int) -> void:
	if index >= 0 and index < world.companions.size():
		world.companions.remove_at(index)


## Здає завдання; повертає {"quest", "loyalty_up"} або порожній словник.
static func turn_in(world, player: Player, qid: int) -> Dictionary:
	var q: Dictionary = world.turn_in(qid)
	if q.is_empty():
		return {}
	player.gold += q["gold"]
	player.add_xp(q["xp"])
	var up: bool = world.add_loyalty(q["city"], q["loyalty"])
	return {"quest": q, "loyalty_up": up}
