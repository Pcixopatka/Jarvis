extends RefCounted
## Походи побратимів: супутника можна відправити у власний похід на годину, чотири чи вісім.
## Час реальний (іде й коли гра закрита). Поки супутник у поході, в бою його нема й досвіду з боїв він не має.
## Повернувся — приносить гривні, ресурси, трофеї, інколи річ, і сам набирається досвіду.
## Інколи потрапляє в засідку: тоді гривень удвічі менше, а сам він поранений.
## Стан — у записі супутника world.companions[i]["away"]: {"kind", "start", "until"}.

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Party := preload("res://scripts/game/party.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const HeroService := preload("res://scripts/game/hero_service.gd")


static func away(c: Dictionary) -> bool:
	return not c.get("away", {}).is_empty()


## Повернувся, але здобич іще не забрано.
static func back(c: Dictionary) -> bool:
	return away(c) and ChallengeService._now() >= int(c["away"]["until"])


static func time_left(c: Dictionary) -> int:
	return maxi(0, int(c["away"]["until"]) - ChallengeService._now()) if away(c) else 0


static func away_count(world) -> int:
	var n := 0
	for c in world.companions:
		if away(c):
			n += 1
	return n


static func can_send(world, i: int, kind: String) -> bool:
	if i < 0 or i >= world.companions.size() or not Acts.is_expedition(kind):
		return false
	var c: Dictionary = world.companions[i]
	return not away(c) and not c.get("downed", false)


static func send(world, i: int, kind: String) -> bool:
	if not can_send(world, i, kind):
		return false
	var now := ChallengeService._now()
	world.companions[i]["away"] = {"kind": kind, "start": now, "until": now + int(float(Acts.expedition(kind)["hours"]) * 3600.0)}
	return true


## Відкликати з дороги: повертається одразу, але з порожніми руками.
static func recall(world, i: int) -> bool:
	if i < 0 or i >= world.companions.size() or not away(world.companions[i]):
		return false
	world.companions[i].erase("away")
	return true


## Здобич походу для цього супутника (rng — для тестів).
static func reward(c: Dictionary, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var E: Dictionary = Acts.expedition(kind)
	var lvl := int(c.get("level", 1))
	var k := (1.0 + Acts.EXPEDITION_LEVEL * (lvl - 1)) * (Acts.EXPEDITION_HERO if c.get("hero", "") != "" else 1.0)
	var res := {}
	var keys := Camp.resources()
	for n in int(round(int(E["res"]) * (Acts.EXPEDITION_HERO if c.get("hero", "") != "" else 1.0))):
		var r: String = keys[rng.randi() % keys.size()]
		res[r] = int(res.get(r, 0)) + 1
	return {
		"gold": int(Acts.EXPEDITION_GOLD * float(E["gold"]) * k * rng.randf_range(0.85, 1.15)),
		"res": res,
		"xp": int(Party.xp_for_level(lvl) * float(E["xp"])),
		"item": rng.randf() < float(E["item"]),
		"trophy": int(E["trophy"]),
		"wounded": rng.randf() < float(E["risk"]),
	}


## Зустріти всіх, хто повернувся: здобич герою, досвід супутникові. Повертає повідомлення.
## healed — зустрічаємо в місті чи на хуторі, де рани одразу перев'яжуть.
static func collect(world, player, seed_value: int = -1, healed: bool = false) -> Array:
	var msgs := []
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for c in world.companions:
		if not back(c):
			continue
		var kind: String = c["away"]["kind"]
		var E: Dictionary = Acts.expedition(kind)
		var r := reward(c, kind, rng)
		c.erase("away")
		if r["wounded"]:
			r["gold"] = int(r["gold"]) / 2  # засідка: половину здобичі довелося кинути
		player.gold += int(r["gold"])
		var parts := ["+%d грн" % int(r["gold"])]
		for id in r["res"]:
			player.resources[id] = int(player.resources.get(id, 0)) + int(r["res"][id])
			parts.append("%s %d" % [Camp.res_name(id).to_lower(), int(r["res"][id])])
		if int(r["trophy"]) > 0:
			player.resources[Camp.TROPHY] = int(player.resources.get(Camp.TROPHY, 0)) + int(r["trophy"])
			parts.append("трофеї %d" % int(r["trophy"]))
		var name := HeroService.member_name(c)
		var text := "%s повернувся %s: %s" % [name, E["back"], ", ".join(parts)]
		if r["item"]:
			var it := Data.gen_item(maxi(1, int(c.get("level", 1))), Data.roll_rarity(int(c.get("level", 1)), 1))
			if player.add_item(it):
				text += "\nПриніс річ: %s" % Data.item_title(it)
			else:
				var g := Data.sell_price(it)
				player.gold += g
				text += "\nПриніс річ, та торба повна: продано за %d грн" % g
		# Досвід самому супутникові (не вище рівня героя)
		var lvl := int(c.get("level", 1))
		if lvl < player.level:
			c["xp"] = int(c.get("xp", 0)) + int(r["xp"])
			while lvl < player.level and int(c["xp"]) >= Party.xp_for_level(lvl):
				c["xp"] = int(c["xp"]) - Party.xp_for_level(lvl)
				lvl += 1
			if lvl >= player.level:
				c["xp"] = 0
			if lvl != int(c.get("level", 1)):
				c["level"] = lvl
				text += "\nНабрався досвіду: рівень %d" % lvl
		if r["wounded"]:
			c["downed"] = not healed
			text += "\nПотрапив у засідку: гривень удвічі менше. " + ("Рани йому вже перев'язали." if healed else "Сам поранений: одужає в місті чи на хуторі.")
		msgs.append(text)
	return msgs


static func time_text(sec: int) -> String:
	if sec <= 0:
		return "уже тут"
	var h := sec / 3600
	var m := int(ceil((sec % 3600) / 60.0))
	if m == 60:
		h += 1
		m = 0
	if h > 0:
		return "%d год %d хв" % [h, m] if m > 0 else "%d год" % h
	return "%d хв" % maxi(1, m)
