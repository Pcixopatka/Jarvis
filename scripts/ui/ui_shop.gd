extends RefCounted
## Екран крамниці за донат: набори червінців і все рідкісне за них (золоті речі, набори, артефакти, душі).
## Відкривається з паузи, привалу на мапі й екрана героя (game.open_shop). Усі дії йдуть через
## game.shop_do(дія, аргумент), після чого екран перебудовується. Покупка за червінці просить другий дотик.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Shop := preload("res://scripts/data/shop.gd")
const ShopService := preload("res://scripts/game/shop_service.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")
const Sets := preload("res://scripts/data/sets.gd")
const Souls := preload("res://scripts/data/souls.gd")
const SoulService := preload("res://scripts/game/soul_service.gd")
const Premium := preload("res://scripts/game/premium_service.gd")
const Costumes := preload("res://scripts/data/costumes.gd")
const CostumeService := preload("res://scripts/game/costume_service.gd")
const QuickService := preload("res://scripts/game/quick_service.gd")
const AdRewards := preload("res://scripts/game/ad_rewards.gd")
const DivineService := preload("res://scripts/game/divine_service.gd")

const CARD_BG := Color(0.14, 0.11, 0.09)
const CARD_LINE := Color(0.45, 0.36, 0.22)
const COIN_COLOR := Color(1.0, 0.78, 0.3)


static func build(game) -> Control:
	# Вкладки будуються ліниво: функція викликається лише для відкритої (UI.screen).
	var pages := [["Червінці", func(): return _packs(game)]]
	for kind in Shop.KINDS:
		pages.append([Shop.KIND_NAMES[kind], (func(): return _sets(game)) if kind == "set" else _goods.bind(game, kind)])
	if DivineService.on_sale:  # поки дари не продаються, вкладки нема (Game._shop_tab_index рахує так само)
		pages.append(["Божі дари", func(): return load("res://scripts/ui/ui_divine.gd").shop_page(game)])
	pages.append(["Вбрання", func(): return _costumes(game)])
	pages.append(["Універсал", func(): return _premium(game)])
	var title := "Крамниця   •   %s: %s" % [Shop.COIN, UI.num(ShopService.coins(game.world))]
	if Premium.active(game.world):
		title += "   •   універсал: ще %d дн." % Premium.days_left(game.world)
	var screen := UI.screen(title, "Назад", game.close_shop, pages, game.shop_tab, func(i: int): game.shop_tab = i)
	# Крамниця відкривається й посеред бою (з паузи), тож під нею суцільне тло, а не арена
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UI.style(Color(0.13, 0.11, 0.08), Color(0.13, 0.11, 0.08), 0, 0))
	bg.add_child(screen)
	return bg


static func _wrap(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l


static func _note(game) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	if game.get_node("/root/Billing").is_test():
		v.add_child(_wrap("Тестова оплата: справжні гроші не списуються. Справжній магазин застосунків ще не підключено.", 15, UI.GOOD))
	return v


# ---------------- Червінці ----------------

static func _packs(game) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	if not ShopService.coins_on_sale:
		# купівлю червінців вимкнено (Shop.COINS_ON_SALE): лише рахунок і пояснення, без наборів і цін
		v.add_child(_wrap("На рахунку роду %s: %s" % [Shop.COIN, UI.num(ShopService.coins(game.world))], 22, COIN_COLOR))
		v.add_child(_wrap(ShopService.PACKS_OFF_TEXT, 17, UI.TEXT))
		v.add_child(_wrap("Червінці спільні для всіх твоїх героїв і не зникають. Усе рідкісне з крамниці можна здобути й у грі без жодної покупки.", 15, UI.MUTED))
		return v
	v.add_child(_wrap("Червінці купують за справжні гроші. Вони спільні для всіх твоїх героїв і не зникають. За них продається все рідкісне: золоті речі, речі наборів, артефакти й душі. Усе це можна здобути й у грі без жодної покупки.", 16, UI.TEXT))
	v.add_child(_note(game))
	var grid := UI.grid(2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for p in Shop.PACKS:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UI.style(CARD_BG, CARD_LINE, 10, 10))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		h.add_child(col)
		col.add_child(_wrap(str(p["name"]), 21, UI.GOLD))
		col.add_child(_wrap("%s червінців%s" % [UI.num(int(p["coins"])), ("   •   на %d%% більше за ті самі гроші" % int(p["bonus"])) if int(p["bonus"]) > 0 else ""], 17, COIN_COLOR))
		h.add_child(UI.button("Купити\n%s" % str(p["price"]), game.shop_do.bind("pack", str(p["id"])), Vector2(170, 64), 18))
		grid.add_child(panel)
	return v


# ---------------- Вбрання ----------------

## Вбрання героя: постать у вбранні, опис і кнопка. Куплене вдягається й знімається тут само.
static func _costumes(game) -> Control:
	var world = game.world
	var p = game.player
	var wt: String = "pike" if p.is_peasant() else str(p.weapon_type)
	var grid := UI.grid(COLS)
	var picked := ""
	for id in Costumes.ORDER:
		var key := "costume:" + str(id)
		if key == game.shop_sel:
			picked = id
		var have: bool = CostumeService.owned(world, id)
		grid.add_child(UI.goods_cell(UI.sprite_icon(Costumes.sprite(id, wt), CELL), COIN_COLOR if str(p.costume) == id else CARD_LINE.lightened(0.2),
			game.shop_do.bind("select", key), key == game.shop_sel, CELL, "" if have else UI.num(CostumeService.price(id)), "", have))
	var det := VBoxContainer.new()
	det.add_theme_constant_override("separation", 6)
	if picked == "":
		det.add_child(_hint("Торкнись вбрання,\nщоб роздивитись його."))
	else:
		var D: Dictionary = Costumes.DEFS[picked]
		var have: bool = CostumeService.owned(world, picked)
		var worn: bool = str(p.costume) == picked
		var big := UI.sprite_icon(Costumes.sprite(picked, wt), 128)
		big.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # великий вигляд стоїть ліворуч, над назвою
		det.add_child(big)
		det.add_child(_wrap(str(D["name"]), 22, UI.GOLD))
		det.add_child(_wrap(str(D["desc"]), 16, UI.TEXT))
		if worn:
			det.add_child(_wrap("Вдягнено", 14, UI.GOOD))
		elif have:
			det.add_child(_wrap("Куплено для всього роду", 14, UI.MUTED))
		if have:
			det.add_child(UI.button("Зняти" if worn else "Вдягнути", game.shop_do.bind("costume", picked), Vector2(BTN_W, 60), 20))
		else:
			var why: String = CostumeService.block_reason(world, picked)
			det.add_child(_buy_button(game, "costume:" + picked, CostumeService.price(picked), why, game.shop_do.bind("costume", picked)))
			if why != "":
				det.add_child(_wrap(why, 14, UI.BAD))
	return _page("Вбрання міняє лише вигляд героя, сили не додає. Купується раз на весь рід: кожен герой вдягає його окремо. Галочка означає, що вбрання вже куплене.", grid, det)


# ---------------- Гетьманський універсал ----------------

## Преміум на 30 днів: що дає, скільки лишилось і кнопка купити чи продовжити (другий дотик підтверджує).
static func _premium(game) -> Control:
	var world = game.world
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.style(CARD_BG, COIN_COLOR if Premium.active(world) else CARD_LINE, 12, 10))
	v.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	h.add_child(left)
	left.add_child(_wrap(Premium.NAME, 24, UI.GOLD))
	if Premium.active(world):
		left.add_child(_wrap("Діє. Лишилось днів: %d. Продовження додає ще %d днів до решти." % [Premium.days_left(world), Premium.DAYS], 16, UI.GOOD))
	else:
		left.add_child(_wrap("Грамота гетьмана на %d днів для всього твого роду: кожен герой користується нею одразу." % Premium.DAYS, 16, UI.TEXT))
	for line in Premium.perks(QuickService.PER_DAY, AdRewards.SAFE_PER_DAY):
		left.add_child(_wrap("•  " + str(line), 16, UI.TEXT))
	var why: String = Premium.block_reason(world)
	var confirm: bool = game.shop_confirm == "premium" and why == ""
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(190, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	h.add_child(right)
	var verb := "Продовжити" if Premium.active(world) else "Купити"
	var b := UI.button(("Підтвердити\n%d %s" if confirm else verb + "\n%d %s") % [Premium.PRICE, Shop.COIN_SHORT], game.shop_do.bind("premium", ""), Vector2(190, 72), 19, why == "")
	if confirm:
		b.modulate = Color(1.0, 1.0, 0.6)
	right.add_child(b)
	if why != "":
		right.add_child(_wrap(why, 13, UI.BAD))
	v.add_child(_wrap("Усе це можна мати й без універсалу: реклама дає ті самі подарунки, лише повільніше. Сили героя універсал не додає.", 14, UI.MUTED))
	return v


# ---------------- Товари ----------------

## Картка товару: назва, підпис, опис і кнопка з ціною. Другий дотик по кнопці підтверджує покупку.
const CELL := 70  # клітинка товару: така сама, як у торбі на екрані героя
const COLS := 8
const BTN_W := 300

## Сторінка товарів: ліворуч сітка клітинок, праворуч картка вибраного товару з кнопкою.
static func _page(intro: String, left: Control, detail: Control) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if intro != "":
		v.add_child(_wrap(intro, 15, UI.MUTED))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.add_child(left)
	detail.custom_minimum_size = Vector2(BTN_W + 20, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(detail)
	v.add_child(h)
	return v


static func _hint(text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.label(text, 20, UI.MUTED, false))
	v.add_child(UI.label("Число під значком: ціна\nв червінцях.", 15, UI.MUTED, false))
	return v


## Кнопка покупки за червінці: перший дотик просить підтвердити, другий купує.
static func _buy_button(game, key: String, cost: int, why: String, cb: Callable) -> Button:
	var confirm: bool = game.shop_confirm == key and why == ""
	var b := UI.button(("Підтвердити • %s %s" if confirm else "Купити • %s %s") % [UI.num(cost), Shop.COIN_SHORT], cb, Vector2(BTN_W, 60), 20, why == "")
	if confirm:
		b.modulate = Color(1.0, 1.0, 0.6)
	return b


## Значок товару для клітинки. Артефакт показує свого боса, душа свою нечисть: так їх видно здалеку.
static func _goods_icon(kind: String, id: String, p) -> Control:
	var Gfx = load("res://scripts/world/gfx.gd")
	match kind:
		"unique":
			var D: Dictionary = Uniques.DEFS[id]
			return UI.icon(UI.item_icon_id({"slot": D["slot"], "type": D["type"]}), CELL)
		"artifact":
			var boss: String = str(Artifacts.DEFS[id].get("boss", ""))
			return UI.sprite_icon(boss, CELL) if Gfx.has(boss) else UI.icon("it_artifact", CELL)
		"soul":
			var who: String = id.trim_prefix("b_")
			return UI.sprite_icon(who, CELL) if Gfx.has(who) else UI.icon("it_soul", CELL)
		"set":
			var slot: String = id.get_slice(":", 1)
			return UI.icon(UI.item_icon_id({"slot": slot, "type": ShopService.set_weapon(p)}), CELL)
	return UI.icon("it_body", CELL)


## Що писати на картці товару: {"title", "col", "sub", "text"}.
static func _goods_info(kind: String, id: String, p) -> Dictionary:
	match kind:
		"unique":
			var D: Dictionary = Uniques.DEFS[id]
			return {"title": "★ " + str(D["name"]), "col": Data.RARITY_COLORS[Uniques.RARITY],
				"sub": "Золота річ «%s» • %s" % [Uniques.TIER_NAMES[int(D["tier"])], str(Data.WEAPON_TYPES[D["type"]]["name"]) if D["slot"] == "weapon" else str(Data.SLOT_NAMES[D["slot"]])],
				"text": "%s: %s" % [Uniques.power_name(id), Uniques.power_text(id)]}
		"artifact":
			var A: Dictionary = Artifacts.DEFS[id]
			return {"title": "◆ " + str(A["name"]), "col": Data.RARITY_COLORS[Artifacts.RARITY],
				"sub": "Артефакт • трофей: %s" % str(Data.BOSS_NAMES.get(A["boss"], "")), "text": str(A["text"])}
		"soul":
			var t: int = SoulService.tier(id)
			return {"title": SoulService.soul_name(id), "col": SoulService.color(id),
				"sub": "%s • %s%s" % [str(Souls.TIER_NAMES[t]), SoulService.owner_name(id), " • лише зброя й оберіг" if t >= Souls.BOSS_TIER else ""],
				"text": SoulService.fx_text(id)}
		"set":
			var sid: String = id.get_slice(":", 0)
			var slot: String = id.get_slice(":", 1)
			return {"title": "✦ " + Sets.piece_name(sid, slot, ShopService.set_weapon(p) if slot == "weapon" else ""), "col": Sets.COLOR,
				"sub": "Набір «%s» • %s" % [str(Sets.SETS[sid]["name"]), str(Data.SLOT_NAMES[slot])], "text": ""}
		"set_full":
			var steps := []
			for step in Sets.STEPS:
				steps.append("%d речі: %s" % [step, Sets.step_text(id, step)])
			return {"title": "✦ Увесь набір «%s»" % str(Sets.SETS[id]["name"]), "col": Sets.COLOR,
				"sub": "шість речей разом: дешевше, ніж поодинці (%d замість %d)" % [Shop.SET_FULL_PRICE, Shop.SET_PIECE_PRICE * Data.SLOTS.size()], "text": "\n".join(steps)}
	return {"title": id, "col": UI.GOLD, "sub": "", "text": ""}


## Картка вибраного товару: назва, що він дає, чи вже куплено, кнопка покупки.
static func _detail(game, kind: String, id: String) -> Control:
	var world = game.world
	var p = game.player
	var info: Dictionary = _goods_info(kind, id, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_wrap(str(info["title"]), 22, info["col"]))
	if str(info["sub"]) != "":
		v.add_child(_wrap(str(info["sub"]), 15, UI.MUTED))
	if str(info["text"]) != "":
		v.add_child(_wrap(str(info["text"]), 17, UI.TEXT))
	var have: int = ShopService.bought(world, kind, id)
	if have > 0:
		v.add_child(_wrap("Уже куплено: %d" % have, 14, UI.GOOD))
	if not ShopService.fits(p, kind, id):
		v.add_child(_wrap("Не для класу «%s»: згодиться іншому героєві через спільну скриню" % p.class_name_ua(), 14, UI.BAD))
	var why: String = ShopService.block_reason(world, p, kind, id)
	v.add_child(_buy_button(game, ShopService.key(kind, id), ShopService.price(kind, id), why, game.shop_do.bind("buy", [kind, id])))
	if why != "":
		v.add_child(_wrap(why, 14, UI.BAD))
	return v


## Клітинка товару: значок, ціна під ним, галочка на купленому, тьмяний значок на речі не для цього класу.
static func _goods_cell(game, kind: String, id: String, mark: String) -> Button:
	var key: String = ShopService.key(kind, id)
	var info: Dictionary = _goods_info(kind, id, game.player)
	return UI.goods_cell(_goods_icon(kind, id, game.player), info["col"], game.shop_do.bind("select", key), key == game.shop_sel, CELL,
		UI.num(ShopService.price(kind, id)), mark, ShopService.bought(game.world, kind, id) > 0, not ShopService.fits(game.player, kind, id))


static func _goods(game, kind: String) -> Control:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	var lvl: int = ShopService.item_level(game.player)
	var intro := ""
	var mark := ""
	match kind:
		"unique":
			intro = "Усі золоті речі гри. Куплена річ має рівень твого героя (%d) і лягає в торбу. Далі її можна точити й оновлювати, як будь-яку іншу. Тьмяний значок: річ не для твого класу." % lvl
			mark = "★"
		"artifact":
			intro = "Трофеї всіх босів: у клітинці сам бос. Артефакт діє, поки лежить у торбі героя; другий такий самий не діє."
			mark = "◆"
		"soul":
			intro = "Душі всієї нечисті й усіх босів: у клітинці той, чия душа. Куплена душа летить у торбинку душ; у гніздо речі її вселяє коваль. Душі босів лягають лише в зброю й оберіг."
	var grid: GridContainer = null
	var last_head := ""
	var picked := ""
	for id in ShopService.ids(kind):
		var head := ""
		match kind:
			"unique":
				head = "«%s»" % Uniques.TIER_NAMES[int(Uniques.DEFS[id]["tier"])]
			"soul":
				var t: int = SoulService.tier(id)
				head = str(Souls.TIER_NAMES[t]) + (" • лише зброя й оберіг" if t >= Souls.BOSS_TIER else "")
		if grid == null or head != last_head:
			if head != "":
				left.add_child(UI.label(head, 18, UI.GOLD, false))
			grid = UI.grid(COLS)
			left.add_child(grid)
			last_head = head
		if ShopService.key(kind, id) == game.shop_sel:
			picked = id
		grid.add_child(_goods_cell(game, kind, id, mark))
	return _page(intro, left, _detail(game, kind, picked) if picked != "" else _hint("Торкнись товару,\nщоб побачити,\nщо він дає."))


static func _sets(game) -> Control:
	var p = game.player
	var lvl: int = ShopService.item_level(p)
	var wname: String = str(Data.WEAPON_TYPES[ShopService.set_weapon(p)]["name"]).to_lower()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	var det: Control = null
	for sid in Sets.ORDER:
		var S: Dictionary = Sets.SETS[sid]
		var steps := []
		for step in Sets.STEPS:
			steps.append("%d: %s" % [step, Sets.step_text(sid, step)])
		left.add_child(UI.label(str(S["name"]), 20, Sets.COLOR, false))
		var sl := _wrap("; ".join(steps), 14, UI.MUTED)
		sl.custom_minimum_size = Vector2(COLS * CELL, 0)
		left.add_child(sl)
		var grid := UI.grid(COLS)
		left.add_child(grid)
		# перша клітинка: увесь набір одразу
		var full_key: String = ShopService.key("set_full", sid)
		grid.add_child(UI.goods_cell(UI.icon("it_body", CELL), Sets.COLOR, game.shop_do.bind("select", full_key), full_key == game.shop_sel, CELL,
			UI.num(ShopService.price("set_full", sid)), "✦6", ShopService.bought(game.world, "set_full", sid) > 0))
		if full_key == game.shop_sel:
			det = _detail(game, "set_full", sid)
		for slot in Data.SLOTS:
			var pid := "%s:%s" % [sid, slot]
			grid.add_child(_goods_cell(game, "set", pid, "✦"))
			if ShopService.key("set", pid) == game.shop_sel:
				det = _detail(game, "set", pid)
	return _page("Речі трьох наборів. Куплена річ має рівень твого героя (%d), зброя набору буде до його руки (%s). Бонуси дають 2, 4 й 6 вдягнених речей одного набору. Перша клітинка кожного ряду: увесь набір разом." % [lvl, wname],
		left, det if det != null else _hint("Торкнись речі набору,\nщоб побачити її."))
