extends RefCounted
## Бос дня й бос тижня. Щодня й щотижня до героя виходить один із відомих босів: той самий для всіх
## гравців, бо його обирає дата. Рівнем він дорівнює героєві, тож не буває ні заслабким, ні задужим.
## Щоразу в нього інші властивості (data/boss_mods.json): одна в боса дня, дві в боса тижня.
## Перемогти кожного можна раз на період. Поразка спроби не забирає, але ціна смерті звичайна.
## Стан у героя свій, world.boss_hunt: {"day": ключ дня, "day_done": чи переможено, "week": ключ тижня,
## "week_done", "day_wins": перемог за весь час, "week_wins", "best": {бос: найкращий час у секундах}}.
## Сам бій це печера на одну кімнату (Combat._spawn_room): бос із почтом із рідного лігва.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const LootService := preload("res://scripts/game/loot_service.gd")

## Боси дня й тижня, які вміє цей код (ключі періоду, нагорода): у data/boss_hunts.json мусять бути саме вони.
## Запис каже назви, з якого рівня, множники сили, скільки властивостей і нагороду: гривні за рівень героя,
## трофеї, частку досвіду поточного рівня й рідкість речі.
const KINDS := ["day", "week"]
## Поля властивості боса (boss_mods.json), що множаться, а не замінюються.
const MULT_KEYS := ["boss_dmg_mult", "boss_hp_mult", "boss_speed_mult", "minions"]
static var WEEK_ITEMS: int  # легендарних речей із боса тижня (і ще золота)


## Числа-правила вище лежать у data/settings.json (запис «events»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("events")
	WEEK_ITEMS = S["boss_week_items"]


## Запис боса дня чи тижня (boss_hunts.json).
static func hunt(kind: String) -> Dictionary:
	return GameDB.row("boss_hunts", kind)


## Хто може вийти (пул «hunt» у boss_pools.json). Надважких босів тут нема: їх зустрічають лише у власних печерах.
static func pool() -> Array:
	return GameDB.row("boss_pools", "hunt").get("bosses", [])


## Властивість боса (boss_mods.json): назва, опис і поля, що лягають в опис бою.
static func mod(id: String) -> Dictionary:
	return GameDB.row("boss_mods", id)


static func key(kind: String) -> String:
	var t := ChallengeService._now()
	return ChallengeService.week_key(t) if kind == "week" else ChallengeService.day_key(t)


static func state(world) -> Dictionary:
	var s: Dictionary = world.boss_hunt
	for kind in KINDS:
		if str(s.get(kind, "")) != key(kind):
			s[kind] = key(kind)
			s[kind + "_done"] = false
		if not s.has(kind + "_wins"):
			s[kind + "_wins"] = 0
	if not s.has("best"):
		s["best"] = {}
	return s


## Бос цього періоду: один для всіх, обраний датою. Бос тижня не збігається з босом дня.
static func boss_id(kind: String, period_key: String = "") -> String:
	var k: String = period_key if period_key != "" else key(kind)
	var bosses := pool()
	var i: int = absi(hash(kind + ":" + k)) % bosses.size()
	# Поступається бос дня: бос тижня той самий увесь тиждень. Раніше зсувався бос тижня,
	# і серед тижня він раптом мінявся на іншого.
	if kind == "day" and period_key == "" and bosses[i] == boss_id("week"):
		i = (i + 1) % bosses.size()
	return bosses[i]


## Властивості боса цього періоду (id з boss_mods.json).
static func mods(kind: String, period_key: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mods:" + kind + ":" + (period_key if period_key != "" else key(kind)))
	var ids: Array = GameDB.ids("boss_mods").duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	return ids.slice(0, int(hunt(kind)["mods"]))


static func mod_names(kind: String) -> Array:
	var out := []
	for m in mods(kind):
		out.append(str(mod(m)["name"]))
	return out


## Рідне лігво боса: звідти беруться прислужники й вигляд арени.
static func home_of(boss: String) -> Dictionary:
	for id in Data.place_ids():
		var L: Dictionary = Data.place(id)
		if str(L.get("boss", "")) == boss and not L.get("endless", false) and not L.has("peril"):
			return L
	return Data.place("hlybyny")


static func done(world, kind: String) -> bool:
	return bool(state(world)[kind + "_done"])


## Чому зараз не можна вийти на боса ("" — можна).
static func block_reason(world, player, kind: String) -> String:
	if player.is_peasant():
		return "спершу обери дорогу"
	if int(player.level) < int(hunt(kind)["min_level"]):
		return "з %d-го рівня героя" % int(hunt(kind)["min_level"])
	if done(world, kind):
		return "уже переможено, новий буде %s" % hunt(kind)["next"]
	return ""


static func available(world, player) -> int:
	var n := 0
	for kind in KINDS:
		if block_reason(world, player, kind) == "":
			n += 1
	return n


## Опис бою (як місце в data/places.json): печера на одну кімнату, бос рівня героя.
static func loc_for(player, kind: String) -> Dictionary:
	var boss := boss_id(kind)
	var home := home_of(boss)
	var H := hunt(kind)
	var loc := {"name": "%s: %s" % [H["name"], GameDB.boss_name(boss)], "type": "dungeon", "biome": str(home.get("biome", "cave")),
		"level": int(player.level), "rooms": 1, "enemies": home["enemies"], "boss": boss, "hunt": kind,
		"boss_hp_mult": float(H["hp_mult"]), "boss_dmg_mult": float(H["dmg_mult"]), "desc": ""}
	for m in mods(kind):
		var M: Dictionary = mod(m)
		for f in M:
			if f in ["num", "name", "desc"]:
				continue
			if f in MULT_KEYS:
				loc[f] = float(loc.get(f, 1.0)) * float(M[f])
			else:
				loc[f] = M[f]
	return loc


static func gold_for(kind: String, level: int) -> int:
	return int(hunt(kind)["gold"]) * level


## Рядки нагороди для екрана босів.
static func reward_lines(player, kind: String) -> Array:
	var out := ["%d грн, %d трофеїв і %d%% досвіду рівня" % [gold_for(kind, int(player.level)), int(hunt(kind)["trophies"]), roundi(float(hunt(kind)["xp_part"]) * 100.0)]]
	if kind == "week":
		out.append("%d легендарні речі твого рівня й золота річ напевно" % WEEK_ITEMS)
	else:
		out.append("легендарна річ твого рівня")
	out.append("звичайна здобич боса: шанс на золоту річ, трофей-артефакт і душу")
	return out


## Перемога: позначити період, видати гривні, трофеї й досвід. Повертає {"msgs": рядки для банера,
## "items": речі, що мають упасти біля героя, "record": чи побито власний час}.
## boss — кого саме здолано. Бій міг початися до півночі, а скінчитися після: рекорд часу пишеться
## тому босові, з яким бились, а не тому, що вийшов уже в новій добі.
static func on_win(world, player, kind: String, seconds: float, boss: String = "") -> Dictionary:
	var s := state(world)
	if boss == "":
		boss = boss_id(kind)
	s[kind + "_done"] = true
	s[kind + "_wins"] = int(s[kind + "_wins"]) + 1
	var t: int = maxi(1, int(seconds))
	var old: int = int(s["best"].get(boss, 0))
	var record: bool = old == 0 or t < old
	if record:
		s["best"][boss] = t
	var gold := gold_for(kind, int(player.level))
	player.add_gold(gold)
	var H := hunt(kind)
	player.resources["trophy"] = int(player.resources.get("trophy", 0)) + int(H["trophies"])
	var xp: int = int(float(player.xp_next) * float(H["xp_part"]))
	player.add_xp(xp)
	var items := []
	for i in (WEEK_ITEMS if kind == "week" else 1):
		items.append(Data.gen_item(int(player.level), int(H["item_rarity"])))
	if kind == "week":
		var uid := LootService.pick(player, weekly_tier(int(player.level)), boss)
		if uid != "":
			items.append(Uniques.make(uid, int(player.level)))
	var msgs := ["%s переможено за %d:%02d%s" % [H["name"], t / 60, t % 60, " — твій найкращий час" if record and old > 0 else ""],
		"+%d грн, +%d трофеїв, +%d досвіду" % [gold, int(H["trophies"]), xp],
		"Наступний вийде %s" % H["next"]]
	return {"msgs": msgs, "items": items, "record": record}


## Ступінь золотої речі боса тижня: той, що дають боси рівня героя (Uniques.hero_tier); шостий лишається
## надважким печерам.
static func weekly_tier(level: int) -> int:
	return Uniques.hero_tier(level)


static func best_time(world, boss: String) -> int:
	return int(state(world)["best"].get(boss, 0))


static func time_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60] if seconds > 0 else "—"
