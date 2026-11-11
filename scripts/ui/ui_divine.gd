extends RefCounted
## Божі дари в інтерфейсі: гнізда на екрані героя, картка дару, вкладка крамниці й крамниця Хованця.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Shop := preload("res://scripts/data/shop.gd")
const Divine := preload("res://scripts/data/divine.gd")
const DivineService := preload("res://scripts/game/divine_service.gd")
const CityService := preload("res://scripts/game/city_service.gd")

const DIVINE_COLOR := Color(1.0, 0.82, 0.4)
const CARD_BG := Color(0.14, 0.11, 0.09)
const CARD_LINE := Color(0.45, 0.36, 0.22)
const SEL_BASE := -10  # вибране гніздо дару на екрані героя: -10 - номер гнізда


static func sel_of(slot: String) -> int:
	return SEL_BASE - Divine.SLOTS.find(slot)


## Яке гніздо вибрано ("" — жодне).
static func slot_of(sel: int) -> String:
	var i := SEL_BASE - sel
	return str(Divine.SLOTS[i]) if i >= 0 and i < Divine.SLOTS.size() else ""


static func _wrap(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l


## Клітинка гнізда: яскрава, коли дар вдягнено; бліда, коли ні.
static func _cell(icon_id: String, cb: Callable, on: bool, selected: bool, px: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.clip_contents = true
	var bg := DIVINE_COLOR.darkened(0.6 if on else 0.9)
	var edge := Color(1.0, 0.95, 0.75) if selected else (DIVINE_COLOR if on else Color(0.28, 0.23, 0.18))
	b.add_theme_stylebox_override("normal", UI.style(bg, edge, 8, 2))
	b.add_theme_stylebox_override("hover", UI.style(bg.lightened(0.08), edge, 8, 2))
	b.add_theme_stylebox_override("pressed", UI.style(bg.darkened(0.15), edge, 8, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var t := UI.icon(icon_id, px - 22)
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-(px - 22) / 2.0, -(px - 22) / 2.0)
	if not on:
		t.modulate = Color(1, 1, 1, 0.28)
	b.add_child(t)
	b.pressed.connect(cb)
	return b


## Гнізда під звичайним спорядженням на екрані героя: по чотири в ряд.
## У клітинці значок вдягненого дару, а коли гніздо порожнє, блідий значок першого дару цього гнізда.
static func slots_row(game, sel: int, px: int) -> Control:
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(UI.label("Божі дари", 16, DIVINE_COLOR, false))
	var grid := UI.grid(4)
	for slot in Divine.SLOTS:
		var worn: String = DivineService.worn(p, slot)
		var on: bool = worn != "" and Divine.has(worn)
		var id: String = worn if on else str(Divine.in_slot(slot)[0])
		grid.add_child(_cell(str(Divine.DEFS[id]["icon"]), game.char_do.bind("select", sel_of(slot)), on, sel == sel_of(slot), px))
	v.add_child(grid)
	return v


## Картка гнізда на екрані героя: усі дари, що сюди лягають, і для кожного кнопка вдягти, зняти чи піти в крамницю.
static func detail(game, slot: String) -> Control:
	var p = game.player
	var w = game.world
	var ids: Array = Divine.in_slot(slot)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Гніздо «%s»" % Divine.SLOT_NAMES[slot], 22, DIVINE_COLOR, false))
	if ids.size() > 1:
		v.add_child(_wrap("У це гніздо лягає один дар із %d: обирай, який зараз потрібніший." % ids.size(), 15, UI.MUTED))
	for id in ids:
		var D: Dictionary = Divine.DEFS[id]
		var have: bool = DivineService.owned(w, id)
		var on: bool = DivineService.wears(p, id)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.style(CARD_BG, DIVINE_COLOR if on else CARD_LINE, 10, 8))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(UI.icon(str(D["icon"]), 40))
		var nl := UI.label(str(D["name"]), 20, DIVINE_COLOR, false)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nl)
		box.add_child(head)
		box.add_child(_wrap(str(D["desc"]), 15, UI.TEXT))
		for line in D["lines"]:
			box.add_child(_wrap("•  " + str(line), 16, UI.GOOD if on else UI.TEXT))
		if have:
			var acts := HBoxContainer.new()
			acts.add_theme_constant_override("separation", 8)
			acts.add_child(UI.button("Зняти" if on else "Вдягнути", game.char_do.bind("divine_toggle", id), Vector2(150, 46), 18))
			if on and D.get("shop", false):
				acts.add_child(UI.button("Відкрити крамницю", game.char_do.bind("trader", null), Vector2(210, 46), 16))
			box.add_child(acts)
			box.add_child(_wrap("Вдягнено" if on else "Куплено для всього роду, зараз знято", 14, UI.GOOD if on else UI.MUTED))
		else:
			box.add_child(UI.button("До крамниці • %d %s" % [int(D["price"]), Shop.COIN_SHORT], game.char_do.bind("divine_shop", id), Vector2(260, 46), 16))
		v.add_child(panel)
	return v


## Вкладка «Божі дари» в крамниці.
static func shop_page(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_wrap("Божі дари вдягаються у власні гнізда на екрані героя, поруч зі спорядженням, і місця в торбі не займають. Купуються раз на весь рід: кожен герой вдягає їх окремо. У гнізді лежить один дар: де їх два, герой обирає. На відміну від вбрання, дари дають силу й зручність.", 16, UI.TEXT))
	var grid := UI.grid(2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in Divine.ORDER:
		var D: Dictionary = Divine.DEFS[id]
		var have: bool = DivineService.owned(w, id)
		var on: bool = DivineService.wears(p, id)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UI.style(CARD_BG, DIVINE_COLOR if on else CARD_LINE, 10, 10))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)
		h.add_child(UI.icon(str(D["icon"]), 80))
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 2)
		h.add_child(left)
		left.add_child(_wrap(str(D["name"]), 20, DIVINE_COLOR))
		left.add_child(_wrap("Гніздо «%s»" % Divine.SLOT_NAMES[D["slot"]], 14, UI.MUTED))
		left.add_child(_wrap(str(D["desc"]), 15, UI.TEXT))
		for line in D["lines"]:
			left.add_child(_wrap("•  " + str(line), 15, UI.GOOD))
		var right := VBoxContainer.new()
		right.custom_minimum_size = Vector2(170, 0)
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.add_theme_constant_override("separation", 2)
		h.add_child(right)
		if have:
			right.add_child(UI.button("Зняти" if on else "Вдягнути", game.shop_do.bind("divine", id), Vector2(170, 64), 19))
			right.add_child(_wrap("Куплено для роду", 13, UI.MUTED))
		else:
			var why: String = DivineService.block_reason(w, id)
			var confirm: bool = game.shop_confirm == "divine:" + id and why == ""
			var b := UI.button(("Підтвердити\n%d %s" if confirm else "Купити\n%d %s") % [DivineService.price(id), Shop.COIN_SHORT], game.shop_do.bind("divine", id), Vector2(170, 64), 18, why == "")
			if confirm:
				b.modulate = Color(1.0, 1.0, 0.6)
			right.add_child(b)
			if why != "":
				right.add_child(_wrap(why, 13, UI.BAD))
		grid.add_child(panel)
	return v


## Крамниця Хованця: та сама крамниця, що й у місті (товари, зілля, продаж поодинці, гуртом і
## кількох вибраних речей), лише відкривається будь-де. Товар і ціни беруться з міста game.trader_city.
static func trader(game) -> Control:
	var p = game.player
	var city: String = game.trader_city
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_wrap("Хованець збігав до крамаря замість тебе: %s. Товар, ціни й знижка тамтешні." % Data.place_name(city), 15, UI.MUTED))
	v.add_child(load("res://scripts/ui/ui_city.gd")._shop(game, city))
	return UI.screen("Хованець: крамниця будь-де   •   %s грн" % UI.num(p.gold), "Назад", game.close_trader, [["Крамниця", v]], 0, func(_i: int): pass)
