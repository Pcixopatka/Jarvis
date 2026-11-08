extends Node2D
## Головний менеджер гри: світ, хвилі нечисті, інтерфейс, екран козака, меню, рекорд.

const ARENA := Rect2(-1400, -1400, 2800, 2800)
const SAVE_PATH := "user://save.cfg"

const Data := preload("res://scripts/data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const FloatTextScript := preload("res://scripts/float_text.gd")
const BoltScript := preload("res://scripts/bolt.gd")
const GroundScript := preload("res://scripts/ground.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const ActionButtonScript := preload("res://scripts/action_button.gd")

const GOLD := Color(1.0, 0.85, 0.3)
const TEXT := Color(0.95, 0.92, 0.85)
const MUTED := Color(0.7, 0.7, 0.7)

enum State { MENU, PLAYING, CHARACTER, PAUSED, GAMEOVER }

var state := State.MENU
var player
var camera: Camera2D
var entities: Node2D
var effects: Node2D

var wave := 0
var to_spawn := 0
var spawn_timer := 0.0
var spawn_interval := 1.0
var between_waves := -1.0
var kills := 0
var play_time := 0.0
var shake_strength := 0.0
var best_wave := 0
var best_kills := 0
var _pulse := 0.0

# Інтерфейс
var hud: CanvasLayer
var ui_root: Control
var stats_box: Control
var controls: Node2D
var joystick
var btn_attack
var btn_dodge
var skill_buttons := {}  # id -> кнопка
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_label: Label
var level_label: Label
var wave_label: Label
var kills_label: Label
var banner: Label
var pause_btn: Button
var char_btn: Button
var overlay: ColorRect
var overlay_center: CenterContainer
var overlay_box: VBoxContainer
var char_root: Control
var char_tab := 0


func _ready() -> void:
	randomize()
	# Менеджер працює і на паузі (меню, клавіші), а світ — ні.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_best()
	_build_world()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_main_menu()


# ============ Світ ============

func _build_world() -> void:
	var ground = GroundScript.new()
	ground.arena = ARENA
	ground.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ground)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	entities.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(entities)

	effects = Node2D.new()
	effects.z_index = 10
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)

	player = PlayerScript.new()
	player.main = self
	entities.add_child(player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_level_up)

	camera = Camera2D.new()
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = int(ARENA.position.x - 120)
	camera.limit_top = int(ARENA.position.y - 160)
	camera.limit_right = int(ARENA.end.x + 120)
	camera.limit_bottom = int(ARENA.end.y + 120)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	camera.global_position = player.global_position
	if shake_strength > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO

	play_time += delta
	player.attack_held = btn_attack.held or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_SPACE)
	btn_dodge.set_cooldown(player.dodge_timer / player.dodge_cooldown)
	for id in skill_buttons:
		var b = skill_buttons[id]
		b.visible = player.sk(id) > 0
		b.set_cooldown(player.skill_ready_ratio(id))
	_update_waves(delta)
	_update_hud(delta)


func _update_waves(delta: float) -> void:
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval
			spawn_enemy(_pick_kind())
			to_spawn -= 1
	elif alive_enemy_count() == 0:
		if between_waves < 0.0:
			between_waves = 2.5
			if wave > 0:
				show_banner("Хвилю %d відбито!" % wave, Color(0.6, 1.0, 0.6))
		else:
			between_waves -= delta
			if between_waves <= 0.0:
				between_waves = -1.0
				start_wave()


func start_wave() -> void:
	wave += 1
	to_spawn = 6 + wave * 4
	spawn_interval = maxf(0.22, 1.1 - wave * 0.07)
	spawn_timer = 0.5
	player.unbreak_ready = true
	if wave % 5 == 0:
		show_banner("Хвиля %d\nЗмій наближається!" % wave, Color(1.0, 0.55, 0.2))
		spawn_enemy("zmii")
	else:
		show_banner("Хвиля %d" % wave)


func _pick_kind() -> String:
	var pool := ["mavka", "mavka", "mavka", "mavka", "mavka"]
	if wave >= 2:
		pool.append_array(["upyr", "upyr", "upyr"])
	if wave >= 3:
		pool.append_array(["bolotianyk", "bolotianyk"])
	return pool[randi() % pool.size()]


func spawn_enemy(kind: String) -> void:
	var pos := Vector2.ZERO
	for i in 10:
		pos = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(700, 900)
		pos = pos.clamp(ARENA.position + Vector2(60, 60), ARENA.end - Vector2(60, 60))
		if pos.distance_to(player.global_position) > 450.0:
			break
	var e := EnemyScript.new()
	e.main = self
	e.position = pos
	e.setup(kind, wave)
	entities.add_child(e)


func _new_projectile(pos: Vector2, vel: Vector2, dmg: float):
	var p = ProjectileScript.new()
	p.main = self
	p.position = pos
	p.velocity = vel
	p.damage = dmg
	effects.add_child(p)
	return p


func spawn_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float) -> void:
	var p = _new_projectile(pos, dir * spd, dmg)
	p.color = col
	p.radius = r


func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, crit: bool) -> void:
	var p = _new_projectile(pos, dir * 950.0, dmg)
	p.friendly = true
	p.crit = crit
	p.radius = 6.0
	p.life = 0.9


func spawn_bolt(points: PackedVector2Array) -> void:
	var b = BoltScript.new()
	b.points = points
	effects.add_child(b)


func spawn_pickup(pos: Vector2, kind: String, value: int) -> void:
	var p = PickupScript.new()
	p.main = self
	p.kind = kind
	p.value = value
	p.position = pos
	p.spawn_vel = Vector2.from_angle(randf() * TAU) * randf_range(60, 200)
	entities.add_child(p)


func float_text(pos: Vector2, text: String, col: Color = Color.WHITE) -> void:
	var t = FloatTextScript.new()
	t.text = text
	t.color = col
	t.position = pos + Vector2(randf_range(-10, 10), 0)
	effects.add_child(t)


func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func nearest_enemy(from: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d: float = from.distance_to(e.global_position) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best


func alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func on_enemy_killed(e) -> void:
	kills += 1
	var heal_value := int(20 * (1.0 + 0.5 * player.varenyk_bonus))
	if e.is_boss:
		shake(14.0)
		show_banner("Змія переможено!", GOLD)
		for i in 12:
			spawn_pickup(e.global_position, "coin", 6)
		spawn_pickup(e.global_position, "varenyk", heal_value * 2)
	else:
		spawn_pickup(e.global_position, "coin", e.xp_value)
		if randf() < 0.05 * (1 + player.varenyk_bonus):
			spawn_pickup(e.global_position, "varenyk", heal_value)


func get_move_input() -> Vector2:
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if k != Vector2.ZERO:
		return k.normalized()
	return joystick.vector.limit_length(1.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var playing := state == State.PLAYING
	match event.physical_keycode:
		KEY_K, KEY_SHIFT:
			if playing: player.dodge()
		KEY_L, KEY_1:
			if playing: player.use_skill("whirl")
		KEY_I, KEY_2:
			if playing: player.use_skill("lightning")
		KEY_O, KEY_3:
			if playing: player.use_skill("musket")
		KEY_C, KEY_TAB:
			if playing:
				_show_character()
			elif state == State.CHARACTER:
				_resume()
		KEY_ESCAPE, KEY_P:
			if playing:
				_show_pause()
			elif state == State.PAUSED or state == State.CHARACTER:
				_resume()


func _notification(what: int) -> void:
	# Автопауза, коли гравець згортає гру або тисне «Назад» на Android.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.PLAYING:
			_show_pause()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == State.CHARACTER:
			_resume()


# ============ Події гри ============

func _on_level_up(lvl: int) -> void:
	show_banner("Рівень %d!\nВідкрий «Козак», щоб прокачатися" % lvl, GOLD)


func _on_player_died() -> void:
	state = State.GAMEOVER
	controls.visible = false
	pause_btn.visible = false
	char_btn.visible = false
	var new_record := wave > best_wave or (wave == best_wave and kills > best_kills)
	if new_record:
		best_wave = wave
		best_kills = kills
		_save_best()
	show_banner("Козак поліг...", Color(1.0, 0.4, 0.35))
	await get_tree().create_timer(1.4).timeout
	_show_gameover(new_record)


func _start_game() -> void:
	_resume()
	stats_box.visible = true
	between_waves = 1.0
	_update_hud(0.0)


func _resume() -> void:
	_close_overlay()
	state = State.PLAYING
	get_tree().paused = false
	controls.visible = true
	pause_btn.visible = true
	char_btn.visible = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ============ Збереження ============

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_wave = int(cfg.get_value("best", "wave", 0))
		best_kills = int(cfg.get_value("best", "kills", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("best", "wave", best_wave)
	cfg.set_value("best", "kills", best_kills)
	cfg.save(SAVE_PATH)


# ============ Інтерфейс ============

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.set_stylebox("normal", "Button", _style(Color(0.55, 0.12, 0.1), Color(0.95, 0.75, 0.2)))
	th.set_stylebox("hover", "Button", _style(Color(0.68, 0.18, 0.12), Color(0.95, 0.75, 0.2)))
	th.set_stylebox("pressed", "Button", _style(Color(0.4, 0.08, 0.06), Color(0.95, 0.75, 0.2)))
	th.set_stylebox("disabled", "Button", _style(Color(0.2, 0.17, 0.15), Color(0.4, 0.35, 0.3)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 30)
	th.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_disabled_color", "Button", Color(0.62, 0.6, 0.57))
	th.set_font_size("font_size", "Label", 26)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 6)
	th.set_font_size("font_size", "TabContainer", 26)
	th.set_stylebox("panel", "TabContainer", _style(Color(0.1, 0.08, 0.07, 0.92), Color(0.6, 0.45, 0.15)))
	th.set_stylebox("tab_selected", "TabContainer", _style(Color(0.55, 0.12, 0.1), Color(0.95, 0.75, 0.2)))
	th.set_stylebox("tab_unselected", "TabContainer", _style(Color(0.2, 0.15, 0.12), Color(0.45, 0.35, 0.2)))
	th.set_stylebox("tab_hovered", "TabContainer", _style(Color(0.35, 0.12, 0.1), Color(0.75, 0.55, 0.2)))
	th.set_color("font_selected_color", "TabContainer", Color(1, 0.95, 0.8))
	th.set_color("font_unselected_color", "TabContainer", Color(0.75, 0.7, 0.6))
	th.set_color("font_hovered_color", "TabContainer", Color(1, 0.9, 0.75))
	return th


func _make_bar(fill: Color) -> ProgressBar:
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
	return bar


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	# Сенсорне керування
	controls = Node2D.new()
	hud.add_child(controls)
	joystick = JoystickScript.new()
	controls.add_child(joystick)
	btn_attack = _make_action_button("Шабля", 86.0, Color(0.75, 0.15, 0.12))
	btn_attack.triggered.connect(_on_attack_button)
	btn_dodge = _make_action_button("Перекид", 56.0, Color(0.2, 0.45, 0.75))
	btn_dodge.triggered.connect(_on_dodge_button)
	var skill_colors := {"whirl": Color(0.55, 0.3, 0.8), "lightning": Color(0.25, 0.55, 0.9), "musket": Color(0.45, 0.4, 0.3)}
	for id in Data.ACTIVE_SKILLS:
		var b = _make_action_button(Data.ACTIVE_LABELS[id], 54.0, skill_colors[id])
		b.triggered.connect(_on_skill_button.bind(id))
		b.visible = false
		skill_buttons[id] = b

	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	hud.add_child(ui_root)

	stats_box = Control.new()
	stats_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.visible = false
	ui_root.add_child(stats_box)

	hp_bar = _make_bar(Color(0.85, 0.15, 0.15))
	hp_bar.position = Vector2(20, 18)
	hp_bar.size = Vector2(340, 30)
	stats_box.add_child(hp_bar)
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 20)
	hp_label.position = Vector2(30, 18)
	hp_label.size = Vector2(320, 30)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_box.add_child(hp_label)

	xp_bar = _make_bar(Color(0.95, 0.75, 0.15))
	xp_bar.position = Vector2(20, 54)
	xp_bar.size = Vector2(340, 16)
	stats_box.add_child(xp_bar)

	level_label = Label.new()
	level_label.position = Vector2(20, 74)
	stats_box.add_child(level_label)

	wave_label = Label.new()
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.anchor_right = 1.0
	wave_label.offset_top = 14
	stats_box.add_child(wave_label)

	kills_label = Label.new()
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label.anchor_right = 1.0
	kills_label.offset_top = 48
	kills_label.add_theme_font_size_override("font_size", 20)
	stats_box.add_child(kills_label)

	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.offset_bottom = -200
	banner.add_theme_font_size_override("font_size", 52)
	banner.add_theme_constant_override("outline_size", 10)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(banner)

	pause_btn = _make_corner_button("II", -96, -20)
	pause_btn.pressed.connect(_on_pause_button)
	char_btn = _make_corner_button("Козак", -290, -110)
	char_btn.add_theme_font_size_override("font_size", 26)
	char_btn.pressed.connect(_on_char_button)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(overlay)
	overlay_center = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_center)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 18)
	overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_center.add_child(overlay_box)


func _make_corner_button(text: String, left: float, right: float) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = left
	b.offset_right = right
	b.offset_top = 16
	b.offset_bottom = 88
	b.visible = false
	ui_root.add_child(b)
	return b


func _on_attack_button() -> void:
	if state == State.PLAYING:
		player.attack()


func _on_dodge_button() -> void:
	if state == State.PLAYING:
		player.dodge()


func _on_skill_button(id: String) -> void:
	if state == State.PLAYING:
		player.use_skill(id)


func _on_pause_button() -> void:
	if state == State.PLAYING:
		_show_pause()


func _on_char_button() -> void:
	if state == State.PLAYING:
		_show_character()


func _make_action_button(text: String, r: float, col: Color):
	var b = ActionButtonScript.new()
	b.label = text
	b.radius = r
	b.color = col
	controls.add_child(b)
	return b


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	joystick.rest_pos = Vector2(190, s.y - 180)
	joystick.queue_redraw()
	btn_attack.position = Vector2(s.x - 140, s.y - 140)
	btn_dodge.position = Vector2(s.x - 300, s.y - 80)
	skill_buttons["whirl"].position = Vector2(s.x - 120, s.y - 315)
	skill_buttons["lightning"].position = Vector2(s.x - 275, s.y - 255)
	skill_buttons["musket"].position = Vector2(s.x - 425, s.y - 105)


func _update_hud(delta: float) -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "Здоров'я %d / %d" % [int(ceil(player.hp)), int(player.max_hp)]
	xp_bar.max_value = player.xp_next
	xp_bar.value = player.xp
	level_label.text = "Рівень %d" % player.level
	wave_label.text = "Хвиля %d" % wave if wave > 0 else ""
	kills_label.text = "Знищено нечисті: %d" % kills
	var pts: int = player.unspent_points()
	if pts > 0:
		_pulse += delta * 5.0
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


# --- Екрани-оверлеї ---

func _open_overlay() -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	if char_root:
		char_root.queue_free()
		char_root = null
	overlay.visible = true
	overlay_center.visible = true
	controls.visible = false
	pause_btn.visible = false
	char_btn.visible = false
	joystick.release()
	banner.visible = false
	get_tree().paused = true


func _close_overlay() -> void:
	overlay.visible = false
	banner.visible = true
	for c in overlay_box.get_children():
		c.queue_free()
	if char_root:
		char_root.queue_free()
		char_root = null


func _label(text: String, size: int = 26, col: Color = TEXT, center := true) -> Label:
	var l := Label.new()
	l.text = text
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _add_title(text: String, size: int = 56, col: Color = GOLD) -> Label:
	var l := _label(text, size, col)
	overlay_box.add_child(l)
	return l


func _add_button(text: String, cb: Callable, min_size := Vector2(460, 84)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(cb)
	overlay_box.add_child(b)
	return b


func _show_main_menu() -> void:
	state = State.MENU
	_open_overlay()
	_add_title("Козацька Звитяга", 72)
	_add_title("Нечисть лізе з Дикого Поля! Захисти рідний хутір.", 26, TEXT)
	if best_wave > 0:
		_add_title("Рекорд: хвиля %d, знищено %d" % [best_wave, best_kills], 22, Color(0.7, 0.9, 1.0))
	_add_button("В бій!", _start_game)
	_add_title("Ліва частина екрана — рух.  Праворуч — шабля, перекид і вміння.\nКнопка «Козак» — характеристики, вміння та перки.", 20, Color(0.8, 0.8, 0.8))


func _show_pause() -> void:
	state = State.PAUSED
	_open_overlay()
	_add_title("Пауза")
	_add_button("Продовжити", _resume)
	_add_button("Козак", _show_character)
	_add_button("Почати заново", _restart)


func _show_gameover(new_record: bool) -> void:
	_open_overlay()
	_add_title("Козак поліг", 64, Color(1.0, 0.45, 0.35))
	var mins := int(play_time) / 60
	var secs := int(play_time) % 60
	_add_title("Хвиля %d  •  Рівень %d  •  Нечисті знищено: %d  •  Час %d:%02d" % [wave, player.level, kills, mins, secs], 26, TEXT)
	if new_record:
		_add_title("Новий рекорд!", 32, Color(0.6, 1.0, 0.6))
	else:
		_add_title("Рекорд: хвиля %d, знищено %d" % [best_wave, best_kills], 22, Color(0.7, 0.9, 1.0))
	_add_button("Ще раз!", _restart)


# ============ Екран козака: характеристики, вміння, перки ============

func _show_character() -> void:
	state = State.CHARACTER
	_open_overlay()
	overlay_center.visible = false
	_build_character()


func _refresh_character() -> void:
	if char_root:
		char_root.queue_free()
	_build_character()


func _build_character() -> void:
	char_root = MarginContainer.new()
	char_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		char_root.add_theme_constant_override("margin_" + side, 16)
	overlay.add_child(char_root)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	char_root.add_child(v)

	var header := HBoxContainer.new()
	var title := _label("Козак — рівень %d" % player.level, 36, GOLD, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "До бою"
	close.custom_minimum_size = Vector2(220, 64)
	close.pressed.connect(_resume)
	header.add_child(close)
	v.add_child(header)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_scroll(_build_stats_tab()))
	tabs.add_child(_scroll(_build_skills_tab()))
	tabs.add_child(_scroll(_build_perks_tab()))
	tabs.set_tab_title(0, "Характеристики" + _pts_suffix(player.stat_points))
	tabs.set_tab_title(1, "Вміння" + _pts_suffix(player.skill_points))
	tabs.set_tab_title(2, "Перки" + _pts_suffix(player.perk_points))
	tabs.current_tab = char_tab
	tabs.tab_changed.connect(func(i: int): char_tab = i)


func _pts_suffix(n: int) -> String:
	return "  (+%d)" % n if n > 0 else ""


func _scroll(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_child(content)
	sc.add_child(m)
	return sc


func _build_stats_tab() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(_label("Вільні очки: %d   (+%d за рівень)" % [player.stat_points, Data.STAT_POINTS_PER_LEVEL], 26, GOLD if player.stat_points > 0 else MUTED, false))
	for st in Data.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val: int = player.stat(st["id"])
		info.add_child(_label("%s: %d" % [st["name"], val], 30, TEXT, false))
		info.add_child(_label(st["desc"], 18, MUTED, false))
		row.add_child(info)
		var b := Button.new()
		b.text = "+"
		b.custom_minimum_size = Vector2(90, 72)
		b.disabled = player.stat_points <= 0
		b.pressed.connect(_on_add_stat.bind(st["id"]))
		row.add_child(b)
		left.add_child(row)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size = Vector2(380, 0)
	h.add_child(right)
	right.add_child(_label("Бойові показники", 26, GOLD, false))
	var p = player
	var lines := [
		["Здоров'я", "%d / %d" % [int(p.hp), int(p.max_hp)]],
		["Шкода шаблею", "%.1f" % p.damage],
		["Ударів за секунду", "%.2f" % (1.0 / p.attack_cooldown)],
		["Шанс криту", "%d%%  (x%.0f)" % [roundi(p.crit_chance * 100), p.crit_mult]],
		["Дальність удару", "%d" % int(p.attack_range)],
		["Захист", "%d%%" % roundi(p.armor * 100)],
		["Швидкість бігу", "%d" % int(p.speed)],
		["Сила вмінь", "%d%%" % roundi(p.skill_power * 100)],
		["Перезарядка вмінь", "%d%%" % roundi(p.skill_cd_mult * 100)],
		["Відновлення", "%.1f / с" % p.regen],
		["Вампіризм", "%d%%" % roundi(p.lifesteal * 100)],
		["Бонус досвіду", "+%d%%" % roundi((p.xp_mult - 1.0) * 100)],
	]
	for l in lines:
		var row := HBoxContainer.new()
		var k := _label(l[0], 20, MUTED, false)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		row.add_child(_label(l[1], 20, TEXT, false))
		right.add_child(row)
	return h


func _connector() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.85, 0.65, 0.2, 0.8)
	c.custom_minimum_size = Vector2(6, 22)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _tree_button(text: String, rank: int, max_rank: int, can: bool, locked: bool, font: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.disabled = not can
	if rank >= max_rank:
		b.add_theme_stylebox_override("disabled", _style(Color(0.15, 0.32, 0.15), Color(0.5, 0.9, 0.4)))
		b.add_theme_color_override("font_disabled_color", Color(0.85, 1.0, 0.8))
	elif rank > 0:
		b.add_theme_stylebox_override("disabled", _style(Color(0.35, 0.12, 0.1), Color(0.8, 0.6, 0.2)))
		b.add_theme_color_override("font_disabled_color", Color(0.95, 0.88, 0.75))
	elif locked:
		b.modulate = Color(1, 1, 1, 0.6)
	return b


func _build_skills_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(_label("Очки вмінь: %d   (+%d за рівень).  Активні вміння з'являються кнопками в бою." % [player.skill_points, Data.SKILL_POINTS_PER_LEVEL], 22, GOLD if player.skill_points > 0 else MUTED))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	for branch in Data.SKILL_BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(_label(branch["name"], 30, GOLD))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		col.add_child(spacer)
		var nodes: Array = branch["nodes"]
		for i in nodes.size():
			var n: Dictionary = nodes[i]
			if i > 0:
				col.add_child(_connector())
			var rank: int = player.sk(n["id"])
			var req_met: bool = player.skill_req_met(n)
			var text := "%s   %d/%d\n%s" % [n["name"], rank, n["max"], n["desc"]]
			if not req_met:
				var reqs := []
				for r in n["req"]:
					if player.sk(r) < n["req"][r]:
						reqs.append("%s %d" % [Data.skill_name(r), n["req"][r]])
				text += "\nПотрібно: " + ", ".join(reqs)
			elif n.get("active", false):
				text += "\nАктивне вміння"
			var b := _tree_button(text, rank, n["max"], player.can_learn_skill(n), not req_met, 17, Vector2(320, 120))
			b.pressed.connect(_on_learn_skill.bind(n["id"]))
			col.add_child(b)
		h.add_child(col)
	return v


func _build_perks_tab() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(_label("Очки перків: %d   (+%d за рівень).  Новий ярус відкривається за кожні %d очки, вкладені в гілку." % [player.perk_points, Data.PERK_POINTS_PER_LEVEL, Data.PERK_TIER_STEP], 22, GOLD if player.perk_points > 0 else MUTED))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	for bi in Data.PERK_BRANCHES.size():
		var branch: Dictionary = Data.PERK_BRANCHES[bi]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(_label("%s  (%d)" % [branch["name"], player.branch_perk_points(bi)], 28, GOLD))
		var tiers: Array = branch["tiers"]
		for ti in tiers.size():
			var open: bool = player.perk_tier_open(bi, ti)
			if ti > 0:
				col.add_child(_connector())
			if not open:
				col.add_child(_label("Ярус %d: ще %d очк. у гілку" % [ti + 1, ti * Data.PERK_TIER_STEP - player.branch_perk_points(bi)], 16, MUTED))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			for p in tiers[ti]:
				var rank: int = player.pk(p["id"])
				var text := "%s  %d/%d\n%s" % [p["name"], rank, p["max"], p["desc"]]
				var w := 340.0 if tiers[ti].size() == 1 else 166.0
				var b := _tree_button(text, rank, p["max"], player.can_learn_perk(p["id"]), not open, 14, Vector2(w, 88))
				b.pressed.connect(_on_learn_perk.bind(p["id"]))
				row.add_child(b)
			col.add_child(row)
		h.add_child(col)
	return v


func _on_add_stat(id: String) -> void:
	if player.add_stat(id):
		_refresh_character()


func _on_learn_skill(id: String) -> void:
	if player.learn_skill(id):
		_refresh_character()


func _on_learn_perk(id: String) -> void:
	if player.learn_perk(id):
		_refresh_character()
