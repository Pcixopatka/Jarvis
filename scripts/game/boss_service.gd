extends RefCounted
## Бос дня й бос тижня. Щодня й щотижня до героя виходить один із відомих босів: той самий для всіх
## гравців, бо його обирає дата. Рівнем він дорівнює героєві, тож не буває ні заслабким, ні задужим.
## Щоразу в нього інші властивості (MODS): одна в боса дня, дві в боса тижня.
## Перемогти кожного можна раз на період. Поразка спроби не забирає, але ціна смерті звичайна.
## Стан у героя свій, world.boss_hunt: {"day": ключ дня, "day_done": чи переможено, "week": ключ тижня,
## "week_done", "day_wins": перемог за весь час, "week_wins", "best": {бос: найкращий час у секундах}}.
## Сам бій це печера на одну кімнату (Combat._spawn_room): бос із почтом із рідного лігва.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const LootService := preload("res://scripts/game/loot_service.gd")

const KINDS := ["day", "week"]
const NAMES := {"day": "Бос дня", "week": "Бос тижня"}
const PERIOD := {"day": "сьогодні", "week": "цього тижня"}
const NEXT := {"day": "завтра", "week": "наступного тижня"}
const MIN_LEVEL := {"day": 12, "week": 30}
## Хто може вийти. Надважких босів тут нема: їх зустрічають лише у власних печерах.
const POOL := ["zmii", "upyr", "vovkulaka", "chaklun", "koshchii", "putinoid", "baba_yaha", "solovei", "lykho", "oprychnyk",
	"vidma", "vii", "morskyi_tsar", "shubin", "bila_pani", "pushkar", "lisovyi_did", "idolyshche"]
const HP_MULT := {"day": 1.6, "week": 3.2}
const DMG_MULT := {"day": 1.0, "week": 1.2}
const MOD_COUNT := {"day": 1, "week": 2}
## Властивості боса. Поля, крім name і desc, лягають в опис бою: множники перемножуються, решта замінюється.
const MODS := {
	"liutyi": {"name": "Лютий", "desc": "б'є на 25% сильніше", "boss_dmg_mult": 1.25},
	"tovstyi": {"name": "Товстошкурий", "desc": "має на 40% більше здоров'я", "boss_hp_mult": 1.4},
	"pochet": {"name": "Із почтом", "desc": "прислужників удвічі більше, серед них більше еліт", "minions": 2.0, "elite_bonus": 0.2},
	"nichnyi": {"name": "Нічний", "desc": "бій іде вночі: навколо темно", "night": true},
	"skazhenyi": {"name": "Скажений", "desc": "за хвилину бою лютішає й б'є щораз сильніше", "enrage_after": 60.0},
	"prudkyi": {"name": "Прудкий", "desc": "рухається на 30% швидше", "boss_speed_mult": 1.3},
}
const MOD_ORDER := ["liutyi", "tovstyi", "pochet", "nichnyi", "skazhenyi", "prudkyi"]
const MULT_KEYS := ["boss_dmg_mult", "boss_hp_mult", "boss_speed_mult", "minions"]
## Нагорода: гривні за рівень героя, трофеї, частка досвіду поточного рівня й річ.
const GOLD_PER_LEVEL := {"day": 300, "week": 1500}
const TROPHIES := {"day": 5, "week": 20}
const XP_PART := {"day": 0.08, "week": 0.3}
const ITEM_RARITY := {"day": 3, "week": 3}
const WEEK_ITEMS := 2  # бос тижня дає дві легендарні речі й золоту


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
	var i: int = absi(hash(kind + ":" + k)) % POOL.size()
	# Поступається бос дня: бос тижня той самий увесь тиждень. Раніше зсувався бос тижня,
	# і серед тижня він раптом мінявся на іншого.
	if kind == "day" and period_key == "" and POOL[i] == boss_id("week"):
		i = (i + 1) % POOL.size()
	return POOL[i]


## Властивості боса цього періоду (id з MODS).
static func mods(kind: String, period_key: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mods:" + kind + ":" + (period_key if period_key != "" else key(kind)))
	var ids: Array = MOD_ORDER.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	return ids.slice(0, int(MOD_COUNT[kind]))


static func mod_names(kind: String) -> Array:
	var out := []
	for m in mods(kind):
		out.append(str(MODS[m]["name"]))
	return out


## Рідне лігво боса: звідти беруться прислужники й вигляд арени.
static func home_of(boss: String) -> Dictionary:
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		if str(L.get("boss", "")) == boss and not L.get("endless", false) and not L.has("peril"):
			return L
	return Data.LOCATIONS["hlybyny"]


static func done(world, kind: String) -> bool:
	return bool(state(world)[kind + "_done"])


## Чому зараз не можна вийти на боса ("" — можна).
static func block_reason(world, player, kind: String) -> String:
	if player.is_peasant():
		return "спершу обери дорогу"
	if int(player.level) < int(MIN_LEVEL[kind]):
		return "з %d-го рівня героя" % int(MIN_LEVEL[kind])
	if done(world, kind):
		return "уже переможено, новий буде %s" % NEXT[kind]
	return ""


static func available(world, player) -> int:
	var n := 0
	for kind in KINDS:
		if block_reason(world, player, kind) == "":
			n += 1
	return n


## Опис бою (як місцевість у Data.LOCATIONS): печера на одну кімнату, бос рівня героя.
static func loc_for(player, kind: String) -> Dictionary:
	var boss := boss_id(kind)
	var home := home_of(boss)
	var loc := {"name": "%s: %s" % [NAMES[kind], GameDB.boss_name(boss)], "type": "dungeon", "biome": str(home.get("biome", "cave")),
		"level": int(player.level), "rooms": 1, "enemies": home["enemies"], "boss": boss, "hunt": kind,
		"boss_hp_mult": float(HP_MULT[kind]), "boss_dmg_mult": float(DMG_MULT[kind]), "desc": ""}
	for m in mods(kind):
		var M: Dictionary = MODS[m]
		for f in M:
			if f in ["name", "desc"]:
				continue
			if f in MULT_KEYS:
				loc[f] = float(loc.get(f, 1.0)) * float(M[f])
			else:
				loc[f] = M[f]
	return loc


static func gold_for(kind: String, level: int) -> int:
	return int(GOLD_PER_LEVEL[kind]) * level


## Рядки нагороди для екрана босів.
static func reward_lines(player, kind: String) -> Array:
	var out := ["%d грн, %d трофеїв і %d%% досвіду рівня" % [gold_for(kind, int(player.level)), int(TROPHIES[kind]), roundi(float(XP_PART[kind]) * 100.0)]]
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
	player.resources["trophy"] = int(player.resources.get("trophy", 0)) + int(TROPHIES[kind])
	var xp: int = int(float(player.xp_next) * float(XP_PART[kind]))
	player.add_xp(xp)
	var items := []
	for i in (WEEK_ITEMS if kind == "week" else 1):
		items.append(Data.gen_item(int(player.level), int(ITEM_RARITY[kind])))
	if kind == "week":
		var uid := LootService.pick(player, weekly_tier(int(player.level)), boss)
		if uid != "":
			items.append(Uniques.make(uid, int(player.level)))
	var msgs := ["%s переможено за %d:%02d%s" % [NAMES[kind], t / 60, t % 60, " — твій найкращий час" if record and old > 0 else ""],
		"+%d грн, +%d трофеїв, +%d досвіду" % [gold, int(TROPHIES[kind]), xp],
		"Наступний вийде %s" % NEXT[kind]]
	return {"msgs": msgs, "items": items, "record": record}


## Ступінь золотої речі боса тижня: росте з рівнем героя, шостий лишається надважким печерам.
static func weekly_tier(level: int) -> int:
	return clampi(1 + level / 20, 1, Uniques.TOP_COMMON_TIER)


static func best_time(world, boss: String) -> int:
	return int(state(world)["best"].get(boss, 0))


static func time_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60] if seconds > 0 else "—"
