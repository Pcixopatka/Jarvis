extends SceneTree
## ПЕРЕВІРКА НА СПРАВЖНЬОМУ ПРОЄКТІ FIREBASE. Шле справжні запити до kozatska-zvytiaha: створює гостей і
## одноразовий обліковий запис kz-test-…@example.com, пише й стирає документи. НІКОЛИ не запускати з набору
## тестів чи CI — лише руками:
##   XDG_DATA_HOME=<окрема тека> godot --headless --path . -s res://tools/cloud_live_check.gd
## Два «пристрої» (A і Б) — два самостійні екземпляри Cloud зі справжнім транспортом, своїми файлами сеансу
## й збережень; третій (В) — окремий гість для спільної таблиці. Таблиця лише перевірочна: boards/zz_test, ніколи
## не таблиця справжнього рекорду. Кожен обліковий запис, створений тут, стирається в кінці, навіть якщо щось упало
## (сценарій іде окремо, а прибирання чекає його не довше за LIMIT секунд).

const CloudScript := preload("res://scripts/core/cloud.gd")
const FirebaseApi := preload("res://scripts/core/firebase_api.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")
const SaveTransfer := preload("res://scripts/core/save_transfer.gd")
const TransportScript := preload("res://scripts/core/cloud_transport.gd")
const LIMIT := 300.0

var ok_n := 0
var fail_n := 0
var done := false
var creds := {}  # uid -> {"refresh", "email", "password"}: усе, що треба стерти
var email := ""
var password := ""
var dev := {}


func _initialize() -> void:
	_main.call_deferred()


func step(cond: bool, text: String) -> void:
	if cond:
		ok_n += 1
	else:
		fail_n += 1
	print("%s %s" % ["OK  " if cond else "FAIL", text])


func _rand_letters(n: int) -> String:
	var s := ""
	for i in n:
		s += char(97 + randi() % 26)
	return s


## Запам'ятати, кого потім стерти.
func remember(c) -> void:
	var u: String = c.uid()
	if u == "":
		return
	var e: Dictionary = creds.get(u, {})
	e["refresh"] = str(c.session["refresh"])
	if c.email() != "":
		e["email"] = c.email()
		e["password"] = password
	creds[u] = e


func _dir(name: String) -> String:
	var d := "user://live_%s/" % name
	DirAccess.make_dir_recursive_absolute(d)
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d + f)
	return d


func _device(name: String) -> Node:
	var d: String = dev[name]
	var c: Node = CloudScript.new()
	root.add_child(c)
	c.set_process(false)  # розклад тут не потрібен: кроки йдуть руками
	c.set_meta("cfg", {"session_path": d + "cloud.session", "paths": {1: d + "hero_1.save", 2: d + "hero_2.save"}, "account_path": d + "account.save"})
	return c


## Невеликий справжній рід: герой рівня level у слоті 1 і спільна скриня.
func _write_clan(name: String, level: int, gold: int) -> void:
	var d: String = dev[name]
	var p = load("res://scripts/entities/player.gd").new()
	p._ready()
	p.change_class("cossack")
	p.level = level
	p.gold = gold
	p.nick = "Перевірка"
	var w = load("res://scripts/game/world_state.gd").new()
	SaveSystem.save({"player": p.to_dict(), "world": w.to_dict(), "meta": {"playtime": 100.0 * level}}, d + "hero_1.save")
	p.free()
	SaveSystem.write_var(d + "account.save", {"chest": {"gold": gold, "items": [], "stones": {}}})


## Що зараз у хмарі (читає пристрій c своїм ключем): документ або порожньо.
func _cloud_doc(c) -> Dictionary:
	var r: Dictionary = await c._fs(func(t): return FirebaseApi.get_doc(FirebaseApi.player_path(c.uid()), t))
	if r["code"] != 200:
		return {}
	return c._read_doc(r["text"])


func _main() -> void:
	randomize()
	print("Перевірка хмари на справжньому проєкті %s" % FirebaseApi.PROJECT_ID)
	email = "kz-test-%s@example.com" % _rand_letters(10)
	password = "Pw-" + _rand_letters(12)
	print("одноразова пошта: %s" % email)
	dev = {"a": _dir("a"), "b": _dir("b"), "c": _dir("c"), "a2": ""}
	dev["a2"] = dev["a"]
	_scenario()
	var t0 := Time.get_ticks_msec()
	while not done and (Time.get_ticks_msec() - t0) / 1000.0 < LIMIT:
		await process_frame
	if not done:
		step(false, "сценарій не дійшов до кінця (помилка скрипту чи час вийшов)")
	await _cleanup()
	print("\nРАЗОМ: %d OK, %d FAIL" % [ok_n, fail_n])
	quit(1 if fail_n > 0 else 0)


func _scenario() -> void:
	# 1. Пристрій A: рід є на диску ще до першого запуску (оновлення з версії без хмари)
	_write_clan("a", 12, 1200)
	var a: Node = _device("a")
	var local_before: String = CloudScript.digest(SaveTransfer.collect(a.get_meta("cfg")["paths"], a.get_meta("cfg")["account_path"]))
	await a.start(a.get_meta("cfg"))
	remember(a)
	var da: Dictionary = await _cloud_doc(a)
	step(a.state == "guest" and a.transport is TransportScript and not da.is_empty() and da["digest"] == local_before and da["rev"] == 1 and a.local()["digest"] == local_before,
		"A: перший запуск з родом на диску — гість %s, у хмарі було порожньо, рід вивантажено без змін (rev 1)" % a.uid())
	# 2. A прив'язує пошту
	var uid_a: String = a.uid()
	var bind: Dictionary = await a.bind_email(email, password)
	remember(a)
	var da2: Dictionary = await _cloud_doc(a)
	step(bind["ok"] and a.state == "email" and a.uid() == uid_a and not da2.is_empty() and da2["update_time"] == da["update_time"], "A: пошту прив'язано, той самий uid і той самий документ")
	# 3. Пристрій Б: без героїв, спершу гість, тоді входить і бере рід
	var b: Node = _device("b")
	await b.start(b.get_meta("cfg"))
	remember(b)
	var b_guest: String = b.uid()
	var b_guest_rt: String = str(b.session["refresh"])
	step(b.state == "guest" and b_guest != "" and b_guest != uid_a, "Б: гість %s" % b_guest)
	var sin: Dictionary = await b.sign_in(email, password)
	remember(b)
	step(sin["ok"] and b.state == "email" and b.uid() == uid_a and not b.conflict and b.local()["digest"] == a.local()["digest"], "Б: увійшов, рід завантажено одразу, такий самий, як на A")
	var gone: Dictionary = await b._send(FirebaseApi.refresh(b_guest_rt))
	step(gone["code"] == 400 and FirebaseApi.is_dead_session(FirebaseApi.error_code(gone["text"])), "Б: колишнього гостя стерто (його ключ сеансу більше не діє: %s)" % FirebaseApi.error_code(gone["text"]))
	# 4. Б міняє рід і зберігає
	_write_clan("b", 20, 2000)
	var ub: Dictionary = await b.upload_now()
	var db: Dictionary = await _cloud_doc(b)
	step(ub["ok"] and db["digest"] == b.local()["digest"] and db["rev"] == 2 and db["device"] == b.device_id(), "Б: свій рід у хмарі (rev 2)")
	# 4а. A з часу синхронізації нічого не міняв: рід Б (той самий родовід) береться сам, без питань
	a._last_check = -1.0e12
	var line0: String = str(a.session["synced_line"])
	await a.on_main_menu()
	step(not a.conflict and a.local()["digest"] == b.local()["digest"] and str(a.session["synced_line"]) == line0 and line0 != "", "A без змін: рід Б узято сам, без розбіжності (той самий родовід)")
	_write_clan("b", 21, 2100)
	await b.upload_now()
	# 5. A теж міняє рід: запис зі старою міткою відхилено — розбіжність
	_write_clan("a", 13, 1300)
	var ua: Dictionary = await a.upload_now()
	var dcheck: Dictionary = await _cloud_doc(a)
	step(not ua["ok"] and a.conflict and dcheck["digest"] == b.local()["digest"], "A: розбіжність знайдено, хмару не затерто")
	# 6. A бере рід із хмари
	var took: Dictionary = await a.take_cloud()
	step(took["ok"] and not a.conflict and a.local()["digest"] == b.local()["digest"], "A: узяв рід із хмари, тепер такий самий, як на Б")
	# 6а. Б свідомо кладе свій рід поверх: новий родовід, і A без змін усе одно бачить вибір
	_write_clan("a", 14, 1400)
	await a.upload_now()
	_write_clan("b", 22, 2200)
	b._last_check = -1.0e12
	await b.on_main_menu()
	var b_conf: bool = b.conflict
	var kb: Dictionary = await b.keep_local()
	var dk: Dictionary = await _cloud_doc(b)
	step(b_conf and kb["ok"] and dk["line"] != "" and dk["line"] != line0 and dk["digest"] == b.local()["digest"], "Б: «Лишити рід із цього пристрою» — новий родовід у хмарі")
	a._last_check = -1.0e12
	await a.on_main_menu()
	step(a.conflict and a.local()["digest"] != b.local()["digest"], "A без змін, але родовід інший: розбіжність, а не тихе завантаження")
	var took2: Dictionary = await a.take_cloud()
	step(took2["ok"] and not a.conflict and str(a.session["synced_line"]) == dk["line"] and a.local()["digest"] == b.local()["digest"], "A узяв рід Б і його родовід")
	# 7. Без змін — не шле
	var n0: int = a.requests
	var same: Dictionary = await a.upload_now()
	step(same["ok"] and a.last_skip == "same" and a.requests == n0, "A: той самий рід удруге не шле (запитів: %d)" % (a.requests - n0))
	# 8. Перезапуск A з файлу сеансу
	a.queue_free()
	var a2: Node = _device("a2")
	await a2.start(a2.get_meta("cfg"))
	remember(a2)
	step(a2.state == "email" and a2.uid() == uid_a and a2._id_token != "" and not a2.conflict and a2.last_skip == "same", "A після перезапуску: сеанс з файлу, новий ключ входу, без розбіжності")
	# 8а. Спільна таблиця (лише zz_test): A (пошта) і В (гість) пишуть рядки
	a2.rows_fn = func(): return {"zz_test": {"value": 50, "name": "Перевірка A", "cls": "cossack", "level": 12}}
	a2.extra_doc_paths = func(u: String) -> Array: return [FirebaseApi.board_row_path("zz_test", u)]  # перевірочна таблиця — через місце розширення
	await a2.sync_boards()
	var c: Node = _device("c")
	c.rows_fn = func(): return {"zz_test": {"value": 80, "name": "Перевірка В", "cls": "strilets", "level": 30}}
	c.extra_doc_paths = func(u: String) -> Array: return [FirebaseApi.board_row_path("zz_test", u)]
	await c.start(c.get_meta("cfg"))
	remember(c)
	await c.sync_boards()
	var top: Dictionary = await a2.board("zz_test")
	var ours: Array = top["rows"].filter(func(r): return r["uid"] == c.uid() or r["uid"] == uid_a)
	var above: int = top["rows"].filter(func(r): return r["value"] > 50).size()
	step(top["ok"] and ours.size() == 2 and ours[0]["uid"] == c.uid() and ours[0]["value"] == 80 and ours[1]["mine"] and ours[1]["name"] == "Перевірка A"
		and ours[1]["cls"] == "cossack" and ours[1]["level"] == 12, "таблиця zz_test: обидва рядки, від більшого, свій позначено")
	step(top["place"] == above + 1 and top["place"] >= 2, "своє місце за лічильником: %d" % top["place"])
	var rep: Dictionary = await a2.report_name("zz_test", c.uid(), "Перевірка В")
	var rep2: Dictionary = await a2.report_name("zz_test", c.uid(), "Перевірка В")
	step(rep["ok"] and rep2["text"] == "Скаргу вже надіслано.", "скаргу на ім'я прийнято, удруге не шле")
	# 9. Видалення облікового запису з A; Б більше не входить
	var del: Dictionary = await a2.delete_account()
	if del.get("need_password", false):
		del = await a2.delete_account(password)
	step(del["ok"] and a2.state == "signed_out" and not a2.local()["empty"], "A: обліковий запис видалено, рід на пристрої лишився")
	var top2: Dictionary = await c.board("zz_test")
	step(top2["ok"] and not top2["rows"].any(func(r): return r["uid"] == uid_a) and top2["rows"].any(func(r): return r["uid"] == c.uid()), "рядок A зник із таблиці разом з обліковим записом")
	await b.retry()
	step(b.state == "signed_out" and b.last_error == CloudScript.SESSION_ENDED, "Б: ключ сеансу більше не діє — «Сеанс завершився»")
	var again: Dictionary = await b.sign_in(email, password)
	step(not again["ok"] and again["code"] == "INVALID_LOGIN_CREDENTIALS", "Б: увійти з тією поштою не можна (%s)" % again["code"])
	done = true


## Стерти все, що створено: документ і обліковий запис кожного uid.
func _cleanup() -> void:
	print("\nПрибирання:")
	var t: Node = TransportScript.new()
	root.add_child(t)
	var helper: Node = CloudScript.new()
	helper.transport = t
	root.add_child(helper)
	helper.set_process(false)
	for u in creds:
		var e: Dictionary = creds[u]
		var tok := ""
		var r: Dictionary = await helper._send(FirebaseApi.refresh(str(e.get("refresh", ""))))
		var a := FirebaseApi.parse_auth(r["code"], r["text"])
		if a["ok"] and a["uid"] == u:
			tok = a["id_token"]
		elif e.has("email"):
			r = await helper._send(FirebaseApi.sign_in(e["email"], e["password"]))
			a = FirebaseApi.parse_auth(r["code"], r["text"])
			if a["ok"] and a["uid"] == u:
				tok = a["id_token"]
		if tok == "":
			print("  %s: уже стерто (увійти не можна)" % u)
			continue
		var d1: Dictionary = await helper._send(FirebaseApi.delete_doc(FirebaseApi.player_path(u), tok))
		var d3: Dictionary = await helper._send(FirebaseApi.delete_doc(FirebaseApi.board_row_path("zz_test", u), tok))
		var d2: Dictionary = await helper._send(FirebaseApi.delete_account(tok))
		print("  %s: документ — HTTP %d, рядок zz_test — HTTP %d, обліковий запис — HTTP %d" % [u, d1["code"], d3["code"], d2["code"]])
		if d2["code"] != 200:
			step(false, "прибирання %s: %s" % [u, FirebaseApi.error_code(d2["text"])])
