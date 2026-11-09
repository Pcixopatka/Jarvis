extends RefCounted
## Екран козака: характеристики, спорядження, дерево вмінь, дерево перків.
## Усі дії йдуть через game.char_do(дія, аргумент), після чого екран перебудовується.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")


static func _pts(n: int) -> String:
	return "  (+%d)" % n if n > 0 else ""


static func build(game) -> Control:
	var p = game.player
	var pages := [
		["Характеристики" + _pts(p.stat_points), _stats(game)],
		["Спорядження", _gear(game)],
		["Вміння" + _pts(p.skill_points), _skills(game)],
		["Загартування" + _pts(p.perk_points), _perks(game)],
		["Літопис", _chronicle(game)],
		["Виклики" + _pts(game.ChallengeService.ready_count(game.world)), _challenges(game)],
	]
	return UI.screen("%s — рівень %d   •   Гривні: %d" % [("Гетьман" if p.rank == "hetman" else p.class_name_ua()), p.level, p.gold], "Назад", game.close_character,
		pages, game.char_tab, func(i: int): game.char_tab = i)


static func _do(game, action: String, arg = null) -> Callable:
	return game.char_do.bind(action, arg)


# ---------------- Характеристики ----------------

static func _stats(game) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UI.label("Вільні очки: %d   (+%d за рівень)" % [p.stat_points, Data.STAT_POINTS_PER_LEVEL], 24, UI.GOLD if p.stat_points > 0 else UI.MUTED, false))
	for st in Data.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bonus := int(p.eq(st["id"]))
		var extra := ("  (+%d від спорядження)" % bonus) if bonus > 0 else ""
		info.add_child(UI.label("%s: %d%s" % [st["name"], p.stat(st["id"]), extra], 28, UI.TEXT, false))
		info.add_child(UI.label(st["desc"], 17, UI.MUTED, false))
		row.add_child(info)
		row.add_child(UI.button("+", _do(game, "stat", st["id"]), Vector2(90, 70), 0, p.stat_points > 0))
		left.add_child(row)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.custom_minimum_size = Vector2(380, 0)
	h.add_child(right)
	right.add_child(UI.label("Бойові показники", 24, UI.GOLD, false))
	var lines := [
		["Зброя", Data.WEAPON_TYPES[p.weapon_type]["name"]],
		["Здоров'я", "%d / %d" % [int(p.hp), int(p.max_hp)]],
		["Наснага", "%d / %d  (+%.1f/с)" % [int(p.mana), int(p.max_mana), p.mana_regen]],
		["Шкода", "%.1f" % p.damage],
		["Ударів за секунду", "%.2f" % (1.0 / p.attack_cooldown)],
		["Шанс криту", "%d%%  (x%.0f)" % [roundi(p.crit_chance * 100), p.crit_mult]],
		["Дальність удару", "%d" % int(p.attack_range)],
		["Захист", "%d%%" % roundi(p.armor * 100)],
		["Швидкість бігу", "%d" % int(p.speed)],
		["Сила вмінь", "%d%%" % roundi(p.skill_power * 100)],
		["Перезарядка вмінь", "%d%%" % roundi(p.skill_cd_mult * 100)],
		["Відновлення", "%.1f / с" % p.regen],
		["Вампіризм", "%.1f%%" % (p.lifesteal * 100)],
		["Бонус досвіду / гривень", "+%d%% / +%d%%" % [roundi((p.xp_mult - 1.0) * 100), roundi((p.gold_mult - 1.0) * 100)]],
	]
	for l in lines:
		var row := HBoxContainer.new()
		var k := UI.label(l[0], 19, UI.MUTED, false)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		row.add_child(UI.label(l[1], 19, UI.TEXT, false))
		right.add_child(row)
	return h


# ---------------- Виклики й досягнення ----------------

static func _challenges(game) -> Control:
	var CS = game.ChallengeService
	var w = game.world
	var p = game.player
	var c: Dictionary = CS.state(w)
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
	col.add_child(UI.label("Нагорода: " + CS.reward_text(weekly, game.player.level), 15, UI.MUTED, false))
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


# ---------------- Спорядження ----------------

static func _gear(game) -> Control:
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = game.char_sel_uid

	var slots := VBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	slots.add_child(UI.label("Вдягнуто", 22, UI.GOLD, false))
	var sg := UI.grid(2)
	for slot in Data.SLOTS:
		if p.equipment.has(slot):
			var it: Dictionary = p.equipment[slot]
			sg.add_child(UI.item_button(it, _do(game, "select", it["uid"]), it["uid"] == sel, Data.SLOT_NAMES[slot]))
		else:
			sg.add_child(UI.empty_slot_button("%s\n—" % Data.SLOT_NAMES[slot]))
	slots.add_child(sg)
	h.add_child(slots)

	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", 6)
	bag.add_child(UI.label("Торба %d/%d" % [p.inventory.size(), p.bag_size()], 22, UI.GOLD, false))
	var bg := UI.grid(3)
	for it in p.inventory:
		bg.add_child(UI.item_button(it, _do(game, "select", it["uid"]), it["uid"] == sel))
	if p.inventory.is_empty():
		bag.add_child(UI.label("Порожньо. Речі падають з нечисті\nта продаються в містах.", 17, UI.MUTED, false))
	bag.add_child(bg)
	h.add_child(bag)

	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(330, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	var item: Dictionary = p.find_item(sel) if sel > 0 else {}
	if item.is_empty():
		det.add_child(UI.label("Торкнись речі,\nщоб побачити бонуси.", 20, UI.MUTED, false))
		det.add_child(UI.label("Заточувати речі можна\nу коваля в будь-якому місті.", 17, UI.MUTED, false))
		return h
	var equipped: bool = p.is_equipped(sel)
	var cmp: Dictionary = {} if equipped else p.equipment.get(item["slot"], {})
	det.add_child(UI.item_card(item, cmp))
	if equipped:
		det.add_child(UI.button("Зняти", _do(game, "unequip", sel), Vector2(300, 60), 24, not p.bag_full()))
	else:
		var usable: bool = p.can_use(item)
		if not usable:
			det.add_child(UI.label("Не для класу «%s»" % p.class_name_ua(), 18, UI.BAD, false))
		det.add_child(UI.button("Вдягнути", _do(game, "equip", sel), Vector2(300, 60), 24, usable))
		det.add_child(UI.button("Викинути", _do(game, "drop", sel), Vector2(300, 52), 20))
	return h


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


static func _skills(game) -> Control:
	var p = game.player
	var Classes = p.Classes
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var head := "%s — майстерність %d/%d" % [p.class_name_ua(), p.job_level, p.job_max()]
	if p.job_level < p.job_max():
		head += "   (досвід %d/%d)" % [p.job_xp, p.job_next()]
	v.add_child(UI.label(head, 24, UI.GOLD, false))
	v.add_child(UI.label("Очки вмінь: %d — по одному за кожен рівень майстерності. Активні вміння стають кнопками в бою (до 4) і коштують наснагу." % p.skill_points, 18, UI.GOLD if p.skill_points > 0 else UI.MUTED, false))
	if p.can_change_class():
		var names := []
		for c in p.class_info()["next"]:
			names.append("%s (%s)" % [Classes.CLASSES[c]["name"], {"sich": "Січ", "kapyshche": "Карпати"}.get(Classes.CLASSES[c].get("where", ""), "")])
		v.add_child(UI.label("Можна обирати нову дорогу: " + ", ".join(names) + ". Іди до наставника.", 19, UI.GOOD, false))
	_stones_row(game, v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	var branches: Array = Classes.TREES[p.job]
	var w := 320.0 if branches.size() <= 3 else 250.0
	if branches.size() == 1:
		w = 420.0
	for branch in branches:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(UI.label(branch["name"], 26, UI.GOLD))
		for n in branch["nodes"]:
			col.add_child(UI.connector())
			var rank: int = p.sk(n["id"])
			var req_met: bool = p.skill_req_met(n)
			var text := "%s   %d/%d\n%s" % [n["name"], rank, n["max"], n["desc"]]
			if not req_met:
				var reqs := []
				for r in n["req"]:
					if p.sk(r) < n["req"][r]:
						reqs.append("%s %d" % [Classes.find_node(r, p.job).get("name", r), n["req"][r]])
				text += "\nПотрібно: " + ", ".join(reqs)
			elif n.get("active", false):
				text += "\nАктивне • %d наснаги" % int(n.get("cost", 0))
			col.add_child(_tree_button(text, rank, n["max"], p.can_learn_skill(n), not req_met, 15, Vector2(w, 104), _do(game, "skill", n["id"])))
		h.add_child(col)
	# Вміння попередніх класів лишаються з героєм
	var earlier := []
	for c in Classes.lineage(p.job):
		if c == p.job:
			continue
		for b in Classes.TREES[c]:
			for n in b["nodes"]:
				if p.sk(n["id"]) > 0:
					earlier.append("%s %d" % [n["name"], p.sk(n["id"])])
	if not earlier.is_empty():
		v.add_child(UI.label("Набуте раніше: " + ", ".join(earlier), 17, UI.MUTED, false))
	return v


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
		row.add_child(UI.button(t, _do(game, "stone_reset"), Vector2(300, 52), 15))
	if a > 0:
		for cls in SS.siblings(p):
			var key: String = "stone_path:" + cls
			var nm: String = p.Classes.CLASSES[cls]["name"]
			var t: String = ("Алатир ×%d: стати «%s»" % [a, nm]) if game.confirm_action != key else "Точно «%s»? Ще раз" % nm
			row.add_child(UI.button(t, _do(game, "stone_path", cls), Vector2(290, 52), 15))
	v.add_child(row)
	if game.confirm_action != "":
		v.add_child(UI.label("Забуття повертає очки характеристик, Загартування й вмінь нинішнього класу. Алатир змінює дорогу: вміння старої забуваються з поверненням очок.", 15, UI.MUTED, false))


# ---------------- Загартування ----------------

static func _perks(game) -> Control:
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(UI.label("Очки Загартування: %d   (+1 за кожні %d рівні героя). Спільне для всіх класів. Новий ярус — за кожні %d очки в гілці." % [p.perk_points, p.Classes.HARDEN_EVERY, Data.PERK_TIER_STEP], 20, UI.GOLD if p.perk_points > 0 else UI.MUTED))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
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
				var w := 340.0 if tiers[ti].size() == 1 else 166.0
				row.add_child(_tree_button(text, rank, pk["max"], p.can_learn_perk(pk["id"]), not open, 14, Vector2(w, 88), _do(game, "perk", pk["id"])))
			col.add_child(row)
		h.add_child(col)
	return v
