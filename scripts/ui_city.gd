extends RefCounted
## Екран міста: дошка завдань, крамниця, коваль (заточка), корчма (супутники).
## Дії йдуть через main.city_do(дія, аргумент).

const Data := preload("res://scripts/data.gd")
const UI := preload("res://scripts/ui_kit.gd")


static func _do(main, action: String, arg = null) -> Callable:
	return main.city_do.bind(action, arg)


static func build(main, city: String) -> Control:
	var w = main.world
	var C: Dictionary = Data.CITIES[city]
	var lvl: int = w.loyalty_level(city)
	var pts: int = w.loyalty_points(city)
	var next := ""
	if lvl < Data.LOYALTY_THRESHOLDS.size() - 1:
		next = " (%d/%d)" % [pts, Data.LOYALTY_THRESHOLDS[lvl + 1]]
	var title := "%s  •  Лояльність: %s%s  •  Дукати: %d" % [C["name"], Data.LOYALTY_NAMES[lvl], next, main.player.gold]
	var pages := [
		["Завдання", _quests(main, city)],
		["Крамниця", _shop(main, city)],
		["Коваль", _smith(main)],
		["Корчма", _tavern(main, city)],
	]
	return UI.screen(title, "На мапу", main.leave_city, pages, main.city_tab, func(i: int): main.city_tab = i,
		[["Козак" + ((" +%d" % main.player.unspent_points()) if main.player.unspent_points() > 0 else ""), main.open_character]])


static func _reward_text(q: Dictionary) -> String:
	return "Нагорода: %d дукатів, %d досвіду, +%d лояльності" % [q["gold"], q["xp"], q["loyalty"]]


# ---------------- Завдання ----------------

static func _quests(main, city: String) -> Control:
	var w = main.world
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Лояльність міста дає знижки, кращий товар і нових супутників. Заробляй її завданнями.", 18, UI.MUTED, false))
	v.add_child(UI.label("Дошка оголошень", 24, UI.GOLD, false))
	for q in w.board(city):
		v.add_child(_quest_row(main, q, "take"))
	var mine := []
	for q in w.quests:
		if q["city"] == city:
			mine.append(q)
	v.add_child(UI.label("Твої завдання від цього міста   (усього активних: %d/%d)" % [w.quests.size(), Data.MAX_ACTIVE_QUESTS], 24, UI.GOLD, false))
	if mine.is_empty():
		v.add_child(UI.label("Немає.", 18, UI.MUTED, false))
	for q in mine:
		v.add_child(_quest_row(main, q, "active"))
	var others := []
	for q in w.quests:
		if q["city"] != city:
			others.append("%s — %s %d/%d" % [Data.place_name(q["city"]), q["text"], q["progress"], q["count"]])
	if not others.is_empty():
		v.add_child(UI.label("Завдання інших міст (здаються там):", 18, UI.MUTED, false))
		for t in others:
			v.add_child(UI.label("• " + t, 17, UI.MUTED, false))
	return v


static func _quest_row(main, q: Dictionary, mode: String) -> Control:
	var w = main.world
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: bool = w.is_done(q)
	var prog := "" if mode == "take" else ("   %d/%d" % [q["progress"], q["count"]])
	info.add_child(UI.label(q["text"] + prog, 21, UI.GOOD if done and mode != "take" else UI.TEXT, false))
	info.add_child(UI.label(_reward_text(q), 16, UI.MUTED, false))
	row.add_child(info)
	if mode == "take":
		row.add_child(UI.button("Взяти", _do(main, "take", q["id"]), Vector2(170, 58), 22, w.can_take()))
	else:
		if done:
			row.add_child(UI.button("Здати", _do(main, "turn_in", q["id"]), Vector2(170, 58), 22))
		else:
			row.add_child(UI.button("Відмовитись", _do(main, "abandon", q["id"]), Vector2(170, 58), 18))
	return row


# ---------------- Крамниця ----------------

static func _shop(main, city: String) -> Control:
	var p = main.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = main.city_sel_uid
	var stock: Array = main.shop_stock(city)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	var disc: float = main.world.discount(city)
	left.add_child(UI.label("Товари" + (("  (знижка %d%%)" % roundi(disc * 100)) if disc > 0 else ""), 22, UI.GOLD, false))
	var sg := UI.grid(2)
	for it in stock:
		sg.add_child(UI.item_button(it, _do(main, "select", it["uid"]), it["uid"] == sel, "%d дук." % main.buy_price(city, it)))
	if stock.is_empty():
		left.add_child(UI.label("Усе розкупили.\nЗазирни після походу.", 17, UI.MUTED, false))
	left.add_child(sg)
	h.add_child(left)

	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", 6)
	bag.add_child(UI.label("Твоя торба %d/%d" % [p.inventory.size(), Data.INVENTORY_SIZE], 22, UI.GOLD, false))
	var bg := UI.grid(3)
	for it in p.inventory:
		bg.add_child(UI.item_button(it, _do(main, "select", it["uid"]), it["uid"] == sel, "+%d дук." % Data.sell_price(it)))
	bag.add_child(bg)
	bag.add_child(UI.button("Продати всі звичайні", _do(main, "sell_junk"), Vector2(300, 52), 18))
	h.add_child(bag)

	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(320, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	var shop_item: Dictionary = {}
	for it in stock:
		if it["uid"] == sel:
			shop_item = it
	if not shop_item.is_empty():
		det.add_child(UI.item_card(shop_item, p.equipment.get(shop_item["slot"], {})))
		var price: int = main.buy_price(city, shop_item)
		det.add_child(UI.button("Купити за %d" % price, _do(main, "buy", sel), Vector2(300, 60), 22, p.gold >= price and not p.bag_full()))
	else:
		var it: Dictionary = p.find_item(sel) if sel > 0 else {}
		if not it.is_empty() and not p.is_equipped(sel):
			det.add_child(UI.item_card(it, p.equipment.get(it["slot"], {})))
			det.add_child(UI.button("Продати за %d" % Data.sell_price(it), _do(main, "sell", sel), Vector2(300, 60), 22))
		else:
			det.add_child(UI.label("Торкнись товару або\nсвоєї речі.", 20, UI.MUTED, false))
	return h


# ---------------- Коваль ----------------

static func _smith(main) -> Control:
	var p = main.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = main.city_sel_uid

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.add_child(UI.label("Вдягнуте", 22, UI.GOLD, false))
	var eg := UI.grid(3)
	for slot in Data.SLOTS:
		if p.equipment.has(slot):
			var it: Dictionary = p.equipment[slot]
			eg.add_child(UI.item_button(it, _do(main, "select", it["uid"]), it["uid"] == sel))
	list.add_child(eg)
	list.add_child(UI.label("Торба", 22, UI.GOLD, false))
	var bg := UI.grid(3)
	for it in p.inventory:
		bg.add_child(UI.item_button(it, _do(main, "select", it["uid"]), it["uid"] == sel))
	list.add_child(bg)
	h.add_child(list)

	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(360, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	det.add_child(UI.label("Заточка робить усі бонуси речі сильнішими\n(+%d%% за рівень, максимум +%d).\nЗ +%d невдача знижує заточку на 1." % [roundi(Data.UPGRADE_BONUS * 100), Data.MAX_UPGRADE, Data.SHARPEN_RISK_FROM], 16, UI.MUTED, false))
	var it: Dictionary = p.find_item(sel) if sel > 0 else {}
	if it.is_empty():
		det.add_child(UI.label("Обери річ для заточки.", 20, UI.MUTED, false))
		return h
	det.add_child(UI.item_card(it))
	if it["up"] >= Data.MAX_UPGRADE:
		det.add_child(UI.label("Заточено до межі!", 22, UI.GOLD, false))
	else:
		var cost := Data.sharpen_cost(it)
		var chance := Data.sharpen_chance(it)
		var risk := "  ризик -1" if it["up"] >= Data.SHARPEN_RISK_FROM else ""
		det.add_child(UI.button("Заточити до +%d\n%d дук. • шанс %d%%%s" % [it["up"] + 1, cost, roundi(chance * 100), risk], _do(main, "sharpen", sel), Vector2(340, 80), 20, p.gold >= cost))
	if main.smith_msg != "":
		det.add_child(UI.label(main.smith_msg, 22, main.smith_msg_color, false))
	return h


# ---------------- Корчма ----------------

static func _tavern(main, city: String) -> Control:
	var w = main.world
	var p = main.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Твій загін (%d/%d). Поранені супутники одужують у будь-якому місті." % [w.companions.size(), Data.MAX_COMPANIONS], 22, UI.GOLD, false))
	if w.companions.is_empty():
		v.add_child(UI.label("Поки що ти сам.", 18, UI.MUTED, false))
	for i in w.companions.size():
		var c: Dictionary = w.companions[i]
		var row := HBoxContainer.new()
		var l := UI.label("%s%s" % [Data.COMPANIONS[c["type"]]["name"], "  (поранений)" if c["downed"] else ""], 22, UI.TEXT, false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.button("Відпустити", _do(main, "dismiss", i), Vector2(190, 54), 18))
		v.add_child(row)
	v.add_child(UI.label("Найняти", 24, UI.GOLD, false))
	var lvl: int = w.loyalty_level(city)
	for type in Data.COMPANIONS:
		var info: Dictionary = Data.COMPANIONS[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hp: int = int(info["hp"] + info["hp_lvl"] * (p.level - 1))
		var dmg: int = int(info["dmg"] + info["dmg_lvl"] * (p.level - 1))
		col.add_child(UI.label("%s — здоров'я %d, шкода %d" % [info["name"], hp, dmg], 22, UI.TEXT, false))
		col.add_child(UI.label(info["desc"].replace("\n", " "), 16, UI.MUTED, false))
		var need: int = info["loyalty"]
		if lvl < need:
			col.add_child(UI.label("Потрібна лояльність міста: %s" % Data.LOYALTY_NAMES[need], 16, UI.BAD, false))
		row.add_child(col)
		var price: int = main.hire_price(city, type)
		var ok: bool = lvl >= need and p.gold >= price and w.companions.size() < Data.MAX_COMPANIONS and not w.has_companion(type)
		row.add_child(UI.button("Найняти\n%d дук." % price, _do(main, "hire", type), Vector2(190, 70), 18, ok))
		v.add_child(row)
	return v
