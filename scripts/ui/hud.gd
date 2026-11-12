class_name Hud
extends CanvasLayer
## Інтерфейс поверх гри: сенсорне керування, смуги здоров'я й досвіду, написи,
## банер, підказки, червоні краї при пораненні, мапа, повноекранні екрани та меню-оверлеї.
## Сам нічого не вирішує: про натискання повідомляє сигналами, а Game вирішує, що робити.

signal attack_pressed
signal dodge_pressed
signal skill_pressed(id: String)
signal potion_pressed
signal mana_pressed
signal pause_pressed
signal character_pressed
signal map_pressed
signal auto_pressed
signal map_location_selected(id: String)

const Classes := preload("res://scripts/data/classes.gd")
const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const WorldMap := preload("res://scripts/ui/world_map.gd")
const JoystickScript := preload("res://scripts/ui/joystick.gd")
const ActionButtonScript := preload("res://scripts/ui/action_button.gd")
const Gfx := preload("res://scripts/world/gfx.gd")

var ui_root: Control
var stats_box: Control
var controls: Node2D
var joystick
var btn_attack
var btn_dodge
var skill_buttons := {}
var btn_potion
var btn_mana
var btn_block
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var mana_bar: ProgressBar
var job_bar: ProgressBar
var attack_slots: Array = []  # 3 кнопки атак праворуч, біля основного удару
var buff_slots: Array = []  # 5 кнопок бафів знизу посередині
var hp_label: Label
var level_label: Label
var quest_label: Label
var loc_label: Label
var sub_label: Label
var banner: Label
var objective_arrow  # стрілка до мети в бою (ObjectiveArrow)
var pause_btn: Button
var corner_box: HBoxContainer  # рядок кнопок у правому верхньому куті: «Мапа», герой, меню
var char_btn: Button
var map_btn: Button
var auto_btn: Button  # автобій: видно лише там, де він буває (виставляє Game)
var auto_vector := Vector2.ZERO  # куди веде героя автобій; дотик до джойстика важить більше
var map_view
var map_panel: PanelContainer
var screen_root: Control = null
var dialogue_root: Control = null
var vignette: TextureRect
var hint_panel: PanelContainer
var hint_label: Label
var overlay: ColorRect
var overlay_box: VBoxContainer
var overlay_scroll: ScrollContainer  # гортає меню, якщо воно вище за екран
var _hint_tween: Tween
var _banner_tween: Tween = null
var _pulse := 0.0
var _time := 0.0
var _low_hp := false


# ---------- Безпечна зона екрана ----------
## На телефонах із вирізом камери гра малюється й під ним (Android 15+ розтягує застосунки на весь екран).
## Світ гри хай іде до самого краю, а написи й кнопки відсуваємо на ширину вирізу.
const SAFE_MAX_X := 0.08  # найбільший відступ збоку, частка ширини (захист від хибних даних пристрою)
const SAFE_MAX_Y := 0.05
static var insets_override: Array = []  # для перевірок і знімків: [ліворуч, згори, праворуч, знизу]
var insets: Array = [0.0, 0.0, 0.0, 0.0]  # застосовані відступи в одиницях полотна
var edge_dim: Array = []  # смуги поза безпечною зоною: темніють разом із меню й розмовами
var _safe_check := 0.0


## Відступи в одиницях полотна з розміру вікна й безпечного прямокутника (обидва — у пікселях екрана).
static func insets_from(win: Vector2i, safe: Rect2i, view: Vector2) -> Array:
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return [0.0, 0.0, 0.0, 0.0]
	var kx := view.x / win.x
	var ky := view.y / win.y
	return [clampf(safe.position.x * kx, 0.0, view.x * SAFE_MAX_X), clampf(safe.position.y * ky, 0.0, view.y * SAFE_MAX_Y),
		clampf((win.x - safe.end.x) * kx, 0.0, view.x * SAFE_MAX_X), clampf((win.y - safe.end.y) * ky, 0.0, view.y * SAFE_MAX_Y)]


func safe_insets() -> Array:
	if not insets_override.is_empty():
		return insets_override
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	return insets_from(DisplayServer.window_get_size(), DisplayServer.get_display_safe_area(), get_viewport().get_visible_rect().size)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(layout)
	layout()
	Events.banner.connect(show_banner)
	Events.player_hurt.connect(func(): vignette.modulate.a = 0.6)


func _process(delta: float) -> void:
	_time += delta
	var low := 0.25 + 0.15 * sin(_time * 6.0) if _low_hp else 0.0
	vignette.modulate.a = maxf(move_toward(vignette.modulate.a, 0.0, delta * 1.5), low)
	# Телефон перевернули іншим боком — виріз переїхав на протилежний край, а розмір екрана той самий
	_safe_check -= delta
	if _safe_check <= 0.0:
		_safe_check = 0.5
		if safe_insets() != insets:
			layout()
	var dim := 0.72 if overlay.visible else (0.55 if dialogue_root != null else 0.0)
	for strip in edge_dim:
		strip.visible = dim > 0.0 and strip.size.x > 0.5 and strip.size.y > 0.5
		strip.color.a = dim


# ======================= Побудова =======================

func _build() -> void:
	controls = Node2D.new()
	controls.visible = false
	add_child(controls)
	joystick = JoystickScript.new()
	controls.add_child(joystick)
	btn_attack = _action_button("Удар", 86.0, Color(0.75, 0.15, 0.12))
	btn_attack.triggered.connect(func(): attack_pressed.emit())
	btn_dodge = _action_button("Перекид", 56.0, Color(0.2, 0.45, 0.75))
	btn_dodge.triggered.connect(func(): dodge_pressed.emit())
	btn_block = _action_button("Блок", 50.0, Color(0.55, 0.42, 0.2))
	btn_potion = _action_button("Зілля", 46.0, Color(0.75, 0.12, 0.2))
	btn_potion.triggered.connect(func(): potion_pressed.emit())
	btn_mana = _action_button("Наснага", 40.0, Color(0.18, 0.4, 0.85))
	btn_mana.triggered.connect(func(): mana_pressed.emit())
	var SkillInfo = load("res://scripts/data/skill_info.gd")
	for id in Data.Classes.actives():
		var b = _action_button(Data.Classes.label(id), 54.0 if SkillInfo.kind(id) == "attack" else 42.0, Data.Classes.color(id))
		b.triggered.connect(func(): skill_pressed.emit(id))
		b.icon = Gfx.skill_icon_tex(id)
		b.visible = false
		skill_buttons[id] = b

	for i in 4:
		var strip := ColorRect.new()
		strip.color = Color(0, 0, 0, 0)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.visible = false
		add_child(strip)
		edge_dim.append(strip)

	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	add_child(ui_root)

	vignette = TextureRect.new()
	vignette.texture = _make_vignette_texture()
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	ui_root.add_child(vignette)

	map_view = WorldMap.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.visible = false
	map_view.location_selected.connect(func(id): map_location_selected.emit(id))
	# мапа під крамницею, довідником чи меню щипків не слухає
	map_view.is_covered = func(): return screen_root != null or overlay.visible or dialogue_root != null
	ui_root.add_child(map_view)

	map_panel = PanelContainer.new()
	map_panel.anchor_left = 1.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_bottom = 1.0
	map_panel.offset_left = -390
	map_panel.offset_right = -12
	map_panel.offset_top = 100
	map_panel.offset_bottom = -12
	map_panel.visible = false
	ui_root.add_child(map_panel)

	_build_stats()

	# Кнопки в правому верхньому куті стоять рядком і ростуть ліворуч:
	# довгий напис («Запорожець +23») розсуває сусідів, а не налазить на них
	corner_box = HBoxContainer.new()
	corner_box.anchor_left = 1.0
	corner_box.anchor_right = 1.0
	corner_box.offset_left = -20
	corner_box.offset_right = -20
	corner_box.offset_top = 16
	corner_box.offset_bottom = 88
	corner_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner_box.alignment = BoxContainer.ALIGNMENT_END
	corner_box.add_theme_constant_override("separation", 14)
	corner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(corner_box)
	auto_btn = _corner_button("Авто", 110, func(): auto_pressed.emit())
	auto_btn.add_theme_font_size_override("font_size", 22)
	map_btn = _corner_button("Мапа", 115, func(): map_pressed.emit())
	map_btn.add_theme_font_size_override("font_size", 24)
	char_btn = _corner_button("Козак", 180, func(): character_pressed.emit())
	char_btn.add_theme_font_size_override("font_size", 24)
	pause_btn = _corner_button("II", 76, func(): pause_pressed.emit())

	objective_arrow = load("res://scripts/ui/objective_arrow.gd").new()
	objective_arrow.visible = false
	ui_root.add_child(objective_arrow)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.offset_bottom = -200
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_constant_override("outline_size", 10)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.z_index = 5
	ui_root.add_child(banner)

	hint_panel = PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.gui_input.connect(func(ev: InputEvent):
		# На мапі підказка ловить дотик і зникає: раніше дотик провалювався крізь неї, і козак їхав у чисте поле
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			hide_hint()
			hint_panel.accept_event())
	hint_panel.visible = false
	hint_panel.z_index = 5
	hint_panel.add_theme_stylebox_override("panel", UI.style(Color(0.1, 0.08, 0.06, 0.9), Color(1.0, 0.8, 0.3)))
	hint_label = UI.label("", 20, UI.TEXT, false)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(620, 0)
	hint_panel.add_child(hint_label)
	ui_root.add_child(hint_panel)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = 6
	ui_root.add_child(overlay)
	# Меню стоїть по центру, поки вміщається. На низькому екрані воно гортається, а не ховає нижні кнопки.
	overlay_scroll = ScrollContainer.new()
	overlay_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(overlay_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL  # не нижчий за екран: коротке меню лишається по центру
	overlay_scroll.add_child(center)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	center.add_child(pad)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 14)
	overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(overlay_box)


func _build_stats() -> void:
	stats_box = Control.new()
	stats_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.visible = false
	ui_root.add_child(stats_box)
	hp_bar = _bar(Color(0.85, 0.15, 0.15), Vector2(20, 18), Vector2(340, 30))
	hp_label = _stat_label(Vector2(30, 18), 20)
	hp_label.size = Vector2(320, 30)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_bar = _bar(Color(0.25, 0.45, 0.95), Vector2(20, 51), Vector2(340, 10))
	xp_bar = _bar(Color(0.95, 0.75, 0.15), Vector2(20, 64), Vector2(340, 9))
	job_bar = _bar(Color(0.55, 0.85, 1.0), Vector2(20, 75), Vector2(340, 5))
	level_label = _stat_label(Vector2(20, 82), 22)
	quest_label = _stat_label(Vector2(20, 114), 16)
	loc_label = Label.new()
	loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loc_label.anchor_right = 1.0
	loc_label.offset_top = 14
	stats_box.add_child(loc_label)
	sub_label = Label.new()
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.anchor_right = 1.0
	sub_label.offset_top = 46
	sub_label.add_theme_font_size_override("font_size", 18)
	stats_box.add_child(sub_label)


static func _make_theme() -> Theme:
	var th := Theme.new()
	var gold_b := Color(0.95, 0.75, 0.2)
	th.set_stylebox("normal", "Button", UI.style(Color(0.55, 0.12, 0.1), gold_b))
	th.set_stylebox("hover", "Button", UI.style(Color(0.68, 0.18, 0.12), gold_b))
	th.set_stylebox("pressed", "Button", UI.style(Color(0.4, 0.08, 0.06), gold_b))
	th.set_stylebox("disabled", "Button", UI.style(Color(0.2, 0.17, 0.15), Color(0.4, 0.35, 0.3)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 28)
	th.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_disabled_color", "Button", Color(0.62, 0.6, 0.57))
	th.set_font_size("font_size", "Label", 24)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 6)
	th.set_font_size("font_size", "TabContainer", 24)
	th.set_stylebox("panel", "TabContainer", UI.style(Color(0.1, 0.08, 0.07, 0.94), Color(0.6, 0.45, 0.15)))
	th.set_stylebox("panel", "PanelContainer", UI.style(Color(0.1, 0.08, 0.07, 0.92), Color(0.6, 0.45, 0.15)))
	th.set_stylebox("tab_selected", "TabContainer", UI.style(Color(0.55, 0.12, 0.1), gold_b))
	th.set_stylebox("tab_unselected", "TabContainer", UI.style(Color(0.2, 0.15, 0.12), Color(0.45, 0.35, 0.2)))
	th.set_stylebox("tab_hovered", "TabContainer", UI.style(Color(0.35, 0.12, 0.1), Color(0.75, 0.55, 0.2)))
	th.set_color("font_selected_color", "TabContainer", Color(1, 0.95, 0.8))
	th.set_color("font_unselected_color", "TabContainer", Color(0.75, 0.7, 0.6))
	th.set_color("font_hovered_color", "TabContainer", Color(1, 0.9, 0.75))
	return th


static func _make_vignette_texture() -> GradientTexture2D:
	var vg := GradientTexture2D.new()
	vg.width = 256
	vg.height = 256
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.25, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.75, 0.0, 0.0, 0.75))
	g.add_point(0.72, Color(0.75, 0.0, 0.0, 0.0))
	vg.gradient = g
	return vg


func _bar(fill: Color, pos: Vector2, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = pos
	bar.size = size
	stats_box.add_child(bar)
	return bar


func _stat_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	stats_box.add_child(l)
	return l


func _corner_button(text: String, min_width: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 72)
	b.visible = false
	b.pressed.connect(cb)
	corner_box.add_child(b)
	return b


func _action_button(text: String, r: float, col: Color):
	var b = ActionButtonScript.new()
	b.label = text
	b.radius = r
	b.color = col
	controls.add_child(b)
	return b


func layout() -> void:
	var full := get_viewport().get_visible_rect().size
	insets = safe_insets().duplicate()
	var il: float = insets[0]
	var it: float = insets[1]
	var ir: float = insets[2]
	var ib: float = insets[3]
	# Увесь інтерфейс живе в безпечній зоні; світ гри під ним — на весь екран
	ui_root.offset_left = il
	ui_root.offset_top = it
	ui_root.offset_right = -ir
	ui_root.offset_bottom = -ib
	# Червоне мерехтіння при малому здоров'ї — до самих країв
	vignette.offset_left = -il
	vignette.offset_top = -it
	vignette.offset_right = ir
	vignette.offset_bottom = ib
	var strips := [Rect2(0, 0, il, full.y), Rect2(full.x - ir, 0, ir, full.y), Rect2(il, 0, full.x - il - ir, it), Rect2(il, full.y - ib, full.x - il - ir, ib)]
	for i in 4:
		edge_dim[i].position = strips[i].position
		edge_dim[i].size = strips[i].size
	# Кнопки бою рахуються від країв безпечної зони (o — її лівий верхній кут, s — розмір)
	var o := Vector2(il, it)
	var s := full - Vector2(il + ir, it + ib)
	joystick.rest_pos = o + Vector2(190, s.y - 180)
	joystick.queue_redraw()
	btn_attack.position = o + Vector2(s.x - 140, s.y - 140)
	btn_dodge.position = o + Vector2(s.x - 300, s.y - 80)
	# Атаки — дугою навколо основного удару; бафи — рядком унизу між джойстиком і ударом
	attack_slots = [o + Vector2(s.x - 120, s.y - 315), o + Vector2(s.x - 275, s.y - 255), o + Vector2(s.x - 425, s.y - 105)]
	var bx := (s.x - 540.0) / 2.0 + 60.0  # центр смуги між джойстиком (≈340) і кнопками праворуч (≈540)
	buff_slots = []
	for i in 5:
		buff_slots.append(o + Vector2(bx + (i - 2) * 96.0, s.y - 52))
	btn_potion.position = o + Vector2(s.x - 430, s.y - 250)
	btn_mana.position = o + Vector2(s.x - 540, s.y - 200)
	btn_block.position = o + Vector2(s.x - 270, s.y - 420)
	map_view.map_rect = Rect2(Vector2(8, 96), Vector2(s.x - 410, s.y - 104))


# ======================= Режими показу =======================

## Що показувати: смуги героя (stats) і кнопки бою (combat).
func set_mode(show_stats: bool, combat: bool) -> void:
	stats_box.visible = show_stats
	pause_btn.visible = combat
	map_btn.visible = combat
	if not combat:
		auto_btn.visible = false
		auto_vector = Vector2.ZERO
	char_btn.visible = show_stats
	controls.visible = combat
	if not combat:
		joystick.release()


func show_map(v: bool) -> void:
	map_view.visible = v
	map_panel.visible = v


## Вміст панелі мапи гортається, а footer (подарунки спонсора) завжди видно внизу.
func set_map_panel(content: Control, footer: Control = null) -> void:
	for c in map_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	v.add_child(sc)
	if footer != null:
		v.add_child(footer)
	map_panel.add_child(v)


func move_vector() -> Vector2:
	if joystick.touched() or auto_vector == Vector2.ZERO:
		return joystick.vector.limit_length(1.0)
	return auto_vector.limit_length(1.0)


# ======================= Оновлення =======================

## combat_info: {"name", "sub"} для бою або порожній словник.
func update(player: Player, world, combat_info: Dictionary, delta: float, story_line: String = "") -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "Здоров'я %d / %d" % [roundi(player.hp), roundi(player.max_hp)]
	if player.level >= Classes.BASE_LEVEL_MAX:
		# на останньому рівні смуга показує звитягу
		xp_bar.max_value = player.valor_next()
		xp_bar.value = player.valor_xp
	else:
		xp_bar.max_value = player.xp_next
		xp_bar.value = player.xp
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.mana
	job_bar.max_value = maxi(1, player.job_next())
	job_bar.value = player.job_next() if player.job_level >= player.job_max() else player.job_xp
	level_label.text = "Рівень %d  •  %s %d  •  Гривні: %s" % [player.level, player.class_name_ua(), player.job_level, UI.num(player.gold)]
	if not player.statuses.is_empty() and not combat_info.is_empty():
		level_label.text += "    " + player.Status.describe(player)
	var ql := []
	if story_line != "":
		ql.append(story_line)
	for q in world.quests:
		ql.append("• %s %d/%d" % [q["text"], q["progress"], q["count"]] + (("  ✓ здай: %s" % Data.place_name(str(q["city"]))) if world.is_done(q) else ""))
	quest_label.text = "\n".join(ql)
	loc_label.text = combat_info.get("name", "")
	sub_label.text = combat_info.get("sub", "")
	_low_hp = not combat_info.is_empty() and player.alive and player.hp < player.max_hp * 0.3
	if not combat_info.is_empty():
		btn_dodge.set_cooldown(player.dodge_timer / player.dodge_cooldown)
		btn_potion.set_cooldown(1.0 if player.potions <= 0 else player.potion_timer / Data.POTION_CD)
		var bl := "Заряд!" if player.blocking and player.block_time >= player.CHARGE_MIN else ("Оберіг" if player.is_mage() else "Блок")
		if btn_block.label != bl:
			btn_block.label = bl
			btn_block.queue_redraw()
		var pl := "Зілля %d" % player.potions
		if btn_potion.label != pl:
			btn_potion.label = pl
			btn_potion.queue_redraw()
		# Кнопка наснаги: у волхвів завжди на місці, в інших — лише коли є що пити
		btn_mana.visible = player.mana_potions > 0 or player.is_volkhv()
		btn_mana.set_cooldown(1.0 if player.mana_potions <= 0 else player.mana_potion_timer / Data.MANA_POTION_CD)
		var ml := "Наснага %d" % player.mana_potions
		if btn_mana.label != ml:
			btn_mana.label = ml
			btn_mana.queue_redraw()
		player.sync_panel()
		for id in skill_buttons:
			var b = skill_buttons[id]
			var ai: int = player.panel["attack"].find(id)
			var bi: int = player.panel["buff"].find(id)
			b.visible = ai >= 0 or bi >= 0
			if b.visible:
				b.position = attack_slots[ai] if ai >= 0 else buff_slots[bi]
				var no_mana: bool = player.mana < player.skill_cost(id)
				b.set_cooldown(1.0 if no_mana and player.skill_timers.get(id, 0.0) <= 0.0 else player.skill_ready_ratio(id))
	var pts: int = player.unspent_points() + ChallengeService.ready_count(world, player)
	if pts > 0:
		_pulse += maxf(delta, 0.016) * 5.0
		char_btn.text = "Персонаж +%d" % pts
		char_btn.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.25, 0.6), 0.5 + 0.5 * sin(_pulse))
	else:
		char_btn.text = "Персонаж"
		char_btn.modulate = Color.WHITE


## Розмір шрифту банера за обсягом тексту: коротке гасло велике, довгі новини дрібніші.
static func banner_font(text: String) -> int:
	var lines := text.split("\n")
	var longest := 0
	for l in lines:
		longest = maxi(longest, l.length())
	if lines.size() > 4 or longest > 56:
		return 26
	if lines.size() > 2 or longest > 34:
		return 34
	return 48


## Скільки секунд банер висить на повну яскравість: довгому тексту — більше часу.
static func banner_hold(text: String) -> float:
	return clampf(1.6 + 0.6 * (text.split("\n").size() - 1) + maxf(0.0, text.length() - 60) * 0.012, 1.6, 6.0)


func show_banner(text: String, col: Color = Color(1, 0.92, 0.7)) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.add_theme_font_size_override("font_size", banner_font(text))
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()  # новий банер не має згаснути за розкладом старого
	_banner_tween = banner.create_tween()
	banner.modulate.a = 0.0
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(banner_hold(text))
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.5)


## Підказка. На мапі — внизу ліворуч (праворуч бічна панель), в інших режимах — угорі по центру.
## Сховати підказку одразу: вона не має затуляти екран, який щойно відкрили.
func hide_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	hint_panel.visible = false


func show_hint(text: String, on_map: bool) -> void:
	hint_label.text = text
	var shift := -205.0 if on_map else 0.0
	hint_panel.offset_left = -330 + shift
	hint_panel.offset_right = 330 + shift
	hint_panel.anchor_top = 1.0 if on_map else 0.0
	hint_panel.anchor_bottom = hint_panel.anchor_top
	hint_panel.offset_top = -120.0 if on_map else 84.0
	hint_panel.offset_bottom = hint_panel.offset_top
	hint_panel.visible = true
	hint_panel.modulate.a = 1.0
	# у бою підказка дотиків не ловить (під нею кнопки й рух), на мапі ловить
	hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP if on_map else Control.MOUSE_FILTER_IGNORE
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = hint_panel.create_tween()
	_hint_tween.tween_interval(8.0)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.6)
	_hint_tween.tween_callback(func(): hint_panel.visible = false)


# ======================= Повноекранні екрани =======================

## Замінити екран. keep_scroll — це той самий екран після дії (купівля, заточка, врожай):
## прокрутка відкритої вкладки лишається на місці, а не стрибає на початок списку.
func set_screen(c: Control, keep_scroll: bool = false) -> void:
	var was := _screen_scroller(screen_root) if keep_scroll else null
	var at: int = was.scroll_vertical if was else 0
	clear_screen()
	screen_root = c
	ui_root.add_child(c)
	ui_root.move_child(c, banner.get_index())
	if at > 0:
		_restore_scroll(_screen_scroller(c), at)


## Прокрутка відкритої вкладки екрана (або перша на екрані без вкладок).
func _screen_scroller(screen: Control) -> ScrollContainer:
	if screen == null or not is_instance_valid(screen):
		return null
	var tabs := screen.find_children("*", "TabContainer", true, false)
	if not tabs.is_empty():
		return tabs[0].get_current_tab_control() as ScrollContainer
	var all := screen.find_children("*", "ScrollContainer", true, false)
	return (all[0] as ScrollContainer) if not all.is_empty() else null


## Вміст нового екрана ще не розкладено, тож чекаємо, доки смуга прокрутки дізнається свою довжину,
## і лише тоді ставимо її на місце. Це стається в тому самому кадрі, до малювання.
func _restore_scroll(sc: ScrollContainer, at: int) -> void:
	if sc == null:
		return
	var bar := sc.get_v_scroll_bar()
	var st := {"done": false}
	bar.changed.connect(func():
		if not st["done"] and bar.max_value > bar.page:
			st["done"] = true
			sc.set_deferred("scroll_vertical", at))


func clear_screen() -> void:
	if screen_root:
		screen_root.queue_free()
		screen_root = null


func show_dialogue(d: Control) -> void:
	close_dialogue()
	dialogue_root = d
	ui_root.add_child(d)


func close_dialogue() -> void:
	if dialogue_root:
		dialogue_root.queue_free()
		dialogue_root = null


# ======================= Меню-оверлеї =======================

func open_overlay() -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	overlay_scroll.scroll_vertical = 0
	overlay.visible = true
	controls.visible = false
	joystick.release()


func close_overlay() -> void:
	overlay.visible = false
	for c in overlay_box.get_children():
		c.queue_free()


func add_title(text: String, size: int = 56, col: Color = UI.GOLD) -> Label:
	var l := UI.label(text, size, col)
	overlay_box.add_child(l)
	return l


func add_button(text: String, cb: Callable, min_size := Vector2(480, 80)) -> Button:
	var b := UI.button(text, cb, min_size)
	overlay_box.add_child(b)
	return b


func add_row(nodes: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for n in nodes:
		row.add_child(n)
	overlay_box.add_child(row)
