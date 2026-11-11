extends RefCounted
const Gfx := preload("res://scripts/world/gfx.gd")
## Екран козака: характеристики, спорядження, дерево вмінь, дерево перків.
## Усі дії йдуть через game.char_do(дія, аргумент), після чого екран перебудовується.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")


static func _pts(n: int) -> String:
	return "  (+%d)" % n if n > 0 else ""


static func build(game) -> Control:
	var p = game.player
	var pages := [
		["Герой" + _pts(p.stat_points), _hero(game)],
		["Журнал" + _pts(load("res://scripts/game/journal_service.gd").ready_count(game.world, p) + (1 if game.WayService.ready(game.world, p) else 0)), _journal(game)],
		["Вміння" + _pts(p.skill_points), _skills(game)],
		["Загартування" + _pts(p.perk_points + p.valor_points()), _perks(game)],
		["Літопис", _chronicle(game)],
		["Слава", _glory(game)],
		["Свята" + _pts(_holiday_ready(game)), _holidays(game)],
		["Події" + _pts(game.EventsBoard.ready_count(game.world, p)), _events(game)],
		["Виклики" + _pts(game.ChallengeService.ready_count(game.world, p)), _challenges(game)],
	]
	var title: String = game.PerilService.title(game.world)
	return UI.screen("%s%s — рівень %d   •   Гривні: %s" % [("Гетьман" if p.rank == "hetman" else p.class_name_ua()), (" «%s»" % title) if title != "" else "", p.level, UI.num(p.gold)], "Назад", game.close_character,
		pages, game.char_tab, func(i: int): game.char_tab = i, [["Довідник", func(): game.open_wiki(game._build_character)]])


static func _do(game, action: String, arg = null) -> Callable:
	return game.char_do.bind(action, arg)


# ---------------- Герой: вдягнене, показники й торба на одному екрані ----------------

const CELL := 70  # сторона клітинки торби
const DOLL_SLOTS := ["weapon", "head", "amulet", "belt", "body", "boots"]  # вдягнене: два ряди по три


static func _kv(key: String, value: String, size: int = 16) -> Control:
	var row := HBoxContainer.new()
	var k := UI.label(key, size, UI.MUTED, false)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	row.add_child(UI.label(value, size, UI.TEXT, false))
	return row


static func _hero(game) -> Control:
	var p = game.player
	var sel: int = game.char_sel_uid
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)

	# ----- Ліва панель: герой -----
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	left.add_child(top)
	var sum := VBoxContainer.new()
	sum.custom_minimum_size = Vector2(190, 0)
	sum.add_theme_constant_override("separation", 0)
	top.add_child(sum)
	for pair in [["Шкода за секунду", UI.num(int(p.Power.dps(p)))], ["Здоров'я", "%s / %s" % [UI.num(int(p.hp)), UI.num(int(p.max_hp))]],
			["Захист", "%d%%" % roundi(p.armor * 100)], ["Наснага", "%d / %d" % [int(p.mana), int(p.max_mana)]]]:
		sum.add_child(UI.label(pair[0], 14, UI.MUTED, false))
		sum.add_child(UI.label(pair[1], 21, UI.GOLD if pair[0] == "Шкода за секунду" else UI.TEXT, false))
	var doll_box := VBoxContainer.new()
	doll_box.add_theme_constant_override("separation", 4)
	doll_box.add_child(UI.label("Вдягнуто", 18, UI.GOLD, false))
	var doll := UI.grid(3)
	for slot in DOLL_SLOTS:
		if p.equipment.has(slot):
			var it: Dictionary = p.equipment[slot]
			doll.add_child(UI.item_cell(it, _do(game, "select", it["uid"]), it["uid"] == sel, CELL + 10))
		else:
			doll.add_child(UI.empty_cell(CELL + 10, "it_sabre" if slot == "weapon" else "it_" + slot))
	doll_box.add_child(doll)
	top.add_child(doll_box)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	if p.level >= p.Classes.BASE_LEVEL_MAX:
		# останній рівень: досвід наповнює смугу звитяги
		bar.max_value = maxf(1.0, float(p.valor_next()))
		bar.value = float(p.valor_xp)
		left.add_child(_kv("Звитяга %d: до наступної" % p.valor, "%s / %s" % [UI.num(p.valor_xp), UI.num(p.valor_next())], 15))
	else:
		bar.max_value = maxf(1.0, float(p.xp_next))
		bar.value = float(p.xp)
		left.add_child(_kv("Досвід до рівня %d" % (p.level + 1), "%s / %s" % [UI.num(p.xp), UI.num(p.xp_next)], 15))
	left.add_child(bar)

	# Очки характеристик: чотири коробки з «+»
	var pts := HBoxContainer.new()
	pts.add_theme_constant_override("separation", 8)
	var free := VBoxContainer.new()
	free.custom_minimum_size = Vector2(70, 0)
	free.add_child(UI.label("Очки", 15, UI.MUTED))
	free.add_child(UI.label(str(p.stat_points), 30, UI.GOLD if p.stat_points > 0 else UI.MUTED))
	pts.add_child(free)
	for st in Data.STATS:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 0)
		box.add_child(UI.label(st["name"], 14, UI.MUTED))
		box.add_child(UI.label(str(p.stat(st["id"])), 22, UI.TEXT))
		box.add_child(UI.button("+", _do(game, "stat", st["id"]), Vector2(88, 38), 22, p.stat_points > 0))
		pts.add_child(box)
	left.add_child(pts)

	# Докладні показники у дві колонки
	var lines := [
		["Зброя", Data.WEAPON_TYPES[p.weapon_type]["name"]],
		["Ударів за секунду", "%.2f" % (1.0 / p.attack_cooldown)],
		["Шкода удару", "%.1f" % p.damage],
		["Шанс криту", "%d%%  (x%s)" % [roundi(p.crit_chance * 100), ("%.2f" % p.crit_mult).trim_suffix("0").trim_suffix("0").trim_suffix(".")]],
		["Сила вмінь", "%d%%" % roundi(p.skill_power * 100)],
		["Перезарядка вмінь", "%d%%" % roundi(p.skill_cd_mult * 100)],
		["Наснага за секунду", "+%.1f" % p.mana_regen],
		["Відновлення", "%.1f / с" % p.regen],
		["Вампіризм", "%.1f%%" % (p.lifesteal * 100)],
		["Швидкість бігу", "%d" % int(p.speed)],
		["Дальність удару", "%d" % int(p.attack_range)],
		["Бонус досвіду", "+%d%%" % roundi((p.xp_mult - 1.0) * 100)],
		["Бонус гривень", "+%d%%" % roundi((p.gold_mult - 1.0) * 100)],
		["Зілля з собою", "%d і %d" % [p.potion_max(), p.mana_potion_max()]],
	]
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 22)
	stats.add_theme_constant_override("v_separation", 0)
	for l in lines:
		var cell := _kv(l[0], l[1], 14)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(cell)
	left.add_child(stats)

	# ----- Торба: сітка клітинок -----
	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", 6)
	h.add_child(bag)
	var bag_head := HBoxContainer.new()
	bag_head.add_theme_constant_override("separation", 10)
	var bl := UI.label("Торба %d/%d" % [p.inventory.size(), p.bag_size()], 20, UI.GOLD, false)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_head.add_child(bl)
	bag_head.add_child(UI.button("Душі: %d" % p.SoulService.pouch_count(p), _do(game, "select", -2), Vector2(130, 40), 16))
	bag.add_child(bag_head)
	var arts: Array = p.Artifacts.active_ids(p.inventory)
	if not arts.is_empty():
		bag.add_child(UI.label("Артефактів діє: %d" % arts.size(), 15, Data.RARITY_COLORS[p.Artifacts.RARITY], false))
	# Набори: скільки речей вдягнено й які щаблі вже діють
	var worn: Dictionary = p.Sets.count(p.equipment)
	for sid in p.Sets.ORDER:
		var n: int = int(worn.get(sid, 0))
		if n <= 0:
			continue
		var on := []
		for step in p.Sets.STEPS:
			if n >= int(step):
				on.append(p.Sets.step_text(sid, step))
		var sl := UI.label("✦ %s %d/%d%s" % [p.Sets.SETS[sid]["name"], n, Data.SLOTS.size(), (": " + ", ".join(on)) if not on.is_empty() else ": бонус від 2 речей"], 15, p.Sets.COLOR, false)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(300, 0)
		bag.add_child(sl)
	# Кращі за вдягнене речі позначено зеленою стрілкою; одна кнопка вдягає найкраще в кожну клітинку
	var gains := {}
	var up_slots := {}  # клітинки, для яких у торбі є щось сильніше (рахуємо з тих самих примірок)
	for it in p.inventory:
		gains[it["uid"]] = p.gain_from(it)
		if float(gains[it["uid"]]) > p.Power.MIN_GAIN:
			up_slots[it["slot"]] = true
	var ups: int = up_slots.size()
	if ups > 0:
		bag.add_child(UI.button("Вдягнути найкраще: %d" % ups, _do(game, "equip_best", 0), Vector2(300, 46), 17))
	var bg := UI.grid(6)
	for it in p.inventory:
		bg.add_child(UI.item_cell(it, _do(game, "select", it["uid"]), it["uid"] == sel, CELL, float(gains[it["uid"]]) > p.Power.MIN_GAIN))
	for i in maxi(0, p.bag_size() - p.inventory.size()):
		bg.add_child(UI.empty_cell(CELL))
	bag.add_child(bg)

	# ----- Картка вибраної речі -----
	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(320, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	var item: Dictionary = p.find_item(sel) if sel > 0 else {}
	if sel == -2:
		det.add_child(load("res://scripts/ui/ui_souls.gd").codex(p))  # Пом'яник душ замість картки речі
		return h
	if item.is_empty():
		det.add_child(UI.label("Торкнись речі,\nщоб побачити бонуси.", 19, UI.MUTED, false))
		det.add_child(UI.label("Заточувати речі й пробивати\nгнізда для душ можна в коваля.", 16, UI.MUTED, false))
		return h
	var equipped: bool = p.is_equipped(sel)
	var cmp: Dictionary = {} if equipped else p.equipment.get(item["slot"], {})
	# Дії з річчю стоять над карткою, щоб їх не треба було шукати гортанням
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 6)
	det.add_child(acts)
	if equipped:
		acts.add_child(UI.button("Зняти", _do(game, "unequip", sel), Vector2(150, 50), 19, not p.bag_full()))
	else:
		if not item.has("artifact"):
			var usable: bool = p.can_use(item)
			acts.add_child(UI.button("Вдягнути", _do(game, "equip", sel), Vector2(150, 50), 19, usable))
			if not usable:
				det.add_child(UI.label("Не для класу «%s»" % p.class_name_ua(), 16, UI.BAD, false))
		if game.char_return == game.State.PLAYING:
			acts.add_child(UI.button("Викинути на землю", _do(game, "drop", sel), Vector2(190, 50), 16))
		var sure: bool = game.confirm_action == "destroy:%d" % sel
		var db := UI.button("Точно знищити? Ще раз" if sure else "Знищити", _do(game, "destroy", sel), Vector2(190 if sure else 130, 50), 16)
		if sure:
			db.add_theme_stylebox_override("normal", UI.style(Color(0.45, 0.1, 0.08), Color(1.0, 0.5, 0.4), 10, 6))
		acts.add_child(db)
	if not equipped and p.can_use(item) and Data.SLOTS.has(item.get("slot", "")):
		# що дасть ця річ герою загалом: одне число замість порівняння рядок за рядком
		var gain: float = p.gain_from(item)
		var gt := "Сила героя з цією річчю: %s%d%%" % ["+" if gain >= 0.0 else "−", absi(roundi(gain * 100.0))]
		det.add_child(UI.label(gt, 16, UI.GOOD if gain > p.Power.MIN_GAIN else (UI.BAD if gain < -p.Power.MIN_GAIN else UI.MUTED), false))
	det.add_child(UI.item_card(item, cmp))
	if not item.has("artifact"):
		det.add_child(load("res://scripts/ui/ui_souls.gd").block(p, item, func(a: String, b): return _do(game, a, b), false))
	return h


# ---------------- Журнал завдань ----------------

static func _journal(game) -> Control:
	var Journal = load("res://scripts/game/journal_service.gd")
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var secs: Array = Journal.sections(game.world, p)
	var ready: int = Journal.ready_count(game.world, p)
	var head := "Усе, що зараз треба зробити. Завдань: %d" % Journal.total(game.world, p)
	if ready > 0:
		head += "   •   можна здати: %d" % ready
	v.add_child(UI.label(head, 17, UI.GOOD if ready > 0 else UI.MUTED, false))
	_way_card(game, v)
	# Порадник: що зробити просто зараз, від найважливішого. Дотик веде на мапу чи на потрібну вкладку
	v.add_child(UI.label("Що робити зараз", 22, UI.GOLD, false))
	var tips: Array = game.GuideService.top(game.world, p, game.map_here)
	for i in tips.size():
		var tip: Dictionary = tips[i]
		var tc := PanelContainer.new()
		tc.add_theme_stylebox_override("panel", UI.style(Color(0.16, 0.13, 0.08), Color(1.0, 0.8, 0.3) if i == 0 else Color(0.55, 0.45, 0.28), 10, 10))
		var tl := HBoxContainer.new()
		tl.add_theme_constant_override("separation", 10)
		tc.add_child(tl)
		var tb := VBoxContainer.new()
		tb.add_theme_constant_override("separation", 2)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.add_child(tb)
		var tt := UI.label("%d. %s" % [i + 1, str(tip["text"])], 19, UI.GOLD if i == 0 else UI.TEXT, false)
		tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tb.add_child(tt)
		if str(tip["sub"]) != "":
			var ts := UI.label(str(tip["sub"]), 15, UI.MUTED, false)
			ts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tb.add_child(ts)
		if str(tip["place"]) != "":
			_tap_card(tc, tl, "на мапі ›", _do(game, "place_show", [tip["place"], tip["text"]]))
		elif int(tip["tab"]) >= 0:
			_tap_card(tc, tl, "відкрити ›", _do(game, "tab_show", tip["tab"]))
		v.add_child(tc)
	for sec in secs:
		v.add_child(UI.label(sec["title"], 22, UI.GOLD, false))
		if sec.has("chapters"):
			# сюжетна гілка розділами: пройдені, нинішній і ті, що попереду
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 18)
			flow.add_theme_constant_override("v_separation", 2)
			for ch in sec["chapters"]:
				var mark: String = {"done": "✓ ", "now": "★ ", "ahead": "· "}[ch["state"]]
				flow.add_child(UI.label(mark + str(ch["title"]), 15, {"done": UI.GOOD, "now": UI.GOLD, "ahead": UI.MUTED}[ch["state"]], false))
			v.add_child(flow)
		if sec["rows"].is_empty() and str(sec["empty"]) != "":
			var el := UI.label(sec["empty"], 16, UI.MUTED, false)
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(el)
		for r in sec["rows"]:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UI.style(Color(0.14, 0.11, 0.1), Color(0.5, 0.9, 0.4) if r["ready"] else Color(0.42, 0.33, 0.2), 10, 10))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 10)
			card.add_child(line)
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 2)
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(box)
			var t := UI.label(r["text"], 19, UI.TEXT, false)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(t)
			var parts := []
			if r["where"] != "":
				parts.append("Де: %s" % r["where"])
			if r["from"] != "":
				parts.append("Від міста: %s" % r["from"])
			if r["reward"] != "":
				parts.append("Нагорода: %s" % r["reward"])
			if not parts.is_empty():
				var sub := UI.label("   •   ".join(parts), 15, UI.MUTED, false)
				sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box.add_child(sub)
			if r["ready"]:
				box.add_child(UI.label(r["ready_text"], 16, UI.GOOD, false))
			if str(r.get("place", "")) != "":
				# завдання з місцем: дотик показує на мапі мету, а для виконаного — місто, де здати
				_tap_card(card, line, "на мапі ›", _do(game, "place_show", [r["place"], r["text"]]))
			v.add_child(card)
	v.add_child(UI.label("Щоденні й тижневі виклики на вкладці «Виклики», заняття й події світу на вкладці «Події». На мапі зірка веде за історією, «!» позначає мету завдання, а зелена галочка стоїть на місті, де здати виконане.", 15, UI.MUTED, false))
	v.get_child(v.get_child_count() - 1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return v


## «Шлях козака»: нинішній крок ланцюжка цілей. Що зробити, як, яка нагорода; готове забирається кнопкою.
static func _way_card(game, v: VBoxContainer) -> void:
	var Way = game.WayService
	var w = game.world
	var p = game.player
	if Way.finished(w):
		return
	var step: Dictionary = Way.current(w)
	var ready: int = Way.ready_count(w, p)
	v.add_child(UI.label("Шлях козака  •  крок %d із %d" % [Way.index(w) + 1, Way.total()], 22, UI.GOLD, false))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.style(Color(0.13, 0.15, 0.1), Color(0.5, 0.9, 0.4) if ready > 0 else Color(0.75, 0.6, 0.3), 10, 10))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(box)
	box.add_child(UI.label(str(step["title"]), 20, UI.GOOD if ready > 0 else UI.TEXT, false))
	var how := UI.label(str(step["how"]), 15, UI.MUTED, false)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	box.add_child(UI.label("Нагорода: %s" % Way.reward_text(step), 15, UI.GOLD, false))
	if ready > 0:
		var cb := UI.button("Забрати нагороду" if ready == 1 else "Забрати все готове: %d" % ready, _do(game, "way_claim", 0), Vector2(250, 56), 18)
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(cb)
	else:
		var g: Dictionary = Way.go(step, w, p, game.map_here)
		if str(g["place"]) != "":
			_tap_card(card, line, "на мапі ›", _do(game, "place_show", [g["place"], step["title"]]))
		elif int(g["tab"]) >= 0 and int(g["tab"]) != Way.TAB_JOURNAL:
			_tap_card(card, line, "відкрити ›", _do(game, "tab_show", g["tab"]))
	v.add_child(card)


# ---------------- Виклики й досягнення ----------------

static func _challenges(game) -> Control:
	var CS = game.ChallengeService
	var w = game.world
	var p = game.player
	var c: Dictionary = CS.state(w, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var left: int = CS.seconds_to_reset()
	v.add_child(UI.label("Щоденні виклики  (оновляться за %d год %d хв)" % [left / 3600, (left % 3600) / 60], 24, UI.GOLD, false))
	for i in c["daily"].size():
		v.add_child(_challenge_row(game, c["daily"][i], false, i))
	v.add_child(UI.label("Виклики тижня", 24, UI.GOLD, false))
	for i in c["weekly"].size():
		v.add_child(_challenge_row(game, c["weekly"][i], true, i))
	var A = CS.A
	v.add_child(UI.label("Досягнення: %d / %d" % [c["ach"].size(), A.ACHIEVEMENTS.size()], 24, UI.GOLD, false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for a in A.ACHIEVEMENTS:
		var got: bool = c["ach"].has(a["id"])
		var cur: int = int(w.stats.get(a["stat"], 0))
		var text: String = ("✔ " if got else "") + a["name"]
		var sub: String = a["desc"] + ("" if got else "  (%d/%d)" % [mini(cur, a["goal"]), a["goal"]])
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(520, 0)
		col.add_child(UI.label(text, 19, UI.GOOD if got else UI.TEXT, false))
		col.add_child(UI.label(sub, 15, UI.MUTED, false))
		grid.add_child(col)
	v.add_child(grid)
	return v


static func _challenge_row(game, ch: Dictionary, weekly: bool, i: int) -> Control:
	var CS = game.ChallengeService
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: bool = int(ch["progress"]) >= int(ch["goal"])
	col.add_child(UI.label("%s  %d/%d" % [ch["text"], ch["progress"], ch["goal"]], 20, UI.GOOD if done else UI.TEXT, false))
	var where: String = str(ch.get("where", ""))
	var sub: String = "Нагорода: " + CS.reward_text(weekly, game.player.level)
	if where != "" and not done:
		sub = "Де: %s   •   %s" % [where, sub]
	col.add_child(UI.label(sub, 15, UI.MUTED, false))
	row.add_child(col)
	var label := "Отримано" if ch["claimed"] else "Забрати"
	row.add_child(UI.button(label, _do(game, "claim", [weekly, i]), Vector2(170, 56), 18, CS.can_claim(ch)))
	return row


# ---------------- Літопис ----------------

static func _chronicle(game) -> Control:
	var SS = game.StoryService
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var title: String = SS.chapter_title(game.world)
	v.add_child(UI.label(title if title != "" else "Сюжет пройдено", 26, UI.GOLD, false))
	var obj: String = SS.objective_line(game.world)
	if obj != "":
		v.add_child(UI.label(obj, 20, UI.TEXT, false))
	v.add_child(UI.label("Твої вибори та їхні наслідки", 24, UI.GOLD, false))
	var rec: Array = SS.chronicle(game.world)
	if rec.is_empty():
		v.add_child(UI.label("Поки що доля ще не ставила тебе перед вибором.", 19, UI.MUTED, false))
	var last := ""
	for r in rec:
		if r["chapter"] != last:
			last = r["chapter"]
			v.add_child(UI.label(last, 18, UI.MUTED, false))
		var l := UI.label("•  " + r["text"], 20, UI.TEXT, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


# ---------------- Сезонні свята ----------------

## Скільки нагород свята можна забрати просто зараз.
static func _holiday_ready(game) -> int:
	var n := 0
	for i in 3:
		if game.HolidayService.can_claim(game.world, i):
			n += 1
	return n


static func _holidays(game) -> Control:
	var HS = game.HolidayService
	var Acts = game.Acts
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var id: String = HS.active()
	if id != "":
		var H: Dictionary = Acts.HOLIDAYS[id]
		v.add_child(UI.label("Сьогодні свято: %s" % H["name"], 28, UI.GOLD, false))
		var d := UI.label(H["desc"], 17, UI.TEXT, false)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		v.add_child(UI.label("Святковий бонус: %s   •   днів лишилось: %d" % [H["bonus_text"], HS.days_left()], 19, UI.GOOD, false))
		var have: int = HS.tokens(w)
		v.add_child(UI.icon_text("tok_" + id, "%s: %d   (падає з нечисті; жетони спільні для всіх твоїх персонажів)" % [H["token"], have], 19, UI.GOLD))
		var tiers: Array = HS.tiers(id)
		var claimed: Array = HS.progress(w)["claimed"]
		for i in 3:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			var done: bool = claimed[i]
			var l := UI.label("%s %d %s — %s" % ["✓" if done else "•", int(tiers[i]), H["tokens"], HS.reward_text(i, p.level)], 18, UI.MUTED if done else UI.TEXT, false)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			if done:
				row.add_child(UI.button("Забрано", func(): pass, Vector2(220, 56), 18, false))
			else:
				row.add_child(UI.button("Забрати" if have >= int(tiers[i]) else "%d/%d" % [have, int(tiers[i])], _do(game, "holiday_claim", i), Vector2(220, 56), 18, HS.can_claim(w, i)))
			v.add_child(row)
	else:
		var nx: Dictionary = HS.upcoming()
		v.add_child(UI.label("Сьогодні будень", 26, UI.GOLD, false))
		if not nx.is_empty():
			v.add_child(UI.label("Найближче свято: %s — за %d дн." % [Acts.HOLIDAYS[nx["id"]]["name"], int(nx["in_days"])], 20, UI.TEXT, false))
		var hint := UI.label("У свята діє особливий бонус, а з нечисті падають жетони. За жетони дають три нагороди: гривні з ресурсами, річ і славу, а на великі свята ще й Алатир-камінь.", 16, UI.MUTED, false)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
	v.add_child(UI.label("Календар свят", 24, UI.GOLD, false))
	var legend := UI.label("★ велике свято: жетонів треба більше, зате найвища нагорода — Алатир-камінь. Малі свята коротші, і нагороди в них скромніші.", 15, UI.MUTED, false)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(legend)
	var table := UI.grid(3)
	table.add_theme_constant_override("h_separation", 30)
	table.add_theme_constant_override("v_separation", 6)
	for row in HS.calendar():
		var col: Color = UI.GOOD if row["active"] else UI.TEXT
		table.add_child(UI.label(("★ " if row["great"] else "") + row["name"], 18, col, false))
		table.add_child(UI.label(row["dates"] + ("  •  триває" if row["active"] else "  •  за %d дн." % int(row["in_days"])), 16, col if row["active"] else UI.MUTED, false))
		table.add_child(UI.label(row["bonus"], 16, UI.MUTED, false))
	v.add_child(table)
	return v


# ---------------- Події й заняття (як календар свят) ----------------

static func _events(game) -> Control:
	var EB = game.EventsBoard
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Зараз на мапі", 26, UI.GOLD, false))
	var now: Array = EB.now_items(w, p, game.map_here)
	if now.is_empty():
		v.add_child(UI.label("Спокійно: подій на мапі зараз нема. Вони трапляються після походів.", 18, UI.MUTED, false))
	for it in now:
		if str(it["place"]) != "":
			# подія має місце: дотик показує його на мапі
			var nb := UI.button("• %s   ›  на мапі" % str(it["text"]), _do(game, "event_show", it["id"]), Vector2(0, 46), 18)
			nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(nb)
			continue
		var l := UI.label("• " + str(it["text"]), 19, UI.GOOD, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var hint := UI.label("Торкнись події, щоб побачити її місце на мапі.", 15, UI.MUTED, false)
	v.add_child(hint)
	var rows: Array = EB.rows(w, p, game.map_here)
	for k in EB.Wiki.EVENT_KINDS:
		v.add_child(UI.label(k[1], 24, UI.GOLD, false))
		var grid := UI.grid(2)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		for r in rows:
			if r["kind"] == k[0]:
				grid.add_child(_event_card(r, game))
		v.add_child(grid)
	v.add_child(UI.button("Докладно про кожну подію — у довіднику", func(): game.open_wiki(game._build_character, "events"), Vector2(620, 60), 20))
	return v


static func _event_card(r: Dictionary, game = null) -> Control:
	var ready: bool = r["ready"]
	var locked: bool = r["locked"]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := UI.GOOD if ready else (Color(0.35, 0.32, 0.28) if locked else Color(0.55, 0.45, 0.28))
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.14, 0.11, 0.09), border, 10, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var icon := UI.map_icon(str(r["icon"]), 40)
	if locked:
		icon.modulate = Color(1, 1, 1, 0.45)
	h.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	col.add_child(UI.label(r["name"], 20, UI.GOOD if ready else (UI.MUTED if locked else UI.TEXT), false))
	var where := UI.label(str(r["where"]), 14, UI.MUTED, false)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(where)
	if str(r["status"]) != "":
		var st := UI.label(str(r["status"]), 16, UI.GOOD if ready else (UI.MUTED if locked else UI.TEXT), false)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(st)
	# Подія з місцем на мапі: уся картка стає кнопкою, праворуч підказка
	var opens: String = "вкладка ›" if str(r["id"]) == "challenges" else ("на мапі ›" if str(r.get("place", "")) != "" else "")
	if game != null and opens != "" and not locked:
		_tap_card(panel, h, opens, _do(game, "event_show", r["id"]))
	return panel


## Робить картку кнопкою: праворуч у рядку row підказка cue, а дотик до будь-якої точки картки викликає cb.
static func _tap_card(panel: PanelContainer, row: HBoxContainer, cue: String, cb: Callable) -> void:
	var cl := UI.label(cue, 14, UI.GOLD, false)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cl)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for sb in ["normal", "focus", "disabled"]:
		tap.add_theme_stylebox_override(sb, StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("hover", UI.style(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.0), 10, 0))
	tap.add_theme_stylebox_override("pressed", UI.style(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0), 10, 0))
	tap.pressed.connect(cb)
	panel.add_child(tap)


# ---------------- Слава й рекорди роду ----------------

static func _glory(game) -> Control:
	var GS = game.GloryService
	var RS = game.RecordService
	var Acts = game.Acts
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var gl: int = GS.glory(w)
	var next: int = GS.to_next(w)
	v.add_child(UI.icon_text("glory", "Слава: %d — %s%s" % [gl, GS.rank_name(w), ("   •   до наступного рангу: %d" % next) if next > 0 else "   •   найвищий ранг"], 26, UI.GOLD))
	var cur: int = GS.rank_index(gl)
	var ranks := UI.grid(2)
	ranks.add_theme_constant_override("h_separation", 40)
	for i in range(1, Acts.GLORY_RANKS.size()):
		var R: Array = Acts.GLORY_RANKS[i]
		var reward := "%d грн" % int(R[2])
		if str(R[3]) != "":
			reward += " і %s" % game.StoneService.NAMES[R[3]]
		ranks.add_child(UI.label("%s %s — %d слави: %s" % ["✓" if i <= cur else "•", R[1], int(R[0]), reward], 16, UI.GOOD if i <= cur else UI.MUTED, false))
	v.add_child(ranks)
	v.add_child(UI.label("Звідки береться слава", 20, UI.GOLD, false))
	for line in Acts.GLORY_SOURCES:
		var sl := UI.label("•  " + line, 15, UI.MUTED, false)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
	v.add_child(UI.label("Рекорди роду", 24, UI.GOLD, false))
	v.add_child(UI.label("Найкраще серед усіх твоїх персонажів. Золотим позначено рекорди, які тримає цей герой.", 15, UI.MUTED, false))
	var table := UI.grid(3)
	table.add_theme_constant_override("h_separation", 36)
	table.add_theme_constant_override("v_separation", 6)
	for head in ["", "Цей герой", "Рекорд роду"]:
		table.add_child(UI.label(head, 16, UI.MUTED, false))
	for row in RS.rows(w, p, game.slot):
		table.add_child(UI.label(row["name"], 18, UI.TEXT, false))
		table.add_child(UI.label(row["mine"], 18, UI.GOLD if row["holder"] else UI.TEXT, false))
		var best: String = row["best"]
		if row["who"] != "" and not row["holder"]:
			best += "  (%s)" % row["who"]
		elif row["holder"]:
			best += "  (твій)"
		table.add_child(UI.label(best, 18, UI.GOLD if row["holder"] else UI.TEXT, false))
	v.add_child(table)
	return v


# ---------------- Вміння ----------------

static func _tree_button(text: String, rank: int, max_rank: int, can: bool, locked: bool, font: int, min_size: Vector2, cb: Callable) -> Button:
	var b := UI.button(text, cb, min_size, font, can)
	if rank >= max_rank:
		b.add_theme_stylebox_override("disabled", UI.style(Color(0.15, 0.32, 0.15), Color(0.5, 0.9, 0.4)))
		b.add_theme_color_override("font_disabled_color", Color(0.85, 1.0, 0.8))
	elif rank > 0:
		b.add_theme_stylebox_override("disabled", UI.style(Color(0.35, 0.12, 0.1), Color(0.8, 0.6, 0.2)))
		b.add_theme_color_override("font_disabled_color", Color(0.95, 0.88, 0.75))
	elif locked:
		b.modulate = Color(1, 1, 1, 0.6)
	return b


const SK_CELL := 68  # значок вміння в дереві
const TAB_CHALLENGES := 8  # номер вкладки «Виклики» (подія «Виклики дня й тижня» відкриває її)
const SK_STEP_X := 124  # крок між гілками
const SK_STEP_ONE := 200  # ширина дерева з однією гілкою: щоб довга назва не налазила на сусідню колонку
const SK_STEP_Y := 102  # крок між рядами
const SK_TOP := 34  # місце під назву гілки


## Значок вміння: рамка показує стан (зелена — вивчено до межі, золота — вивчено, сіра — ще ні, бліда — закрито).
static func _skill_cell(p, n: Dictionary, selected: bool, cb: Callable, px: int = SK_CELL, plain: bool = false) -> Button:
	var id: String = n["id"]
	var rank: int = p.sk(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.size = Vector2(px, px)
	var edge := Color(0.5, 0.9, 0.4) if rank >= int(n["max"]) else (Color(1.0, 0.8, 0.3) if rank > 0 else Color(0.42, 0.36, 0.3))
	var bg := Color(0.2, 0.12, 0.1) if rank > 0 else Color(0.11, 0.095, 0.085)
	if plain:
		# кнопка бою: рамка не каже про ранг, щоб зелений лишався лише для «сюди можна поставити»
		edge = Color(0.75, 0.6, 0.3)
		bg = Color(0.16, 0.12, 0.1)
	if selected:
		edge = Color(1.0, 1.0, 0.92)
		bg = bg.lightened(0.12)
	b.add_theme_stylebox_override("normal", UI.style(bg, edge, 10, 2))
	b.add_theme_stylebox_override("hover", UI.style(bg.lightened(0.06), edge, 10, 2))
	b.add_theme_stylebox_override("pressed", UI.style(bg.darkened(0.1), edge, 10, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var tex := Gfx.skill_icon_tex(id)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.position = Vector2(8, 8)
		t.size = Vector2(px - 16, px - 16)
		b.add_child(t)
	if n.get("active", false):
		# активне вміння: позначка, атака це чи підсилення
		var m := UI.label("⚔" if p.SkillInfo.kind(id) == "attack" else "✦", 15, Color(1.0, 0.95, 0.8), false)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("outline_size", 5)
		m.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04))
		m.position = Vector2(px - 21, 0)
		b.add_child(m)
	if not p.skill_req_met(n) and rank == 0:
		b.modulate = Color(1, 1, 1, 0.45)
	b.pressed.connect(cb)
	return b


static func _skills(game) -> Control:
	var p = game.player
	var Classes = p.Classes
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)

	# ----- Ліворуч: очки й перемикач дерев -----
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	left.add_child(UI.label("Очки вмінь", 15, UI.MUTED))
	left.add_child(UI.label(str(p.skill_points), 38, UI.GOLD if p.skill_points > 0 else UI.MUTED))
	var lineage: Array = Classes.lineage(p.job).filter(func(c): return Classes.TREES.has(c))
	var shown: String = game.skill_tree if game.skill_tree in lineage else p.job
	left.add_child(UI.label("Дерева", 15, UI.MUTED))
	for c in lineage:
		var tb := UI.button(str(Classes.CLASSES[c]["name"]), _do(game, "skill_tree", c), Vector2(170, 56), 17)
		if c == shown:
			tb.add_theme_stylebox_override("normal", UI.style(Color(0.3, 0.25, 0.12), Color(1.0, 0.85, 0.3), 10, 6))
		# у кутку кнопки: скільки рангів дерева вивчено, щоб було видно, куди ще можна вкласти очки
		var prog: Array = p.tree_progress(c)
		var pl := UI.label("%d/%d" % prog, 12, Color(0.6, 0.95, 0.5) if prog[0] >= prog[1] else UI.GOLD, false)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pl.offset_top = -19
		pl.offset_bottom = -3
		pl.offset_left = 8
		pl.offset_right = -9
		tb.add_child(pl)
		left.add_child(tb)
	var mastery := "Майстерність %d/%d" % [p.job_level, p.job_max()]
	if p.job_level < p.job_max():
		mastery += "\nдосвід %d/%d" % [p.job_xp, p.job_next()]
	left.add_child(UI.label(mastery, 14, UI.MUTED))
	var note := "Очко за кожен рівень майстерності."
	var own: Array = p.tree_progress(p.job)
	if shown != p.job:
		note = "Пройдене дерево. Вільні очки можна вкладати й сюди."
	elif own[0] >= own[1] and p.skill_points > 0 and lineage.size() > 1:
		var all_full := true
		for c in lineage:
			var pr: Array = p.tree_progress(c)
			all_full = all_full and pr[0] >= pr[1]
		note = "Усю дорогу вивчено до кінця. Очки лишились про запас." if all_full else "Це дерево вивчено до кінця. Вільні очки вклади в пройдені дерева: кнопки вище."
	if p.can_change_class():
		var names := []
		for c in p.class_info()["next"]:
			names.append("%s (%s)" % [Classes.CLASSES[c]["name"], {"sich": "Січ", "kapyshche": "Карпати"}.get(Classes.CLASSES[c].get("where", ""), "")])
		note = "Можна обирати нову дорогу: " + ", ".join(names) + ". Іди до наставника."
	var nl := UI.label(note, 13, UI.GOOD if p.can_change_class() else UI.MUTED, false)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(170, 0)
	left.add_child(nl)

	# ----- Посередині: дерево значками -----
	var branches: Array = Classes.TREES[shown]
	var rows := 1
	for br in branches:
		rows = maxi(rows, br["nodes"].size())
	var step: float = SK_STEP_X if branches.size() > 1 else SK_STEP_ONE
	var view: Control = load("res://scripts/ui/tree_lines.gd").new()
	view.custom_minimum_size = Vector2(branches.size() * step, SK_TOP + rows * SK_STEP_Y)
	var at := {}  # id вміння -> центр його значка
	for bi in branches.size():
		for ni in branches[bi]["nodes"].size():
			at[branches[bi]["nodes"][ni]["id"]] = Vector2(bi * step + step / 2.0, SK_TOP + ni * SK_STEP_Y + SK_CELL / 2.0)
	for bi in branches.size():
		var title := UI.label(str(branches[bi]["name"]), 18, UI.GOLD)
		title.position = Vector2(bi * step, 0)
		title.size = Vector2(step, 28)
		view.add_child(title)
		var nodes: Array = branches[bi]["nodes"]
		for ni in nodes.size():
			var n: Dictionary = nodes[ni]
			var c: Vector2 = at[n["id"]]
			for r in n.get("req", {}):
				if at.has(r):
					view.links.append([at[r], c, p.sk(r) >= int(n["req"][r])])
			var cell := _skill_cell(p, n, n["id"] == game.skill_sel, _do(game, "skill_pick", n["id"]))
			cell.position = c - Vector2(SK_CELL, SK_CELL) / 2.0
			view.add_child(cell)
			var rank: int = p.sk(n["id"])
			var rl := UI.label("%d/%d" % [rank, int(n["max"])], 15, (Color(0.6, 0.95, 0.5) if rank >= int(n["max"]) else UI.GOLD) if rank > 0 else UI.MUTED)
			rl.position = Vector2(c.x - step / 2.0, c.y + SK_CELL / 2.0 + 1.0)
			rl.size = Vector2(step, 20)
			view.add_child(rl)
	h.add_child(view)

	# ----- Праворуч: кнопки бою й картка вміння -----
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_panel_block(game, right)
	right.add_child(_skill_card(game))
	_stones_row(game, right)
	return h


## Кнопки бою: три атаки біля «Удару» й п'ять підсилень знизу. Дотик до кнопки вибирає вміння на ній.
## Коли вибрано вивчене активне вміння (у дереві чи на кнопці), кнопки його виду світяться зеленим:
## дотик ставить вміння туди, а те, що там стояло, переходить на його місце.
static func _panel_block(game, v: VBoxContainer) -> void:
	var p = game.player
	p.sync_panel()
	var sel: String = game.skill_sel
	var sel_kind: String = p.SkillInfo.kind(sel) if sel != "" else ""
	var can_place: bool = sel != "" and p.sk(sel) > 0 and p.Classes.find_node(sel).get("active", false)
	v.add_child(UI.label("Кнопки бою", 20, UI.GOLD, false))
	for kind in ["attack", "buff"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var cap := UI.label("⚔ Атаки\nбіля «Удару»" if kind == "attack" else "✦ Підсилення\nнижній ряд", 13, UI.MUTED, false)
		cap.custom_minimum_size = Vector2(104, 0)
		row.add_child(cap)
		var arr: Array = p.panel[kind]
		for i in arr.size():
			var id: String = arr[i]
			var slot := VBoxContainer.new()
			slot.add_theme_constant_override("separation", 0)
			var b: Button
			var place: bool = can_place and sel_kind == kind
			if id != "":
				b = _skill_cell(p, p.Classes.find_node(id), id == sel, _do(game, "panel_set", [kind, i, sel]) if place and id != sel else _do(game, "skill_pick", id), 58, true)
				b.modulate = Color.WHITE
			else:
				b = UI.button("", _do(game, "panel_set", [kind, i, sel]) if place else func(): pass, Vector2(58, 58), 14, place)
			if place and id != sel:
				for st in ["normal", "hover", "pressed"]:
					b.add_theme_stylebox_override(st, UI.style(Color(0.16, 0.3, 0.13), Color(0.5, 0.95, 0.4), 10, 2))
			slot.add_child(b)
			var cl := UI.label(str(Data.ACTIVE_LABELS.get(id, "")) if id != "" else "вільно", 12, (UI.GOOD if place and id != sel else UI.TEXT) if id != "" else (UI.GOOD if place else UI.MUTED))
			cl.custom_minimum_size = Vector2(58, 0)
			slot.add_child(cl)
			row.add_child(slot)
		v.add_child(row)
	var hint := "Торкнись зеленої кнопки, щоб поставити туди «%s». Те, що там стоїть, перейде на його місце." % Data.skill_name(sel) if can_place else "Щоб переставити вміння, торкнись його кнопки або вивченого активного вміння в дереві (з позначкою ⚔ чи ✦), а тоді зеленої кнопки."
	var hl := UI.label(hint, 13, UI.GOOD if can_place else UI.MUTED, false)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hl)


## Картка вміння: що робить, цифри зараз → наступний ранг, ціна, перезарядка; «Вивчити».
static func _skill_card(game) -> Control:
	var p = game.player
	var SI = p.SkillInfo
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(360, 0)
	card.add_theme_constant_override("separation", 6)
	var id: String = game.skill_sel
	var n: Dictionary = p.Classes.find_node(id) if id != "" else {}
	if n.is_empty():
		card.add_child(UI.label("Торкнись вміння в дереві —\nтут буде його картка.", 20, UI.MUTED, false))
		return card
	var rank: int = p.sk(id)
	var active: bool = n.get("active", false)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var ic := Gfx.skill_icon_tex(id)
	if ic != null:
		var tr := TextureRect.new()
		tr.texture = ic
		tr.custom_minimum_size = Vector2(72, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		head.add_child(tr)
	var title := UI.label(n["name"], 26, UI.GOLD, false)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	card.add_child(head)
	var sub := "Ранг %d/%d" % [rank, n["max"]]
	if active:
		sub += "  •  %s" % ("атака ⚔" if SI.kind(id) == "attack" else "баф ✦")
	card.add_child(UI.label(sub, 16, UI.MUTED, false))
	# Кнопка «Вивчити» стоїть одразу під назвою, щоб її не треба було шукати гортанням
	if rank >= int(n["max"]):
		card.add_child(UI.label("Максимальний ранг", 16, UI.GOOD, false))
	else:
		var why := "Вивчити (1 очко)"
		if p.skill_points <= 0:
			why = "Немає очок вмінь"
		elif not p.skill_req_met(n):
			why = "Спершу вивчи потрібне"
		var lb := UI.button(why, _do(game, "skill", id), Vector2(340, 52), 18, p.can_learn_skill(n))
		lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.add_child(lb)
		if not p.skill_req_met(n):
			var reqs := []
			for r in n["req"]:
				if p.sk(r) < n["req"][r]:
					reqs.append("%s %d" % [p.Classes.find_node(r).get("name", r), n["req"][r]])
			card.add_child(UI.label("Потрібно: " + ", ".join(reqs), 15, UI.BAD, false))
	var what: String = SI.WHAT.get(id, n["desc"].replace("\n", " "))
	var wl := UI.label(what, 17, UI.TEXT, false)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(wl)
	if active:
		var cost := int(n.get("cost", 0))
		card.add_child(UI.label("Наснага: %d   •   Перезарядка: %.1f с" % [cost, p.skill_cooldown(id)], 16, UI.TEXT, false))
		var scales: String = SI.SCALES.get(id, "")
		if scales != "" and scales != "—":
			card.add_child(UI.label("Підсилює: " + scales, 14, UI.MUTED, false))
		var now: Array = SI.stats(id, rank, p)
		var next: Array = SI.stats(id, mini(rank + 1, n["max"]), p) if rank < n["max"] else []
		if not now.is_empty():
			var g := GridContainer.new()
			g.columns = 3 if not next.is_empty() else 2
			g.add_theme_constant_override("h_separation", 14)
			g.add_theme_constant_override("v_separation", 2)
			g.add_child(UI.label("", 13, UI.MUTED, false))
			g.add_child(UI.label("Ранг %d" % maxi(1, rank) if rank > 0 else "Ранг 1", 13, UI.MUTED, false))
			if not next.is_empty():
				g.add_child(UI.label("→ ранг %d" % (rank + 1), 13, UI.GOOD, false))
			for i in now.size():
				g.add_child(UI.label(now[i][0], 15, UI.MUTED, false))
				g.add_child(UI.label(str(now[i][1]), 15, UI.TEXT, false))
				if not next.is_empty():
					var nv: String = str(next[i][1]) if i < next.size() else ""
					g.add_child(UI.label(nv if nv != str(now[i][1]) else "—", 15, UI.GOOD if nv != str(now[i][1]) else UI.MUTED, false))
			card.add_child(g)
	else:
		var dl := UI.label(n["desc"].replace("\n", " "), 15, UI.MUTED, false)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(dl)
	if active and rank > 0:
		var on: bool = id in p.panel["attack"] or id in p.panel["buff"]
		card.add_child(UI.label("Стоїть на кнопці бою" if on else "Не на кнопці: торкнись зеленої кнопки бою вище", 14, UI.GOOD if on else UI.MUTED, false))
	return card


## Камені долі: скинути очки або змінити дорогу (друге натискання — підтвердження).
static func _stones_row(game, v: VBoxContainer) -> void:
	var p = game.player
	var SS = game.StoneService
	var z: int = SS.count(p, "zabuttia")
	var a: int = SS.count(p, "alatyr")
	if z == 0 and a == 0:
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	if z > 0:
		var t := ("Камінь забуття ×%d: скинути очки" % z) if game.confirm_action != "stone_reset" else "Точно скинути? Ще раз"
		row.add_child(UI.button(t, _do(game, "stone_reset"), Vector2(250, 44), 13))
	if a > 0:
		for cls in SS.siblings(p):
			var key: String = "stone_path:" + cls
			var nm: String = p.Classes.CLASSES[cls]["name"]
			var t: String = ("Алатир ×%d: стати «%s»" % [a, nm]) if game.confirm_action != key else "Точно «%s»? Ще раз" % nm
			row.add_child(UI.button(t, _do(game, "stone_path", cls), Vector2(250, 44), 13))
	v.add_child(row)
	if game.confirm_action != "":
		v.add_child(UI.label("Забуття повертає очки характеристик, Загартування й вмінь нинішнього класу. Алатир змінює дорогу: вміння старої забуваються з поверненням очок.", 15, UI.MUTED, false))


# ---------------- Загартування ----------------

static func _perks(game) -> Control:
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(UI.label("Очки Загартування: %d   (+1 за кожні %d рівні героя). Спільне для всіх класів. Новий ярус — за кожні %d очки в гілці." % [p.perk_points, p.Classes.HARDEN_EVERY, Data.PERK_TIER_STEP], 20, UI.GOLD if p.perk_points > 0 else UI.MUTED))
	_valor_block(game, v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	for bi in Data.PERK_BRANCHES.size():
		var branch: Dictionary = Data.PERK_BRANCHES[bi]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(UI.label("%s  (%d)" % [branch["name"], p.branch_perk_points(bi)], 26, UI.GOLD))
		var tiers: Array = branch["tiers"]
		for ti in tiers.size():
			var open: bool = p.perk_tier_open(bi, ti)
			if ti > 0:
				col.add_child(UI.connector())
			if not open:
				col.add_child(UI.label("Ярус %d: ще %d очк. у гілку" % [ti + 1, ti * Data.PERK_TIER_STEP - p.branch_perk_points(bi)], 15, UI.MUTED))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			for pk in tiers[ti]:
				var rank: int = p.pk(pk["id"])
				var text := "%s  %d/%d\n%s" % [pk["name"], rank, pk["max"], pk["desc"]]
				var w := 356.0 if tiers[ti].size() == 1 else 174.0
				row.add_child(_tree_button(text, rank, pk["max"], p.can_learn_perk(pk["id"]), not open, 13, Vector2(w, 84), _do(game, "perk", pk["id"])))
			col.add_child(row)
		h.add_child(col)
	return v


## Звитяги: поступ після останнього рівня. Смуга, вільні очки, п'ять ліній і іменні звитяги героя.
static func _valor_block(game, v: VBoxContainer) -> void:
	var p = game.player
	var Valor = p.Valor
	var cap: int = p.Classes.BASE_LEVEL_MAX
	if p.level < cap and p.valor <= 0:
		v.add_child(UI.label("Звитяги відкриються на %d-му рівні: досвід далі наповнює смугу звитяги, а кожна смуга дає очко малих вічних бонусів." % cap, 15, UI.MUTED))
		_named_valor(game, v)
		return
	var head := UI.label("Звитяга %d   •   вільних очок: %d   •   до наступної: %s / %s" % [p.valor, p.valor_points(), UI.num(p.valor_xp), UI.num(p.valor_next())], 19, UI.GOLD)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for id in Valor.ORDER:
		var L: Dictionary = Valor.LINES[id]
		var n: int = int(p.valor_spent.get(id, 0))
		var text := "%s  %d/%d\n%s" % [L["name"], n, Valor.LINE_MAX, Valor.text(id, float(L["per"]) * maxi(n, 1))]
		row.add_child(_tree_button(text, n, Valor.LINE_MAX, p.can_add_valor(id), false, 13, Vector2(214, 78), _do(game, "valor", id)))
	v.add_child(row)
	_named_valor(game, v)


## Іменні звитяги героя: звання за надважких босів і їхні бонуси.
static func _named_valor(game, v: VBoxContainer) -> void:
	var PS = game.PerilService
	var Peril = game.Peril
	var got: Array = PS.titles(game.world)
	if got.is_empty():
		return
	var parts := []
	for boss in got:
		parts.append("%s (%s)" % [str(Peril.TITLES.get(boss, "")), game.player.Valor.fx_text(Peril.TITLE_FX.get(boss, {}))])
	var l := UI.label("Іменні звитяги: " + ", ".join(parts), 15, UI.GOOD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)


## Додати до кнопки піксельний значок вміння (ліворуч від тексту або над ним).
static func _with_icon(b: Button, id: String, size: int, above: bool = false) -> void:
	var tex := Gfx.skill_icon_tex(id)
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", size)
	if above:
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
