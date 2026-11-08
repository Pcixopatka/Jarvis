class_name Hud
extends CanvasLayer
## Інтерфейс поверх гри: сенсорне керування, смуги здоров'я й досвіду, написи,
## банер, підказки, червоні краї при пораненні, мапа, повноекранні екрани та меню-оверлеї.
## Сам нічого не вирішує: про натискання повідомляє сигналами, а Game вирішує, що робити.

signal attack_pressed
signal dodge_pressed
signal skill_pressed(id: String)
signal pause_pressed
signal character_pressed
signal map_pressed
signal map_location_selected(id: String)

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const WorldMap := preload("res://scripts/ui/world_map.gd")
const JoystickScript := preload("res://scripts/ui/joystick.gd")
const ActionButtonScript := preload("res://scripts/ui/action_button.gd")

var ui_root: Control
var stats_box: Control
var controls: Node2D
var joystick
var btn_attack
var btn_dodge
var skill_buttons := {}
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_label: Label
var level_label: Label
var quest_label: Label
var loc_label: Label
var sub_label: Label
var banner: Label
var pause_btn: Button
var char_btn: Button
var map_btn: Button
var map_view
var map_panel: PanelContainer
var screen_root: Control = null
var dialogue_root: Control = null
var vignette: TextureRect
var hint_panel: PanelContainer
var hint_label: Label
var overlay: ColorRect
var overlay_box: VBoxContainer
var _hint_tween: Tween
var _pulse := 0.0
var _time := 0.0
var _low_hp := false


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
	var skill_colors := {"whirl": Color(0.55, 0.3, 0.8), "lightning": Color(0.25, 0.55, 0.9), "musket": Color(0.45, 0.4, 0.3)}
	for id in Data.ACTIVE_SKILLS:
		var b = _action_button(Data.ACTIVE_LABELS[id], 54.0, skill_colors[id])
		b.triggered.connect(func(): skill_pressed.emit(id))
		b.visible = false
		skill_buttons[id] = b

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

	pause_btn = _corner_button("II", -96, -20, func(): pause_pressed.emit())
	char_btn = _corner_button("Козак", -290, -110, func(): character_pressed.emit())
	char_btn.add_theme_font_size_override("font_size", 24)
	map_btn = _corner_button("Мапа", -420, -305, func(): map_pressed.emit())
	map_btn.add_theme_font_size_override("font_size", 24)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.offset_bottom = -200
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_constant_override("outline_size", 10)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.z_index = 5
	ui_root.add_child(banner)

	hint_panel = PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 18)
	overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(overlay_box)


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
	xp_bar = _bar(Color(0.95, 0.75, 0.15), Vector2(20, 54), Vector2(340, 16))
	level_label = _stat_label(Vector2(20, 72), 22)
	quest_label = _stat_label(Vector2(20, 104), 16)
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


func _corner_button(text: String, left: float, right: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = left
	b.offset_right = right
	b.offset_top = 16
	b.offset_bottom = 88
	b.visible = false
	b.pressed.connect(cb)
	ui_root.add_child(b)
	return b


func _action_button(text: String, r: float, col: Color):
	var b = ActionButtonScript.new()
	b.label = text
	b.radius = r
	b.color = col
	controls.add_child(b)
	return b


func layout() -> void:
	var s := get_viewport().get_visible_rect().size
	joystick.rest_pos = Vector2(190, s.y - 180)
	joystick.queue_redraw()
	btn_attack.position = Vector2(s.x - 140, s.y - 140)
	btn_dodge.position = Vector2(s.x - 300, s.y - 80)
	skill_buttons["whirl"].position = Vector2(s.x - 120, s.y - 315)
	skill_buttons["lightning"].position = Vector2(s.x - 275, s.y - 255)
	skill_buttons["musket"].position = Vector2(s.x - 425, s.y - 105)
	map_view.map_rect = Rect2(Vector2(8, 96), Vector2(s.x - 410, s.y - 104))


# ======================= Режими показу =======================

## Що показувати: смуги героя (stats) і кнопки бою (combat).
func set_mode(show_stats: bool, combat: bool) -> void:
	stats_box.visible = show_stats
	pause_btn.visible = combat
	map_btn.visible = combat
	char_btn.visible = show_stats
	controls.visible = combat
	if not combat:
		joystick.release()


func show_map(v: bool) -> void:
	map_view.visible = v
	map_panel.visible = v


func set_map_panel(content: Control) -> void:
	for c in map_panel.get_children():
		c.queue_free()
	map_panel.add_child(content)


func move_vector() -> Vector2:
	return joystick.vector.limit_length(1.0)


# ======================= Оновлення =======================

## combat_info: {"name", "sub"} для бою або порожній словник.
func update(player: Player, world, combat_info: Dictionary, delta: float, story_line: String = "") -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "Здоров'я %d / %d" % [roundi(player.hp), roundi(player.max_hp)]
	xp_bar.max_value = player.xp_next
	xp_bar.value = player.xp
	level_label.text = "Рівень %d    Дукати: %d" % [player.level, player.gold]
	var ql := []
	if story_line != "":
		ql.append(story_line)
	for q in world.quests:
		ql.append("• %s %d/%d" % [q["text"], q["progress"], q["count"]] + ("  ✓" if world.is_done(q) else ""))
	quest_label.text = "\n".join(ql)
	loc_label.text = combat_info.get("name", "")
	sub_label.text = combat_info.get("sub", "")
	_low_hp = not combat_info.is_empty() and player.alive and player.hp < player.max_hp * 0.3
	if not combat_info.is_empty():
		btn_dodge.set_cooldown(player.dodge_timer / player.dodge_cooldown)
		for id in skill_buttons:
			var b = skill_buttons[id]
			b.visible = player.sk(id) > 0
			b.set_cooldown(player.skill_ready_ratio(id))
	var pts: int = player.unspent_points()
	if pts > 0:
		_pulse += maxf(delta, 0.016) * 5.0
		char_btn.text = "Козак +%d" % pts
		char_btn.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.25, 0.6), 0.5 + 0.5 * sin(_pulse))
	else:
		char_btn.text = "Козак"
		char_btn.modulate = Color.WHITE


func show_banner(text: String, col: Color = Color(1, 0.92, 0.7)) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	var tw := banner.create_tween()
	banner.modulate.a = 0.0
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.6)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


## Підказка. На мапі — внизу ліворуч (праворуч бічна панель), в інших режимах — угорі по центру.
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
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = hint_panel.create_tween()
	_hint_tween.tween_interval(8.0)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.6)
	_hint_tween.tween_callback(func(): hint_panel.visible = false)


# ======================= Повноекранні екрани =======================

func set_screen(c: Control) -> void:
	clear_screen()
	screen_root = c
	ui_root.add_child(c)
	ui_root.move_child(c, banner.get_index())


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
