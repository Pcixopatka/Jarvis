extends RefCounted
## Герць на майдані Січі — тижневий турнір один на один: три кола проти іменованих суперників.
## Без смерті: програв — мінус спроба. Стан — world.duel:
##   {"week": ключ тижня, "round": скільки кіл уже виграно (0..3), "tries": спроб лишилось,
##    "titles": скільки разів ставав чемпіоном, "wins": виграних кіл за весь час, "belt": чи вже має пояс}

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")
const Power := preload("res://scripts/game/power.gd")

const ROUNDS := 3
const TRIES := 3
const MIN_LEVEL := 5
const BELT_NAME := "Пояс чемпіона Січі"


static func week() -> String:
	return ChallengeService.week_key(ChallengeService._now())


static func state(world) -> Dictionary:
	var s: Dictionary = world.duel
	if s.get("week", "") != week():
		s["week"] = week()
		s["round"] = 0
		s["tries"] = TRIES
	for k in ["titles", "wins"]:
		if not s.has(k):
			s[k] = 0
	if not s.has("belt"):
		s["belt"] = false
	return s


static func unlocked(player) -> bool:
	return not player.is_peasant() and player.level >= MIN_LEVEL


## Три суперники цього тижня (однакові для всіх героїв, міняються щотижня).
static func lineup(week_key: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(week_key if week_key != "" else week())
	var ids: Array = Acts.RIVAL_ORDER.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	return ids.slice(0, ROUNDS)


static func is_champion(world) -> bool:
	return int(state(world)["round"]) >= ROUNDS


static func can_fight(world, player) -> bool:
	var s := state(world)
	return unlocked(player) and int(s["round"]) < ROUNDS and int(s["tries"]) > 0


## Наступний суперник ({} — турнір скінчено).
static func next_rival(world) -> Dictionary:
	var s := state(world)
	if int(s["round"]) >= ROUNDS:
		return {}
	var id: String = lineup()[int(s["round"])]
	var info: Dictionary = Acts.RIVALS[id].duplicate()
	info["id"] = id
	return info


static func gold_for(round_i: int, level: int) -> int:
	return int(Acts.DUEL_GOLD[round_i]) * level


## Опис бою з конкретним суперником у конкретному колі. Суперник міряється силою з героєм:
## здоров'я — від шкоди героя, удар — від його здоров'я, тож герць чесний на будь-якому рівні.
static func loc_for(player, rival_id: String, round_i: int) -> Dictionary:
	return {"name": "Герць: " + str(Acts.RIVALS[rival_id]["name"]), "type": "duel", "biome": "maidan", "level": player.level, "enemies": [],
		"rival": rival_id, "round": round_i,
		"rival_hp": Power.dps(player) * float(Acts.DUEL_SECONDS[round_i]),
		"rival_cap": 1.0 / (0.6 * float(Acts.DUEL_SECONDS[round_i])),  # найшвидший герць — 60% від розрахункового часу
		"rival_dmg": Power.hit(player, float(Acts.DUEL_HIT[round_i]) * hit_scale(player.level)), "desc": ""}


## Досвідчений герой краще лікується в бою (вампіризм, вміння), тож суперник б'є трохи сильніше.
static func hit_scale(level: int) -> float:
	return clampf(0.55 + 0.015 * level, 0.6, 1.3)


## Опис бою наступного кола (для combat.enter через defense_loc).
static func battle_loc(world, player) -> Dictionary:
	return loc_for(player, next_rival(world)["id"], int(state(world)["round"]))


## Перемога в колі: гривні, слава; у фіналі — чемпіонство й пояс (уперше). Повертає повідомлення.
static func win(world, player) -> Array:
	var s := state(world)
	var r := int(s["round"])
	var msgs := []
	var g := gold_for(r, player.level)
	player.gold += g
	s["round"] = r + 1
	s["wins"] = int(s["wins"]) + 1
	if r + 1 < ROUNDS:
		msgs.append("Коло %d за тобою! +%d грн, +%d слави" % [r + 1, g, Acts.DUEL_GLORY[r]])
	else:
		s["titles"] = int(s["titles"]) + 1
		var text := "Ти — чемпіон майдану! +%d грн, +%d слави" % [g, Acts.DUEL_GLORY[r]]
		if not s["belt"]:
			s["belt"] = true
			var belt := champion_belt(player.level)
			if not player.add_item(belt):
				player.inventory.append(belt)
			text += "\nКошовий вручає тобі «%s»" % BELT_NAME
		else:
			player.resources["trophy"] = int(player.resources.get("trophy", 0)) + 3
			text += " і 3 трофеї"
		msgs.append(text)
	msgs.append_array(GloryService.add(world, player, int(Acts.DUEL_GLORY[r])))
	return msgs


## Поразка в колі: мінус спроба.
static func lose(world) -> String:
	var s := state(world)
	s["tries"] = maxi(0, int(s["tries"]) - 1)
	if int(s["tries"]) <= 0:
		return "Тебе поклали на лопатки. Спроб цього тижня більше нема — приходь наступного."
	return "Тебе поклали на лопатки. Лишилось спроб: %d." % int(s["tries"])


## Пояс чемпіона: легендарний пояс рівня героя з власною назвою.
static func champion_belt(level: int) -> Dictionary:
	var it := Data.gen_item(maxi(1, level), 3, "belt")
	it["name"] = BELT_NAME
	return it


## Скільки днів до нового турніру (тиждень починається в понеділок).
static func days_to_reset() -> int:
	var t := ChallengeService._now()
	var day := int(t / 86400 + 3) % 7  # 0 — понеділок
	return 7 - day
