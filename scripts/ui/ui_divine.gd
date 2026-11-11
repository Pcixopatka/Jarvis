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


## Ряд гнізд під звичайним спорядженням на екрані героя.
static func slots_row(game, sel: int, px: int) -> Control:
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(UI.label("Божі дари", 16, DIVINE_COLOR, false))
	var grid := UI.grid(Divine.SLOTS.size())
	for slot in Divine.SLOTS:
		var id: String = Divine.for_slot(slot)
		var on: bool = DivineService.wears(p, id)
		grid.add_child(_cell(str(Divine.DEFS[id]["icon"]), game.char_do.bind("select", sel_of(slot)), on, sel == sel_of(slot), px))
	v.add_child(grid)
	return v


## Картка дару на екрані героя: що дає, чи куплений, кнопка вдягти, зняти чи піти в крамницю.
static func detail(game, slot: String) -> Control:
	var p = game.player
	var w = game.world
	var id: String = Divine.for_slot(slot)
	var D: Dictionary = Divine.DEFS[id]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var have: bool = DivineService.owned(w, id)
	var on: bool = DivineService.wears(p, id)
	if have:
		v.add_child(UI.button("Зняти" if on else "Вдягнути", game.char_do.bind("divine_toggle", id), Vector2(170, 50), 19))
	else:
		v.add_child(UI.button("До крамниці • %d %s" % [int(D["price"]), Shop.COIN_SHORT], game.char_do.bind("divine_shop", id), Vector2(260, 50), 17))
	v.add_child(UI.label(str(D["name"]), 24, DIVINE_COLOR, false))
	v.add_child(UI.label("Божий дар • гніздо «%s»" % Divine.SLOT_NAMES[slot], 16, UI.MUTED, false))
	v.add_child(_wrap(str(D["desc"]), 16, UI.TEXT))
	for line in D["lines"]:
		v.add_child(_wrap("•  " + str(line), 17, UI.GOOD if on else UI.TEXT))
	v.add_child(_wrap("Вдягнено" if on else ("Куплено для всього роду, зараз знято" if have else "Продається в крамниці за червінці. Купується раз на весь рід."), 15, UI.GOOD if on else UI.MUTED))
	return v


## Вкладка «Божі дари» в крамниці.
static func shop_page(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_wrap("Божі дари вдягаються у власні гнізда на екрані героя, поруч зі спорядженням, і місця в торбі не займають. Купуються раз на весь рід: кожен герой вдягає їх окремо. На відміну від вбрання, вони дають силу й зручність.", 16, UI.TEXT))
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


## Крамниця Хованця: продати зайве й купити зілля будь-де, без дороги до міста.
static func trader(game) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(_wrap("Хованець збігає до крамаря замість тебе. Ціни звичайні, без міських знижок.", 16, UI.MUTED))
	var pprice: int = Data.potion_price(int(p.level))
	left.add_child(UI.label("Зілля здоров'я: %d/%d" % [p.potions, p.potion_max()], 20, UI.TEXT, false))
	left.add_child(UI.button("Купити зілля • %d грн" % pprice, game.trader_do.bind("buy_potion", 0), Vector2(340, 56), 18, p.gold >= pprice and p.potions < p.potion_max()))
	var mprice: int = Data.mana_potion_price(int(p.level))
	left.add_child(UI.label("Зілля наснаги: %d/%d" % [p.mana_potions, p.mana_potion_max()], 20, UI.TEXT, false))
	left.add_child(UI.button("Купити зілля наснаги • %d грн" % mprice, game.trader_do.bind("buy_mana", 0), Vector2(340, 56), 17, p.gold >= mprice and p.mana_potions < p.mana_potion_max()))
	left.add_child(UI.label("Продати гуртом", 20, UI.GOLD, false))
	for r in [0, 1, 2]:
		var cand: Array = CityService.bulk_candidates(p, r)
		var sum := 0
		for it in cand:
			sum += Data.sell_price(it)
		left.add_child(UI.button("Усе до «%s»: %d шт. за %s грн" % [str(Data.RARITY_NAMES[r]).to_lower(), cand.size(), UI.num(sum)], game.trader_do.bind("sell_upto", r), Vector2(340, 52), 15, not cand.is_empty()))
	left.add_child(_wrap("Гуртом не продаються золоті й наборні речі, речі з душами й ті, що кращі за вдягнені.", 14, UI.MUTED))

	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", 6)
	h.add_child(bag)
	bag.add_child(UI.label("Твоя торба %d/%d" % [p.inventory.size(), p.bag_size()], 22, UI.GOLD, false))
	var sel: int = game.trader_sel
	var bg := UI.grid(6)
	for it in p.inventory:
		if it.has("artifact"):
			continue  # артефакти не продають
		bg.add_child(UI.item_cell(it, game.trader_do.bind("select", it["uid"]), it["uid"] == sel, 72))
	bag.add_child(bg)

	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(320, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	var item: Dictionary = p.find_item(sel) if sel > 0 else {}
	if item.is_empty() or p.is_equipped(sel):
		det.add_child(UI.label("Торкнись речі в торбі,\nщоб продати її.", 19, UI.MUTED, false))
	else:
		det.add_child(UI.button("Продати за %s грн" % UI.num(Data.sell_price(item)), game.trader_do.bind("sell", sel), Vector2(300, 56), 19))
		det.add_child(UI.item_card(item))
	return UI.screen("Хованець: крамниця будь-де   •   %s грн" % UI.num(p.gold), "Назад", game.close_trader, [["Торгівля", h]], 0, func(_i: int): pass)
