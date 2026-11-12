extends RefCounted
## Екран міста: дошка завдань, крамниця, коваль (заточка), корчма (супутники).
## Дії йдуть через game.city_do(дія, аргумент).

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")


static func _do(game, action: String, arg = null) -> Callable:
	return game.city_do.bind(action, arg)


static func build(game, city: String) -> Control:
	var w = game.world
	var C: Dictionary = Data.city(city)
	var lvl: int = w.loyalty_level(city)
	var pts: int = w.loyalty_points(city)
	var next := ""
	if lvl < Data.loyalty_levels().size() - 1:
		next = " (%d/%d)" % [pts, Data.loyalty_from(lvl + 1)]
	var title := "%s  •  Лояльність: %s%s  •  Гривні: %s" % [C["name"], Data.loyalty_name(lvl), next, UI.num(game.player.gold)]
	# Перша вкладка: ратуша. Тут чекають ті, хто має до героя справу; число в назві каже, скільки їх.
	var waiting: Array = game.hall_rows(city)
	var pages := [
		[Data.hall_name(city) + ((" (%d)" % waiting.size()) if not waiting.is_empty() else ""), func(): return _hall(game, city, waiting)],
		["Завдання", func(): return _quests(game, city)],
		["Крамниця", func(): return _shop(game, city)],
		["Коваль", func(): return _smith(game)],
		["Корчма", func(): return _tavern(game, city)],
		["Шинок", func(): return _shynok(game, city)],
	]
	if game.BountyService.unlocked(game.player):
		pages.insert(2, ["Розшук", func(): return _bounty_tab(game, city)])
	if game.TradeService.has_market(city) and not game.player.is_peasant():
		pages.append(["Торг", func(): return _trade(game, city)])
	if city == "sich":
		pages.append(["Майдан", func(): return _maidan(game)])
	if city == game.Acts.MUSTER_CITY and not game.player.is_peasant():
		pages.append(["Огляд", func(): return _muster(game)])
	if city == "sich" and game.PathService.choosing(game.world):
		pages.insert(0, ["★ Дорога", func(): return _path_tab(game)])
	if not _city_specs(game, city).is_empty():
		pages.append(["Наставники" if _city_specs(game, city).size() > 1 else "Наставник", func(): return _mentors(game, city)])
	if game.city_tab_want != "":
		game.city_tab_key = game.city_tab_want
		game.city_tab_want = ""
	# Вкладку шукаємо за назвою: набір вкладок у містах різний і міняється з поступом, тож той самий
	# номер у Києві — крамниця, а на Січі вже коваль. Нема такої вкладки тут — відкривається перша.
	if game.city_tab_key != "":
		var key: String = game.city_tab_key
		var found := -1
		for i in pages.size():
			if str(pages[i][0]).begins_with(key):
				found = i
		game.city_tab = maxi(found, 0)
		game.city_tab_key = key if found >= 0 else ""
	return UI.screen(title, "На мапу", game.leave_city, pages, game.city_tab, func(i: int):
		game.city_tab = i
		game.city_tab_key = str(pages[i][0]).get_slice(" (", 0)
		game.city_tab_changed(str(pages[i][0])),
		[["Персонаж" + ((" +%d" % game.player.unspent_points()) if game.player.unspent_points() > 0 else ""), game.open_character]])


# ---------------- Ратуша ----------------

const HALL_TALK := "Поговорити"

## Хто має справу до героя в цьому місті. Розмова починається лише з кнопки.
static func _hall(game, city: String, rows: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label(Data.hall_name(city), 24, UI.GOLD, false))
	var intro := UI.label("Тут чекають ті, хто має до тебе справу: люди з історії, побратими, наставники й оповідачі переказів. Розмова почнеться, коли сам підійдеш.", 17, UI.MUTED, false)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	if rows.is_empty():
		v.add_child(UI.label("Зараз на тебе ніхто не чекає.", 20, UI.TEXT, false))
		var story_line: String = game.StoryService.objective_line(game.world)
		if story_line != "":
			var next := UI.label("Історія веде далі: %s" % story_line, 17, UI.MUTED, false)
			next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(next)
		return v
	for r in rows:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.style(Color(0.16, 0.13, 0.1), UI.GOOD if r["ready"] else UI.GOLD, 10, 10))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		var who: String = str(r["name"]) + ((", " + str(r["role"])) if str(r["role"]) != "" else "")
		info.add_child(UI.label(who, 21, UI.GOLD, false))
		var what := UI.label(str(r["what"]), 17, UI.TEXT, false)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(what)
		info.add_child(UI.label("Чекає з нагородою" if r["ready"] else "Має до тебе справу", 15, UI.GOOD if r["ready"] else UI.MUTED, false))
		row.add_child(info)
		row.add_child(UI.button(HALL_TALK, game.hall_talk.bind(str(r["kind"]), str(r["line"])), Vector2(190, 58), 20))
		v.add_child(panel)
	return v


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

const SHOP_CELL := 70  # клітинка крамниці: така сама, як у торбі на екрані героя
const SHOP_COLS := 3  # товари стоять у три стовпці
const BAG_COLS := 6  # торба в шість, як на екрані героя

## Крамниця: товари й торба сіткою значків, як інвентар героя. Під значком ціна, дотик показує картку
## речі праворуч, там же кнопки «Купити» й «Продати». Цю саму сторінку показує Хованець (UiDivine.trader).
static func _shop(game, city: String) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = game.city_sel_uid
	var stock: Array = game.shop_stock(city)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	var disc: float = game.world.discount(city)
	left.add_child(UI.label("Товари" + (("  (знижка %d%%)" % roundi(disc * 100)) if disc > 0 else ""), 20, UI.GOLD, false))
	var sg := UI.grid(SHOP_COLS)
	for it in stock:
		sg.add_child(UI.item_cell(it, _do(game, "select", it["uid"]), it["uid"] == sel, SHOP_CELL, float(p.gain_from(it)) > p.Power.MIN_GAIN, UI.num(game.buy_price(city, it))))
	for i in maxi(0, SHOP_COLS * 2 - stock.size()):
		sg.add_child(UI.empty_cell(SHOP_CELL))
	left.add_child(sg)
	if stock.is_empty():
		left.add_child(UI.label("Усе розкупили.\nЗазирни після походу.", 15, UI.MUTED, false))
	h.add_child(left)

	var pw: int = SHOP_COLS * SHOP_CELL + (SHOP_COLS - 1) * 6
	var pprice: int = game.CityService.potion_price(game.world, p, city)
	left.add_child(UI.label("Зілля здоров'я: %d/%d" % [p.potions, p.potion_max()], 17, UI.TEXT, false))
	left.add_child(UI.label("Лікує %d%% здоров'я" % roundi(Data.POTION_HEAL * 100), 13, UI.MUTED, false))
	left.add_child(UI.button("Купити • %s грн" % UI.num(pprice), _do(game, "buy_potion"), Vector2(pw, 52), 16, p.gold >= pprice and p.potions < p.potion_max()))
	var mprice: int = game.CityService.mana_potion_price(game.world, p, city)
	left.add_child(UI.label("Зілля наснаги: %d/%d" % [p.mana_potions, p.mana_potion_max()], 17, UI.TEXT, false))
	left.add_child(UI.label("Повертає %d%% наснаги" % roundi(Data.MANA_POTION_RESTORE * 100), 13, UI.MUTED, false))
	left.add_child(UI.button("Купити • %s грн" % UI.num(mprice), _do(game, "buy_mana_potion"), Vector2(pw, 52), 16, p.gold >= mprice and p.mana_potions < p.mana_potion_max()))

	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var bl := UI.label("Твоя торба %d/%d" % [p.inventory.size(), p.bag_size()], 20, UI.GOLD, false)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(bl)
	head.add_child(UI.button("✓ Вибрати кілька" if not game.sell_multi else "Готово", _do(game, "sell_multi"), Vector2(190, 40), 15))
	bag.add_child(head)
	# Продаж гуртом стоїть над сіткою, щоб кнопки не тікали вниз разом із довгою торбою
	if game.sell_multi:
		var total := 0
		for uid in game.sell_marked:
			var mi: Dictionary = p.find_item(uid)
			if not mi.is_empty():
				total += Data.sell_price(mi)
		bag.add_child(UI.button("Продати вибране (%d) за %s грн" % [game.sell_marked.size(), UI.num(total)], _do(game, "sell_marked"), Vector2(300, 50), 16, not game.sell_marked.is_empty()))
		bag.add_child(UI.label("Торкайся речей у торбі: позначені продадуться разом.", 13, UI.MUTED, false))
	else:
		var CS = game.CityService
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for r in 3:
			var cands: Array = CS.bulk_candidates(p, r)
			var sum := 0
			for c in cands:
				sum += Data.sell_price(c)
			var name: String = ["звичайні", "до добротних", "до рідкісних"][r]
			row.add_child(UI.button("Продати %s\n%d шт • +%s грн" % [name, cands.size(), UI.num(sum)], _do(game, "sell_upto", r), Vector2(146, 52), 12, not cands.is_empty()))
		bag.add_child(row)
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 8)
		arow.add_child(UI.button(("☑ " if game.combat.autosell else "☐ ") + "Автопродаж звичайних при повній торбі", _do(game, "autosell"), Vector2(300, 38), 13))
		arow.add_child(UI.label("Кращі за вдягнені\nне продаються.", 12, UI.MUTED, false))
		bag.add_child(arow)
	var bg := UI.grid(BAG_COLS)
	for it in p.inventory:
		var art: bool = it.has("artifact")  # артефакти не продають: вони діють просто з торби
		var marked: bool = game.sell_marked.has(it["uid"])
		var act: String = "mark" if game.sell_multi and not art else "select"
		bg.add_child(UI.item_cell(it, _do(game, act, it["uid"]), it["uid"] == sel and not game.sell_multi, SHOP_CELL, float(p.gain_from(it)) > p.Power.MIN_GAIN,
			"" if art else "+" + UI.num(Data.sell_price(it)), marked))
	for i in maxi(0, p.bag_size() - p.inventory.size()):
		bg.add_child(UI.empty_cell(SHOP_CELL))
	bag.add_child(bg)
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
		det.add_child(UI.button("Купити за %s грн" % UI.num(price), _do(game, "buy", sel), Vector2(300, 60), 22, p.gold >= price and not p.bag_full()))
	else:
		var it: Dictionary = p.find_item(sel) if sel > 0 else {}
		if not it.is_empty() and not p.is_equipped(sel):
			det.add_child(UI.item_card(it, p.equipment.get(it["slot"], {})))
			if it.has("artifact"):
				det.add_child(UI.label("Артефакти не продаються.", 16, UI.MUTED, false))
			else:
				det.add_child(UI.button("Продати за %s грн" % UI.num(Data.sell_price(it)), _do(game, "sell", sel), Vector2(300, 60), 22))
		else:
			det.add_child(UI.label("Торкнись товару або\nсвоєї речі,\nщоб побачити бонуси.", 20, UI.MUTED, false))
			det.add_child(UI.label("Число під значком: ціна.\nЗелена стрілка: річ краща\nза вдягнену.", 15, UI.MUTED, false))
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
	var eg := UI.grid(5)
	for slot in Data.slots():
		if p.equipment.has(slot):
			var it: Dictionary = p.equipment[slot]
			eg.add_child(UI.item_cell(it, _do(game, "select", it["uid"]), it["uid"] == sel, 66))
	list.add_child(eg)
	list.add_child(UI.label("Торба", 22, UI.GOLD, false))
	var bg := UI.grid(5)
	for it in p.inventory:
		if it.has("artifact"):
			continue  # артефакти не продають і не точать: вони лежать у торбі
		bg.add_child(UI.item_cell(it, _do(game, "select", it["uid"]), it["uid"] == sel, 66))
	list.add_child(bg)
	h.add_child(list)

	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(360, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	det.add_child(UI.label("Заточка робить усі бонуси речі сильнішими\n(+%d%% за рівень, максимум +%d).\nЗ +%d невдача знижує заточку на 1." % [roundi(Data.UPGRADE_BONUS * 100), Data.MAX_UPGRADE, Data.SHARPEN_RISK_FROM], 16, UI.MUTED, false))
	var safe_n: int = game.AdRewards.safe_tokens(game.world)
	det.add_child(UI.label("Безпечних заточок: %d" % safe_n, 16, UI.TEXT, false))
	det.add_child(UI.button(game.AdRewards.safe_button_text(game.world), _do(game, "ad_safe"), Vector2(360, 52), 15, game.AdRewards.safe_left_today(game.world) > 0))
	var it: Dictionary = p.find_item(sel) if sel > 0 else {}
	if it.is_empty():
		det.add_child(UI.label("Обери річ для заточки.", 20, UI.MUTED, false))
		return h
	det.add_child(UI.item_card(it))
	if it["up"] >= Data.MAX_UPGRADE:
		# неактивна кнопка того самого розміру на місці «Заточити» (і порожнє місце замість «без ризику»):
		# після останньої заточки під палець не стає гніздо чи душа
		det.add_child(UI.button("Заточено до краю: +%d" % int(it["up"]), func(): pass, Vector2(340, 80), 20, false))
		if safe_n <= 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(340, 72)
			det.add_child(gap)
	else:
		var cost := Data.sharpen_cost(it)
		var chance := minf(1.0, Data.sharpen_chance(it) + game.HolidayService.bonus("sharpen"))
		var risk := ""
		if it["up"] >= Data.SHARPEN_RISK_FROM:
			risk = "  без ризику" if safe_n > 0 else "  ризик -1"
		det.add_child(UI.button("Заточити до +%d\n%d грн • шанс %d%%%s" % [it["up"] + 1, cost, roundi(chance * 100), risk], _do(game, "sharpen", sel), Vector2(340, 80), 20, p.gold >= cost))
		if it["up"] >= Data.SHARPEN_RISK_FROM and safe_n <= 0:
			var safe_cost := Data.sharpen_safe_cost(it)
			det.add_child(UI.button("Заточити без ризику\n%s грн • рівень не впаде" % UI.num(safe_cost), _do(game, "sharpen_safe", sel), Vector2(340, 72), 17, p.gold >= safe_cost))
	det.add_child(load("res://scripts/ui/ui_souls.gd").block(p, it, func(a: String, b): return _do(game, a, b), true))
	if game.smith_msg != "":
		det.add_child(UI.label(game.smith_msg, 22, game.smith_msg_color, false))
	return h


# ---------------- Дорога: вибір Козак / Волхв / Стрілець ----------------

static func _path_tab(game) -> Control:
	var PS = game.PathService
	var w = game.world
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var both: bool = PS.talked_all(w)
	var intro := "Поговори з усіма трьома — осавулом Мироном, посланницею Зореславою й сотником Лесем — і обери свою дорогу. Не поспішай: вибір назавжди (змінити зможе лише Алатир-камінь)." if not both else "Ти вислухав усіх трьох. Обирай, коли будеш готовий, або повертайся пізніше."
	var il := UI.label(intro, 18, UI.GOLD if not both else UI.GOOD, false)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(il)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for cls in game.Paths.order():
		var card := class_card(game, cls, true)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var talked: bool = PS.talked(w, cls)
		var rep: String = game.Paths.rep(cls)
		var rep_name: String = game.StoryService.Story.npc_name(rep)
		card.add_child(UI.button(("Поговорити з: " if not talked else "Ще раз: ") + rep_name, _do(game, "path_talk", cls), Vector2(0, 54), 16))
		var key: String = "path_choose:" + cls
		var t: String = ("Обрати: %s" % game.Paths.card(cls)["title"]) if game.confirm_action != key else "Точно? Натисни ще раз"
		var b := UI.button(t, _do(game, "path_choose", cls), Vector2(0, 60), 20, both)
		if both:
			b.add_theme_stylebox_override("normal", UI.style(Color(0.2, 0.32, 0.15), Color(0.5, 0.9, 0.4), 12, 8))
		card.add_child(b)
		if not talked:
			card.add_child(UI.label("Спершу вислухай %s." % rep_name, 14, UI.MUTED, false))
		row.add_child(card)
	return v


## Картка дороги чи спеціалізації: стиль, сильні/слабкі сторони, зброя, вміння, що далі.
static func class_card(game, cls: String, big: bool = false) -> VBoxContainer:
	var c: Dictionary = game.Paths.card(cls)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.1, 0.09, 0.07, 0.9), Color(0.6, 0.5, 0.25), 12, 10))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	inner.add_child(UI.label(c["title"], 26 if big else 22, UI.GOLD, false))
	inner.add_child(UI.label(c["where"], 14, UI.MUTED, false))
	var st := UI.label(c["style"], 16, UI.TEXT, false)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(st)
	for s_ in c["strong"]:
		inner.add_child(UI.label("+ " + s_, 15, UI.GOOD, false))
	for wk in c["weak"]:
		inner.add_child(UI.label("− " + wk, 15, UI.BAD, false))
	inner.add_child(UI.label("Вміння: " + ", ".join(c["skills"]), 14, UI.TEXT, false))
	if not c["next"].is_empty():
		inner.add_child(UI.label("Далі: " + ", ".join(c["next"]), 14, UI.MUTED, false))
	var fl := UI.label(c["for"], 14, UI.GOLD, false)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(fl)
	v.add_child(panel)
	return v


# ---------------- Наставники (спеціалізації Козака) ----------------

## Спеціалізації, наставники яких живуть у цьому місті (для героя відповідної гілки).
static func _city_specs(game, city: String) -> Array:
	var Classes = game.player.Classes
	var out := []
	for base in Classes.info("peasant")["next"]:
		if not base in Classes.lineage(game.player.job):
			continue
		for spec in Classes.info(base)["next"]:
			if Classes.info(spec)["where"] == city:
				out.append(spec)
	return out


static func _mentors(game, city: String) -> Control:
	var p = game.player
	var Classes = p.Classes
	var SS = game.SpecService
	var w = game.world
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var base: String = "cossack"
	for b0 in Classes.info("peasant")["next"]:
		if b0 in Classes.lineage(p.job):
			base = b0
	var need: int = int(Classes.info(base)["change_at"])
	if p.job == base:
		var t := "Спеціалізацію можна обрати з %d-го рівня майстерності (зараз %d)." % [need, p.job_level]
		v.add_child(UI.label(t, 19, UI.GOOD if p.job_level >= need else UI.MUTED, false))
		if base != "cossack":
			var places := []
			for sp in Classes.info(base)["next"]:
				places.append("%s — %s" % [Classes.info(sp)["name"], Data.place_name(Classes.info(sp)["where"])])
			v.add_child(UI.label("Наставники: " + ", ".join(places), 16, UI.MUTED, false))
	else:
		v.add_child(UI.label("Ти вже %s. Іншу дорогу відкриє лише Алатир-камінь." % p.class_name_ua().to_lower(), 19, UI.MUTED, false))
	var trial: Dictionary = w.spec_trial
	for spec in _city_specs(game, city):
		var info: Dictionary = Classes.info(spec)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mentor: Dictionary = game.StoryService.Story.npc(info["mentor"])
		col.add_child(UI.label("%s  •  наставник: %s" % [info["name"], mentor["name"]], 22, UI.GOLD if p.job == spec else UI.TEXT, false))
		if game.Paths.has_card(spec):
			col.add_child(class_card(game, spec))
		else:
			var d := UI.label(info["desc"], 16, UI.MUTED, false)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(d)
		row.add_child(col)
		var label := "Випробування"
		var ok: bool = spec in SS.available(p)
		if p.job == spec:
			label = "Твоя дорога"
			ok = false
		elif not trial.is_empty() and trial["spec"] == spec:
			label = "Триває" if trial["stage"] == "active" else "Посвята"
			ok = false
		v.add_child(row)
		row.add_child(UI.button(label, _do(game, "spec_start", spec), Vector2(200, 64), 18, ok))
	if not trial.is_empty():
		v.add_child(UI.label(SS.objective_line(w), 19, UI.GOLD, false))
	return v


# ---------------- Шинок: кості й чутки ----------------

static func _shynok(game, city: String) -> Control:
	var TS = game.TavernService
	var Acts = game.Acts
	var DiceRow = load("res://scripts/ui/dice_row.gd")
	var w = game.world
	var p = game.player
	var s: Dictionary = TS.state(w)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_wrap("Гамір, дим і стукіт кісток об стіл. Тут грають у «дванадцять» і розносять чутки з усього краю.", 17, UI.MUTED))
	v.add_child(UI.label("Кості: партій сьогодні %d/%d  •  виграно %d, програно %d  •  найдовша серія %d" % [int(s["games"]), TS.games_max(), int(s["wins"]), int(s["losses"]), int(s["best_streak"])], 19, UI.GOLD, false))
	var g: Dictionary = TS.game(w)
	if g.is_empty():
		v.add_child(_wrap("Кидаєш по одній кості й додаєш очки. Понад %d — перебір і програш. Зупинишся — кидає суперник: у кого більше, того й ставка. Рівно %d — виграш у півтора раза." % [Acts.DICE_LIMIT, Acts.DICE_LIMIT], 16, UI.TEXT))
		for id in Acts.dice_rival_ids():
			var R: Dictionary = Acts.dice_rival(id)
			var st: int = TS.stake(id, p.level)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(UI.label("%s  •  ставка %d грн" % [R["name"], st], 21, UI.TEXT, false))
			info.add_child(_wrap(R["desc"], 15, UI.MUTED))
			row.add_child(info)
			row.add_child(UI.button("Грати", _do(game, "dice_start", id), Vector2(200, 64), 20, TS.can_start(w, p, id)))
			v.add_child(row)
		if TS.games_left(w) <= 0:
			v.add_child(_wrap("На сьогодні досить: шинкар ховає кості до завтра.", 17, UI.BAD))
	else:
		var R2: Dictionary = Acts.dice_rival(g["rival"])
		var mine: int = TS.total(g["mine"])
		v.add_child(UI.label("Проти: %s  •  на кону %d грн" % [R2["name"], int(g["stake"]) * 2], 21, UI.TEXT, false))
		var r1 := HBoxContainer.new()
		r1.add_theme_constant_override("separation", 16)
		var l1 := UI.label("Ти: %d" % mine, 26, UI.BAD if mine > Acts.DICE_LIMIT else UI.GOLD, false)
		l1.custom_minimum_size = Vector2(230, 0)
		r1.add_child(l1)
		var late := []  # написи, що мають з'явитися, коли кості вже лежать
		var anim: Dictionary = game.dice_anim
		var wait := 0.0  # скільки чекати, доки всі нові кості ляжуть
		var mine_from: int = int(anim.get("mine", 9999))
		var theirs_from: int = int(anim.get("theirs", 9999))
		r1.add_child(DiceRow.new().setup(g["mine"], Color(0.95, 0.91, 0.8), mine_from))
		wait += DiceRow.roll_time(g["mine"].size() - mine_from)
		if wait > 0.0:
			late.append(l1)  # сума героя оновлюється, коли його кість лягла
		v.add_child(r1)
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 16)
		var theirs: int = TS.total(g["theirs"])
		var l2 := UI.label(("Суперник: %d" % theirs) if not g["theirs"].is_empty() else "Суперник чекає", 26, UI.BAD if theirs > Acts.DICE_LIMIT else UI.TEXT, false)
		l2.custom_minimum_size = Vector2(230, 0)
		r2.add_child(l2)
		var rival_row = DiceRow.new().setup(g["theirs"], Color(0.8, 0.62, 0.5), theirs_from)
		r2.add_child(rival_row)
		v.add_child(r2)
		var rival_time: float = DiceRow.roll_time(g["theirs"].size() - theirs_from)
		if rival_time > 0.0:
			# суперник кидає після героя: його ряд починає котитись, коли лягли кості героя
			rival_row._t = -wait
			late.append(l2)
		wait += rival_time
		if g["over"]:
			var col: Color = UI.GOOD if g["result"] == "win" else (UI.TEXT if g["result"] == "draw" else UI.BAD)
			var res := UI.label(TS.result_text(g), 26, col, false)
			v.add_child(res)
			late.append(res)
			for m in g.get("msgs", []):
				var ml := UI.label(m, 18, UI.GOLD, false)
				v.add_child(ml)
				late.append(ml)
			var back := UI.button("До столів", _do(game, "dice_clear"), Vector2(260, 64), 20)
			back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(back)
			late.append(back)
		else:
			var btns := HBoxContainer.new()
			btns.add_theme_constant_override("separation", 14)
			btns.add_child(UI.button("Кинути ще", _do(game, "dice_roll"), Vector2(260, 76), 24))
			btns.add_child(UI.button("Досить", _do(game, "dice_stand"), Vector2(260, 76), 24))
			v.add_child(btns)
			v.add_child(_wrap("До перебору лишилось %d. %s" % [Acts.DICE_LIMIT - mine, R2["desc"]], 15, UI.MUTED))
		_reveal_late(late, wait)
	# Чутки
	v.add_child(UI.label("Чутки", 24, UI.GOLD, false))
	v.add_child(_wrap("Пригости шинок — і язики розв'яжуться: хтось чув про скарб, хтось про нічну нечисть, вигідний торг чи багаті угіддя. Одна чутка за похід.", 16, UI.MUTED))
	var cost: int = TS.rumor_cost(p.level)
	var why := ""
	if s["rumor_done"]:
		why = "Усе вже розказано. Нові чутки будуть після походу."
	elif TS.rumor_kinds(w, p, city).is_empty():
		why = "Сьогодні в шинку самі байки."
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 14)
	rrow.add_child(UI.button("Пригостити шинок\n%d грн" % cost, _do(game, "rumor"), Vector2(300, 70), 18, TS.can_rumor(w, p, city)))
	if why != "":
		var wl := _wrap(why, 16, UI.MUTED)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(wl)
	v.add_child(rrow)
	if str(s["rumor_text"]) != "":
		v.add_child(_wrap("Остання чутка: " + str(s["rumor_text"]), 17, UI.TEXT))
	var tip: Dictionary = TS.tip(w)
	if not tip.is_empty():
		v.add_child(_wrap("Торгова порада ще свіжа: %s у місті %s, походів лишилось %d." % [Acts.trade_good(tip["good"])["name"], Data.place_name(tip["city"]), int(tip["left"])], 16, UI.GOOD))
	return v


## Показати написи з затримкою: підсумок не має випереджати кості, що ще котяться.
static func _reveal_late(nodes: Array, delay: float) -> void:
	if delay <= 0.0:
		return
	for n in nodes:
		n.modulate.a = 0.0
		n.ready.connect(func():
			var tw: Tween = n.create_tween()
			tw.tween_interval(delay)
			tw.tween_property(n, "modulate:a", 1.0, 0.18))


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
	if not w.companions.is_empty():
		v.add_child(_wrap("Супутника можна відправити у власний похід: розвідка на годину, далекий похід на чотири чи виправа на вісім. Він повернеться зі здобиччю й досвідом, та поки його нема, в бою ти без нього.", 15, UI.MUTED))
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
		# Власний похід супутника
		var ES = game.ExpeditionService
		var erow := HBoxContainer.new()
		erow.add_theme_constant_override("separation", 10)
		if ES.away(c):
			var E: Dictionary = game.Acts.expedition(c["away"]["kind"])
			var el := UI.label("У поході (%s): повернеться за %s. У бій зараз не піде." % [str(E["name"]).to_lower(), ES.time_text(ES.time_left(c))], 16, UI.GOLD, false)
			el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			erow.add_child(el)
			erow.add_child(UI.button("Відкликати", _do(game, "exp_recall", i), Vector2(190, 48), 16))
		else:
			var hl := UI.label("Відправити самого:", 16, UI.MUTED, false)
			erow.add_child(hl)
			for kind in game.Acts.expedition_ids():
				var E2: Dictionary = game.Acts.expedition(kind)
				erow.add_child(UI.button("%s, %d год" % [E2["name"], int(E2["hours"])], _do(game, "exp_send", [i, kind]), Vector2(230, 48), 16, ES.can_send(w, i, kind)))
		v.add_child(erow)
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
	for type in GameDB.companion_ids():
		var info: Dictionary = GameDB.companion(type)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var start_lvl: int = game.Party.new_member(type, p.level)["level"]
		var st: Dictionary = game.Party.stats(type, start_lvl)
		col.add_child(UI.label("%s — рівень %d • здоров'я %d, шкода %d" % [info["name"], start_lvl, st["hp"], st["dmg"]], 22, UI.TEXT, false))
		col.add_child(UI.label(info["desc"].replace("\n", " "), 16, UI.MUTED, false))
		var need: int = info["hire"]["loyalty"]
		if lvl < need:
			col.add_child(UI.label("Потрібна лояльність міста: %s" % Data.loyalty_name(need), 16, UI.BAD, false))
		row.add_child(col)
		var price: int = game.hire_price(city, type)
		var ok: bool = lvl >= need and p.gold >= price and w.companions.size() < game.CityService.party_size(w) and not w.has_companion(type)
		row.add_child(UI.button("Найняти\n%d грн" % price, _do(game, "hire", type), Vector2(190, 70), 18, ok))
		v.add_child(row)
	return v


# ---------------- Майдан (Січ): герць ----------------

static func _wrap(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _maidan(game) -> Control:
	var DS = game.DuelService
	var GS = game.GloryService
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Герць на майдані", 26, UI.GOLD, false))
	v.add_child(_wrap("Щотижня на Січі сходяться найкращі шаблі. Три кола сам на сам, без побратимів. Програв — мінус спроба; смерті на майдані нема.", 17, UI.MUTED))
	v.add_child(UI.label("Слава: %d — %s%s" % [GS.glory(w), GS.rank_name(w), ("   (до наступного рангу: %d)" % GS.to_next(w)) if GS.to_next(w) > 0 else ""], 18, UI.TEXT, false))
	if not DS.unlocked(p):
		v.add_child(_wrap("Кошовий пускає на майдан із %d-го рівня й лише тих, хто вже обрав свою дорогу." % DS.MIN_LEVEL, 19, UI.BAD))
		return v
	var s: Dictionary = DS.state(w)
	var done: int = int(s["round"])
	v.add_child(UI.label("Виграно кіл: %d/%d   •   Спроб: %d   •   Новий турнір за %d дн.   •   Титулів чемпіона: %d" % [done, DS.ROUNDS, int(s["tries"]), DS.days_to_reset(), int(s["titles"])], 18, UI.TEXT, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ids: Array = DS.lineup()
	for i in ids.size():
		var info: Dictionary = game.Acts.rival(ids[i])
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := UI.GOOD if i < done else (UI.GOLD if i == done else UI.MUTED)
		card.add_theme_stylebox_override("panel", UI.style(Color(0.14, 0.11, 0.09), border, 10, 10))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var status := "✓ Переможений" if i < done else ("▶ Наступний" if i == done else "Попереду")
		col.add_child(UI.label("Коло %d%s  •  %s" % [i + 1, " (фінал)" if i == DS.ROUNDS - 1 else "", status], 15, border, false))
		col.add_child(UI.label(info["name"], 22, UI.GOLD if i <= done else UI.TEXT, false))
		col.add_child(_wrap(info["bio"], 15, UI.MUTED))
		col.add_child(UI.label("+%s грн, +%d слави" % [UI.num(DS.gold_for(i, p.level)), game.Acts.duel_round(i)["glory"]], 15, UI.TEXT, false))
		card.add_child(col)
		row.add_child(card)
	v.add_child(row)
	if DS.is_champion(w):
		v.add_child(UI.label("Ти — чемпіон майдану цього тижня! Повертайся на новий турнір.", 22, UI.GOOD, false))
	elif int(s["tries"]) <= 0:
		v.add_child(UI.label("Спроб цього тижня більше нема. Новий турнір — за %d дн." % DS.days_to_reset(), 20, UI.BAD, false))
	else:
		var rival: Dictionary = DS.next_rival(w)
		v.add_child(UI.button("Вийти на герць: %s" % rival["name"], _do(game, "duel_start"), Vector2(520, 70), 24, DS.can_fight(w, p)))
		if not s["belt"]:
			v.add_child(UI.label("Перший чемпіонський титул — легендарний «%s»." % DS.BELT_NAME, 16, UI.GOLD, false))
	# Вільний герць: поза турніром, скільки завгодно
	v.add_child(UI.label("Вільний герць", 24, UI.GOLD, false))
	v.add_child(_wrap("Поза турніром охочі виходять один за одним, до твоєї першої поразки. Кожен наступний міцніший за попереднього. Перші %d перемоги дня — з гаманцем, далі б'ються за серію й рекорд у Літописі. Спроб не лічать." % game.Acts.FREE_DUEL_PAID, 17, UI.MUTED))
	var streak: int = int(s["streak"])
	v.add_child(UI.label("Серія: %d   •   Найдовша: %d   •   Гаманців сьогодні лишилось: %d" % [streak, int(s["best_streak"]), DS.free_paid_left(w)], 18, UI.TEXT, false))
	var fr: Dictionary = DS.free_rival(w)
	var purse := ("+%s грн" % UI.num(DS.free_gold(p.level, streak))) if DS.free_paid_left(w) > 0 else "за серію"
	v.add_child(UI.button("Вільний герць: %s (%s)" % [fr["name"], purse], _do(game, "duel_free"), Vector2(520, 64), 22))
	return v


# ---------------- Гетьманський огляд (Чигирин) ----------------

static func _muster(game) -> Control:
	var MS = game.MusterService
	var Acts = game.Acts
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Гетьманський огляд", 26, UI.GOLD, false))
	v.add_child(_wrap("Щотижня гетьман скликає сотні на огляд: гурт на гурт, до першої крові. Ти виходиш зі своїми побратимами проти цілої сотні. Три сутички, три спроби. Смерті й ран тут нема.", 18, UI.TEXT))
	if not MS.unlocked(p):
		v.add_child(_wrap("На огляд кличуть із %d-го рівня." % Acts.MUSTER_MIN_LEVEL, 19, UI.BAD))
		return v
	var s: Dictionary = MS.state(w)
	var done: int = int(s["round"])
	var allies: int = MS.allies(w)
	v.add_child(UI.label("Виграно сутичок: %d/%d   •   Спроб: %d   •   Новий огляд за %d дн.   •   Виграних оглядів: %d" % [done, MS.ROUNDS, int(s["tries"]), MS.days_to_reset(), int(s["titles"])], 17, UI.TEXT, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ids: Array = MS.lineup()
	for i in ids.size():
		var info: Dictionary = Acts.muster_team(ids[i])
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := UI.GOOD if i < done else (UI.GOLD if i == done else UI.MUTED)
		card.add_theme_stylebox_override("panel", UI.style(Color(0.14, 0.11, 0.09), border, 10, 10))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var status := "✓ Покладено" if i < done else ("▶ Наступна" if i == done else "Попереду")
		col.add_child(UI.label("Сутичка %d%s  •  %s" % [i + 1, " (остання)" if i == MS.ROUNDS - 1 else "", status], 15, border, false))
		col.add_child(UI.label(info["name"], 22, UI.GOLD if i <= done else UI.TEXT, false))
		col.add_child(_wrap(info["bio"], 15, UI.MUTED))
		col.add_child(UI.label("Вийде бійців: %d" % MS.team_size(i, allies), 15, UI.TEXT, false))
		col.add_child(UI.label("+%s грн, +%d слави, +%d лояльності" % [UI.num(MS.gold_for(i, p.level)), Acts.muster_round(i)["glory"], Acts.muster_round(i)["loyalty"]], 15, UI.TEXT, false))
		card.add_child(col)
		row.add_child(card)
	v.add_child(row)
	if allies >= 2:
		v.add_child(UI.label("З тобою стане побратимів: %d." % allies, 17, UI.GOOD, false))
	else:
		v.add_child(_wrap("З тобою стане побратимів: %d. Сотня з поваги виставить менше людей, та з повним загоном битись легше: найми супутників у корчмі." % allies, 17, UI.MUTED))
	if MS.is_winner(w):
		v.add_child(UI.label("Цього тижня огляд за твоєю ватагою! Повертайся на наступний.", 22, UI.GOOD, false))
	elif int(s["tries"]) <= 0:
		v.add_child(UI.label("Спроб цього тижня більше нема. Новий огляд — за %d дн." % MS.days_to_reset(), 20, UI.BAD, false))
	else:
		var team: Dictionary = MS.next_team(w)
		v.add_child(UI.button("Вивести ватагу: %s" % team["name"], _do(game, "muster_start"), Vector2(520, 70), 24, MS.can_fight(w, p)))
		if not s["prize"]:
			v.add_child(UI.label("За перший виграний огляд гетьман дає легендарний оберіг: «%s»." % MS.PRIZE_NAME, 16, UI.GOLD, false))
	return v


# ---------------- Розшук (у вкладці «Завдання») ----------------

static func _bounty_tab(game, city: String) -> Control:
	var BS = game.BountyService
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Розшук   (шукаєш голів: %d/%d)" % [BS.state(w)["active"].size(), game.Acts.BOUNTY_ACTIVE], 24, UI.GOLD, false))
	v.add_child(UI.label("Іменована нечисть у навколишніх місцях. Убий і принеси голову сюди — отримаєш гривні, славу й лояльність.", 16, UI.MUTED, false))
	for b in BS.mine(w, city):
		v.add_child(_bounty_row(game, b, "killed" if b["killed"] else "active"))
	for b in BS.board(w, city, p):
		v.add_child(_bounty_row(game, b, "take"))
	var elsewhere := []
	for b in BS.state(w)["active"]:
		if b["city"] != city:
			elsewhere.append("%s (%s) — %s" % [b["name"], Data.place_name(b["loc"]), ("голову здобуто, неси в місто %s" % Data.place_name(b["city"])) if b["killed"] else "ще ходить"])
	if not elsewhere.is_empty():
		v.add_child(UI.label("Оголошення інших міст:", 18, UI.MUTED, false))
	for t in elsewhere:
		v.add_child(UI.label("• " + t, 16, UI.MUTED, false))
	v.add_child(UI.label("Дошка оновлюється кожні %d походів. Слава: %d — %s." % [game.Acts.BOUNTY_REFRESH, game.GloryService.glory(w), game.GloryService.rank_name(w)], 16, UI.MUTED, false))
	return v


static func _bounty_row(game, b: Dictionary, mode: String) -> Control:
	var BS = game.BountyService
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := "☠ %s — %s" % [b["name"], Data.place_name(b["loc"])]
	if mode == "killed":
		head += "   (голову здобуто)"
	info.add_child(UI.label(head, 21, UI.GOOD if mode == "killed" else UI.TEXT, false))
	info.add_child(UI.label("%s: %s.  Нагорода: %d грн, +%d слави, +30 лояльності" % [GameDB.mob_name(b["kind"]), BS.traits(b), b["gold"], b["glory"]], 16, UI.MUTED, false))
	row.add_child(info)
	match mode:
		"take":
			row.add_child(UI.button("Взяти", _do(game, "bounty_take", b["id"]), Vector2(170, 58), 22, BS.can_take(game.world)))
		"killed":
			row.add_child(UI.button("Здати голову", _do(game, "bounty_turn_in", b["id"]), Vector2(170, 58), 18))
		_:
			row.add_child(UI.button("Відмовитись", _do(game, "bounty_drop", b["id"]), Vector2(170, 58), 18))
	return row


# ---------------- Торг: чумацький крам ----------------

static func _trade(game, city: String) -> Control:
	var TS = game.TradeService
	var Acts = game.Acts
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Чумацький крам", 26, UI.GOLD, false))
	v.add_child(_wrap("Купи дешево тут — продай дорого деінде. Ціни й запаси оновлюються кожні %d походи; що більше продаєш в одному місті, то дешевше беруть." % Acts.TRADE_PERIOD, 16, UI.MUTED))
	var chance := roundi(TS.ambush_chance(w) * 100.0)
	var head := "Віз: %d/%d   •   Гривні: %s" % [TS.cargo_count(w), TS.capacity(w), UI.num(p.gold)]
	if chance > 0:
		head += "   •   Ризик нападу в дорозі: %d%%" % chance
	v.add_child(UI.label(head, 19, UI.TEXT, false))
	if game.EventService.fair_city(w) == city:
		v.add_child(UI.label("Ярмарок: крам тут беруть на чверть дорожче!", 18, UI.GOOD, false))
	for g in Acts.trade_good_ids():
		var info: Dictionary = Acts.trade_good(g)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tag: String = TS.tag(city, g)
		var tag_text := "  — тут дешево" if tag == "cheap" else ("  — тут у ціні" if tag == "dear" else "")
		var name_l := UI.label(info["name"] + tag_text, 20, UI.GOOD if tag == "cheap" else (UI.GOLD if tag == "dear" else UI.TEXT), false)
		col.add_child(name_l)
		var have: int = TS.cargo_n(w, g)
		var sub := "Запас міста: %d" % TS.stock_left(w, city, g)
		if have > 0:
			sub += "   •   На возі: %d (брав по %d)   •   найдорожче: %s" % [have, roundi(TS.avg_cost(w, g)), Data.place_name(TS.best_city(g))]
		col.add_child(UI.label(sub, 14, UI.MUTED, false))
		row.add_child(col)
		var bp: int = TS.price(w, city, g, p.level)
		var sp: int = TS.sell_price(w, city, g, p.level)
		var can: bool = TS.can_buy(w, p, city, g)
		row.add_child(UI.button("Купити\n%d грн" % bp, _do(game, "trade_buy", [g, 1]), Vector2(120, 56), 15, can))
		row.add_child(UI.button("×макс", _do(game, "trade_buy", [g, 99]), Vector2(84, 56), 15, can))
		row.add_child(UI.button("Продати\n%d грн" % sp, _do(game, "trade_sell", [g, 1]), Vector2(120, 56), 15, have > 0))
		row.add_child(UI.button("×усе", _do(game, "trade_sell", [g, 99]), Vector2(84, 56), 15, have > 0))
		v.add_child(row)
	var st: Dictionary = TS.state(w)
	v.add_child(UI.label("Усього продано: %d од.   •   зиск за весь час: %d грн   •   Склад на хуторі збільшує віз." % [int(st["sold"]), int(st["profit"])], 15, UI.MUTED, false))
	return v
