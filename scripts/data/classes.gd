extends RefCounted
## Класи героя (у дусі Ragnarok): Селянин → Козак (Січ) / Стрілець (Батурин) / Волхв (Карпати) → спеціалізації.
## Кожен клас має свій рівень майстерності (job level), дерево вмінь, дозволену зброю
## і вроджені множники здоров'я та шкоди (воїн міцніший, маг — із більшою наснагою).
## Рівень майстерності дає по 1 очку вмінь; після зміни класу він скидається на 1, а вивчене лишається.
##
## Самі класи, вузли дерев, ступені майстерності й ключі бонусів лежать у таблицях (docs/data.md, «Класи й
## уміння»): data/classes.json, skills.json, job_tiers.json, effects.json. Тут — виклики над ними.
## Вузол дерева — запис skills.json: id (ранги, які зберігає герой), name, max, req {id: ранг}, active,
## cost, cd, label, kind, act (вміння за даними), fx (пасивне), desc. Записи заморожені: лише читати.
## Пасивні вузли з id колишніх перків (sharp, tough, ward…) діють так само, як ті перки.

const GameDB := preload("res://scripts/core/game_db.gd")

static var BASE_LEVEL_MAX: int  # стеля рівня героя
static var HARDEN_EVERY: int  # одне очко Загартування за кожні стільки рівнів героя


## Числа-правила вище лежать у data/settings.json (запис «experience»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("experience")
	BASE_LEVEL_MAX = S["base_level_max"]
	HARDEN_EVERY = S["harden_every"]


const _EMPTY := {}
const _EMPTY_LIST := []

# Покажчики, складені раз із таблиць (див. _index): усе заморожене, читати можна, міняти — ні.
static var _indexed := false
static var _trees := {}  # клас → [{"name": гілка, "nodes": [вузли]}] у порядку файлу
static var _tree_ids: Array = []  # класи з деревом, у порядку skills.json
static var _first := {}  # id уміння → перший вузол із ним (у порядку дерев)
static var _own := {}  # клас → {id уміння: вузол цього класу}
static var _parent := {}  # клас → хто веде до нього («next»)
static var _lineage := {}  # клас → ланцюжок класів від Селянина
static var _passive := {}  # клас → пасивні вузли з «fx» на всій дорозі, у порядку дерев
static var _actives: Array = []


static func _index() -> void:
	if _indexed:
		return
	_indexed = true
	var classes: Dictionary = GameDB.table("classes")
	for c in GameDB.ids("classes"):
		for x in classes[c]["next"]:
			if not _parent.has(x):
				_parent[x] = c
	for id in GameDB.ids("skills"):
		var n: Dictionary = GameDB.row("skills", id)
		var c := str(n["class"])
		if not _trees.has(c):
			_trees[c] = []
			_own[c] = {}
			_tree_ids.append(c)
			for b in classes.get(c, _EMPTY).get("branches", _EMPTY_LIST):
				_trees[c].append({"name": b, "nodes": []})
		var bi := int(n["branch"]) - 1
		if bi >= 0 and bi < _trees[c].size():
			_trees[c][bi]["nodes"].append(n)
		var sid: String = n["id"]
		if not _first.has(sid):
			_first[sid] = n
		if not _own[c].has(sid):
			_own[c][sid] = n
		if n.get("active", false) and not sid in _actives:
			_actives.append(sid)
	for c in _trees:
		GameDB._freeze(_trees[c])
	_tree_ids.make_read_only()
	_actives.make_read_only()


## Класи в порядку classes.json.
static func ids() -> Array:
	return GameDB.ids("classes")


static func has_class(cls: String) -> bool:
	return GameDB.table("classes").has(cls)


## Запис класу (classes.json); для невідомого — порожній запис.
static func info(cls: String) -> Dictionary:
	return GameDB.row("classes", cls)


## Класи з деревом умінь, у порядку skills.json (так їх перебирав довідник і пошук вузла).
static func tree_ids() -> Array:
	_index()
	return _tree_ids


static func has_tree(cls: String) -> bool:
	_index()
	return _trees.has(cls)


## Дерево класу: [{"name": назва гілки, "nodes": [вузли]}]; для класу без дерева — порожнє.
static func tree(cls: String) -> Array:
	_index()
	return _trees.get(cls, _EMPTY_LIST)


## Чи належить клас до волхвівської гілки (для звертань «волхве», вигляду тощо).
static func is_volkhv_line(cls: String) -> bool:
	return cls == "volkhv" or info(cls).get("parent", "") == "volkhv"


## Чи належить клас до гілки стрільців.
static func is_strilets_line(cls: String) -> bool:
	return cls == "strilets" or info(cls).get("parent", "") == "strilets"


## Досвід майстерності до наступного рівня: крива ступеня класу (job_tiers.json).
## Ступінь вище за останній у таблиці бере останній.
static func job_xp_for(tier: int, jl: int) -> int:
	var tiers: Array = GameDB.ladder("job_tiers", "tier")
	var T: Dictionary = tiers[clampi(tier, 0, tiers.size() - 1)]
	var X: Dictionary = T["xp"]
	return int(X["base"]) + int(X["per"]) * jl + int(X["square"]) * jl * jl


## Вузол дерева вмінь будь-якого класу (перший знайдений) і клас, якому він належить.
## cls — шукати спершу в дереві цього класу (той самий id буває в кількох класах).
static func find_node(id: String, cls: String = "") -> Dictionary:
	_index()
	if cls != "" and _own.has(cls) and _own[cls].has(id):
		return _own[cls][id]
	return _first.get(id, _EMPTY)


## Усі активні вміння гри за порядком дерев (кнопки бою будуються з цього переліку).
static func actives() -> Array:
	_index()
	return _actives


## Опис активного вміння за даними ("act" у вузлі) або порожній словник.
static func act(id: String) -> Dictionary:
	return find_node(id).get("act", _EMPTY)


## Підпис на кнопці бою.
static func label(id: String) -> String:
	var n := find_node(id)
	return str(n["label"]) if n.has("label") else node_name(id)


## Колір кнопки бою: свій («color») або колір дії, темніший на чверть.
static func color(id: String) -> Color:
	var n := find_node(id)
	if n.has("color"):
		return n["color"]
	return Color(str(n.get("act", _EMPTY).get("color", "8a6a3a"))).darkened(0.25)


## Перезарядка вміння в секундах до поправок героя.
static func cooldown(id: String) -> float:
	return float(find_node(id).get("cd", 6.0))


## Значення параметра вміння для рангу: число або [основа, приріст за кожен ранг понад перший].
static func val(v, rank: int) -> float:
	if v is Array:
		return float(v[0]) + float(v[1]) * maxi(0, rank - 1)
	return float(v)


## Пасивні бонуси вмінь за даними: вузли дерева з "fx" (без "act") дають fx[ключ] × ранг.
## "when": {"weapon": [...]} — бонус діє лише з такою зброєю в руках. Повертає {ключ: сума}.
static func passive_fx(job: String, skills: Dictionary, weapon_type: String) -> Dictionary:
	var out := {}
	if skills.is_empty():
		return out
	if not _passive.has(job):
		var list := []
		for c in lineage(job):
			for b in tree(c):
				for n in b["nodes"]:
					if n.has("fx") and not n.has("act"):
						list.append(n)
		list.make_read_only()
		_passive[job] = list
	for n in _passive[job]:
		var r := int(skills.get(n["id"], 0))
		if r <= 0:
			continue
		var w: Dictionary = n.get("when", _EMPTY)
		if w.has("weapon") and not weapon_type in w["weapon"]:
			continue
		for k in n["fx"]:
			out[k] = float(out.get(k, 0.0)) + float(n["fx"][k]) * r
	return out


## Ключі бонусів «fx» (effects.json) у порядку файлу.
static func fx_ids() -> Array:
	return GameDB.ids("effects")


static func has_fx(key: String) -> bool:
	return GameDB.table("effects").has(key)


## Шаблон тексту бонусу: %s — число (у відсотках, якщо не сказано інше).
static func fx_template(key: String) -> String:
	return str(GameDB.row("effects", key).get("text", "%s"))


## Бонуси словами: «+8% шкоди, +4% захисту».
static func fx_text(fx: Dictionary, rank: int = 1) -> String:
	var parts := []
	for k in fx:
		var v: float = val(fx[k], rank)
		var num := str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")
		var t: String = fx_template(k)
		if k == "ward" and v < 0.0:
			parts.append("шкода по тобі більша на %s%%" % num.trim_prefix("-"))
			continue
		if v < 0.0 and t.begins_with("+"):
			t = t.substr(1)  # «−5% захисту», а не «+−5%»
			num = "−" + num.trim_prefix("-")
		parts.append(t % num)
	return ", ".join(parts)


## Слово до числа: plural(1, "очко", "очки", "очок") — «очко», 3 — «очки», 5 і 11–14 — «очок».
static func plural(n: int, one: String, few: String, many: String) -> String:
	var d := absi(n) % 100
	if d >= 11 and d <= 14:
		return many
	match d % 10:
		1: return one
		2, 3, 4: return few
	return many


static func node_name(id: String) -> String:
	return find_node(id).get("name", id)


## Ланцюжок класів від Селянина до цього (для «набутих раніше» вмінь). Лише для читання.
static func lineage(cls: String) -> Array:
	if not _lineage.has(cls):
		_index()
		var out := [cls]
		var c := cls
		while _parent.has(c) and not _parent[c] in out:
			c = _parent[c]
			out.push_front(c)
		out.make_read_only()
		_lineage[cls] = out
	return _lineage[cls]
