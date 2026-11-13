extends RefCounted
## Рушій завдань: один на всі лінії (історія, перекази, сага й будь-які нові). Читає таблиці кроків
## (data/story.json, legend_steps.json, saga.json) і лінії (quest_lines.json) і вирішує, що героєві зараз
## відкрито. Розмови, нагороди й тексти кроку веде служба виду його лінії (KIND_SERVICES): рушій лише
## каже, що відкрито, і рахує мету.
##
## Коли крок відкритий («місія»):
## - кожен крок з його «after» пройдено (здано або пропущено); крок без «after» нічого не чекає;
## - рівень героя не менший за «min_level» кроку, а для перших кроків лінії (тих, що не чекають на крок
##   своєї ж лінії) — і за «min_level» лінії;
## - умова «if» ("ключ=вибір") справджується. Якщо ні — крок пропущено: для тих, хто на нього чекає,
##   він пройдений (так у пролозі розходяться гілки козака, волхва й стрільця).
## Відкритих місій може бути скільки завгодно водночас; у кожної свій етап і лічильник.
## Обов'язкова місія для іншої — та, що стоїть у її «after»; інших відмінностей між обов'язковою й
## необов'язковою нема. «story» кроку (або його лінії) — чи місія сюжетна (позначка для інтерфейсу).
##
## Стан героя — world.missions:
##   {"done": {id кроку: true} — здані кроки,
##    "active": {id: {"stage": "active"/"turnin", "progress": скільки зроблено}} — початі кроки,
##    "choices": {ключ вибору: номер вибору}}.
## Пропущені кроки не пишуться: їх видно з виборів. Крок без розмови на початку («start» порожній) стає
## активним сам, щойно відкривається, і до першого поступу в «active» не пишеться.
## Етапи кроку (stage): done (здано), skip (пропущено), offer (чекає розмови), active (виконується мета),
## turnin (мету виконано, треба повернутися), level (усе пройдено, та рівень героя замалий), locked (ще чекає
## на інші кроки).
##
## Що відкрито, рахується раз на зміну стану (і рівня героя), а не на кожен виклик: журнал, порадник і
## позначки мапи питають часто.

const GameDB := preload("res://scripts/core/game_db.gd")

## Служба, що веде кроки кожного виду лінії («kind» у quest_lines.json).
const KIND_SERVICES := {"story": "res://scripts/game/story_service.gd", "legend": "res://scripts/game/legend_service.gd", "saga": "res://scripts/game/saga_service.gd"}

static var _db_graph := {}  # граф із таблиць бази (складається раз)
static var _test_graph := {}  # граф, підставлений через use_graph (тести на вигаданих даних)
static var _graph_rev := 0  # міняється з кожним use_graph: старий підрахунок не годиться
static var _view_key := []
static var _view := {}


# ---------- Граф ----------

## Граф із ліній і кроків, що в пам'яті. lines — {id лінії: {"kind", "min_level"?, "story"?}} у порядку показу,
## steps — {id кроку: {"line", "after"?, "min_level"?, "story"?, "if"?, "start"?, "objective"?...}} у порядку показу.
## Перевіряти такі дані — GameDB.quest_graph_problems.
static func make_graph(lines: Dictionary, steps: Dictionary) -> Dictionary:
	var g := {"lines": {}, "line_order": [], "steps": steps, "line_of": {}, "after": {}, "need": {}, "story": {}, "order": [], "topo": [], "kids": {}}
	for lid in lines:
		var L: Dictionary = lines[lid]
		g["line_order"].append(str(lid))
		g["lines"][str(lid)] = {"kind": str(L.get("kind", "")), "min_level": int(L.get("min_level", 0)), "story": bool(L.get("story", false)), "steps": []}
	for id in steps:
		var R: Dictionary = steps[id]
		var lid := str(R.get("line", ""))
		if not g["lines"].has(lid):
			continue
		var L: Dictionary = g["lines"][lid]
		L["steps"].append(str(id))
		var after := []
		var root := true  # перший крок лінії: не чекає на крок своєї ж лінії
		for a in R.get("after", []):
			after.append(str(a))
			if steps.has(a) and str(steps[a].get("line", "")) == lid:
				root = false
		g["line_of"][str(id)] = lid
		g["after"][str(id)] = after
		g["need"][str(id)] = maxi(int(R.get("min_level", 0)), int(L["min_level"]) if root else 0)
		g["story"][str(id)] = bool(R.get("story", L["story"]))
		for a in after:
			if not g["kids"].has(a):
				g["kids"][a] = []
			g["kids"][a].append(str(id))
	# Порядок місій: спершу сюжетні, далі за порядком ліній, у лінії — за порядком кроків
	for want in [true, false]:
		for lid in g["line_order"]:
			for id in g["lines"][lid]["steps"]:
				if bool(g["story"][id]) == want:
					g["order"].append(id)
	# Порядок обчислення: кожен крок після тих, на кого чекає (крок у колі не відкривається ніколи)
	var left := {}
	for id in g["order"]:
		var n := 0
		for a in g["after"][id]:
			if g["line_of"].has(a):
				n += 1
		left[id] = n
	var ready: Array = g["order"].filter(func(id): return int(left[id]) == 0)
	while not ready.is_empty():
		var id: String = ready.pop_front()
		g["topo"].append(id)
		for k in g["kids"].get(id, []):
			if left.has(k):
				left[k] = int(left[k]) - 1
				if int(left[k]) == 0:
					ready.append(k)
	return g


## Граф таблиць бази.
static func _from_db() -> Dictionary:
	if _db_graph.is_empty():
		_db_graph = make_graph(GameDB.table("quest_lines"), GameDB.quest_steps())
	return _db_graph


static func graph() -> Dictionary:
	return _test_graph if not _test_graph.is_empty() else _from_db()


## Підставити граф (make_graph) замість таблиць бази; порожній словник — назад до бази. Для тестів.
static func use_graph(g: Dictionary) -> void:
	_test_graph = g
	_graph_rev += 1
	_view_key = []


## Запис кроку ({} — нема такого).
static func step(id: String) -> Dictionary:
	return graph()["steps"].get(id, {})


static func has_step(id: String) -> bool:
	return graph()["line_of"].has(id)


## Лінія кроку ("" — нема такого кроку).
static func line_of(id: String) -> String:
	return str(graph()["line_of"].get(id, ""))


## Вид лінії кроку: story / legend / saga.
static func kind_of(id: String) -> String:
	return str(graph()["lines"].get(line_of(id), {}).get("kind", ""))


## Чи місія сюжетна («story» кроку, без нього — лінії).
static func is_story(id: String) -> bool:
	return bool(graph()["story"].get(id, false))


## Лінії в порядку показу.
static func line_ids() -> Array:
	return graph()["line_order"]


## Кроки лінії в порядку показу.
static func line_steps(line: String) -> Array:
	return graph()["lines"].get(line, {}).get("steps", [])


## З якого рівня героя крок відкривається (своє «min_level» чи, для перших кроків лінії, лінії).
static func level_needed(id: String) -> int:
	return int(graph()["need"].get(id, 0))


## На які кроки крок чекає.
static func after(id: String) -> Array:
	return graph()["after"].get(id, [])


## Скільки треба зробити за метою кроку.
static func count(id: String) -> int:
	return int(step(id).get("objective", {}).get("count", 1))


## Служба, що веде кроки лінії цього виду.
static func service(kind: String):
	return load(KIND_SERVICES[kind]) if KIND_SERVICES.has(kind) else null


# ---------- Стан ----------

static func state(world) -> Dictionary:
	var s: Dictionary = world.missions
	for k in ["done", "active", "choices"]:
		if not s.has(k):
			s[k] = {}
	return s


## Чи вибір зроблено так. cond: "ключ=номер вибору".
static func chose(world, cond: String) -> bool:
	var parts := cond.split("=")
	if parts.size() != 2:
		return false
	return int(state(world)["choices"].get(parts[0], -1)) == int(parts[1])


## Записати вибір під ключем.
static func set_choice(world, key: String, choice: int) -> void:
	state(world)["choices"][key] = choice


## Усі зроблені вибори {ключ: номер} (лише читати).
static func choices(world) -> Dictionary:
	return state(world)["choices"]


## Що відкрито зараз: {"finished": {id: "done"/"skip"}, "open": {id: етап}, "level": {id: потрібний рівень},
## "list": [id відкритих у порядку місій]}. Рахується знову лише тоді, коли змінився стан чи рівень героя.
static func _now(world) -> Dictionary:
	var s := state(world)
	var g := graph()
	var key := [world.get_instance_id(), s.hash(), int(world.hero_level), _graph_rev]
	if key == _view_key:
		return _view
	var fin := {}
	var open := {}
	var low := {}
	var lvl := int(world.hero_level)
	for id in g["topo"]:
		if s["done"].has(id):
			fin[id] = "done"
			continue
		if s["active"].has(id):
			open[id] = str(s["active"][id].get("stage", "active"))
			continue
		var waits := false
		for a in g["after"][id]:
			if not fin.has(a):
				waits = true
				break
		if waits:
			continue
		var R: Dictionary = g["steps"][id]
		if R.has("if") and not chose(world, str(R["if"])):
			fin[id] = "skip"
			continue
		if lvl < int(g["need"][id]):
			low[id] = int(g["need"][id])
			continue
		open[id] = "active" if R.get("start", []).is_empty() else "offer"
	# почате, хоч і не в порядку обчислення (крок у колі чи збереження з дивним станом), теж відкрите
	for id in s["active"]:
		if not open.has(id) and not fin.has(id) and g["line_of"].has(id):
			open[id] = str(s["active"][id].get("stage", "active"))
	var list := []
	for id in g["order"]:
		if open.has(id):
			list.append(id)
	list.make_read_only()
	_view = {"finished": fin, "open": open, "level": low, "list": list}
	_view_key = key
	return _view


## Відкриті місії (offer / active / turnin) у порядку: спершу сюжетні, далі за лініями й кроками. Лише читати.
static func missions(world) -> Array:
	return _now(world)["list"]


## Відкриті місії ліній цих видів.
static func missions_of(world, kinds: Array) -> Array:
	var out := []
	for id in missions(world):
		if kind_of(id) in kinds:
			out.append(id)
	return out


## Етап кроку: done / skip / offer / active / turnin / level / locked.
static func stage(world, id: String) -> String:
	var v := _now(world)
	if v["finished"].has(id):
		return str(v["finished"][id])
	if v["open"].has(id):
		return str(v["open"][id])
	if v["level"].has(id):
		return "level"
	return "locked"


static func is_done(world, id: String) -> bool:
	return state(world)["done"].has(id)


static func is_skipped(world, id: String) -> bool:
	return str(_now(world)["finished"].get(id, "")) == "skip"


## Чи крок пройдено: здано або пропущено.
static func is_finished(world, id: String) -> bool:
	return _now(world)["finished"].has(id)


static func is_open(world, id: String) -> bool:
	return _now(world)["open"].has(id)


## Скільки зроблено за метою кроку.
static func progress(world, id: String) -> int:
	return int(state(world)["active"].get(id, {}).get("progress", 0))


## Чи всі кроки лінії пройдено.
static func line_finished(world, line: String) -> bool:
	for id in line_steps(line):
		if not is_finished(world, id):
			return false
	return not line_steps(line).is_empty()


## Чи лінію почато: якийсь її крок здано чи почато.
static func line_started(world, line: String) -> bool:
	var s := state(world)
	for id in line_steps(line):
		if s["done"].has(id) or s["active"].has(id):
			return true
	return false


## Чи лінія вже пускає героя: рівень не менший за «min_level» лінії або її вже почато.
static func line_open(world, line: String) -> bool:
	var L: Dictionary = graph()["lines"].get(line, {})
	return not L.is_empty() and (int(world.hero_level) >= int(L["min_level"]) or line_started(world, line))


## Наступний крок лінії: перший у порядку показу, ще не пройдений, чиї кроки з тієї ж лінії в «after» уже
## пройдено ("" — лінію пройдено). На кроки інших ліній і на рівень не зважає: відкритий він чи ще ні,
## каже stage.
static func line_next(world, line: String) -> String:
	var v := _now(world)
	for id in line_steps(line):
		if v["finished"].has(id):
			continue
		var waits := false
		for a in after(id):
			if line_of(a) == line and not v["finished"].has(a):
				waits = true
				break
		if not waits:
			return id
	return ""


# ---------- Зміни стану ----------

static func _entry(world, id: String) -> Dictionary:
	var a: Dictionary = state(world)["active"]
	if not a.has(id):
		a[id] = {"stage": "active", "progress": 0}
	return a[id]


## Почати крок: мета виконується, лічильник з нуля.
static func start(world, id: String) -> void:
	state(world)["active"][id] = {"stage": "active", "progress": 0}


## Етап почату кроку: active чи turnin.
static func set_stage(world, id: String, stage_name: String) -> void:
	_entry(world, id)["stage"] = stage_name


static func set_progress(world, id: String, n: int) -> void:
	_entry(world, id)["progress"] = n


## Крок здано: він пройдений для всіх, хто на нього чекає.
static func complete(world, id: String) -> void:
	var s := state(world)
	s["active"].erase(id)
	s["done"][id] = true


# ---------- Події гри ----------

## Подія гри для всіх активних місій (kinds — лише ліній цих видів; порожній — усіх).
## type: clear / dungeon / visit (arg = id місця), kill (arg = вид ворога), job (arg = рівень майстерності),
## choose (дорогу обрано). Місії обходяться в порядку missions(); ті, що відкрилися від цієї ж події, її не чують.
## Повертає повідомлення [{"text", "big"}]: що сказати, вирішує служба лінії.
static func on_event(world, player, type: String, arg: String, kinds: Array = []) -> Array:
	var msgs := []
	for id in missions(world):
		if not kinds.is_empty() and not kind_of(id) in kinds:
			continue
		if stage(world, id) != "active":
			continue
		var o: Dictionary = step(id).get("objective", {})
		var n := count(id)
		var svc = service(kind_of(id))
		var met := false
		match type:
			"clear", "dungeon", "visit":
				met = str(o.get("type", "")) == type and str(o.get("loc", "")) == arg
			"job":
				if str(o.get("type", "")) == "job":
					set_progress(world, id, mini(int(arg), n))
					met = int(arg) >= n
			"choose":
				met = str(o.get("type", "")) == "choose"
			"kill":
				if str(o.get("enemy", "")) == arg and str(o.get("type", "")) in ["kill", "fetch"]:
					if str(o["type"]) == "kill":
						set_progress(world, id, progress(world, id) + 1)
					elif randf() < float(o.get("chance", 0.5)):
						set_progress(world, id, progress(world, id) + 1)
						msgs.append(svc.fetch_msg(world, id))
					met = progress(world, id) >= n
		if met:
			set_progress(world, id, n)
			msgs.append_array(svc.objective_met(world, player, id))
	return msgs


## Куди веде місія (id міста чи місця; "" — нікуди): питає службу її лінії.
static func target(world, id: String) -> String:
	var svc = service(kind_of(id))
	return str(svc.mission_target(world, id)) if svc != null else ""


# ---------- Для налагодження й тестів ----------

## Поставити героя на крок id: усі кроки, на які він чекає (прямо чи через інших), здано (крім тих, що
## пропускаються за виборами), сам крок — на етапі stage_name (offer — нічого не пише).
static func place_at(world, id: String, stage_name: String = "offer", n: int = 0) -> void:
	var s := state(world)
	var anc: Dictionary = GameDB.quest_ancestors(graph()["steps"]).get(id, {})
	for a in graph()["topo"]:
		if anc.has(a) and not (step(a).has("if") and not chose(world, str(step(a)["if"]))):
			s["done"][a] = true
			s["active"].erase(a)
	s["done"].erase(id)
	if stage_name == "offer":
		s["active"].erase(id)
	else:
		s["active"][id] = {"stage": stage_name, "progress": n}


## Пройти всю лінію (крім кроків, що пропускаються за виборами).
static func finish_line(world, line: String) -> void:
	var s := state(world)
	for id in graph()["topo"]:
		if line_of(id) == line and not (step(id).has("if") and not chose(world, str(step(id)["if"]))):
			s["done"][id] = true
			s["active"].erase(id)
