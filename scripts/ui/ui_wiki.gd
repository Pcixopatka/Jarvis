extends RefCounted
## Екран довідника: вкладки за розділами WikiService, у кожній картки зі значком, назвою, підписом і текстом.
## Остання вкладка — пошук по всьому довіднику. Відкривається з головного меню, паузи, привалу на мапі
## й вкладки «Події» на екрані героя (game.open_wiki).

const UI := preload("res://scripts/ui/ui_kit.gd")
const WikiService := preload("res://scripts/game/wiki_service.gd")

const CARD_BG := Color(0.14, 0.11, 0.09)
const CARD_LINE := Color(0.45, 0.36, 0.22)


static func build(game) -> Control:
	var pages := []
	for s in WikiService.sections():
		pages.append([s["title"], _page(s["entries"])])
	pages.append(["Пошук", _search_page(game)])
	var screen := UI.screen("Довідник • %d статей" % _count(), "Назад", game.close_wiki, pages, game.wiki_tab, func(i: int): game.wiki_tab = i)
	# Довідник відкривається й посеред бою (з паузи), тож під ним — суцільне тло, а не арена
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UI.style(Color(0.12, 0.16, 0.1), Color(0.12, 0.16, 0.1), 0, 0))
	bg.add_child(screen)
	return bg


static func _count() -> int:
	var n := 0
	for s in WikiService.sections():
		n += s["entries"].size()
	return n


## Сторінка розділу: заголовки груп і картки по дві в ряд.
static func _page(entries: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var grid: GridContainer = null
	for e in entries:
		if str(e["head"]) != "" or grid == null:
			if str(e["head"]) != "":
				v.add_child(UI.label(e["head"], 24, UI.GOLD, false))
			grid = UI.grid(2)
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 10)
			v.add_child(grid)
		grid.add_child(card(e))
	return v


## Картка одного запису.
static func card(e: Dictionary, section: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.style(CARD_BG, CARD_LINE, 10, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var icon := _icon(e.get("icon", {}))
	if icon != null:
		h.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	h.add_child(col)
	col.add_child(_wrap(str(e["title"]), 21, UI.GOLD))
	var sub := str(e["sub"])
	if section != "":
		sub = section + ((" • " + sub) if sub != "" else "")
	if sub != "":
		col.add_child(_wrap(sub, 15, UI.MUTED))
	if str(e["text"]) != "":
		col.add_child(_wrap(str(e["text"]), 16, UI.TEXT))
	return panel


static func _icon(icon: Dictionary) -> Control:
	if icon.has("sprite"):
		return UI.sprite_icon(str(icon["sprite"]), 64)
	if icon.has("map"):
		return UI.map_icon(str(icon["map"]), 48)
	if icon.has("loot"):
		return UI.icon(str(icon["loot"]), 44)
	return null


static func _wrap(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l


## Пошук: рядок і знахідки під ним (оновлюються, щойно змінюється текст).
static func _search_page(game) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Пошук по довіднику", 24, UI.GOLD, false))
	var edit := LineEdit.new()
	edit.placeholder_text = "Що шукаєш? Наприклад: Вій, зілля, ярмарок"
	edit.custom_minimum_size = Vector2(600, 56)
	edit.add_theme_font_size_override("font_size", 22)
	edit.text = game.wiki_query
	v.add_child(edit)
	var found := VBoxContainer.new()
	found.add_theme_constant_override("separation", 10)
	v.add_child(found)
	var refresh := func(q: String):
		game.wiki_query = q
		for c in found.get_children():
			c.queue_free()
		if q.strip_edges().length() < 2:
			found.add_child(UI.label("Введи хоча б дві літери.", 17, UI.MUTED, false))
			return
		var res: Array = WikiService.search(q)
		if res.is_empty():
			found.add_child(UI.label("Нічого не знайдено.", 17, UI.MUTED, false))
			return
		found.add_child(UI.label("Знайдено: %d" % res.size(), 17, UI.TEXT, false))
		for r in res:
			found.add_child(card(r["entry"], r["section"]))
	edit.text_changed.connect(refresh)
	refresh.call(edit.text)
	return v
