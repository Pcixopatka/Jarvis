extends RefCounted
## Город на хуторі: грядки, що ростуть у реальному часі (і коли гра закрита).
## Посадив — чекаєш — збираєш: зілля (трави), городину (на борщ у казані) або хміль (гривні).
## Город спільний для всіх персонажів, як і весь хутір; урожай дістається тому, хто збирає.
## Стан — world.camp["garden"]: {"beds": [{"crop", "ts"} або {}], "harvests": n}

const Camp := preload("res://scripts/data/camp_data.gd")
const CampService := preload("res://scripts/game/camp_service.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const HolidayService := preload("res://scripts/game/holiday_service.gd")


static func level(world) -> int:
	return CampService.level(world, "horod")


static func beds_count(world) -> int:
	return int(Camp.GARDEN_BEDS[clampi(level(world), 0, Camp.GARDEN_BEDS.size() - 1)])


static func state(world) -> Dictionary:
	var camp := CampService.state(world)
	if not camp.has("garden"):
		camp["garden"] = {"beds": [], "harvests": 0}
	var g: Dictionary = camp["garden"]
	var beds: Array = g["beds"]
	while beds.size() < beds_count(world):
		beds.append({})
	return g


static func bed(world, i: int) -> Dictionary:
	var beds: Array = state(world)["beds"]
	return beds[i] if i >= 0 and i < beds_count(world) else {}


## Скільки секунд росте культура (на 3-му рівні городу — швидше).
static func grow_time(world, crop: String) -> float:
	return float(Camp.CROPS[crop]["hours"]) * 3600.0 * (Camp.GARDEN_FAST if level(world) >= 3 else 1.0)


## Частка росту грядки 0..1 (порожня — 0).
static func progress(world, i: int) -> float:
	var b := bed(world, i)
	if b.is_empty():
		return 0.0
	return clampf((ChallengeService._now() - float(b["ts"])) / grow_time(world, b["crop"]), 0.0, 1.0)


static func ready(world, i: int) -> bool:
	return not bed(world, i).is_empty() and progress(world, i) >= 1.0


static func time_left(world, i: int) -> int:
	var b := bed(world, i)
	if b.is_empty():
		return 0
	return maxi(0, int(ceil(float(b["ts"]) + grow_time(world, b["crop"]) - ChallengeService._now())))


static func ready_count(world) -> int:
	var n := 0
	for i in beds_count(world):
		if ready(world, i):
			n += 1
	return n


static func can_plant(world, player, i: int, crop: String) -> bool:
	return i >= 0 and i < beds_count(world) and bed(world, i).is_empty() and Camp.CROPS.has(crop) and player.gold >= int(Camp.CROPS[crop]["seed"])


static func plant(world, player, i: int, crop: String) -> bool:
	if not can_plant(world, player, i, crop):
		return false
	player.gold -= int(Camp.CROPS[crop]["seed"])
	state(world)["beds"][i] = {"crop": crop, "ts": ChallengeService._now()}
	return true


## Скільки дасть грядка цьому героєві (хміль росте в ціні з рівнем).
static func yield_of(crop: String, hero_level: int) -> int:
	var c: Dictionary = Camp.CROPS[crop]
	var feast := 1.0 + HolidayService.bonus("harvest")  # на Спаса врожай щедріший
	if c["gives"] == "gold":
		return int(int(c["amount"]) * (1.0 + 0.2 * (hero_level - 1)) * feast)
	return int(round(int(c["amount"]) * feast))


## Зібрати достиглу грядку. Повертає текст ("" — нема чого збирати).
static func harvest(world, player, i: int) -> String:
	if not ready(world, i):
		return ""
	var g := state(world)
	var crop: String = g["beds"][i]["crop"]
	var c: Dictionary = Camp.CROPS[crop]
	var n := yield_of(crop, player.level)
	g["beds"][i] = {}
	g["harvests"] = int(g["harvests"]) + 1
	if c["gives"] == "gold":
		player.gold += n
		return "%s продано: +%d грн" % [c["name"], n]
	player.resources[c["gives"]] = int(player.resources.get(c["gives"], 0)) + n
	return "%s: +%d" % [c["name"], n]


## Зібрати все достигле. Повертає список текстів.
static func harvest_all(world, player) -> Array:
	var out := []
	for i in beds_count(world):
		var m := harvest(world, player, i)
		if m != "":
			out.append(m)
	return out


## Викорчувати грядку (насіння не повертається).
static func uproot(world, i: int) -> bool:
	if bed(world, i).is_empty():
		return false
	state(world)["beds"][i] = {}
	return true


static func time_text(sec: int) -> String:
	if sec <= 0:
		return "готово"
	var h := sec / 3600
	var m := int(ceil((sec % 3600) / 60.0))
	if m == 60:
		h += 1
		m = 0
	if h > 0:
		return "%d год %d хв" % [h, m] if m > 0 else "%d год" % h
	return "%d хв" % maxi(1, m)
