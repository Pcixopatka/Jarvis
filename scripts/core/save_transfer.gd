extends RefCounted
## Перенесення роду на інший пристрій без сервера: усі персонажі й спільний хутір одним текстовим кодом.
## Гра кладе код у буфер обміну, гравець сам надсилає його собі (пошта, нотатки, месенджер)
## і вставляє на іншому пристрої. Мережі гра для цього не потребує.
##
## Формат:  KZ1:<знаків у тілі>:<байтів до стискання>:<перші 8 знаків SHA-256 тіла>:<тіло>
##   тіло — base64 від стиснутого (deflate) var_to_bytes({"v": 1, "account": {...}, "heroes": [{"slot": n, "data": {...}}, ...]}).
## Пробіли й переноси рядків усередині коду дозволені: месенджери ріжуть довгий текст.
## Якщо вставлено лише початок, unpack каже, скільки знаків є й скільки треба, і гра чекає на решту.
## Розпаковується bytes_to_var без об'єктів, тож чужий код не може принести із собою скрипт.
## Перед заміною старі файли лишаються поруч із суфіксом BACKUP — щоб можна було повернути, як було.

const SaveSystem := preload("res://scripts/core/save_system.gd")
const Data := preload("res://scripts/data/data.gd")
const NameService := preload("res://scripts/game/name_service.gd")
const PREFIX := "KZ1"
const FORMAT := 1
const MAX_RAW := 8 * 1024 * 1024  # більшого збереження не буває: захист від зіпсованого заголовка
const BACKUP := ".before_transfer"
const NONE := ".before_transfer_none"  # позначка «тут до перенесення було порожньо»

static var clipboard_override = null  # тести: рядок замість справжнього буфера обміну


static func clipboard_get() -> String:
	if clipboard_override != null:
		return str(clipboard_override)
	return DisplayServer.clipboard_get()


static func clipboard_set(text: String) -> void:
	if clipboard_override != null:
		clipboard_override = text
		return
	DisplayServer.clipboard_set(text)


# ---------- Код ----------

static func _digest(body: String) -> String:
	return body.sha256_text().substr(0, 8)


static func pack(profile: Dictionary) -> String:
	var raw := var_to_bytes(profile)
	var body := Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE)).rstrip("=")
	return "%s:%d:%d:%s:%s" % [PREFIX, body.length(), raw.size(), _digest(body), body]


## Розібрати код. Повертає {"ok", "partial", "error", "have", "need", "profile"}:
##   ok — код цілий і рід у profile;  partial — вставлено лише початок (have із need знаків);  інакше error — що не так.
static func unpack(text: String) -> Dictionary:
	var out := {"ok": false, "partial": false, "error": "", "have": 0, "need": 0, "profile": {}}
	var rx := RegEx.create_from_string("\\s+")
	var t := rx.sub(text, "", true)
	var parts := t.split(":", true, 4)
	if parts.size() < 5 or not parts[0].begins_with("KZ"):
		out["error"] = "У буфері обміну немає коду роду. Спершу скопіюй його на іншому пристрої."
		return out
	if parts[0] != PREFIX:
		out["error"] = "Цей код зроблено в новішій версії гри. Спершу онови гру на цьому пристрої."
		return out
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		out["error"] = "Код пошкоджено: заголовок не читається."
		return out
	var need := int(parts[1])
	var raw_size := int(parts[2])
	var body := parts[4]
	out["need"] = need
	out["have"] = mini(body.length(), need)
	if need <= 0 or raw_size <= 0 or raw_size > MAX_RAW:
		out["error"] = "Код пошкоджено: заголовок не читається."
		return out
	if body.length() < need:
		out["partial"] = true
		return out
	body = body.substr(0, need)  # після коду могли дописати щось своє — відтинаємо
	if _digest(body) != parts[3]:
		out["error"] = "Код пошкоджено. Перевір, чи скопійовано його повністю й без змін."
		return out
	var packed := Marshalls.base64_to_raw(body + "=".repeat((4 - body.length() % 4) % 4))
	var raw := packed.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != raw_size:
		out["error"] = "Код пошкоджено: вміст не розпаковується."
		return out
	var v = bytes_to_var(raw)
	var why := check(v)
	if why != "":
		out["error"] = why
		return out
	out["ok"] = true
	out["profile"] = v
	return out


## Чи схожий розпакований вміст на рід. Порожній рядок — усе гаразд, інакше пояснення.
static func check(v) -> String:
	var bad := "Код пошкоджено: усередині не рід."
	if typeof(v) != TYPE_DICTIONARY or typeof(v.get("account")) != TYPE_DICTIONARY or typeof(v.get("heroes")) != TYPE_ARRAY:
		return bad
	if int(v.get("v", 0)) > FORMAT:
		return "Цей код зроблено в новішій версії гри. Спершу онови гру на цьому пристрої."
	var heroes: Array = v["heroes"]
	if heroes.is_empty() or heroes.size() > SaveSystem.MAX_SLOTS:
		return bad
	var seen := {}
	for h in heroes:
		if typeof(h) != TYPE_DICTIONARY or typeof(h.get("data")) != TYPE_DICTIONARY:
			return bad
		var slot := int(h.get("slot", 0))
		if slot < 1 or slot > SaveSystem.MAX_SLOTS or seen.has(slot):
			return bad
		seen[slot] = true
		var d: Dictionary = h["data"]
		if typeof(d.get("player")) != TYPE_DICTIONARY or typeof(d.get("world")) != TYPE_DICTIONARY:
			return bad
		if int(d.get("version", 0)) > SaveSystem.SAVE_VERSION:
			return "Цей код зроблено в новішій версії гри. Спершу онови гру на цьому пристрої."
		var p: Dictionary = d["player"]
		var lvl := int(p.get("level", 0))
		if lvl < 1 or lvl > Data.Classes.BASE_LEVEL_MAX or typeof(p.get("job", "")) != TYPE_STRING:
			return bad
		if not Data.Classes.CLASSES.has(str(p.get("job", "peasant"))):
			return "У коді є герой класу, якого ця версія гри не знає. Спершу онови гру на цьому пристрої."
		# ім'я, якщо є, має бути рядком; недопустиме не причина відмови: при вході воно стане порожнім
		if p.has("nick") and typeof(p["nick"]) != TYPE_STRING:
			return bad
	return ""


## Рядки для підтвердження: хто в коді.
static func summary(profile: Dictionary) -> Array:
	var out := []
	for h in profile["heroes"]:
		var p: Dictionary = h["data"]["player"]
		var job := str(p.get("job", "cossack"))
		var title: String = Data.Classes.CLASSES.get(job, {}).get("name", "Герой")
		if str(p.get("rank", "")) == "hetman":
			title = "Гетьман"
		var nick: String = NameService.from_save(p.get("nick", ""))
		out.append("Слот %d: %s%s, рівень %d" % [int(h["slot"]), (nick + ", ") if nick != "" else "", title, int(p.get("level", 1))])
	return out


# ---------- Файли ----------

static func _read_var(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var d = f.get_var()
		f.close()
		if typeof(d) == TYPE_DICTIONARY and not d.is_empty():
			return d
	return {}


## Зібрати рід із файлів пристрою. paths — {слот: шлях до збереження героя}.
static func collect(paths: Dictionary, account_path: String) -> Dictionary:
	var heroes := []
	for slot in paths:
		var d := SaveSystem.load_data(paths[slot])
		if not d.is_empty():
			heroes.append({"slot": int(slot), "data": d})
	return {"v": FORMAT, "account": _read_var(account_path), "heroes": heroes, "made": int(Time.get_unix_time_from_system())}


static func _all_files(paths: Dictionary, account_path: String) -> Array:
	var out := [account_path]
	for slot in paths:
		out.append(paths[slot])
	return out


static func has_backup(paths: Dictionary, account_path: String) -> bool:
	for p in _all_files(paths, account_path):
		if FileAccess.file_exists(p + BACKUP) or FileAccess.file_exists(p + NONE):
			return true
	return false


static func _drop_backup(paths: Dictionary, account_path: String) -> void:
	for p in _all_files(paths, account_path):
		for suffix in [BACKUP, NONE]:
			if FileAccess.file_exists(p + suffix):
				DirAccess.remove_absolute(p + suffix)


## Замінити рід на пристрої вмістом коду. Те, що було, лишається в запасі (див. restore).
static func apply(profile: Dictionary, paths: Dictionary, account_path: String) -> bool:
	if check(profile) != "":
		return false
	for h in profile["heroes"]:
		if not paths.has(int(h["slot"])):
			return false  # на цьому пристрої такого слота нема
	_drop_backup(paths, account_path)
	for p in _all_files(paths, account_path):
		var src: String = p if FileAccess.file_exists(p) else (p + ".bak" if FileAccess.file_exists(p + ".bak") else "")
		if src != "":
			DirAccess.copy_absolute(src, p + BACKUP)
		else:
			var mark := FileAccess.open(p + NONE, FileAccess.WRITE)
			if mark:
				mark.close()
		SaveSystem.delete(p)
	var ok := true
	for h in profile["heroes"]:
		var d := SaveSystem.migrate(h["data"])
		if d.is_empty() or not SaveSystem.save(d, paths[int(h["slot"])]):
			ok = false
	var acc: Dictionary = profile["account"]
	if not acc.is_empty():
		var f := FileAccess.open(account_path, FileAccess.WRITE)
		if f == null:
			ok = false
		else:
			f.store_var(acc)
			f.close()
	if not ok:
		restore(paths, account_path)
	return ok


## Повернути рід, який був на пристрої до останнього перенесення.
static func restore(paths: Dictionary, account_path: String) -> bool:
	if not has_backup(paths, account_path):
		return false
	for p in _all_files(paths, account_path):
		if FileAccess.file_exists(p + BACKUP):
			SaveSystem.delete(p)
			DirAccess.rename_absolute(p + BACKUP, p)
		elif FileAccess.file_exists(p + NONE):
			SaveSystem.delete(p)
			DirAccess.remove_absolute(p + NONE)
	return true
