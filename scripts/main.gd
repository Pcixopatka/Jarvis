extends Node2D
## Головний менеджер гри: мапа України, міста, місцевості, печери, бій, інтерфейс, збереження.

const SAVE_PATH := "user://hero.save"

const Data := preload("res://scripts/data.gd")
const UI := preload("res://scripts/ui_kit.gd")
const UiCharacter := preload("res://scripts/ui_character.gd")
const UiCity := preload("res://scripts/ui_city.gd")
const WorldState := preload("res://scripts/world_state.gd")
const WorldMap := preload("res://scripts/world_map.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const CompanionScript := preload("res://scripts/companion.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const PortalScript := preload("res://scripts/portal.gd")
const FloatTextScript := preload("res://scripts/float_text.gd")
const BoltScript := preload("res://scripts/bolt.gd")
const GroundScript := preload("res://scripts/ground.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const ActionButtonScript := preload("res://scripts/action_button.gd")
const AudioScript := preload("res://scripts/audio.gd")
const FxScript := preload("res://scripts/fx.gd")
const AmbientScript := preload("res://scripts/ambient.gd")
const SETTINGS_PATH := "user://settings.cfg"

# Тон освітлення для кожного ландшафту (CanvasModulate)
const BIOME_TINT := {
	"steppe": Color(1.0, 0.97, 0.9), "river": Color(0.97, 1.0, 1.0), "forest": Color(0.82, 0.92, 0.82),
	"swamp": Color(0.78, 0.86, 0.8), "mountain": Color(0.92, 0.95, 1.0), "cave": Color(0.2, 0.18, 0.25),
}

enum State { MENU, MAP, CITY, PLAYING, CHARACTER, PAUSED, DEAD }

var state := State.MENU
var arena := Rect2(-1400, -1400, 2800, 2800)
var player = null
var world = WorldState.new()
var camera: Camera2D
var ground
var entities: Node2D
var effects: Node2D
var companion_nodes := []
var audio
var fx
var ambient
var canvas_mod: CanvasModulate
var lights: Node2D
var torch: PointLight2D
var light_tex: GradientTexture2D
var _hitstop_active := false
var _time := 0.0

# Очищення дикої місцевості
var field_kills := 0
var field_goal := 0
var field_cleared := false

# Поточна локація
var loc_id := ""
var loc := {}
var room := 0
var room_cleared := false
var portal = null
var spawn_timer := 0.0
var city_id := ""
var map_here := "sich"
var map_sel := ""

var shake_strength := 0.0
var _pulse := 0.0

# Інтерфейс
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
var vignette: TextureRect
var hint_panel: PanelContainer
var hint_label: Label
var _hint_tween: Tween
var overlay: ColorRect
var overlay_box: VBoxContainer

# Стан екранів
var char_tab := 0
var char_sel_uid := -1
var char_return := State.MAP
var city_tab := 0
var city_sel_uid := -1
var smith_msg := ""
var smith_msg_color := Color.WHITE


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio = AudioScript.new()
	add_child(audio)
	_load_settings()
	# Клацання для всіх кнопок інтерфейсу
	get_tree().node_added.connect(func(n):
		if n is BaseButton:
			n.pressed.connect(func(): audio.play("click", 0.05, -6.0)))
	_build_world()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_main_menu()


# ======================= Світ і герой =======================

func _build_world() -> void:
	ground = GroundScript.new()
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
	lights = Node2D.new()
	lights.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(lights)
	fx = FxScript.new()
	fx.z_index = 11
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fx)
	ambient = AmbientScript.new()
	ambient.main = self
	ambient.z_index = 12
	ambient.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ambient)
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = Color.WHITE
	add_child(canvas_mod)
	light_tex = GradientTexture2D.new()
	light_tex.width = 256
	light_tex.height = 256
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	light_tex.gradient = g
	camera = Camera2D.new()
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()
	_set_world_visible(false)


func _new_hero(data: Dictionary) -> void:
	if player:
		player.queue_free()
	player = PlayerScript.new()
	player.main = self
	if not data.is_empty():
		player.from_dict(data)
	entities.add_child(player)
	torch = PointLight2D.new()
	torch.texture = light_tex
	torch.texture_scale = 4.5
	torch.color = Color(1.0, 0.8, 0.55)
	torch.energy = 1.2
	torch.enabled = false
	torch.position = Vector2(0, -20)
	player.add_child(torch)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_level_up)


func _set_world_visible(v: bool) -> void:
	ground.visible = v
	entities.visible = v
	effects.visible = v
	fx.visible = v
	ambient.visible = v
	lights.visible = v
	canvas_mod.visible = v


func _new_game() -> void:
	world = WorldState.new()
	_new_hero({})
	player.gold = 60
	map_here = "sich"
	enter_city("sich")
	show_banner("Ласкаво просимо на Січ!\nВізьми завдання на дошці оголошень", UI.GOLD)


func save_game() -> void:
	if player == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({"version": 2, "player": player.to_dict(), "world": world.to_dict()})
		f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	f.close()
	if typeof(d) != TYPE_DICTIONARY or d.get("version", 0) != 2:
		return false
	world = WorldState.new()
	world.from_dict(d["world"])
	_new_hero(d["player"])
	return true


# ======================= Режими =======================

func enter_map() -> void:
	_clear_combat()
	_clear_screen()
	_close_overlay()
	state = State.MAP
	Engine.time_scale = 1.0
	audio.play_music("calm")
	get_tree().paused = true
	_set_world_visible(false)
	controls.visible = false
	map_view.visible = true
	map_panel.visible = true
	map_view.current = map_here
	map_view.focus_on(map_here)
	map_view.selected = map_sel
	map_view.hero_level = player.level
	map_view.targets = world.quest_targets()
	_hud_mode(true, false)
	_build_map_panel()
	_update_hud(0.0)
	save_game()
	hint("map", "Торкнись місця на мапі. «!» позначає твоє завдання. Почни з Дикого Поля поруч із Січчю.")


func enter_city(id: String) -> void:
	_clear_combat()
	_close_overlay()
	state = State.CITY
	Engine.time_scale = 1.0
	audio.play_music("calm")
	get_tree().paused = true
	city_id = id
	map_here = id
	world.last_city = id
	player.revive()
	world.revive_companions()
	_set_world_visible(false)
	controls.visible = false
	map_view.visible = false
	map_panel.visible = false
	_hud_mode(false, false)
	city_sel_uid = -1
	smith_msg = ""
	_build_city()
	save_game()
	hint("city", "Це місто. На вкладці «Завдання» візьми доручення, у «Крамниці» купи спорядження, а потім натисни «На мапу».")


func leave_city() -> void:
	enter_map()


func enter_location(id: String) -> void:
	loc_id = id
	loc = Data.LOCATIONS[id]
	map_here = id
	for cid in Data.CITIES:
		world.shop_dirty[cid] = true
	_clear_screen()
	_close_overlay()
	room = 1 if loc["type"] == "dungeon" else 0
	_setup_arena()
	map_view.visible = false
	map_panel.visible = false
	_set_world_visible(true)
	controls.visible = true
	_hud_mode(true, true)
	state = State.PLAYING
	get_tree().paused = false
	player.unbreak_ready = true
	spawn_timer = 1.0
	field_kills = 0
	field_goal = 20 + loc["level"] * 3
	field_cleared = false
	audio.play_music("battle")
	hint("combat", "Ліва частина екрана — рух. Тримай «Удар» — козак сам б'є найближчу нечисть. Коли ворог червоніє — він замахується: тисни «Перекид»!")
	if loc["type"] == "dungeon":
		_spawn_room()
	else:
		show_banner(loc["name"])
		var en: Array = loc["enemies"]
		for i in 5:
			var pos: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * randf_range(450, 650)
			spawn_enemy(en[randi() % en.size()], loc["level"], false, pos.clamp(arena.position + Vector2(60, 60), arena.end - Vector2(60, 60)))
	_update_hud(0.0)


func _setup_arena() -> void:
	_clear_combat()
	if loc["type"] == "dungeon":
		arena = Rect2(-750, -550, 1500, 1100)
		player.position = Vector2(0, arena.end.y - 160)
	else:
		arena = Rect2(-1400, -1400, 2800, 2800)
		player.position = Vector2.ZERO
	ground.setup(arena, loc["biome"], hash(loc_id) + room * 31)
	_setup_atmosphere(loc["biome"])
	camera.limit_left = int(arena.position.x - 120)
	camera.limit_top = int(arena.position.y - 160)
	camera.limit_right = int(arena.end.x + 120)
	camera.limit_bottom = int(arena.end.y + 120)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	_spawn_companions()


func _clear_combat() -> void:
	for c in entities.get_children():
		if c == player:
			continue
		if c.is_in_group("enemies"):
			c.remove_from_group("enemies")
		c.queue_free()
	companion_nodes.clear()
	for c in effects.get_children():
		c.queue_free()
	portal = null
	fx.clear()


func _spawn_companions() -> void:
	for c in companion_nodes:
		if is_instance_valid(c):
			c.queue_free()
	companion_nodes.clear()
	for i in world.companions.size():
		var data: Dictionary = world.companions[i]
		if data["downed"]:
			continue
		var c := CompanionScript.new()
		c.main = self
		c.setup(data["type"], player.level, i)
		c.position = player.position + Vector2(-60 + 120 * (i % 2), 50)
		entities.add_child(c)
		companion_nodes.append(c)


func allies() -> Array:
	var out := []
	if player and player.alive:
		out.append(player)
	for c in companion_nodes:
		if is_instance_valid(c) and c.alive:
			out.append(c)
	return out


func on_companion_down(c) -> void:
	if c.index < world.companions.size():
		world.companions[c.index]["downed"] = true
	float_text(c.global_position + Vector2(0, -40), "%s поранений!" % Data.COMPANIONS[c.type]["name"], UI.BAD)


# ======================= Бій =======================

func _process(delta: float) -> void:
	_time += delta
	if vignette:
		var low: float = 0.0
		if state == State.PLAYING and player and player.alive and player.hp < player.max_hp * 0.3:
			low = 0.25 + 0.15 * sin(_time * 6.0)
		vignette.modulate.a = maxf(move_toward(vignette.modulate.a, 0.0, delta * 1.5), low)
	if state != State.PLAYING:
		return
	if torch.enabled:
		torch.energy = 1.15 + sin(_time * 13.0) * 0.05 + randf() * 0.06
	camera.global_position = player.global_position
	if shake_strength > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	player.attack_held = btn_attack.held or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_SPACE)
	btn_dodge.set_cooldown(player.dodge_timer / player.dodge_cooldown)
	for id in skill_buttons:
		var b = skill_buttons[id]
		b.visible = player.sk(id) > 0
		b.set_cooldown(player.skill_ready_ratio(id))
	if loc["type"] == "dungeon":
		_update_dungeon()
	else:
		_update_field(delta)
	_update_hud(delta)


func _update_field(delta: float) -> void:
	if field_cleared:
		_check_portal()
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.6, 1.5 - loc["level"] * 0.05)
		if alive_enemy_count() < 7 + loc["level"]:
			var en: Array = loc["enemies"]
			spawn_enemy(en[randi() % en.size()], loc["level"] + (1 if randf() < 0.15 else 0))


func _spawn_room() -> void:
	room_cleared = false
	var en: Array = loc["enemies"]
	for i in 4 + room * 2:
		var pos := Vector2(randf_range(arena.position.x + 80, arena.end.x - 80), randf_range(arena.position.y + 80, arena.position.y + arena.size.y * 0.55))
		spawn_enemy(en[randi() % en.size()], loc["level"], false, pos)
	if room == loc["rooms"]:
		spawn_enemy(loc["boss"], loc["level"], true, Vector2(0, arena.position.y + 220))
		show_banner("%s!" % Data.BOSS_NAMES[loc["boss"]], Color(1.0, 0.55, 0.2))
	else:
		show_banner("%s\nКімната %d/%d" % [loc["name"], room, loc["rooms"]])


func _update_dungeon() -> void:
	if not room_cleared and alive_enemy_count() == 0:
		room_cleared = true
		if room < loc["rooms"]:
			_spawn_portal("Далі")
			show_banner("Прохід відкрито!", Color(0.6, 1.0, 0.6))
		else:
			_dungeon_complete()
	if portal != null and is_instance_valid(portal) and player.global_position.distance_to(portal.global_position) < 60.0:
		audio.play("portal", 0.0)
		_collect_all()
		if room < loc["rooms"]:
			room += 1
			_setup_arena()
			_spawn_room()
		else:
			enter_map()


func _check_portal() -> void:
	if portal != null and is_instance_valid(portal) and player.global_position.distance_to(portal.global_position) < 60.0:
		audio.play("portal", 0.0)
		_collect_all()
		enter_map()


func _field_cleared() -> void:
	field_cleared = true
	world.cleared[loc_id] = world.cleared.get(loc_id, 0) + 1
	var g: int = 25 * loc["level"]
	player.add_gold(g)
	audio.play("quest", 0.0)
	show_banner("%s очищено!\n+%d дукатів і скарб" % [loc["name"], g], UI.GOLD)
	var pos: Vector2 = player.global_position + Vector2(0, -120)
	for i in 2:
		spawn_pickup(pos, "item", 0, Data.gen_item(loc["level"], Data.roll_rarity(loc["level"], 1)))
	for i in 6:
		spawn_pickup(pos, "coin", loc["level"] * 2)
	portal = PortalScript.new()
	portal.label = "На мапу"
	portal.position = (player.global_position + Vector2(0, -260)).clamp(arena.position + Vector2(80, 120), arena.end - Vector2(80, 60))
	entities.add_child(portal)
	hint("cleared", "Місцевість очищено! Збери скарб і зайди в портал, щоб повернутися на мапу.")


func _spawn_portal(text: String) -> void:
	portal = PortalScript.new()
	portal.label = text
	portal.position = Vector2(0, arena.position.y + 110)
	entities.add_child(portal)


func _dungeon_complete() -> void:
	world.on_dungeon(loc_id)
	var g: int = 40 * loc["level"]
	player.add_gold(g)
	show_banner("%s очищено!\n+%d дукатів" % [loc["name"], g], UI.GOLD)
	audio.play("quest", 0.0)
	_spawn_portal("Вихід")


## Збирає всю здобич, що лишилась на землі (перед переходом у наступну кімнату).
func _collect_all() -> void:
	for c in entities.get_children():
		if c.get_script() == PickupScript:
			match c.kind:
				"coin":
					player.add_xp(c.value)
					player.add_gold(c.value)
				"item":
					on_item_picked(c.item)


func spawn_enemy(kind: String, level: int, boss: bool = false, pos = null) -> void:
	if pos == null:
		pos = Vector2.ZERO
		for i in 10:
			pos = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(650, 850)
			pos = pos.clamp(arena.position + Vector2(60, 60), arena.end - Vector2(60, 60))
			if pos.distance_to(player.global_position) > 420.0:
				break
	var e := EnemyScript.new()
	e.main = self
	e.position = pos
	e.setup(kind, level, boss)
	entities.add_child(e)
	if e.is_boss:
		audio.play("roar", 0.0)
		shake(10.0)
		hint("boss", "Бос! Червоні зони на землі — місця його удару. Виходь із них, поки вони не заповнились!")


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


func spawn_pickup(pos: Vector2, kind: String, value: int, item: Dictionary = {}) -> void:
	var p = PickupScript.new()
	p.main = self
	p.kind = kind
	p.value = value
	p.item = item
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
	audio.play("enemy_die", 0.15, -3.0)
	fx.burst(e.global_position + Vector2(0, -10), Color(0.25, 0.2, 0.25, 0.8), 12 if not e.is_boss else 40, 180 if not e.is_boss else 320, 9, 0.6, -60)
	if e.is_boss:
		fx.ring(e.global_position, Color(1.0, 0.8, 0.3), 40, 600, 8, 0.7)
		hitstop(0.15)
	else:
		hitstop(0.03)
	if loc.get("type", "") == "field" and not field_cleared:
		field_kills += 1
		if field_kills >= field_goal:
			_field_cleared()
	for m in world.on_kill(e.kind):
		float_text(player.global_position + Vector2(0, -90), m, UI.GOLD)
	var pos: Vector2 = e.global_position
	var ilvl: int = loc.get("level", 1)
	var heal_value := int(20 * (1.0 + 0.5 * player.varenyk_bonus))
	if e.is_boss:
		shake(14.0)
		show_banner("%s переможений!" % Data.BOSS_NAMES.get(e.kind, "Бос"), UI.GOLD)
		for i in 10:
			spawn_pickup(pos, "coin", maxi(1, e.xp_value / 10))
		for i in 2:
			spawn_pickup(pos, "item", 0, Data.gen_item(ilvl + 1, Data.roll_rarity(ilvl, 2)))
		spawn_pickup(pos, "varenyk", heal_value * 2)
	else:
		spawn_pickup(pos, "coin", e.xp_value)
		if randf() < 0.05 * (1 + player.varenyk_bonus):
			spawn_pickup(pos, "varenyk", heal_value)
		if randf() < 0.05:
			spawn_pickup(pos, "item", 0, Data.gen_item(ilvl, Data.roll_rarity(ilvl)))


func on_item_picked(item: Dictionary) -> void:
	var col: Color = Data.RARITY_COLORS[item["rarity"]]
	if player.add_item(item):
		float_text(player.global_position + Vector2(0, -70), item["name"], col)
		audio.play("item", 0.0)
		hint("item", "Знайдено річ! Вдягни її: кнопка «Козак» → вкладка «Спорядження».")
	else:
		var g := Data.sell_price(item)
		player.gold += g
		float_text(player.global_position + Vector2(0, -70), "Торба повна: +%d дук." % g, col)


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
			if state == State.CHARACTER:
				close_character()
			elif playing or state == State.MAP or state == State.CITY:
				open_character()
		KEY_M:
			if playing:
				_try_leave()
		KEY_ESCAPE, KEY_P:
			if playing:
				_show_pause()
			elif state == State.PAUSED:
				_resume_play()
			elif state == State.CHARACTER:
				close_character()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.PLAYING:
			_show_pause()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == State.CHARACTER:
			close_character()


func _try_leave() -> void:
	var e := nearest_enemy(player.global_position, 350.0)
	if e:
		show_banner("Нечисть поруч — не втечеш!", UI.BAD)
		return
	_collect_all()
	enter_map()


# ======================= Події =======================

func _on_level_up(lvl: int) -> void:
	show_banner("Рівень %d!\nВідкрий «Козак», щоб прокачатися" % lvl, UI.GOLD)
	hint("levelup", "Новий рівень! Натисни «Козак» угорі: вклади очки в характеристики, вміння й перки.")


func _on_player_died() -> void:
	state = State.DEAD
	controls.visible = false
	_hud_mode(true, false)
	char_btn.visible = false
	show_banner("Козак поліг...", Color(1.0, 0.4, 0.35))
	await get_tree().create_timer(1.4).timeout
	var lost := int(player.gold * 0.25)
	player.gold -= lost
	_open_overlay()
	_add_title("Козак поліг", 64, Color(1.0, 0.45, 0.35))
	_add_title("Побратими винесли тебе з бою. Втрачено %d дукатів." % lost, 24, UI.TEXT)
	_add_button("Отямитися: %s" % Data.place_name(world.last_city), func(): enter_city(world.last_city))


# ======================= Інтерфейс =======================

func _make_theme() -> Theme:
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


func _hud_label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	stats_box.add_child(l)
	return l


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	controls = Node2D.new()
	controls.visible = false
	hud.add_child(controls)
	joystick = JoystickScript.new()
	controls.add_child(joystick)
	btn_attack = _make_action_button("Удар", 86.0, Color(0.75, 0.15, 0.12))
	btn_attack.triggered.connect(func(): if state == State.PLAYING: player.attack())
	btn_dodge = _make_action_button("Перекид", 56.0, Color(0.2, 0.45, 0.75))
	btn_dodge.triggered.connect(func(): if state == State.PLAYING: player.dodge())
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

	map_view = WorldMap.new()
	map_view.main = self
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.visible = false
	map_view.location_selected.connect(_on_map_select)
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

	stats_box = Control.new()
	stats_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.visible = false
	ui_root.add_child(stats_box)
	hp_bar = _make_bar(Color(0.85, 0.15, 0.15))
	hp_bar.position = Vector2(20, 18)
	hp_bar.size = Vector2(340, 30)
	stats_box.add_child(hp_bar)
	hp_label = _hud_label(Vector2(30, 18), 20)
	hp_label.size = Vector2(320, 30)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_bar = _make_bar(Color(0.95, 0.75, 0.15))
	xp_bar.position = Vector2(20, 54)
	xp_bar.size = Vector2(340, 16)
	stats_box.add_child(xp_bar)
	level_label = _hud_label(Vector2(20, 72), 22)
	quest_label = _hud_label(Vector2(20, 104), 16)
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

	pause_btn = _make_corner_button("II", -96, -20, _on_pause_button)
	char_btn = _make_corner_button("Козак", -290, -110, open_character)
	char_btn.add_theme_font_size_override("font_size", 24)
	map_btn = _make_corner_button("Мапа", -420, -305, func(): if state == State.PLAYING: _try_leave())
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

	vignette = TextureRect.new()
	var vg := GradientTexture2D.new()
	vg.width = 256
	vg.height = 256
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.25, 0.5)
	var vgrad := Gradient.new()
	vgrad.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	vgrad.set_color(1, Color(0.75, 0.0, 0.0, 0.75))
	vgrad.add_point(0.72, Color(0.75, 0.0, 0.0, 0.0))
	vg.gradient = vgrad
	vignette.texture = vg
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	ui_root.add_child(vignette)
	ui_root.move_child(vignette, 0)

	hint_panel = PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.offset_left = -330
	hint_panel.offset_right = 330
	hint_panel.offset_top = 84
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


func _make_corner_button(text: String, left: float, right: float, cb: Callable) -> Button:
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


func _make_action_button(text: String, r: float, col: Color):
	var b = ActionButtonScript.new()
	b.label = text
	b.radius = r
	b.color = col
	controls.add_child(b)
	return b


func _on_skill_button(id: String) -> void:
	if state == State.PLAYING:
		player.use_skill(id)


func _on_pause_button() -> void:
	if state == State.PLAYING:
		_show_pause()


## Що показувати в HUD: смуги героя та кнопки бою.
func _hud_mode(show_stats: bool, combat: bool) -> void:
	stats_box.visible = show_stats
	pause_btn.visible = combat
	map_btn.visible = combat
	char_btn.visible = show_stats


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	joystick.rest_pos = Vector2(190, s.y - 180)
	joystick.queue_redraw()
	btn_attack.position = Vector2(s.x - 140, s.y - 140)
	btn_dodge.position = Vector2(s.x - 300, s.y - 80)
	skill_buttons["whirl"].position = Vector2(s.x - 120, s.y - 315)
	skill_buttons["lightning"].position = Vector2(s.x - 275, s.y - 255)
	skill_buttons["musket"].position = Vector2(s.x - 425, s.y - 105)
	map_view.map_rect = Rect2(Vector2(8, 96), Vector2(s.x - 410, s.y - 104))


func _update_hud(delta: float) -> void:
	if player == null:
		return
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "Здоров'я %d / %d" % [roundi(player.hp), roundi(player.max_hp)]
	xp_bar.max_value = player.xp_next
	xp_bar.value = player.xp
	level_label.text = "Рівень %d    Дукати: %d" % [player.level, player.gold]
	var ql := []
	for q in world.quests:
		ql.append("• %s %d/%d" % [q["text"], q["progress"], q["count"]] + ("  ✓" if world.is_done(q) else ""))
	quest_label.text = "\n".join(ql)
	if state == State.PLAYING:
		loc_label.text = loc["name"]
		if loc["type"] == "dungeon":
			sub_label.text = "Кімната %d/%d" % [room, loc["rooms"]]
		elif field_cleared:
			sub_label.text = "Очищено! Портал веде на мапу"
		else:
			sub_label.text = "Рівень %d  •  Зачистка: %d/%d" % [loc["level"], field_kills, field_goal]
	else:
		loc_label.text = ""
		sub_label.text = ""
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


# --- Мапа ---

func _on_map_select(id: String) -> void:
	map_sel = id
	map_view.selected = id
	_build_map_panel()


func _build_map_panel() -> void:
	for c in map_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	map_panel.add_child(v)
	if map_sel == "":
		v.add_child(UI.label("Мапа земель", 28, UI.GOLD, false))
		v.add_child(UI.label("Торкнись місця на мапі.\nЩипок або +/− — масштаб,\nпалець — рух мапою.", 19, UI.TEXT, false))
		for t in ["Фортеця — місто: крамниця, коваль,\nкорчма, завдання", "Шаблі — дика місцевість", "Арка — печера з босом", "«!» — тут твоє завдання", "Червоне коло — небезпечно\nдля твого рівня", "(число) — рівень місцевості"]:
			v.add_child(UI.label(t, 16, UI.MUTED, false))
		return
	if Data.CITIES.has(map_sel):
		var C: Dictionary = Data.CITIES[map_sel]
		v.add_child(UI.label(C["name"], 28, UI.GOLD, false))
		v.add_child(UI.label("Місто", 18, UI.MUTED, false))
		var desc := UI.label(C["desc"], 18, UI.TEXT, false)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(desc)
		v.add_child(UI.label("Лояльність: %s (%d)" % [Data.LOYALTY_NAMES[world.loyalty_level(map_sel)], world.loyalty_points(map_sel)], 18, UI.TEXT, false))
		var done := 0
		for q in world.quests:
			if q["city"] == map_sel and world.is_done(q):
				done += 1
		if done > 0:
			v.add_child(UI.label("Можна здати завдань: %d" % done, 18, UI.GOOD, false))
		v.add_child(UI.button("Увійти до міста", func(): enter_city(map_sel), Vector2(350, 70), 26))
		return
	var L: Dictionary = Data.LOCATIONS[map_sel]
	v.add_child(UI.label(L["name"], 28, UI.GOLD, false))
	var kind_text: String = ("Печера • %d кімнат • бос: %s" % [L["rooms"], Data.BOSS_NAMES[L["boss"]]]) if L["type"] == "dungeon" else "Дика місцевість"
	v.add_child(UI.label(kind_text, 17, UI.MUTED, false))
	var danger: bool = L["level"] > player.level + 2
	v.add_child(UI.label("Рівень місцевості: %d%s" % [L["level"], "  — небезпечно!" if danger else ""], 19, UI.BAD if danger else UI.TEXT, false))
	var desc2 := UI.label(L["desc"], 18, UI.TEXT, false)
	desc2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc2)
	var names := []
	for e in L["enemies"]:
		names.append(Data.ENEMY_NAMES[e])
	v.add_child(UI.label("Нечисть: " + ", ".join(names), 17, UI.MUTED, false))
	for q in world.quests:
		if q["loc"] == map_sel and not world.is_done(q):
			var ql := UI.label("! " + q["text"], 16, UI.GOLD, false)
			ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(ql)
	v.add_child(UI.button("Вирушити", func(): enter_location(map_sel), Vector2(350, 70), 26))


# --- Повноекранні екрани (козак, місто) ---

func _clear_screen() -> void:
	if screen_root:
		screen_root.queue_free()
		screen_root = null


func _set_screen(c: Control) -> void:
	_clear_screen()
	screen_root = c
	ui_root.add_child(c)
	ui_root.move_child(c, banner.get_index())


func _build_city() -> void:
	_set_screen(UiCity.build(self, city_id))


func shop_stock(city: String) -> Array:
	if not world.shops.has(city) or world.shop_dirty.get(city, true):
		var C: Dictionary = Data.CITIES[city]
		var loyal: int = world.loyalty_level(city)
		var ilvl: int = maxi(C["level"], player.level - 1) + loyal
		var stock := []
		for i in 6:
			stock.append(player.assign_uid(Data.gen_item(ilvl, Data.roll_rarity(C["level"] + loyal * 3))))
		world.shops[city] = stock
		world.shop_dirty[city] = false
	return world.shops[city]


func buy_price(city: String, item: Dictionary) -> int:
	return int(Data.sell_price(item) * 4 * (1.0 - world.discount(city)))


func hire_price(city: String, type: String) -> int:
	return int(Data.COMPANIONS[type]["cost"] * (1.0 - world.discount(city)) * (1.0 + 0.1 * (player.level - 1)))


func city_do(action: String, arg) -> void:
	match action:
		"take":
			world.take(city_id, arg)
		"abandon":
			world.abandon(arg)
		"turn_in":
			var q: Dictionary = world.turn_in(arg)
			if not q.is_empty():
				player.gold += q["gold"]
				player.add_xp(q["xp"])
				audio.play("quest", 0.0)
				var up: bool = world.add_loyalty(q["city"], q["loyalty"])
				if up:
					show_banner("Лояльність зросла!\n%s: %s" % [Data.place_name(q["city"]), Data.LOYALTY_NAMES[world.loyalty_level(q["city"])]], UI.GOOD)
				else:
					show_banner("Завдання виконано!\n+%d дукатів, +%d досвіду" % [q["gold"], q["xp"]], UI.GOLD)
		"select":
			city_sel_uid = arg
			smith_msg = ""
		"buy":
			var stock := shop_stock(city_id)
			for i in stock.size():
				var it: Dictionary = stock[i]
				if it["uid"] == arg:
					var price := buy_price(city_id, it)
					if player.gold >= price and player.add_item(it):
						player.gold -= price
						audio.play("coin", 0.0)
						stock.remove_at(i)
					break
		"sell":
			var it: Dictionary = player.remove_from_bag(arg)
			if not it.is_empty():
				player.gold += Data.sell_price(it)
			city_sel_uid = -1
		"sell_junk":
			for it in player.inventory.duplicate():
				if it["rarity"] == 0:
					player.remove_from_bag(it["uid"])
					player.gold += Data.sell_price(it)
		"sharpen":
			var before: int = player.find_item(arg).get("up", 0)
			match player.sharpen(arg):
				"ok":
					audio.play("sharpen_ok", 0.03)
					smith_msg = "Успіх! Тепер +%d" % (before + 1)
					smith_msg_color = UI.GOOD
				"fail":
					audio.play("sharpen_fail")
					smith_msg = "Не вдалося... Заточка лишилась +%d" % before
					smith_msg_color = UI.MUTED
				"down":
					audio.play("sharpen_fail")
					smith_msg = "Лезо тріснуло! Заточка впала до +%d" % (before - 1)
					smith_msg_color = UI.BAD
				"nogold":
					smith_msg = "Бракує дукатів."
					smith_msg_color = UI.BAD
		"hire":
			var price := hire_price(city_id, arg)
			if player.gold >= price and world.companions.size() < Data.MAX_COMPANIONS:
				player.gold -= price
				world.companions.append({"type": arg, "downed": false})
		"dismiss":
			if arg < world.companions.size():
				world.companions.remove_at(arg)
	save_game()
	_build_city()


func open_character() -> void:
	if state == State.CHARACTER or player == null:
		return
	if not (state == State.PLAYING or state == State.MAP or state == State.CITY):
		return
	char_return = state
	state = State.CHARACTER
	get_tree().paused = true
	controls.visible = false
	joystick.release()
	map_panel.visible = false
	map_view.visible = false
	_hud_mode(false, false)
	char_sel_uid = -1
	_build_character()


func _build_character() -> void:
	_set_screen(UiCharacter.build(self))


func char_do(action: String, arg) -> void:
	match action:
		"stat":
			player.add_stat(arg)
		"skill":
			player.learn_skill(arg)
		"perk":
			player.learn_perk(arg)
		"select":
			char_sel_uid = arg
		"equip":
			player.equip(arg)
		"unequip":
			player.unequip(arg)
		"drop":
			player.remove_from_bag(arg)
			char_sel_uid = -1
	_build_character()


func close_character() -> void:
	_clear_screen()
	save_game()
	match char_return:
		State.PLAYING:
			_resume_play()
		State.CITY:
			state = State.CITY
			_build_city()
		_:
			enter_map()


func _resume_play() -> void:
	_close_overlay()
	_clear_screen()
	state = State.PLAYING
	get_tree().paused = false
	controls.visible = true
	_hud_mode(true, true)


# --- Оверлеї меню ---

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


func _add_title(text: String, size: int = 56, col: Color = UI.GOLD) -> Label:
	var l := UI.label(text, size, col)
	overlay_box.add_child(l)
	return l


func _add_button(text: String, cb: Callable, min_size := Vector2(480, 80)) -> Button:
	var b := UI.button(text, cb, min_size)
	overlay_box.add_child(b)
	return b


func _show_main_menu() -> void:
	state = State.MENU
	audio.play_music("calm")
	_hud_mode(false, false)
	_open_overlay()
	_add_title("Козацька Звитяга", 72)
	_add_title("Нечисть сунеться на українські землі. Козаче, рушай у похід!", 24, UI.TEXT)
	if FileAccess.file_exists(SAVE_PATH):
		_add_button("Продовжити", _continue_game)
		_add_button("Нова гра", _confirm_new_game)
	else:
		_add_button("Нова гра", _new_game)
	_add_sound_toggles(_show_main_menu)
	_add_title("Ліва частина екрана — рух, праворуч — удар, перекид і вміння.\nНа мапі обирай міста, дикі місцевості та печери.", 18, Color(0.8, 0.8, 0.8))


func _continue_game() -> void:
	if load_game():
		map_here = world.last_city
		enter_city(world.last_city)
	else:
		_new_game()


func _confirm_new_game() -> void:
	_open_overlay()
	_add_title("Почати нову гру?", 48)
	_add_title("Поточне збереження буде втрачено.", 24, UI.TEXT)
	_add_button("Так, нова гра", _new_game)
	_add_button("Ні", _show_main_menu)


func _show_pause() -> void:
	state = State.PAUSED
	_hud_mode(false, false)
	_open_overlay()
	_add_title("Пауза")
	_add_button("Продовжити", _resume_play)
	_add_button("Козак", func():
		_close_overlay()
		state = State.PLAYING
		open_character())
	var leave_text := "Покинути печеру (прогрес втратиться)" if loc.get("type", "") == "dungeon" else "Повернутися на мапу"
	_add_button(leave_text, func():
		_collect_all()
		enter_map())
	_add_sound_toggles(_show_pause)
	_add_button("Головне меню", func():
		save_game()
		_clear_combat()
		_set_world_visible(false)
		_show_main_menu())


# ======================= Відчуття, атмосфера, підказки, налаштування =======================

## Коротке «завмирання» гри від сильного удару.
func hitstop(dur: float) -> void:
	if _hitstop_active or state != State.PLAYING:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func on_player_hurt() -> void:
	vignette.modulate.a = 0.6


func _setup_atmosphere(biome: String) -> void:
	canvas_mod.color = BIOME_TINT.get(biome, Color.WHITE)
	torch.enabled = biome == "cave"
	for c in lights.get_children():
		c.queue_free()
	if biome == "cave":
		for c in ground.crystals:
			var l := PointLight2D.new()
			l.texture = light_tex
			l.texture_scale = 1.6
			l.color = c[1]
			l.energy = 1.1
			l.position = c[0]
			lights.add_child(l)
	ambient.setup(biome)


## Показує підказку один раз за всю гру.
func hint(id: String, text: String) -> void:
	if world.hints.has(id):
		return
	world.hints[id] = true
	hint_label.text = text
	# На мапі праворуч бічна панель — зсуваємо підказку лівіше
	var shift := -205.0 if state == State.MAP else 0.0
	hint_panel.offset_left = -330 + shift
	hint_panel.offset_right = 330 + shift
	hint_panel.visible = true
	hint_panel.modulate.a = 1.0
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = hint_panel.create_tween()
	_hint_tween.tween_interval(8.0)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.6)
	_hint_tween.tween_callback(func(): hint_panel.visible = false)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		audio.set_sound(cfg.get_value("audio", "sound", true))
		audio.set_music(cfg.get_value("audio", "music", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", audio.sound_on)
	cfg.set_value("audio", "music", audio.music_on)
	cfg.save(SETTINGS_PATH)


func _add_sound_toggles(refresh: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UI.button("Звук: " + ("так" if audio.sound_on else "ні"), func():
		audio.set_sound(not audio.sound_on)
		_save_settings()
		refresh.call(), Vector2(232, 64), 22))
	row.add_child(UI.button("Музика: " + ("так" if audio.music_on else "ні"), func():
		audio.set_music(not audio.music_on)
		_save_settings()
		refresh.call(), Vector2(232, 64), 22))
	overlay_box.add_child(row)
