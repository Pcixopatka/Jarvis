extends Node2D
## Головний менеджер гри: світ, хвилі нечисті, інтерфейс, меню, збереження рекорду.

const ARENA := Rect2(-1400, -1400, 2800, 2800)
const SAVE_PATH := "user://save.cfg"

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const FloatTextScript := preload("res://scripts/float_text.gd")
const GroundScript := preload("res://scripts/ground.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const ActionButtonScript := preload("res://scripts/action_button.gd")

const UPGRADES := [
	{"id": "damage", "name": "Гостра шабля", "desc": "+25% до шкоди"},
	{"id": "hp", "name": "Козацьке здоров'я", "desc": "+25 до здоров'я"},
	{"id": "speed", "name": "Легкі чоботи", "desc": "+12% до швидкості"},
	{"id": "attack_speed", "name": "Швидка рука", "desc": "Шабля б'є на 15% частіше"},
	{"id": "range", "name": "Довга шабля", "desc": "+20% до дальності удару"},
	{"id": "skill", "name": "Характерник", "desc": "Вихор заряджається на 20% швидше"},
	{"id": "heal", "name": "Бабусин узвар", "desc": "Відновлює 50% здоров'я"},
	{"id": "magnet", "name": "Жадібний гаманець", "desc": "+40% радіус збору дукатів"},
	{"id": "armor", "name": "Оберіг", "desc": "-12% отриманої шкоди"},
	{"id": "crit", "name": "Козацька вдача", "desc": "+8% шансу критичного удару"},
]

enum State { MENU, PLAYING, LEVELUP, PAUSED, GAMEOVER }

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
var pending_levelups := 0
var shake_strength := 0.0
var best_wave := 0
var best_kills := 0

# Інтерфейс
var hud: CanvasLayer
var ui_root: Control
var stats_box: Control
var controls: Node2D
var joystick
var btn_attack
var btn_dodge
var btn_skill
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_label: Label
var level_label: Label
var wave_label: Label
var kills_label: Label
var banner: Label
var pause_btn: Button
var overlay: ColorRect
var overlay_box: VBoxContainer


func _ready() -> void:
	randomize()
	_load_best()
	_build_world()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_main_menu()


# ============ Світ ============

func _build_world() -> void:
	var ground = Node2D.new()
	ground.set_script(GroundScript)
	ground.arena = ARENA
	add_child(ground)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	effects = Node2D.new()
	effects.z_index = 10
	add_child(effects)

	player = PlayerScript.new()
	player.main = self
	player.position = Vector2.ZERO
	entities.add_child(player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_level_up)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = int(ARENA.position.x - 120)
	camera.limit_top = int(ARENA.position.y - 160)
	camera.limit_right = int(ARENA.end.x + 120)
	camera.limit_bottom = int(ARENA.end.y + 120)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	camera.global_position = player.global_position
	if shake_strength > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO

	if state != State.PLAYING:
		return
	play_time += delta
	player.attack_held = btn_attack.held or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_SPACE)
	btn_dodge.set_cooldown(player.dodge_timer / player.dodge_cooldown)
	btn_skill.set_cooldown(player.skill_timer / player.skill_cooldown)
	_update_waves(delta)
	_update_hud()


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


func spawn_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float) -> void:
	var p = Node2D.new()
	p.set_script(ProjectileScript)
	p.main = self
	p.position = pos
	p.velocity = dir * spd
	p.damage = dmg
	p.color = col
	p.radius = r
	effects.add_child(p)


func spawn_pickup(pos: Vector2, kind: String, value: int) -> void:
	var p = Node2D.new()
	p.set_script(PickupScript)
	p.main = self
	p.kind = kind
	p.value = value
	p.position = pos
	p.spawn_vel = Vector2.from_angle(randf() * TAU) * randf_range(60, 200)
	entities.add_child(p)


func float_text(pos: Vector2, text: String, col: Color = Color.WHITE) -> void:
	var t = Node2D.new()
	t.set_script(FloatTextScript)
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
	if e.is_boss:
		shake(14.0)
		show_banner("Змія переможено!", Color(1.0, 0.85, 0.3))
		for i in 12:
			spawn_pickup(e.global_position, "coin", 6)
		spawn_pickup(e.global_position, "varenyk", 40)
	else:
		spawn_pickup(e.global_position, "coin", e.xp_value)
		if randf() < 0.05:
			spawn_pickup(e.global_position, "varenyk", 20)


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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_K, KEY_SHIFT:
				if state == State.PLAYING:
					player.dodge()
			KEY_L:
				if state == State.PLAYING:
					player.skill()
			KEY_ESCAPE, KEY_P:
				if state == State.PLAYING:
					_show_pause()
				elif state == State.PAUSED:
					_resume()


func _notification(what: int) -> void:
	# Автопауза, коли гравець згортає гру або повертається «назад» на Android.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.PLAYING:
			_show_pause()


# ============ Події гри ============

func _on_level_up(_lvl: int) -> void:
	pending_levelups += 1
	if state == State.PLAYING:
		_show_levelup()


func _on_player_died() -> void:
	state = State.GAMEOVER
	controls.visible = false
	pause_btn.visible = false
	var new_record := wave > best_wave or (wave == best_wave and kills > best_kills)
	if new_record:
		best_wave = wave
		best_kills = kills
		_save_best()
	show_banner("Козак поліг...", Color(1.0, 0.4, 0.35))
	await get_tree().create_timer(1.4).timeout
	_show_gameover(new_record)


func _start_game() -> void:
	_close_overlay()
	stats_box.visible = true
	_update_hud()
	state = State.PLAYING
	get_tree().paused = false
	controls.visible = true
	pause_btn.visible = true
	between_waves = 1.0


func _resume() -> void:
	_close_overlay()
	state = State.PLAYING
	get_tree().paused = false
	controls.visible = true
	pause_btn.visible = true
	if pending_levelups > 0:
		_show_levelup()


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

func _make_theme() -> Theme:
	var th := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.55, 0.12, 0.1)
	normal.border_color = Color(0.95, 0.75, 0.2)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(16)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.68, 0.18, 0.12)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.4, 0.08, 0.06)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 30)
	th.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	th.set_font_size("font_size", "Label", 26)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 6)
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
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	# Сенсорне керування (малюється під меню)
	controls = Node2D.new()
	hud.add_child(controls)
	joystick = JoystickScript.new()
	controls.add_child(joystick)
	btn_attack = _make_action_button("Шабля", 86.0, Color(0.75, 0.15, 0.12))
	btn_attack.triggered.connect(_on_attack_button)
	btn_dodge = _make_action_button("Перекид", 58.0, Color(0.2, 0.45, 0.75))
	btn_dodge.triggered.connect(_on_dodge_button)
	btn_skill = _make_action_button("Вихор", 58.0, Color(0.55, 0.3, 0.8))
	btn_skill.triggered.connect(_on_skill_button)

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
	banner.add_theme_font_size_override("font_size", 56)
	banner.add_theme_constant_override("outline_size", 10)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(banner)

	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -96
	pause_btn.offset_right = -20
	pause_btn.offset_top = 16
	pause_btn.offset_bottom = 88
	pause_btn.pressed.connect(_on_pause_button)
	ui_root.add_child(pause_btn)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 18)
	overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(overlay_box)


func _on_attack_button() -> void:
	if state == State.PLAYING:
		player.attack()


func _on_dodge_button() -> void:
	if state == State.PLAYING:
		player.dodge()


func _on_skill_button() -> void:
	if state == State.PLAYING:
		player.skill()


func _on_pause_button() -> void:
	if state == State.PLAYING:
		_show_pause()


func _make_action_button(text: String, r: float, col: Color):
	var b = Node2D.new()
	b.set_script(ActionButtonScript)
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
	btn_dodge.position = Vector2(s.x - 300, s.y - 90)
	btn_skill.position = Vector2(s.x - 110, s.y - 310)


func _update_hud() -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "Здоров'я %d / %d" % [int(ceil(player.hp)), int(player.max_hp)]
	xp_bar.max_value = player.xp_next
	xp_bar.value = player.xp
	level_label.text = "Рівень %d" % player.level
	wave_label.text = "Хвиля %d" % wave if wave > 0 else ""
	kills_label.text = "Знищено нечисті: %d" % kills


func show_banner(text: String, col: Color = Color(1, 0.92, 0.7)) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	var tw := banner.create_tween()
	banner.modulate.a = 0.0
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


# --- Екрани-оверлеї ---

func _open_overlay() -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	overlay.visible = true
	controls.visible = false
	joystick.release()
	get_tree().paused = true


func _close_overlay() -> void:
	overlay.visible = false
	for c in overlay_box.get_children():
		c.queue_free()


func _add_title(text: String, size: int = 56, col: Color = Color(1.0, 0.85, 0.3)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
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
	pause_btn.visible = false
	_open_overlay()
	_add_title("Козацька Звитяга", 72)
	_add_title("Нечисть лізе з Дикого Поля! Захисти рідний хутір.", 26, Color(0.95, 0.92, 0.85))
	if best_wave > 0:
		_add_title("Рекорд: хвиля %d, знищено %d" % [best_wave, best_kills], 22, Color(0.7, 0.9, 1.0))
	_add_button("В бій!", _start_game)
	_add_title("Ліва частина екрана — рух.  Праворуч — Шабля, Перекид, Вихор.", 20, Color(0.8, 0.8, 0.8))


func _show_pause() -> void:
	state = State.PAUSED
	_open_overlay()
	_add_title("Пауза")
	_add_button("Продовжити", _resume)
	_add_button("Почати заново", _restart)


func _show_levelup() -> void:
	state = State.LEVELUP
	_open_overlay()
	_add_title("Новий рівень! (%d)" % player.level)
	_add_title("Обери козацьку науку:", 26, Color(0.95, 0.92, 0.85))
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	for i in 3:
		var up: Dictionary = pool[i]
		_add_button("%s\n%s" % [up["name"], up["desc"]], _pick_upgrade.bind(up["id"]), Vector2(560, 100))


func _pick_upgrade(id: String) -> void:
	player.apply_upgrade(id)
	pending_levelups -= 1
	if pending_levelups > 0:
		_show_levelup()
	else:
		_resume()


func _show_gameover(new_record: bool) -> void:
	_open_overlay()
	_add_title("Козак поліг", 64, Color(1.0, 0.45, 0.35))
	var mins := int(play_time) / 60
	var secs := int(play_time) % 60
	_add_title("Хвиля %d  •  Нечисті знищено: %d  •  Час %d:%02d" % [wave, kills, mins, secs], 26, Color(0.95, 0.92, 0.85))
	if new_record:
		_add_title("Новий рекорд!", 32, Color(0.6, 1.0, 0.6))
	else:
		_add_title("Рекорд: хвиля %d, знищено %d" % [best_wave, best_kills], 22, Color(0.7, 0.9, 1.0))
	_add_button("Ще раз!", _restart)
