extends RefCounted
## Полювання й рибалка — тихі заняття між походами, і казан на хуторі, де з улову варять страви.
## Полювання: галявиною пробігають звірі, є три стріли — торкнись звіра, щоб вистрілити.
## Рибалка: закинь, дочекайся клювання, підсічи й тягни, тримаючи натяг у зеленій смузі.
## Після кожного заняття звір і риба «відпочивають» до наступного походу.
## Стан — world.outdoors: {"hunt_ready", "fish_ready", "meat", "ryba", "hunts", "trips_fish", "som"}.

const Acts := preload("res://scripts/data/activities.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")


static func state(world) -> Dictionary:
	var s: Dictionary = world.outdoors
	if s.is_empty():
		s["hunt_ready"] = true
		s["fish_ready"] = true
		s["meat"] = 0
		s["ryba"] = 0
		s["hunts"] = 0
		s["fishings"] = 0
		s["som"] = 0
	return s


static func ready(world, kind: String) -> bool:
	return bool(state(world)["hunt_ready" if kind == "hunt" else "fish_ready"])


## Похід скінчився: звір повернувся на галявину, риба знову клює.
static func tick(world) -> void:
	var s := state(world)
	s["hunt_ready"] = true
	s["fish_ready"] = true


static func food(player, id: String) -> int:
	return int(player.resources.get(id, 0))


## Випадковий запис за вагою; boost — множники ваги для окремих записів (0 — не трапляється).
static func _weighted(table: Dictionary, rng: RandomNumberGenerator, boost: Dictionary = {}) -> String:
	var total := 0
	for id in table:
		total += int(table[id]["weight"]) * int(boost.get(id, 1))
	var roll := rng.randi_range(1, total)
	for id in table:
		roll -= int(table[id]["weight"]) * int(boost.get(id, 1))
		if roll <= 0:
			return id
	return table.keys()[0]


## Чутка з шинку: наступне заняття буде багатим (великий звір, більше сомів).
static func rich(world, kind: String) -> bool:
	if load("res://scripts/game/holiday_service.gd").bonus("outdoor") > 0.0:
		return true  # на Петра й Павла кожен день щедрий
	return bool(state(world).get("rich_hunt" if kind == "hunt" else "rich_fish", false))


# ======================= Полювання =======================

static func arrows_for(player) -> int:
	# Пластун і самопальник — природжені мисливці
	return Acts.HUNT_ARROWS + (1 if player.job in ["plastun", "samopalnyk"] else 0)


static func new_hunt(player, seed_value: int = -1, rich_day: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var queue := []
	for i in Acts.HUNT_PASSES:
		queue.append(_weighted(Acts.HUNT_ANIMALS, rng, {"hare": 0} if rich_day else {}))
	return {"arrows": arrows_for(player), "shots": 0, "queue": queue, "index": 0, "meat": 0, "hits": 0, "bull": 0, "wounded": false, "bag": [], "rich": rich_day}


## Який звір зараз на галявині ("" — полювання скінчилось).
static func current(h: Dictionary) -> String:
	if int(h["arrows"]) <= 0 and not h["wounded"]:
		return ""
	if int(h["index"]) >= h["queue"].size():
		return ""
	return h["queue"][int(h["index"])]


static func hunt_over(h: Dictionary) -> bool:
	return int(h["index"]) >= h["queue"].size() or int(h["arrows"]) <= 0


## Постріл: dist — відстань від дотику до звіра (пікселі). Повертає "none" | "miss" | "wound" | "hit" | "bullseye".
static func shoot(h: Dictionary, dist: float) -> String:
	if int(h["arrows"]) <= 0 or int(h["index"]) >= h["queue"].size():
		return "none"
	var id: String = h["queue"][int(h["index"])]
	var a: Dictionary = Acts.HUNT_ANIMALS[id]
	h["arrows"] = int(h["arrows"]) - 1
	h["shots"] = int(h["shots"]) + 1
	var r := float(a["radius"])
	if dist > r:
		return "miss"
	var bull := dist <= r * Acts.HUNT_BULLSEYE
	if a["tough"] and not bull and not h["wounded"]:
		h["wounded"] = true  # вепра простим влучанням не взяти — поранений, біжить повільніше
		h["hits"] = int(h["hits"]) + 1
		return "wound"
	var meat := int(a["meat"])
	if bull:
		meat += int(ceil(meat / 2.0))
		h["bull"] = int(h["bull"]) + 1
	h["hits"] = int(h["hits"]) + 1
	h["meat"] = int(h["meat"]) + meat
	h["bag"].append(id)
	h["wounded"] = false
	h["index"] = int(h["index"]) + 1
	return "bullseye" if bull else "hit"


## Звір утік за край галявини — наступний.
static func escaped(h: Dictionary) -> void:
	h["wounded"] = false
	h["index"] = int(h["index"]) + 1


## Полювання закінчено: м'ясо в запас, слава за влучність. Повертає повідомлення.
static func finish_hunt(world, player, h: Dictionary) -> Array:
	var s := state(world)
	s["hunt_ready"] = false
	if h.get("rich", false):
		s["rich_hunt"] = false
	s["hunts"] = int(s["hunts"]) + 1
	var meat := int(h["meat"])
	s["meat"] = int(s["meat"]) + meat
	player.resources["meat"] = food(player, "meat") + meat
	var msgs := []
	if meat <= 0:
		msgs.append("Полювання без здобичі. Звір повернеться після походу.")
		return msgs
	var names := []
	for id in h["bag"]:
		names.append(str(Acts.HUNT_ANIMALS[id]["name"]).to_lower())
	msgs.append("Здобич: %s. +%d м'яса" % [", ".join(names), meat])
	if int(h["shots"]) > 0 and int(h["hits"]) == int(h["shots"]) and int(h["shots"]) >= Acts.HUNT_ARROWS:
		msgs[0] += "\nЖодної стріли намарно! +3 слави"
		msgs.append_array(GloryService.add(world, player, 3))
	return msgs


# ======================= Рибалка =======================

static func new_fishing(seed_value: int = -1, rich_day: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	return {"bait": Acts.FISH_BAIT, "ryba": 0, "caught": [], "rng": rng, "rich": rich_day}


static func roll_fish(f: Dictionary) -> String:
	return _weighted(Acts.FISH, f["rng"], {"som": 4, "shchuka": 2} if f.get("rich", false) else {})


## Скільки чекати клювання (секунд).
static func bite_delay(f: Dictionary) -> float:
	return f["rng"].randf_range(1.5, 4.5)


## Крок натягу волосіні: тримаєш — росте, відпустив — падає; риба смикає (pull — її сила, wave — фаза ривка −1…1).
static func step_tension(tension: float, holding: bool, pull: float, wave: float, delta: float) -> float:
	var v := (0.6 if holding else -0.5) + pull * wave
	return tension + v * delta


static func in_zone(tension: float) -> bool:
	return tension >= float(Acts.FISH_ZONE[0]) and tension <= float(Acts.FISH_ZONE[1])


## Закид витрачено (рано смикнув, зірвалась, порвав волосінь чи впіймав).
static func use_bait(f: Dictionary) -> void:
	f["bait"] = maxi(0, int(f["bait"]) - 1)


static func catch_fish(f: Dictionary, id: String) -> void:
	f["ryba"] = int(f["ryba"]) + int(Acts.FISH[id]["ryba"])
	f["caught"].append(id)


static func fishing_over(f: Dictionary) -> bool:
	return int(f["bait"]) <= 0


static func finish_fishing(world, player, f: Dictionary) -> Array:
	var s := state(world)
	s["fish_ready"] = false
	if f.get("rich", false):
		s["rich_fish"] = false
	s["fishings"] = int(s["fishings"]) + 1
	var n := int(f["ryba"])
	s["ryba"] = int(s["ryba"]) + n
	player.resources["ryba"] = food(player, "ryba") + n
	var msgs := []
	if n <= 0:
		msgs.append("Сьогодні не клювало. Риба повернеться після походу.")
		return msgs
	var names := []
	for id in f["caught"]:
		names.append(str(Acts.FISH[id]["name"]).to_lower())
	msgs.append("Улов: %s. +%d риби" % [", ".join(names), n])
	if "som" in f["caught"]:
		s["som"] = int(s["som"]) + 1
		msgs[0] += "\nСом! Про такий улов гомонітиме вся Січ: +3 слави"
		msgs.append_array(GloryService.add(world, player, 3))
	return msgs


# ======================= Казан =======================

static func can_cook(player, recipe: String) -> bool:
	var need: Dictionary = Acts.RECIPES[recipe]["need"]
	for r in need:
		if food(player, r) < int(need[r]):
			return false
	return player.trip_buffs.get("food", "") != recipe


## Зварити страву: діє один похід, нова страва замінює попередню.
static func cook(player, recipe: String) -> bool:
	if not can_cook(player, recipe):
		return false
	var need: Dictionary = Acts.RECIPES[recipe]["need"]
	for r in need:
		player.resources[r] = food(player, r) - int(need[r])
	player.trip_buffs["food"] = recipe
	player.recalc()
	return true


static func eaten(player) -> String:
	return str(player.trip_buffs.get("food", ""))
