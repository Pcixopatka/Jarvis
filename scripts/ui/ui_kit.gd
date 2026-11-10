extends RefCounted
## Спільні будівельні блоки інтерфейсу: написи, кнопки, картки речей.

const Data := preload("res://scripts/data/data.gd")
const GOLD := Color(1.0, 0.85, 0.3)
const TEXT := Color(0.95, 0.92, 0.85)
const MUTED := Color(0.7, 0.7, 0.7)
const GOOD := Color(0.55, 1.0, 0.55)
const BAD := Color(1.0, 0.5, 0.45)


static func style(bg: Color, border: Color, radius: int = 14, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func label(text: String, size: int = 26, col: Color = TEXT, center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## Велике число з проміжками між тисячами: 1226262 → «1 226 262».
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func button(text: String, cb: Callable, min_size: Vector2 = Vector2.ZERO, font: int = 0, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if font > 0:
		b.add_theme_font_size_override("font_size", font)
	b.disabled = not enabled
	b.pressed.connect(cb)
	return b


## Кнопка-річ у кольорі рідкості.
static func item_button(item: Dictionary, cb: Callable, selected: bool = false, extra: String = "") -> Button:
	var col: Color = Data.RARITY_COLORS[item["rarity"]]
	var b := Button.new()
	var up: String = (" +%d" % item["up"]) if item["up"] > 0 else ""
	b.text = item["name"] + up + ("\n" + extra if extra != "" else "\n" + Data.SLOT_NAMES[item["slot"]])
	b.custom_minimum_size = Vector2(150, 62)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", col.lightened(0.2))
	b.add_theme_color_override("font_hover_color", col.lightened(0.4))
	b.add_theme_color_override("font_pressed_color", col)
	var bg := Color(0.25, 0.2, 0.12) if selected else Color(0.12, 0.1, 0.09)
	b.add_theme_stylebox_override("normal", style(bg, col if selected else col.darkened(0.35), 10, 6))
	b.add_theme_stylebox_override("hover", style(bg.lightened(0.08), col, 10, 6))
	b.add_theme_stylebox_override("pressed", style(bg.darkened(0.2), col, 10, 6))
	b.pressed.connect(cb)
	return b


static func empty_slot_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 62)
	b.add_theme_font_size_override("font_size", 15)
	b.disabled = true
	return b


## Детальна картка речі. compare — річ, вдягнена в той самий слот (для порівняння).
static func item_card(item: Dictionary, compare: Dictionary = {}) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var col: Color = Data.RARITY_COLORS[item["rarity"]]
	v.add_child(label(Data.item_title(item), 24, col, false))
	v.add_child(label("%s • %s • рівень речі %d" % [Data.RARITY_NAMES[item["rarity"]], Data.SLOT_NAMES[item["slot"]], item["ilvl"]], 16, MUTED, false))
	if item["slot"] == "weapon":
		v.add_child(label(Data.WEAPON_TYPES[item["type"]]["hint"], 16, MUTED, false))
	var st := Data.item_stats(item)
	var cmp := Data.item_stats(compare) if not compare.is_empty() else {}
	for id in st:
		var line := Data.fmt_stat(id, st[id])
		var c := TEXT
		if not compare.is_empty():
			var diff: float = st[id] - cmp.get(id, 0.0)
			if diff > 0.05:
				c = GOOD
			elif diff < -0.05:
				c = BAD
		v.add_child(label(line, 18, c, false))
	if not compare.is_empty() and compare.get("uid", -1) != item.get("uid", -2):
		var lost := []
		for id in cmp:
			if not st.has(id):
				lost.append(Data.fmt_stat(id, cmp[id]))
		if not lost.is_empty():
			var ll := label("Втратиш: " + ", ".join(lost), 15, BAD, false)
			ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ll.custom_minimum_size = Vector2(290, 0)
			v.add_child(ll)
		v.add_child(label("Зараз вдягнуто: " + Data.item_title(compare), 15, MUTED, false))
	if item["up"] > 0:
		v.add_child(label("Заточка +%d: усі бонуси +%d%%" % [item["up"], roundi(item["up"] * Data.UPGRADE_BONUS * 100)], 15, GOLD, false))
	return v


## Піксельний значок здобичі заданого розміру (без згладжування).
static func icon(id: String, px: int = 28) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://scripts/world/gfx.gd").icon_tex(id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Перший кадр спрайта персонажа чи нечисті (дивиться на нас) — для довідника.
static func sprite_icon(id: String, px: int = 56) -> TextureRect:
	var t := TextureRect.new()
	var sheet: Texture2D = load("res://scripts/world/gfx.gd").sheet(id)
	if sheet != null:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(0, 0, 48, 48)
		t.texture = at
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Значок зі старовинної мапи світу (замок, печера, курган...).
static func map_icon(name: String, px: int = 48) -> TextureRect:
	var t := TextureRect.new()
	var order: Array = load("res://scripts/ui/world_map.gd").ICON_ORDER
	var i := order.find(name)
	if i >= 0:
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/gfx/sprites/map_icons.png")
		at.region = Rect2(i * 24, 0, 24, 24)
		t.texture = at
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Значок і підпис поруч: «[м'ясо] 5».
static func icon_text(id: String, text: String, size: int = 20, col: Color = TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(icon(id, int(size * 1.5)))
	h.add_child(label(text, size, col, false))
	return h


## Ряд значків із числами: [[значок, підпис], ...].
static func icon_row(items: Array, size: int = 20, col: Color = TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	for it in items:
		h.add_child(icon_text(it[0], it[1], size, col))
	return h


static func scroll(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.add_child(content)
	sc.add_child(m)
	return sc


static func grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	return g


static func connector() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.85, 0.65, 0.2, 0.8)
	c.custom_minimum_size = Vector2(6, 22)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


## Повноекранна панель із заголовком, кнопкою закриття і вкладками.
static func screen(title: String, close_text: String, close_cb: Callable, pages: Array, current: int, on_tab: Callable, extra: Array = []) -> MarginContainer:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)
	var header := HBoxContainer.new()
	var t := label(title, 24, GOLD, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.custom_minimum_size = Vector2(120, 0)
	header.add_child(t)
	header.add_theme_constant_override("separation", 10)
	for e in extra:
		header.add_child(button(e[0], e[1], Vector2(170, 60)))
	header.add_child(button(close_text, close_cb, Vector2(200, 60)))
	v.add_child(header)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for i in pages.size():
		tabs.add_child(scroll(pages[i][1]))
		tabs.set_tab_title(i, pages[i][0])
	# Вкладку виставляємо, коли контейнер уже в дереві сцени (інакше він скидається на першу).
	var idx := clampi(current, 0, pages.size() - 1)
	tabs.ready.connect(func():
		tabs.current_tab = idx
		tabs.tab_changed.connect(on_tab))
	return root
