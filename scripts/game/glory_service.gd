extends RefCounted
## Слава героя: world.glory (число). Ранги й нагороди — Activities.GLORY_RANKS.

const Acts := preload("res://scripts/data/activities.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const HolidayService := preload("res://scripts/game/holiday_service.gd")


static func glory(world) -> int:
	return int(world.glory)


static func rank_index(value: int) -> int:
	var r := 0
	for i in Acts.GLORY_RANKS.size():
		if value >= int(Acts.GLORY_RANKS[i][0]):
			r = i
	return r


static func rank_name(world) -> String:
	return Acts.GLORY_RANKS[rank_index(glory(world))][1]


## Скільки слави до наступного рангу (0 — найвищий).
static func to_next(world) -> int:
	var r := rank_index(glory(world))
	if r >= Acts.GLORY_RANKS.size() - 1:
		return 0
	return int(Acts.GLORY_RANKS[r + 1][0]) - glory(world)


## Додати славу (на Покрову — вдвічі). Повертає повідомлення про нові ранги (з нагородами).
static func add(world, player, amount: int) -> Array:
	var kleinod: float = load("res://scripts/game/kleinod_service.gd").bonus(world, "glory")  # корогва роду
	return add_plain(world, player, int(round(amount * (1.0 + HolidayService.bonus("glory") + kleinod))))


## Додати славу без святкових надбавок.
static func add_plain(world, player, amount: int) -> Array:
	var msgs := []
	if amount <= 0:
		return msgs
	var before := rank_index(glory(world))
	world.glory = glory(world) + amount
	var after := rank_index(glory(world))
	for r in range(before + 1, after + 1):
		var info: Array = Acts.GLORY_RANKS[r]
		player.gold += int(info[2])
		var extra := ""
		if str(info[3]) != "":
			StoneService.grant(player, info[3])
			extra = " і %s" % StoneService.NAMES[info[3]]
		msgs.append("Слава росте: тепер ти — %s! +%d грн%s" % [info[1], info[2], extra])
	return msgs
