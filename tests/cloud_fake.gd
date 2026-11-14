extends RefCounted
## Підставний Firebase для тестів і знімків екрана: той самий send(), що й справжній транспорт, але відповідає
## з пам'яті й нікуди не ходить. Тримає облікові записи (гості й пошта), ключі, документи players/{uid} з
## мітками updateTime і умовами currentDocument, перевіряє будову документа, як правила Firestore
## (docs/store/firestore.rules). Кілька екземплярів Cloud можуть ділити один FakeFirebase: два пристрої.
## Тести керують ним: offline (зв'язку нема), queue (наступні відповіді як є), expire_tokens(), too_old тощо.

var calls := []  # {"method", "url", "headers", "body", "path", "query"}
var queue := []  # наступні відповіді [ok, code, text], раніше за будь-яку логіку
var offline := false
var deferred := false  # відповідати наступним кадром, як справжня мережа (інакше — одразу)
var drop_next := 0  # стільки наступних запитів сервер виконає, але відповідь до пристрою не дійде
var users := {}  # uid -> {"email", "password", "disabled", "too_old"}
var refresh_tokens := {}  # refresh -> uid
var id_tokens := {}  # id token -> uid
var docs := {}  # шлях -> {"fields": typed, "updateTime", "createTime"}
var resets := []  # кому слали лист зі зміною пароля
var reports := []  # прийняті скарги: розібрані поля
var _n := 0


func send(method: String, url: String, headers: PackedStringArray, body: String, done: Callable) -> void:
	var q := url.get_slice("?", 1) if "?" in url else ""
	var path := url.get_slice("?", 0)
	calls.append({"method": method, "url": url, "headers": headers, "body": body, "path": path, "query": q})
	var ans: Array
	if offline:
		ans = [false, 0, ""]
	elif not queue.is_empty():
		ans = queue.pop_front()
	else:
		ans = _answer(method, path, q, headers, body)
		if drop_next > 0:
			drop_next -= 1
			ans = [false, 0, ""]
	if deferred:
		done.call_deferred(ans[0], ans[1], ans[2])
	else:
		done.call(ans[0], ans[1], ans[2])


func sent(part: String) -> Array:
	return calls.filter(func(r): return part in r["url"])


func _id() -> String:
	_n += 1
	return "%s%04d" % [["u", "t", "r"][_n % 3], _n]


func _err(code: int, msg: String, status: String = "") -> Array:
	var e := {"code": code, "message": msg}
	if status != "":
		e["status"] = status
	return [true, code, JSON.stringify({"error": e})]


func _tokens(uid: String) -> Dictionary:
	var it := "id-" + _id()
	var rt := "rt-" + _id()
	id_tokens[it] = uid
	refresh_tokens[rt] = uid
	return {"id": it, "rt": rt}


func _auth_ok(uid: String, extra: Dictionary = {}) -> Array:
	var t := _tokens(uid)
	var out := {"localId": uid, "idToken": t["id"], "refreshToken": t["rt"], "expiresIn": "3600"}
	if users[uid]["email"] != "":
		out["email"] = users[uid]["email"]
	out.merge(extra, true)
	return [true, 200, JSON.stringify(out)]


## Усі видані ключі входу більше не діють (як після години).
func expire_tokens() -> void:
	id_tokens.clear()


func uid_of(email: String) -> String:
	for u in users:
		if users[u]["email"] == email:
			return u
	return ""


func _answer(method: String, path: String, q: String, headers: PackedStringArray, body: String) -> Array:
	if path.begins_with("https://identitytoolkit.googleapis.com/v1/accounts:"):
		return _auth(path.get_slice("accounts:", 1), JSON.parse_string(body) if body != "" else {})
	if path.begins_with("https://securetoken.googleapis.com/v1/token"):
		var rt := body.get_slice("refresh_token=", 1).uri_decode()
		if not refresh_tokens.has(rt):
			return _err(400, "INVALID_REFRESH_TOKEN")
		var uid: String = refresh_tokens[rt]
		if not users.has(uid):
			return _err(400, "USER_NOT_FOUND")
		if users[uid]["disabled"]:
			return _err(400, "USER_DISABLED")
		var it := "id-" + _id()
		id_tokens[it] = uid
		return [true, 200, JSON.stringify({"id_token": it, "refresh_token": rt, "expires_in": "3600", "user_id": uid})]
	if path.begins_with("https://firestore.googleapis.com/"):
		return _firestore(method, path.get_slice("/documents/", 1), q, headers, body)
	return [true, 404, ""]


func _auth(action: String, b: Dictionary) -> Array:
	match action:
		"signUp":
			if b.has("idToken"):
				var uid: String = id_tokens.get(b["idToken"], "")
				if uid == "" or not users.has(uid):
					return _err(400, "INVALID_ID_TOKEN")
				if not ("@" in str(b.get("email", ""))):
					return _err(400, "INVALID_EMAIL")
				if str(b.get("password", "")).length() < 6:
					return _err(400, "WEAK_PASSWORD : Password should be at least 6 characters")
				if uid_of(b["email"]) != "":
					return _err(400, "EMAIL_EXISTS")
				users[uid]["email"] = b["email"]
				users[uid]["password"] = b["password"]
				return _auth_ok(uid)
			var nu := "uid" + _id()
			users[nu] = {"email": "", "password": "", "disabled": false, "too_old": false}
			return _auth_ok(nu)
		"signInWithPassword":
			var u := uid_of(str(b.get("email", "")))
			if u == "" or users[u]["password"] != str(b.get("password", "")):
				return _err(400, "INVALID_LOGIN_CREDENTIALS")
			if users[u]["disabled"]:
				return _err(400, "USER_DISABLED")
			users[u]["too_old"] = false
			return _auth_ok(u, {"registered": true})
		"sendOobCode":
			resets.append(str(b.get("email", "")))
			return [true, 200, JSON.stringify({"email": b.get("email", "")})]
		"delete":
			var uid: String = id_tokens.get(b.get("idToken", ""), "")
			if uid == "" or not users.has(uid):
				return _err(400, "INVALID_ID_TOKEN")
			if users[uid]["too_old"]:
				return _err(400, "CREDENTIAL_TOO_OLD_LOGIN_REQUIRED")
			users.erase(uid)
			for k in refresh_tokens.keys():
				if refresh_tokens[k] == uid:
					refresh_tokens.erase(k)
			return [true, 200, "{}"]
	return _err(400, "OPERATION_NOT_ALLOWED")


func _stamp() -> String:
	_n += 1
	return "2026-11-14T10:%02d:%02d.%06dZ" % [(_n / 60) % 60, _n % 60, _n]


func _doc_json(path: String) -> String:
	var d: Dictionary = docs[path]
	return JSON.stringify({"name": "projects/p/databases/(default)/documents/" + path, "fields": d["fields"],
		"createTime": d["createTime"], "updateTime": d["updateTime"]})


## Те саме, що вимагають правила для players/{uid}.
static func shape_ok(f: Dictionary) -> bool:
	var keys := f.keys()
	keys.sort()
	if keys != ["device", "rev", "save", "summary", "updated", "ver"]:
		return false
	return f["save"].has("stringValue") and str(f["save"]["stringValue"]).length() <= 900000 and f["rev"].has("integerValue") \
		and f["ver"].has("integerValue") and f["updated"].has("timestampValue") and f["device"].has("stringValue") \
		and str(f["device"]["stringValue"]).length() <= 64 and f["summary"].has("mapValue")


func _firestore(method: String, path: String, q: String, headers: PackedStringArray, body: String) -> Array:
	var tok := ""
	for h in headers:
		if h.begins_with("Authorization: Bearer "):
			tok = h.trim_prefix("Authorization: Bearer ")
	if not id_tokens.has(tok):
		return _err(401, "Request had invalid authentication credentials.", "UNAUTHENTICATED")
	var uid: String = id_tokens[tok]
	if path.begins_with("boards/") and ":" in path:
		return _board_query(path.get_slice("/", 1).get_slice(":", 0), path.get_slice(":", 1), body)
	if path == "reports" and method == "POST":
		return _report(uid, body)
	if path.begins_with("boards/"):
		return _board_row(method, path, uid, body)
	var own := (path.begins_with("players/") and path.get_slice("/", 1) == uid) or (method == "DELETE" and path.ends_with("/" + uid))
	if not own:
		return _err(403, "Missing or insufficient permissions.", "PERMISSION_DENIED")
	match method:
		"GET":
			if not docs.has(path):
				return _err(404, "No document to get.", "NOT_FOUND")
			return [true, 200, _doc_json(path)]
		"DELETE":
			docs.erase(path)
			return [true, 200, "{}"]
		"PATCH":
			if q.begins_with("currentDocument.exists=false") and docs.has(path):
				return _err(409, "Document already exists.", "ALREADY_EXISTS")
			if q.begins_with("currentDocument.updateTime="):
				var want := q.get_slice("=", 1).uri_decode()
				if not docs.has(path):
					return _err(404, "No document to update.", "NOT_FOUND")
				if docs[path]["updateTime"] != want:
					return _err(400, "the stored version does not match the required base version.", "FAILED_PRECONDITION")
			var j = JSON.parse_string(body)
			if not j is Dictionary or not shape_ok(j.get("fields", {})):
				return _err(403, "Missing or insufficient permissions.", "PERMISSION_DENIED")
			var st := _stamp()
			var created: String = docs[path]["createTime"] if docs.has(path) else st
			docs[path] = {"fields": j["fields"], "updateTime": st, "createTime": created}
			return [true, 200, _doc_json(path)]
	return _err(400, "bad", "INVALID_ARGUMENT")


## Рядок таблиці: як правила boards/{board}/scores/{uid}.
static func row_ok(board: String, f: Dictionary) -> bool:
	if RegEx.create_from_string("^[a-z_]{1,24}$").search(board) == null:
		return false
	var keys := f.keys()
	keys.sort()
	if keys != ["cls", "level", "name", "updated", "value"]:
		return false
	var v = f["value"].get("integerValue", f["value"].get("doubleValue"))
	if v == null or float(str(v)) < 0 or float(str(v)) > 1000000000:
		return false
	var nm := str(f["name"].get("stringValue", ""))
	var lv = f["level"].get("integerValue")
	return f["name"].has("stringValue") and nm.length() >= 1 and nm.length() <= 24 and f["cls"].has("stringValue") \
		and str(f["cls"]["stringValue"]).length() <= 24 and lv != null and int(lv) >= 1 and int(lv) <= 200 and f["updated"].has("timestampValue")


func _board_row(method: String, path: String, uid: String, body: String) -> Array:
	var parts := path.split("/")
	if parts.size() != 4 or parts[2] != "scores":
		return _err(403, "Missing or insufficient permissions.", "PERMISSION_DENIED")
	if method == "GET":
		return [true, 200, _doc_json(path)] if docs.has(path) else _err(404, "No document to get.", "NOT_FOUND")
	if parts[3] != uid:
		return _err(403, "Missing or insufficient permissions.", "PERMISSION_DENIED")
	if method == "DELETE":
		docs.erase(path)
		return [true, 200, "{}"]
	var j = JSON.parse_string(body)
	if method != "PATCH" or not j is Dictionary or not row_ok(parts[1], j.get("fields", {})):
		return _err(403, "Missing or insufficient permissions.", "PERMISSION_DENIED")
	var st := _stamp()
	docs[path] = {"fields": j["fields"], "updateTime": st, "createTime": docs[path]["createTime"] if docs.has(path) else st}
	return [true, 200, _doc_json(path)]


func _rows_of(board: String) -> Array:
	var out := []
	for p in docs:
		if str(p).begins_with("boards/%s/scores/" % board):
			out.append(p)
	return out


func _value_of(p: String) -> float:
	var v: Dictionary = docs[p]["fields"]["value"]
	return float(str(v.get("integerValue", v.get("doubleValue", 0))))


func _board_query(board: String, kind: String, body: String) -> Array:
	var q = JSON.parse_string(body)
	if not q is Dictionary:
		return _err(400, "bad", "INVALID_ARGUMENT")
	var rows := _rows_of(board)
	if kind == "runQuery":
		var sq: Dictionary = q.get("structuredQuery", {})
		rows.sort_custom(func(a, b): return _value_of(a) > _value_of(b))
		var n := int(sq.get("limit", rows.size()))
		var out := []
		for p in rows.slice(0, n):
			out.append({"document": {"name": "projects/p/databases/(default)/documents/" + p, "fields": docs[p]["fields"],
				"createTime": docs[p]["createTime"], "updateTime": docs[p]["updateTime"]}, "readTime": "2026-11-14T10:00:00Z"})
		if out.is_empty():
			out.append({"readTime": "2026-11-14T10:00:00Z"})
		return [true, 200, JSON.stringify(out)]
	if kind == "runAggregationQuery":
		var ff: Dictionary = q["structuredAggregationQuery"]["structuredQuery"]["where"]["fieldFilter"]
		var above := float(str(ff["value"].get("integerValue", ff["value"].get("doubleValue", 0))))
		var n := rows.filter(func(p): return _value_of(p) > above).size()
		return [true, 200, JSON.stringify([{"result": {"aggregateFields": {"n": {"integerValue": str(n)}}}, "readTime": "2026-11-14T10:00:00Z"}])]
	return _err(400, "bad", "INVALID_ARGUMENT")


func _report(uid: String, body: String) -> Array:
	var j = JSON.parse_string(body)
	var f: Dictionary = j.get("fields", {}) if j is Dictionary else {}
	var keys := f.keys()
	keys.sort()
	if keys != ["board", "from", "name", "target", "time"] or str(f["from"].get("stringValue", "")) != uid or str(f["target"].get("stringValue", "")).length() > 64 \
		or str(f["name"].get("stringValue", "")).length() > 24 or str(f["board"].get("stringValue", "")).length() > 24 or not f["time"].has("timestampValue"):
		return _err(403, "Missing or insufficient permissions.", "PERMISSION_DENIED")
	reports.append({"from": f["from"]["stringValue"], "target": f["target"]["stringValue"], "name": f["name"]["stringValue"], "board": f["board"]["stringValue"]})
	_n += 1
	return [true, 200, JSON.stringify({"name": "projects/p/databases/(default)/documents/reports/r%d" % _n, "fields": f})]
