extends RefCounted
## Унікальні (золоті) речі: іменні, зі сталими властивостями й однією силою.
## Падають лише з босів у їхніх лігвах і з супербосів Башти (див. LootService).
## Що лютіший бос, то вищий ступінь речі; у Глибинах і Башті ступінь росте далі.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const _EMPTY := {}

const RARITY := 4
## Записи — у data/golden.json (речі), data/powers.json (сили) і data/golden_tiers.json (ступені: назва,
## множник головної властивості, шанс із боса, ціни). Тут правила й зручні виклики.
const TOP_COMMON_TIER := 5  # найвищий ступінь поза надважкими печерами: шостий дають лише їхні боси
const LUCK_STEP := 20.0  # кожні 20 босів без золота подвоюють шанс
const LUCK_SURE := 99  # сотий бос поспіль без золота дає річ напевно
const LEVEL_GAP := 8  # бос має бути не нижчий за героя більш як на стільки рівнів
## Власний ступінь боса — boss.tier у data/mobs.json. Нового боса без нього оцінюють за рівнем лігва (див. LootService.boss_tier).

static var _tiers: Array = []  # записи ступенів за номером (0 — порожній)


## Запис золотої речі (golden.json); для невідомого id — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.golden(id)


static func has(id: String) -> bool:
	return GameDB.table("golden").has(id)


## Усі золоті речі в порядку файлу (так їх показують довідник і крамниця).
static func ids() -> Array:
	return GameDB.ids("golden")


## Вид зброї золотої речі ("" — не зброя).
static func type_of(id: String) -> String:
	return str(GameDB.golden(id).get("type", ""))


static func _tier(t: int) -> Dictionary:
	if _tiers.is_empty():
		_tiers = GameDB.ladder("golden_tiers", "tier")
	return _tiers[t] if t >= 0 and t < _tiers.size() else _EMPTY


## Найвищий ступінь (шостий).
static func max_tier() -> int:
	if _tiers.is_empty():
		_tier(0)
	return _tiers.size() - 1


## Назва ступеня: «Сотницька» ("" для 0).
static func tier_name(t: int) -> String:
	return str(_tier(t).get("name", ""))


## Множник головної (дробової) властивості речі цього ступеня.
static func tier_mult(t: int) -> float:
	return float(_tier(t).get("primary_mult", 1.0))


## Шанс золотої речі з боса цього ступеня (до долі й удачі).
static func tier_chance(t: int) -> float:
	return float(_tier(t).get("chance", 0.0))


## Ціна в крамниці за червінці.
static func tier_price(t: int) -> int:
	return int(_tier(t).get("price", 0))


## Ціна на трофейному ярмарку: {"trophy", "gold"} (порожньо — там такого ступеня нема).
static func tier_fair(t: int) -> Dictionary:
	return _tier(t).get("fair", _EMPTY)


static func is_unique(item: Dictionary) -> bool:
	return item.has("unique") and has(str(item["unique"]))


## Значення властивості: стале, без випадковості. Цілі характеристики рівні найкращому кидку легендарної,
## решта — середина кидка з якістю золотої речі (1,6 проти 1,45 у легендарної).
## Досвід і гривні множаться на той самий масштаб, що й у випадкових речей, і не перевищують стелі
## (Data.xp_gold_scale, Data.XP_GOLD_CAP).
static func value(stat: String, ilvl: int, m: float) -> float:
	if Data.is_whole(stat):
		return floorf(m * (2 + ilvl / 3))
	var mid: Array = GameDB.bonus(stat)["mid"]
	var v := 1.6 * (float(mid[0]) + float(mid[1]) * ilvl) * m
	if Data.is_capped(stat):
		v = Data.cap_affix(stat, v * Data.xp_gold_scale(stat))
	return v


## Створює золоту річ за її id для вказаного рівня.
static func make(id: String, ilvl: int) -> Dictionary:
	var D: Dictionary = GameDB.golden(id)
	var slot: String = D["slot"]
	var primary: String = Data.slot_primary(slot)
	var base: float = Data._primary_value(slot, ilvl, RARITY)
	if not Data.is_whole(primary):
		base *= tier_mult(int(D["tier"]))
	var affixes := {}
	for a in D["affixes"]:
		affixes[a] = value(a, ilvl, float(D["affixes"][a]))
	return {"slot": slot, "type": str(D.get("type", "")), "name": D["name"], "rarity": RARITY, "ilvl": ilvl, "up": 0, "spent": 0,
		"unique": id, "base": {primary: base}, "affixes": affixes}


## Перерахувати річ на новий рівень (оновлення в кузні): ті самі властивості, сила нового рівня.
## Набір властивостей лишається нинішнім, тож перекований бонус не зникає. Властивість з опису речі
## дістає Uniques.value нового рівня; перекована росте, як у звичайної речі: більше з нинішнього
## значення й нового кидка, досвід і гривні не вище стелі.
static func rescale(item: Dictionary, ilvl: int) -> void:
	var fresh := make(str(item["unique"]), ilvl)
	item["ilvl"] = ilvl
	item["base"] = fresh["base"]
	var old_affixes = item.get("affixes")
	if typeof(old_affixes) != TYPE_DICTIONARY:
		item["affixes"] = fresh["affixes"]
		return
	var affixes := {}
	for a in old_affixes:
		if fresh["affixes"].has(a):
			affixes[a] = fresh["affixes"][a]
		else:
			affixes[a] = Data.cap_affix(a, maxf(float(old_affixes[a]), Data._roll_value(a, ilvl, int(item.get("rarity", RARITY)))))
	item["affixes"] = affixes


static func tier(item: Dictionary) -> int:
	return int(GameDB.golden(str(item["unique"]))["tier"]) if is_unique(item) else 0


static func power_id(item: Dictionary) -> String:
	return str(GameDB.golden(str(item["unique"]))["power"]) if is_unique(item) else ""


## Параметри сили цієї золотої речі (лише для читання): {параметр: значення}.
static func params(id: String) -> Dictionary:
	return GameDB.golden(id)["params"]


static func power_name(id: String) -> String:
	return str(GameDB.power(str(GameDB.golden(id)["power"]))["name"])


## Опис сили з числами цієї речі. Параметр-частка (pct у powers.json) показується відсотками.
static func power_text(id: String) -> String:
	var D: Dictionary = GameDB.golden(id)
	var P: Dictionary = GameDB.power(str(D["power"]))
	var vals := {}
	for k in D["params"]:
		var v: float = float(D["params"][k])
		if str(P["params"].get(k, "")) == "pct":
			vals[k] = str(roundi(v * 100.0))
		else:
			vals[k] = str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
	return str(P["text"]).format(vals)


## Назви босів, що найчастіше носять цю річ.
static func boss_names(id: String) -> String:
	var out := []
	for b in GameDB.golden(id)["bosses"]:
		out.append(GameDB.boss_name(b, b))
	return ", ".join(out)
