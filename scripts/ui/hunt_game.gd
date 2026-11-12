extends Control
## Мініігра «Полювання»: галявиною пробігають звірі. Торкнись звіра — пустиш стрілу.
## Правила — в OutdoorService (shoot / escaped); тут лише рух, малювання й дотики.

const Acts := preload("res://scripts/data/activities.gd")
const OutdoorService := preload("res://scripts/game/outdoor_service.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Tiles := preload("res://scripts/world/tiles.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const Backdrop := preload("res://scripts/ui/backdrop.gd")
const ANIMALS := preload("res://assets/gfx/sprites/animals.png")
const ROW := {"hare": 0, "deer": 1, "boar": 2}
const SCALE := 3.0

var on_done: Callable  # викликається з підсумком полювання
var hero_sheet := "cossack_sabre"
var h := {}
var animal := ""
var pos := Vector2.ZERO
var dir := 1.0
var base_y := 0.0
var boost := 1.0  # сполоханий звір біжить швидше
var wait := 1.0
var stop_t := 0.0
var stopped := false
var fall_t := 0.0
var arrow := {}
var msg := ""
var msg_t := 0.0
var msg_col := Color.WHITE
var msg_pos := Vector2.ZERO
var t := 0.0
var done := false
var end_t := -1.0
var info: Label
var _seed := 0


func setup(session: Dictionary, sheet: String, cb: Callable):
	h = session
	hero_sheet = sheet
	on_done = cb
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_seed = randi()
	var bg = Backdrop.new()
	bg.painter = _paint_backdrop
	add_child(bg)
	info = UI.label("", 24, UI.GOLD, false)
	info.position = Vector2(20, 14)
	add_child(info)
	var tip := UI.label("Торкнись звіра, щоб пустити стрілу. У серцевину — «в яблучко»: м'яса більше.", 17, UI.TEXT, false)
	tip.position = Vector2(20, 50)
	add_child(tip)
	var b := UI.button("Досить", func(): _finish(), Vector2(180, 60), 22)
	_pin(b, Vector2(1, 0), Rect2(-200, 14, 180, 60))
	add_child(b)
	_update_info()


## Прикріпити кнопку до кута екрана: anchor — частка екрана, r — зсув і розмір від цієї точки.
static func _pin(c: Control, anchor: Vector2, r: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.end.x
	c.offset_bottom = r.end.y


func field() -> Rect2:
	return Rect2(0.0, size.y * 0.24, size.x, size.y * 0.5)


func speed_now() -> float:
	if animal == "":
		return 0.0
	return float(Acts.animal(animal)["speed"]) * boost * (0.6 if h["wounded"] else 1.0)


func _update_info() -> void:
	info.text = "Стріл: %d   •   Здобич: %d м'яса   •   Звір %d із %d" % [int(h["arrows"]), int(h["meat"]), mini(int(h["index"]) + 1, h["queue"].size()), h["queue"].size()]


func _process(delta: float) -> void:
	t += delta
	msg_t -= delta
	if not arrow.is_empty():
		arrow["t"] = float(arrow["t"]) + delta * 7.0
		if float(arrow["t"]) >= 1.0:
			arrow = {}
	if done:
		queue_redraw()
		return
	if end_t > 0.0:
		end_t -= delta
		if end_t <= 0.0:
			_finish()
			return
	if fall_t > 0.0:
		fall_t -= delta
		if fall_t <= 0.0:
			animal = ""
			wait = 0.6
	elif animal == "":
		wait -= delta
		if wait <= 0.0:
			_spawn()
	else:
		if stop_t > 0.0:
			stop_t -= delta
		else:
			pos.x += dir * speed_now() * delta
			if animal == "hare":
				pos.y = base_y + sin(t * 7.0) * 26.0
			# Посеред галявини звір на мить завмирає й дослухається
			if not stopped and absf(pos.x - size.x * 0.5) < 30.0 and animal != "hare":
				stopped = true
				stop_t = 0.55
		if pos.x < -90.0 or pos.x > size.x + 90.0:
			OutdoorService.escaped(h)
			animal = ""
			wait = 0.6
			_update_info()
	queue_redraw()


func _spawn() -> void:
	var id := OutdoorService.current(h)
	if id == "":
		_finish()
		return
	animal = id
	dir = 1.0 if randf() < 0.5 else -1.0
	var f := field()
	base_y = randf_range(f.position.y + 70.0, f.end.y - 40.0)
	pos = Vector2(-80.0 if dir > 0.0 else size.x + 80.0, base_y)
	boost = 1.0
	stopped = false
	stop_t = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot_at(event.position)
		accept_event()


## Центр звіра на екрані (куди цілитись).
func target_point() -> Vector2:
	return pos + Vector2(0, -34)


func shoot_at(p: Vector2) -> String:
	if done or animal == "" or fall_t > 0.0 or int(h["arrows"]) <= 0:
		return "none"
	var res := OutdoorService.shoot(h, p.distance_to(target_point()))
	arrow = {"from": Vector2(size.x * 0.5, size.y - 120.0), "to": p, "t": 0.0}
	msg_pos = p + Vector2(0, -50)
	msg_t = 1.1
	match res:
		"miss":
			msg = "Мимо!"
			msg_col = UI.BAD
			boost = 1.5
			stop_t = 0.0
			Audio.play("shoot", 0.1, 3.0)
		"wound":
			msg = "Поранений! Добий"
			msg_col = UI.GOLD
			boost = 1.0
			Audio.play("shoot", 0.1, 3.0)
			Audio.play("hit", 0.1, -2.0)
		"hit", "bullseye":
			msg = "В яблучко!" if res == "bullseye" else "Влучив!"
			msg_col = UI.GOOD
			fall_t = 0.9
			Audio.play("shoot", 0.1, 3.0)
			Audio.play("crit" if res == "bullseye" else "hit", 0.05, -2.0)
	_update_info()
	if int(h["arrows"]) <= 0 and fall_t <= 0.0 and not h["wounded"]:
		end_t = 1.2  # стріли скінчились — додивляємось, як звір тікає
	elif OutdoorService.hunt_over(h) and fall_t > 0.0:
		end_t = 1.3
	return res


func _finish() -> void:
	if done:
		return
	done = true
	if on_done.is_valid():
		on_done.call(h)


## Нерухоме тло (малюється один раз): трава, затінені узлісся, дальній ряд дерев.
func _paint_backdrop(ci: Control) -> void:
	var ts := float(Tiles.TILE) * 1.5
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var y := 0.0
	while y < ci.size.y:
		var x := 0.0
		while x < ci.size.x:
			var cell: Array = Tiles.GRASS[0] if rng.randf() > 0.1 else Tiles.GRASS[1 + rng.randi() % 2]
			ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(cell))
			if rng.randf() > 0.93:
				ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(Tiles.FLOWERS[rng.randi() % Tiles.FLOWERS.size()]))
			x += ts
		y += ts
	var f := field()
	ci.draw_rect(Rect2(0, 0, ci.size.x, f.position.y - 20.0), Color(0.05, 0.12, 0.05, 0.45))
	ci.draw_rect(Rect2(0, f.end.y + 30.0, ci.size.x, ci.size.y), Color(0.05, 0.12, 0.05, 0.45))
	var tree: Array = Tiles.PROPS["tree"]["r"]
	var tx := -20.0
	while tx < ci.size.x:
		ci.draw_texture_rect_region(Tiles.OV, Rect2(tx + rng.randf_range(-12, 12), f.position.y - 150.0 + rng.randf_range(-14, 14), 128, 128), Tiles.src(tree))
		tx += 92.0


## Рухоме (щокадру): звір, ближні дерева перед ним, мисливець, стріла, напис.
func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 1
	var f := field()
	var tree: Array = Tiles.PROPS["tree"]["r"]
	var tx := 0.0
	# Звір
	if animal != "":
		var frame := 2 if fall_t > 0.0 else (int(t * 10.0) % 2 if stop_t <= 0.0 else 1)
		var w := 48.0 * SCALE
		var hh := 32.0 * SCALE
		draw_set_transform(pos + Vector2(0, 6), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 46.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var dst := Rect2(pos + Vector2(-w / 2.0, -hh + 10.0), Vector2(w * dir, hh))  # від'ємна ширина — віддзеркалення
		draw_texture_rect_region(ANIMALS, dst, Rect2(frame * 48, ROW[animal] * 32, 48, 32), Color(1, 0.75, 0.75) if h["wounded"] and fall_t <= 0.0 else Color.WHITE)
	# Ближній ряд дерев і кущів (звір ховається за ними)
	tx = -60.0
	while tx < size.x:
		draw_texture_rect_region(Tiles.OV, Rect2(tx + rng.randf_range(-16, 16), f.end.y - 20.0 + rng.randf_range(-10, 16), 160, 160), Tiles.src(tree))
		tx += 150.0
	# Мисливець унизу, спиною до нас
	if Gfx.has(hero_sheet):
		draw_set_transform(Vector2(size.x * 0.5, size.y - 70.0), 0.0, Vector2(3.0, 3.0))
		# Лук опущено, поки галявина порожня; натягнуто, коли є звір і стріла; щойно після пострілу — без стріли
		var bow := Gfx.IDLE
		if not arrow.is_empty():
			bow = Gfx.ATK0 + 1
		elif animal != "" and fall_t <= 0.0 and int(h["arrows"]) > 0:
			bow = Gfx.ATK0
		Gfx.draw(self, hero_sheet, Vector2.UP, bow, Vector2(-24, -30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Стріла в польоті
	if not arrow.is_empty():
		var a: Vector2 = arrow["from"]
		var b: Vector2 = arrow["to"]
		var k: float = clampf(float(arrow["t"]), 0.0, 1.0)
		var tip: Vector2 = a.lerp(b, k)
		var back: Vector2 = a.lerp(b, maxf(0.0, k - 0.18))
		draw_line(back, tip, Color(0.45, 0.3, 0.15), 4.0)
		draw_circle(tip, 4.0, Color(0.85, 0.87, 0.9))
	if msg_t > 0.0:
		var font := ThemeDB.fallback_font
		var p := msg_pos + Vector2(-150, -30.0 * (1.1 - msg_t))
		draw_string_outline(font, p, msg, HORIZONTAL_ALIGNMENT_CENTER, 300, 30, 6, Color(0, 0, 0, 0.8))
		draw_string(font, p, msg, HORIZONTAL_ALIGNMENT_CENTER, 300, 30, msg_col)
