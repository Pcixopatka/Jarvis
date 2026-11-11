extends RefCounted
## Козацька варта на Сторожовій могилі: вистояти п'ять хвилин проти нечисті, що суне без упину
## й лютішає щохвилини. Смерті нема — варту просто знято. Нагорода за кожну хвилину — раз на день;
## рекорд часу й убитих зберігається. Стан — world.vigil:
##   {"best_time": с, "best_kills": n, "runs": n, "day": ключ дня, "paid": хвилин оплачено сьогодні}

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")

const SPOT_ID := "varta"


static func state(world) -> Dictionary:
	var s: Dictionary = world.vigil
	for k in ["best_time", "best_kills", "runs", "paid"]:
		if not s.has(k):
			s[k] = 0
	var day := ChallengeService.day_key(ChallengeService._now())
	if s.get("day", "") != day:
		s["day"] = day
		s["paid"] = 0
	return s


static func unlocked(player) -> bool:
	return not player.is_peasant() and player.level >= int(Acts.SPOTS[SPOT_ID]["level"])


## Сила нечисті на конкретній хвилині варти (0 — перша): частка звичайної мірки рівня героя.
## std_hp — здоров'я звичайного зараженого, std_dmg — його удар. Від спорядження не залежить.
## Досвіду з юрби менше — нагорода тут за хвилини.
static func targets_at(player, minute: int) -> Dictionary:
	var lvl := int(player.level)
	return {"std_hp": Data.enemy_std_hp(lvl) * (Acts.VIGIL_HP + Acts.VIGIL_HP_STEP * minute),
		"std_dmg": Data.enemy_std_dmg(lvl) * (Acts.VIGIL_HIT + Acts.VIGIL_HIT_STEP * minute),
		"xp_mult": Acts.VIGIL_XP}


static func battle_loc(player) -> Dictionary:
	var lvl: int = maxi(4, player.level)
	var enemies := ["zarazhenyi", "upyr", "vovkulaka", "mavka"]
	if lvl >= 8:
		enemies = ["zarazhenyi", "pishchalnyk", "vovkulaka", "upyr"]
	if lvl >= 13:
		enemies = ["zarazhenyi", "pishchalnyk", "chort", "vovkulaka"]
	var L := {"name": "Козацька варта", "type": "vigil", "biome": "steppe", "level": lvl, "enemies": enemies,
		"goal": Acts.VIGIL_GOAL, "hero_level": player.level, "desc": ""}
	L.merge(targets_at(player, 0))
	return L


## Нагорода за хвилину m (1 — перша). item: рідкість речі або -1.
static func minute_reward(level: int, m: int) -> Dictionary:
	var goal_min := int(Acts.VIGIL_GOAL / 60.0)
	var r := {"gold": Acts.VIGIL_GOLD * level * m, "glory": Acts.VIGIL_GLORY if m <= goal_min else 2, "item": -1, "trophy": 0}
	if m == 3:
		r["item"] = 1
	if m == goal_min:
		r["item"] = 2
		r["trophy"] = 2
		r["glory"] = int(r["glory"]) + Acts.VIGIL_GLORY_GOAL
	return r


## Хвилину вистояно. Нагорода видається раз на день за кожну хвилину. Повертає
## {"paid": чи видано, "gold", "glory", "item", "trophy", "msgs": [...]}.
static func on_minute(world, player, m: int) -> Dictionary:
	var s := state(world)
	var out := {"paid": false, "gold": 0, "glory": 0, "item": -1, "trophy": 0, "msgs": []}
	if m <= int(s["paid"]):
		return out
	s["paid"] = m
	var r := minute_reward(player.level, m)
	out.merge(r, true)
	out["paid"] = true
	player.gold += int(r["gold"])
	if int(r["trophy"]) > 0:
		player.resources["trophy"] = int(player.resources.get("trophy", 0)) + int(r["trophy"])
	out["msgs"] = GloryService.add(world, player, int(r["glory"]))
	return out


## Варту закінчено (вистояв, пішов чи впав). Оновлює рекорди. Повертає повідомлення.
static func finish(world, player, time: float, kills: int) -> Array:
	var s := state(world)
	s["runs"] = int(s["runs"]) + 1
	var msgs := []
	var old_t := float(s["best_time"])
	var mins := int(time) / 60
	var secs := int(time) % 60
	var text := "Варта: %d:%02d, вбито %d" % [mins, secs, kills]
	if time > old_t + 1.0:
		s["best_time"] = time
		if old_t > 0.0:
			text += "\nНовий рекорд часу! +5 слави"
			msgs.append_array(GloryService.add(world, player, 5))
	if kills > int(s["best_kills"]):
		s["best_kills"] = kills
	msgs.insert(0, text)
	return msgs


static func time_text(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
