extends RefCounted
## Чумацький шлях: купи крам дешево в одному місті, довези возом і продай дорого в іншому.
## Ціни залежать від міста (де що роблять), торгового дня (кожні TRADE_PERIOD походів трохи інші)
## й твоїх власних угод (продаєш багато — ціна падає). Дорогою до міста на валку можуть напасти.
## Стан — world.trade:
##   {"cargo": {крам: {"n": одиниць, "spent": заплачено}}, "age": походів, "moves": {місто: {крам: продано − куплено}},
##    "profit": зиск за весь час, "sold": проданих одиниць}

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const CampService := preload("res://scripts/game/camp_service.gd")


static func state(world) -> Dictionary:
	var s: Dictionary = world.trade
	if s.is_empty():
		s["cargo"] = {}
		s["age"] = 0
		s["moves"] = {}
		s["profit"] = 0
		s["sold"] = 0
	return s


static func has_market(city: String) -> bool:
	return Acts.TRADE_CITIES.has(city)


static func period(world) -> int:
	return int(state(world)["age"]) / Acts.TRADE_PERIOD


## Похід скінчився: настає (чи ні) новий торговий день — ціни й запаси оновлюються.
static func tick(world) -> void:
	var s := state(world)
	var before := period(world)
	s["age"] = int(s["age"]) + 1
	if period(world) != before:
		s["moves"] = {}


# ---------- Віз ----------

static func capacity(world) -> int:
	return Acts.TRADE_CART + Acts.TRADE_CART_SKLAD * CampService.level(world, "sklad")


static func cargo_n(world, good: String) -> int:
	return int(state(world)["cargo"].get(good, {}).get("n", 0))


static func cargo_count(world) -> int:
	var n := 0
	for g in state(world)["cargo"]:
		n += int(state(world)["cargo"][g]["n"])
	return n


static func free_space(world) -> int:
	return capacity(world) - cargo_count(world)


## Середня ціна, за яку куплено цей крам на возі (0 — нема).
static func avg_cost(world, good: String) -> float:
	var c: Dictionary = state(world)["cargo"].get(good, {})
	if int(c.get("n", 0)) <= 0:
		return 0.0
	return float(c["spent"]) / float(c["n"])


# ---------- Ціни ----------

static func wealth(level: int) -> float:
	return 1.0 + Acts.TRADE_WEALTH * (level - 1)


## Коливання торгового дня: 0.88…1.12, однакове для всіх у цьому місті цього дня.
static func fluct(world, city: String, good: String) -> float:
	var h: int = hash("%d|%s|%s" % [period(world), city, good])
	return 0.88 + 0.24 * float(absi(h) % 1000) / 999.0


static func _net(world, city: String, good: String) -> int:
	return int(state(world)["moves"].get(city, {}).get(good, 0))


## Ціна купівлі одиниці краму в місті зараз.
static func price(world, city: String, good: String, level: int) -> int:
	var base: float = float(Acts.TRADE_GOODS[good]["base"]) * wealth(level) * float(Acts.TRADE_CITIES[city][good]) * fluct(world, city, good)
	var move := clampf(1.0 - Acts.TRADE_STEP * _net(world, city, good), 0.55, 1.6)
	return maxi(1, roundi(base * move))


## За скільки місто купить у тебе одиницю краму (на ярмарку — на чверть дорожче).
static func sell_price(world, city: String, good: String, level: int) -> int:
	var fair: float = 1.25 if str(world.events.get("fair", {}).get("city", "")) == city else 1.0
	return maxi(1, int(price(world, city, good, level) * Acts.TRADE_SPREAD * fair * tip_bonus(world, city, good)))


## Чутка з шинку: поки вона свіжа, названий крам у названому місті беруть дорожче.
static func tip_bonus(world, city: String, good: String) -> float:
	var t: Dictionary = world.tavern.get("tip", {})
	if not t.is_empty() and t.get("city", "") == city and t.get("good", "") == good:
		return Acts.RUMOR_TIP_BONUS
	return 1.0


## Скільки одиниць краму місто ще продасть цього торгового дня.
static func stock_left(world, city: String, good: String) -> int:
	var bought := int(state(world)["moves"].get(city, {}).get("bought:" + good, 0))
	return maxi(0, Acts.TRADE_STOCK - bought)


## «cheap» — тут цей крам роблять, «dear» — тут він у ціні, "" — звичайна ціна.
static func tag(city: String, good: String) -> String:
	var m: float = Acts.TRADE_CITIES[city][good]
	if m <= 0.8:
		return "cheap"
	return "dear" if m >= 1.4 else ""


## Де цей крам найдорожчий (за сталими цінами міст).
static func best_city(good: String, exclude: String = "") -> String:
	var best := ""
	var best_m := 0.0
	for c in Acts.TRADE_CITIES:
		if c != exclude and float(Acts.TRADE_CITIES[c][good]) > best_m:
			best_m = Acts.TRADE_CITIES[c][good]
			best = c
	return best


# ---------- Угоди ----------

static func _move(world, city: String, key: String, delta: int) -> void:
	var m: Dictionary = state(world)["moves"]
	if not m.has(city):
		m[city] = {}
	m[city][key] = int(m[city].get(key, 0)) + delta


static func can_buy(world, player, city: String, good: String) -> bool:
	return has_market(city) and free_space(world) > 0 and stock_left(world, city, good) > 0 and player.gold >= price(world, city, good, player.level)


## Купити до n одиниць (кожна наступна трохи дорожча). Повертає, скільки куплено.
static func buy(world, player, city: String, good: String, n: int = 1) -> int:
	var got := 0
	var cargo: Dictionary = state(world)["cargo"]
	for i in n:
		if not can_buy(world, player, city, good):
			break
		var p := price(world, city, good, player.level)
		player.gold -= p
		if not cargo.has(good):
			cargo[good] = {"n": 0, "spent": 0}
		cargo[good]["n"] = int(cargo[good]["n"]) + 1
		cargo[good]["spent"] = int(cargo[good]["spent"]) + p
		_move(world, city, good, -1)
		_move(world, city, "bought:" + good, 1)
		got += 1
	return got


## Продати до n одиниць (кожна наступна трохи дешевша). Повертає {"n", "gold", "profit"}.
static func sell(world, player, city: String, good: String, n: int = 1) -> Dictionary:
	var out := {"n": 0, "gold": 0, "profit": 0}
	if not has_market(city):
		return out
	var s := state(world)
	var cargo: Dictionary = s["cargo"]
	for i in n:
		if cargo_n(world, good) <= 0:
			break
		var p := sell_price(world, city, good, player.level)
		var cost := avg_cost(world, good)
		player.gold += p
		cargo[good]["n"] = int(cargo[good]["n"]) - 1
		cargo[good]["spent"] = maxi(0, int(cargo[good]["spent"]) - roundi(cost))
		if int(cargo[good]["n"]) <= 0:
			cargo.erase(good)
		_move(world, city, good, 1)
		out["n"] = int(out["n"]) + 1
		out["gold"] = int(out["gold"]) + p
		out["profit"] = int(out["profit"]) + p - roundi(cost)
	s["sold"] = int(s["sold"]) + int(out["n"])
	s["profit"] = int(s["profit"]) + int(out["profit"])
	return out


# ---------- Напад на валку ----------

static func ambush_chance(world) -> float:
	var n := cargo_count(world)
	if n <= 0:
		return 0.0
	return minf(Acts.TRADE_AMBUSH_MAX, Acts.TRADE_AMBUSH + Acts.TRADE_AMBUSH_UNIT * n)


## Чи нападуть на валку дорогою до цього міста (кидок; roll — для тестів).
static func should_ambush(world, roll: float = -1.0) -> bool:
	var r := roll if roll >= 0.0 else randf()
	return r < ambush_chance(world)


## Бій біля возів дорогою до міста (як оборона: відбий хвилі, вбережи вози).
static func battle_loc(world, city: String, player) -> Dictionary:
	var lvl := maxi(int(Data.CITIES[city]["level"]), player.level - 1)
	var enemies := ["zarazhenyi", "zarazhenyi", "upyr", "vovkulaka"]
	if lvl >= 8:
		enemies = ["zarazhenyi", "pishchalnyk", "vovkulaka", "upyr"]
	if lvl >= 13:
		enemies = ["zarazhenyi", "pishchalnyk", "chort", "vovkulaka"]
	return {"name": "Напад на валку", "type": "defense", "biome": "steppe", "level": lvl, "enemies": enemies, "waves": 3,
		"target": city, "camp": false, "variant": "caravan", "ambush": true, "gate_hp": 400.0 + 80.0 * lvl, "desc": ""}


## Вози розбито: половина краму пропала. Повертає повідомлення.
static func lose_half(world) -> String:
	var cargo: Dictionary = state(world)["cargo"]
	var lost := 0
	for g in cargo.keys():
		var n := int(cargo[g]["n"])
		var gone := int(ceil(n / 2.0))
		var cost := avg_cost(world, g)
		cargo[g]["n"] = n - gone
		cargo[g]["spent"] = maxi(0, int(cargo[g]["spent"]) - roundi(cost * gone))
		if int(cargo[g]["n"]) <= 0:
			cargo.erase(g)
		lost += gone
	return "Вози розбито: нечисть розтягла половину краму (%d од.)." % lost
