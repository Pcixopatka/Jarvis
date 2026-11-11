extends RefCounted
## Надважкі печери: правила входу, поступ, табір біля входу, звання й рекорди (дані — у Peril).
## Стан героя — world.peril: {"cleared": {печера: скільки разів}, "best": {печера: секунд}, "titles": [бос, ...]}.
## Найкращий час роду — world.records["peril_time:<печера>"] (менше — краще, тож не через RecordService).

const Data := preload("res://scripts/data/data.gd")
const Peril := preload("res://scripts/data/peril.gd")
const Valor := preload("res://scripts/data/valor.gd")

static var _ids := []


static func is_peril(loc_id: String) -> bool:
	return Data.LOCATIONS.has(loc_id) and Data.LOCATIONS[loc_id].has("peril")


## Печери за порядком відкриття.
static func ids() -> Array:
	if _ids.is_empty():
		for id in Data.LOCATIONS:
			if Data.LOCATIONS[id].has("peril"):
				_ids.append(id)
		_ids.sort_custom(func(a, b): return int(Data.LOCATIONS[a]["peril"]) < int(Data.LOCATIONS[b]["peril"]))
	return _ids


static func state(world) -> Dictionary:
	if world.peril.is_empty():
		world.peril = {"cleared": {}, "best": {}, "titles": []}
	return world.peril


static func cleared(world, loc_id: String) -> int:
	return int(state(world)["cleared"].get(loc_id, 0))


## Скільки різних надважких босів уже здолав цей герой.
static func bosses_down(world) -> int:
	var n := 0
	for id in ids():
		if cleared(world, id) > 0:
			n += 1
	return n


## Печера, яку треба пройти перед цією ("" — це перша).
static func previous(loc_id: String) -> String:
	var order := ids()
	var i := order.find(loc_id)
	return str(order[i - 1]) if i > 0 else ""


static func land_name(loc_id: String) -> String:
	return str(Peril.LANDS.get(str(Data.LOCATIONS[loc_id].get("land", "")), {}).get("name", ""))


## Чому зараз не пускають ("" — пускають).
static func block_reason(world, player, loc_id: String) -> String:
	if not is_peril(loc_id):
		return ""
	if int(player.level) < Peril.OPEN_LEVEL:
		return "Сюди пускають із %d-го рівня героя" % Peril.OPEN_LEVEL
	var prev := previous(loc_id)
	if prev != "" and cleared(world, prev) <= 0:
		return "Спершу здолай печеру «%s»" % str(Data.LOCATIONS[prev]["name"])
	return ""


## Додатки до опису місця для бою: надважкий бос і його лють (див. Combat._spawn_room, Enemy._tick_enrage).
static func combat_mods(loc_id: String) -> Dictionary:
	if not is_peril(loc_id):
		return {}
	return {"hp_mult": hp_mult(loc_id), "dmg_mult": dmg_mult(loc_id), "xp_mult": Peril.XP_MULT,
		"boss_hp_mult": Peril.BOSS_HP_MULT, "boss_dmg_mult": Peril.BOSS_DMG_MULT, "enrage_after": Peril.ENRAGE_AFTER}


## Номер печери за порядком відкриття: 1..5 (0 — не надважка).
static func number(loc_id: String) -> int:
	return int(Data.LOCATIONS[loc_id].get("peril", 0)) if Data.LOCATIONS.has(loc_id) else 0


## У скільки разів нечисть цієї печери міцніша за звичайну свого рівня.
static func hp_mult(loc_id: String) -> float:
	return Peril.HP_MULT * (1.0 + Peril.HP_STEP * maxi(0, number(loc_id) - 1))


## У скільки разів вона б'є сильніше.
static func dmg_mult(loc_id: String) -> float:
	return Peril.DMG_MULT * (1.0 + Peril.DMG_STEP * maxi(0, number(loc_id) - 1))


static func time_text(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]


static func best_time(world, loc_id: String) -> float:
	return float(state(world)["best"].get(loc_id, 0.0))


## Найкращий час роду: {"value": секунд, "who": хто, "slot"} або порожньо.
static func family_best(world, loc_id: String) -> Dictionary:
	return world.records.get("peril_time:" + loc_id, {})


static func titles(world) -> Array:
	return state(world)["titles"]


## Найвище звання героя: за боса найдальшої з пройдених печер ("" — жодного).
static func title(world) -> String:
	var out := ""
	for id in ids():
		var boss := str(Data.LOCATIONS[id]["boss"])
		if boss in titles(world):
			out = str(Peril.TITLES.get(boss, ""))
	return out


## Сума бонусів іменних звитяг цього героя: {ключ: відсотки}.
static func title_fx(world) -> Dictionary:
	var out := {}
	for boss in titles(world):
		var F: Dictionary = Peril.TITLE_FX.get(str(boss), {})
		for k in F:
			out[k] = float(out.get(k, 0.0)) + float(F[k])
	return out


## Передати героєві бонуси його іменних звитяг (після завантаження й після нового звання).
static func apply(world, player) -> void:
	var fx := title_fx(world)
	if fx != player.title_fx:
		player.title_fx = fx
		player.recalc()


## Печеру пройдено за seconds секунд. Повертає повідомлення: звання, рекорди, що відкрилось далі.
static func on_clear(world, player, loc_id: String, seconds: float, slot: int = 0) -> Array:
	var msgs := []
	if not is_peril(loc_id):
		return msgs
	var s := state(world)
	var first: bool = cleared(world, loc_id) == 0
	s["cleared"][loc_id] = cleared(world, loc_id) + 1
	var boss := str(Data.LOCATIONS[loc_id]["boss"])
	if first:
		if Peril.TITLES.has(boss) and not boss in s["titles"]:
			s["titles"].append(boss)
			var bonus: String = Valor.fx_text(Peril.TITLE_FX.get(boss, {}))
			msgs.append("Іменна звитяга: %s%s" % [str(Peril.TITLES[boss]), (" (%s)" % bonus) if bonus != "" else ""])
			apply(world, player)
		var order := ids()
		var i := order.find(loc_id)
		if i >= 0 and i + 1 < order.size():
			msgs.append("Відкрито печеру «%s» (%s)" % [str(Data.LOCATIONS[order[i + 1]]["name"]), land_name(str(order[i + 1]))])
		else:
			msgs.append("Усі надважкі печери пройдено. Далі дороги нема")
	var old := best_time(world, loc_id)
	if seconds > 0.0 and (old <= 0.0 or seconds < old):
		s["best"][loc_id] = seconds
		msgs.append("Твій найкращий час: %s" % time_text(seconds))
	var fam: Dictionary = family_best(world, loc_id)
	if seconds > 0.0 and (fam.is_empty() or seconds < float(fam.get("value", 0.0))):
		var took: bool = not fam.is_empty() and int(fam.get("slot", slot)) != slot
		world.records["peril_time:" + loc_id] = {"value": seconds, "slot": slot, "who": "%s %d рівня" % [player.class_name_ua(), int(player.level)]}
		if took:
			msgs.append("Рекорд роду побито: %s (було %s, %s)" % [time_text(seconds), time_text(float(fam["value"])), str(fam.get("who", "?"))])
	return msgs


## Ціни маркітанта в таборі біля входу.
static func potion_price(player) -> int:
	return int(ceil(Data.potion_price(int(player.level)) * Peril.CAMP_POTION_MARKUP))


static func mana_potion_price(player) -> int:
	return int(ceil(Data.mana_potion_price(int(player.level)) * Peril.CAMP_POTION_MARKUP))
