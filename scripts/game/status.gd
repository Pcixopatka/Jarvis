extends RefCounted
## Стани й ефекти для козака і нечисті. Стан зберігається на сутності:
##   statuses = {id: {"t": скільки лишилось, "dps": шкода за секунду, "tick": до наступного удару}}
## Шкода від станів б'є раз на пів секунди (щоб не засипати екран цифрами).
## Назва, колір і опис кожного стану — у data/statuses.json; що стан робить — тут (chill повільніший,
## plague — лікування вдвічі слабше, weak б'є слабше) і в Enemy (curse — отримує більше шкоди).

const GameDB := preload("res://scripts/core/game_db.gd")
const TICK := 0.5
## Чий колір бере підсвітка, коли станів кілька (перший знайдений). Тут мусять бути всі стани з
## data/statuses.json, а в таблиці — всі стани, що тут (перевіряє GameDB.problems()).
const TINT_ORDER := ["burn", "plague", "bleed", "chill", "weak", "curse"]


## Запис стану: {"name", "color", "desc"}; невідомий — порожній.
static func info(id: String) -> Dictionary:
	return GameDB.row("statuses", id)


## Стани в порядку файлу (довідник).
static func ids() -> Array:
	return GameDB.ids("statuses")


static func is_status(id: String) -> bool:
	return GameDB.table("statuses").has(id)


static func name_of(id: String) -> String:
	return str(info(id).get("name", ""))


static func color_of(id: String) -> Color:
	return info(id)["color"]


static func apply(target, id: String, dur: float, dps: float = 0.0) -> void:
	var st: Dictionary = target.statuses
	if st.has(id):
		st[id]["t"] = maxf(float(st[id]["t"]), dur)
		st[id]["dps"] = maxf(float(st[id]["dps"]), dps)
	else:
		st[id] = {"t": dur, "dps": dps, "tick": TICK}


## Минає час; повертає шкоду, яку стани завдають саме зараз (або 0).
static func tick(target, delta: float) -> float:
	var st: Dictionary = target.statuses
	if st.is_empty():
		return 0.0
	var dmg := 0.0
	for id in st.keys():
		var s: Dictionary = st[id]
		s["t"] = float(s["t"]) - delta
		if float(s["dps"]) > 0.0:
			s["tick"] = float(s["tick"]) - delta
			if float(s["tick"]) <= 0.0:
				s["tick"] = float(s["tick"]) + TICK
				dmg += float(s["dps"]) * TICK
		if float(s["t"]) <= 0.0:
			st.erase(id)
	return dmg


static func has(target, id: String) -> bool:
	return target.statuses.has(id)


static func speed_mult(target) -> float:
	return 0.6 if target.statuses.has("chill") else 1.0


static func heal_mult(target) -> float:
	return 0.5 if target.statuses.has("plague") else 1.0


static func damage_mult(target) -> float:
	return 0.7 if target.statuses.has("weak") else 1.0


## Колір головного стану (для підсвітки) або прозорий.
static func tint(target) -> Color:
	for id in TINT_ORDER:
		if target.statuses.has(id):
			return color_of(id)
	return Color(0, 0, 0, 0)


## Кружечки станів над головою.
static func draw_icons(node: CanvasItem, y: float) -> void:
	var ids: Array = node.statuses.keys()
	var x := -(ids.size() - 1) * 6.0
	for id in ids:
		node.draw_circle(Vector2(x, y), 4.5, color_of(id))
		node.draw_arc(Vector2(x, y), 4.5, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.2)
		x += 12.0


## Рядок для HUD: «Кровотеча 2с • Холод 1с».
static func describe(target) -> String:
	var parts := []
	for id in target.statuses:
		parts.append("%s %dс" % [name_of(id), ceili(float(target.statuses[id]["t"]))])
	return " • ".join(parts)
