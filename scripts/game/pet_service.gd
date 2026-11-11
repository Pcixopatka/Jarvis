extends RefCounted
## Улюбленці: купівля, годування й вибір супутника. Стан роду — world.camp["pets"] = {id: ступінь},
## узятий із собою записано в героя (player.pet). Хист улюбленця лягає в player.pet_fx (CampService.apply_effects).

const Pets := preload("res://scripts/data/pets.gd")
const Camp := preload("res://scripts/data/camp_data.gd")


static func state(world) -> Dictionary:
	if not world.camp.has("pets"):
		world.camp["pets"] = {}
	return world.camp["pets"]


static func level(world, id: String) -> int:
	return int(state(world).get(id, 0))


static func owned(world, id: String) -> bool:
	return level(world, id) > 0


static func owned_count(world) -> int:
	var n := 0
	for id in Pets.ORDER:
		if owned(world, id):
			n += 1
	return n


## Ціна наступного ступеня ({} — уже найвищий).
static func next_cost(world, id: String) -> Dictionary:
	var lvl := level(world, id)
	return {} if lvl >= Pets.MAX_LEVEL else Pets.cost(id, lvl + 1)


static func can_pay(player, cost: Dictionary) -> bool:
	if cost.is_empty() or int(player.gold) < int(cost["gold"]):
		return false
	for r in cost:
		if r != "gold" and int(player.resources.get(r, 0)) < int(cost[r]):
			return false
	return true


static func cost_text(cost: Dictionary) -> String:
	var parts := ["%d грн" % int(cost["gold"])]
	for r in Camp.RESOURCES:
		if int(cost.get(r, 0)) > 0:
			parts.append("%s %d" % [Camp.RESOURCES[r], int(cost[r])])
	if int(cost.get(Camp.TROPHY, 0)) > 0:
		parts.append("Трофеї %d" % int(cost[Camp.TROPHY]))
	return ", ".join(parts)


## Купити улюбленця або нагодувати до наступного ступеня. Куплений одразу йде з героєм, якщо той ще сам.
static func upgrade(world, player, id: String) -> bool:
	var cost := next_cost(world, id)
	if not Pets.DEFS.has(id) or not can_pay(player, cost):
		return false
	player.gold -= int(cost["gold"])
	for r in cost:
		if r != "gold":
			player.resources[r] = int(player.resources.get(r, 0)) - int(cost[r])
	state(world)[id] = level(world, id) + 1
	if str(player.pet) == "":
		player.pet = id
	apply(world, player)
	return true


## Узяти улюбленця з собою ("" — лишити всіх удома).
static func choose(world, player, id: String) -> bool:
	if id != "" and not owned(world, id):
		return false
	player.pet = id
	apply(world, player)
	return true


## Хист узятого улюбленця: {"pickup"|"travel"|"xp"|"res": частка}. Порожньо, якщо герой сам.
static func fx(world, player) -> Dictionary:
	var id: String = str(player.pet)
	if id == "" or not owned(world, id):
		return {}
	return {str(Pets.DEFS[id]["stat"]): Pets.value(id, level(world, id))}


static func apply(world, player) -> void:
	if str(player.pet) != "" and not owned(world, str(player.pet)):
		player.pet = ""
	player.pet_fx = fx(world, player)
	player.recalc()


static func travel_mult(player) -> float:
	return 1.0 + float(player.pet_fx.get("travel", 0.0))
