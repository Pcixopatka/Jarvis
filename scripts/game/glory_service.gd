extends RefCounted
## Слава героя: world.glory (число). Ранги й нагороди — data/glory_ranks.json (Activities.glory_ranks).

const Acts := preload("res://scripts/data/activities.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const HolidayService := preload("res://scripts/game/holiday_service.gd")


static func glory(world) -> int:
	return int(world.glory)


static func rank_index(value: int) -> int:
	var r := 0
	var ranks := Acts.glory_ranks()
	for i in ranks.size():
		if value >= int(ranks[i]["from"]):
			r = i
	return r


static func rank_name(world) -> String:
	return Acts.glory_ranks()[rank_index(glory(world))]["name"]


## Скільки слави до наступного рангу (0 — найвищий).
static func to_next(world) -> int:
	var r := rank_index(glory(world))
	if r >= Acts.glory_ranks().size() - 1:
		return 0
	return int(Acts.glory_ranks()[r + 1]["from"]) - glory(world)


## Додати славу (на Покрову — вдвічі). Повертає повідомлення про нові ранги (з нагородами).
static func add(world, player, amount: int) -> Array:
	var kleinod: float = load("res://scripts/game/kleinod_service.gd").bonus(world, "glory")  # корогва роду
	return add_plain(world, player, int(round(amount * (1.0 + HolidayService.bonus("glory") + kleinod + float(player.art.get("glory", 0.0))))))


## Додати славу без святкових надбавок.
static func add_plain(world, player, amount: int) -> Array:
	var msgs := []
	if amount <= 0:
		return msgs
	var before := rank_index(glory(world))
	world.glory = glory(world) + amount
	var after := rank_index(glory(world))
	for r in range(before + 1, after + 1):
		var info: Dictionary = Acts.glory_ranks()[r]
		player.gold += int(info["gold"])
		var extra := ""
		if str(info.get("stone", "")) != "":
			StoneService.grant(player, info["stone"])
			extra = " і %s" % StoneService.name_of(info["stone"])
		msgs.append("Слава росте: тепер ти — %s! +%d грн%s" % [info["name"], info["gold"], extra])
	return msgs
