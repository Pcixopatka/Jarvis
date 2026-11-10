class_name Combat
extends Node2D
## Бій і локації: арена, ландшафт, освітлення, вороги, супутники, снаряди, здобич,
## дика місцевість (зачистка) і печери (кімнати з босом).
## Про важливі події повідомляє через шину Events; сам нічого не знає про меню й інтерфейс.

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const EnemyScript := preload("res://scripts/entities/enemy.gd")
const CompanionScript := preload("res://scripts/entities/companion.gd")
const ProjectileScript := preload("res://scripts/entities/projectile.gd")
const PickupScript := preload("res://scripts/entities/pickup.gd")
const PortalScript := preload("res://scripts/entities/portal.gd")
const FxSpriteScript := preload("res://scripts/world/fx_sprite.gd")
const FloatTextScript := preload("res://scripts/world/float_text.gd")
const BoltScript := preload("res://scripts/world/bolt.gd")
const Elites := preload("res://scripts/data/elites.gd")
const TelegraphScript := preload("res://scripts/world/telegraph.gd")
const PlagueService := preload("res://scripts/game/plague_service.gd")
const PlagueScript := preload("res://scripts/world/plague_cloud.gd")
const GateScript := preload("res://scripts/entities/gate.gd")
const TrapScript := preload("res://scripts/world/trap.gd")
const ZoneScript := preload("res://scripts/world/zone.gd")
const SpectatorScript := preload("res://scripts/world/spectator.gd")
const CampfireScript := preload("res://scripts/world/campfire.gd")
const VigilService := preload("res://scripts/game/vigil_service.gd")
const TrailService := preload("res://scripts/game/trail_service.gd")
const HolidayService := preload("res://scripts/game/holiday_service.gd")
const Sounds := preload("res://scripts/data/sounds.gd")
const TrailScript := preload("res://scripts/world/trail.gd")
const Acts := preload("res://scripts/data/activities.gd")
const DEFENSE_ARENA := Rect2(-900, -800, 1800, 1300)
const GroundScript := preload("res://scripts/world/ground.gd")
const FxScript := preload("res://scripts/world/fx.gd")
const AmbientScript := preload("res://scripts/world/ambient.gd")

const FIELD_ARENA := Rect2(-1400, -1400, 2800, 2800)
const DUNGEON_ARENA := Rect2(-750, -550, 1500, 1100)
const DUEL_ARENA := Rect2(-480, -360, 960, 720)  # майдан для герцю
const VIGIL_ARENA := Rect2(-1000, -800, 2000, 1600)  # сторожова могила
const BIOME_TINT := {
	"steppe": Color(1.0, 0.97, 0.9), "river": Color(0.97, 1.0, 1.0), "forest": Color(0.82, 0.92, 0.82),
	"swamp": Color(0.78, 0.86, 0.8), "mountain": Color(0.92, 0.95, 1.0), "cave": Color(0.2, 0.18, 0.25),
	"plague": Color(0.2, 0.26, 0.17), "village": Color(1.0, 0.82, 0.68),
}

## Джерела керування (задає Game): вектор руху і чи затиснуто удар.
var move_input: Callable = func() -> Vector2: return Vector2.ZERO
var attack_input: Callable = func() -> bool: return false
var block_input: Callable = func() -> bool: return false

var arena := FIELD_ARENA
var player: Player
var camera: Camera2D
var ground
var entities: Node2D
var effects: Node2D
var fx
var ambient
var lights: Node2D
var canvas_mod: CanvasModulate
var torch: PointLight2D
var light_tex: GradientTexture2D
var companion_nodes: Array = []

var active := false
var plague := 0  # рівень зарази поточної місцевості
var festive := {}  # святкові надбавки до здобичі (ключі — Acts.HOLIDAY_COMBAT_KEYS; виставляє Game)
var boss_revives := 0
var defense_loc := {}
var custom_loc := {}
var tower_boss_spawned := false  # Башта: міні-бос/супербос поверху вже на арені
var duel_over := false  # герць: суперник упав
var vigil_time := 0.0  # варта: скільки секунд вистояно
var vigil_kills := 0
var vigil_minute := 0
var vigil_done := false  # мету (5 хв) досягнуто, портал відкрито
var _vigil_fire = null
var _vigil_day := Color.WHITE
var torch_base := 1.15  # сила смолоскипа: у печері яскравий, уночі надворі — слабший, щоб не засвічувати
var spectators: Array = []  # глядачі на майдані
var trail = null  # стежка слідів у місцевості (TrailScript) або null
var _duel_hp := 0.0  # здоров'я суперника минулого кадру (щоб глядачі раділи влучанням)
var autosell := false  # звичайні речі при повній торбі одразу продаються (налаштування)  # Глибини зарази: опис печери обраної глибини (див. DepthService)  # бій-оборона: опис від DefenseService (замість Data.LOCATIONS)
var gate = null
var wave := 0
var wave_timer := 0.0
var defense_over := false  # скільки разів Кощій ще встане (поки голка ціла)
var plague_mods := {}
var cloud_timer := 0.0
var loc_id := ""
var loc: Dictionary = {}
var room := 0
var room_cleared := false
var portal: Node2D = null
var spawn_timer := 0.0
var field_kills := 0
var field_goal := 0
var field_cleared := false

var shake_strength := 0.0
var _hitstop_active := false
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ground = GroundScript.new()
	add_child(ground)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	ground.props_parent = entities
	effects = Node2D.new()
	effects.z_index = 10
	add_child(effects)
	lights = Node2D.new()
	add_child(lights)
	fx = FxScript.new()
	fx.z_index = 11
	add_child(fx)
	ambient = AmbientScript.new()
	ambient.combat = self
	ambient.z_index = 12
	add_child(ambient)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	light_tex = _make_light_texture()
	camera = Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)  # піксельна графіка: тайл 16 px → 48 px на екрані
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()
	Events.enemy_killed.connect(_on_enemy_killed)
	set_visible_world(false)


static func _make_light_texture() -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	t.gradient = g
	return t


## Підключає героя до світу (смолоскип для печер — його дочірній вузол).
func set_player(p: Player) -> void:
	player = p
	player.combat = self
	entities.add_child(player)
	torch = PointLight2D.new()
	torch.texture = light_tex
	torch.texture_scale = 4.5
	torch.color = Color(1.0, 0.8, 0.55)
	torch.energy = 1.2
	torch.enabled = false
	torch.position = Vector2(0, -20)
	player.add_child(torch)


func set_visible_world(v: bool) -> void:
	for n in [ground, entities, effects, fx, ambient, lights, canvas_mod]:
		n.visible = v


# ======================= Вхід і вихід =======================

## companions — список {"type", "downed"} зі стану світу.
func enter(id: String, companions: Array, plague_level: int = 0, extra: Dictionary = {}) -> void:
	loc_id = id
	if not Data.LOCATIONS.has(id):
		# Особливі бої, описані службами (оборона, події, герць...)
		match str(defense_loc.get("type", "")):
			"duel":
				enter_duel(defense_loc)
			"vigil":
				enter_vigil(defense_loc, companions)
			_:
				enter_defense(defense_loc, companions)
		return
	plague = plague_level
	plague_mods = PlagueService.mods(plague)
	cloud_timer = 4.0
	loc = Data.LOCATIONS[id]
	if loc.get("endless", false) and not custom_loc.is_empty():
		loc = custom_loc  # Глибини зарази: печера потрібної глибини
	if not extra.is_empty():
		# Модифікатори подій: ніч, скарб, спалене село (див. EventService.mods_for)
		loc = loc.duplicate()
		loc.merge(extra, true)
	room = 1 if loc["type"] == "dungeon" else 0
	field_kills = 0
	field_goal = int(loc.get("goal", Data.FIELD_GOAL_BASE + int(loc["level"]) * Data.FIELD_GOAL_PER_LEVEL))
	field_cleared = false
	spawn_timer = 1.0
	player.unbreak_ready = true
	player.berehynia_ready = true
	_setup_arena(companions)
	set_visible_world(true)
	active = true
	if is_tower():
		_start_floor()
	elif loc["type"] == "dungeon":
		_spawn_room()
	else:
		var with_trail: bool = is_field() and TrailService.should_spawn(player, randf())
		var trail_note := ""
		if with_trail:
			trail_note = "\nОко пластуна: бачиш усю стежку слідів" if player.job == "plastun" else "\nНеподалік чиїсь сліди"
		Events.banner.emit(loc["name"] + ("\nНічний похід" if loc.get("night", false) else "") + trail_note, Color(1, 0.92, 0.7))
		var en: Array = loc["enemies"]
		for i in 5:
			var pos: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * randf_range(450, 650)
			spawn_enemy(en[randi() % en.size()], loc["level"], false, _clamp_in(pos, 60.0))
		if loc.has("bounty"):
			_spawn_bounty(loc["bounty"])
		if loc.get("treasure", false):
			# Сторож скарбу: еліта з двома властивостями, після неї — скриня
			var gp := _clamp_in(player.position + Vector2.from_angle(randf() * TAU) * 700.0, 80.0)
			spawn_enemy(en[randi() % en.size()], int(loc["level"]) + 1, false, gp)
			var g = _last_enemy()
			var gk := Elites.AFFIXES.keys()
			gk.shuffle()
			g.make_elite(gk.slice(0, 2))
			g.max_hp *= 1.5
			g.hp = g.max_hp
			g.treasure_guard = true
			g.title = "Сторож скарбу: " + g.title
		if with_trail:
			spawn_trail(TrailService.roll_kind(randf()))


## Покласти на арену стежку слідів, що веде до знахідки (cache | den | beast).
func spawn_trail(kind: String, seed_value: int = -1) -> void:
	_drop_trail()
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	trail = TrailScript.new().setup(TrailService.make_points(player.position, arena, rng), kind, player.job == "plastun")
	ground.add_child(trail)


func _drop_trail() -> void:
	if trail != null and is_instance_valid(trail):
		trail.queue_free()
	trail = null


## Герой дійшов до чергової точки стежки: відкриваємо наступний відтинок або знахідку.
func _update_trail() -> void:
	if trail == null or not is_instance_valid(trail) or trail.found:
		return
	if player.global_position.distance_to(trail.target()) > Acts.TRAIL_REACH:
		return
	if trail.step < trail.points.size() - 1:
		trail.step += 1
		Audio.play("coin", 0.2, -8.0)
		if trail.step == 1:
			Events.banner.emit("Свіжі сліди! Іди по них", Color(1.0, 0.9, 0.55))
			Events.hint.emit("trail", "Сліди на землі ведуть до знахідки: схованки, лігва нечисті чи пораненого звіра. Іди від відбитка до відбитка, стежка відкривається частинами.")
		return
	trail.found = true
	_trail_found()


func _trail_found() -> void:
	var pos: Vector2 = trail.points[-1]
	var lvl := int(loc.get("level", 1))
	var info: Dictionary = Acts.TRAIL_KINDS[trail.kind]
	match str(trail.kind):
		"cache":
			Events.banner.emit(info["text"], Color(1.0, 0.85, 0.35))
			for i in 5:
				spawn_pickup(pos, "coin", TrailService.cache_gold(lvl) / 5)
			_resource_bundle(pos, 3)
			if randf() < Acts.TRAIL_CACHE_ITEM:
				spawn_pickup(pos, "item", 0, Data.gen_item(lvl, Data.roll_rarity(lvl, 1)))
		"den":
			Events.banner.emit(info["text"], Color(1.0, 0.5, 0.4))
			var en: Array = loc["enemies"]
			for i in 3:
				spawn_enemy(en[randi() % en.size()], lvl, false, _clamp_in(pos + Vector2.from_angle(i * TAU / 3.0 + 0.5) * 150.0, 60.0))
			var boss = _last_enemy()
			if boss != null and not boss.elite:
				boss.make_elite(Elites.roll_affixes(lvl))
			# Купа здобичі посеред лігва
			spawn_pickup(pos, "item", 0, Data.gen_item(lvl, maxi(1, Data.roll_rarity(lvl, 1))))
			for i in 4:
				spawn_pickup(pos, "coin", TrailService.cache_gold(lvl) / 8)
			shake(6.0)
		"beast":
			var meat := TrailService.beast_meat(randf())
			player.resources["meat"] = int(player.resources.get("meat", 0)) + meat
			Events.banner.emit("%s\n+%d м'яса для казана" % [info["text"], meat], Color(1.0, 0.85, 0.35))
			float_text(pos + Vector2(0, -40), "+%d м'яса" % meat, Color(1.0, 0.8, 0.6))
			spawn_pickup(pos, "res", 1 + player.pk("h_trophy"), {"res": Camp.TROPHY})
	Audio.play("quest", 0.0)
	Events.trail_found.emit(str(trail.kind))


## Ціль із дошки розшуку: іменована еліта десь у місцевості, сама йде на козака.
func _spawn_bounty(b: Dictionary) -> void:
	var pos := _clamp_in(player.position + Vector2.from_angle(randf() * TAU) * 820.0, 100.0)
	spawn_enemy(b["kind"], int(b["level"]), false, pos)
	var e = _last_enemy()
	e.make_elite(b["affixes"])
	e.max_hp *= 2.5
	e.hp = e.max_hp
	e.damage *= 1.2
	e.xp_value *= 3
	e.base_scale = 1.45
	e.scale = Vector2.ONE * e.base_scale
	e.title = b["name"]
	e.bounty_id = int(b["id"])
	Events.hint.emit("bounty", "Розшукувана нечисть десь тут і сама тебе знайде. Золоте коло й ім'я над головою — це вона. Убий і неси голову в місто.")


func leave() -> void:
	if active and counts_as_trip() and not player.trip_buffs.is_empty():
		player.trip_buffs.clear()  # зілля й страва «на похід» діють один похід (герць на майдані походом не є)
		player.recalc()
	active = false
	player.statuses.clear()
	Engine.time_scale = 1.0
	_clear()
	set_visible_world(false)


func is_dungeon() -> bool:
	return loc.get("type", "") == "dungeon"


func is_defense() -> bool:
	return loc.get("type", "") == "defense"


func is_tower() -> bool:
	return loc.get("type", "") == "tower"


func is_duel() -> bool:
	return loc.get("type", "") == "duel"


func is_field() -> bool:
	return loc.get("type", "") == "field"


func is_vigil() -> bool:
	return loc.get("type", "") == "vigil"


## Чи рахується цей бій походом (після нього світ робить крок: зараза, облоги, події).
func counts_as_trip() -> bool:
	return not is_duel()


# ======================= Козацька варта =======================

## Варта на сторожовій могилі: нечисть суне без упину й лютішає щохвилини; вечоріє, далі — ніч.
func enter_vigil(dl: Dictionary, companions: Array) -> void:
	loc = dl
	plague = 0
	plague_mods = PlagueService.mods(0)
	room = 0
	vigil_time = 0.0
	vigil_kills = 0
	vigil_minute = 0
	vigil_done = false
	field_cleared = false
	spawn_timer = 2.5
	player.unbreak_ready = true
	player.berehynia_ready = true
	_setup_arena(companions)
	_vigil_day = canvas_mod.color
	ground._prop("wall:tower", Vector2(0, -150))
	_vigil_fire = CampfireScript.new()
	_vigil_fire.position = Vector2(90, -60)
	entities.add_child(_vigil_fire)
	_vigil_fire.setup(light_tex)
	set_visible_world(true)
	active = true
	Events.banner.emit("Козацька варта\nВистій %d хвилин" % int(float(dl["goal"]) / 60.0), Color(1.0, 0.85, 0.4))


func _update_vigil(delta: float) -> void:
	vigil_time += delta
	# Вечоріє: з першої хвилини світ темнішає, згодом світить лише вогнище на могилі
	var k := clampf((vigil_time - 45.0) / 200.0, 0.0, 1.0)
	canvas_mod.color = _vigil_day.lerp(_vigil_day * Color(0.3, 0.32, 0.5), k)
	if _vigil_fire != null and is_instance_valid(_vigil_fire):
		_vigil_fire.darkness = k
	var m := int(vigil_time / 60.0)
	if m > vigil_minute:
		vigil_minute = m
		_vigil_minute_up()
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.45, 1.3 - 0.14 * vigil_minute)
		if alive_enemy_count() < 8 + 3 * vigil_minute:
			var en: Array = loc["enemies"]
			spawn_enemy(en[randi() % en.size()], int(loc["level"]) + vigil_minute / 2)
			var e = _last_enemy()
			if e != null and int(loc["level"]) >= Elites.MIN_LEVEL and randf() < 0.05 + 0.03 * vigil_minute:
				e.make_elite(Elites.roll_affixes(int(loc["level"])))
	if vigil_done:
		_check_exit_portal()


func _vigil_minute_up() -> void:
	loc.merge(VigilService.targets_at(player, vigil_minute), true)
	Audio.play("roar", 0.1, -6.0)
	var goal_min := int(float(loc["goal"]) / 60.0)
	if vigil_minute == goal_min - 1:
		# Остання хвилина: на могилу йде ватажок
		spawn_enemy(loc["enemies"][0], int(loc["level"]) + 1, true)
	if vigil_minute >= goal_min and not vigil_done:
		vigil_done = true
		Audio.jingle("victory")
		field_cleared = true
		_spawn_portal("З варти", _clamp_in(player.global_position + Vector2(0, -220), 100.0))
	Events.vigil_minute.emit(vigil_minute)


# ======================= Герць на майдані =======================

## Сам на сам із суперником на майдані Січі: без побратимів, довкола глядачі.
func enter_duel(dl: Dictionary) -> void:
	loc = dl
	plague = 0
	plague_mods = PlagueService.mods(0)
	room = int(dl.get("round", 0))
	duel_over = false
	field_cleared = false
	player.unbreak_ready = true
	player.berehynia_ready = true
	_setup_arena([])
	set_visible_world(true)
	active = true
	spawn_enemy("rival", int(dl["level"]), false, Vector2(0, arena.position.y + 190))
	var e = _last_enemy()
	e.make_rival(Acts.RIVALS[dl["rival"]], float(dl["rival_hp"]), float(dl["rival_dmg"]), float(dl.get("rival_cap", 0.0)))
	_duel_hp = e.hp
	_spawn_spectators()
	Events.banner.emit("%s\nКоло %d із 3" % [dl["name"], int(dl["round"]) + 1], Color(1.0, 0.85, 0.4))


func _spawn_spectators() -> void:
	spectators.clear()
	var sheets: Array = Acts.SPECTATORS
	var spots := []
	var x := arena.position.x + 30.0
	while x < arena.end.x - 20.0:
		spots.append([Vector2(x, arena.position.y - 34.0), Vector2.DOWN])
		spots.append([Vector2(x + 26.0, arena.end.y + 58.0), Vector2.UP])
		x += 62.0
	var y := arena.position.y + 40.0
	while y < arena.end.y - 20.0:
		spots.append([Vector2(arena.position.x - 44.0, y), Vector2.RIGHT])
		spots.append([Vector2(arena.end.x + 44.0, y), Vector2.LEFT])
		y += 70.0
	for sp in spots:
		if randf() < 0.2:
			continue  # подекуди порожнє місце
		var s = SpectatorScript.new()
		s.sheet = sheets[randi() % sheets.size()]
		s.look = sp[1]
		s.position = sp[0] + Vector2(randf_range(-8, 8), randf_range(-6, 6))
		entities.add_child(s)
		spectators.append(s)


func cheer(dur: float = 0.7) -> void:
	for s in spectators:
		if is_instance_valid(s) and randf() < 0.6:
			s.cheer = dur * randf_range(0.6, 1.2)


func _update_duel(_delta: float) -> void:
	if duel_over:
		_check_exit_portal()
		return
	var rival = nearest_enemy(player.global_position, 5000.0)
	if rival != null:
		if rival.hp < _duel_hp - 1.0:
			cheer()
		_duel_hp = rival.hp
		return
	duel_over = true
	field_cleared = true
	cheer(2.5)
	Audio.play("quest", 0.0)
	Audio.jingle("victory")
	Audio.play_music("map")
	_spawn_portal("До Січі", Vector2(0, 0))
	Events.duel_won.emit()


# ======================= Башта Кощія =======================

## Поверх: хвилі нечисті, потім міні-бос (іменована еліта) або супербос. Пройшов — портал «Вище».
func _start_floor() -> void:
	wave = 0
	wave_timer = 1.5
	tower_boss_spawned = false
	field_cleared = false
	room_cleared = false
	Audio.play_music("battle")
	Events.banner.emit("%s\n%s" % [loc["name"], ("Супербос: %s!" % Data.BOSS_NAMES[loc["boss"]]) if loc["boss"] != "" else "Хвиль: %d, далі — %s" % [loc["waves"], loc["mini_title"].to_lower()]], Color(1.0, 0.7, 0.4))


## Наступний поверх без виходу з бою (поранені побратими лишаються пораненими).
func next_floor(new_loc: Dictionary) -> void:
	collect_all()
	custom_loc = new_loc
	loc = new_loc
	var comps := _companion_states()
	room += 1
	_setup_arena(comps)
	_start_floor()


func _update_tower(delta: float) -> void:
	_update_plague(delta)
	if field_cleared:
		if _player_in_portal():
			Audio.play("portal", 0.0)
			Events.tower_next.emit(int(loc["floor"]))
		return
	if alive_enemy_count() > 0:
		return
	if tower_boss_spawned:
		_tower_complete()
		return
	wave_timer -= delta
	if wave_timer > 0.0:
		return
	if wave < int(loc["waves"]):
		wave += 1
		wave_timer = 2.5
		_spawn_tower_wave()
	else:
		tower_boss_spawned = true
		_spawn_tower_boss()


func _spawn_tower_wave() -> void:
	var en: Array = loc["enemies"]
	var lvl := int(loc["level"])
	Events.banner.emit("Хвиля %d/%d" % [wave, loc["waves"]], Color(1.0, 0.7, 0.4))
	for i in 5 + wave + int(loc["floor"]) / 6:
		var pos := Vector2(randf_range(arena.position.x + 80, arena.end.x - 80), randf_range(arena.position.y + 80, arena.position.y + arena.size.y * 0.5))
		spawn_enemy(en[randi() % en.size()], maxi(1, lvl - 1), false, pos)
		_maybe_elite(_last_enemy())


func _spawn_tower_boss() -> void:
	var lvl := int(loc["level"])
	var pos := Vector2(0, arena.position.y + 220)
	if loc["boss"] != "":
		spawn_enemy(loc["boss"], lvl, true, pos)
		var b = _last_enemy()
		b.max_hp *= float(loc.get("boss_hp_mult", 1.0))
		b.hp = b.max_hp
		b.damage *= float(loc.get("boss_dmg_mult", 1.0))
		Events.banner.emit("%s!" % Data.BOSS_NAMES[loc["boss"]], Color(1.0, 0.55, 0.2))
		return
	# Міні-бос: іменована еліта з 2–3 властивостями, удвічі міцніша за звичайну
	spawn_enemy(loc["mini"], lvl, false, pos)
	var e = _last_enemy()
	var keys := Elites.AFFIXES.keys()
	keys.shuffle()
	e.make_elite(keys.slice(0, int(loc["mini_affixes"])))
	e.max_hp *= 3.0
	e.hp = e.max_hp
	e.damage *= 1.25
	e.xp_value *= 3
	e.base_scale = 1.5
	e.scale = Vector2.ONE * e.base_scale
	e.title = "%s: %s" % [loc["mini_title"], e.title]
	Audio.play("roar", 0.05, -4.0)
	shake(8.0)
	Events.banner.emit("%s!" % e.title, Color(1.0, 0.75, 0.3))


func _tower_complete() -> void:
	field_cleared = true
	Audio.play("quest", 0.0)
	_spawn_portal("Вище", Vector2(0, arena.position.y + 110))
	Events.tower_cleared.emit(int(loc["floor"]))


# ======================= Оборона =======================

## Бій біля брами: хвилі нечисті йдуть згори, брама — внизу.
func enter_defense(dl: Dictionary, companions: Array) -> void:
	loc = dl
	plague = 0
	plague_mods = PlagueService.mods(0)
	room = 0
	wave = 0
	wave_timer = 2.5
	defense_over = false
	field_cleared = false
	player.unbreak_ready = true
	player.berehynia_ready = true
	_setup_arena(companions)
	set_visible_world(true)
	active = true
	gate = GateScript.new()
	gate.combat = self
	gate.camp = dl.get("camp", false)
	gate.variant = dl.get("variant", "camp" if dl.get("camp", false) else "city")
	gate.max_hp = float(dl["gate_hp"])
	gate.hp = gate.max_hp
	gate.position = Vector2(0, arena.end.y - 170)
	if gate.variant == "escort":
		# Супровід: замість брами — мандрівник; він менший за мур, його можна лікувати
		var w: Dictionary = Acts.ESCORT_WHO[dl["who"]]
		gate.sheet = w["sheet"]
		gate.who_name = w["name"]
		gate.radius = 22.0
		gate.plague_immune = false
	entities.add_child(gate)
	var hint_line: String = {"village": "Не дай спалити хати!", "caravan": "Вози їдуть — не дай їх розбити!", "captives": "Вбережи бранців!", "wounded": "Вбережи пораненого!",
		"escort": "Іди поруч: на шляху засідки!"}.get(gate.variant, "Не дай зламати браму!")
	Events.banner.emit(dl["name"] + "\n" + hint_line, Color(1.0, 0.6, 0.4))


func _update_defense(delta: float) -> void:
	if defense_over:
		_check_exit_portal()
		return
	if gate != null and is_instance_valid(gate) and gate.variant == "escort":
		_update_escort(delta)
		return
	if gate != null and is_instance_valid(gate) and gate.variant == "caravan" and gate.alive:
		# Валка повільно їде вгору ареною; нечисть наздоганяє
		gate.position.y = maxf(arena.position.y + 220.0, gate.position.y - 22.0 * delta)
	if alive_enemy_count() > 0:
		return
	if wave >= int(loc["waves"]):
		_defense_complete()
		return
	wave_timer -= delta
	if wave_timer > 0.0:
		return
	wave += 1
	wave_timer = 3.0
	_spawn_wave()


func _spawn_wave() -> void:
	var en: Array = loc["enemies"]
	var lvl := int(loc["level"])
	var last := wave == int(loc["waves"])
	Events.banner.emit("Хвиля %d/%d%s" % [wave, loc["waves"], "\nВатажок!" if last else ""], Color(1.0, 0.7, 0.4))
	Audio.play("roar", 0.1, -6.0)
	for i in 4 + 2 * wave:
		var pos := Vector2(randf_range(arena.position.x + 80, arena.end.x - 80), randf_range(arena.position.y + 60, arena.position.y + 260))
		spawn_enemy(en[randi() % en.size()], lvl, false, pos)
		var e = _last_enemy()
		e.rams_gate = i % 2 == 1  # половина нечисті одразу йде на браму
		if wave >= 3 and i == 0:
			e.make_elite(Elites.roll_affixes(lvl))
	if last:
		spawn_enemy(en[0], lvl, true, Vector2(0, arena.position.y + 140))


## Де починається й де кінчається шлях мандрівника (y на арені).
func escort_route() -> Vector2:
	return Vector2(arena.end.y - 170.0, arena.position.y + 190.0)


## Яку частку шляху мандрівник уже пройшов (0..1).
func escort_part() -> float:
	if gate == null or not is_instance_valid(gate):
		return 0.0
	var r := escort_route()
	return clampf((r.x - gate.position.y) / (r.x - r.y), 0.0, 1.0)


## Супровід: мандрівник іде ареною знизу вгору. На шляху засідки; поки нечисть поруч — стоїть.
## Дійшов до кінця, і нечисті не лишилось — завдання виконано.
func _update_escort(delta: float) -> void:
	if not gate.alive:
		return
	gate.walking = false
	# Боїться, коли нечисть поруч або коли щойно влучили здалеку (стрільці тримаються осторонь)
	gate.scared = gate.flinch > 0.0 or nearest_enemy(gate.global_position, Acts.ESCORT_FEAR) != null
	wave_timer -= delta
	if wave_timer > 0.0 or gate.scared:
		return
	var waves := int(loc["waves"])
	var part := escort_part()
	if wave < waves and part >= float(wave + 1) / float(waves + 1):
		if alive_enemy_count() > 0:
			return  # попередню засідку ще не добито — далі не йде
		wave += 1
		_spawn_ambush()
		return
	if part >= 1.0:
		if alive_enemy_count() == 0:
			_defense_complete()
		return
	gate.walking = true
	gate.position.y = maxf(escort_route().y, gate.position.y - Acts.ESCORT_SPEED * delta)


## Засідка на шляху: нечисть вискакує півколом попереду й з боків, не впритул до мандрівника.
func _spawn_ambush() -> void:
	var en: Array = loc["enemies"]
	var lvl := int(loc["level"])
	var last := wave == int(loc["waves"])
	Events.banner.emit("Засідка %d/%d%s" % [wave, loc["waves"], "\nВатажок!" if last else ""], Color(1.0, 0.7, 0.4))
	Audio.play("roar", 0.1, -6.0)
	for i in Acts.ESCORT_PACK + Acts.ESCORT_PACK_STEP * wave:
		var ang := -PI / 2.0 + randf_range(-1.9, 1.9)
		var pos := _clamp_in(gate.position + Vector2.from_angle(ang) * randf_range(430.0, 580.0), 70.0)
		spawn_enemy(en[randi() % en.size()], lvl, false, pos)
		var e = _last_enemy()
		e.rams_gate = i % 2 == 1  # половина нечисті одразу кидається на мандрівника
		if last and i == 0:
			e.make_elite(Elites.roll_affixes(lvl))  # ватажок засідки


func _defense_complete() -> void:
	defense_over = true
	field_cleared = true
	Audio.play("quest", 0.0)
	Audio.jingle("victory")
	Audio.play_music("map")
	var pos: Vector2 = player.global_position + Vector2(0, -120)
	for i in 6:
		spawn_pickup(pos, "coin", int(loc["level"]) * 3)
	spawn_pickup(pos, "item", 0, Data.gen_item(int(loc["level"]), Data.roll_rarity(int(loc["level"]), 1)))
	_spawn_portal("До брами" if not (loc.has("event") or loc.has("escort")) else "На мапу", _clamp_in(player.global_position + Vector2(0, -220), 100.0))
	Events.defense_won.emit(loc["target"])


## Браму зламано — оборону програно.
func on_gate_destroyed() -> void:
	if defense_over:
		return
	defense_over = true
	if gate.variant == "escort":
		# Мандрівника не вберегли: він кидає все й тікає (див. gate.gd)
		shake(8.0)
		Audio.play("hurt", 0.0)
		fx.burst(gate.global_position, Color(0.9, 0.85, 0.7), 14, 200, 6, 0.6)
	else:
		shake(16.0)
		Audio.play("boom", 0.0)
		fx.burst(gate.global_position, Color(0.5, 0.35, 0.2), 40, 320, 9, 0.8)
	Events.defense_lost.emit(loc["target"])


func _setup_arena(companions: Array) -> void:
	_clear()
	arena = _arena_rect()
	player.position = _start_pos()
	ground.setup(arena, loc["biome"], hash(loc_id) + room * 31)
	_setup_atmosphere(loc["biome"])
	camera.limit_left = int(arena.position.x - 120)
	camera.limit_top = int(arena.position.y - 160)
	camera.limit_right = int(arena.end.x + 120)
	camera.limit_bottom = int(arena.end.y + 120)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	_spawn_companions(companions)


func _arena_rect() -> Rect2:
	if is_duel():
		return DUEL_ARENA
	if is_vigil():
		return VIGIL_ARENA
	if is_dungeon() or is_tower():
		return DUNGEON_ARENA
	return DEFENSE_ARENA if is_defense() else FIELD_ARENA


func _start_pos() -> Vector2:
	if is_duel():
		return Vector2(0, arena.end.y - 150)
	if is_dungeon() or is_tower():
		return Vector2(0, arena.end.y - 160)
	return Vector2(0, arena.end.y - 330) if is_defense() else Vector2.ZERO


func _clear() -> void:
	spectators.clear()
	_drop_trail()
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
	gate = null
	fx.clear()


func _spawn_companions(companions: Array) -> void:
	companion_nodes.clear()
	for i in companions.size():
		var data: Dictionary = companions[i]
		if data["downed"]:
			continue
		var c: Companion = CompanionScript.new()
		c.combat = self
		c.setup(data["type"], int(data.get("level", player.level)), data.get("index", i), data)
		c.position = player.position + CompanionScript.OFFSETS[c.index % CompanionScript.OFFSETS.size()]
		entities.add_child(c)
		companion_nodes.append(c)


func _setup_atmosphere(biome: String) -> void:
	canvas_mod.color = BIOME_TINT.get(biome, Color.WHITE).lerp(Color(0.7, 0.95, 0.55), 0.12 * plague)  # зараза зеленить світ
	var night: bool = loc.get("night", false)
	if night:
		canvas_mod.color = canvas_mod.color * Color(0.3, 0.32, 0.5)  # ніч: синя пітьма, світить лише смолоскип героя
	torch.enabled = biome in ["cave", "plague"] or night
	torch_base = 1.15 if biome in ["cave", "plague"] else 0.6
	for c in lights.get_children():
		c.queue_free()
	if biome in ["cave", "plague"]:
		for c in ground.crystals:
			var l := PointLight2D.new()
			l.texture = light_tex
			l.texture_scale = 1.6
			l.color = c[1]
			l.energy = 1.1
			l.position = c[0]
			lights.add_child(l)
	ambient.setup(biome)


## Чи можна зараз піти з локації (поруч немає ворогів).
func can_leave() -> bool:
	return nearest_enemy(player.global_position, 350.0) == null


# ======================= Цикл =======================

func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	if torch.enabled:
		torch.energy = torch_base + sin(_time * 13.0) * 0.05 + randf() * 0.06
	camera.global_position = player.global_position
	if shake_strength > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	player.attack_held = attack_input.call()
	player.block_held = block_input.call()
	if is_duel():
		_update_duel(delta)
	elif is_vigil():
		_update_vigil(delta)
	elif is_tower():
		_update_tower(delta)
	elif is_dungeon():
		_update_dungeon()
	elif is_defense():
		_update_defense(delta)
	else:
		_update_field(delta)


## Заражена місцевість: хмари зарази час від часу здіймаються біля нечисті.
func _update_plague(delta: float) -> void:
	var every: float = plague_mods.get("cloud_every", 0.0)
	if every <= 0.0:
		return
	cloud_timer -= delta
	if cloud_timer > 0.0:
		return
	cloud_timer = every * randf_range(0.8, 1.2)
	var e = nearest_enemy(player.global_position, 700.0)
	var pos: Vector2 = e.global_position if e else player.global_position + Vector2.from_angle(randf() * TAU) * 260.0
	spawn_plague(pos, 4.0 + 1.5 * int(loc["level"]))


func _update_field(delta: float) -> void:
	_update_plague(delta)
	_update_trail()
	if field_cleared:
		_check_exit_portal()
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.6, 1.5 - loc["level"] * 0.05)
		if alive_enemy_count() < 7 + int(loc["level"]):
			var en: Array = loc["enemies"]
			var kind: String = en[randi() % en.size()]
			if randf() < plague_mods.get("infected", 0.0):
				kind = "zarazhenyi"  # зараза жене своїх солдатів
			spawn_enemy(kind, loc["level"] + (1 if randf() < 0.15 else 0))
			_maybe_elite(_last_enemy())


func _spawn_room() -> void:
	room_cleared = false
	var en: Array = loc["enemies"]
	# Рядова нечисть у печері на рівень нижча — головна загроза тут бос
	var minion_level := maxi(1, int(loc["level"]) - 1)
	for i in Data.DUNGEON_ROOM_BASE + room * Data.DUNGEON_ROOM_PER:
		var pos := Vector2(randf_range(arena.position.x + 80, arena.end.x - 80), randf_range(arena.position.y + 80, arena.position.y + arena.size.y * 0.55))
		spawn_enemy(en[randi() % en.size()], minion_level, false, pos)
		_maybe_elite(_last_enemy())
	if room == int(loc["rooms"]):
		spawn_enemy(loc["boss"], loc["level"], true, Vector2(0, arena.position.y + 220))
		Events.banner.emit("%s!" % Data.BOSS_NAMES[loc["boss"]], Color(1.0, 0.55, 0.2))
	else:
		Events.banner.emit("%s\nКімната %d/%d" % [loc["name"], room, loc["rooms"]], Color(1, 0.92, 0.7))


func _update_dungeon() -> void:
	if not room_cleared and alive_enemy_count() == 0:
		room_cleared = true
		if room < int(loc["rooms"]):
			_spawn_portal("Далі", Vector2(0, arena.position.y + 110))
			Events.banner.emit("Прохід відкрито!", Color(0.6, 1.0, 0.6))
		else:
			_dungeon_complete()
	if _player_in_portal():
		Audio.play("portal", 0.0)
		collect_all()
		if room < int(loc["rooms"]):
			var comps := _companion_states()
			room += 1
			_setup_arena(comps)
			_spawn_room()
		else:
			Events.exit_requested.emit()


func _check_exit_portal() -> void:
	if _player_in_portal():
		Audio.play("portal", 0.0)
		collect_all()
		Events.exit_requested.emit()


func _player_in_portal() -> bool:
	return portal != null and is_instance_valid(portal) and player.global_position.distance_to(portal.global_position) < 60.0


## Поточний стан супутників (щоб пронести поранених між кімнатами печери).
func _companion_states() -> Array:
	var out := []
	for c in companion_nodes:
		if is_instance_valid(c):
			out.append({"type": c.type, "downed": not c.alive, "index": c.index, "level": c.level,
				"hero": c.hero, "mult": c.mult, "name": c.display_name, "color": c.info["color"]})
	out.sort_custom(func(a, b): return a["index"] < b["index"])
	return out


func _spawn_portal(text: String, pos: Vector2) -> void:
	portal = PortalScript.new()
	portal.label = text
	portal.position = pos
	entities.add_child(portal)


func _field_complete() -> void:
	field_cleared = true
	var g: int = 25 * int(loc["level"])
	player.add_gold(g)
	Audio.play("quest", 0.0)
	Events.banner.emit("%s очищено!\n+%d грн і скарб" % [loc["name"], g], Color(1.0, 0.85, 0.3))
	var pos: Vector2 = player.global_position + Vector2(0, -120)
	for i in 2:
		spawn_pickup(pos, "item", 0, Data.gen_item(loc["level"], Data.roll_rarity(loc["level"], 1)))
	for i in 6:
		spawn_pickup(pos, "coin", int(loc["level"]) * 2)
	_resource_bundle(pos, 5)
	_spawn_portal("На мапу", _clamp_in(player.global_position + Vector2(0, -260), 100.0))
	Events.field_cleared.emit(loc_id)
	Events.hint.emit("cleared", "Місцевість очищено! Збери скарб і зайди в портал, щоб повернутися на мапу.")


func _dungeon_complete() -> void:
	var g: int = 40 * int(loc["level"])
	player.add_gold(g)
	Events.banner.emit("%s очищено!\n+%d грн" % [loc["name"], g], Color(1.0, 0.85, 0.3))
	Audio.play("quest", 0.0)
	_resource_bundle(player.global_position + Vector2(0, -100), 7)
	_spawn_portal("Вихід", Vector2(0, arena.position.y + 110))
	Events.dungeon_cleared.emit(loc_id)


## Збирає всю здобич, що лишилась на землі (перед переходом або виходом).
func collect_all() -> void:
	for c in entities.get_children():
		if c.get_script() == PickupScript and not c.is_queued_for_deletion():
			match c.kind:
				"coin":
					player.add_xp(c.value)
					player.add_gold(Data.coin_gold(c.value))
				"item":
					pick_item(c.item)
				"res":
					add_resource(c.item["res"], c.value)
				"token":
					Events.holiday_token.emit(c.value, c.global_position)  # жетони свята не лишаються на полі
			c.queue_free()


# ======================= Нечисть і здобич =======================

func _on_enemy_killed(e: Node2D) -> void:
	if not active:
		return
	Audio.play("roar" if e.is_boss else Sounds.death(e.kind), 0.15, 0.0)
	fx.burst(e.global_position + Vector2(0, -10), Color(0.25, 0.2, 0.25, 0.8), 40 if e.is_boss else 12, 320 if e.is_boss else 180, 9, 0.6, -60)
	if e.is_boss:
		fx.ring(e.global_position, Color(1.0, 0.8, 0.3), 40, 600, 8, 0.7)
		hitstop(0.15)
	else:
		hitstop(0.03)
	if is_vigil():
		vigil_kills += 1
	if not is_duel() and HolidayService.active() != "":
		var tk := HolidayService.token_roll(e.is_boss, e.elite, randf())
		for i in tk:
			spawn_pickup(e.global_position, "token", 1, {"icon": "tok_" + HolidayService.active()})
	if is_field() and not field_cleared:
		field_kills += 1
		if field_kills >= field_goal:
			_field_complete()
	_drop_loot(e)


func _drop_loot(e: Node2D) -> void:
	if is_duel():
		return  # на майдані здобичі нема — нагороду дає кошовий
	var pos: Vector2 = e.global_position
	var ilvl: int = loc.get("level", 1)
	var heal_value := int(20 * (1.0 + 0.5 * player.varenyk_bonus))
	if e.is_boss:
		shake(14.0)
		Audio.jingle("victory")
		Audio.play_music("map")  # бій скінчено: замість бойової теми — спокійна
		Events.banner.emit("%s переможений!" % Data.BOSS_NAMES.get(e.kind, "Бос"), Color(1.0, 0.85, 0.3))
		for i in 10:
			spawn_pickup(pos, "coin", maxi(1, e.xp_value / 10))
		for i in 2:
			spawn_pickup(pos, "item", 0, _loot(ilvl + 1, Data.roll_rarity(ilvl, 2)))
		spawn_pickup(pos, "varenyk", heal_value * 2)
		spawn_pickup(pos, "potion", 1)
		spawn_pickup(pos, "res", 3 + int(loc.get("level", 1)) / 5 + player.pk("h_trophy") + int(festive.get("trophy", 0)), {"res": Camp.TROPHY})
	elif e.bounty_id > 0:
		for i in 6:
			spawn_pickup(pos, "coin", maxi(2, e.xp_value / 5))
		spawn_pickup(pos, "item", 0, _loot(ilvl, maxi(1, Data.roll_rarity(ilvl, 1))))
		_resource_bundle(pos, 3)
		spawn_pickup(pos, "res", 2 + player.pk("h_trophy") + int(festive.get("trophy", 0)), {"res": Camp.TROPHY})
		Events.bounty_killed.emit(e.bounty_id)
	elif e.treasure_guard:
		Events.banner.emit("Сторожа скарбу вбито!\nСкриня твоя", Color(1.0, 0.85, 0.35))
		spawn_pickup(pos, "item", 0, _loot(ilvl + 1, maxi(2, Data.roll_rarity(ilvl, 2))))
		for i in 8:
			spawn_pickup(pos, "coin", maxi(2, e.xp_value / 4))
		_resource_bundle(pos, 4)
		Events.treasure_found.emit(loc_id)
	elif e.elite:
		Events.banner.emit("%s переможена!" % e.title if e.kind in Elites.FEMININE else "%s переможений!" % e.title, Color(1.0, 0.85, 0.35))
		for i in 3:
			spawn_pickup(pos, "coin", maxi(1, e.xp_value / 3))
		if randf() < Elites.ITEM_CHANCE * (1.0 + float(festive.get("loot", 0.0))):
			spawn_pickup(pos, "item", 0, _loot(ilvl, Data.roll_rarity(ilvl, 1)))
		_resource_bundle(pos, 2)
		spawn_pickup(pos, "res", 1 + player.pk("h_trophy") + int(festive.get("trophy", 0)), {"res": Camp.TROPHY})
		if randf() < 0.3:
			spawn_pickup(pos, "potion", 1)
	else:
		spawn_pickup(pos, "coin", e.xp_value)
		if randf() < 0.05 * (1 + player.varenyk_bonus) * (1.0 + float(festive.get("varenyk", 0.0))):
			spawn_pickup(pos, "varenyk", heal_value)
		if randf() < Camp.RESOURCE_DROP_CHANCE:
			spawn_pickup(pos, "res", _res_amount(1), {"res": _roll_resource()})
		if randf() < Data.POTION_DROP_CHANCE:
			spawn_pickup(pos, "potion", 1)
		if randf() < Data.MANA_POTION_DROP_CHANCE * (2.0 if player.is_volkhv() else 1.0):
			spawn_pickup(pos, "mana", 1)
		if randf() < Data.ITEM_DROP_CHANCE * (1.0 + float(festive.get("loot", 0.0))):
			spawn_pickup(pos, "item", 0, _loot(ilvl, Data.roll_rarity(ilvl)))


## Річ із нечисті. На Катерини доля всміхається: частина речей на рідкість краща.
func _loot(ilvl: int, rarity: int) -> Dictionary:
	if rarity < Data.RARITY_NAMES.size() - 1 and randf() < float(festive.get("rare", 0.0)):
		rarity += 1
	return Data.gen_item(ilvl, rarity)


## Скільки ресурсу в одній купці з урахуванням свята (Зелені свята — вдвічі).
func _res_amount(n: int) -> int:
	return int(round(n * (1.0 + float(festive.get("res", 0.0)))))


## Ресурс для хутора: здебільшого той, яким багатий ландшафт.
func _roll_resource() -> String:
	if randf() < 0.7:
		return Camp.BIOME_RESOURCE.get(loc.get("biome", "steppe"), "wood")
	return Camp.RESOURCES.keys()[randi() % Camp.RESOURCES.size()]


func _resource_bundle(pos: Vector2, n: int) -> void:
	for i in n:
		spawn_pickup(pos, "res", _res_amount(1 + int(loc.get("level", 1)) / 4), {"res": _roll_resource()})


func add_resource(r: String, amount: int) -> void:
	if r != Camp.TROPHY and randf() < 0.15 * player.pk("h_eye"):
		amount *= 2  # Зіркий погляд (Загартування)
	player.resources[r] = int(player.resources.get(r, 0)) + amount


func pick_item(item: Dictionary) -> void:
	var col: Color = Data.RARITY_COLORS[item["rarity"]]
	if autosell and int(item["rarity"]) == 0 and player.bag_full():
		var g0 := Data.sell_price(item)
		player.gold += g0
		float_text(player.global_position + Vector2(0, -70), "Мотлох продано: +%d грн" % g0, col)
		return
	if player.add_item(item):
		float_text(player.global_position + Vector2(0, -70), item["name"], col)
		Audio.play("item", 0.0)
		Events.item_found.emit(item)
	else:
		var g := Data.sell_price(item)
		player.gold += g
		float_text(player.global_position + Vector2(0, -70), "Торба повна: +%d грн" % g, col)


## Супутник підріс просто в бою: оновлюємо показники й радіємо разом.
func companion_level_up(index: int, lvl: int) -> void:
	for c in companion_nodes:
		if is_instance_valid(c) and c.index == index and c.alive:
			c.set_level(lvl)
			float_text(c.global_position + Vector2(0, -50), "Рівень %d!" % lvl, Color(0.6, 1.0, 0.6))
			fx.ring(c.global_position, Color(0.6, 1.0, 0.6), 20, 200, 4, 0.5)


func on_companion_down(c: Companion) -> void:
	var name: String = c.display_name
	float_text(c.global_position + Vector2(0, -40), "%s поранений!" % name, Color(1.0, 0.5, 0.45))
	Events.companion_down.emit(c.index, name)


# ======================= Сервіси для сутностей =======================

func allies() -> Array:
	var out := []
	if player and player.alive:
		out.append(player)
	for c in companion_nodes:
		if is_instance_valid(c) and c.alive:
			out.append(c)
	if gate != null and is_instance_valid(gate) and gate.alive:
		out.append(gate)
	return out


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


func get_move_input() -> Vector2:
	return move_input.call()


func _clamp_in(pos: Vector2, margin: float) -> Vector2:
	return pos.clamp(arena.position + Vector2(margin, margin), arena.end - Vector2(margin, margin))


func spawn_enemy(kind: String, level: int, boss: bool = false, pos = null) -> void:
	if pos == null:
		pos = Vector2.ZERO
		for i in 10:
			pos = _clamp_in(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(650, 850), 60.0)
			if pos.distance_to(player.global_position) > 420.0:
				break
	var e: Enemy = EnemyScript.new()
	e.combat = self
	e.position = pos
	e.setup(kind, level, boss)
	if loc.has("std_hp"):
		# Варта: нечисть міряється силою з героєм (std — звичайний заражений; інші види — у своїй пропорції)
		var s0: float = Data.ENEMY_HP_MULT * (1.0 + Data.ENEMY_HP_PER_LEVEL * (level - 1))
		e.max_hp = e.max_hp / (70.0 * s0) * float(loc["std_hp"])
		e.hp = e.max_hp
		e.damage = e.damage / (13.0 * (1.0 + Data.ENEMY_DMG_PER_LEVEL * (level - 1))) * float(loc["std_dmg"])
		e.xp_value = maxi(1, int(e.xp_value * float(loc.get("xp_mult", 1.0))))
	elif loc.has("hp_mult"):
		e.max_hp *= float(loc["hp_mult"])
		e.hp = e.max_hp
		e.damage *= float(loc["dmg_mult"])
		e.xp_value = int(e.xp_value * float(loc["xp_mult"]))
	if plague > 0:
		e.max_hp *= plague_mods["hp"]
		e.hp = e.max_hp
		e.damage *= plague_mods["dmg"]
		e.xp_value = int(e.xp_value * plague_mods["reward"])
		e.infected = plague
	entities.add_child(e)
	if e.is_boss:
		Audio.play("roar", 0.0)
		Audio.play_music("boss")
		shake(10.0)
		Events.boss_spawned.emit(e)


func _new_projectile(pos: Vector2, vel: Vector2, dmg: float) -> Projectile:
	var p: Projectile = ProjectileScript.new()
	_last_proj = p
	p.combat = self
	p.position = pos
	p.velocity = vel
	p.damage = dmg
	effects.add_child(p)
	return p


func spawn_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float, source = null) -> void:
	var p := _new_projectile(pos, dir * spd, dmg)
	p.color = col
	p.radius = r
	p.source = source


## Остання випущена куля/снаряд (щоб вміння могли її налаштувати).
var _last_proj = null


func last_projectile():
	return _last_proj


## Пастка пластуна. max_count — скільки пасток може стояти одночасно (старі зникають).
func spawn_trap(pos: Vector2, dmg: float, crit: bool, max_count: int) -> void:
	var traps := effects.get_children().filter(func(n): return n.get_script() == TrapScript and n.kind == "trap" and not n.is_queued_for_deletion())
	while traps.size() >= max_count:
		traps.pop_front().queue_free()
	var t = TrapScript.new()
	t.combat = self
	t.position = pos
	t.damage = dmg
	t.crit = crit
	effects.add_child(t)


## Зона чарів волхва (grad / tuman / otruta) або дух-помічник (spirit).
func spawn_zone(kind: String, pos: Vector2, r: float, dur: float, dmg: float) -> void:
	var z = ZoneScript.new()
	z.combat = self
	z.kind = kind
	z.position = pos
	z.radius = r
	z.duration = dur
	z.damage = dmg
	effects.add_child(z)


## Знахар підіймає поранених побратимів просто в бою. Повертає, скількох підняв.
func revive_companions(pct: float) -> int:
	var n := 0
	for c in companion_nodes:
		if is_instance_valid(c) and not c.alive:
			c.alive = true
			c.visible = true
			c.hp = c.max_hp * pct
			c.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * 60.0
			fx.burst(c.global_position, Color(1.0, 0.9, 0.5), 18, 160, 5, 0.6, -60)
			Events.companion_revived.emit(c.index)
			n += 1
	return n


## Бочка пороху: вибухає за мить.
func spawn_barrel(pos: Vector2, dmg: float, crit: bool, blast: float, burn: float) -> void:
	var t = TrapScript.new()
	t.combat = self
	t.kind = "barrel"
	t.position = pos
	t.damage = dmg
	t.crit = crit
	t.blast = blast
	t.burn = burn
	effects.add_child(t)


## Іскра волхва: самонавідна ціль уже обрана, летить швидко, б'є одного.
func spawn_spark(pos: Vector2, dir: Vector2, dmg: float, crit: bool) -> void:
	var p := _new_projectile(pos, dir * 700.0, dmg)
	p.friendly = true
	p.spell = true
	p.crit = crit
	p.radius = 6.0
	p.life = 0.9
	p.color = Color(1.0, 0.8, 0.35) if not crit else Color(1.0, 1.0, 0.6)


## Вогняна куля волхва: вибухає серед ворогів.
func spawn_fireball(pos: Vector2, dir: Vector2, dmg: float, crit: bool, blast: float, burn: float, stun: bool = false) -> void:
	var p := _new_projectile(pos, dir * 520.0, dmg)
	p.friendly = true
	p.spell = true
	p.crit = crit
	p.radius = 11.0
	p.life = 1.3
	p.color = Color(1.0, 0.45, 0.1)
	p.explode_radius = blast
	p.burn_dps = burn
	p.stun_all = stun


## Вибух без джерела (напр. вибухова еліта після смерті): попередження, потім удар.
func spawn_blast(pos: Vector2, r: float, dur: float, dmg: float, col: Color) -> void:
	var t = TelegraphScript.new()
	t.combat = self
	t.shape = "circle"
	t.position = pos
	t.radius = r
	t.duration = dur
	t.damage = dmg
	t.color = col
	effects.add_child(t)


## Можливо, перетворює щойно народжену нечисть на еліту.
func _maybe_elite(e) -> void:
	if e == null or e.is_boss:
		return
	if randf() < Elites.chance(int(loc.get("level", 1)), plague) + float(loc.get("elite_bonus", 0.0)):
		e.make_elite(Elites.roll_affixes(int(loc.get("level", 1))))
		float_text(e.global_position + Vector2(0, -60), "Еліта!", Color(1.0, 0.8, 0.2))
		Events.hint.emit("elite", "Еліта! Золоте коло — сильніший ворог із властивостями (підпалює, морозить, вибухає...). За неї — щедра здобич.")


func _last_enemy():
	var list := get_tree().get_nodes_in_group("enemies")
	return list[-1] if not list.is_empty() else null


func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, crit: bool) -> void:
	var p := _new_projectile(pos, dir * 950.0, dmg)
	p.friendly = true
	p.crit = crit
	p.radius = 6.0
	p.life = 0.9


func spawn_plague(pos: Vector2, dps: float, status: String = "plague", tint: Color = Color(0.35, 0.6, 0.12), life: float = 3.0) -> void:
	var c = PlagueScript.new()
	c.combat = self
	c.position = pos
	c.dps = dps
	c.status = status
	c.tint = tint
	c.life = life
	effects.add_child(c)


## Анімований ефект вміння (fx_<kind>.png) у шарі ефектів.
func spawn_fx(kind: String, pos: Vector2, scale_k: float = 1.0, rot: float = 0.0, tint: Color = Color.WHITE, fps: float = 16.0) -> void:
	var f = FxSpriteScript.new()
	f.kind = kind
	f.position = pos
	f.scale = Vector2.ONE * scale_k
	f.rotation = rot
	f.tint = tint
	f.fps = fps
	effects.add_child(f)


func spawn_bolt(points: PackedVector2Array) -> void:
	var b = BoltScript.new()
	b.points = points
	effects.add_child(b)


func spawn_pickup(pos: Vector2, kind: String, value: int, item: Dictionary = {}) -> void:
	var p = PickupScript.new()
	p.combat = self
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


## Коротке «завмирання» гри від сильного удару.
## Бій зникає (вихід у меню, нова гра) посеред «завмирання» — повертаємо нормальний час.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_hitstop_active = false


func hitstop(dur: float) -> void:
	if _hitstop_active or not active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false
