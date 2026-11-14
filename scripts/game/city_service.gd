extends RefCounted
## Логіка міста без інтерфейсу: крамниця, ціни, найм, заточка, здача завдань.
## Чисті функції над станом світу й героя — їх легко тестувати і в майбутньому перенести на сервер.

const Data := preload("res://scripts/data/data.gd")
const Party := preload("res://scripts/game/party.gd")
const CampService := preload("res://scripts/game/camp_service.gd")
const GameDB := preload("res://scripts/core/game_db.gd")

static var SHOP_SIZE: int  # речей у крамниці міста
static var BUY_MARKUP: float  # крамниця продає річ у стільки разів дорожче за її ціну


## Числа-правила вище лежать у data/settings.json (запис «city»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("city")
	SHOP_SIZE = S["shop_size"]
	BUY_MARKUP = S["buy_markup"]


## Товар крамниці міста. Речі — рівня героя, хоч би якого рівня було місто (місто відкрите завжди, тож і крам
## там для того, хто прийшов); рідкість — за рівнем героя й лояльністю міста (кожен рівень лояльності — як три
## рівні героя). Ярмарок додає дві рідкісні речі на рівень вище. Товар оновлюється, коли стоїть позначка
## shop_dirty: Game.enter_location ставить її всім містам щоразу, як герой іде в бій.
static func shop_stock(world, player: Player, city: String) -> Array:
	if not world.shops.has(city) or world.shop_dirty.get(city, true):
		var loyal: int = world.loyalty_level(city)
		var ilvl: int = maxi(1, int(player.level))
		var stock := []
		for i in SHOP_SIZE:
			stock.append(player.assign_uid(Data.gen_item(ilvl, Data.roll_rarity(ilvl + loyal * 3))))
		if load("res://scripts/game/event_service.gd").fair_city(world) == city:
			for i in 2:  # ярмарок: купці привезли рідкісне
				stock.append(player.assign_uid(Data.gen_item(ilvl + 1, 2)))
		world.shops[city] = stock
		world.shop_dirty[city] = false
	return world.shops[city]


static func buy_price(world, city: String, item: Dictionary) -> int:
	# від ціни без надбавки ярмарку: ярмарок піднімає те, за скільки купують у героя, а не ціни крамниці
	return int(Data.base_price(item) * BUY_MARKUP * (1.0 - world.discount(city)))


static func hire_price(world, player: Player, city: String, type: String) -> int:
	if load("res://scripts/game/event_service.gd").free_hire(world):
		return 0  # звільнений бранець чи побратим пораненого — задарма
	var feast: float = 1.0 - load("res://scripts/game/holiday_service.gd").bonus("hire")  # у День Державності до війська пристають охочіше
	return int(GameDB.companion(type)["hire"]["cost"] * (1.0 - world.discount(city)) * (1.0 + 0.3 * (player.level - 1)) * feast)


static func can_hire(world, player: Player, city: String, type: String) -> bool:
	var info: Dictionary = GameDB.companion(type)
	return world.loyalty_level(city) >= info["hire"]["loyalty"] \
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
	player.SoulService.strip(player, it)  # душа з проданої речі вертається в торбинку
	var g := Data.sell_price(it)
	player.gold += g
	return g


static func sell_junk(player: Player) -> int:
	var total := 0
	for it in player.inventory.duplicate():
		if it["rarity"] == 0 and not it.has("unique"):
			total += sell(player, it["uid"])
	return total


## Чи річ із торби краща за вдягнену в той самий слот (таку масовий продаж не чіпає).
## Для порожнього слота кращою вважається лише одна найцінніша річ торби.
static func is_upgrade(player: Player, it: Dictionary) -> bool:
	if it["slot"] == "weapon" and not player.can_use(it):
		return false
	var worn: Dictionary = player.equipment.get(it["slot"], {})
	var price := Data.sell_price(it)
	if not worn.is_empty():
		return price > Data.sell_price(worn)
	for other in player.inventory:
		if other["slot"] == it["slot"] and int(other["uid"]) != int(it["uid"]):
			var op := Data.sell_price(other)
			if op > price or (op == price and int(other["uid"]) < int(it["uid"])):
				return false
	return true


## Що продалося б «до рідкості включно»: вдягнене не чіпається, речі, кращі за вдягнені, — теж.
static func bulk_candidates(player: Player, max_rarity: int) -> Array:
	var out := []
	for it in player.inventory:
		if int(it["rarity"]) <= max_rarity and not it.has("unique") and not it.has("artifact") and not it.has("set") and str(it.get("soul", "")) == "" and not is_upgrade(player, it):
			out.append(it)
	return out


static func sell_up_to(player: Player, max_rarity: int) -> int:
	var total := 0
	for it in bulk_candidates(player, max_rarity):
		total += sell(player, it["uid"])
	return total


## Продати обрані речі (за uid). Повертає виторг.
static func sell_many(player: Player, uids: Array) -> int:
	var total := 0
	for uid in uids:
		if not player.is_equipped(uid):
			total += sell(player, uid)
	return total


static func hire(world, player: Player, city: String, type: String) -> bool:
	if not can_hire(world, player, city, type):
		return false
	var price := hire_price(world, player, city, type)
	player.gold -= price
	if price == 0:
		load("res://scripts/game/event_service.gd").use_free_hire(world)
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


static func mana_potion_price(world, player: Player, city: String) -> int:
	return int(Data.mana_potion_price(player.level) * (1.0 - world.discount(city)))


static func buy_mana_potion(world, player: Player, city: String) -> bool:
	var price := mana_potion_price(world, player, city)
	if player.gold < price or player.mana_potions >= player.mana_potion_max():
		return false
	player.gold -= price
	player.mana_potions += 1
	return true


static func dismiss(world, index: int) -> void:
	if index >= 0 and index < world.companions.size():
		world.companions.remove_at(index)


## Здає завдання; повертає {"quest", "loyalty_up", "xp": скільки досвіду дістав рівень чи звитяга} або порожній словник.
## Досвід — частка смуги нинішнього рівня (WorldState.quest_xp_share, Player.add_mission_xp), без надбавок.
static func turn_in(world, player: Player, qid: int) -> Dictionary:
	var q: Dictionary = world.turn_in(qid)
	if q.is_empty():
		return {}
	player.gold += q["gold"]
	var got: int = player.add_mission_xp(world.quest_xp_share(q))
	var up: bool = world.add_loyalty(q["city"], q["loyalty"])
	return {"quest": q, "loyalty_up": up, "xp": got}
