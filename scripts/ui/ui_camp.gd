extends RefCounted
## Екран хутора: будівлі, кузня, зілляварня, пасіка. Дії йдуть через game.camp_do(дія, аргумент).

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const CampService := preload("res://scripts/game/camp_service.gd")
const AdRewards := preload("res://scripts/game/ad_rewards.gd")
const CraftService := preload("res://scripts/game/craft_service.gd")


static func _do(game, action: String, arg = null) -> Callable:
	return game.camp_do.bind(action, arg)


static func resources_text(p) -> String:
	return "%d грн • Дерево %d • Залізо %d • Трави %d • Трофеї %d" % [p.gold, p.resources.get("wood", 0), p.resources.get("iron", 0), p.resources.get("herbs", 0), p.resources.get("trophy", 0)]


static func build(game) -> Control:
	var w = game.world
	var pages := [["Будівлі", _buildings(game)], ["Скриня", _chest(game)]]
	if CampService.level(w, "kuznia") >= 1:
		pages.append(["Кузня", _forge(game)])
		pages.append(["Кування", _crafting(game)])
	if CampService.level(w, "zillia") >= 1:
		pages.append(["Зілляварня", _brewery(game)])
	if CampService.level(w, "pasika") >= 1:
		pages.append(["Пасіка", _pasika(game)])
	var pts: int = game.player.unspent_points()
	return UI.screen("Хутір • " + resources_text(game.player), "На мапу", game.leave_camp,
		pages, game.camp_tab, func(i: int): game.camp_tab = i,
		[[game.player.class_name_ua() + ((" +%d" % pts) if pts > 0 else ""), game.open_character]])


static func _cost_text(cost: Dictionary) -> String:
	var parts := ["%d грн" % cost["gold"]]
	for r in Camp.RESOURCES:
		if int(cost.get(r, 0)) > 0:
			parts.append("%s %d" % [Camp.RESOURCES[r], cost[r]])
	return ", ".join(parts)


static func _buildings(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Козак і загін відпочили. Ресурси (дерево, залізо, трави) падають з ворогів у місцевостях.", 17, UI.MUTED, false))
	_ad_row(game, v)
	for id in Camp.BUILD_ORDER:
		var b: Dictionary = Camp.BUILDINGS[id]
		var lvl := CampService.level(w, id)
		var mx := CampService.max_level(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s — рівень %d/%d" % [b["name"], lvl, mx], 22, UI.GOLD if lvl > 0 else UI.TEXT, false))
		info.add_child(UI.label(b["desc"], 15, UI.MUTED, false))
		for i in mx:
			var done := i < lvl
			info.add_child(UI.label(("✓ " if done else "• ") + b["levels"][i]["text"], 16, UI.GOOD if done else UI.MUTED, false))
		row.add_child(info)
		var cost := CampService.next_cost(w, id)
		if cost.is_empty():
			row.add_child(UI.button("Збудовано", func(): pass, Vector2(260, 64), 18, false))
		else:
			var txt := ("Збудувати" if lvl == 0 else "Покращити") + "\n" + _cost_text(cost)
			row.add_child(UI.button(txt, _do(game, "build", id), Vector2(260, 80), 15, CampService.can_afford(p, cost)))
		v.add_child(row)
	return v


static func _ad_row(game, v: VBoxContainer) -> void:
	var w = game.world
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := AdRewards.xp2_left(w)
	var l := UI.label(("×2 досвіду діє ще: %s" % AdRewards.format_time(left)) if left > 0.0 else "Подарунок спонсора: ×2 досвіду на годину гри", 18, UI.GOLD, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UI.button("Переглянути рекламу", _do(game, "ad_xp2"), Vector2(260, 56), 17, AdRewards.can_xp2(w)))
	v.add_child(row)


# ---------- Скриня (спільна на всіх персонажів) ----------

static func _chest(game) -> Control:
	var p = game.player
	var acc = game.account
	var w = game.world
	var sklad: int = CampService.level(w, "sklad")
	var size: int = acc.chest_size(sklad)
	var items: Array = acc.chest["items"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Спільна скриня: усе, що тут лежить, бачать усі твої персонажі. Склад на хуторі робить її більшою.", 16, UI.MUTED, false))
	# Гривні
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 8)
	var gl := UI.label("У скрині: %d грн   •   у тебе: %d грн" % [acc.chest["gold"], p.gold], 20, UI.GOLD, false)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.add_child(gl)
	for amt in [100, 1000]:
		grow.add_child(UI.button("↓%d" % amt, _do(game, "chest_put_gold", amt), Vector2(86, 44), 14, p.gold >= amt))
		grow.add_child(UI.button("↑%d" % amt, _do(game, "chest_take_gold", amt), Vector2(86, 44), 14, int(acc.chest["gold"]) >= amt))
	grow.add_child(UI.button("↓ усе", _do(game, "chest_put_gold", p.gold), Vector2(90, 44), 14, p.gold > 0))
	grow.add_child(UI.button("↑ усе", _do(game, "chest_take_gold", int(acc.chest["gold"])), Vector2(90, 44), 14, int(acc.chest["gold"]) > 0))
	v.add_child(grow)
	# Камені долі
	var SS = game.StoneService
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	for id in ["zabuttia", "alatyr"]:
		var mine: int = SS.count(p, id)
		var there: int = int(acc.chest["stones"].get(id, 0))
		srow.add_child(UI.label("%s: у скрині %d, у тебе %d" % [SS.NAMES[id], there, mine], 15, UI.TEXT, false))
		srow.add_child(UI.button("↓", _do(game, "chest_put_stone", id), Vector2(44, 40), 16, mine > 0))
		srow.add_child(UI.button("↑", _do(game, "chest_take_stone", id), Vector2(44, 40), 16, there > 0))
	v.add_child(srow)
	# Речі: дві колонки — скриня й торба
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UI.label("Скриня %d/%d  (торкнись — забрати)" % [items.size(), size], 20, UI.GOLD, false))
	var cg := UI.grid(3)
	for it in items:
		cg.add_child(UI.item_button(it, _do(game, "chest_take", it["uid"]), false, Data.SLOT_NAMES[it["slot"]]))
	if items.is_empty():
		left.add_child(UI.label("Порожньо.", 16, UI.MUTED, false))
	left.add_child(cg)
	h.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.label("Твоя торба %d/%d  (торкнись — покласти)" % [p.inventory.size(), p.bag_size()], 20, UI.GOLD, false))
	var bg := UI.grid(3)
	for it in p.inventory:
		bg.add_child(UI.item_button(it, _do(game, "chest_put", it["uid"]), false, Data.SLOT_NAMES[it["slot"]]))
	if p.inventory.is_empty():
		right.add_child(UI.label("Порожньо.", 16, UI.MUTED, false))
	right.add_child(bg)
	h.add_child(right)
	v.add_child(h)
	if game.smith_msg != "":
		v.add_child(UI.label(game.smith_msg, 18, game.smith_msg_color, false))
	return v


# ---------- Кузня ----------

static func _forge(game) -> Control:
	var w = game.world
	var p = game.player
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var sel: int = game.camp_sel_uid
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
	det.custom_minimum_size = Vector2(380, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	var bonus := "Своя кузня: заточка на %d%% дешевше" % roundi((1.0 - CampService.forge_cost_mult(w)) * 100)
	if CampService.forge_chance_bonus(w) > 0.0:
		bonus += ", шанс +%d%%" % roundi(CampService.forge_chance_bonus(w) * 100)
	det.add_child(UI.label(bonus, 16, UI.GOOD, false))
	det.add_child(UI.label("Безпечних заточок: %d (рівень не падає при невдачі)" % AdRewards.safe_tokens(w), 16, UI.TEXT, false))
	det.add_child(UI.button("Реклама: +1 безпечна заточка (сьогодні ще %d)" % AdRewards.safe_left_today(w), _do(game, "ad_safe"), Vector2(370, 52), 15, AdRewards.safe_left_today(w) > 0))
	var it: Dictionary = p.find_item(sel) if sel > 0 else {}
	if it.is_empty():
		det.add_child(UI.label("Обери річ.", 20, UI.MUTED, false))
		return h
	det.add_child(UI.item_card(it))
	if it["up"] < Data.MAX_UPGRADE:
		var cost := int(Data.sharpen_cost(it) * CampService.forge_cost_mult(w))
		var chance := minf(1.0, Data.sharpen_chance(it) + CampService.forge_chance_bonus(w))
		var risk := ""
		if it["up"] >= Data.SHARPEN_RISK_FROM:
			risk = "  без ризику" if AdRewards.safe_tokens(w) > 0 else "  ризик -1"
		det.add_child(UI.button("Заточити до +%d\n%d грн • шанс %d%%%s" % [it["up"] + 1, cost, roundi(chance * 100), risk], _do(game, "sharpen", sel), Vector2(370, 80), 19, p.gold >= cost))
	if CampService.level(w, "kuznia") >= 2 and not p.is_equipped(sel):
		det.add_child(UI.button("Переплавити на залізо (+%d)" % CampService.salvage_value(it), _do(game, "salvage", sel), Vector2(370, 56), 18))
	_craft_item_actions(game, det, it)
	if game.smith_msg != "":
		det.add_child(UI.label(game.smith_msg, 20, game.smith_msg_color, false))
	return h


static func _craft_cost_text(cost: Dictionary) -> String:
	var parts := ["%d грн" % int(cost.get("gold", 0))]
	for r in ["iron", "wood", "herbs", "trophy"]:
		if int(cost.get(r, 0)) > 0:
			parts.append("%s %d" % [Camp.res_name(r), cost[r]])
	return ", ".join(parts)


## Перекування властивостей і оновлення до свого рівня (для вибраної речі в кузні).
static func _craft_item_actions(game, det: VBoxContainer, it: Dictionary) -> void:
	var w = game.world
	var p = game.player
	if CraftService.can_reforge(w, it):
		var cost := CraftService.reforge_cost(it)
		det.add_child(UI.label("Перекувати властивість (%s):" % _craft_cost_text(cost), 16, UI.MUTED, false))
		for a in it["affixes"]:
			var fmt: Array = Data.STAT_FMT[a]
			var txt: String = fmt[0] % (("%." + str(fmt[1]) + "f") % it["affixes"][a])
			det.add_child(UI.button("↻ " + txt, _do(game, "reforge", [it["uid"], a]), Vector2(370, 46), 15, CraftService.can_pay(p, cost)))
	if CraftService.can_renew(w, it, p.level):
		var rc := CraftService.renew_cost(it, p.level)
		det.add_child(UI.button("Оновити до рівня %d\n%s" % [p.level, _craft_cost_text(rc)], _do(game, "renew", it["uid"]), Vector2(370, 70), 15, CraftService.can_pay(p, rc)))


# ---------- Кування ----------

static func _crafting(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Викуй річ свого рівня (%d) потрібного виду. Трофеї дають еліти, боси й виграні облоги." % p.level, 17, UI.MUTED, false))
	var tier: int = game.craft_tier
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 10)
	for t in range(1, 4):
		var open := CraftService.tier_open(w, t)
		var label: String = ("▸ " if t == tier else "") + CraftService.TIER_NAMES[t] + ("" if open else "\n(кузня %d)" % CraftService.TIER_KUZNIA[t])
		var b := UI.button(label, _do(game, "craft_tier", t), Vector2(220, 60), 17, open)
		if t == tier:
			b.modulate = Data.RARITY_COLORS[t].lightened(0.3)
		tiers.add_child(b)
	v.add_child(tiers)
	var grid := UI.grid(2)
	for r in CraftService.RECIPES:
		var cost := CraftService.forge_cost(r[0], tier, p.level)
		var ok: bool = CraftService.tier_open(w, tier) and CraftService.can_pay(p, cost) and p.inventory.size() < p.bag_size()
		var txt := "%s — %s\n%s" % [CraftService.recipe_name(r[0], r[1]), CraftService.TIER_NAMES[tier].to_lower(), _craft_cost_text(cost)]
		var b := UI.button(txt, _do(game, "craft", r), Vector2(520, 66), 15, ok)
		grid.add_child(b)
	v.add_child(grid)
	if p.inventory.size() >= p.bag_size():
		v.add_child(UI.label("Торба повна — звільни місце.", 18, UI.BAD, false))
	if game.smith_msg != "":
		v.add_child(UI.label(game.smith_msg, 20, game.smith_msg_color, false))
	return v


# ---------- Зілляварня ----------

static func _brewery(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(UI.label("Трави: %d  •  Залізо: %d  •  Зілля здоров'я: %d/%d" % [p.resources.get("herbs", 0), p.resources.get("iron", 0), p.potions, p.potion_max()], 20, UI.TEXT, false))
	v.add_child(UI.label("Зілля «на похід» випивається одразу й діє до кінця наступного походу.", 16, UI.MUTED, false))
	for id in Camp.BREW:
		var r: Dictionary = Camp.BREW[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var locked: bool = CampService.level(w, "zillia") < int(r["level"])
		info.add_child(UI.label(r["name"] + ("  (діє на наступний похід)" if p.trip_buffs.has(id) else ""), 21, UI.GOOD if p.trip_buffs.has(id) else UI.TEXT, false))
		info.add_child(UI.label(r["desc"] + ("  •  потрібна зілляварня %d рівня" % r["level"] if locked else ""), 15, UI.BAD if locked else UI.MUTED, false))
		row.add_child(info)
		var cost := "трави %d" % r["herbs"] + ((", залізо %d" % r["iron"]) if int(r["iron"]) > 0 else "")
		row.add_child(UI.button("Зварити\n" + cost, _do(game, "brew", id), Vector2(220, 70), 17, CampService.can_brew(w, p, id)))
		v.add_child(row)
	return v


# ---------- Пасіка ----------

static func _pasika(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var ready := CampService.pasika_ready(w, p.level)
	v.add_child(UI.label("Пасіка %d рівня: %d грн на годину (накопичується до %d годин, навіть коли гра закрита)" % [CampService.level(w, "pasika"), roundi(CampService.pasika_rate(w, p.level)), roundi(Camp.PASIKA_CAP_HOURS)], 19, UI.TEXT, false))
	v.add_child(UI.label("Готово до збору: %d грн" % ready, 26, UI.GOLD, false))
	v.add_child(UI.button("Зібрати мед і продати", _do(game, "collect"), Vector2(360, 70), 22, ready > 0))
	return v
