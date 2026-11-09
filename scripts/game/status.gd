extends RefCounted
## Стани й ефекти для козака і нечисті. Стан зберігається на сутності:
##   statuses = {id: {"t": скільки лишилось, "dps": шкода за секунду, "tick": до наступного удару}}
## Шкода від станів б'є раз на пів секунди (щоб не засипати екран цифрами).

const INFO := {
	"bleed": {"name": "Кровотеча", "color": Color(0.9, 0.12, 0.12)},
	"burn": {"name": "Горіння", "color": Color(1.0, 0.55, 0.1)},
	"plague": {"name": "Зараза", "color": Color(0.45, 0.9, 0.15)},  # ще й лікування вдвічі слабше
	"chill": {"name": "Холод", "color": Color(0.55, 0.82, 1.0)},  # повільніший
	"weak": {"name": "Слабкість", "color": Color(0.7, 0.45, 0.9)},  # б'є слабше
	"curse": {"name": "Прокляття", "color": Color(0.45, 0.15, 0.4)},  # отримує більше шкоди (чари мольфара)
}
const TICK := 0.5


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
	for id in ["burn", "plague", "bleed", "chill", "weak", "curse"]:
		if target.statuses.has(id):
			return INFO[id]["color"]
	return Color(0, 0, 0, 0)


## Кружечки станів над головою.
static func draw_icons(node: CanvasItem, y: float) -> void:
	var ids: Array = node.statuses.keys()
	var x := -(ids.size() - 1) * 6.0
	for id in ids:
		node.draw_circle(Vector2(x, y), 4.5, INFO[id]["color"])
		node.draw_arc(Vector2(x, y), 4.5, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.2)
		x += 12.0


## Рядок для HUD: «Кровотеча 2с • Холод 1с».
static func describe(target) -> String:
	var parts := []
	for id in target.statuses:
		parts.append("%s %dс" % [INFO[id]["name"], ceili(float(target.statuses[id]["t"]))])
	return " • ".join(parts)
