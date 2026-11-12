extends RefCounted
## База даних гри: сталі таблиці (нечисть, а згодом уміння, речі, світ) лежать у data/*.json,
## окремо від коду. Цей модуль — єдиний вхід до них: вантажить кожну таблицю раз, коли вона вперше
## потрібна, зводить числа до потрібних типів за схемою й перевіряє записи (див. problems()).
## Записи, які віддає база, лише для читання: їх заморожено, і спроба змінити їх дає помилку.
## Опис полів і як додати нечисть — docs/data.md.

const DIR := "res://data/"

## Схема запису: поле → {"type": ..., "required": true}. Типи: string, int, float, bool,
## color (масив [r, g, b] або [r, g, b, a] із часток 0..1, стає Color), record (вкладений запис
## зі своїми "fields"), enum (рядок із переліку "values"), list (масив значень, кожне за описом "of";
## "size" — точна довжина), map (об'єкт {рядковий ключ: значення за описом "of"}; порядок ключів
## зберігається). Порядок полів у схемі — порядок ключів у файлі (див. tools/data_format.gd).
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
	"mechanic": {"type": "string"},  # механіка звичайної форми: "mob/<файл>" у scripts/mechanics/ (див. Mechanic)
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
		"phase2": {"type": "bool"},  # лютішає на половині здоров'я (тоді рушій кличе phase2 механіки)
		"mechanic": {"type": "string"},  # механіка боса: "boss/<файл>" у scripts/mechanics/
		"wiki": {"type": "record", "fields": {
			"text": {"type": "string", "required": true},
			"tip": {"type": "string", "required": true},
		}},
	}},
}

## Найманець із корчми (джура, стрілець, знахарка): ім'я, ціна, сила 1-го рівня, механіка бою.
const COMPANION_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (3001...)
	"name": {"type": "string", "required": true},
	"desc": {"type": "string", "required": true},  # опис у корчмі ("\n" — розрив рядка)
	"hire": {"type": "record", "required": true, "fields": {
		"cost": {"type": "int", "required": true},  # ціна найму в гривнях до знижки й мірки рівня героя
		"loyalty": {"type": "int", "required": true},  # потрібна лояльність міста: номер у Data.LOYALTY_NAMES
	}},
	"stats": {"type": "record", "required": true, "fields": {
		"hp": {"type": "float", "required": true},  # здоров'я на 1-му рівні (далі росте за еталоном, див. Party.stats)
		"hp_lvl": {"type": "float"},  # приріст за рівень зі старої формули; зараз гра його не читає
		"dmg": {"type": "float", "required": true},
		"dmg_lvl": {"type": "float"},  # так само не читається
		"heal": {"type": "float"},  # лікування на 1-му рівні (знахарка)
		"heal_lvl": {"type": "float"},  # так само не читається
		"range": {"type": "float", "required": true},  # дальність удару
		"cd": {"type": "float", "required": true},  # с між ударами
		"speed": {"type": "float", "required": true},
	}},
	"color": {"type": "color", "required": true},
	"mechanic": {"type": "string"},  # як б'ється: "companion/<файл>" у scripts/mechanics/
}

## Репліка розмови: [мовець, текст]; мовець — id із Story.NPCS.
const LINE := {"type": "list", "size": 2, "of": {"type": "string"}}
const DIALOGUE := {"type": "list", "required": true, "of": LINE}

## Побратим: іменний супутник з історією. Б'ється як найманець свого base, але сильніший.
const HERO_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (3101...)
	"name": {"type": "string", "required": true},
	"base": {"type": "string", "required": true},  # рід служби: id із companions.json
	"mult": {"type": "float", "required": true},  # у скільки разів сильніший за найманця
	"color": {"type": "color", "required": true},
	"bio": {"type": "string", "required": true},
	"join": {"type": "record", "required": true, "fields": {  # де й коли зустріти
		"city": {"type": "string", "required": true},  # місто (Data.CITIES)
		"after": {"type": "string", "required": true},  # крок сюжету, який уже пройдено
		"if": {"type": "string"},  # "крок=номер вибору"
	}},
	"meet": DIALOGUE,  # розмова при зустрічі
	"quest_bond": {"type": "int", "required": true},  # від якої дружби дає особисте завдання
	"quest": {"type": "record", "required": true, "fields": {
		"start": DIALOGUE,
		"objective": {"type": "record", "required": true, "fields": {
			"type": {"type": "enum", "required": true, "values": ["kill", "fetch", "clear", "dungeon"]},
			"enemy": {"type": "string"},  # kill, fetch: кого бити (mobs.json)
			"count": {"type": "int"},  # kill, fetch: скільки
			"loc": {"type": "string", "required": true},  # місце (Data.LOCATIONS)
			"item": {"type": "string"},  # fetch: що здобути
			"chance": {"type": "float"},  # fetch: шанс на кожного переможеного
			"text": {"type": "string", "required": true},
		}},
		"end": DIALOGUE,
	}},
	"bonded": {"type": "float", "required": true},  # множник сили після особистого завдання
}

## Улюбленець стайні (пес, кіт, ворон, кінь) або супутник із божого дару (Хованець, скакун, мажа).
const PET_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (3201...)
	"name": {"type": "string"},  # улюбленець стайні; у дару ім'я — з самого дару (Divine)
	"desc": {"type": "string"},
	"stable": {"type": "record", "fields": {  # є в улюбленців стайні: хист, ступені, ціна
		"stat": {"type": "enum", "required": true, "values": ["pickup", "travel", "xp", "res"]},
		"base": {"type": "float", "required": true},  # надбавка на 1-му ступені (частка)
		"per": {"type": "float", "required": true},  # приріст за кожен наступний ступінь
		"text": {"type": "string", "required": true},  # опис хисту з %d (відсотки)
		"gold": {"type": "int", "required": true},  # ціна 1-го ступеня; ступінь N коштує в N разів більше
		"res": {"type": "map", "required": true, "of": {"type": "int"}},  # ресурси 1-го ступеня
	}},
	"gift": {"type": "bool"},  # супутник із божого дару з тим самим id (Divine.DEFS)
	"mechanic": {"type": "string"},  # що робить у бою: "pet/<файл>"; без нього в бій не йде (кінь)
}

## Таблиці бази: назва → файл і схема. Нова таблиця (уміння, речі...) додається сюди одним рядком,
## а її власні правила й перехресні посилання — у _rules() і _links().
const TABLES := {
	"mobs": {"file": "mobs.json", "schema": MOB_SCHEMA},
	"companions": {"file": "companions.json", "schema": COMPANION_SCHEMA},
	"heroes": {"file": "heroes.json", "schema": HERO_SCHEMA},
	"pets": {"file": "pets.json", "schema": PET_SCHEMA},
}

## Основи механік за родинами: тека в scripts/mechanics/ → скрипт-основа.
const MECHANIC_BASES := {
	"mob": "res://scripts/mechanics/mechanic.gd",
	"boss": "res://scripts/mechanics/mechanic.gd",
	"companion": "res://scripts/mechanics/companion_mechanic.gd",
	"pet": "res://scripts/mechanics/pet_mechanic.gd",
}

## Гнізда божих дарів, у яких лежать супутники, що ходять за героєм у бою (Хованець, скакун, мажа).
const PET_GIFT_SLOTS := ["pet", "cart"]

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
		"enum":
			if v is String:
				if v in f["values"]:
					return v
				probs.append("%s: «%s» — не з переліку %s" % [where, v, str(f["values"])])
				return null
		"list":
			if v is Array:
				if f.has("size") and v.size() != int(f["size"]):
					probs.append("%s: має бути %d значень, а не %d" % [where, int(f["size"]), v.size()])
					return null
				var out := []
				for i in v.size():
					var x = _value(v[i], f["of"], "%s[%d]" % [where, i], probs)
					if x == null:
						return null
					out.append(x)
				return out
		"map":
			if v is Dictionary:
				var out := {}
				for k in v:
					var x = _value(v[k], f["of"], "%s.%s" % [where, k], probs)
					if x != null:
						out[k] = x
				return out
	probs.append("%s: має бути %s, а не %s" % [where, _type_name(t), _type_name_of(v)])
	return null


static func _type_name(t: String) -> String:
	return {"string": "рядком", "bool": "true або false", "int": "цілим числом", "float": "числом", "record": "об'єктом {...}",
		"enum": "рядком", "list": "масивом [...]", "map": "об'єктом {...}"}.get(t, t)


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
				# Механіка: звичайна форма — лише з теки mob/, бос — лише з boss/
				if R.has("mechanic") and not _is_mechanic_ref(R["mechanic"], "mob"):
					out.append("mobs/%s: «mechanic» має бути \"mob/<файл>\", а не «%s»" % [id, R["mechanic"]])
				if R.has("boss") and R["boss"].has("mechanic") and not _is_mechanic_ref(R["boss"]["mechanic"], "boss"):
					out.append("mobs/%s: «boss.mechanic» має бути \"boss/<файл>\", а не «%s»" % [id, R["boss"]["mechanic"]])
			out.append_array(_unique_nums(name, rows))
		"companions":
			for id in rows:
				var R: Dictionary = rows[id]
				_not_blank(R, ["name", "desc"], "companions/" + id, out)
				var st: Dictionary = R.get("stats", {})
				for k in ["hp", "dmg", "range", "cd", "speed"]:
					if st.has(k) and float(st[k]) <= 0.0:
						out.append("companions/%s: «stats.%s» має бути більшим за нуль" % [id, k])
				for k in ["hp_lvl", "dmg_lvl", "heal", "heal_lvl"]:
					if st.has(k) and float(st[k]) < 0.0:
						out.append("companions/%s: «stats.%s» не може бути від'ємним" % [id, k])
				if int(R.get("hire", {}).get("cost", 0)) < 0:
					out.append("companions/%s: «hire.cost» не може бути від'ємним" % id)
				if R.has("mechanic") and not _is_mechanic_ref(R["mechanic"], "companion"):
					out.append("companions/%s: «mechanic» має бути \"companion/<файл>\", а не «%s»" % [id, R["mechanic"]])
			out.append_array(_unique_nums(name, rows))
		"heroes":
			for id in rows:
				out.append_array(_hero_rules("heroes/" + id, rows[id]))
			out.append_array(_unique_nums(name, rows))
		"pets":
			for id in rows:
				out.append_array(_pet_rules("pets/" + id, rows[id]))
			out.append_array(_unique_nums(name, rows))
	return out


static func _not_blank(R: Dictionary, keys: Array, where: String, out: Array) -> void:
	for k in keys:
		if R.has(k) and str(R[k]).strip_edges() == "":
			out.append("%s: «%s» порожнє" % [where, k])


## Розмови побратима: назва → масив реплік.
static func _hero_dialogues(R: Dictionary) -> Dictionary:
	var q: Dictionary = R.get("quest", _EMPTY)
	return {"meet": R.get("meet", []), "quest.start": q.get("start", []), "quest.end": q.get("end", [])}


static func _hero_rules(where: String, R: Dictionary) -> Array:
	var out := []
	_not_blank(R, ["name", "bio"], where, out)
	if R.has("mult") and float(R["mult"]) <= 0.0:
		out.append("%s: «mult» має бути більшим за нуль" % where)
	if R.has("bonded") and R.has("mult") and float(R["bonded"]) < float(R["mult"]):
		out.append("%s: «bonded» менший за «mult», а після особистого завдання побратим має сильнішати" % where)
	if R.has("quest_bond") and int(R["quest_bond"]) <= 0:
		out.append("%s: «quest_bond» має бути більшим за нуль" % where)
	var dl := _hero_dialogues(R)
	for k in dl:
		var lines: Array = dl[k]
		if lines.is_empty() and (k == "meet" and R.has("meet") or R.get("quest", _EMPTY).has(k.trim_prefix("quest."))):
			out.append("%s: розмова «%s» порожня" % [where, k])
		for i in lines.size():
			if str(lines[i][0]).strip_edges() == "" or str(lines[i][1]).strip_edges() == "":
				out.append("%s: «%s[%d]»: порожній мовець чи текст" % [where, k, i])
	var o: Dictionary = R.get("quest", _EMPTY).get("objective", _EMPTY)
	var ot := str(o.get("type", ""))
	if ot in ["kill", "fetch"]:
		if not o.has("enemy") or not o.has("count"):
			out.append("%s: мета «%s» потребує «enemy» і «count»" % [where, ot])
		elif int(o["count"]) < 1:
			out.append("%s: «quest.objective.count» має бути від 1" % where)
	if ot == "fetch":
		if not o.has("item") or not o.has("chance"):
			out.append("%s: мета «fetch» потребує «item» і «chance»" % where)
		elif float(o["chance"]) <= 0.0 or float(o["chance"]) > 1.0:
			out.append("%s: «quest.objective.chance» має бути від 0 до 1" % where)
	for k in ["enemy", "count", "item", "chance"]:
		if o.has(k) and not (ot == "fetch" or (ot == "kill" and k in ["enemy", "count"])):
			out.append("%s: мета «%s» не читає «%s»" % [where, ot, k])
	return out


static func _pet_rules(where: String, R: Dictionary) -> Array:
	var out := []
	if R.has("stable") == R.has("gift"):
		out.append("%s: має бути або «stable» (улюбленець стайні), або «gift» (супутник із божого дару)" % where)
	if R.has("gift") and not bool(R["gift"]):
		out.append("%s: «gift» пишеться лише як true" % where)
	if R.has("stable"):
		for k in ["name", "desc"]:
			if not R.has(k):
				out.append("%s: улюбленцю стайні потрібне «%s»" % [where, k])
		_not_blank(R, ["name", "desc"], where, out)
		var D: Dictionary = R["stable"]
		if D.has("text") and not "%d" in str(D["text"]):
			out.append("%s: «stable.text» має містити %%d (відсотки хисту)" % where)
		if D.has("base") and float(D["base"]) <= 0.0:
			out.append("%s: «stable.base» має бути більшим за нуль" % where)
		if D.has("per") and float(D["per"]) < 0.0:
			out.append("%s: «stable.per» не може бути від'ємним" % where)
		if D.has("gold") and int(D["gold"]) <= 0:
			out.append("%s: «stable.gold» має бути більшим за нуль" % where)
		for r in D.get("res", _EMPTY):
			if int(D["res"][r]) <= 0:
				out.append("%s: «stable.res.%s» має бути більшим за нуль" % [where, r])
	if R.has("gift"):
		for k in ["name", "desc"]:
			if R.has(k):
				out.append("%s: у супутника з дару «%s» береться з самого дару (Divine.DEFS), тут його не пишуть" % [where, k])
		if not R.has("mechanic"):
			out.append("%s: супутник із дару без «mechanic» у бою нічого не робить" % where)
	if R.has("mechanic") and not _is_mechanic_ref(R["mechanic"], "pet"):
		out.append("%s: «mechanic» має бути \"pet/<файл>\", а не «%s»" % [where, R["mechanic"]])
	return out


static func _is_mechanic_ref(ref: String, folder: String) -> bool:
	return ref.begins_with(folder + "/") and _is_id(ref.substr(folder.length() + 1))


## Номери записів не повторюються в межах таблиці (а в нечисті — ще й окремо серед босів).
static func _unique_nums(name: String, rows: Dictionary) -> Array:
	var out := []
	var seen := {}
	var seen_boss := {}
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("num"):
			var n := int(R["num"])
			if n <= 0:
				out.append("%s/%s: «num» має бути додатним" % [name, id])
			elif seen.has(n):
				out.append("%s/%s: номер %d уже має «%s»" % [name, id, n, seen[n]])
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
		"companions":
			out.append_array(_companion_links(rows))
		"heroes":
			out.append_array(_hero_links(rows))
		"pets":
			out.append_array(_pet_links(rows))
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
	out.append_array(_mechanic_links(rows))
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


## Механіки нечисті: кожне посилання веде на файл, що походить від Mechanic, і кожен файл у mob/ і
## boss/ має запис, який на нього посилається (без сиріт).
static func _mechanic_links(rows: Dictionary) -> Array:
	var out := []
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("mechanic"):
			_mechanic_ref("mobs/" + id, "mechanic", str(R["mechanic"]), used, out)
		if R.has("boss") and R["boss"].has("mechanic"):
			_mechanic_ref("mobs/" + id, "boss.mechanic", str(R["boss"]["mechanic"]), used, out)
	out.append_array(_mechanic_orphans(["mob", "boss"], used, "mobs.json"))
	return out


## Одне посилання на механіку: файл є й походить від основи своєї теки (MECHANIC_BASES).
## Лише для перевірки: під час гри теки не переглядаються.
static func _mechanic_ref(where: String, field: String, ref: String, used: Dictionary, out: Array) -> void:
	used[ref] = true
	var Loader = load("res://scripts/mechanics/loader.gd")
	var path: String = Loader.path_of(ref)
	if not ResourceLoader.exists(path):
		out.append("%s: «%s» посилається на %s, а такого файлу нема" % [where, field, path])
		return
	var base: String = MECHANIC_BASES.get(ref.get_slice("/", 0), "")
	var s = load(path)
	if base == "" or not s is Script or not Loader.extends_base(s, base):
		out.append("%s: %s — не механіка (має походити від %s)" % [where, path, base])


## Файли механік у теках, на які не посилається жоден запис таблиці (сироти).
static func _mechanic_orphans(folders: Array, used: Dictionary, file: String) -> Array:
	var out := []
	var Loader = load("res://scripts/mechanics/loader.gd")
	for folder in folders:
		for ref in mechanic_files(folder):
			if not used.has(ref):
				out.append("механіка %s нікому не потрібна: жоден запис %s на неї не посилається" % [Loader.path_of(ref), file])
	return out


## Файли механік у теці (mob, boss, companion, pet) як посилання ("mob/chort"). Лише для перевірки й
## інструментів: у збірці теки містять .gdc і .remap, тож гра механік так не шукає.
static func mechanic_files(folder: String) -> Array:
	var out := []
	var dir := "res://scripts/mechanics/" + folder
	for f in DirAccess.get_files_at(dir):
		f = f.trim_suffix(".remap")
		if f.ends_with(".gd") or f.ends_with(".gdc"):
			var ref := folder + "/" + f.get_basename()
			if not ref in out:
				out.append(ref)
	out.sort()
	return out


static func _companion_links(rows: Dictionary) -> Array:
	var out := []
	var Data = load("res://scripts/data/data.gd")
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		var lv := int(R.get("hire", _EMPTY).get("loyalty", 0))
		if lv < 0 or lv >= Data.LOYALTY_NAMES.size():
			out.append("companions/%s: «hire.loyalty» має бути від 0 до %d (Data.LOYALTY_NAMES)" % [id, Data.LOYALTY_NAMES.size() - 1])
		if R.has("mechanic"):
			_mechanic_ref("companions/" + id, "mechanic", str(R["mechanic"]), used, out)
	out.append_array(_mechanic_orphans(["companion"], used, "companions.json"))
	return out


static func _hero_links(rows: Dictionary) -> Array:
	var out := []
	var Data = load("res://scripts/data/data.gd")
	var Story = load("res://scripts/data/story.gd")
	var steps := {}  # id кроку сюжету → скільки в нього виборів
	for ch in Story.CHAPTERS:
		for st in ch["steps"]:
			steps[st["id"]] = st.get("choices", []).size()
	for id in rows:
		var R: Dictionary = rows[id]
		var where: String = "heroes/" + id
		if R.has("base") and not table("companions").has(R["base"]):
			out.append("%s: «base» посилається на найманця «%s», якого немає в companions.json" % [where, R["base"]])
		if table("companions").has(id):
			out.append("%s: id збігається з найманцем (вигляд comp_<id> був би спільний)" % where)
		var j: Dictionary = R.get("join", _EMPTY)
		if j.has("city") and not Data.CITIES.has(j["city"]):
			out.append("%s: «join.city» — невідоме місто «%s»" % [where, j["city"]])
		if j.has("after") and not steps.has(j["after"]):
			out.append("%s: «join.after» — нема кроку сюжету «%s»" % [where, j["after"]])
		if j.has("if"):
			var parts: PackedStringArray = str(j["if"]).split("=")
			if parts.size() != 2 or not parts[1].is_valid_int():
				out.append("%s: «join.if» має бути \"крок=номер вибору\", а не «%s»" % [where, j["if"]])
			elif not steps.has(parts[0]) or int(parts[1]) < 0 or int(parts[1]) >= int(steps[parts[0]]):
				out.append("%s: «join.if» — нема кроку «%s» із вибором %s" % [where, parts[0], parts[1]])
		var dl := _hero_dialogues(R)
		for k in dl:
			for i in dl[k].size():
				if not Story.NPCS.has(dl[k][i][0]):
					out.append("%s: «%s[%d]» — мовця «%s» нема в Story.NPCS" % [where, k, i, dl[k][i][0]])
		var o: Dictionary = R.get("quest", _EMPTY).get("objective", _EMPTY)
		if o.has("loc"):
			var L: Dictionary = Data.LOCATIONS.get(o["loc"], _EMPTY)
			if L.is_empty():
				out.append("%s: «quest.objective.loc» — нема місця «%s»" % [where, o["loc"]])
			else:
				var ot := str(o.get("type", ""))
				if ot == "clear" and str(L.get("type", "")) == "dungeon":
					out.append("%s: «%s» — печера, її проходять метою «dungeon», а не «clear»" % [where, o["loc"]])
				if ot == "dungeon" and str(L.get("type", "")) != "dungeon":
					out.append("%s: «%s» — не печера" % [where, o["loc"]])
				if o.has("enemy") and not o["enemy"] in L.get("enemies", []):
					out.append("%s: «%s» не водиться в «%s»" % [where, o["enemy"], o["loc"]])
		if o.has("enemy") and not has_mob(str(o["enemy"])):
			out.append("%s: «quest.objective.enemy» посилається на нечисть «%s», якої немає в mobs.json" % [where, o["enemy"]])
	return out


static func _pet_links(rows: Dictionary) -> Array:
	var out := []
	var Camp = load("res://scripts/data/camp_data.gd")
	var Divine = load("res://scripts/data/divine.gd")
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		var where: String = "pets/" + id
		for r in R.get("stable", _EMPTY).get("res", _EMPTY):
			if not Camp.RESOURCES.has(r) and r != Camp.TROPHY:
				out.append("%s: «stable.res» — невідомий ресурс «%s» (див. CampData.RESOURCES)" % [where, r])
		if R.has("gift"):
			if not Divine.DEFS.has(id):
				out.append("%s: божого дару «%s» нема в Divine.DEFS" % [where, id])
			elif not str(Divine.DEFS[id]["slot"]) in PET_GIFT_SLOTS:
				out.append("%s: дар «%s» лежить у гнізді «%s», а супутники бувають лише в %s" % [where, id, Divine.DEFS[id]["slot"], str(PET_GIFT_SLOTS)])
		if R.has("mechanic"):
			_mechanic_ref(where, "mechanic", str(R["mechanic"]), used, out)
	# Кожен дар-супутник (гнізда «Супутник» і «Віз») має запис, інакше в бою його не видно
	for d in Divine.DEFS:
		if str(Divine.DEFS[d]["slot"]) in PET_GIFT_SLOTS and not rows.has(d):
			out.append("божий дар «%s» (гніздо «%s») не має запису в pets.json, тож у бою його не видно" % [d, Divine.DEFS[d]["slot"]])
	out.append_array(_mechanic_orphans(["pet"], used, "pets.json"))
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
	return by_num("mobs", n)


## Вид нечисті за сталим номером її боса ("" — такого нема).
static func boss_by_num(n: int) -> String:
	return str(_num_index("mobs", "boss").get(n, ""))


## Id запису таблиці за його сталим номером ("" — такого нема).
static func by_num(name: String, n: int) -> String:
	return str(_num_index(name, "").get(n, ""))


## Покажчик номер → id: за «num» запису, а sub — за «num» його вкладеного запису (боса).
static func _num_index(name: String, sub: String) -> Dictionary:
	var key := name + "/" + sub
	if not _nums.has(key):
		var idx := {}
		for id in ids(name):
			var R: Dictionary = row(name, id)
			var n = R.get("num") if sub == "" else R.get(sub, _EMPTY).get("num")
			if n != null and not idx.has(n):
				idx[n] = id
		idx.make_read_only()
		_nums[key] = idx
	return _nums[key]


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


## Посилання на механіку виду ("" — нема): boss — бойової форми боса, інакше звичайної.
static func mechanic(id: String, boss: bool = false) -> String:
	var R: Dictionary = mob(id).get("boss", _EMPTY) if boss else mob(id)
	return str(R.get("mechanic", ""))


## Голос смерті ("" — свого нема).
static func death_sound(id: String) -> String:
	return str(mob(id).get("sounds", _EMPTY).get("death", ""))


## Опис для довідника {text, tip}; порожній, якщо нема.
static func mob_wiki(id: String) -> Dictionary:
	return mob(id).get("wiki", _EMPTY)


static func boss_wiki(id: String) -> Dictionary:
	return mob(id).get("boss", _EMPTY).get("wiki", _EMPTY)


# ---------- Загін і улюбленці ----------

## Найманець (див. COMPANION_SCHEMA); для невідомого — порожній запис.
static func companion(id: String) -> Dictionary:
	return table("companions").get(id, _EMPTY)


## Найманці в порядку файлу (так їх показує корчма й довідник).
static func companion_ids() -> Array:
	return ids("companions")


## Побратим (див. HERO_SCHEMA); для невідомого — порожній запис.
static func hero(id: String) -> Dictionary:
	return table("heroes").get(id, _EMPTY)


## Побратими в порядку файлу.
static func hero_ids() -> Array:
	return ids("heroes")


## Улюбленець або супутник із дару (див. PET_SCHEMA); для невідомого — порожній запис.
static func pet(id: String) -> Dictionary:
	return table("pets").get(id, _EMPTY)


## Усі записи pets.json у порядку файлу (і стайня, і дари).
static func pet_ids() -> Array:
	return ids("pets")
