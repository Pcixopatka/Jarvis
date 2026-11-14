extends RefCounted
## Спільна таблиця рекорду (екран героя → «Слава» → «Таблиця»). Читає Cloud.board(); стан екрана — у
## game.board_view: "status" (loading, offline, ready), "data" (відповідь Cloud.board), "confirm" ({uid, name} —
## питаємо, чи скаржитись), "note" (рядок під списком). «Назад» і системне «Назад» ведуть до екрана героя.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const Classes := preload("res://scripts/data/classes.gd")
const RecordService := preload("res://scripts/game/record_service.gd")

const WAIT := "Зачекай…"
const OFFLINE := "Таблиця доступна, коли є зв'язок із хмарою."
const EMPTY := "Тут ще нікого немає. Будь першим."
const ROW_BG := Color(0.13, 0.11, 0.08)
const MINE_BG := Color(0.3, 0.22, 0.08)


## Відкрити таблицю рекорду key і прочитати її.
static func open(game, key: String) -> void:
	game.board_key = key
	game.board_view = {"status": "loading", "seq": int(game.board_view.get("seq", 0)) + 1}
	show(game)
	await load_rows(game)


## Прочитати таблицю (з кешу Cloud, якщо свіжа) і показати.
static func load_rows(game) -> void:
	var key: String = game.board_key
	var c = game.cloud
	if c == null or not c.started or not c.is_signed_in():
		game.board_view["status"] = "offline"
		show(game)
		return
	game.board_view["status"] = "loading"
	game.board_view["note"] = ""
	show(game)
	var seq: int = game.board_view["seq"]
	var r: Dictionary = await c.board(key)
	if not is_instance_valid(game) or game.board_key != key or int(game.board_view.get("seq", -1)) != seq:
		return  # гравець уже пішов з екрана
	game.board_view["status"] = "ready" if r["ok"] else "offline"
	game.board_view["data"] = r
	show(game)


static func show(game) -> void:
	game.hud.set_screen(build(game), "board")


static func class_name_of(cls: String) -> String:
	return str(Classes.info(cls).get("name", "Козак")) if Classes.has_class(cls) else "Козак"


## Рядок таблиці: «3. Сірко, Козак 41 — 12 поверх».
static func row_text(key: String, place: int, row: Dictionary) -> String:
	return "%d. %s, %s %d — %s" % [place, row["name"], class_name_of(str(row["cls"])), int(row["level"]), RecordService.value_text(key, int(row["value"]))]


static func build(game) -> Control:
	var key: String = game.board_key
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var view: Dictionary = game.board_view
	var status := str(view.get("status", "loading"))
	var conf: Dictionary = view.get("confirm", {})
	if not conf.is_empty():
		v.add_child(UI.label("Поскаржитись на ім'я «%s»? Ми перевіримо його." % conf["name"], 24, UI.TEXT))
		var yes := UI.button("Так, поскаржитись", func(): _send_report(game), Vector2(360, 64), 22)
		var no := UI.button("Ні", func():
			game.board_view.erase("confirm")
			show(game), Vector2(200, 64), 22)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		row.add_child(yes)
		row.add_child(no)
		v.add_child(row)
	elif status == "loading":
		v.add_child(UI.label(WAIT, 24, UI.GOLD))
	elif status == "offline":
		v.add_child(UI.label(OFFLINE, 22, UI.TEXT))
	else:
		var data: Dictionary = view.get("data", {})
		var rows: Array = data.get("rows", [])
		if rows.is_empty():
			v.add_child(UI.label(EMPTY, 22, UI.TEXT))
		for i in rows.size():
			v.add_child(_row(game, key, i + 1, rows[i]))
		var place := int(data.get("place", 0))
		var mine := int(data.get("mine", 0))
		v.add_child(UI.label("Твоє місце: %d" % place if mine > 0 and place > 0 else "Тебе ще немає в таблиці.", 22, UI.GOLD))
	if str(view.get("note", "")) != "":
		v.add_child(UI.label(str(view["note"]), 20, UI.BAD if view.get("note_bad", false) else UI.GOOD))
	var title := "%s • таблиця гравців" % GameDB.row("records", key)["name"]
	var extra := [] if status == "offline" else [["Оновити", func(): load_rows(game)]]
	var screen := UI.screen(title, "Назад", game.close_board, [["Найкращі", v]], 0, func(_i): pass, extra)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UI.style(Color(0.1, 0.09, 0.07), Color(0.1, 0.09, 0.07), 0, 0))
	bg.add_child(screen)
	return bg


static func _row(game, key: String, place: int, row: Dictionary) -> Control:
	var mine: bool = row.get("mine", false)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style(MINE_BG if mine else ROW_BG, UI.GOLD if mine else ROW_BG.lightened(0.15), 8, 6))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var l := UI.label(row_text(key, place, row) + ("   (ти)" if mine else ""), 20, UI.GOLD if mine else UI.TEXT, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	if not mine:
		var done: bool = game.cloud != null and game.cloud.reported(key, str(row["uid"]))
		var b := UI.button("Надіслано" if done else "Скарга", func():
			game.board_view["confirm"] = {"uid": str(row["uid"]), "name": str(row["name"])}
			show(game), Vector2(150, 44), 16, not done)
		h.add_child(b)
	return panel


static func _send_report(game) -> void:
	var conf: Dictionary = game.board_view.get("confirm", {})
	if conf.is_empty():
		return
	game.board_view.erase("confirm")
	game.board_view["note"] = WAIT
	game.board_view["note_bad"] = false
	show(game)
	var key: String = game.board_key
	var r: Dictionary = await game.cloud.report_name(key, conf["uid"], conf["name"])
	if not is_instance_valid(game) or game.board_key != key:
		return
	game.board_view["note"] = r["text"]
	game.board_view["note_bad"] = not r["ok"]
	show(game)
