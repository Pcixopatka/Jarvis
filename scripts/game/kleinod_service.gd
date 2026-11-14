extends RefCounted
## Клейноди роду: литаври, корогва, пернач, бунчук, булава, печатка й сурми.
## Довгі цілі для гривень, трофеїв і ресурсів, яким у пізній грі більше нема куди йти.
## Кожен клейнод має п'ять ступенів; ступінь купують на хуторі, і він назавжди додає бонус усім персонажам роду.
## Стан — world.camp["kleinody"] = {клейнод: ступінь} (хутір спільний для акаунта).
## Бонуси до показників героя йдуть через player.klein (див. player.recalc), слава й лояльність — через служби.

const Camp := preload("res://scripts/data/camp_data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
## Показники героя, які вміє клейнод (player.klein → Player.recalc); решту («glory», «loyalty») читають служби.
const HERO_STATS := ["xp", "dmg", "hp", "crit", "cd"]
const SERVICE_STATS := ["glory", "loyalty"]


## Куплені ступені. Читання нічого не створює: порожній хутір має лишатись порожнім, доки CampService його не заповнить.
static func levels(world) -> Dictionary:
	return world.camp.get("kleinody", {})


static func max_level() -> int:
	return Camp.kleinod_tiers()


static func level(world, id: String) -> int:
	return clampi(int(levels(world).get(id, 0)), 0, max_level())


## Скільки ступенів куплено разом.
static func total(world) -> int:
	var n := 0
	for id in GameDB.ids("kleinody"):
		n += level(world, id)
	return n


## Ціна наступного ступеня: {"gold", "trophy", "<ресурс>"} або {} — клейнод уже досконалий.
static func cost(world, id: String) -> Dictionary:
	var l := level(world, id)
	if l >= max_level():
		return {}
	var T := Camp.kleinod_tier(l)
	return {"gold": int(T["gold"]), Camp.TROPHY: int(T["trophy"]), str(GameDB.row("kleinody", id)["res"]): int(T["res"])}


static func can_buy(world, player, id: String) -> bool:
	var c := cost(world, id)
	if c.is_empty() or player.gold < int(c["gold"]):
		return false
	for r in c:
		if r != "gold" and int(player.resources.get(r, 0)) < int(c[r]):
			return false
	return true


static func buy(world, player, id: String) -> bool:
	if not can_buy(world, player, id):
		return false
	var c := cost(world, id)
	player.gold -= int(c["gold"])
	for r in c:
		if r != "gold":
			player.resources[r] = int(player.resources.get(r, 0)) - int(c[r])
	var camp: Dictionary = load("res://scripts/game/camp_service.gd").state(world)  # хутір сам заповнює свої поля
	if not camp.has("kleinody"):
		camp["kleinody"] = {}
	camp["kleinody"][id] = level(world, id) + 1
	apply(world, player)
	return true


## Сума бонусів за показником (частка): усі клейноди з таким stat.
static func bonus(world, stat: String) -> float:
	var v := 0.0
	for id in GameDB.ids("kleinody"):
		var K: Dictionary = GameDB.row("kleinody", id)
		if K["stat"] == stat:
			v += float(K["per"]) * level(world, id)
	return v


## Надбавки до показників героя (player.klein).
static func player_mods(world) -> Dictionary:
	var out := {}
	for stat in HERO_STATS:
		var v := bonus(world, stat)
		if v > 0.0:
			out[stat] = v
	return out


## Перенести бонуси клейнодів на героя (після купівлі, завантаження, зміни персонажа).
static func apply(world, player) -> void:
	var mods := player_mods(world)
	if mods != player.klein:
		var part: float = player.hp / maxf(1.0, player.max_hp)
		player.klein = mods
		player.recalc()
		player.hp = minf(player.max_hp, player.max_hp * part)


## Бонус словами для ступеня lvl: «+12% досвіду».
static func bonus_text(id: String, lvl: int) -> String:
	var K: Dictionary = GameDB.row("kleinody", id)
	return str(K["text"]) % roundi(float(K["per"]) * lvl * 100.0)


static func cost_text(c: Dictionary) -> String:
	var UI = load("res://scripts/ui/ui_kit.gd")
	var parts := ["%s грн" % UI.num(int(c.get("gold", 0)))]
	for r in c:
		if r != "gold":
			parts.append("%s %s" % [Camp.res_name(r).to_lower(), UI.num(int(c[r]))])
	return ", ".join(parts)

