extends RefCounted
## Золота здобич із босів: хто гідний, якого ступеня, з яким шансом і яка саме річ.
## Шанси навмисно малі; реклама «×2 здобичі», свята й зараза на них не впливають.

const Data := preload("res://scripts/data/data.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")


## Справжній господар лігва чи супербос Башти (не ватажок варти, не примара, не чудовисько Кола).
static func is_lair_boss(combat, e) -> bool:
	if not e.is_boss or e.illusion:
		return false
	if combat.is_tower():
		return true
	return combat.is_dungeon() and e.kind == str(combat.loc.get("boss", ""))


## Золото дає лише бос, що не надто слабший за героя: старі печери високим рівнем не «фармляться».
static func worthy(combat, player, e) -> bool:
	return is_lair_boss(combat, e) and int(e.level) >= int(player.level) - Uniques.LEVEL_GAP


## Ступінь боса: власний, а в Глибинах і Башті вищий. Шостий ступінь мають лише надважкі боси:
## Глибини й Башта до нього не дотягують.
static func boss_tier(combat, e) -> int:
	var t: int = int(Uniques.BOSS_TIER.get(e.kind, 0))
	var top: int = maxi(Uniques.TOP_COMMON_TIER, t)
	if t == 0:
		t = 3
		for id in Data.LOCATIONS:
			var L: Dictionary = Data.LOCATIONS[id]
			if str(L.get("boss", "")) == e.kind:
				var lv: int = int(L["level"])
				t = 1 if lv < 8 else (2 if lv < 12 else (3 if lv < 16 else 4))
				break
	if combat.is_tower():
		t += 2 if int(combat.loc.get("floor", 0)) >= 40 else 1
	elif combat.loc.has("depth"):
		t += int(combat.loc["depth"]) / 8
	return clampi(t, 1, top)


static func chance(tier: int, luck: int) -> float:
	if luck >= Uniques.LUCK_SURE:
		return 1.0
	return float(Uniques.BASE_CHANCE[tier]) * (1.0 + luck / Uniques.LUCK_STEP)


## Усі золоті речі героя (вдягнені й у торбі) за id.
static func owned(player) -> Dictionary:
	var out := {}
	for it in player.inventory:
		if Uniques.is_unique(it):
			out[str(it["unique"])] = true
	for slot in player.equipment:
		if Uniques.is_unique(player.equipment[slot]):
			out[str(player.equipment[slot]["unique"])] = true
	return out


## Яка річ випаде: свого ступеня найчастіше, улюблена річ боса втричі частіше, вже наявна вчетверо рідше.
static func pick(player, tier: int, boss_kind: String) -> String:
	var weapons: Array = Classes.CLASSES[player.job].get("weapons", [])
	var have := owned(player)
	var ids := []
	var weights := []
	var total := 0.0
	for id in Uniques.ORDER:
		var D: Dictionary = Uniques.DEFS[id]
		var t: int = int(D["tier"])
		if t > tier:
			continue
		if D["slot"] == "weapon" and not D["type"] in weapons:
			continue
		var w := 4.0 if t == tier else (2.0 if t == tier - 1 else 1.0)
		if boss_kind in D["bosses"]:
			w *= 3.0
		if have.has(id):
			w *= 0.25
		ids.append(id)
		weights.append(w)
		total += w
	if ids.is_empty():
		return ""
	var r := randf() * total
	for i in ids.size():
		r -= weights[i]
		if r <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]


## Бос упав: чи дає він золоту річ. Повертає річ або порожній словник; веде лічильник Долі героя.
static func on_boss(combat, player, e) -> Dictionary:
	if not worthy(combat, player, e):
		return {}
	var tier := boss_tier(combat, e)
	if randf() >= chance(tier, int(player.u_luck)) * (1.0 + float(player.art.get("unique_luck", 0.0))) * player.loot_luck():
		player.u_luck += 1
		return {}
	var id := pick(player, tier, e.kind)
	if id == "":
		return {}
	player.u_luck = 0
	return Uniques.make(id, mini(int(e.level), int(combat.loc.get("loot_level", e.level))))  # у Башті й Глибинах здобич не росте вище 99-го


## Шанс артефакта з боса: основа (гідний бос, слабкий чи супербос Башти) з поправкою на долю трофея.
static func artifact_chance(base: float, luck: int) -> float:
	if luck >= Artifacts.LUCK_SURE:
		return 1.0
	return minf(1.0, base * (1.0 + luck / Artifacts.LUCK_STEP))


## Бос упав: чи лишає він свій трофей-артефакт. Того, що вже лежить у торбі, удруге не дає.
## Веде лічильник долі трофея для цього боса (player.art_luck).
static func artifact_on_boss(combat, player, e) -> Dictionary:
	if not is_lair_boss(combat, e):
		return {}
	var id: String = Artifacts.by_boss(e.kind)
	if id == "" or Artifacts.has(player.inventory, id):
		return {}
	var base: float = Artifacts.CHANCE_TOWER if combat.is_tower() else (Artifacts.CHANCE if worthy(combat, player, e) else Artifacts.CHANCE_GREY)
	if combat.loc.has("peril"):
		base = Artifacts.CHANCE_PERIL
	var kind := str(e.kind)
	var luck: int = int(player.art_luck.get(kind, 0))
	if randf() >= artifact_chance(base, luck) * player.loot_luck():
		player.art_luck[kind] = luck + 1
		return {}
	player.art_luck.erase(kind)
	return Artifacts.make(id)
