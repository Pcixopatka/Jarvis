extends RefCounted
## База даних гри: сталі таблиці (нечисть, а згодом уміння, речі, світ) лежать у data/*.json,
## окремо від коду. Цей модуль — єдиний вхід до них: вантажить кожну таблицю раз, коли вона вперше
## потрібна, зводить числа до потрібних типів за схемою й перевіряє записи (див. problems()).
## Записи, які віддає база, лише для читання: їх заморожено, і спроба змінити їх дає помилку.
## Опис полів і як додати нечисть — docs/data.md.

const DIR := "res://data/"

## Схема запису: поле → {"type": ..., "required": true}. Типи: string, int, float, bool,
## color (масив [r, g, b] або [r, g, b, a] із часток 0..1, стає Color), record (вкладений запис
## зі своїми "fields"). Порядок полів у схемі — порядок ключів у файлі (див. tools/data_format.gd).
const MOB_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер запису (1001...): ніколи не змінюється й не віддається іншому
	"name": {"type": "string"},  # ім'я в однині; без нього нечисть не з'являється на мапі й у завданнях
	"plural": {"type": "string"},  # родовий множини: «Знищ 10 мавок»
	"quest_item": {"type": "string"},  # трофей для завдання «Принеси»
	"stats": {"type": "record", "required": true, "fields": {
		"hp": {"type": "float", "required": true},  # здоров'я на 1-му рівні до мірки рівня
		"speed": {"type": "float", "required": true},
		"damage": {"type": "float", "required": true},
		"xp": {"type": "int", "required": true},
		"radius": {"type": "float", "required": true},
		"scale": {"type": "float"},  # зріст (1 — звичайний); бос усе одно вдвічі більший
	}},
	"color": {"type": "color", "required": true},
	"attack": {"type": "record", "required": true, "fields": {
		"windup": {"type": "float", "required": true},  # замах перед ударом, с
		"ranged": {"type": "bool"},  # стріляє
		"keep_distance": {"type": "float"},  # тримається на такій відстані від цілі
		"shoot_cd": {"type": "float"},  # с між пострілами
		"as_boss": {"type": "record", "fields": {  # що інакше, коли цей вид веде бій як бос чи ватажок
			"ranged": {"type": "bool"},
			"shoot_cd": {"type": "float"},
		}},
	}},
	"hit_status": {"type": "string"},  # стан, який може накласти удар (див. Status.INFO)
	"minion_ability": {"type": "bool"},  # має свій прийом (Enemy._minion_ability)
	"sounds": {"type": "record", "fields": {
		"death": {"type": "string"},  # голос смерті (без нього — загальний «enemy_die»)
	}},
	"wiki": {"type": "record", "fields": {
		"text": {"type": "string", "required": true},
		"tip": {"type": "string", "required": true},
	}},
	"boss": {"type": "record", "fields": {  # є, якщо вид буває іменним босом
		"num": {"type": "int", "required": true},  # сталий номер боса (2001...), окремий від номера нечисті
		"name": {"type": "string", "required": true},
		"tier": {"type": "int"},  # ступінь золотих речей (без нього — за рівнем лігва, див. LootService)
		"phase2": {"type": "bool"},  # лютішає на половині здоров'я (Enemy._enter_phase2)
		"wiki": {"type": "record", "fields": {
			"text": {"type": "string", "required": true},
			"tip": {"type": "string", "required": true},
		}},
	}},
}

## Таблиці бази: назва → файл і схема. Нова таблиця (уміння, речі...) додається сюди одним рядком,
## а її власні правила й перехресні посилання — у _rules() і _links().
const TABLES := {
	"mobs": {"file": "mobs.json", "schema": MOB_SCHEMA},
}

const _EMPTY := {}

static var _tables := {}  # назва → заморожені записи
static var _ids := {}  # назва → заморожений масив id у порядку файлу
static var _load_problems := {}  # назва → що не так із файлом
static var _nums := {}  # покажчики за номером записів (див. _num_index)


# ---------- Загальний доступ ----------

## Уся таблиця: id → запис (лише для читання). Вантажиться раз, при першому зверненні.
static func table(name: String) -> Dictionary:
	if not _tables.has(name):
		_load(name)
	return _tables[name]


## Перелік id таблиці в порядку файлу (лише для читання).
static func ids(name: String) -> Array:
	if not _ids.has(name):
		_load(name)
	return _ids[name]


## Запис таблиці; для невідомого id — порожній словник (теж лише для читання).
static func row(name: String, id: String) -> Dictionary:
	return table(name).get(id, _EMPTY)


## Шлях до файлу таблиці.
static func path_of(name: String) -> String:
	return DIR + str(TABLES[name]["file"])


static func _load(name: String) -> void:
	var file_probs := []
	var raw := _read(name, file_probs)
	var res := _normalize_rows(name, raw)
	# Гучно: зламана чи загублена таблиця не має пройти тихо (повний перелік — problems())
	for p in file_probs + res[1]:
		push_error("GameDB: %s" % p)
	var rows: Dictionary = res[0]
	_freeze(rows)
	var keys := rows.keys()
	keys.make_read_only()
	_tables[name] = rows
	_ids[name] = keys
	_load_problems[name] = file_probs


## Сирий вміст файлу таблиці (числа — як їх дав JSON, тобто дробові).
static func _read(name: String, probs: Array) -> Dictionary:
	var path := path_of(name)
	if not FileAccess.file_exists(path):
		probs.append("немає файлу таблиці %s (чи не випав він зі збірки? див. include_filter в export_presets.cfg)" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		probs.append("%s, рядок %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		probs.append("%s: на верхньому рівні має бути об'єкт {id: запис}" % path)
		return {}
	return json.data


## Заморожує словники й масиви на всю глибину.
static func _freeze(v) -> void:
	if v is Dictionary:
		for k in v:
			_freeze(v[k])
		v.make_read_only()
	elif v is Array:
		for x in v:
			_freeze(x)
		v.make_read_only()


# ---------- Перевірка ----------

## Усе, що не так із базою: помилки файлів, полів, типів, невідомі ключі й посилання з коду гри
## на нечисть, якої в базі нема. Порожній масив — усе гаразд.
static func problems() -> Array:
	var out := []
	for name in TABLES:
		table(name)
		out.append_array(_load_problems[name])
		var raw := _read(name, [])
		out.append_array(validate(name, raw))
	return out


## Перевіряє сирі записи таблиці так само, як файл (схема, власні правила, посилання).
## Нічого не змінює й не вантажить у базу: зручно, щоб перевірити запис до того, як його записати.
static func validate(name: String, raw: Dictionary) -> Array:
	var res := _normalize_rows(name, raw)
	var out: Array = res[1]
	out.append_array(_rules(name, res[0]))
	out.append_array(_links(name, res[0]))
	return out


## Зводить усі записи таблиці до схеми. Повертає [записи, проблеми]; хибні поля пропускає.
static func _normalize_rows(name: String, raw: Dictionary) -> Array:
	var probs := []
	var rows := {}
	var schema: Dictionary = TABLES[name]["schema"]
	for id in raw:
		var where := "%s/%s" % [name, id]
		if not id is String or not _is_id(id):
			probs.append("%s: id має бути з малих латинських літер, цифр і «_»" % where)
		if not raw[id] is Dictionary:
			probs.append("%s: запис має бути об'єктом" % where)
			continue
		rows[str(id)] = _normalize(raw[id], schema, where, probs)
	return [rows, probs]


static func _is_id(id: String) -> bool:
	if id == "":
		return false
	for c in id:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_":
			return false
	return true


static func _normalize(rec: Dictionary, schema: Dictionary, where: String, probs: Array) -> Dictionary:
	var out := {}
	for k in rec:
		if not schema.has(k):
			probs.append("%s: невідоме поле «%s» (описка?)" % [where, k])
	for k in schema:
		var f: Dictionary = schema[k]
		if not rec.has(k):
			if f.get("required", false):
				probs.append("%s: немає обов'язкового поля «%s»" % [where, k])
			continue
		var v = _value(rec[k], f, "%s.%s" % [where, k], probs)
		if v != null:
			out[k] = v
	return out


## Одне значення за описом поля; null, якщо воно хибне (тоді проблему вже записано).
static func _value(v, f: Dictionary, where: String, probs: Array):
	var t: String = f["type"]
	match t:
		"string":
			if v is String:
				return v
		"bool":
			if v is bool:
				return v
		"int":
			# JSON дає всі числа дробовими: 3 приходить як 3.0. Ціле поле мусить бути цілим.
			if v is int:
				return v
			if v is float:
				if v == floorf(v) and absf(v) < 9.0e15:
					return int(v)
				probs.append("%s: має бути цілим числом, а не %s" % [where, var_to_str(v)])
				return null
		"float":
			if v is float or v is int:
				return float(v)
		"color":
			if v is Array and (v.size() == 3 or v.size() == 4):
				var ok := true
				for c in v:
					ok = ok and (c is float or c is int) and c >= 0.0 and c <= 1.0
				if ok:
					return Color(v[0], v[1], v[2], v[3] if v.size() == 4 else 1.0)
			probs.append("%s: колір має бути масивом [r, g, b] із чисел від 0 до 1" % where)
			return null
		"record":
			if v is Dictionary:
				return _normalize(v, f["fields"], where, probs)
	probs.append("%s: має бути %s, а не %s" % [where, _type_name(t), _type_name_of(v)])
	return null


static func _type_name(t: String) -> String:
	return {"string": "рядком", "bool": "true або false", "int": "цілим числом", "float": "числом", "record": "об'єктом {...}"}.get(t, t)


static func _type_name_of(v) -> String:
	if v is String:
		return "рядком"
	if v is bool:
		return "true/false"
	if v is float or v is int:
		return "числом"
	if v is Array:
		return "масивом"
	if v is Dictionary:
		return "об'єктом"
	return "null" if v == null else type_string(typeof(v))


## Власні правила таблиці (поза типами полів).
static func _rules(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"mobs":
			for id in rows:
				var R: Dictionary = rows[id]
				var at: Dictionary = R.get("attack", {})
				if at.get("ranged", false) and not at.has("shoot_cd"):
					out.append("mobs/%s: стрілець без «attack.shoot_cd»" % id)
				var ab: Dictionary = at.get("as_boss", {})
				if ab.get("ranged", false) and not ab.has("shoot_cd") and not at.has("shoot_cd"):
					out.append("mobs/%s: стрілець-бос без «attack.as_boss.shoot_cd»" % id)
				for k in ["hp", "speed", "damage", "radius", "scale"]:
					if float(R.get("stats", {}).get(k, 1.0)) <= 0.0:
						out.append("mobs/%s: «stats.%s» має бути більшим за нуль" % [id, k])
				if int(R.get("stats", {}).get("xp", 0)) < 0:
					out.append("mobs/%s: «stats.xp» не може бути від'ємним" % id)
				if R.has("boss") and R["boss"].has("tier") and (int(R["boss"]["tier"]) < 1 or int(R["boss"]["tier"]) > 6):
					out.append("mobs/%s: «boss.tier» має бути від 1 до 6" % id)
				for k in ["name", "plural", "quest_item"]:
					if R.has(k) and str(R[k]).strip_edges() == "":
						out.append("mobs/%s: «%s» порожнє" % [id, k])
			out.append_array(_unique_nums(rows))
	return out


## Номери записів не повторюються: серед нечисті й окремо серед босів.
static func _unique_nums(rows: Dictionary) -> Array:
	var out := []
	var seen := {}
	var seen_boss := {}
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("num"):
			var n := int(R["num"])
			if n <= 0:
				out.append("mobs/%s: «num» має бути додатним" % id)
			elif seen.has(n):
				out.append("mobs/%s: номер %d уже має «%s»" % [id, n, seen[n]])
			else:
				seen[n] = id
		if R.has("boss") and R["boss"].has("num"):
			var n := int(R["boss"]["num"])
			if n <= 0:
				out.append("mobs/%s: «boss.num» має бути додатним" % id)
			elif seen_boss.has(n):
				out.append("mobs/%s: номер боса %d уже має «%s»" % [id, n, seen_boss[n]])
			else:
				seen_boss[n] = id
	return out


## Посилання з інших частин гри на записи таблиці: чи є все, на що посилаються.
static func _links(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"mobs":
			out.append_array(_mob_links(rows))
	return out


static func _mob_links(rows: Dictionary) -> Array:
	var out := []
	var need := func(id, what: String, field: String = "") -> void:
		var R: Dictionary = rows.get(str(id), {})
		if R.is_empty():
			out.append("%s посилається на нечисть «%s», якої немає в mobs.json" % [what, id])
		elif field == "boss" and not R.has("boss"):
			out.append("%s: «%s» тут бос, але в mobs.json у нього нема запису «boss»" % [what, id])
		elif field != "" and field != "boss" and not R.has(field):
			out.append("%s: у «%s» нема поля «%s»" % [what, id, field])
	var Data = load("res://scripts/data/data.gd")
	for lid in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[lid]
		for e in L.get("enemies", []):
			for f in ["name", "plural", "quest_item"]:
				need.call(e, "місце %s" % lid, f)
		if str(L.get("boss", "")) != "":
			need.call(L["boss"], "місце %s (бос)" % lid, "boss")
	var Tower = load("res://scripts/game/tower_service.gd")
	var Depth = load("res://scripts/game/depth_service.gd")
	var Acts = load("res://scripts/data/activities.gd")
	var BossS = load("res://scripts/game/boss_service.gd")
	for b in Tower.SUPER_BOSSES:
		need.call(b, "Башта (супербос)", "boss")
	for e in Tower.POOL:
		need.call(e, "Башта (нечисть)", "name")
	for b in Depth.BOSSES:
		need.call(b, "Глибини (бос)", "boss")
	for e in Depth.POOL:
		need.call(e, "Глибини (нечисть)", "name")
	for b in Acts.RING_POOL:
		need.call(b, "Коло Кожум'яки", "boss")
	for b in BossS.POOL:
		need.call(b, "Боси дня й тижня", "boss")
	for k in Acts.BOUNTY_NAMES:
		need.call(k, "розшук (Activities.BOUNTY_NAMES)", "name")
	for k in load("res://scripts/game/stone_service.gd").FIRST_KILL:
		need.call(k, "камінь за першу перемогу", "boss")
	var Peril = load("res://scripts/data/peril.gd")
	for k in Peril.TITLES:
		need.call(k, "звитяга надважкої печери", "boss")
	for k in Peril.TITLE_FX:
		need.call(k, "бонус звитяги надважкої печери", "boss")
	var Uniques = load("res://scripts/data/uniques.gd")
	for u in Uniques.DEFS:
		for b in Uniques.DEFS[u].get("bosses", []):
			need.call(b, "золота річ %s" % u, "boss")
	var Arts = load("res://scripts/data/artifacts.gd")
	for a in Arts.DEFS:
		need.call(Arts.DEFS[a]["boss"], "артефакт %s" % a, "boss")
	var Souls = load("res://scripts/data/souls.gd")
	for s in Souls.SOULS:
		if str(s).begins_with("b_"):
			need.call(str(s).substr(2), "душа %s" % s, "boss")
		else:
			need.call(s, "душа %s" % s, "name")
	for k in load("res://scripts/data/elites.gd").FEMININE:
		need.call(k, "Elites.FEMININE")
	var Wiki = load("res://scripts/data/wiki_data.gd")
	for k in Wiki.ENEMY_ORDER:
		need.call(k, "довідник (нечисть)", "wiki")
	for k in Wiki.BOSS_ORDER:
		need.call(k, "довідник (боси)", "boss")
		if rows.has(k) and rows[k].has("boss") and not rows[k]["boss"].has("wiki"):
			out.append("довідник (боси): у «%s» нема «boss.wiki»" % k)
	# Зворотні перевірки: те, що є в записі, мусить мати сенс для гри
	var Status = load("res://scripts/game/status.gd")
	var Index = load("res://scripts/data/sound_index.gd")
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("hit_status") and not Status.INFO.has(R["hit_status"]):
			out.append("mobs/%s: невідомий стан «%s» (див. Status.INFO)" % [id, R["hit_status"]])
		var snd := str(R.get("sounds", {}).get("death", ""))
		if snd != "" and not Index.SFX.has(snd):
			out.append("mobs/%s: невідомий звук «%s» (див. SoundIndex.SFX)" % [id, snd])
		if R.has("wiki") and not id in Wiki.ENEMY_ORDER:
			out.append("mobs/%s: опис у довіднику є, а в Wiki.ENEMY_ORDER виду нема, тож його не видно" % id)
		if R.has("boss") and R["boss"].has("wiki") and not id in Wiki.BOSS_ORDER:
			out.append("mobs/%s: опис боса є, а в Wiki.BOSS_ORDER його нема, тож його не видно" % id)
	return out


# ---------- Нечисть ----------

## Запис нечисті (див. MOB_SCHEMA); для невідомого виду — порожній словник.
static func mob(id: String) -> Dictionary:
	return table("mobs").get(id, _EMPTY)


static func has_mob(id: String) -> bool:
	return table("mobs").has(id)


## Усі види нечисті в порядку файлу.
static func mob_ids() -> Array:
	return ids("mobs")


## Вид нечисті за сталим номером запису ("" — такого нема).
static func mob_by_num(n: int) -> String:
	return str(_num_index("num").get(n, ""))


## Вид нечисті за сталим номером її боса ("" — такого нема).
static func boss_by_num(n: int) -> String:
	return str(_num_index("boss_num").get(n, ""))



static func _num_index(which: String) -> Dictionary:
	if not _nums.has(which):
		var idx := {}
		for id in mob_ids():
			var R: Dictionary = mob(id)
			var n = R.get("num") if which == "num" else R.get("boss", _EMPTY).get("num")
			if n != null and not idx.has(n):
				idx[n] = id
		idx.make_read_only()
		_nums[which] = idx
	return _nums[which]


## Види, що бувають іменними босами (мають запис «boss»).
static func boss_ids() -> Array:
	var out := []
	for id in mob_ids():
		if mob(id).has("boss"):
			out.append(id)
	return out


static func mob_name(id: String, fallback: String = "") -> String:
	return str(mob(id).get("name", fallback))


static func mob_plural(id: String, fallback: String = "") -> String:
	return str(mob(id).get("plural", fallback))


static func quest_item(id: String, fallback: String = "") -> String:
	return str(mob(id).get("quest_item", fallback))


static func has_boss(id: String) -> bool:
	return mob(id).has("boss")


static func boss_name(id: String, fallback: String = "") -> String:
	return str(mob(id).get("boss", _EMPTY).get("name", fallback))


## Ступінь боса для золотих речей; 0 — власного нема.
static func boss_tier(id: String) -> int:
	return int(mob(id).get("boss", _EMPTY).get("tier", 0))


static func is_phase2_boss(id: String) -> bool:
	return bool(mob(id).get("boss", _EMPTY).get("phase2", false))


## Стан, який накладає удар цього виду ("" — жодного).
static func hit_status(id: String) -> String:
	return str(mob(id).get("hit_status", ""))


static func has_minion_ability(id: String) -> bool:
	return bool(mob(id).get("minion_ability", false))


## Голос смерті ("" — свого нема).
static func death_sound(id: String) -> String:
	return str(mob(id).get("sounds", _EMPTY).get("death", ""))


## Опис для довідника {text, tip}; порожній, якщо нема.
static func mob_wiki(id: String) -> Dictionary:
	return mob(id).get("wiki", _EMPTY)


static func boss_wiki(id: String) -> Dictionary:
	return mob(id).get("boss", _EMPTY).get("wiki", _EMPTY)
