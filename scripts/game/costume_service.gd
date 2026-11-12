extends RefCounted
## Вбрання героя: купівля за червінці й вдягання. Куплене лежить у роду (world.shop["costumes"]),
## вдягнене записане в героя (player.costume). На силу героя вбрання не впливає.

const Costumes := preload("res://scripts/data/costumes.gd")
const Shop := preload("res://scripts/data/shop.gd")


static func owned(world, id: String) -> bool:
	return bool(world.shop.get("costumes", {}).get(id, false))


static func owned_count(world) -> int:
	return int(world.shop.get("costumes", {}).size())


static func price(id: String) -> int:
	return Costumes.price(id)


## Чому не можна купити ("" — можна).
static func block_reason(world, id: String) -> String:
	if not Costumes.has(id):
		return "такого вбрання нема"
	if owned(world, id):
		return "уже куплено"
	var coins: int = int(world.shop.get("coins", 0))
	if coins < price(id):
		return "бракує %d %s" % [price(id) - coins, Shop.COIN_SHORT]
	return ""


## Купити вбрання для всього роду. Герой, що купив, одразу його вдягає.
static func buy(world, player, id: String) -> bool:
	if block_reason(world, id) != "":
		return false
	var s: Dictionary = world.shop
	s["coins"] = int(s.get("coins", 0)) - price(id)
	s["spent"] = int(s.get("spent", 0)) + price(id)
	if not s.has("costumes"):
		s["costumes"] = {}
	s["costumes"][id] = true
	player.costume = id
	return true


## Вдягнути куплене вбрання або зняти його (id == "").
static func wear(world, player, id: String) -> bool:
	if id != "" and not owned(world, id):
		return false
	player.costume = id
	return true


## Вбрання, якого в роду вже нема (чуже збереження), знімається.
static func check(world, player) -> void:
	if str(player.costume) != "" and not owned(world, str(player.costume)):
		player.costume = ""
