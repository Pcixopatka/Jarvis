extends RefCounted
## Супровід: завдання міста «проведи мандрівника» через дику місцевість.
## Завдання типу "escort" лежить серед звичайних (world.quests): target — хто йде, loc — куди вести.
## Бій — оборона з рухомою «брамою»: мандрівник сам іде ареною знизу вгору, на шляху три засідки.
## Поки нечисть поруч, він стоїть. Дійшов — завдання виконано, нагорода чекає в місті.
## Не вберіг — мандрівник тікає назад, завдання лишається, можна спробувати ще раз.

const Data := preload("res://scripts/data/data.gd")
const Acts := preload("res://scripts/data/activities.gd")


## Хто йде (запис з Acts.ESCORT_WHO).
static func who(q: Dictionary) -> Dictionary:
	return Acts.ESCORT_WHO.get(str(q.get("target", "")), Acts.ESCORT_WHO[Acts.ESCORT_ORDER[0]])


## Чи це невиконане завдання на супровід.
static func is_open(q: Dictionary) -> bool:
	return str(q.get("type", "")) == "escort" and int(q["progress"]) < int(q["count"])


## Узяте й ще не виконане завдання на супровід у цій місцевості (або порожній словник).
static func at(world, loc_id: String) -> Dictionary:
	for q in world.quests:
		if is_open(q) and q["loc"] == loc_id:
			return q
	return {}


## Нове завдання для дошки міста: доповнює заготовку q (id, city, loc, progress, lvl).
static func fill(q: Dictionary, roll: float) -> void:
	var order: Array = Acts.ESCORT_ORDER
	var id: String = order[clampi(int(roll * order.size()), 0, order.size() - 1)]
	q["type"] = "escort"
	q["target"] = id
	q["count"] = 1
	q["text"] = "Проведи %s (%s)" % [Acts.ESCORT_WHO[id]["acc"], Data.LOCATIONS[q["loc"]]["name"]]


static func hp(level: int) -> float:
	return Acts.ESCORT_HP + Acts.ESCORT_HP_LVL * level


## Опис бою для Combat.enter_defense.
## player — хто веде: нечисть підтягується до його рівня й сили (без нього — за рівнем місця, для довідок).
static func battle_loc(q: Dictionary, player = null) -> Dictionary:
	var L: Dictionary = Data.LOCATIONS[q["loc"]]
	var lvl := maxi(int(L["level"]), int(q.get("lvl", 0)) if L.get("scale", false) else 0)  # у далеких краях — за рівнем героя на час завдання
	var lift := {}
	var Far = load("res://scripts/game/far_service.gd")
	if player != null:
		lvl = maxi(lvl, int(player.level) - 1)
		lift = Far.event_mods(player)
	var guard: float = Far.guard_mult(lvl)  # мандрівник міцніший на стільки ж, на скільки лютіша нечисть
	var biome: String = L["biome"]
	if biome in ["cave", "plague"]:
		biome = "steppe"
	var w := who(q)
	var out := {"name": "Супровід: %s" % str(w["name"]).to_lower(), "type": "defense", "biome": biome, "level": lvl,
		"enemies": L["enemies"], "waves": Acts.ESCORT_WAVES, "target": q["loc"], "camp": false, "variant": "escort",
		"escort": int(q["id"]), "who": str(q["target"]), "gate_hp": hp(lvl) * guard, "desc": ""}
	out.merge(lift)
	return out


## Дієслово минулого часу за родом мандрівника: «дійшов» чи «дійшла».
static func verb(w: Dictionary, he: String, she: String) -> String:
	return she if w.get("she", false) else he


## Мандрівник дійшов: завдання виконано. part — частка його здоров'я (вдячність гривнями).
static func win(world, player, qid: int, part: float) -> String:
	for q in world.quests:
		if int(q["id"]) != qid or not is_open(q):
			continue
		q["progress"] = q["count"]
		var w := who(q)
		var tip := int(round(Acts.ESCORT_TIP * int(q["lvl"]) * clampf(part, 0.0, 1.0)))
		var text := "%s %s!\n«%s»" % [w["name"], verb(w, "дійшов", "дійшла"), w["thanks"]]
		if tip > 0:
			player.gold += tip
			text += "\n+%d грн на дорогу" % tip
		return text + "\nНагорода чекає: %s" % Data.place_name(q["city"])
	return "Мандрівник дійшов."


## Мандрівника не вберегли: він тікає назад, завдання лишається.
static func lose(world, qid: int) -> String:
	for q in world.quests:
		if int(q["id"]) == qid and is_open(q):
			var w := who(q)
			return "%s ледве %s назад.\nЗавдання лишилось — спробуй ще раз." % [w["name"], verb(w, "втік", "втекла")]
	return "Мандрівника не вберегли."
