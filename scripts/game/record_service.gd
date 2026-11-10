extends RefCounted
## Літопис слави: рекорди роду — найкращі досягнення серед усіх твоїх персонажів.
## Зберігаються в акаунті (account.records, доступні як world.records):
##   {ключ: {"value", "slot", "who": "Характерник 34 рівня", "day": "2026-11-09"}}
## sync() звіряє поточного героя з рекордами: новий рекорд записується, за віхи (step) дається слава,
## а якщо рекорд відібрано в іншого персонажа — про це кажемо окремо.

const Acts := preload("res://scripts/data/activities.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")


## Що зараз має цей герой за кожним рекордом.
static func hero_values(world, player) -> Dictionary:
	return {
		"level": int(player.level),
		"glory": int(world.glory),
		"tower": int(world.tower.get("best", 0)),
		"depth": int(world.depths.get("best", 0)),
		"vigil": int(float(world.vigil.get("best_time", 0.0))),
		"vigil_kills": int(world.vigil.get("best_kills", 0)),
		"duel_titles": int(world.duel.get("titles", 0)),
		"duel_streak": int(world.duel.get("best_streak", 0)),
		"ring_titles": int(world.ring.get("titles", 0)),
		"muster_titles": int(world.muster.get("titles", 0)),
		"bounties": int(world.bounties.get("done", 0)),
		"trade_profit": int(world.trade.get("profit", 0)),
		"dice_streak": int(world.tavern.get("best_streak", 0)),
	}


static func value_text(key: String, value: int) -> String:
	if value <= 0:
		return "—"
	var f: String = Acts.RECORDS[key]["fmt"]
	if f == "time":
		return "%d:%02d" % [value / 60, value % 60]
	return f % value


static func record(world, key: String) -> Dictionary:
	return world.records.get(key, {})


static func who(player) -> String:
	return "%s %d рівня" % [player.class_name_ua(), player.level]


## Звірити героя з рекордами роду. Повертає повідомлення про побиті рекорди й славу за віхи.
static func sync(world, player, slot: int = 0) -> Array:
	var msgs := []
	var vals := hero_values(world, player)
	for key in Acts.RECORD_ORDER:
		var v := int(vals[key])
		var cur: Dictionary = record(world, key)
		var old := int(cur.get("value", 0))
		if v <= old:
			continue
		var R: Dictionary = Acts.RECORDS[key]
		var took: bool = old > 0 and int(cur.get("slot", slot)) != slot
		world.records[key] = {"value": v, "slot": slot, "who": who(player), "day": ChallengeService.day_key(ChallengeService._now())}
		if took:
			msgs.append("Рекорд роду побито! %s: %s (було %s — %s)" % [R["name"], value_text(key, v), value_text(key, old), str(cur.get("who", "?"))])
		var step := int(R["step"])
		if step > 0 and v / step > old / step:
			var g := int(R["glory"]) * (v / step - old / step)
			msgs.append("Рекорд роду: %s — %s. +%d слави" % [R["name"], value_text(key, v), g])
			msgs.append_array(GloryService.add(world, player, g))
	# Слава могла зрости від віх — запишемо й цей рекорд одразу
	if int(world.glory) > int(record(world, "glory").get("value", 0)):
		world.records["glory"] = {"value": int(world.glory), "slot": slot, "who": who(player), "day": ChallengeService.day_key(ChallengeService._now())}
	return msgs


## Рядки для вкладки «Слава»: [{"name", "mine", "best", "who", "holder": чи тримає рекорд цей герой}].
static func rows(world, player, slot: int = 0) -> Array:
	var out := []
	var vals := hero_values(world, player)
	for key in Acts.RECORD_ORDER:
		var cur: Dictionary = record(world, key)
		var best := int(cur.get("value", 0))
		out.append({
			"key": key,
			"name": Acts.RECORDS[key]["name"],
			"mine": value_text(key, int(vals[key])),
			"best": value_text(key, best),
			"who": str(cur.get("who", "")),
			"holder": best > 0 and int(vals[key]) >= best and int(cur.get("slot", -1)) == slot,
		})
	return out
