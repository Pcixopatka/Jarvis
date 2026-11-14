extends Node
## Обліковий запис і хмарне збереження роду (автозавантаження «Cloud»). Firebase через REST (FirebaseApi), мережею
## ходить транспорт: справжній (cloud_transport.gd) чи підставлений тестами. Опис і будова документа — docs/online.md.
##
## Нічого не робить, доки не покликали start(): гра кличе його лише справжньою головною сценою, тести й
## інструменти (-s) — ніколи, тож вони в мережу не ходять. Справжній транспорт з'являється лише в start(), коли
## не підставлено свого. Кожен екземпляр самостійний (стану в static var нема, лише числа з налаштувань): перевірка
## на справжньому проєкті тримає два «пристрої» двома екземплярами з різними файлами сеансу й збережень.
##
## Стани (state): off — не запущено; connecting; offline — нема зв'язку (повтор за RETRY_DELAYS); guest; email;
## signed_out — гравець вийшов. Окремо: conflict — у хмарі й на пристрої різні роди, гравець має вибрати;
## newer_cloud — у хмарі рід новішої версії гри (тоді ні завантаження, ні вивантаження). Зміна — сигнал changed.
## Усе мовчки: гра ніколи не чекає мережі й сама не показує помилок, крім банерів, про які просить notice.
##
## Сеанс — файл session_path (store_var): uid, ключ сеансу (refresh token), пошта, гість, випадковий ідентифікатор
## пристрою, rev і updateTime останньої синхронізації, відбиток вмісту, час останнього збереження в хмару, signed_out.
## Ключ входу (id token) живе лише в пам'яті й оновлюється, коли до кінця його дії лишилось TOKEN_MARGIN секунд,
## і раз — на відповідь 401.

signal changed
signal notice(text: String, good: bool)  # банер для гравця
signal conflict_found  # щойно знайдено розбіжність (раз на кожну)

const FirebaseApi := preload("res://scripts/core/firebase_api.gd")
const SaveTransfer := preload("res://scripts/core/save_transfer.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const TransportScript := preload("res://scripts/core/cloud_transport.gd")

const SESSION_PATH := "user://cloud.session"

const OFF := "off"
const CONNECTING := "connecting"
const OFFLINE := "offline"
const GUEST := "guest"
const EMAIL := "email"
const SIGNED_OUT := "signed_out"

const DOWNLOADED := "Рід завантажено з хмари. Персонажів: %d."
const CONFLICT_PLAY := "У хмарі є новіший рід з іншого пристрою. Вийди в головне меню, щоб вибрати."
const SESSION_ENDED := "Сеанс завершився. Увійди знову."
const BOUND := "Пошту прив'язано. Тепер рід можна відновити на будь-якому пристрої."
const NEWER := "Рід у хмарі збережено новішою версією гри. Онови гру на цьому пристрої."
const RESET_SENT := "Якщо така пошта є, на неї надійшов лист зі зміною пароля. Перевір і папку «Спам»."
const TOO_BIG := "Рід завеликий для хмари. Він зберігається лише на цьому пристрої."
const SAME := "У хмарі вже цей самий рід."
const SAVED := "Рід збережено в хмару."

## Робочі копії налаштувань (запис «cloud»; їх заповнює apply_settings()).
static var TIMEOUT: float
static var MAX_SAVE: int
static var UPLOAD_GAP: float
static var UPLOAD_MIN_GAP: float
static var CHECK_GAP: float
static var RETRY_DELAYS: Array
static var TOKEN_MARGIN: float
static var BOARD_GAP: float
static var BOARD_TOP: int
static var BOARD_CACHE: float


static func _static_init() -> void:
	apply_settings()


static func apply_settings() -> void:
	var S := GameDB.settings("cloud")
	TIMEOUT = S["timeout"]
	MAX_SAVE = S["max_save"]
	UPLOAD_GAP = S["upload_gap"]
	UPLOAD_MIN_GAP = S["upload_min_gap"]
	CHECK_GAP = S["check_gap"]
	RETRY_DELAYS = S["retry_delays"]
	TOKEN_MARGIN = S["token_margin"]
	BOARD_GAP = S["board_gap"]
	BOARD_TOP = S["board_top"]
	BOARD_CACHE = S["board_cache"]


var state := OFF
var started := false
var conflict := false
var conflict_doc := {}  # документ у хмарі, з яким розбіжність (див. _read_doc)
var newer_cloud := false
var too_big := false
var last_error := ""  # останнє, що варто сказати гравцеві на екрані облікового запису
var last_skip := ""  # чому останнє збереження в хмару не пішло (для тестів): same, no_heroes, conflict, newer, signed_out, too_big, gap, busy

## Налаштування екземпляра (start(cfg) бере їх зі словника з тими самими ключами)
var transport: Object = null  # будь-що з send(method, url, headers, body, done)
var session_path := SESSION_PATH
var paths := {}  # {слот: шлях збереження}
var paths_fn := Callable()  # або функція, що їх дає (гра: слоти міняються)
var account_path: String = SaveSystem.ACCOUNT_PATH
var can_apply := Callable()  # чи можна зараз замінити рід на пристрої (гра: лише в головному меню)
var apply_fn := Callable()  # (profile) -> bool: замінити рід; порожньо — SaveTransfer.apply
var clock := Callable()  # () -> секунди; порожньо — справжній час
## МІСЦЕ ДЛЯ РОЗШИРЕННЯ: (uid) -> Array шляхів інших документів, які теж треба стерти разом з обліковим записом.
## Рядки спільних таблиць (boards/{рекорд}/scores/{uid}) doc_paths додає сам.
var extra_doc_paths := Callable()
var rows_fn := Callable()  # () -> {таблиця: {"value", "name", "cls", "level"}}: рядки роду для спільних таблиць

var session := {}
var _id_token := ""
var _token_exp := 0.0
var _retry_step := 0
var _retry_at := -1.0
var _next_auto := 0.0
var _last_check := -1.0e12
var _last_try := -1.0e12  # коли востаннє слали рід у хмару
var _pending := {}  # документ, який треба завантажити, щойно гра в головному меню
var _lock := false
var requests := 0  # скільки запитів послано (для тестів і перевірки)
var _last_board := -1.0e12  # коли востаннє слали рядки таблиць
var _board_cache := {}  # таблиця -> {"at", "rows", "place", "mine"}
var _reported := {}  # "таблиця/uid" -> true: на кого вже скаржились за цей запуск

signal _unlocked


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if started:
		poll()


func now() -> float:
	return float(clock.call()) if clock.is_valid() else Time.get_unix_time_from_system()


# ================= Запуск =================

## Запустити: прочитати сеанс, оновити ключ або тихо створити гостя, перевірити хмару.
## cfg — будь-які з: transport, session_path, paths, paths_fn, account_path, can_apply, apply_fn, clock, extra_doc_paths.
func start(cfg: Dictionary = {}) -> void:
	if started:
		return
	for k in cfg:
		set(k, cfg[k])
	if transport == null:
		var t := TransportScript.new()
		t.timeout = TIMEOUT
		add_child(t)
		transport = t
	started = true
	_load_session()
	_next_auto = now() + UPLOAD_GAP
	_last_try = float(session["last_upload"])
	await _locked(_connect)


func is_signed_in() -> bool:
	return state == GUEST or state == EMAIL


func is_busy() -> bool:
	return _lock


func email() -> String:
	return str(session.get("email", ""))


func uid() -> String:
	return str(session.get("uid", ""))


func device_id() -> String:
	return str(session.get("device", ""))


## Коли рід востаннє збігся з хмарою (секунди Unix; 0 — ще не було).
func last_sync() -> int:
	return int(session.get("last_sync", 0))


# ================= Сеанс =================

func _blank_session(device: String = "") -> Dictionary:
	if device == "":
		device = _new_device_id()
	return {"uid": "", "refresh": "", "email": "", "guest": true, "device": device, "synced_rev": 0, "seen_rev": 0,
		"seen_update": "", "synced_digest": "", "synced_line": "", "last_upload": 0, "last_sync": 0, "signed_out": false,
		"boards_sent": {}}


static func _new_device_id() -> String:
	var c := Crypto.new()
	return "d" + c.generate_random_bytes(12).hex_encode()  # 25 знаків, межа правил 64


func _load_session() -> void:
	session = _blank_session("x")
	var d = null
	if FileAccess.file_exists(session_path):
		var f := FileAccess.open(session_path, FileAccess.READ)
		if f:
			d = f.get_var()
			f.close()
	if d is Dictionary:
		for k in session:
			if d.has(k) and typeof(d[k]) == typeof(session[k]):
				session[k] = d[k]
	if str(session["device"]) in ["", "x"] or str(session["device"]).length() > 64:
		session["device"] = _new_device_id()
		_save_session()


func _save_session() -> void:
	SaveSystem.write_var(session_path, session)


## Забути обліковий запис на цьому пристрої (ідентифікатор пристрою лишається).
func _clear_session(signed_out: bool) -> void:
	var keep_email := email()
	session = _blank_session(device_id())
	session["signed_out"] = signed_out
	session["email"] = keep_email if signed_out else ""
	_id_token = ""
	_token_exp = 0.0
	conflict = false
	conflict_doc = {}
	newer_cloud = false
	_pending = {}
	_board_cache = {}
	_save_session()


func _set_state(s: String) -> void:
	state = s
	changed.emit()


# ================= Черга =================

## Одна справа з мережею за раз: решта чекають своєї черги.
func _locked(fn: Callable, args: Array = []):
	while _lock:
		await _unlocked
	_lock = true
	changed.emit()
	var r = await fn.callv(args)
	_lock = false
	changed.emit()
	_unlocked.emit()
	return r


## Послати запит і дочекатися відповіді: {"net" (немає зв'язку), "code", "text"}.
func _send(req: Dictionary) -> Dictionary:
	var box := _Reply.new()
	requests += 1
	transport.send(req["method"], req["url"], req["headers"], req["body"], box.finish)
	if not box.done:
		await box.finished
	return {"net": not box.ok, "code": box.code, "text": box.text}


class _Reply:
	extends RefCounted
	signal finished
	var done := false
	var ok := false
	var code := 0
	var text := ""

	func finish(ok_: bool, code_: int, text_: String) -> void:
		done = true
		ok = ok_
		code = code_
		text = text_
		finished.emit()


# ================= Ключ входу =================

func _take_tokens(a: Dictionary) -> void:
	_id_token = a["id_token"]
	_token_exp = now() + float(a["expires_in"])
	if a["refresh_token"] != "":
		session["refresh"] = a["refresh_token"]


## Свіжий ключ входу. Повертає "" — є; "net" — немає зв'язку; "dead" — сеанс скінчився; інакше код помилки.
func _ensure_token(force: bool = false) -> String:
	if not force and _id_token != "" and now() < _token_exp - TOKEN_MARGIN:
		return ""
	if str(session["refresh"]) == "":
		return "dead"
	var r := await _send(FirebaseApi.refresh(session["refresh"]))
	if r["net"]:
		return "net"
	var a := FirebaseApi.parse_auth(r["code"], r["text"])
	if not a["ok"]:
		return "dead" if FirebaseApi.is_dead_session(a["error"]) else a["error"]
	_take_tokens(a)
	_save_session()
	return ""


## Сеанс скінчився: гостеві тихо новий гість, обліковий запис із поштою — «увійди знову».
func _session_dead() -> void:
	if bool(session["guest"]):
		_clear_session(false)
		await _new_guest()
	else:
		_clear_session(true)
		last_error = SESSION_ENDED
		_set_state(SIGNED_OUT)


func _new_guest() -> bool:
	var r := await _send(FirebaseApi.sign_up_guest())
	if r["net"]:
		_go_offline()
		return false
	var a := FirebaseApi.parse_auth(r["code"], r["text"])
	if not a["ok"]:
		last_error = FirebaseApi.message(a["error"])
		_go_offline()
		return false
	session["uid"] = a["uid"]
	session["guest"] = true
	session["email"] = ""
	session["signed_out"] = false
	_take_tokens(a)
	_save_session()
	_set_state(GUEST)
	return true


func _go_offline() -> void:
	var delays: Array = RETRY_DELAYS
	_retry_at = now() + float(delays[mini(_retry_step, delays.size() - 1)])
	_retry_step += 1
	_set_state(OFFLINE)


## Вхід за сеансом (або новий гість) і перевірка хмари.
func _connect() -> void:
	if bool(session["signed_out"]):
		_set_state(SIGNED_OUT)
		return
	_set_state(CONNECTING)
	if str(session["uid"]) != "" and str(session["refresh"]) != "":
		var e := await _ensure_token(true)
		if e == "net":
			_go_offline()
			return
		if e == "dead":
			await _session_dead()
			if not is_signed_in():
				return
		elif e != "":
			_go_offline()
			return
		else:
			_set_state(GUEST if bool(session["guest"]) else EMAIL)
	elif not await _new_guest():
		return
	_retry_step = 0
	_retry_at = -1.0
	await _check()


## Запит до Firestore з ключем входу; на 401 — новий ключ і ще раз. {"net", "code", "text"}; "dead": true — сеанс скінчився.
func _fs(build: Callable) -> Dictionary:
	for attempt in 2:
		var e := await _ensure_token(attempt > 0)
		if e == "net":
			return {"net": true, "code": 0, "text": ""}
		if e != "":
			return {"net": false, "code": 0, "text": "", "dead": e == "dead"}
		var r := await _send(build.call(_id_token))
		if r["code"] != 401:
			return r
	return {"net": false, "code": 401, "text": ""}


## Мережева невдача посеред справи: offline чи кінець сеансу. true — справу треба кинути.
func _failed(r: Dictionary) -> bool:
	if r["net"]:
		_go_offline()
		return true
	if r.get("dead", false):
		await _session_dead()
		return true
	return false


# ================= Що в хмарі й на пристрої =================

## Відбиток роду без часу збирання («made»): однаковий рід — однаковий відбиток, хоч де й коли його зібрано.
## JSON з ключами за абеткою (сортує рушій, не GDScript) і повною точністю дробових: порядок ключів у файлах
## значення не має. Копія лише верхнього рівня — щоб прибрати «made», глибокої не треба.
static func digest(profile: Dictionary) -> String:
	var p := profile
	if p.has("made"):
		p = profile.duplicate()
		p.erase("made")
	return JSON.stringify(p, "", true, true).sha256_text()


func _paths() -> Dictionary:
	return paths_fn.call() if paths_fn.is_valid() else paths


## Рід на пристрої: {"profile", "empty", "digest"} (і "lines", коли with_lines). Один collect і один відбиток:
## решту (рядки героїв, код) рахує лише той, кому вони справді потрібні.
func local(with_lines: bool = true) -> Dictionary:
	var prof := SaveTransfer.collect(_paths(), account_path)
	var empty: bool = prof["heroes"].is_empty()
	var out := {"profile": prof, "empty": empty, "digest": "" if empty else digest(prof)}
	if with_lines:
		out["lines"] = [] if empty else SaveTransfer.summary(prof)
	return out


## Новий випадковий родовід (≤ 32 знаків): ним позначено рід, що свідомо замінив хмарний.
static func new_line() -> String:
	return "l" + Crypto.new().generate_random_bytes(12).hex_encode()


## Документ players/{uid}: {"rev", "ver", "update_time", "device", "lines", "made", "newer", "corrupt", "profile", "digest"}.
func _read_doc(text: String) -> Dictionary:
	var d := FirebaseApi.parse_doc(text)
	var f: Dictionary = d.get("fields", {})
	var summ = f.get("summary", {})
	if not summ is Dictionary:
		summ = {}
	var lines := []
	for l in summ.get("heroes", []):
		lines.append(str(l))
	var out := {"rev": int(f.get("rev", 0)), "ver": int(f.get("ver", 0)), "update_time": str(d.get("update_time", "")),
		"device": str(f.get("device", "")), "lines": lines, "made": int(summ.get("made", 0)), "updated": FirebaseApi.ts_unix(f.get("updated", "")),
		"line": str(summ.get("line", "")),
		"newer": false, "corrupt": false, "profile": {}, "digest": ""}
	out["newer"] = out["ver"] > SaveSystem.SAVE_VERSION
	if not out["newer"]:
		var u := SaveTransfer.unpack(str(f.get("save", "")))
		if u["ok"]:
			out["profile"] = u["profile"]
			out["digest"] = digest(u["profile"])
		elif str(u["error"]).contains("новішій версії"):
			out["newer"] = true
		else:
			out["corrupt"] = true
	return out


func _adopt(doc_rev: int, update_time: String, dig: String, line: String) -> void:
	session["synced_line"] = line
	session["synced_rev"] = doc_rev
	session["seen_rev"] = doc_rev
	session["seen_update"] = update_time
	session["synced_digest"] = dig
	session["last_sync"] = int(now())
	conflict = false
	conflict_doc = {}
	_save_session()


func _player_path() -> String:
	return FirebaseApi.player_path(uid())


## Перевірити хмару: що там і що з цим робити (див. docs/online.md, «Порівняння»).
func _check() -> void:
	if not is_signed_in():
		return
	_last_check = now()
	var r := await _fs(func(t): return FirebaseApi.get_doc(_player_path(), t))
	if await _failed(r):
		return
	if r["code"] == 404:
		newer_cloud = false
		conflict = false
		conflict_doc = {}
		session["seen_update"] = ""
		session["seen_rev"] = 0
		session["synced_rev"] = 0
		session["synced_line"] = ""  # документа нема (чи його стерли): перший запис почне новий родовід
		_save_session()
		changed.emit()
		await _upload(false)
		return
	if r["code"] != 200:
		last_error = FirebaseApi.FAILED
		changed.emit()
		return
	await _decide(_read_doc(r["text"]))


func _decide(doc: Dictionary) -> void:
	newer_cloud = doc["newer"]
	if newer_cloud:
		conflict = false
		conflict_doc = {}
		_pending = {}
		changed.emit()
		return
	if doc["corrupt"]:
		# у хмарі щось нечитне, а не рід: пристрій пише свій поверх
		session["seen_update"] = doc["update_time"]
		session["seen_rev"] = doc["rev"]
		changed.emit()
		await _upload(true, {}, true)
		return
	if int(session["synced_rev"]) > 0 and doc["rev"] == int(session["synced_rev"]):
		# у хмарі те, що цей пристрій синхронізував востаннє: тягти нічого, своє нове піде як завжди
		session["seen_update"] = doc["update_time"]
		session["seen_rev"] = doc["rev"]
		conflict = false
		conflict_doc = {}
		_save_session()
		changed.emit()
		await _upload(false)
		return
	var loc := local(false)
	if loc["empty"]:
		await _download(doc)
		return
	if loc["digest"] == doc["digest"]:
		_adopt(doc["rev"], doc["update_time"], doc["digest"], doc["line"])
		changed.emit()
		return
	if loc["digest"] == str(session["synced_digest"]) and doc["line"] != "" and doc["line"] == str(session["synced_line"]):
		# той самий родовід, а на пристрої відтоді нічого не мінялось: інший пристрій просто грав далі
		await _download(doc)
		return
	var fresh: bool = not conflict or str(conflict_doc.get("update_time", "")) != doc["update_time"]
	conflict = true
	conflict_doc = doc
	changed.emit()
	if fresh:
		conflict_found.emit()


func _can_apply() -> bool:
	return bool(can_apply.call()) if can_apply.is_valid() else true


## Замінити рід на пристрої родом із хмари (лише коли гра в головному меню; інакше — щойно туди повернуться).
func _download(doc: Dictionary) -> bool:
	if not _can_apply():
		_pending = doc
		changed.emit()
		return false
	_pending = {}
	var prof: Dictionary = doc["profile"]
	var ok: bool = apply_fn.call(prof) if apply_fn.is_valid() else SaveTransfer.apply(prof, _paths(), account_path)
	if not ok:
		last_error = FirebaseApi.FAILED
		changed.emit()
		return false
	var loc := local(false)
	_adopt(doc["rev"], doc["update_time"], loc["digest"], doc["line"])
	changed.emit()
	notice.emit(DOWNLOADED % prof["heroes"].size(), true)
	return true


# ================= Збереження в хмару =================

## keep — гравець вибрав свій рід замість хмарного: слати й тоді, коли відбиток той самий.
## loc — уже зібраний рід (local(false)), щоб не збирати вдруге; fresh_line — новий родовід (свідома заміна хмарного).
## Повертає {"ok", "skip" (чому не слали), "error"}.
func _upload(keep: bool, loc: Dictionary = {}, fresh_line: bool = false) -> Dictionary:
	last_skip = ""
	var why := ""
	if not is_signed_in():
		why = "signed_out"
	elif newer_cloud:
		why = "newer"
	elif conflict and not keep:
		why = "conflict"
	if why != "":
		last_skip = why
		return {"ok": false, "skip": why, "error": ""}
	if loc.is_empty():
		loc = local(false)
	if loc["empty"]:
		last_skip = "no_heroes"
		return {"ok": false, "skip": "no_heroes", "error": ""}
	if not keep and loc["digest"] == str(session["synced_digest"]) and str(session["seen_update"]) != "":
		last_skip = "same"
		return {"ok": true, "skip": "same", "error": ""}
	var code := SaveTransfer.pack(loc["profile"])  # код — лише коли справді шлемо
	too_big = code.length() > MAX_SAVE
	if too_big:
		last_skip = "too_big"
		changed.emit()
		return {"ok": false, "skip": "too_big", "error": TOO_BIG}
	var line := str(session["synced_line"])
	if fresh_line or line == "":
		line = new_line()
	var pre := {"update_time": session["seen_update"]} if str(session["seen_update"]) != "" else {"exists": false}
	var rev := int(session["seen_rev"]) + 1
	var t := int(now())
	var fields := {"save": code, "rev": rev, "ver": SaveSystem.SAVE_VERSION, "updated": FirebaseApi.ts(t),
		"device": device_id(), "summary": {"heroes": SaveTransfer.summary(loc["profile"]), "made": int(loc["profile"].get("made", t)), "line": line}}
	_last_try = now()
	var r := await _fs(func(tok): return FirebaseApi.patch_doc(_player_path(), tok, fields, pre))
	if await _failed(r):
		return {"ok": false, "skip": "", "error": FirebaseApi.NO_NET}
	if r["code"] == 200:
		var d := FirebaseApi.parse_doc(r["text"])
		_adopt(rev, str(d.get("update_time", "")), loc["digest"], line)
		session["last_upload"] = t
		_save_session()
		changed.emit()
		return {"ok": true, "skip": "", "error": ""}
	var err := FirebaseApi.error_code(r["text"])
	if err in ["FAILED_PRECONDITION", "ALREADY_EXISTS", "NOT_FOUND"]:
		# у хмарі вже не те, що бачили: хтось писав (чи наш запис дійшов, а відповідь загубилась)
		var g := await _fs(func(tok): return FirebaseApi.get_doc(_player_path(), tok))
		if await _failed(g):
			return {"ok": false, "skip": "", "error": FirebaseApi.NO_NET}
		if g["code"] == 404:
			if pre.has("exists"):
				return {"ok": false, "skip": "", "error": FirebaseApi.FAILED}
			session["seen_update"] = ""  # документ стерли: пишемо як уперше, з новим родоводом
			session["seen_rev"] = 0
			return await _upload(keep, loc, true)
		if g["code"] == 200:
			var doc := _read_doc(g["text"])
			if doc["device"] == device_id() and doc["digest"] == loc["digest"]:
				_adopt(doc["rev"], doc["update_time"], doc["digest"], doc["line"])  # наш власний запис, відповідь на який загубилась
				session["last_upload"] = t
				_save_session()
				changed.emit()
				return {"ok": true, "skip": "", "error": ""}
			conflict = false  # _decide вирішить наново за свіжим документом
			await _decide(doc)
			return {"ok": false, "skip": "conflict" if conflict else "", "error": ""}
	last_error = FirebaseApi.FAILED
	changed.emit()
	return {"ok": false, "skip": "", "error": FirebaseApi.FAILED}


## Розклад: що UPLOAD_GAP секунд гра пробує зберегти рід у хмару; без зв'язку — повтор за RETRY_DELAYS.
func poll() -> void:
	if not started or _lock:
		return
	var t := now()
	if state == OFFLINE and _retry_at >= 0.0 and t >= _retry_at:
		_locked(_connect)
	elif is_signed_in() and t >= _next_auto:
		_next_auto = t + UPLOAD_GAP
		_locked(_auto_upload)


func _auto_upload() -> Dictionary:
	if now() - _last_try < UPLOAD_MIN_GAP:
		last_skip = "gap"
		return {"ok": false, "skip": "gap", "error": ""}
	return await _upload(false)


## Головне меню: раз на CHECK_GAP секунд — перевірка хмари, інакше — звичайна спроба зберегти.
func on_main_menu() -> void:
	if not started:
		return
	if state == OFFLINE:
		return
	await _locked(_menu_check)


## Проміжок судимо вже в черзі: якщо перевірка щойно була (скажімо, на запуску), другої не треба.
func _menu_check() -> void:
	if _pending.is_empty() and now() - _last_check < CHECK_GAP:
		await _auto_upload()
		return
	if not _pending.is_empty() and _can_apply():
		if await _download(_pending):
			return
	await _check()


## Гру згорнули (збереження вже записано): спробувати зберегти й у хмару.
func on_focus_out() -> void:
	if started and is_signed_in():
		await _locked(_auto_upload)


## «Зберегти в хмару зараз»: без чекання проміжку. {"ok", "text"}.
func upload_now() -> Dictionary:
	if not started:
		return {"ok": false, "text": FirebaseApi.NO_NET}
	return await _locked(_manual_upload)


func _manual_upload() -> Dictionary:
	if state == OFFLINE:
		await _connect()
	if not is_signed_in():
		return {"ok": false, "text": FirebaseApi.NO_NET if state == OFFLINE else FirebaseApi.FAILED}
	var r := await _upload(false)
	if r["ok"]:
		return {"ok": true, "text": SAME if r["skip"] == "same" else SAVED}
	match r["skip"]:
		"no_heroes":
			return {"ok": false, "text": "На цьому пристрої ще немає персонажів."}
		"newer":
			return {"ok": false, "text": NEWER}
		"conflict":
			return {"ok": false, "text": "Спершу вибери, який рід лишити."}
	return {"ok": false, "text": r["error"] if r["error"] != "" else FirebaseApi.FAILED}


## «Спробувати ще раз»: з'єднатися негайно.
func retry() -> void:
	if not started:
		return
	_retry_step = 0
	await _locked(_connect)


# ================= Розбіжність =================

## «Взяти рід із хмари».
func take_cloud() -> Dictionary:
	return await _locked(_take_cloud)


func _take_cloud() -> Dictionary:
	if not conflict or conflict_doc.is_empty():
		return {"ok": false, "text": FirebaseApi.FAILED}
	var n: int = conflict_doc["profile"].get("heroes", []).size()
	if await _download(conflict_doc):
		return {"ok": true, "text": DOWNLOADED % n}
	return {"ok": false, "text": FirebaseApi.FAILED}


## «Лишити рід із цього пристрою»: записати свій поверх хмарного (зі свіжою міткою того, що там).
func keep_local() -> Dictionary:
	return await _locked(_keep_local)


func _keep_local() -> Dictionary:
	if not conflict or conflict_doc.is_empty():
		return {"ok": false, "text": FirebaseApi.FAILED}
	session["seen_update"] = conflict_doc["update_time"]
	session["seen_rev"] = conflict_doc["rev"]
	var r := await _upload(true, {}, true)
	if r["ok"]:
		return {"ok": true, "text": SAVED}
	return {"ok": false, "text": r["error"] if r["error"] != "" else ("" if conflict else FirebaseApi.FAILED)}


# ================= Обліковий запис =================

static func email_ok(e: String) -> bool:
	return RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s.]{2,}$").search(e.strip_edges()) != null


## Перевірка на пристрої до запиту: "" — годиться, інакше причина.
static func form_problem(e: String, password: String, need_password: bool = true) -> String:
	if not email_ok(e):
		return FirebaseApi.MESSAGES["INVALID_EMAIL"]
	if need_password and password.length() < 6:
		return FirebaseApi.MESSAGES["WEAK_PASSWORD"]
	return ""


func _fail(err: String) -> Dictionary:
	return {"ok": false, "text": FirebaseApi.message(err), "code": err}


## «Захистити рід: прив'язати пошту» (лише гість): uid і документ лишаються ті самі.
func bind_email(e: String, password: String) -> Dictionary:
	return await _locked(_bind_email, [e.strip_edges(), password])


func _bind_email(e: String, password: String) -> Dictionary:
	if state != GUEST:
		return _fail("")
	var tok := await _ensure_token()
	if tok == "net":
		return _fail("net")
	if tok == "dead":
		await _session_dead()
		return _fail("")
	var r := await _send(FirebaseApi.link_email(_id_token, e, password))
	if r["net"]:
		return _fail("net")
	var a := FirebaseApi.parse_auth(r["code"], r["text"])
	if not a["ok"]:
		return _fail(a["error"])
	_take_tokens(a)
	session["email"] = a["email"] if a["email"] != "" else e
	session["guest"] = false
	_save_session()
	last_error = ""
	_set_state(EMAIL)
	notice.emit(BOUND, true)
	return {"ok": true, "text": BOUND, "code": ""}


## «Увійти в наявний обліковий запис» / «Увійти». Гість, з якого входять, стирається (документ і обліковий запис).
func sign_in(e: String, password: String) -> Dictionary:
	if not started:
		return _fail("net")
	return await _locked(_sign_in, [e.strip_edges(), password])


func _sign_in(e: String, password: String) -> Dictionary:
	var r := await _send(FirebaseApi.sign_in(e, password))
	if r["net"]:
		return _fail("net")
	var a := FirebaseApi.parse_auth(r["code"], r["text"])
	if not a["ok"]:
		return _fail(a["error"])
	if bool(session["guest"]) and uid() != "" and uid() != a["uid"] and not bool(session["signed_out"]):
		await _drop_guest()  # як вийде: збій тут не заважає входу
	var dev := device_id()
	session = _blank_session(dev)
	session["uid"] = a["uid"]
	session["email"] = a["email"] if a["email"] != "" else e
	session["guest"] = false
	_take_tokens(a)
	_save_session()
	conflict = false
	conflict_doc = {}
	newer_cloud = false
	last_error = ""
	_retry_step = 0
	_set_state(EMAIL)
	await _check()
	return {"ok": true, "text": "", "code": ""}


## Стерти нинішнього гостя (його документ і обліковий запис) його ж ключем. Помилки не важать.
func _drop_guest() -> void:
	if await _ensure_token() != "":
		return
	var tok := _id_token
	for p in doc_paths(uid()):
		await _send(FirebaseApi.delete_doc(p, tok))
	await _send(FirebaseApi.delete_account(tok))


## «Забув пароль»: відповідь завжди та сама, щоб не видати, чи є така пошта.
func send_reset(e: String) -> Dictionary:
	e = e.strip_edges()
	if not email_ok(e):
		return _fail("INVALID_EMAIL")
	if transport == null:
		return _fail("net")
	var r := await _send(FirebaseApi.send_reset(e))
	if r["net"]:
		return _fail("net")
	return {"ok": true, "text": RESET_SENT, "code": ""}


## «Вийти з облікового запису»: рід лишається на пристрої, у хмару більше не йде, гість не створюється.
func sign_out() -> void:
	_clear_session(true)
	last_error = ""
	_set_state(SIGNED_OUT)


## «Грати як гість» після виходу.
func play_as_guest() -> void:
	if not started:
		return
	session["signed_out"] = false
	session["uid"] = ""
	session["refresh"] = ""
	session["guest"] = true
	_save_session()
	last_error = ""
	await _locked(_connect)


## Таблиці гравців: рекорди з «board» у data/records.json (назва таблиці — id рекорду).
static func board_ids() -> Array:
	return GameDB.ids("records").filter(func(k): return bool(GameDB.row("records", k).get("board", false)))


## Шляхи всіх документів гравця, які стираються разом з обліковим записом: рід і рядки всіх таблиць.
func doc_paths(u: String) -> Array:
	var out := [FirebaseApi.player_path(u)]
	for b in board_ids():
		out.append(FirebaseApi.board_row_path(b, u))
	if extra_doc_paths.is_valid():
		out.append_array(extra_doc_paths.call(u))  # МІСЦЕ ДЛЯ РОЗШИРЕННЯ (рядки таблиць рекордів)
	return out


## «Видалити обліковий запис»: документи гравця, тоді сам обліковий запис. Рід на пристрої лишається.
## Повертає {"ok", "text", "need_password"}: давній вхід облікового запису з поштою — спершу пароль (password).
func delete_account(password: String = "") -> Dictionary:
	return await _locked(_delete_account, [password])


func _delete_account(password: String) -> Dictionary:
	if not is_signed_in():
		return {"ok": false, "text": FirebaseApi.NO_NET if state == OFFLINE else FirebaseApi.FAILED, "need_password": false}
	if password != "" and not bool(session["guest"]):
		var s := await _send(FirebaseApi.sign_in(email(), password))
		if s["net"]:
			return {"ok": false, "text": FirebaseApi.NO_NET, "need_password": true}
		var a := FirebaseApi.parse_auth(s["code"], s["text"])
		if not a["ok"] or a["uid"] != uid():
			return {"ok": false, "text": FirebaseApi.message(a["error"]), "need_password": true}
		_take_tokens(a)
	for p in doc_paths(uid()):
		var r := await _fs(func(tok): return FirebaseApi.delete_doc(p, tok))
		if r["net"]:
			return {"ok": false, "text": FirebaseApi.NO_NET, "need_password": false}
		if r["code"] != 200 and r["code"] != 404:
			return {"ok": false, "text": FirebaseApi.FAILED, "need_password": false}
	var d := await _send(FirebaseApi.delete_account(_id_token))
	if d["net"]:
		return {"ok": false, "text": FirebaseApi.NO_NET, "need_password": false}
	if d["code"] != 200:
		var err := FirebaseApi.error_code(d["text"])
		if err == FirebaseApi.TOO_OLD and not bool(session["guest"]):
			return {"ok": false, "text": "Для видалення введи пароль ще раз.", "need_password": true}
		if err != FirebaseApi.TOO_OLD and not FirebaseApi.is_dead_session(err):
			return {"ok": false, "text": FirebaseApi.FAILED, "need_password": false}
		# гість із давнім входом: дані вже стерто, а порожній анонімний запис нічого не тримає
	_clear_session(true)
	session["email"] = ""
	_save_session()
	last_error = ""
	_set_state(SIGNED_OUT)
	return {"ok": true, "text": "Обліковий запис видалено. Рід лишився на цьому пристрої.", "need_password": false}


# ================= Спільні таблиці рекордів =================

## Надіслати рядки таблиць, що змінились відтоді, як їх слали востаннє (по запиту на таблицю), не частіше за
## BOARD_GAP. Рядок зі значенням 0 (скажімо, після заміни роду) стирається. Невдача — спроба при наступній нагоді.
func sync_boards() -> void:
	if not started or not is_signed_in() or not rows_fn.is_valid():
		return
	await _locked(_sync_boards)


func _sync_boards() -> void:
	if not is_signed_in() or now() - _last_board < BOARD_GAP:
		return
	_last_board = now()
	var rows: Dictionary = rows_fn.call()
	var sent: Dictionary = session["boards_sent"]
	for b in rows:
		var row: Dictionary = rows[b]
		var path := FirebaseApi.board_row_path(str(b), uid())
		var r: Dictionary
		if int(row.get("value", 0)) <= 0:
			if not sent.has(b):
				continue
			r = await _fs(func(t): return FirebaseApi.delete_doc(path, t))
		elif sent.get(b, {}) == row:
			continue
		else:
			var fields := {"value": int(row["value"]), "name": str(row["name"]), "cls": str(row["cls"]), "level": int(row["level"]), "updated": FirebaseApi.ts(int(now()))}
			r = await _fs(func(t): return FirebaseApi.patch_doc(path, t, fields))
		if r["net"] or r.get("dead", false):
			if r.get("dead", false):
				await _session_dead()
			break
		if r["code"] != 200:
			continue
		if int(row.get("value", 0)) <= 0:
			sent.erase(b)
		else:
			sent[b] = row.duplicate()
		_board_cache.erase(b)
	_save_session()


## Найкращі BOARD_TOP рядків таблиці й власне місце. Прочитане тримається BOARD_CACHE секунд.
## {"ok", "rows": [{"uid", "value", "name", "cls", "level", "mine"}], "place" (0 — тебе нема), "mine" (своє значення), "text"}.
func board(b: String) -> Dictionary:
	if not started or not is_signed_in():
		return {"ok": false, "rows": [], "place": 0, "mine": 0, "text": FirebaseApi.NO_NET}
	var c: Dictionary = _board_cache.get(b, {})
	if not c.is_empty() and now() - float(c["at"]) < BOARD_CACHE:
		return c["data"]
	return await _locked(_read_board, [b])


func _read_board(b: String) -> Dictionary:
	var fail := {"ok": false, "rows": [], "place": 0, "mine": 0, "text": FirebaseApi.NO_NET}
	var r := await _fs(func(t): return FirebaseApi.board_top(b, BOARD_TOP, t))
	if r["net"] or r.get("dead", false) or r["code"] != 200:
		if r["code"] != 0:
			fail["text"] = FirebaseApi.FAILED
		return fail
	var rows := FirebaseApi.parse_board(r["text"])
	var me := uid()
	for row in rows:
		row["mine"] = row["uid"] == me
	var mine := 0
	if rows_fn.is_valid():
		mine = int(rows_fn.call().get(b, {}).get("value", 0))
	if session["boards_sent"].has(b):
		mine = int(session["boards_sent"][b]["value"])
	var place := 0
	if mine > 0:
		var q := await _fs(func(t): return FirebaseApi.board_count_above(b, mine, t))
		if not q["net"] and q["code"] == 200 and FirebaseApi.parse_count(q["text"]) >= 0:
			place = FirebaseApi.parse_count(q["text"]) + 1
	var data := {"ok": true, "rows": rows, "place": place, "mine": mine, "text": ""}
	_board_cache[b] = {"at": now(), "data": data}
	return data


func reported(b: String, target: String) -> bool:
	return _reported.has(b + "/" + target)


## Скарга на ім'я в таблиці: раз на рядок за запуск гри. {"ok", "text"}.
func report_name(b: String, target: String, name: String) -> Dictionary:
	if reported(b, target):
		return {"ok": true, "text": "Скаргу вже надіслано."}
	if not started or not is_signed_in():
		return {"ok": false, "text": FirebaseApi.NO_NET}
	return await _locked(_report, [b, target, name])


func _report(b: String, target: String, name: String) -> Dictionary:
	var r := await _fs(func(t): return FirebaseApi.report(uid(), target, name, b, int(now()), t))
	if r["net"]:
		return {"ok": false, "text": FirebaseApi.NO_NET}
	if r["code"] != 200:
		return {"ok": false, "text": FirebaseApi.FAILED}
	_reported[b + "/" + target] = true
	return {"ok": true, "text": "Скаргу надіслано."}
