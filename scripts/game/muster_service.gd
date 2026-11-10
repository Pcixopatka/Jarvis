extends RefCounted
## Гетьманський огляд у Чигирині — тижневі сутички ватаг: герой із побратимами проти сотні.
## Три сутички проти трьох сотень, три спроби на тиждень. Без смерті: поклали — мінус спроба.
## Суперники міряються з героєм (як у герці), тож добрий загін тут справді важить:
## побратими б'ють і відвертають на себе удари. Без побратимів сотня виставляє менше людей.
## Стан — world.muster: {"week": ключ тижня, "round": виграно сутичок (0..3), "tries": спроб лишилось,
##   "titles": скільки разів виграно весь огляд, "wins": виграних сутичок за весь час, "prize": чи вже має ладанку}

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const DuelService := preload("res://scripts/game/duel_service.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")
const Power := preload("res://scripts/game/power.gd")

const ROUNDS := 3
const TRIES := 3
const PRIZE_NAME := "Гетьманська ладанка"


static func week() -> String:
	return ChallengeService.week_key(ChallengeService._now())


static func state(world) -> Dictionary:
	var s: Dictionary = world.muster
	if s.get("week", "") != week():
		s["week"] = week()
		s["round"] = 0
		s["tries"] = TRIES
	for k in ["titles", "wins"]:
		if not s.has(k):
			s[k] = 0
	if not s.has("prize"):
		s["prize"] = false
	return s


static func unlocked(player) -> bool:
	return not player.is_peasant() and player.level >= int(Acts.MUSTER_MIN_LEVEL)


## Три сотні цього тижня (однакові для всіх героїв).
static func lineup(week_key: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("muster:" + (week_key if week_key != "" else week()))
	var ids: Array = Acts.MUSTER_ORDER.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	return ids.slice(0, ROUNDS)


static func is_winner(world) -> bool:
	return int(state(world)["round"]) >= ROUNDS


static func can_fight(world, player) -> bool:
	var s := state(world)
	return unlocked(player) and int(s["round"]) < ROUNDS and int(s["tries"]) > 0


## Наступна сотня ({} — огляд скінчено).
static func next_team(world) -> Dictionary:
	var s := state(world)
	if int(s["round"]) >= ROUNDS:
		return {}
	var id: String = lineup()[int(s["round"])]
	var info: Dictionary = Acts.MUSTER_TEAMS[id].duplicate()
	info["id"] = id
	return info


## Скільки побратимів стане поруч (ті, хто в загоні й на ногах).
static func allies(world) -> int:
	var n := 0
	for c in world.companions:
		if not bool(c.get("downed", false)) and c.get("away", {}).is_empty():
			n += 1
	return n


## Скільки людей виставить сотня: проти самотнього героя — на двох менше, з одним побратимом — на одного.
static func team_size(round_i: int, allies_n: int) -> int:
	return maxi(1, int(Acts.MUSTER_SIZE[clampi(round_i, 0, ROUNDS - 1)]) - maxi(0, 2 - allies_n))


## Бійці сотні для сутички: [{"style", "sprite", "name", "captain"}]. Перший — сотник.
static func fighters(team_id: String, n: int, seed_text: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fighters:" + team_id + ":" + (seed_text if seed_text != "" else week()))
	var styles: Array = Acts.MUSTER_TEAMS[team_id]["styles"]
	var names: Array = Acts.MUSTER_FIRST.duplicate()
	var out := []
	for i in mini(n, styles.size()):
		var st: String = styles[i]
		var sprite := ""
		for rid in Acts.RIVAL_ORDER:
			if Acts.RIVALS[rid]["style"] == st:
				sprite = Acts.RIVALS[rid]["sprite"]
		var first: String = names.pop_at(rng.randi_range(0, names.size() - 1))
		var nicks: Array = Acts.MUSTER_NICK[st]
		var name := "%s %s" % [first, nicks[rng.randi_range(0, nicks.size() - 1)]]
		out.append({"style": st, "sprite": sprite, "name": ("Сотник " + name) if i == 0 else name, "captain": i == 0})
	return out


static func gold_for(round_i: int, level: int) -> int:
	return int(Acts.MUSTER_GOLD[round_i]) * level


## Опис бою наступної сутички (для combat.enter через defense_loc): герць, але гурт на гурт.
static func battle_loc(world, player) -> Dictionary:
	var r := int(state(world)["round"])
	var team := next_team(world)
	var n := team_size(r, allies(world))
	var secs: float = float(Acts.MUSTER_SECONDS[r])
	return {"name": "Огляд: " + str(team["name"]), "type": "duel", "biome": "maidan", "level": player.level, "enemies": [],
		"round": r, "muster": true, "back": "До Чигирина", "team": fighters(str(team["id"]), n),
		"rival_hp": Power.dps(player) * secs, "rival_cap": 1.0 / (0.5 * secs),
		"rival_dmg": Power.hit(player, float(Acts.MUSTER_HIT[r]) * DuelService.hit_scale(player.level)),
		"captain_mult": float(Acts.MUSTER_CAPTAIN), "ally_hit": float(Acts.MUSTER_ALLY_HIT[r]), "desc": ""}


## Сутичку виграно: гривні, слава, лояльність Чигирина; після третьої — перемога в огляді й ладанка (уперше).
static func win(world, player) -> Array:
	var s := state(world)
	var r := int(s["round"])
	var msgs := []
	var g := gold_for(r, player.level)
	player.gold += g
	s["round"] = r + 1
	s["wins"] = int(s["wins"]) + 1
	world.add_loyalty(str(Acts.MUSTER_CITY), int(Acts.MUSTER_LOYALTY[r]))
	if r + 1 < ROUNDS:
		msgs.append("Сотню покладено! +%d грн, +%d слави" % [g, Acts.MUSTER_GLORY[r]])
	else:
		s["titles"] = int(s["titles"]) + 1
		var text := "Огляд за твоєю ватагою! +%d грн, +%d слави" % [g, Acts.MUSTER_GLORY[r]]
		if not s["prize"]:
			s["prize"] = true
			var it := prize(player.level)
			if not player.add_item(it):
				player.inventory.append(it)
			text += "\nГетьман вручає тобі оберіг: «%s»" % PRIZE_NAME
		else:
			player.resources["trophy"] = int(player.resources.get("trophy", 0)) + 3
			text += " і 3 трофеї"
		msgs.append(text)
	msgs.append_array(GloryService.add(world, player, int(Acts.MUSTER_GLORY[r])))
	return msgs


## Ватагу поклали: мінус спроба.
static func lose(world) -> String:
	var s := state(world)
	s["tries"] = maxi(0, int(s["tries"]) - 1)
	if int(s["tries"]) <= 0:
		return "Сотня взяла гору. Спроб цього тижня більше нема — приходь на наступний огляд."
	return "Сотня взяла гору. Лишилось спроб: %d." % int(s["tries"])


## Нагорода за перший виграний огляд: легендарний оберіг рівня героя з власною назвою.
static func prize(level: int) -> Dictionary:
	var it := Data.gen_item(maxi(1, level), 3, "amulet")
	it["name"] = PRIZE_NAME
	return it


static func days_to_reset() -> int:
	return DuelService.days_to_reset()
