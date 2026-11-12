extends RefCounted
## Трофейний ярмарок на хуторі. Раз на тиждень скупник привозить рідкісне й міняє на трофеї та гривні:
## три золоті речі під клас героя, артефакт, камені долі й жетони безпечної заточки.
## Товар у всіх той самий, бо його обирає номер тижня; кожну річ герой бере раз на тиждень.
## Стан у героя свій, world.fair: {"week": ключ тижня, "bought": {ключ товару: скільки взято}}.

const Data := preload("res://scripts/data/data.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")
const Classes := preload("res://scripts/data/classes.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const PerilService := preload("res://scripts/game/peril_service.gd")

const MIN_LEVEL := 20
const GOLD_ITEMS := 3  # золотих речей на тиждень
## Ціна золотої речі за її ступенем — «fair» у data/golden_tiers.json (трофеї й гривні). Шостий ступінь
## лишається надважким печерам, у нього ярмаркової ціни нема.
const ARTIFACT_TROPHY := 400
const ARTIFACT_GOLD := 80000
## Дрібний товар: ключ -> {"name", "trophy", "gold", "limit" на тиждень}.
const GOODS := {
	"zabuttia": {"name": "Камінь забуття", "trophy": 150, "gold": 15000, "limit": 1},
	"alatyr": {"name": "Алатир-камінь", "trophy": 300, "gold": 40000, "limit": 1},
	"safe": {"name": "Жетон безпечної заточки", "trophy": 15, "gold": 2000, "limit": 5},
}
const GOODS_ORDER := ["safe", "zabuttia", "alatyr"]


static func week() -> String:
	return ChallengeService.week_key(ChallengeService._now())


static func state(world) -> Dictionary:
	var s: Dictionary = world.fair
	if str(s.get("week", "")) != week():
		s["week"] = week()
		s["bought"] = {}
	return s


static func unlocked(player) -> bool:
	return not player.is_peasant() and int(player.level) >= MIN_LEVEL


## Найвищий ступінь золота, який привозять героєві цього рівня.
static func top_tier(level: int) -> int:
	return clampi(1 + level / 20, 1, Uniques.TOP_COMMON_TIER)


static func _shuffled(ids: Array, salt: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(salt + ":" + week())
	var out := ids.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Товар цього тижня для героя: [{"key", "kind", "id", "name", "trophy", "gold", "limit", "tier"}].
static func stock(player) -> Array:
	var out := []
	var weapons: Array = Classes.CLASSES[player.job].get("weapons", [])
	var top := top_tier(int(player.level))
	var pool := []
	for id in Uniques.ids():
		var D: Dictionary = Uniques.def(id)
		var t: int = int(D["tier"])
		if t > top or t < maxi(1, top - 1):
			continue  # лише свого ступеня й на один нижчого
		if D["slot"] == "weapon" and not str(D["type"]) in weapons:
			continue
		pool.append(id)
	for id in _shuffled(pool, "gold").slice(0, GOLD_ITEMS):
		var t: int = int(Uniques.def(id)["tier"])
		out.append({"key": "u:" + id, "kind": "unique", "id": id, "name": str(Uniques.def(id)["name"]), "tier": t,
			"trophy": int(Uniques.tier_fair(t)["trophy"]), "gold": int(Uniques.tier_fair(t)["gold"]), "limit": 1})
	var peril := []
	for loc in PerilService.ids():
		peril.append(str(Data.LOCATIONS[loc]["boss"]))
	var arts := []
	for id in Artifacts.ids():
		if not str(Artifacts.def(id).get("boss", "")) in peril:
			arts.append(id)
	if not arts.is_empty():
		var aid: String = _shuffled(arts, "art")[0]
		out.append({"key": "a:" + aid, "kind": "artifact", "id": aid, "name": str(Artifacts.def(aid)["name"]), "tier": 0,
			"trophy": ARTIFACT_TROPHY, "gold": ARTIFACT_GOLD, "limit": 1})
	for gid in GOODS_ORDER:
		var G: Dictionary = GOODS[gid]
		out.append({"key": "g:" + gid, "kind": "good", "id": gid, "name": str(G["name"]), "tier": 0,
			"trophy": int(G["trophy"]), "gold": int(G["gold"]), "limit": int(G["limit"])})
	return out


static func find(player, key: String) -> Dictionary:
	for e in stock(player):
		if str(e["key"]) == key:
			return e
	return {}


static func bought(world, key: String) -> int:
	return int(state(world)["bought"].get(key, 0))


## Чому не можна взяти ("" — можна).
static func block_reason(world, player, key: String) -> String:
	if not unlocked(player):
		return "ярмарок відкривається з %d-го рівня героя" % MIN_LEVEL
	var e := find(player, key)
	if e.is_empty():
		return "цього тижня такого не привезли"
	if bought(world, key) >= int(e["limit"]):
		return "уже взято цього тижня"
	if e["kind"] == "artifact" and Artifacts.has(player.inventory, str(e["id"])):
		return "такий артефакт уже лежить у торбі"
	if int(player.resources.get("trophy", 0)) < int(e["trophy"]):
		return "бракує трофеїв: %d" % (int(e["trophy"]) - int(player.resources.get("trophy", 0)))
	if int(player.gold) < int(e["gold"]):
		return "бракує гривень: %d" % (int(e["gold"]) - int(player.gold))
	if e["kind"] != "good" and player.bag_full():
		return "торба повна"
	return ""


## Обміняти трофеї на товар. Повертає {"ok", "msg"}.
static func buy(world, player, key: String) -> Dictionary:
	var why := block_reason(world, player, key)
	if why != "":
		return {"ok": false, "msg": why.substr(0, 1).to_upper() + why.substr(1)}
	var e := find(player, key)
	player.resources["trophy"] = int(player.resources.get("trophy", 0)) - int(e["trophy"])
	player.gold -= int(e["gold"])
	state(world)["bought"][key] = bought(world, key) + 1
	match str(e["kind"]):
		"unique":
			player.add_item(Uniques.make(str(e["id"]), int(player.level)))
		"artifact":
			player.add_item(Artifacts.make(str(e["id"])))
		"good":
			if str(e["id"]) == "safe":
				world.boosts["safe_sharpen"] = int(world.boosts.get("safe_sharpen", 0)) + 1
			else:
				StoneService.grant(player, str(e["id"]))
	return {"ok": true, "msg": "Виміняно: %s" % e["name"]}
