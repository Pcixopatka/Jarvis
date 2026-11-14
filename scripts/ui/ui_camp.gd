extends RefCounted
## Екран хутора: будівлі, кузня, зілляварня, пасіка. Дії йдуть через game.camp_do(дія, аргумент).

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const CampService := preload("res://scripts/game/camp_service.gd")
const AdRewards := preload("res://scripts/game/ad_rewards.gd")
const CraftService := preload("res://scripts/game/craft_service.gd")
const Acts := preload("res://scripts/data/activities.gd")
const OutdoorService := preload("res://scripts/game/outdoor_service.gd")
const GardenService := preload("res://scripts/game/garden_service.gd")
const KleinodService := preload("res://scripts/game/kleinod_service.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const Pets := preload("res://scripts/data/pets.gd")
const PetService := preload("res://scripts/game/pet_service.gd")
const Enchants := preload("res://scripts/data/enchants.gd")
const EnchantService := preload("res://scripts/game/enchant_service.gd")
const FairService := preload("res://scripts/game/fair_service.gd")
const GameDB := preload("res://scripts/core/game_db.gd")


static func _do(game, action: String, arg = null) -> Callable:
	return game.camp_do.bind(action, arg)


static func resources_text(p) -> String:
	return "%s грн • Дерево %d • Залізо %d • Трави %d • Трофеї %d" % [UI.num(p.gold), p.resources.get("wood", 0), p.resources.get("iron", 0), p.resources.get("herbs", 0), p.resources.get("trophy", 0)]


static func build(game) -> Control:
	var w = game.world
	# Вкладки будуються ліниво: функція викликається лише для відкритої (UI.screen).
	var pages := [["Будівлі", func(): return _buildings(game)], ["Скриня", func(): return _chest(game)]]
	if CampService.level(w, "kuznia") >= 1:
		pages.append(["Кузня", func(): return _forge(game)])
		pages.append(["Кування", func(): return _crafting(game)])
	if CampService.level(w, "zillia") >= 1:
		pages.append(["Зілляварня", func(): return _brewery(game)])
	if CampService.level(w, "pasika") >= 1:
		pages.append(["Пасіка", func(): return _pasika(game)])
	if GardenService.level(w) >= 1:
		var ripe := GardenService.ready_count(w)
		pages.append(["Город" + ((" (%d)" % ripe) if ripe > 0 else ""), func(): return _garden(game)])
	pages.append(["Казан", func(): return _kazan(game)])
	pages.append(["Клейноди", func(): return _kleinody(game)])
	pages.append(["Стайня", func(): return _pets(game)])
	if FairService.unlocked(game.player):
		pages.append(["Ярмарок", func(): return _fair(game)])
	var pts: int = game.player.unspent_points()
	return UI.screen("Хутір • " + resources_text(game.player), "На мапу", game.leave_camp,
		pages, game.camp_tab, game.camp_tab_changed,
		[["Персонаж" + ((" +%d" % pts) if pts > 0 else ""), game.open_character]])


static func _cost_text(cost: Dictionary) -> String:
	var parts := ["%d грн" % cost["gold"]]
	for r in Camp.resources():
		if int(cost.get(r, 0)) > 0:
			parts.append("%s %d" % [Camp.res_name(r), cost[r]])
	return ", ".join(parts)


static func _buildings(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Козак і загін відпочили. Ресурси (дерево, залізо, трави) падають з ворогів у місцевостях.", 17, UI.MUTED, false))
	_ad_row(game, v)
	for id in Camp.building_ids():
		var b: Dictionary = Camp.building(id)
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
	var texts := {"xp2": "×2 досвіду на годину гри", "drop2": "×2 здобичі на годину гри: удвічі частіше речі й ресурси"}
	if AdRewards.Premium.active(w):
		var pl := UI.label("%s: ×2 досвіду й ×2 здобичі діють постійно, реклама не потрібна. Лишилось днів: %d" % [AdRewards.Premium.NAME, AdRewards.Premium.days_left(w)], 18, UI.GOLD, false)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)
		return
	for id in ["xp2", "drop2"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var left := AdRewards.boost_left(w, id)
		var txt: String = ("%s діє ще: %s" % [AdRewards.BOOST_NAMES[id], AdRewards.format_time(left)]) if left > 0.0 else "Подарунок спонсора: " + texts[id]
		var l := UI.label(txt, 18, UI.GOLD, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.button("Переглянути рекламу", _do(game, "ad_" + id), Vector2(260, 56), 17, AdRewards.can_boost(w, id)))
		v.add_child(row)


# ---------- Клейноди роду й скарбник ----------

static func _kleinody(game) -> Control:
	var w = game.world
	var p = game.player
	var mx := KleinodService.max_level()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Клейноди роду: козацькі регалії. Кожен ступінь назавжди додає бонус усім твоїм героям.", 17, UI.MUTED, false))
	v.add_child(UI.label("Майстри беруть гривні, трофеї й ресурси. Оздоблено ступенів: %d із %d." % [KleinodService.total(w), Camp.kleinod_ids().size() * mx], 17, UI.GOLD, false))
	for id in Camp.kleinod_ids():
		var K: Dictionary = Camp.kleinod(id)
		var lvl := KleinodService.level(w, id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(UI.icon("kl_" + id, 64))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s — ступінь %d/%d" % [K["name"], lvl, mx], 22, UI.GOLD if lvl > 0 else UI.TEXT, false))
		info.add_child(UI.label(K["desc"], 15, UI.MUTED, false))
		if lvl > 0:
			info.add_child(UI.label("Зараз: " + KleinodService.bonus_text(id, lvl), 16, UI.GOOD, false))
		if lvl < mx:
			info.add_child(UI.label("Наступний ступінь: " + KleinodService.bonus_text(id, lvl + 1), 16, UI.TEXT if lvl > 0 else UI.GOOD, false))
		row.add_child(info)
		var cost := KleinodService.cost(w, id)
		if cost.is_empty():
			row.add_child(UI.button("Досконалий", func(): pass, Vector2(330, 64), 18, false))
		else:
			var txt := ("Здобути" if lvl == 0 else "Оздобити") + "\n" + KleinodService.cost_text(cost)
			row.add_child(UI.button(txt, _do(game, "kleinod", id), Vector2(330, 84), 15, KleinodService.can_buy(w, p, id)))
		v.add_child(row)
	# Скарбник: камені долі за гривні
	v.add_child(UI.label("Скарбник", 22, UI.GOLD, false))
	v.add_child(UI.label("Камені долі рідко падають із босів. Скарбник дістане їх за гривні будь-коли.", 15, UI.MUTED, false))
	for id in GameDB.ids("stones"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(UI.icon("stone_" + id, 64))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s — у тебе %d" % [StoneService.name_of(id), StoneService.count(p, id)], 22, UI.TEXT, false))
		info.add_child(UI.label(GameDB.row("stones", id)["text"], 15, UI.MUTED, false))
		row.add_child(info)
		var price := KleinodService.stone_price(id)
		row.add_child(UI.button("Купити\n%s грн" % UI.num(price), _do(game, "buy_stone", id), Vector2(330, 72), 16, p.gold >= price))
		v.add_child(row)
	return v


# ---------- Скриня (спільна на всіх персонажів) ----------

const CHEST_CELL := 66  # клітинка скрині й торби на вкладці «Скриня»
const CHEST_COLS := 6
const CHEST_TAKE := "Забрати в торбу"
const CHEST_PUT := "Покласти до скрині"

static func _chest(game) -> Control:
	var p = game.player
	var acc = game.account
	var w = game.world
	var size: int = acc.chest_size(w)
	var items: Array = acc.chest["items"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Спільна скриня: усе, що тут лежить, бачать усі твої персонажі. Склад на хуторі й Чумацький віз роблять її більшою.", 16, UI.MUTED, false))
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
	for id in GameDB.ids("stones"):
		var mine: int = SS.count(p, id)
		var there: int = int(acc.chest["stones"].get(id, 0))
		srow.add_child(UI.label("%s: у скрині %d, у тебе %d" % [SS.name_of(id), there, mine], 15, UI.TEXT, false))
		srow.add_child(UI.button("↓", _do(game, "chest_put_stone", id), Vector2(44, 40), 16, mine > 0))
		srow.add_child(UI.button("↑", _do(game, "chest_take_stone", id), Vector2(44, 40), 16, there > 0))
	v.add_child(srow)
	# Речі: скриня й торба сіткою значків, як інвентар героя, і картка вибраної речі праворуч.
	# Перший дотик показує річ, другий по тій самій клітинці переносить її.
	var sel: String = game.chest_sel
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.add_child(UI.label("Скриня %d/%d" % [items.size(), size], 20, UI.GOLD, false))
	var cg := UI.grid(CHEST_COLS)
	var picked: Dictionary = {}
	for it in items:
		var key := "c:%d" % int(it["uid"])
		if key == sel:
			picked = it
		cg.add_child(UI.item_cell(it, _do(game, "chest_take", it["uid"]) if key == sel else _do(game, "chest_select", key), key == sel, CHEST_CELL))
	for i in maxi(0, size - items.size()):
		cg.add_child(UI.empty_cell(CHEST_CELL))
	left.add_child(cg)
	h.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.add_child(UI.label("Твоя торба %d/%d" % [p.inventory.size(), p.bag_size()], 20, UI.GOLD, false))
	var bg := UI.grid(CHEST_COLS)
	for it in p.inventory:
		var key := "b:%d" % int(it["uid"])
		if key == sel:
			picked = it
		bg.add_child(UI.item_cell(it, _do(game, "chest_put", it["uid"]) if key == sel else _do(game, "chest_select", key), key == sel, CHEST_CELL))
	for i in maxi(0, p.bag_size() - p.inventory.size()):
		bg.add_child(UI.empty_cell(CHEST_CELL))
	right.add_child(bg)
	h.add_child(right)
	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(300, 0)
	det.add_theme_constant_override("separation", 8)
	h.add_child(det)
	if picked.is_empty():
		det.add_child(UI.label("Торкнись речі,\nщоб побачити бонуси.", 20, UI.MUTED, false))
		det.add_child(UI.label("Другий дотик по тій самій\nклітинці переносить річ:\nзі скрині в торбу або назад.", 15, UI.MUTED, false))
	else:
		det.add_child(UI.item_card(picked))
		if sel.begins_with("c:"):
			det.add_child(UI.button(CHEST_TAKE, _do(game, "chest_take", picked["uid"]), Vector2(290, 58), 20, not p.bag_full()))
		else:
			det.add_child(UI.button(CHEST_PUT, _do(game, "chest_put", picked["uid"]), Vector2(290, 58), 20, not acc.chest_full(w) and not p.is_equipped(picked["uid"])))
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
			continue  # артефакти не точать і не переплавляють
		bg.add_child(UI.item_cell(it, _do(game, "select", it["uid"]), it["uid"] == sel, 66))
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
	det.add_child(UI.button(AdRewards.safe_button_text(w), _do(game, "ad_safe"), Vector2(370, 52), 15, AdRewards.safe_left_today(w) > 0))
	var it: Dictionary = p.find_item(sel) if sel > 0 else {}
	if it.is_empty():
		det.add_child(UI.label("Обери річ.", 20, UI.MUTED, false))
		return h
	det.add_child(UI.item_card(it))
	if it["up"] < Data.MAX_UPGRADE:
		var cost := int(Data.sharpen_cost(it) * CampService.forge_cost_mult(w))
		var chance := minf(1.0, Data.sharpen_chance(it) + CampService.forge_chance_bonus(w) + game.HolidayService.bonus("sharpen"))
		var risk := ""
		if it["up"] >= Data.SHARPEN_RISK_FROM:
			risk = "  без ризику" if AdRewards.safe_tokens(w) > 0 else "  ризик -1"
		det.add_child(UI.button("Заточити до +%d\n%d грн • шанс %d%%%s" % [it["up"] + 1, cost, roundi(chance * 100), risk], _do(game, "sharpen", sel), Vector2(370, 80), 19, p.gold >= cost))
		if it["up"] >= Data.SHARPEN_RISK_FROM and AdRewards.safe_tokens(w) <= 0:
			var safe_cost := Data.sharpen_safe_cost(it, CampService.forge_cost_mult(w))
			det.add_child(UI.button("Заточити без ризику\n%s грн • рівень не впаде" % UI.num(safe_cost), _do(game, "sharpen_safe", sel), Vector2(370, 72), 17, p.gold >= safe_cost))
	else:
		# Заточено до краю: на місці кнопок заточки лишається неактивна кнопка того самого розміру
		# (і порожнє місце замість «без ризику»), щоб наступний дотик туди нічого не зробив.
		det.add_child(sharpen_done_button(it, Vector2(370, 80), 19))
		if AdRewards.safe_tokens(w) <= 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(370, 72)
			det.add_child(gap)
	_craft_item_actions(game, det, it)
	_enchant_block(game, det, it)
	det.add_child(load("res://scripts/ui/ui_souls.gd").block(p, it, func(a: String, b): return _do(game, a, b), true, CampService.forge_cost_mult(w)))
	if game.smith_msg != "":
		det.add_child(UI.label(game.smith_msg, 20, game.smith_msg_color, false))
	# Переплавка в самому низу, подалі від заточки; цінна річ плавиться з другого дотику
	if CampService.level(w, "kuznia") >= 2 and not p.is_equipped(sel):
		var sure: bool = game.confirm_action == "salvage:%d" % sel
		var sb := UI.button(("Точно переплавити?\nНатисни ще раз (+%d заліза)" if sure else "Переплавити на залізо (+%d)") % CampService.salvage_value(it),
			_do(game, "salvage", sel), Vector2(370, 56), 17 if sure else 18)
		if sure:
			sb.modulate = UI.BAD
		det.add_child(sb)
	return h


## Неактивна кнопка на місці «Заточити», коли річ уже заточена до краю.
static func sharpen_done_button(it: Dictionary, size: Vector2, font: int) -> Button:
	return UI.button("Заточено до краю: +%d" % int(it["up"]), func(): pass, size, font, false)


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
			var txt: String = Data.stat_text(a) % (("%." + str(Data.stat_decimals(a)) + "f") % it["affixes"][a])
			det.add_child(UI.button("↻ " + txt, _do(game, "reforge", [it["uid"], a]), Vector2(370, 46), 15, CraftService.can_pay(p, cost)))
	if CraftService.can_renew(w, it, p.level):
		# кожен рівень речі коштує окремо й дорожче за попередній: можна підняти на один або одразу до свого
		var next_lvl: int = int(it["ilvl"]) + 1
		var one := CraftService.renew_cost(it, next_lvl)
		det.add_child(UI.label("Оновлення: рівень речі %d, твій %d. Кожен наступний рівень дорожчий." % [int(it["ilvl"]), p.level], 14, UI.MUTED, false))
		det.add_child(UI.button("Оновити на один рівень, до %d\n%s" % [next_lvl, _craft_cost_text(one)], _do(game, "renew_one", it["uid"]), Vector2(370, 70), 15, CraftService.can_pay(p, one)))
		if next_lvl < p.level:
			var rc := CraftService.renew_cost(it, p.level)
			det.add_child(UI.button("Оновити до свого рівня %d\n%s" % [p.level, _craft_cost_text(rc)], _do(game, "renew", it["uid"]), Vector2(370, 70), 15, CraftService.can_pay(p, rc)))


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
		var label: String = ("▸ " if t == tier else "") + CraftService.tier_name(t) + ("" if open else "\n(кузня %d)" % int(CraftService.forge_tier(t)["kuznia"]))
		var b := UI.button(label, _do(game, "craft_tier", t), Vector2(220, 60), 17, open)
		if t == tier:
			b.modulate = Data.rarity_color(t).lightened(0.3)
		tiers.add_child(b)
	v.add_child(tiers)
	var grid := UI.grid(2)
	for r in CraftService.RECIPES:
		var cost := CraftService.forge_cost(r[0], tier, p.level)
		var ok: bool = CraftService.tier_open(w, tier) and CraftService.can_pay(p, cost) and p.inventory.size() < p.bag_size()
		var txt := "%s — %s\n%s" % [CraftService.recipe_name(r[0], r[1]), CraftService.tier_name(tier).to_lower(), _craft_cost_text(cost)]
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
	v.add_child(UI.label("Трави: %d  •  Залізо: %d  •  Зілля здоров'я: %d/%d  •  Зілля наснаги: %d/%d" % [p.resources.get("herbs", 0), p.resources.get("iron", 0), p.potions, p.potion_max(), p.mana_potions, p.mana_potion_max()], 20, UI.TEXT, false))
	v.add_child(UI.label("Зілля сили й проти зарази випивається одразу й діє %d хвилин бою. Час іде лише в бою. Ще одна порція додає час, запас до години." % int(Data.BREW_TIME / 60.0), 16, UI.MUTED, false))
	for id in Camp.brew_ids():
		var r: Dictionary = Camp.brew(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var locked: bool = CampService.level(w, "zillia") < int(r["level"])
		var timed: bool = not (id in ["heal", "mana"])
		var brewed: bool = timed and p.trip_buffs.has(id)
		info.add_child(UI.label(r["name"] + (("  (діє ще %s)" % buff_time(p.buff_left(id))) if brewed else ""), 21, UI.GOOD if brewed else UI.TEXT, false))
		var desc: String = r["desc"] + ((" на %d хв бою" % int(Data.BREW_TIME / 60.0)) if timed else "")
		info.add_child(UI.label(desc + ("  •  потрібна зілляварня %d рівня" % r["level"] if locked else ""), 15, UI.BAD if locked else UI.MUTED, false))
		row.add_child(info)
		var cost := "трави %d" % r["herbs"] + ((", залізо %d" % r["iron"]) if int(r["iron"]) > 0 else "")
		row.add_child(UI.button("Зварити\n" + cost, _do(game, "brew", id), Vector2(220, 70), 17, CampService.can_brew(w, p, id)))
		v.add_child(row)
	return v


# ---------- Город ----------

static func _garden(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(UI.label("Грядки ростуть самі, навіть коли гра закрита. Город спільний для всіх твоїх персонажів.", 16, UI.MUTED, false))
	v.add_child(food_row(p))
	if GardenService.ready_count(w) > 1:
		var all := UI.button("Зібрати все достигле", _do(game, "harvest_all"), Vector2(360, 60), 20)
		all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(all)
	for i in GardenService.beds_count(w):
		var b: Dictionary = GardenService.bed(w, i)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.style(Color(0.16, 0.13, 0.09), Color(0.45, 0.36, 0.2), 10, 10))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if b.is_empty():
			info.add_child(UI.label("Грядка %d: порожня" % (i + 1), 21, UI.TEXT, false))
			info.add_child(UI.label("Обери, що посадити. Насіння коштує кілька гривень.", 15, UI.MUTED, false))
			for crop in Camp.crop_ids():
				var c: Dictionary = Camp.crop(crop)
				var txt := "%s\n%s, %d грн" % [c["name"], GardenService.time_text(int(GardenService.grow_time(w, crop))), int(c["seed"])]
				row.add_child(UI.button(txt, _do(game, "plant", [i, crop]), Vector2(200, 70), 15, GardenService.can_plant(w, p, i, crop)))
		else:
			var c2: Dictionary = Camp.crop(b["crop"])
			var ripe2 := GardenService.ready(w, i)
			var gives: String = ("+%d грн" % GardenService.yield_of(b["crop"], p.level)) if c2["gives"] == "gold" else str(c2["desc"])
			info.add_child(UI.icon_text("khmil" if b["crop"] == "khmil" else str(b["crop"]), "Грядка %d: %s%s" % [i + 1, c2["name"], "  — достигло!" if ripe2 else ""], 21, UI.GOOD if ripe2 else UI.TEXT))
			var bar := ProgressBar.new()
			bar.min_value = 0.0
			bar.max_value = 1.0
			bar.value = GardenService.progress(w, i)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 14)
			bar.add_theme_stylebox_override("background", UI.style(Color(0.08, 0.07, 0.05), Color(0.3, 0.25, 0.15), 6, 0))
			bar.add_theme_stylebox_override("fill", UI.style(Color(0.35, 0.7, 0.3) if not ripe2 else Color(0.95, 0.8, 0.3), Color(0, 0, 0, 0), 6, 0))
			info.add_child(bar)
			info.add_child(UI.label(("Урожай: %s" % gives) if ripe2 else "Достигне за %s  •  урожай: %s" % [GardenService.time_text(GardenService.time_left(w, i)), gives], 15, UI.MUTED, false))
			if ripe2:
				row.add_child(UI.button("Зібрати", _do(game, "harvest", i), Vector2(200, 70), 20))
			else:
				row.add_child(UI.button("Викорчувати", _do(game, "uproot", i), Vector2(200, 60), 16))
		v.add_child(box)
	if GardenService.level(w) < CampService.max_level("horod"):
		v.add_child(UI.label("Більше грядок дасть наступний рівень городу (вкладка «Будівлі»).", 15, UI.MUTED, false))
	return v


# ---------- Казан: страви зі здобичі ----------

## Запас провіанту значками: м'ясо, риба, городина, трави.
static func food_row(p, extra: Array = []) -> Control:
	var items := []
	for id in Camp.food_ids():
		items.append([id, "%s: %d" % [Camp.res_name(id), OutdoorService.food(p, id)]])
	items.append(["herbs", "Трави: %d" % int(p.resources.get("herbs", 0))])
	items.append_array(extra)
	return UI.icon_row(items, 19)


static func food_text(p) -> String:
	var parts := []
	for id in Camp.food_ids():
		parts.append("%s: %d" % [Camp.res_name(id), OutdoorService.food(p, id)])
	parts.append("Трави: %d" % int(p.resources.get("herbs", 0)))
	return "  •  ".join(parts)


static func _need_text(need: Dictionary) -> String:
	var parts := []
	for r in need:
		var nm: String = Camp.res_name(r).to_lower()
		parts.append("%s %d" % [nm, int(need[r])])
	return ", ".join(parts)


static func _kazan(game) -> Control:
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(food_row(p))
	var about := UI.label("М'ясо добувають на полюванні, рибу — на рибальській тоні, городина росте на городі. Страва діє %d хвилин бою: час іде лише в бою. Та сама страва ще раз додає час (запас до години), інша замінює попередню." % int(Data.MEAL_TIME / 60.0), 16, UI.MUTED, false)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(about)
	var now := OutdoorService.eaten(p)
	for id in GameDB.ids("recipes"):
		var r: Dictionary = GameDB.row("recipes", id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(r["name"] + (("  (діє ще %s)" % buff_time(p.buff_left("food"))) if now == id else ""), 21, UI.GOOD if now == id else UI.TEXT, false))
		info.add_child(UI.label("%s на %d хв бою" % [r["desc"], int(Data.MEAL_TIME / 60.0)], 15, UI.MUTED, false))
		row.add_child(info)
		row.add_child(UI.button("Зварити\n" + _need_text(r["need"]), _do(game, "cook", id), Vector2(260, 70), 16, OutdoorService.can_cook(p, id)))
		v.add_child(row)
	return v


## Залишок підсилення словами: «12 хв», «40 с».
static func buff_time(secs: float) -> String:
	return "%d хв" % ceili(secs / 60.0) if secs >= 60.0 else "%d с" % ceili(secs)


# ---------- Пасіка ----------

## Зачарування вибраної речі: одна особлива властивість на вибір, нове замінює старе.
static func _enchant_block(game, det: VBoxContainer, it: Dictionary) -> void:
	if not EnchantService.can_enchant(it):
		return
	var p = game.player
	var cost: Dictionary = Enchants.cost(it)
	var strong := ", на цій речі в %s сильніше" % "півтора раза" if Enchants.mult(it) > 1.0 else ""
	var hl := UI.label("Зачарувати (%s)%s. Нове замінює старе:" % [EnchantService.cost_text(cost), strong], 16, UI.MUTED, false)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size = Vector2(360, 0)
	det.add_child(hl)
	for id in Enchants.options(it):
		var on: bool = EnchantService.of(it) == id
		var txt := "%s%s\n%s" % ["✧ " if on else "", Enchants.def(id)["name"], game.player.Classes.fx_text(Enchants.fx_of(it, id))]
		var b := UI.button(txt, _do(game, "enchant", [it["uid"], id]), Vector2(370, 58), 15, EnchantService.block_reason(p, it, id) == "")
		if on:
			b.modulate = Color(0.85, 0.75, 1.0)
		det.add_child(b)


## Трофейний ярмарок: тижневий товар скупника за трофеї й гривні.
const FAIR_BUY := "Виміняти"
const FAIR_ICONS := {"safe": "kl_pechatka", "zabuttia": "stone_zabuttia", "alatyr": "stone_alatyr"}

## Ярмарок: товари скупника сіткою значків, як торба героя. Під значком ціна в трофеях,
## дотик показує картку товару праворуч із кнопкою «Виміняти».
static func _fair(game) -> Control:
	var w = game.world
	var p = game.player
	var UShop = load("res://scripts/ui/ui_shop.gd")
	var Uniq = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var grid := UI.grid(UShop.COLS)
	var picked: Dictionary = {}
	for e in FairService.stock(p):
		var key: String = str(e["key"])
		var col: Color = UI.GOLD
		var mark := ""
		var icon: Control = null
		match str(e["kind"]):
			"unique":
				var D: Dictionary = Uniq.def(e["id"])
				col = Data.rarity_color(Uniq.RARITY)
				mark = "★"
				icon = UI.icon(UI.item_icon_id({"slot": D["slot"], "type": Uniq.type_of(str(e["id"]))}), UShop.CELL)
			"artifact":
				col = Data.rarity_color(Arts.RARITY)
				mark = "◆"
				icon = UI.artifact_icon(str(e["id"]), UShop.CELL)
			_:
				icon = UI.icon(str(FAIR_ICONS.get(str(e["id"]), "trophy")), UShop.CELL)
		if key == game.fair_sel:
			picked = e
		grid.add_child(UI.goods_cell(icon, col, _do(game, "fair_select", key), key == game.fair_sel, UShop.CELL, str(int(e["trophy"])), mark,
			FairService.bought(w, key) >= int(e["limit"])))
	var det := VBoxContainer.new()
	det.add_theme_constant_override("separation", 6)
	if picked.is_empty():
		det.add_child(UI.label("Торкнись товару,\nщоб побачити,\nщо він дає.", 20, UI.MUTED, false))
		det.add_child(UI.label("Число під значком: ціна\nв трофеях. Галочка:\nцього тижня вже взято.", 15, UI.MUTED, false))
	else:
		var sub := ""
		var text := ""
		var col: Color = UI.GOLD
		match str(picked["kind"]):
			"unique":
				var D: Dictionary = Uniq.def(picked["id"])
				col = Data.rarity_color(Uniq.RARITY)
				sub = "Золота річ «%s» • %s • рівень %d" % [Uniq.tier_name(int(picked["tier"])), Data.slot_name(D["slot"]), int(p.level)]
				text = "%s: %s" % [Uniq.power_name(str(picked["id"])), Uniq.power_text(str(picked["id"]))]
			"artifact":
				col = Data.rarity_color(Arts.RARITY)
				sub = "Артефакт • діє з торби"
				text = str(Arts.def(picked["id"])["text"])
			_:
				sub = "можна взяти на тиждень: %d" % int(picked["limit"])
		var nl := UI.label(str(picked["name"]), 22, col, false)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		det.add_child(nl)
		det.add_child(UI.label(sub, 14, UI.MUTED, false))
		if text != "":
			var tl := UI.label(text, 16, UI.TEXT, false)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tl.custom_minimum_size = Vector2(280, 0)
			det.add_child(tl)
		var why: String = FairService.block_reason(w, p, str(picked["key"]))
		det.add_child(UI.button("%s • %d трофеїв і %s грн" % [FAIR_BUY, int(picked["trophy"]), UI.num(int(picked["gold"]))], _do(game, "fair_buy", str(picked["key"])), Vector2(UShop.BTN_W + 40, 60), 17, why == ""))
		if why != "":
			var wl := UI.label(why, 14, UI.GOOD if FairService.bought(w, str(picked["key"])) >= int(picked["limit"]) else UI.BAD, false)
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wl.custom_minimum_size = Vector2(280, 0)
			det.add_child(wl)
	return UShop._page("Раз на тиждень скупник привозить рідкісне й міняє на трофеї та гривні. Золоті речі дібрано під твій клас і рівень. Кожну річ можна взяти раз на тиждень, у понеділок товар новий. Твої трофеї: %d." % int(p.resources.get(Camp.TROPHY, 0)), grid, det)


## Стайня: улюбленці роду. Купити, нагодувати до наступного ступеня, узяти з собою.
static func _pets(game) -> Control:
	var w = game.world
	var p = game.player
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var cur: String = str(p.pet)
	var head := "З героєм зараз: %s." % (Pets.pet_name(cur) if cur != "" else "нікого")
	var hl := UI.label("Улюбленці живуть на хуторі й служать усьому роду. Кожен герой бере з собою одного. Сили в бою вони не додають: це помічники в дорозі й господарстві. %s" % head, 17, UI.MUTED, false)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hl)
	var grid := UI.grid(2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in Pets.ids():
		var D: Dictionary = Pets.def(id)
		var lvl: int = PetService.level(w, id)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UI.style(Color(0.14, 0.11, 0.09), UI.GOLD if cur == id else Color(0.45, 0.36, 0.22), 10, 10))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		box.add_child(UI.label(str(D["name"]) + ((" • ступінь %d із %d" % [lvl, Pets.MAX_LEVEL]) if lvl > 0 else ""), 21, UI.GOLD, false))
		var dl := UI.label(str(D["desc"]), 15, UI.TEXT, false)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(dl)
		if lvl > 0:
			box.add_child(UI.label("Зараз: " + Pets.text(id, lvl), 16, UI.GOOD, false))
		var cost: Dictionary = PetService.next_cost(w, id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		if cost.is_empty():
			row.add_child(UI.label("Найвищий ступінь", 16, UI.MUTED, false))
		else:
			var nl := UI.label(("Далі: " if lvl > 0 else "Дасть: ") + Pets.text(id, lvl + 1), 15, UI.MUTED, false)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(nl)
			box.move_child(nl, box.get_child_count() - 2)
			var b := UI.button(("Нагодувати" if lvl > 0 else "Узяти на хутір") + "\n" + PetService.cost_text(cost), _do(game, "pet_up", id), Vector2(330, 62), 15, PetService.can_pay(p, cost))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
		if lvl > 0:
			row.add_child(UI.button("Лишити вдома" if cur == id else "Узяти з собою", _do(game, "pet_pick", id), Vector2(190, 62), 16))
		grid.add_child(panel)
	return v


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
