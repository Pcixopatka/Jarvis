extends RefCounted
## Firebase через звичайний REST: що слати й як читати відповідь. Тут нема мережі, лише рядки й словники,
## тож усе перевіряють тести. Мережею ходить транспорт (cloud_transport.gd), рішення ухвалює Cloud (cloud.gd).
##
## Запит — словник {"method", "url", "headers": PackedStringArray, "body": String}.
## Firebase Auth (identitytoolkit, securetoken): гість, прив'язка пошти, вхід, новий ключ входу, лист зі зміною
## пароля, видалення облікового запису. Firestore: документ players/{uid} (див. docs/online.md і
## docs/store/firestore.rules). Значення Firestore типізовані: {"stringValue": …}, {"integerValue": "12"} тощо;
## encode_value / decode_value перекладають їх у звичайні значення GDScript і назад. Мітку часу GDScript не має:
## її тримає словник {"@ts": "2026-11-14T13:52:00Z"} (ts() і ts_unix()).
## Відкритий ключ і проєкт — data/settings.json, запис «firebase» (не таємниця: це клієнтські налаштування).

const GameDB := preload("res://scripts/core/game_db.gd")

const AUTH := "https://identitytoolkit.googleapis.com/v1/"
const TOKEN := "https://securetoken.googleapis.com/v1/token"
const FIRESTORE := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/"
const JSON_TYPE := "Content-Type: application/json"
const TS := "@ts"

## Тексти для гравця
const NO_NET := "Немає зв'язку. Перевір інтернет і спробуй ще раз."
const FAILED := "Не вдалося. Спробуй пізніше."
const MESSAGES := {
	"EMAIL_EXISTS": "Ця пошта вже має обліковий запис. Натисни «Увійти в наявний обліковий запис».",
	"INVALID_EMAIL": "Пошта написана з помилкою.",
	"MISSING_EMAIL": "Пошта написана з помилкою.",
	"WEAK_PASSWORD": "Пароль закороткий: треба щонайменше 6 знаків.",
	"MISSING_PASSWORD": "Пароль закороткий: треба щонайменше 6 знаків.",
	"INVALID_LOGIN_CREDENTIALS": "Пошта або пароль не підходять.",
	"INVALID_PASSWORD": "Пошта або пароль не підходять.",  # давніші відповіді Firebase
	"EMAIL_NOT_FOUND": "Пошта або пароль не підходять.",
	"INVALID_CREDENTIAL": "Пошта або пароль не підходять.",
	"TOO_MANY_ATTEMPTS_TRY_LATER": "Забагато спроб. Спробуй трохи пізніше.",
	"USER_DISABLED": "Цей обліковий запис вимкнено.",
}
## Відповіді на оновлення ключа, після яких сеансу більше нема.
const DEAD_SESSION := ["INVALID_REFRESH_TOKEN", "USER_NOT_FOUND", "TOKEN_EXPIRED", "USER_DISABLED"]
const TOO_OLD := "CREDENTIAL_TOO_OLD_LOGIN_REQUIRED"

## Робочі копії налаштувань (запис «firebase»; їх заповнює apply_settings()).
static var API_KEY: String
static var PROJECT_ID: String


static func _static_init() -> void:
	apply_settings()


static func apply_settings() -> void:
	var S := GameDB.settings("firebase")
	API_KEY = S["api_key"]
	PROJECT_ID = S["project_id"]


# ================= Запити =================

static func _req(method: String, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	return {"method": method, "url": url, "headers": headers, "body": body}


static func _auth_url(action: String) -> String:
	return AUTH + "accounts:%s?key=%s" % [action, API_KEY]


static func _post_json(url: String, data: Dictionary, extra: Array = []) -> Dictionary:
	var h := PackedStringArray([JSON_TYPE])
	h.append_array(PackedStringArray(extra))
	return _req("POST", url, h, JSON.stringify(data))


## Новий гість (анонімний обліковий запис).
static func sign_up_guest() -> Dictionary:
	return _post_json(_auth_url("signUp"), {"returnSecureToken": true})


## Прив'язати пошту й пароль до нинішнього гостя: uid лишається той самий.
static func link_email(id_token: String, email: String, password: String) -> Dictionary:
	return _post_json(_auth_url("signUp"), {"idToken": id_token, "email": email, "password": password, "returnSecureToken": true})


static func sign_in(email: String, password: String) -> Dictionary:
	return _post_json(_auth_url("signInWithPassword"), {"email": email, "password": password, "returnSecureToken": true})


## Новий ключ входу (id token) за ключем сеансу (refresh token).
static func refresh(refresh_token: String) -> Dictionary:
	return _req("POST", TOKEN + "?key=" + API_KEY, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]),
		"grant_type=refresh_token&refresh_token=" + refresh_token.uri_encode())


## Лист зі зміною пароля (українською).
static func send_reset(email: String) -> Dictionary:
	return _post_json(_auth_url("sendOobCode"), {"requestType": "PASSWORD_RESET", "email": email}, ["X-Firebase-Locale: uk"])


static func delete_account(id_token: String) -> Dictionary:
	return _post_json(_auth_url("delete"), {"idToken": id_token})


static func doc_url(path: String) -> String:
	return (FIRESTORE % PROJECT_ID) + path


static func player_path(uid: String) -> String:
	return "players/" + uid


static func _bearer(id_token: String) -> String:
	return "Authorization: Bearer " + id_token


static func get_doc(path: String, id_token: String) -> Dictionary:
	return _req("GET", doc_url(path), PackedStringArray([_bearer(id_token)]), "")


## Записати документ цілком (усі поля). precondition: {"update_time": "…"} — лише якщо в хмарі досі ця версія;
## {"exists": false} — лише якщо документа ще нема; {} — без умови.
static func patch_doc(path: String, id_token: String, fields: Dictionary, precondition: Dictionary = {}) -> Dictionary:
	var url := doc_url(path)
	if precondition.has("update_time"):
		url += "?currentDocument.updateTime=" + str(precondition["update_time"]).uri_encode()
	elif precondition.has("exists"):
		url += "?currentDocument.exists=" + ("true" if precondition["exists"] else "false")
	return _req("PATCH", url, PackedStringArray([JSON_TYPE, _bearer(id_token)]), JSON.stringify({"fields": encode_fields(fields)}))


static func delete_doc(path: String, id_token: String) -> Dictionary:
	return _req("DELETE", doc_url(path), PackedStringArray([_bearer(id_token)]), "")


# ================= Таблиці рекордів і скарги =================

const BOARD_FIELDS := ["value", "name", "cls", "level", "updated"]


static func board_row_path(board: String, uid: String) -> String:
	return "boards/%s/scores/%s" % [board, uid]


## Найкращі n рядків таблиці (за value, від більшого).
static func board_top(board: String, n: int, id_token: String) -> Dictionary:
	var q := {"structuredQuery": {"from": [{"collectionId": "scores"}], "orderBy": [{"field": {"fieldPath": "value"}, "direction": "DESCENDING"}], "limit": n}}
	return _req("POST", doc_url("boards/" + board) + ":runQuery", PackedStringArray([JSON_TYPE, _bearer(id_token)]), JSON.stringify(q))


## Скільки рядків таблиці мають value більше за дане (місце = це число + 1).
static func board_count_above(board: String, value: int, id_token: String) -> Dictionary:
	var q := {"structuredAggregationQuery": {"structuredQuery": {"from": [{"collectionId": "scores"}],
		"where": {"fieldFilter": {"field": {"fieldPath": "value"}, "op": "GREATER_THAN", "value": {"integerValue": str(value)}}}},
		"aggregations": [{"alias": "n", "count": {}}]}}
	return _req("POST", doc_url("boards/" + board) + ":runAggregationQuery", PackedStringArray([JSON_TYPE, _bearer(id_token)]), JSON.stringify(q))


## Скарга на ім'я: новий документ у reports (його не прочитає жоден гравець).
static func report(from_uid: String, target: String, name: String, board: String, unix: int, id_token: String) -> Dictionary:
	var fields := {"from": from_uid, "target": target.substr(0, 64), "name": name.substr(0, 24), "board": board.substr(0, 24), "time": ts(unix)}
	return _req("POST", doc_url("reports"), PackedStringArray([JSON_TYPE, _bearer(id_token)]), JSON.stringify({"fields": encode_fields(fields)}))


## Відповідь runQuery: [{"uid", "value", "name", "cls", "level"}] у тому порядку, як прийшли (порожня таблиця — []).
static func parse_board(text: String) -> Array:
	var j := JSON.new()
	if text == "" or j.parse(text) != OK or not j.data is Array:
		return []
	var out := []
	for item in j.data:
		if not item is Dictionary or not item.get("document") is Dictionary:
			continue
		var doc: Dictionary = item["document"]
		var f := decode_fields(doc.get("fields", {}))
		out.append({"uid": str(doc.get("name", "")).get_file(), "value": int(f.get("value", 0)), "name": str(f.get("name", "")),
			"cls": str(f.get("cls", "")), "level": int(f.get("level", 1))})
	return out


## Відповідь runAggregationQuery: число з поля n; -1 — не прочитати.
static func parse_count(text: String) -> int:
	var j := JSON.new()
	if text == "" or j.parse(text) != OK or not j.data is Array:
		return -1
	for item in j.data:
		if item is Dictionary and item.get("result") is Dictionary:
			var n = item["result"].get("aggregateFields", {}).get("n")
			if n is Dictionary:
				return int(decode_value(n))
	return -1


# ================= Відповіді =================

static func parse_json(text: String) -> Dictionary:
	var j := JSON.new()
	if text == "" or j.parse(text) != OK:
		return {}  # не JSON (сторінка проксі, обірвана відповідь): тихо порожньо
	return j.data if j.data is Dictionary else {}


## Код помилки з відповіді: Auth пише «WEAK_PASSWORD : Password should be…» у error.message,
## Firestore — «FAILED_PRECONDITION» у error.status. Порожньо, якщо помилки нема.
static func error_code(text: String) -> String:
	var e = parse_json(text).get("error")
	if not e is Dictionary:
		return ""
	var msg := str(e.get("message", ""))
	var m := RegEx.create_from_string("^([A-Z][A-Z0-9_]+)( : .*)?$").search(msg)
	if m != null:
		return m.get_string(1)  # Auth: сам код (інколи з поясненням після « : »)
	return str(e.get("status", ""))  # Firestore: у message пояснення для людей, код — у status


## Відповідь входу (будь-якого з викликів Auth чи оновлення ключа) одним видом:
## {"ok", "uid", "id_token", "refresh_token", "expires_in", "email", "error"}.
static func parse_auth(code: int, text: String) -> Dictionary:
	var j := parse_json(text)
	var out := {"ok": false, "uid": "", "id_token": "", "refresh_token": "", "expires_in": 0, "email": "", "error": ""}
	if code != 200:
		out["error"] = error_code(text)
		return out
	out["uid"] = str(j.get("localId", j.get("user_id", "")))
	out["id_token"] = str(j.get("idToken", j.get("id_token", "")))
	out["refresh_token"] = str(j.get("refreshToken", j.get("refresh_token", "")))
	out["expires_in"] = int(str(j.get("expiresIn", j.get("expires_in", "3600"))))
	out["email"] = str(j.get("email", ""))
	out["ok"] = out["uid"] != "" and out["id_token"] != ""
	if not out["ok"]:
		out["error"] = "BAD_ANSWER"
	return out


## Документ Firestore: {"name", "fields" (звичайні значення), "create_time", "update_time"}; порожньо, якщо не документ.
static func parse_doc(text: String) -> Dictionary:
	var j := parse_json(text)
	if not j.has("name"):
		return {}
	return {"name": str(j["name"]), "fields": decode_fields(j.get("fields", {})), "create_time": str(j.get("createTime", "")),
		"update_time": str(j.get("updateTime", ""))}


static func is_dead_session(err: String) -> bool:
	return err in DEAD_SESSION


## Текст гравцеві за кодом помилки Auth. «net» — немає зв'язку.
static func message(err: String) -> String:
	if err == "net":
		return NO_NET
	return MESSAGES.get(err, FAILED)


# ================= Значення Firestore =================

static func ts(unix: int) -> Dictionary:
	return {TS: Time.get_datetime_string_from_unix_time(unix) + "Z"}


## Мітка часу (словник ts() чи рядок RFC 3339, зокрема з частками секунди) у секунди Unix; 0 — не мітка.
static func ts_unix(v) -> int:
	var s := str(v.get(TS, "")) if v is Dictionary else str(v)
	if s.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(s.substr(0, 19)))


static func encode_value(v) -> Dictionary:
	match typeof(v):
		TYPE_NIL:
			return {"nullValue": null}
		TYPE_BOOL:
			return {"booleanValue": v}
		TYPE_INT:
			return {"integerValue": str(v)}
		TYPE_FLOAT:
			return {"doubleValue": v}
		TYPE_STRING, TYPE_STRING_NAME:
			return {"stringValue": str(v)}
		TYPE_DICTIONARY:
			if v.size() == 1 and v.has(TS):
				return {"timestampValue": str(v[TS])}
			return {"mapValue": {"fields": encode_fields(v)}}
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var vals := []
			for x in v:
				vals.append(encode_value(x))
			return {"arrayValue": {"values": vals}}
	return {"stringValue": str(v)}


static func encode_fields(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = encode_value(d[k])
	return out


static func decode_value(t):
	if not t is Dictionary:
		return null
	if t.has("stringValue"):
		return str(t["stringValue"])
	if t.has("integerValue"):
		return int(str(t["integerValue"]))
	if t.has("doubleValue"):
		var dv = t["doubleValue"]
		if dv is String:
			match dv:
				"NaN": return NAN
				"Infinity": return INF
				"-Infinity": return -INF
			return float(dv)
		return float(dv)
	if t.has("booleanValue"):
		return bool(t["booleanValue"])
	if t.has("timestampValue"):
		return {TS: str(t["timestampValue"])}
	if t.has("mapValue"):
		return decode_fields(t["mapValue"].get("fields", {}))
	if t.has("arrayValue"):
		var out := []
		for x in t["arrayValue"].get("values", []):
			out.append(decode_value(x))
		return out
	return null  # nullValue і невідоме


static func decode_fields(f) -> Dictionary:
	var out := {}
	if f is Dictionary:
		for k in f:
			out[k] = decode_value(f[k])
	return out
