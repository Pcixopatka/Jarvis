extends Control
## Мініігра «Рибалка»: закинь вудку, дочекайся клювання, підсічи й тягни — тримай натяг у зеленій смузі.
## Фази: idle → wait → bite → reel → (idle). Правила й числа — в OutdoorService і data/fish.json.

const Acts := preload("res://scripts/data/activities.gd")
const OutdoorService := preload("res://scripts/game/outdoor_service.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Tiles := preload("res://scripts/world/tiles.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const HuntGame := preload("res://scripts/ui/hunt_game.gd")
const Backdrop := preload("res://scripts/ui/backdrop.gd")
const SHEET := preload("res://assets/gfx/sprites/fishing.png")
const ICON := {"karas": 0, "shchuka": 1, "som": 2, "float": 3, "float_dip": 4, "splash": 5}

var on_done: Callable
var hero_sheet := "cossack_sabre"
var f := {}
var phase := "idle"
var fish := ""
var timer := 0.0
var tension := 0.5
var progress := 0.0
var holding := false
var wave_t := 0.0
var msg := "Закинь вудку"
var msg_col := Color.WHITE
var show_fish := ""
var show_t := 0.0
var t := 0.0
var done := false
var cast_t := 0.0  # скільки минуло від закиду (перші миті випадковий другий дотик не рахується)
var info: Label
var btn: Button
var _seed := 0


func setup(session: Dictionary, sheet: String, cb: Callable):
	f = session
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
	var tip := UI.label("Клює — тисни «Підсікти». Далі тримай кнопку, щоб тягти: натяг має бути в зеленій смузі.", 17, UI.TEXT, false)
	tip.position = Vector2(20, 50)
	add_child(tip)
	var out := UI.button("Досить", func(): _finish(), Vector2(180, 60), 22)
	HuntGame._pin(out, Vector2(1, 0), Rect2(-200, 14, 180, 60))
	add_child(out)
	btn = UI.button("Закинути", func(): pass, Vector2(300, 110), 28)
	HuntGame._pin(btn, Vector2(1, 1), Rect2(-330, -140, 300, 110))
	btn.button_down.connect(func(): press())
	btn.button_up.connect(func(): release())
	add_child(btn)
	_update_info()


func _update_info() -> void:
	info.text = "Закидів: %d   •   Улов: %d риби" % [int(f["bait"]), int(f["ryba"])]
	if btn:
		btn.text = {"idle": "Закинути", "wait": "Чекай...", "bite": "Підсікти!", "reel": "Тягни (тримай)"}[phase]


## Кнопку натиснуто (закинути / підсікти / почати тягти).
func press() -> void:
	if done:
		return
	holding = true
	match phase:
		"idle":
			if OutdoorService.fishing_over(f):
				_finish()
				return
			fish = OutdoorService.roll_fish(f)
			timer = OutdoorService.bite_delay(f)
			cast_t = 0.0
			phase = "wait"
			_say("Поплавок на воді...", UI.TEXT)
			Audio.play("swing", 0.1, 0.0)
			Audio.play("splash", 0.2, -8.0)
		"wait":
			if cast_t >= 0.6:
				_fail("Рано! Риба сполохалась")
		"bite":
			phase = "reel"
			tension = 0.5
			progress = 0.0
			wave_t = 0.0
			_say("%s на гачку! Тягни" % Acts.fish(fish)["name"], UI.GOLD)
			Audio.play("splash", 0.1, 0.0)
	_update_info()


func release() -> void:
	holding = false


func _say(text: String, col: Color) -> void:
	msg = text
	msg_col = col


func _fail(text: String) -> void:
	OutdoorService.use_bait(f)
	phase = "idle"
	_say(text, UI.BAD)
	Audio.play("splash", 0.25, -6.0)
	_update_info()
	if OutdoorService.fishing_over(f):
		timer = 1.4
		phase = "end"


func _catch() -> void:
	OutdoorService.use_bait(f)
	OutdoorService.catch_fish(f, fish)
	show_fish = fish
	show_t = 1.6
	phase = "idle"
	_say("%s! +%d риби" % [Acts.fish(fish)["name"], int(Acts.fish(fish)["ryba"])], UI.GOOD)
	Audio.play("splash", 0.1, 0.0)
	Audio.play("quest", 0.05, -4.0)
	_update_info()
	if OutdoorService.fishing_over(f):
		timer = 1.8
		phase = "end"


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


## Крок гри (окремо від _process, щоб тести могли проганяти час).
func step(delta: float) -> void:
	t += delta
	show_t -= delta
	if done:
		return
	match phase:
		"wait":
			cast_t += delta
			timer -= delta
			if timer <= 0.0:
				phase = "bite"
				timer = float(Acts.fish(fish)["window"])
				_say("Клює!", UI.GOLD)
				Audio.play("splash", 0.3, -5.0)
				_update_info()
		"bite":
			timer -= delta
			if timer <= 0.0:
				_fail("Зірвалась...")
		"reel":
			wave_t += delta
			var pull: float = Acts.fish(fish)["pull"]
			var wave := sin(wave_t * 2.3) * 0.6 + sin(wave_t * 5.1 + 1.0) * 0.4
			tension = OutdoorService.step_tension(tension, holding, pull, wave, delta)
			if OutdoorService.in_zone(tension):
				progress += delta
			if tension >= 1.0:
				_fail("Волосінь порвалась!")
			elif tension <= 0.0:
				_fail("Риба зійшла з гачка")
			elif progress >= float(Acts.fish(fish)["reel"]):
				_catch()
		"end":
			timer -= delta
			if timer <= 0.0:
				_finish()


func _finish() -> void:
	if done:
		return
	done = true
	if on_done.is_valid():
		on_done.call(f)


## Нерухоме тло (малюється один раз): вода зверху, прибій, берег унизу.
func _paint_backdrop(ci: Control) -> void:
	var ts := float(Tiles.TILE) * 1.5
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var shore := ci.size.y * 0.62
	var y := 0.0
	while y < ci.size.y:
		var x := 0.0
		while x < ci.size.x:
			if y < shore - ts:
				ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(Tiles.WATER[rng.randi() % Tiles.WATER.size()]))
				if rng.randf() > 0.95:
					ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(Tiles.LILY[rng.randi() % Tiles.LILY.size()]))
			elif y < shore:
				ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(Tiles.WAVES[rng.randi() % Tiles.WAVES.size()]))
			else:
				ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(Tiles.GRASS[0]))
				if rng.randf() > 0.92:
					ci.draw_texture_rect_region(Tiles.OV, Rect2(x, y, ts, ts), Tiles.src(Tiles.FLOWERS[rng.randi() % Tiles.FLOWERS.size()]))
			x += ts
		y += ts


## Рухоме (щокадру): рибалка, вудка, поплавок, смуга натягу, спіймана риба, напис.
func _draw() -> void:
	var shore := size.y * 0.62
	var hero := Vector2(size.x * 0.38, shore + 60.0)
	var float_pos := Vector2(size.x * 0.5, size.y * 0.3)
	# Рибалка на березі
	if Gfx.has(hero_sheet):
		draw_set_transform(hero, 0.0, Vector2(3.0, 3.0))
		Gfx.draw(self, hero_sheet, Vector2.UP, Gfx.IDLE, Vector2(-24, -30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rod_tip := hero + Vector2(70, -150)
	draw_line(hero + Vector2(20, -40), rod_tip, Color(0.4, 0.26, 0.12), 5.0)
	if phase in ["wait", "bite", "reel"]:
		var fp := float_pos
		if phase == "reel":
			fp = float_pos.lerp(Vector2(size.x * 0.45, shore - 40.0), clampf(progress / float(Acts.fish(fish)["reel"]), 0.0, 1.0)) + Vector2(sin(wave_t * 6.0) * 14.0, 0)
		elif phase == "wait":
			fp.y += sin(t * 2.0) * 3.0
		draw_line(rod_tip, fp, Color(0.9, 0.9, 0.9, 0.8), 1.5)
		var icon := "float_dip" if phase != "wait" else "float"
		if phase == "bite" and int(t * 10.0) % 2 == 0:
			icon = "float"
		draw_texture_rect_region(SHEET, Rect2(fp + Vector2(-72, -36), Vector2(144, 72)), Rect2(ICON[icon] * 48, 0, 48, 24))
		if phase == "reel":
			draw_texture_rect_region(SHEET, Rect2(fp + Vector2(-72, -20), Vector2(144, 72)), Rect2(ICON["splash"] * 48, 0, 48, 24), Color(1, 1, 1, 0.6 + 0.4 * sin(t * 12.0)))
	# Натяг і поступ
	if phase == "reel":
		var bar := Rect2(size.x * 0.5 - 260.0, size.y - 110.0, 520.0, 34.0)
		draw_rect(bar.grow(4), Color(0, 0, 0, 0.7))
		draw_rect(bar, Color(0.25, 0.1, 0.1))
		var z0: float = Acts.FISH_ZONE[0]
		var z1: float = Acts.FISH_ZONE[1]
		draw_rect(Rect2(bar.position.x + bar.size.x * z0, bar.position.y, bar.size.x * (z1 - z0), bar.size.y), Color(0.2, 0.6, 0.25))
		var mx := bar.position.x + bar.size.x * clampf(tension, 0.0, 1.0)
		draw_rect(Rect2(mx - 5.0, bar.position.y - 8.0, 10.0, bar.size.y + 16.0), Color(1.0, 0.9, 0.4))
		var pb := Rect2(bar.position.x, bar.position.y - 30.0, bar.size.x, 14.0)
		draw_rect(pb, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(pb.position, Vector2(pb.size.x * clampf(progress / float(Acts.fish(fish)["reel"]), 0.0, 1.0), pb.size.y)), Color(0.4, 0.75, 1.0))
		var font2 := ThemeDB.fallback_font
		draw_string(font2, bar.position + Vector2(0, bar.size.y + 26.0), "слабко", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
		draw_string(font2, bar.position + Vector2(bar.size.x - 70.0, bar.size.y + 26.0), "порветься", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
	# Спіймана риба
	if show_t > 0.0 and show_fish != "":
		var c := Vector2(size.x * 0.5, size.y * 0.42 - 40.0 * (1.6 - show_t))
		draw_texture_rect_region(SHEET, Rect2(c + Vector2(-144, -72), Vector2(288, 144)), Rect2(ICON[show_fish] * 48, 0, 48, 24))
	var font := ThemeDB.fallback_font
	var mp := Vector2(size.x * 0.5 - 300.0, size.y * 0.18)
	draw_string_outline(font, mp, msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 34, 6, Color(0, 0, 0, 0.8))
	draw_string(font, mp, msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 34, msg_col)
