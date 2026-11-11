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

const CARD_BG := Color(0.14, 0.11, 0.09)
const CARD_LINE := Color(0.45, 0.36, 0.22)
const COIN_COLOR := Color(1.0, 0.78, 0.3)


static func build(game) -> Control:
	var pages := [["Червінці", _packs(game)]]
	for kind in Shop.KINDS:
		pages.append([Shop.KIND_NAMES[kind], _sets(game) if kind == "set" else _goods(game, kind)])
	var title := "Крамниця   •   %s: %s" % [Shop.COIN, UI.num(ShopService.coins(game.world))]
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


# ---------------- Товари ----------------

## Картка товару: назва, підпис, опис і кнопка з ціною. Другий дотик по кнопці підтверджує покупку.
static func _card(game, kind: String, id: String, title: String, col: Color, sub: String, text: String) -> Control:
	var world = game.world
	var p = game.player
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.style(CARD_BG, CARD_LINE, 10, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	h.add_child(left)
	left.add_child(_wrap(title, 20, col))
	var have: int = ShopService.bought(world, kind, id)
	if have > 0:
		sub += "   •   уже куплено: %d" % have
	if sub != "":
		left.add_child(_wrap(sub, 14, UI.MUTED))
	if text != "":
		left.add_child(_wrap(text, 15, UI.TEXT))
	if not ShopService.fits(p, kind, id):
		left.add_child(_wrap("Не для класу «%s»: згодиться іншому героєві через спільну скриню" % p.class_name_ua(), 14, UI.BAD))
	var cost: int = ShopService.price(kind, id)
	var why: String = ShopService.block_reason(world, p, kind, id)
	var key: String = ShopService.key(kind, id)
	var confirm: bool = game.shop_confirm == key and why == ""
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(170, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	h.add_child(right)
	var b := UI.button(("Підтвердити\n%d %s" if confirm else "Купити\n%d %s") % [cost, Shop.COIN_SHORT], game.shop_do.bind("buy", [kind, id]), Vector2(170, 64), 18, why == "")
	if confirm:
		b.modulate = Color(1.0, 1.0, 0.6)
	right.add_child(b)
	if why != "":
		right.add_child(_wrap(why, 13, UI.BAD))
	return panel


static func _grid() -> GridContainer:
	var grid := UI.grid(2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


static func _goods(game, kind: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var lvl: int = ShopService.item_level(game.player)
	match kind:
		"unique":
			v.add_child(_wrap("Усі золоті речі гри. Куплена річ має рівень твого героя (%d) і лягає в торбу. Далі її можна точити й оновлювати в кузні, як здобуту в бою." % lvl, 16, UI.TEXT))
		"artifact":
			v.add_child(_wrap("Трофеї всіх босів. Артефакт діє, поки лежить у торбі героя; другий такий самий не діє.", 16, UI.TEXT))
		"soul":
			v.add_child(_wrap("Душі всієї нечисті й усіх босів. Куплена душа летить у торбинку душ; у гніздо речі її вселяє коваль. Душі босів стають лише в зброю й оберіг.", 16, UI.TEXT))
	var grid: GridContainer = null
	var last_head := ""
	for id in ShopService.ids(kind):
		var head := ""
		var title := ""
		var col := UI.GOLD
		var sub := ""
		var text := ""
		match kind:
			"unique":
				var D: Dictionary = Uniques.DEFS[id]
				head = "«%s»" % Uniques.TIER_NAMES[int(D["tier"])]
				title = "★ " + str(D["name"])
				col = Data.RARITY_COLORS[Uniques.RARITY]
				sub = str(Data.WEAPON_TYPES[D["type"]]["name"]) if D["slot"] == "weapon" else str(Data.SLOT_NAMES[D["slot"]])
				text = "%s: %s" % [Uniques.power_name(id), Uniques.power_text(id)]
			"artifact":
				var A: Dictionary = Artifacts.DEFS[id]
				title = "◆ " + str(A["name"])
				col = Data.RARITY_COLORS[Artifacts.RARITY]
				sub = "Трофей: %s" % str(Data.BOSS_NAMES.get(A["boss"], ""))
				text = str(A["text"])
			"soul":
				var t: int = SoulService.tier(id)
				head = str(Souls.TIER_NAMES[t]) + (" • лише зброя й оберіг" if t >= Souls.BOSS_TIER else "")
				title = SoulService.soul_name(id)
				col = SoulService.color(id)
				sub = SoulService.owner_name(id)
				text = SoulService.fx_text(id)
		if grid == null or head != last_head:
			if head != "":
				v.add_child(UI.label(head, 22, UI.GOLD, false))
			grid = _grid()
			v.add_child(grid)
			last_head = head
		grid.add_child(_card(game, kind, id, title, col, sub, text))
	return v


static func _sets(game) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var p = game.player
	var lvl: int = ShopService.item_level(p)
	var wname: String = str(Data.WEAPON_TYPES[ShopService.set_weapon(p)]["name"]).to_lower()
	v.add_child(_wrap("Речі трьох наборів. Куплена річ має рівень твого героя (%d), зброя набору буде до його руки (%s). Бонуси дають 2, 4 й 6 вдягнених речей одного набору." % [lvl, wname], 16, UI.TEXT))
	for sid in Sets.ORDER:
		var S: Dictionary = Sets.SETS[sid]
		var steps := []
		for step in Sets.STEPS:
			steps.append("%d: %s" % [step, Sets.step_text(sid, step)])
		v.add_child(UI.label(str(S["name"]), 22, Sets.COLOR, false))
		v.add_child(_wrap("; ".join(steps), 15, UI.MUTED))
		var grid := _grid()
		v.add_child(grid)
		grid.add_child(_card(game, "set_full", sid, "✦ Увесь набір: шість речей", Sets.COLOR, "дешевше, ніж поодинці (%d замість %d)" % [Shop.SET_FULL_PRICE, Shop.SET_PIECE_PRICE * Data.SLOTS.size()], str(S["lore"])))
		for slot in Data.SLOTS:
			var name: String = Sets.piece_name(sid, slot, ShopService.set_weapon(p) if slot == "weapon" else "")
			grid.add_child(_card(game, "set", "%s:%s" % [sid, slot], "✦ " + name, Sets.COLOR, str(Data.SLOT_NAMES[slot]), ""))
	return v
