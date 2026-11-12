extends RefCounted
## Крамниця за донат: баланс червінців, каталог усього рідкісного й покупка (ціни — у Shop).
## Стан спільний для роду й лежить в акаунті (world.shop):
##   {"coins": залишок, "paid": скільки червінців куплено за гроші, "spent": скільки витрачено,
##    "packs": {товар: скільки разів куплено}, "bought": {"вид:id": скільки разів}}
## Куплена річ має рівень героя, що її купує, і лягає йому в торбу навіть понад місце; душа летить у торбинку.

const Data := preload("res://scripts/data/data.gd")
const Shop := preload("res://scripts/data/shop.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")
const Sets := preload("res://scripts/data/sets.gd")
const Souls := preload("res://scripts/data/souls.gd")
const Classes := preload("res://scripts/data/classes.gd")
const SoulService := preload("res://scripts/game/soul_service.gd")
const PerilService := preload("res://scripts/game/peril_service.gd")

## Чи продаються червінці зараз. Типове значення в Shop.COINS_ON_SALE; тести можуть перемкнути.
static var coins_on_sale: bool = Shop.COINS_ON_SALE
const OFF_TEXT := "Зараз не продається"


static func state(world) -> Dictionary:
	var s: Dictionary = world.shop
	for k in ["coins", "paid", "spent"]:
		if not s.has(k):
			s[k] = 0
	for k in ["packs", "bought"]:
		if not s.has(k):
			s[k] = {}
	return s


static func coins(world) -> int:
	return int(state(world)["coins"])


# ======================= Червінці =======================

static func pack(id: String) -> Dictionary:
	for p in Shop.PACKS:
		if str(p["id"]) == id:
			return p
	return {}


## Чому набір зараз не купити (порожньо: можна).
static func pack_block_reason(id: String) -> String:
	if not coins_on_sale:
		return OFF_TEXT
	if pack(id).is_empty():
		return "Такого набору нема"
	return ""


## Оплату набору підтверджено: зарахувати червінці. Повертає, скільки зараховано
## (0, коли такого набору нема або купівлю червінців вимкнено).
static func grant_pack(world, id: String) -> int:
	var p := pack(id)
	if p.is_empty() or not coins_on_sale:
		return 0
	var s := state(world)
	var n: int = int(p["coins"])
	s["coins"] = int(s["coins"]) + n
	s["paid"] = int(s["paid"]) + n
	s["packs"][id] = int(s["packs"].get(id, 0)) + 1
	return n


# ======================= Каталог =======================

static func key(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]


static func _peril_bosses() -> Array:
	var out := []
	for loc in PerilService.ids():
		out.append(str(Data.LOCATIONS[loc]["boss"]))
	return out


## Ціна товару в червінцях (0 — такого товару нема).
static func price(kind: String, id: String) -> int:
	match kind:
		"soul":
			if not Souls.SOULS.has(id):
				return 0
			return int(Shop.SOUL_PRICE[clampi(int(Souls.SOULS[id]["tier"]), 1, Shop.SOUL_PRICE.size() - 1)])
		"unique":
			if not Uniques.DEFS.has(id):
				return 0
			return int(Shop.UNIQUE_PRICE[clampi(int(Uniques.DEFS[id]["tier"]), 1, Shop.UNIQUE_PRICE.size() - 1)])
		"artifact":
			if not Artifacts.DEFS.has(id):
				return 0
			return Shop.ARTIFACT_PERIL_PRICE if str(Artifacts.DEFS[id]["boss"]) in _peril_bosses() else Shop.ARTIFACT_PRICE
		"set":
			var parts := id.split(":")
			if parts.size() != 2 or not Sets.SETS.has(parts[0]) or not parts[1] in Data.SLOTS:
				return 0
			return Shop.SET_PIECE_PRICE
		"set_full":
			return Shop.SET_FULL_PRICE if Sets.SETS.has(id) else 0
	return 0


## Усі товари одного виду за порядком показу: ["id", ...].
static func ids(kind: String) -> Array:
	match kind:
		"soul":
			return SoulService.known()
		"unique":
			return Uniques.ORDER.duplicate()
		"artifact":
			return Artifacts.ORDER.duplicate()
		"set":
			var out := []
			for sid in Sets.ORDER:
				for slot in Data.SLOTS:
					out.append("%s:%s" % [sid, slot])
			return out
		"set_full":
			return Sets.ORDER.duplicate()
	return []


## Скільки разів цей товар уже куплено родом.
static func bought(world, kind: String, id: String) -> int:
	return int(state(world)["bought"].get(key(kind, id), 0))


## Зброя набору для цього героя: та, що в руках, якщо вона до класу, інакше перша з дозволених.
static func set_weapon(player) -> String:
	var weapons: Array = Classes.CLASSES[player.job].get("weapons", ["sabre"])
	return str(player.weapon_type) if str(player.weapon_type) in weapons else str(weapons[0])


## Чи річ до руки цьому героєві (чужу зброю купити можна, але вдягти її зможе інший герой).
static func fits(player, kind: String, id: String) -> bool:
	if kind == "unique" and str(Uniques.DEFS[id]["slot"]) == "weapon":
		return str(Uniques.DEFS[id]["type"]) in Classes.CLASSES[player.job].get("weapons", [])
	return true


## Чому зараз не можна купити ("" — можна).
static func block_reason(world, player, kind: String, id: String) -> String:
	var cost := price(kind, id)
	if cost <= 0:
		return "Такого товару нема"
	if kind == "artifact" and Artifacts.has(player.inventory, id):
		return "Уже лежить у торбі: другий такий самий не діє"
	if coins(world) < cost:
		return "Бракує червінців: %d" % (cost - coins(world))
	return ""


## Рівень купленої речі: рівень героя.
static func item_level(player) -> int:
	return maxi(1, int(player.level))


static func _make(player, kind: String, id: String) -> Array:
	var lvl := item_level(player)
	match kind:
		"unique":
			return [Uniques.make(id, lvl)]
		"artifact":
			return [Artifacts.make(id)]
		"set":
			var parts := id.split(":")
			return [Sets.make(parts[0], parts[1], lvl, set_weapon(player) if parts[1] == "weapon" else "")]
		"set_full":
			var out := []
			for slot in Data.SLOTS:
				out.append(Sets.make(id, slot, lvl, set_weapon(player) if slot == "weapon" else ""))
			return out
	return []


## Купити товар за червінці. Повертає {"ok", "msg", "items": [куплені речі]}.
static func buy(world, player, kind: String, id: String) -> Dictionary:
	var why := block_reason(world, player, kind, id)
	if why != "":
		return {"ok": false, "msg": why, "items": []}
	var cost := price(kind, id)
	var s := state(world)
	var items := []
	var what := ""
	if kind == "soul":
		SoulService.grant(player, id)
		what = "%s у торбинці душ" % SoulService.soul_name(id)
	else:
		items = _make(player, kind, id)
		for it in items:
			player.add_item(it, true)  # куплене лягає й понад місце в торбі
		player.recalc()
		what = "%s у торбі" % (str(items[0]["name"]) if items.size() == 1 else "«%s»: шість речей" % str(Sets.SETS[id]["name"]))
	s["coins"] = int(s["coins"]) - cost
	s["spent"] = int(s["spent"]) + cost
	s["bought"][key(kind, id)] = int(s["bought"].get(key(kind, id), 0)) + 1
	return {"ok": true, "msg": "Куплено: %s" % what, "items": items}
