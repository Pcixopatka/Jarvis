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
		["Перки" + _pts(p.perk_points), _perks(game)],
	]
	return UI.screen("Козак — рівень %d   •   Гривні: %d" % [p.level, p.gold], "Назад", game.close_character,
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
	bag.add_child(UI.label("Торба %d/%d" % [p.inventory.size(), Data.INVENTORY_SIZE], 22, UI.GOLD, false))
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
		det.add_child(UI.button("Вдягнути", _do(game, "equip", sel), Vector2(300, 60), 24))
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(UI.label("Очки вмінь: %d   (+%d за рівень).  Активні вміння з'являються кнопками в бою." % [p.skill_points, Data.SKILL_POINTS_PER_LEVEL], 21, UI.GOLD if p.skill_points > 0 else UI.MUTED))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	for branch in Data.SKILL_BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(UI.label(branch["name"], 28, UI.GOLD))
		var nodes: Array = branch["nodes"]
		for i in nodes.size():
			var n: Dictionary = nodes[i]
			col.add_child(UI.connector())
			var rank: int = p.sk(n["id"])
			var req_met: bool = p.skill_req_met(n)
			var text := "%s   %d/%d\n%s" % [n["name"], rank, n["max"], n["desc"]]
			if not req_met:
				var reqs := []
				for r in n["req"]:
					if p.sk(r) < n["req"][r]:
						reqs.append("%s %d" % [Data.skill_name(r), n["req"][r]])
				text += "\nПотрібно: " + ", ".join(reqs)
			elif n.get("active", false):
				text += "\nАктивне вміння"
			col.add_child(_tree_button(text, rank, n["max"], p.can_learn_skill(n), not req_met, 17, Vector2(320, 120), _do(game, "skill", n["id"])))
		h.add_child(col)
	return v


# ---------------- Перки ----------------

static func _perks(game) -> Control:
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(UI.label("Очки перків: %d   (+%d за рівень).  Новий ярус відкривається за кожні %d очки, вкладені в гілку." % [p.perk_points, Data.PERK_POINTS_PER_LEVEL, Data.PERK_TIER_STEP], 21, UI.GOLD if p.perk_points > 0 else UI.MUTED))
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
