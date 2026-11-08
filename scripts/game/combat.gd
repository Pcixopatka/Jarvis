class_name Combat
extends Node2D
## Бій і локації: арена, ландшафт, освітлення, вороги, супутники, снаряди, здобич,
## дика місцевість (зачистка) і печери (кімнати з босом).
## Про важливі події повідомляє через шину Events; сам нічого не знає про меню й інтерфейс.

const Data := preload("res://scripts/data/data.gd")
const EnemyScript := preload("res://scripts/entities/enemy.gd")
const CompanionScript := preload("res://scripts/entities/companion.gd")
const ProjectileScript := preload("res://scripts/entities/projectile.gd")
const PickupScript := preload("res://scripts/entities/pickup.gd")
const PortalScript := preload("res://scripts/entities/portal.gd")
const FloatTextScript := preload("res://scripts/world/float_text.gd")
const BoltScript := preload("res://scripts/world/bolt.gd")
const PlagueScript := preload("res://scripts/world/plague_cloud.gd")
const GroundScript := preload("res://scripts/world/ground.gd")
const FxScript := preload("res://scripts/world/fx.gd")
const AmbientScript := preload("res://scripts/world/ambient.gd")

const FIELD_ARENA := Rect2(-1400, -1400, 2800, 2800)
const DUNGEON_ARENA := Rect2(-750, -550, 1500, 1100)
const BIOME_TINT := {
	"steppe": Color(1.0, 0.97, 0.9), "river": Color(0.97, 1.0, 1.0), "forest": Color(0.82, 0.92, 0.82),
	"swamp": Color(0.78, 0.86, 0.8), "mountain": Color(0.92, 0.95, 1.0), "cave": Color(0.2, 0.18, 0.25),
	"plague": Color(0.2, 0.26, 0.17),
}

## Джерела керування (задає Game): вектор руху і чи затиснуто удар.
var move_input: Callable = func() -> Vector2: return Vector2.ZERO
var attack_input: Callable = func() -> bool: return false

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
func enter(id: String, companions: Array) -> void:
	loc_id = id
	loc = Data.LOCATIONS[id]
	room = 1 if loc["type"] == "dungeon" else 0
	field_kills = 0
	field_goal = Data.FIELD_GOAL_BASE + int(loc["level"]) * Data.FIELD_GOAL_PER_LEVEL
	field_cleared = false
	spawn_timer = 1.0
	player.unbreak_ready = true
	_setup_arena(companions)
	set_visible_world(true)
	active = true
	if loc["type"] == "dungeon":
		_spawn_room()
	else:
		Events.banner.emit(loc["name"], Color(1, 0.92, 0.7))
		var en: Array = loc["enemies"]
		for i in 5:
			var pos: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * randf_range(450, 650)
			spawn_enemy(en[randi() % en.size()], loc["level"], false, _clamp_in(pos, 60.0))


func leave() -> void:
	active = false
	Engine.time_scale = 1.0
	_clear()
	set_visible_world(false)


func is_dungeon() -> bool:
	return loc.get("type", "") == "dungeon"


func _setup_arena(companions: Array) -> void:
	_clear()
	arena = DUNGEON_ARENA if is_dungeon() else FIELD_ARENA
	player.position = Vector2(0, arena.end.y - 160) if is_dungeon() else Vector2.ZERO
	ground.setup(arena, loc["biome"], hash(loc_id) + room * 31)
	_setup_atmosphere(loc["biome"])
	camera.limit_left = int(arena.position.x - 120)
	camera.limit_top = int(arena.position.y - 160)
	camera.limit_right = int(arena.end.x + 120)
	camera.limit_bottom = int(arena.end.y + 120)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	_spawn_companions(companions)


func _clear() -> void:
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


func _spawn_companions(companions: Array) -> void:
	companion_nodes.clear()
	for i in companions.size():
		var data: Dictionary = companions[i]
		if data["downed"]:
			continue
		var c: Companion = CompanionScript.new()
		c.combat = self
		c.setup(data["type"], player.level, data.get("index", i))
		c.position = player.position + Vector2(-60 + 120 * (i % 2), 50)
		entities.add_child(c)
		companion_nodes.append(c)


func _setup_atmosphere(biome: String) -> void:
	canvas_mod.color = BIOME_TINT.get(biome, Color.WHITE)
	torch.enabled = biome in ["cave", "plague"]
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
		torch.energy = 1.15 + sin(_time * 13.0) * 0.05 + randf() * 0.06
	camera.global_position = player.global_position
	if shake_strength > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	player.attack_held = attack_input.call()
	if is_dungeon():
		_update_dungeon()
	else:
		_update_field(delta)


func _update_field(delta: float) -> void:
	if field_cleared:
		_check_exit_portal()
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.6, 1.5 - loc["level"] * 0.05)
		if alive_enemy_count() < 7 + int(loc["level"]):
			var en: Array = loc["enemies"]
			spawn_enemy(en[randi() % en.size()], loc["level"] + (1 if randf() < 0.15 else 0))


func _spawn_room() -> void:
	room_cleared = false
	var en: Array = loc["enemies"]
	# Рядова нечисть у печері на рівень нижча — головна загроза тут бос
	var minion_level := maxi(1, int(loc["level"]) - 1)
	for i in Data.DUNGEON_ROOM_BASE + room * Data.DUNGEON_ROOM_PER:
		var pos := Vector2(randf_range(arena.position.x + 80, arena.end.x - 80), randf_range(arena.position.y + 80, arena.position.y + arena.size.y * 0.55))
		spawn_enemy(en[randi() % en.size()], minion_level, false, pos)
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
			out.append({"type": c.type, "downed": not c.alive, "index": c.index})
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
	_spawn_portal("На мапу", _clamp_in(player.global_position + Vector2(0, -260), 100.0))
	Events.field_cleared.emit(loc_id)
	Events.hint.emit("cleared", "Місцевість очищено! Збери скарб і зайди в портал, щоб повернутися на мапу.")


func _dungeon_complete() -> void:
	var g: int = 40 * int(loc["level"])
	player.add_gold(g)
	Events.banner.emit("%s очищено!\n+%d грн" % [loc["name"], g], Color(1.0, 0.85, 0.3))
	Audio.play("quest", 0.0)
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
			c.queue_free()


# ======================= Нечисть і здобич =======================

func _on_enemy_killed(e: Node2D) -> void:
	if not active:
		return
	Audio.play("enemy_die", 0.15, -3.0)
	fx.burst(e.global_position + Vector2(0, -10), Color(0.25, 0.2, 0.25, 0.8), 40 if e.is_boss else 12, 320 if e.is_boss else 180, 9, 0.6, -60)
	if e.is_boss:
		fx.ring(e.global_position, Color(1.0, 0.8, 0.3), 40, 600, 8, 0.7)
		hitstop(0.15)
	else:
		hitstop(0.03)
	if not is_dungeon() and not field_cleared:
		field_kills += 1
		if field_kills >= field_goal:
			_field_complete()
	_drop_loot(e)


func _drop_loot(e: Node2D) -> void:
	var pos: Vector2 = e.global_position
	var ilvl: int = loc.get("level", 1)
	var heal_value := int(20 * (1.0 + 0.5 * player.varenyk_bonus))
	if e.is_boss:
		shake(14.0)
		Events.banner.emit("%s переможений!" % Data.BOSS_NAMES.get(e.kind, "Бос"), Color(1.0, 0.85, 0.3))
		for i in 10:
			spawn_pickup(pos, "coin", maxi(1, e.xp_value / 10))
		for i in 2:
			spawn_pickup(pos, "item", 0, Data.gen_item(ilvl + 1, Data.roll_rarity(ilvl, 2)))
		spawn_pickup(pos, "varenyk", heal_value * 2)
	else:
		spawn_pickup(pos, "coin", e.xp_value)
		if randf() < 0.05 * (1 + player.varenyk_bonus):
			spawn_pickup(pos, "varenyk", heal_value)
		if randf() < Data.ITEM_DROP_CHANCE:
			spawn_pickup(pos, "item", 0, Data.gen_item(ilvl, Data.roll_rarity(ilvl)))


func pick_item(item: Dictionary) -> void:
	var col: Color = Data.RARITY_COLORS[item["rarity"]]
	if player.add_item(item):
		float_text(player.global_position + Vector2(0, -70), item["name"], col)
		Audio.play("item", 0.0)
		Events.item_found.emit(item)
	else:
		var g := Data.sell_price(item)
		player.gold += g
		float_text(player.global_position + Vector2(0, -70), "Торба повна: +%d грн" % g, col)


func on_companion_down(c: Companion) -> void:
	var name: String = Data.COMPANIONS[c.type]["name"]
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
	entities.add_child(e)
	if e.is_boss:
		Audio.play("roar", 0.0)
		shake(10.0)
		Events.boss_spawned.emit(e)


func _new_projectile(pos: Vector2, vel: Vector2, dmg: float) -> Projectile:
	var p: Projectile = ProjectileScript.new()
	p.combat = self
	p.position = pos
	p.velocity = vel
	p.damage = dmg
	effects.add_child(p)
	return p


func spawn_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float) -> void:
	var p := _new_projectile(pos, dir * spd, dmg)
	p.color = col
	p.radius = r


func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, crit: bool) -> void:
	var p := _new_projectile(pos, dir * 950.0, dmg)
	p.friendly = true
	p.crit = crit
	p.radius = 6.0
	p.life = 0.9


func spawn_plague(pos: Vector2, dps: float) -> void:
	var c = PlagueScript.new()
	c.combat = self
	c.position = pos
	c.dps = dps
	effects.add_child(c)


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
func hitstop(dur: float) -> void:
	if _hitstop_active or not active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false
