extends SceneTree
## Приводить таблиці data/*.json до єдиного вигляду (порядок полів за схемою GameDB, відступи табами,
## справжні українські літери) і перевіряє їх (GameDB.problems()).
## Запуск: godot --headless --path . -s res://tools/data_format.gd
##   CHECK=1 — нічого не переписувати, лише сказати, які файли не в єдиному вигляді (код виходу 1).
## Записи коротші за INLINE знаків пишуться в один рядок, довші — поле на рядок.

const GameDB := preload("res://scripts/core/game_db.gd")
const INLINE := 100


func _initialize() -> void:
	var check := OS.get_environment("CHECK") == "1"
	var bad := 0
	for name in GameDB.TABLES:
		var path := GameDB.path_of(name)
		var text := FileAccess.get_file_as_string(path)
		var raw = JSON.parse_string(text)
		if not raw is Dictionary:
			printerr("%s: не JSON-об'єкт" % path)
			bad += 1
			continue
		var out := format_table(name, raw)
		if out == text:
			print("%s: гаразд" % path)
		elif check:
			printerr("%s: не в єдиному вигляді (запусти без CHECK=1)" % path)
			bad += 1
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(out)
			f.close()
			print("%s: переписано" % path)
	var probs := GameDB.problems()
	for p in probs:
		printerr("  " + str(p))
	print("Проблем у даних: %d" % probs.size())
	quit(1 if bad > 0 or not probs.is_empty() else 0)


## Текст таблиці в єдиному вигляді.
static func format_table(name: String, raw: Dictionary) -> String:
	var schema: Dictionary = GameDB.TABLES[name]["schema"]
	var lines := PackedStringArray()
	var ids := raw.keys()
	for i in ids.size():
		var body := _record(raw[ids[i]], schema, 1, true)
		lines.append("\t%s: %s%s" % [JSON.stringify(str(ids[i])), body, "," if i < ids.size() - 1 else ""])
	return "{\n" + "\n".join(lines) + "\n}\n"


## Запис: в один рядок, якщо короткий, інакше поле на рядок. force_multi — завжди поле на рядок.
static func _record(rec: Dictionary, fields: Dictionary, depth: int, force_multi: bool = false) -> String:
	var keys := []
	for k in fields:
		if rec.has(k):
			keys.append(k)
	for k in rec:
		if not fields.has(k):
			keys.append(k)  # невідоме поле не губимо: на нього вкаже GameDB.problems()
	var inline := PackedStringArray()
	for k in keys:
		inline.append("%s: %s" % [JSON.stringify(k), _value(rec[k], fields.get(k, {}), depth + 1, true)])
	var one := "{" + ", ".join(inline) + "}"
	if not force_multi and one.length() + depth * 4 <= INLINE:
		return one
	var pad := "\t".repeat(depth + 1)
	var multi := PackedStringArray()
	for k in keys:
		multi.append(pad + "%s: %s" % [JSON.stringify(k), _value(rec[k], fields.get(k, {}), depth + 1, false)])
	return "{\n" + ",\n".join(multi) + "\n" + "\t".repeat(depth) + "}"


static func _value(v, f: Dictionary, depth: int, inline_only: bool) -> String:
	var t: String = f.get("type", "")
	if t == "map" and v is Dictionary:
		# Словник з довільними ключами: кожне значення за описом "of", ключі в порядку файлу
		var fields := {}
		for k in v:
			fields[k] = f.get("of", {})
		f = {"type": "record", "fields": fields}
	if v is Dictionary:
		if inline_only:
			var parts := PackedStringArray()
			var sub: Dictionary = f.get("fields", {})
			var keys := []
			for k in sub:
				if v.has(k):
					keys.append(k)
			for k in v:
				if not sub.has(k):
					keys.append(k)
			for k in keys:
				parts.append("%s: %s" % [JSON.stringify(k), _value(v[k], sub.get(k, {}), depth + 1, true)])
			return "{" + ", ".join(parts) + "}"
		return _record(v, f.get("fields", {}), depth)
	if v is Array:
		var parts := PackedStringArray()
		var of: Dictionary = {"type": "float"} if t in ["color", "vector"] else f.get("of", {})
		for x in v:
			parts.append(_value(x, of, depth + 1, true))
		var one := "[" + ", ".join(parts) + "]"
		if inline_only or one.length() + depth * 4 <= INLINE:
			return one
		# Довгий масив (розмова): елемент на рядок
		var pad := "\t".repeat(depth + 1)
		return "[\n" + pad + (",\n" + pad).join(parts) + "\n" + "\t".repeat(depth) + "]"
	if v is float or v is int:
		if t in ["int", "number"] and v == floorf(v):
			return str(int(v))
		if t == "float" or v is float:
			return var_to_str(float(v))  # точне подання: прочитане назад дає те саме число
		return str(v)
	return JSON.stringify(v)
