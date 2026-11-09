extends RefCounted
## Екран міста: дошка завдань, крамниця, коваль (заточка), корчма (супутники).
## Дії йдуть через game.city_do(дія, аргумент).

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")


static func _do(game, action: String, arg = null) -> Callable:
	return game.city_do.bind(action, arg)


static func build(game, city: String) -> Control:
	var w = game.world
	var C: Dictionary = Data.CITIES[city]
	var lvl: int = w.loyalty_level(city)
	var pts: int = w.loyalty_points(city)
	var next := ""
	if lvl < Data.LOYALTY_THRESHOLDS.size() - 1:
		next = " (%d/%d)" % [pts, Data.LOYALTY_THRESHOLDS[lvl + 1]]
	var title := "%s  •  Лояльність: %s%s  •  Гривні: %d" % [C["name"], Data.LOYALTY_NAMES[lvl], next, game.player.gold]
	var pages := [
		["Завдання", _quests(game, city)],
		["Крамниця", _shop(game, city)],
		["Коваль", _smith(game)],
		["Корчма", _tavern(game, city)],
	]
	return UI.screen(title, "На мапу", game.leave_city, pages, game.city_tab, func(i: int): game.city_tab = i,
		[["Козак" + ((" +%d" % game.player.unspent_points()) if game.player.unspent_points() > 0 else ""), game.open_character]])


static func _reward_text(q: Dictionary) -> String:
	return "Нагорода: %d грн, %d досвіду, +%d лояльності" % [q["gold"], q["xp"], q["loyalty"]]


# ---------------- Завдання ----------------

static func _quests(game, city: String) -> Control:
	var w = game.world
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var story_line: String = game.StoryService.objective_line(w)
	if story_line != "":
		v.add_child(UI.label(game.StoryService.chapter_title(w), 22, UI.GOLD, false))
		v.add_child(UI.label(story_line, 20, UI.TEXT, false))
	v.add_child(UI.label("Лояльність міста дає знижки, кращий товар і нових супутників. Заробляй її завданнями.", 18, UI.MUTED, false))
	v.add_child(UI.label("Дошка оголошень", 24, UI.GOLD, false))
	for q in w.board(city):
		v.add_child(_quest_row(game, q, "take"))
	var mine := []
	for q in w.quests:
		if q["city"] == city:
			mine.append(q)
	v.add_child(UI.label("Твої завдання від цього міста   (усього активних: %d/%d)" % [w.quests.size(), Data.MAX_ACTIVE_QUESTS], 24, UI.GOLD, false))
	if mine.is_empty():
		v.add_child(UI.label("Немає.", 18, UI.MUTED, false))
	for q in mine:
		v.add_child(_quest_row(game, q, "active"))
	var others := []
	for q in w.quests:
		if q["city"] != city:
			others.append("%s — %s %d/%d" % [Data.place_name(q["city"]), q["text"], q["progress"], q["count"]])
	if not others.is_empty():
		v.add_child(UI.label("Завдання інших міст (здаються там):", 18, UI.MUTED, false))
		for t in others:
			v.add_child(UI.label("• " + t, 17, UI.MUTED, false))
	return v


static func _quest_row(game, q: Dictionary, mode: String) -> Control:
	var w = game.world
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
		row.add_child(UI.button("Взяти", _do(game, "take", q["id"]), Vector2(170, 58), 22, w.can_take()))
	else:
		if done:
			row.add_child(UI.button("Здати", _do(game, "turn_in", q["id"]), Vector2(170, 58), 22))
		else:
			row.add_child(UI.button("Відмовитись", _do(game, "abandon", q["id"]), Vector2(170, 58), 18))
	return row


# ---------------- Крамниця ----------------

static func _shop(game, city: String) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = game.city_sel_uid
	var stock: Array = game.shop_stock(city)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	var disc: float = game.world.discount(city)
	left.add_child(UI.label("Товари" + (("  (знижка %d%%)" % roundi(disc * 100)) if disc > 0 else ""), 22, UI.GOLD, false))
	var sg := UI.grid(2)
	for it in stock:
		sg.add_child(UI.item_button(it, _do(game, "select", it["uid"]), it["uid"] == sel, "%d грн" % game.buy_price(city, it)))
	if stock.is_empty():
		left.add_child(UI.label("Усе розкупили.\nЗазирни після походу.", 17, UI.MUTED, false))
	left.add_child(sg)
	h.add_child(left)

	var pprice: int = game.CityService.potion_price(game.world, p, city)
	left.add_child(UI.label("Зілля здоров'я: %d/%d" % [p.potions, p.potion_max()], 20, UI.TEXT, false))
	left.add_child(UI.label("Лікує %d%% здоров'я в бою" % roundi(Data.POTION_HEAL * 100), 15, UI.MUTED, false))
	left.add_child(UI.button("Купити зілля • %d грн" % pprice, _do(game, "buy_potion"), Vector2(306, 56), 18, p.gold >= pprice and p.potions < p.potion_max()))

	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", 6)
	bag.add_child(UI.label("Твоя торба %d/%d" % [p.inventory.size(), p.bag_size()], 22, UI.GOLD, false))
	var bg := UI.grid(3)
	for it in p.inventory:
		bg.add_child(UI.item_button(it, _do(game, "select", it["uid"]), it["uid"] == sel, "+%d грн" % Data.sell_price(it)))
	bag.add_child(bg)
	bag.add_child(UI.button("Продати всі звичайні", _do(game, "sell_junk"), Vector2(300, 52), 18))
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
		var price: int = game.buy_price(city, shop_item)
		det.add_child(UI.button("Купити за %d" % price, _do(game, "buy", sel), Vector2(300, 60), 22, p.gold >= price and not p.bag_full()))
	else:
		var it: Dictionary = p.find_item(sel) if sel > 0 else {}
		if not it.is_empty() and not p.is_equipped(sel):
			det.add_child(UI.item_card(it, p.equipment.get(it["slot"], {})))
			det.add_child(UI.button("Продати за %d" % Data.sell_price(it), _do(game, "sell", sel), Vector2(300, 60), 22))
		else:
			det.add_child(UI.label("Торкнись товару або\nсвоєї речі.", 20, UI.MUTED, false))
	return h


# ---------------- Коваль ----------------

static func _smith(game) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = game.city_sel_uid

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.add_child(UI.label("Вдягнуте", 22, UI.GOLD, false))
	var eg := UI.grid(3)
	for slot in Data.SLOTS:
		if p.equipment.has(slot):
			var it: Dictionary = p.equipment[slot]
			eg.add_child(UI.item_button(it, _do(game, "select", it["uid"]), it["uid"] == sel))
	list.add_child(eg)
	list.add_child(UI.label("Торба", 22, UI.GOLD, false))
	var bg := UI.grid(3)
	for it in p.inventory:
		bg.add_child(UI.item_button(it, _do(game, "select", it["uid"]), it["uid"] == sel))
	list.add_child(bg)
	h.add_child(list)

	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(360, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	det.add_child(UI.label("Заточка робить усі бонуси речі сильнішими\n(+%d%% за рівень, максимум +%d).\nЗ +%d невдача знижує заточку на 1." % [roundi(Data.UPGRADE_BONUS * 100), Data.MAX_UPGRADE, Data.SHARPEN_RISK_FROM], 16, UI.MUTED, false))
	var safe_n: int = game.AdRewards.safe_tokens(game.world)
	det.add_child(UI.label("Безпечних заточок: %d" % safe_n, 16, UI.TEXT, false))
	det.add_child(UI.button("Реклама: +1 безпечна заточка (сьогодні ще %d)" % game.AdRewards.safe_left_today(game.world), _do(game, "ad_safe"), Vector2(360, 52), 15, game.AdRewards.safe_left_today(game.world) > 0))
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
		var risk := ""
		if it["up"] >= Data.SHARPEN_RISK_FROM:
			risk = "  без ризику" if safe_n > 0 else "  ризик -1"
		det.add_child(UI.button("Заточити до +%d\n%d грн • шанс %d%%%s" % [it["up"] + 1, cost, roundi(chance * 100), risk], _do(game, "sharpen", sel), Vector2(340, 80), 20, p.gold >= cost))
	if game.smith_msg != "":
		det.add_child(UI.label(game.smith_msg, 22, game.smith_msg_color, false))
	return h


# ---------------- Корчма ----------------

static func _hero_status(w, HS, hid: String) -> String:
	var h: Dictionary = HS.info(hid)
	var s: Dictionary = HS.st(w, hid)
	match s["quest"]:
		"done":
			return "Побратим навіки. " + h["bio"]
		"active", "turnin":
			return "Особисте завдання: " + h["quest"]["objective"]["text"]
		"offer":
			return "Хоче з тобою поговорити — зайди в місто."
	return "Дружба: %d/%d (росте з кожним ворогом, переможеним разом)" % [mini(s["bond"], h["quest_bond"]), h["quest_bond"]]

static func _tavern(game, city: String) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Твій загін (%d/%d). Поранені супутники одужують у будь-якому місті." % [w.companions.size(), game.CityService.party_size(w)], 22, UI.GOLD, false))
	v.add_child(UI.label("Супутники отримують досвід за кожного ворога, вбитого в поході, і ростуть до рівня козака.", 16, UI.MUTED, false))
	if w.companions.is_empty():
		v.add_child(UI.label("Поки що ти сам.", 18, UI.MUTED, false))
	for i in w.companions.size():
		var c: Dictionary = w.companions[i]
		var row := HBoxContainer.new()
		var clvl: int = int(c.get("level", 1))
		var cst: Dictionary = game.Party.stats(c["type"], clvl)
		var xp_text := "макс. (рівень козака)" if clvl >= p.level else "досвід %d/%d" % [c.get("xp", 0), game.Party.xp_for_level(clvl)]
		var HS = game.HeroService
		var hid: String = c.get("hero", "")
		if hid != "":
			cst = game.Party.stats(c["type"], clvl, HS.power(w, hid))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := UI.label("%s%s — рівень %d • здоров'я %d, шкода %d • %s%s" % ["★ " if hid != "" else "", HS.member_name(c), clvl, cst["hp"], cst["dmg"], xp_text, "  (поранений)" if c["downed"] else ""], 20, UI.GOLD if hid != "" else UI.TEXT, false)
		col.add_child(l)
		if hid != "":
			col.add_child(UI.label(_hero_status(w, HS, hid), 16, UI.MUTED, false))
		row.add_child(col)
		row.add_child(UI.button("Відпустити", _do(game, "dismiss", i), Vector2(190, 54), 18))
		v.add_child(row)
	var waiting: Array = game.HeroService.waiting(w)
	if not waiting.is_empty():
		v.add_child(UI.label("Побратими чекають у корчмі", 24, UI.GOLD, false))
		for hid in waiting:
			var h: Dictionary = game.HeroService.info(hid)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UI.label("★ " + h["name"], 22, UI.GOLD, false))
			var bio := UI.label(h["bio"], 16, UI.MUTED, false)
			bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(bio)
			row.add_child(col)
			row.add_child(UI.button("Покликати", _do(game, "hero_join", hid), Vector2(190, 70), 18, w.companions.size() < game.CityService.party_size(w)))
			v.add_child(row)
	v.add_child(UI.label("Найняти", 24, UI.GOLD, false))
	var lvl: int = w.loyalty_level(city)
	for type in Data.COMPANIONS:
		var info: Dictionary = Data.COMPANIONS[type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var start_lvl: int = game.Party.new_member(type, p.level)["level"]
		var st: Dictionary = game.Party.stats(type, start_lvl)
		col.add_child(UI.label("%s — рівень %d • здоров'я %d, шкода %d" % [info["name"], start_lvl, st["hp"], st["dmg"]], 22, UI.TEXT, false))
		col.add_child(UI.label(info["desc"].replace("\n", " "), 16, UI.MUTED, false))
		var need: int = info["loyalty"]
		if lvl < need:
			col.add_child(UI.label("Потрібна лояльність міста: %s" % Data.LOYALTY_NAMES[need], 16, UI.BAD, false))
		row.add_child(col)
		var price: int = game.hire_price(city, type)
		var ok: bool = lvl >= need and p.gold >= price and w.companions.size() < game.CityService.party_size(w) and not w.has_companion(type)
		row.add_child(UI.button("Найняти\n%d грн" % price, _do(game, "hire", type), Vector2(190, 70), 18, ok))
		v.add_child(row)
	return v
