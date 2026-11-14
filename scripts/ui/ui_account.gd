extends RefCounted
## Екрани облікового запису й хмарного збереження (головне меню → «Обліковий запис»). Усе робить Cloud
## (game.cloud), тут лише екрани: стан, форма пошти й пароля, вибір роду при розбіжності, підтвердження виходу
## й видалення. Стан екрана лежить у game.account_ui: seq — номер нинішнього екрана (відповідь, що прийшла,
## коли гравець уже пішов з екрана, нічого не перебудовує), waiting — чекаємо відповіді, note — рядок під станом.
## «Назад» (і системне) веде крок назад через game._menu_back, як у меню перенесення.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Cloud := preload("res://scripts/core/cloud.gd")
const FirebaseApi := preload("res://scripts/core/firebase_api.gd")

const W := Vector2(620, 60)
const TEXT_W := 940.0
const WAIT := "Зачекай…"
const OFFLINE_TEXT := "Немає зв'язку з хмарою. Грати можна й без мережі: рід зберігається на цьому пристрої."
const GUEST_TEXT := "Ти граєш як гість. Рід зберігається в хмарі, але дістатись до нього можна лише з цього пристрою. Прив'яжи пошту, щоб не втратити рід і грати на іншому телефоні."
const SIGNED_OUT_TEXT := "Ти вийшов з облікового запису. Рід лишається на цьому пристрої й у хмару не зберігається."
const CONFLICT_NOTE := "Рід, який ти не обереш, буде замінено. Рід із цього пристрою потім можна повернути в меню «Перенесення роду»."
const FORM_SPACER := 300  # порожнеча під формою: поля й кнопки стоять у верхній половині, над клавіатурою


static func _ui(game) -> Dictionary:
	return game.account_ui


## Новий екран: номер, щоб запізніла відповідь знала, що її екрана вже нема.
static func _screen(game, key: String) -> int:
	var u := _ui(game)
	u["seq"] = int(u.get("seq", 0)) + 1
	u["screen"] = key
	u["waiting"] = false
	game._open_menu(key, true)
	return u["seq"]


static func _still(game, seq: int) -> bool:
	return is_instance_valid(game) and int(_ui(game).get("seq", 0)) == seq


## Довгий текст із переносом рядків.
static func _text(game, text: String, size: int = 20, col: Color = UI.TEXT) -> Label:
	var l := UI.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	game.hud.overlay_box.add_child(l)
	return l


static func _btn(game, text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := UI.button(text, cb, W, 22, enabled)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # ширина меню, а не ширина тексту над кнопками
	game.hud.overlay_box.add_child(b)
	return b


## Дата й час для гравця (місцевий час пристрою): «14.11.2026 о 13:52».
static func when(unix: int) -> String:
	if unix <= 0:
		return "ще не було"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%02d.%02d.%d о %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


# ================= Екран облікового запису =================

## Відкрити екран облікового запису (або вибір роду, коли є розбіжність).
static func open(game, note: String = "", col: Color = UI.TEXT, waiting: bool = false) -> void:
	var c = game.cloud
	if c.conflict and not c.conflict_doc.is_empty() and not waiting:
		conflict(game)
		return
	var u := _ui(game)
	if note == "" and not waiting and u.has("pending_note"):
		note = u["pending_note"][0]  # повідомлення Cloud, що прийшло, поки гравець був на цих екранах
		col = UI.GOOD if u["pending_note"][1] else UI.BAD
	u.erase("pending_note")
	_screen(game, "account")
	u["waiting"] = waiting
	u["note"] = note
	u["note_col"] = col
	game._menu_back = game._show_main_menu
	game.hud.add_title("Обліковий запис", 52)
	var on: bool = not waiting and not c.is_busy()
	match str(c.state):
		Cloud.GUEST:
			_text(game, GUEST_TEXT)
		Cloud.EMAIL:
			game.hud.add_title("Обліковий запис: %s" % c.email(), 24, UI.GOLD)
			game.hud.add_title("Останнє збереження в хмару: %s" % when(c.last_sync()), 20, UI.TEXT)
		Cloud.SIGNED_OUT:
			_text(game, SIGNED_OUT_TEXT)
		Cloud.CONNECTING:
			game.hud.add_title("З'єднання з хмарою. " + WAIT, 22, UI.MUTED)
		_:
			_text(game, OFFLINE_TEXT)
	if c.newer_cloud:
		_text(game, Cloud.NEWER, 20, UI.BAD)
	if c.too_big:
		_text(game, Cloud.TOO_BIG, 20, UI.BAD)
	if c.last_error != "" and str(c.state) == Cloud.SIGNED_OUT:
		_text(game, c.last_error, 20, UI.BAD)
	if waiting:
		game.hud.add_title(WAIT, 22, UI.GOLD)
	elif note != "":
		_text(game, note, 22, col)
	match str(c.state):
		Cloud.GUEST:
			_btn(game, "Захистити рід: прив'язати пошту", form.bind(game, "bind"), on)
			_btn(game, "Увійти в наявний обліковий запис", form.bind(game, "signin"), on)
			_btn(game, "Зберегти в хмару зараз", upload_now.bind(game), on)
			_btn(game, "Видалити обліковий запис", confirm_delete.bind(game, 1), on)
		Cloud.EMAIL:
			_btn(game, "Зберегти в хмару зараз", upload_now.bind(game), on)
			_btn(game, "Вийти з облікового запису", confirm_sign_out.bind(game), on)
			_btn(game, "Видалити обліковий запис", confirm_delete.bind(game, 1), on)
		Cloud.SIGNED_OUT:
			_btn(game, "Увійти", form.bind(game, "signin"), on)
			_btn(game, "Грати як гість", play_as_guest.bind(game), on)
		Cloud.CONNECTING:
			pass
		_:
			_btn(game, "Спробувати ще раз", retry.bind(game), on)
	_btn(game, "Назад", game._show_main_menu)


## Cloud щось змінив: якщо гравець дивиться на екран облікового запису й нічого не чекає — показати нове.
static func refresh(game) -> void:
	var u := _ui(game)
	if str(u.get("screen", "")) != "account" or u.get("waiting", false) or game.hud._overlay_key != "account" or not game.hud.overlay.visible:
		return
	if u.has("pending_note"):
		open(game)
	else:
		open(game, str(u.get("note", "")), u.get("note_col", UI.TEXT))


## Дія з мережею на екрані облікового запису: «Зачекай…», потім екран наново з відповіддю.
static func _run(game, job: Callable) -> void:
	open(game, "", UI.TEXT, true)
	var seq := int(_ui(game)["seq"])
	var r = await job.call()
	if not _still(game, seq):
		return
	if r is Dictionary and str(r.get("text", "")) != "":
		open(game, r["text"], UI.GOOD if r.get("ok", false) else UI.BAD)
	else:
		open(game)


static func retry(game) -> void:
	await _run(game, func():
		await game.cloud.retry()
		return {})


static func upload_now(game) -> void:
	await _run(game, func(): return await game.cloud.upload_now())


static func play_as_guest(game) -> void:
	await _run(game, func():
		await game.cloud.play_as_guest()
		return {})


# ================= Пошта й пароль =================

## Форма: kind — "bind" (прив'язати пошту до гостя), "signin" (увійти), "delete" (пароль перед видаленням).
static func form(game, kind: String, why: String = "") -> void:
	var c = game.cloud
	var seq := _screen(game, "account_form")
	var u := _ui(game)
	u["form"] = kind
	game._menu_back = open.bind(game)
	var title: String = {"bind": "Прив'язати пошту", "signin": "Увійти в обліковий запис", "delete": "Видалити обліковий запис"}[kind]
	game.hud.add_title(title, 40)
	var sub: String = {"bind": "Пошта й пароль захистять рід. З ними можна увійти на будь-якому пристрої.",
		"signin": "Рід з облікового запису можна буде завантажити на цей пристрій.",
		"delete": "Для видалення введи пароль від %s ще раз." % c.email()}[kind]
	game.hud.add_title(sub, 20, UI.TEXT)
	var mail := LineEdit.new()
	# max_length полям не ставимо (див. екран імені в game.gd): Android рахує межу клавіатури неправильно
	mail.custom_minimum_size = Vector2(620, 60)
	mail.placeholder_text = "Пошта"
	mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	mail.add_theme_font_size_override("font_size", 26)
	mail.text = c.email() if kind != "bind" else ""
	mail.editable = kind != "delete"
	var pass_ := LineEdit.new()
	pass_.custom_minimum_size = Vector2(450, 60)
	pass_.placeholder_text = "Пароль (щонайменше 6 знаків)"
	pass_.secret = true
	pass_.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	pass_.add_theme_font_size_override("font_size", 26)
	var show := UI.button("Показати", func(): pass, Vector2(150, 60), 20)
	show.toggle_mode = true
	show.toggled.connect(func(on: bool):
		pass_.secret = not on
		show.text = "Сховати" if on else "Показати")
	game.hud.overlay_box.add_child(mail)
	game.hud.add_row([pass_, show])
	var hint := UI.label("", 20, UI.MUTED)
	hint.custom_minimum_size = Vector2(0, 28)
	game.hud.overlay_box.add_child(hint)
	var back := UI.button("Назад", open.bind(game), Vector2(230, 60), 22)
	var done := UI.button("Готово", func(): pass, Vector2(300, 60), 24)
	game.hud.add_row([back, done])
	var btns := [back, done, show]
	var forgot: Button = null
	if kind == "signin":
		forgot = UI.button("Забув пароль", func(): pass, Vector2(300, 52), 20)
		game.hud.add_row([forgot])
		btns.append(forgot)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, FORM_SPACER)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.overlay_box.add_child(spacer)
	u["mail"] = mail
	u["pass"] = pass_
	u["hint"] = hint
	u["buttons"] = btns
	var say := func(text: String, col: Color):
		hint.text = text
		hint.add_theme_color_override("font_color", col)
	var normal := "Пароль — щонайменше 6 знаків." if kind != "delete" else "Рід на цьому пристрої лишиться."
	say.call(why if why != "" else normal, UI.BAD if why != "" else UI.MUTED)
	var lock := func(on: bool):
		for b in btns:
			b.disabled = on
		mail.editable = not on and kind != "delete"
		pass_.editable = not on
		u["waiting"] = on
	var submit := func():
		if u.get("waiting", false):
			return
		var e := mail.text.strip_edges()
		var p := pass_.text
		var bad := Cloud.form_problem(e, p, true)
		if bad != "":
			say.call(bad, UI.BAD)
			return
		lock.call(true)
		say.call(WAIT, UI.GOLD)
		var r: Dictionary
		match kind:
			"bind":
				r = await c.bind_email(e, p)
			"signin":
				r = await c.sign_in(e, p)
			_:
				r = await c.delete_account(p)
		if not _still(game, seq):
			return
		if r["ok"]:
			if kind == "signin" and c.conflict:
				conflict(game)
			else:
				open(game, "" if kind == "bind" else str(r.get("text", "")), UI.GOOD)
			return
		lock.call(false)
		say.call(str(r.get("text", FirebaseApi.FAILED)), UI.BAD)
	done.pressed.connect(submit)
	pass_.text_submitted.connect(func(_t): submit.call())
	mail.text_submitted.connect(func(_t): pass_.grab_focus())
	mail.text_changed.connect(func(_t): say.call(normal, UI.MUTED))
	pass_.text_changed.connect(func(_t): say.call(normal, UI.MUTED))
	if forgot != null:
		forgot.pressed.connect(func():
			if u.get("waiting", false):
				return
			var e := mail.text.strip_edges()
			if not Cloud.email_ok(e):
				say.call("Спершу впиши пошту, на яку надіслати лист.", UI.BAD)
				return
			lock.call(true)
			say.call(WAIT, UI.GOLD)
			var r: Dictionary = await c.send_reset(e)
			if not _still(game, seq):
				return
			lock.call(false)
			say.call(str(r["text"]), UI.GOOD if r["ok"] else UI.BAD))


## Для тестів і знімків: вписати пошту й пароль у відкриту форму й натиснути «Готово».
static func fill(game, e: String, p: String) -> void:
	var u := _ui(game)
	u["mail"].text = e
	u["pass"].text = p
	u["buttons"][1].pressed.emit()


# ================= Розбіжність =================

static func conflict(game, note: String = "", col: Color = UI.BAD, waiting: bool = false) -> void:
	var c = game.cloud
	var doc: Dictionary = c.conflict_doc
	_screen(game, "account_conflict")
	_ui(game)["waiting"] = waiting
	game._menu_back = later.bind(game)
	game.hud.add_title("Який рід лишити?", 44)
	game.hud.add_title("У хмарі", 26, UI.GOLD)
	game.hud.add_title("Збережено: %s" % when(int(doc.get("updated", 0))), 18, UI.MUTED)
	game.hud.add_title("\n".join(doc.get("lines", [])) if not doc.get("lines", []).is_empty() else "Персонажів не названо.", 20, UI.TEXT)
	game.hud.add_title("На цьому пристрої", 26, UI.GOLD)
	var loc: Array = c.local()["lines"]
	game.hud.add_title("\n".join(loc) if not loc.is_empty() else "Персонажів немає.", 20, UI.TEXT)
	_text(game, CONFLICT_NOTE, 18, UI.MUTED)
	if waiting:
		game.hud.add_title(WAIT, 22, UI.GOLD)
	elif note != "":
		_text(game, note, 20, col)
	var on := not waiting
	_btn(game, "Взяти рід із хмари", take_cloud.bind(game), on)
	_btn(game, "Лишити рід із цього пристрою", confirm_keep.bind(game), on)
	_btn(game, "Вирішити пізніше", later.bind(game), on)


## «Вирішити пізніше»: розбіжність лишається, головне меню цю саму більше не нав'язує.
static func later(game) -> void:
	_ui(game)["later"] = str(game.cloud.conflict_doc.get("update_time", ""))
	game._show_main_menu()


static func take_cloud(game) -> void:
	conflict(game, "", UI.TEXT, true)
	var seq := int(_ui(game)["seq"])
	var r: Dictionary = await game.cloud.take_cloud()
	if not _still(game, seq):
		return
	if r["ok"]:
		_ui(game).erase("pending_note")
		game._show_main_menu()
		game.hud.show_banner(str(r["text"]), UI.GOOD)
	elif game.cloud.conflict:
		conflict(game, str(r["text"]))
	else:
		open(game, str(r["text"]), UI.BAD)


## «Лишити рід із цього пристрою» стирає хмарну копію назавжди: спершу друге підтвердження.
static func confirm_keep(game) -> void:
	var doc: Dictionary = game.cloud.conflict_doc
	_screen(game, "account_keep")
	game._menu_back = conflict.bind(game)
	game.hud.add_title("Замінити рід у хмарі?", 44)
	game.hud.add_title("Ці герої в хмарі зникнуть назавжди:", 22, UI.TEXT)
	game.hud.add_title("\n".join(doc.get("lines", [])) if not doc.get("lines", []).is_empty() else "Персонажів не названо.", 20, UI.GOLD)
	_btn(game, "Так, замінити рід у хмарі", keep_local.bind(game))
	_btn(game, "Ні", conflict.bind(game))


static func keep_local(game) -> void:
	conflict(game, "", UI.TEXT, true)
	var seq := int(_ui(game)["seq"])
	var r: Dictionary = await game.cloud.keep_local()
	if not _still(game, seq):
		return
	if r["ok"]:
		open(game, Cloud.SAVED, UI.GOOD)
	elif game.cloud.conflict:
		conflict(game, str(r["text"]) if str(r["text"]) != "" else "У хмарі знову щось нове. Вибери ще раз.")
	else:
		open(game, str(r["text"]), UI.BAD)


# ================= Вихід і видалення =================

static func confirm_sign_out(game) -> void:
	_screen(game, "account_out")
	game._menu_back = open.bind(game)
	game.hud.add_title("Вийти з облікового запису?", 44)
	_text(game, "Рід лишиться на цьому пристрої, але в хмару більше не зберігатиметься. Повернутись можна будь-коли: увійди знову з цією поштою й паролем.")
	_btn(game, "Так, вийти", func():
		game.cloud.sign_out()
		open(game))
	_btn(game, "Ні", open.bind(game))


static func confirm_delete(game, step: int) -> void:
	var guest := str(game.cloud.state) == Cloud.GUEST
	_screen(game, "account_delete")
	game._menu_back = open.bind(game)
	if step == 1:
		game.hud.add_title("Видалити обліковий запис?", 44)
		_text(game, "Рід у хмарі буде стерто назавжди. Рід на цьому пристрої лишиться: персонажі, хутір і скриня нікуди не зникнуть.")
		if guest:
			_text(game, "Гостя потім не повернути. Якщо захочеш знову зберігати рід у хмарі, натисни «Грати як гість».", 20, UI.MUTED)
		_btn(game, "Так, видалити", confirm_delete.bind(game, 2))
		_btn(game, "Ні", open.bind(game))
	else:
		game.hud.add_title("Точно видалити?", 44)
		_text(game, "Це не скасувати. Рід у хмарі зникне, а рід на цьому пристрої лишиться.", 22, UI.BAD)
		_btn(game, "Видалити назавжди", delete_now.bind(game))
		_btn(game, "Ні", open.bind(game))


static func delete_now(game) -> void:
	open(game, "", UI.TEXT, true)
	var seq := int(_ui(game)["seq"])
	var r: Dictionary = await game.cloud.delete_account()
	if not _still(game, seq):
		return
	if r.get("need_password", false):
		form(game, "delete")  # над полем уже сказано, що треба ввести пароль ще раз
		return
	open(game, str(r["text"]), UI.GOOD if r["ok"] else UI.BAD)


# ================= Головне меню =================

## Головне меню щойно показано: перевірити хмару; знайдено розбіжність — одразу вибір.
static func on_main_menu(game) -> void:
	var c = game.cloud
	if c == null or not c.started:
		return
	_ui(game)["screen"] = "main"
	if c.conflict and str(_ui(game).get("later", "")) != str(c.conflict_doc.get("update_time", "")):
		conflict(game)
		return
	await c.on_main_menu()
	c.sync_boards()


## Повідомлення Cloud (банер). На екранах облікового запису банер ліг би поверх тексту меню, тому там воно
## стає рядком на екрані облікового запису (open); деінде — звичайний банер.
static func on_notice(game, text: String, good: bool) -> void:
	if game.hud.overlay.visible and str(game.hud._overlay_key).begins_with("account"):
		_ui(game)["pending_note"] = [text, good]
		refresh(game)
	else:
		game.hud.show_banner(text, UI.GOOD if good else UI.BAD)


## Cloud знайшов розбіжність: у головному меню — одразу вибір, у грі — один банер.
static func on_conflict(game) -> void:
	if game.state != game.State.MENU:
		game.hud.show_banner(Cloud.CONFLICT_PLAY, UI.GOLD)
	elif str(_ui(game).get("screen", "")) in ["main", "account"] and game.hud._overlay_key in ["main", "account"]:
		conflict(game)
