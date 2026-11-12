extends RefCounted
## Логіка хутора без інтерфейсу. Стан — world.camp:
##   {"buildings": {id: рівень}, "pasika_ts": час останнього збору (unix)}
## Ресурси героя — player.resources {"wood", "iron", "herbs"}.

const Clock := preload("res://scripts/core/clock.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Data := preload("res://scripts/data/data.gd")
const StoryService := preload("res://scripts/game/story_service.gd")


static func state(world) -> Dictionary:
	# Заповнюємо наявний словник, а не підміняємо: хутір спільний на всіх персонажів (посилання з акаунта)
	if not world.camp.has("buildings"):
		world.camp["buildings"] = {}
		world.camp["pasika_ts"] = Clock.now()
	return world.camp


static func level(world, id: String) -> int:
	return int(state(world)["buildings"].get(id, 0))


## Скільки будівель уже стоїть на хуторі.
static func built_count(world) -> int:
	var n := 0
	for id in state(world)["buildings"]:
		if int(state(world)["buildings"][id]) > 0:
			n += 1
	return n


static func max_level(id: String) -> int:
	return Camp.BUILDINGS[id]["levels"].size()


## Ціна наступного рівня або {} якщо вже максимум.
static func next_cost(world, id: String) -> Dictionary:
	var l := level(world, id)
	if l >= max_level(id):
		return {}
	return Camp.BUILDINGS[id]["levels"][l]


static func can_afford(player, cost: Dictionary) -> bool:
	if cost.is_empty() or player.gold < int(cost["gold"]):
		return false
	for r in Camp.RESOURCES:
		if int(player.resources.get(r, 0)) < int(cost.get(r, 0)):
			return false
	return true


static func build(world, player, id: String) -> bool:
	var cost := next_cost(world, id)
	if not can_afford(player, cost):
		return false
	player.gold -= int(cost["gold"])
	for r in Camp.RESOURCES:
		player.resources[r] = int(player.resources.get(r, 0)) - int(cost.get(r, 0))
	state(world)["buildings"][id] = level(world, id) + 1
	if id == "pasika" and level(world, id) == 1:
		state(world)["pasika_ts"] = Clock.now()
	apply_effects(world, player)
	return true


# ---------- Що дають будівлі ----------

static func party_size(world) -> int:
	var k := level(world, "kurin")
	return Data.MAX_COMPANIONS + (2 if k >= 3 else (1 if k >= 1 else 0))


static func companion_xp_mult(world) -> float:
	return 1.5 if level(world, "kurin") >= 2 else 1.0


static func bag_bonus(world) -> int:
	return [0, 8, 16][level(world, "sklad")]


static func potion_bonus(world) -> int:
	return 2 if level(world, "zillia") >= 2 else 0


static func forge_cost_mult(world) -> float:
	return 0.8 if level(world, "kuznia") >= 1 else 1.0


static func forge_chance_bonus(world) -> float:
	return 0.1 if level(world, "kuznia") >= 3 else 0.0


## Застосовує пасивні бонуси будівель і наслідки сюжетних виборів до героя.
static func apply_effects(world, player) -> void:
	player.bag_bonus = bag_bonus(world) + load("res://scripts/game/premium_service.gd").bag_bonus(world)  # склад на хуторі й універсал
	player.potion_bonus = potion_bonus(world) + int(StoryService.effect(world, "potion_max"))
	player.plague_resist = clampf(StoryService.effect(world, "plague_resist"), 0.0, 0.9)
	load("res://scripts/game/costume_service.gd").check(world, player)  # вбрання, якого в роду нема, знімається
	var PetS = load("res://scripts/game/pet_service.gd")
	if str(player.pet) != "" and not PetS.owned(world, str(player.pet)):
		player.pet = ""
	player.pet_fx = PetS.fx(world, player)  # хист улюбленця, якого герой узяв із собою
	var DivS = load("res://scripts/game/divine_service.gd")
	for dslot in player.divine.keys():
		if not DivS.owned(world, str(player.divine[dslot])):
			player.divine.erase(dslot)  # дар, якого в роду нема, знімається
	player.divine_fx = DivS.fx_of(world, player)
	player.bag_divine = int(player.divine_fx["bag"])
	world.cart_divine = int(player.divine_fx["trade"])  # Чумацький віз: місткість воза в торзі
	player.recalc()  # крила, молот і хист улюбленця мають одразу лягти в показники
	load("res://scripts/game/kleinod_service.gd").apply(world, player)  # клейноди роду діють на кожного героя
	load("res://scripts/game/peril_service.gd").apply(world, player)  # іменні звитяги за надважких босів


# ---------- Пасіка ----------

static func pasika_rate(world, hero_level: int) -> float:
	var feast: float = 1.0 + load("res://scripts/game/holiday_service.gd").bonus("harvest")  # на Спаса меду більше
	return Camp.PASIKA_RATE[level(world, "pasika")] * (1.0 + 0.2 * (hero_level - 1)) * feast


static func pasika_ready(world, hero_level: int, now: float = -1.0) -> int:
	if level(world, "pasika") == 0:
		return 0
	if now < 0.0:
		now = Clock.now()
	var hours := clampf((now - float(state(world)["pasika_ts"])) / 3600.0, 0.0, Camp.PASIKA_CAP_HOURS)
	return int(hours * pasika_rate(world, hero_level))


static func collect_pasika(world, player, now: float = -1.0) -> int:
	var g := pasika_ready(world, player.level, now)
	if g > 0:
		player.gold += g
		state(world)["pasika_ts"] = now if now >= 0.0 else Clock.now()
	return g


# ---------- Зілляварня ----------

static func can_brew(world, player, recipe: String) -> bool:
	var r: Dictionary = Camp.BREW[recipe]
	if level(world, "zillia") < int(r["level"]):
		return false
	if int(player.resources.get("herbs", 0)) < int(r["herbs"]) or int(player.resources.get("iron", 0)) < int(r["iron"]):
		return false
	if recipe == "heal":
		return player.potions < player.potion_max()
	if recipe == "mana":
		return player.mana_potions < player.mana_potion_max()
	return player.buff_fits(recipe, Data.BREW_TIME)  # зілля «на час»: ще одна порція додає час, але не понад годину


static func brew(world, player, recipe: String) -> bool:
	if not can_brew(world, player, recipe):
		return false
	var r: Dictionary = Camp.BREW[recipe]
	player.resources["herbs"] -= int(r["herbs"])
	player.resources["iron"] -= int(r["iron"])
	if recipe == "heal":
		player.potions += 1
	elif recipe == "mana":
		player.mana_potions += 1
	else:
		player.add_buff(recipe, Data.BREW_TIME)
	return true


# ---------- Кузня: переплавка ----------

static func salvage_value(item: Dictionary) -> int:
	return 2 + int(item["ilvl"]) / 2 + 2 * int(item["rarity"]) + int(item["up"])


## Чи річ цінна: її переплавка просить другого дотику (заточена, рідкісна й вища, золота чи наборна,
## зачарована або з душею в гнізді). Незаточений звичайний і добротний мотлох плавиться з першого дотику.
static func salvage_precious(item: Dictionary) -> bool:
	return int(item.get("up", 0)) > 0 or int(item.get("rarity", 0)) >= 2 or Data.is_precious(item) \
		or str(item.get("ench", "")) != "" or str(item.get("soul", "")) != ""


static func salvage(world, player, uid: int) -> int:
	if level(world, "kuznia") < 2 or player.is_equipped(uid) or player.find_item(uid).has("artifact"):
		return 0  # артефакт не переплавляють
	var it: Dictionary = player.remove_from_bag(uid)
	if it.is_empty():
		return 0
	player.SoulService.strip(player, it)  # душа з переплавленої речі вертається в торбинку
	var v := salvage_value(it)
	player.resources["iron"] = int(player.resources.get("iron", 0)) + v
	return v
