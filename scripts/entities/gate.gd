extends Node2D
## Брама міста (частокіл) чи тин хутора в бою-обороні. Нечисть б'є її, як козака;
## коли міцність падає до нуля — оборону програно.

var combat
var max_hp := 1000.0
var hp := 1000.0
var radius := 95.0
var alive := true
var dead := false
var plague_immune := true  # хмари зарази стіну не точать
var camp := false  # тин хутора замість частоколу
var variant := "city"  # city | camp | village | caravan | captives | wounded (події, див. EventService)
var phase := 0.0
var flash := 0.0


func take_damage(amount: float, _source = null) -> bool:
	if not alive:
		return false
	hp -= amount
	flash = 0.12
	if hp <= 0.0:
		hp = 0.0
		alive = false
		combat.on_gate_destroyed()
	queue_redraw()
	return false  # стіна не кровить і не горить


func heal(_amount: float, _show: bool = true) -> void:
	pass  # знахарка браму не лікує


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	phase += delta
	queue_redraw()


func label_text() -> String:
	match variant:
		"camp": return "Тин хутора"
		"village": return "Хати"
		"caravan": return "Вози"
		"captives": return "Бранці"
		"wounded": return "Поранений"
	return "Брама"


const Gfx := preload("res://scripts/world/gfx.gd")
const Tiles := preload("res://scripts/world/tiles.gd")


func _draw() -> void:
	if Gfx.has("defense"):
		_draw_sprites()
	else:
		_draw_vector()
	# Міцність брами
	var bw := 240.0
	draw_rect(Rect2(Vector2(-bw / 2, -150), Vector2(bw, 10)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(Vector2(-bw / 2, -150), Vector2(bw * hp / max_hp, 10)), Color(0.95, 0.75, 0.2))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-100, -156), label_text(), HORIZONTAL_ALIGNMENT_CENTER, 200, 16, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-100, -156), label_text(), HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(1.0, 0.9, 0.6))


## Нова графіка: частокіл із вежами й брамою на всю ширину арени (або тин хутора з ворітцями).
func _draw_sprites() -> void:
	var tint := Color.WHITE
	if flash > 0.0:
		tint = Color(1.6, 1.2, 1.1)
	elif not alive:
		tint = Color(0.6, 0.55, 0.5)
	if variant in ["village", "caravan", "captives", "wounded"]:
		_draw_event(tint)
		return
	var half: float = combat.arena.size.x / 2.0 + 80.0 if combat != null else 900.0
	var seg := 64.0
	var gate_w := 192.0 if not camp else 160.0
	var x := gate_w / 2.0
	var i := 0
	while x < half:
		var part := ("fence" if camp else ("palisade_broken" if (not alive and i % 3 == 1) or (hp < max_hp * 0.5 and i % 5 == 2) else "palisade"))
		Gfx.wall_part(self, part, Vector2(x + seg / 2.0, 0), 2.0, tint)
		Gfx.wall_part(self, part, Vector2(-x - seg / 2.0, 0), 2.0, tint)
		x += seg
		i += 1
	if not camp:
		for tx in [gate_w / 2.0 + 40.0, -gate_w / 2.0 - 40.0, half - 60.0, -half + 60.0]:
			Gfx.wall_part(self, "tower", Vector2(tx, 8.0), 2.0, tint)
	var g := ("camp_gate" if camp else "gate") + ("" if alive else "_broken")
	Gfx.wall_part(self, g, Vector2(0, 0), 2.0, tint)
	# За муром — дахи міста (або хата хутора): малюються нижче лінії муру
	var houses: Array = [["house", -520.0, 150.0], ["hut", -300.0, 120.0], ["house", 300.0, 160.0], ["hut", 560.0, 110.0], ["hut", -760.0, 130.0], ["house", 780.0, 150.0]] if not camp else [["hut", -260.0, 110.0], ["house", 300.0, 150.0]]
	for h in houses:
		var info: Dictionary = Tiles.PROPS[h[0]]
		var r: Array = info["r"]
		var w: float = r[2] * Tiles.TILE
		var hh: float = r[3] * Tiles.TILE
		draw_texture_rect_region(Tiles.sheet(info["sheet"]), Rect2(Vector2(h[1] - w / 2.0, h[2] - hh), Vector2(w, hh)), Tiles.src(r), tint)
	if alive and hp < max_hp * 0.35:
		# Тріщини на стулках
		draw_polyline(PackedVector2Array([Vector2(-24, -150), Vector2(-10, -110), Vector2(-26, -70), Vector2(-8, -20)]), Color(0.1, 0.05, 0.02), 2.0)
		draw_polyline(PackedVector2Array([Vector2(26, -140), Vector2(12, -100), Vector2(28, -60)]), Color(0.1, 0.05, 0.02), 2.0)


func _draw_vector() -> void:
	var wood := Color(0.5, 0.33, 0.18) if not camp else Color(0.6, 0.45, 0.25)
	if flash > 0.0:
		wood = wood.lerp(Color(1, 0.6, 0.5), 0.6)
	if not alive:
		wood = Color(0.25, 0.18, 0.12)
	var w := 380.0
	var n := 19
	for i in n:
		var x := -w / 2.0 + i * w / (n - 1)
		if absf(x) < 40.0:
			continue  # отвір брами
		var h := 70.0 + (8.0 if i % 2 == 0 else 0.0)
		if camp:
			h = 46.0
		if not alive and i % 3 == 0:
			h *= 0.4  # зламані колоди
		draw_rect(Rect2(Vector2(x - 9, -h), Vector2(18, h)), wood)
		if not camp:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 9, -h), Vector2(x + 9, -h), Vector2(x, -h - 12)]), wood.lightened(0.1))
	if camp:
		for k in 3:
			draw_line(Vector2(-w / 2, -12 - k * 13), Vector2(w / 2, -12 - k * 13), wood.darkened(0.3), 3.0)
	# Стулки брами
	var gcol := Color(0.38, 0.24, 0.12) if alive else Color(0.2, 0.14, 0.1)
	draw_rect(Rect2(Vector2(-38, -62), Vector2(36, 62)), gcol)
	draw_rect(Rect2(Vector2(2, -62), Vector2(36, 62)), gcol)
	draw_line(Vector2(-38, -40), Vector2(38, -40), Color(0.2, 0.2, 0.22), 4.0)
	draw_line(Vector2(-38, -18), Vector2(38, -18), Color(0.2, 0.2, 0.22), 4.0)
	# Тріщини, коли брама слабне
	if hp < max_hp * 0.5:
		draw_polyline(PackedVector2Array([Vector2(-20, -60), Vector2(-10, -40), Vector2(-24, -22), Vector2(-8, -4)]), Color(0.1, 0.05, 0.02), 2.0)
	if hp < max_hp * 0.25:
		draw_polyline(PackedVector2Array([Vector2(20, -58), Vector2(10, -36), Vector2(26, -16)]), Color(0.1, 0.05, 0.02), 2.0)


## Події: хати села, вози валки, бранці, поранений козак — замість брами.
func _draw_event(tint: Color) -> void:
	var part := hp / maxf(max_hp, 1.0)
	match variant:
		"village":
			for h in [["hut", -170.0], ["house", 0.0], ["hut", 170.0]]:
				var info: Dictionary = Tiles.PROPS[h[0]]
				var r: Array = info["r"]
				var w: float = r[2] * Tiles.TILE
				var hh: float = r[3] * Tiles.TILE
				draw_texture_rect_region(Tiles.sheet(info["sheet"]), Rect2(Vector2(h[1] - w / 2.0, -hh + 10.0), Vector2(w, hh)), Tiles.src(r), tint if alive else Color(0.35, 0.3, 0.28))
				if part < 0.66 or not alive:
					# Полум'я на даху
					for i in 3:
						var fx: float = h[1] + (i - 1) * 24.0 + sin(phase * 7.0 + i) * 3.0
						var fh := 26.0 + sin(phase * 9.0 + i * 2.0) * 6.0
						draw_colored_polygon(PackedVector2Array([Vector2(fx - 10, -hh + 30), Vector2(fx + 10, -hh + 30), Vector2(fx, -hh + 30 - fh)]), Color(1.0, 0.55, 0.15, 0.9))
						draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, -hh + 30), Vector2(fx + 4, -hh + 30), Vector2(fx, -hh + 32 - fh * 0.6)]), Color(1.0, 0.9, 0.4, 0.9))
		"caravan":
			for x in [-70.0, 70.0]:
				Gfx.wall_part(self, "wagon", Vector2(x, 0), 2.0, tint if alive else Color(0.5, 0.45, 0.4))
			if not alive:
				draw_line(Vector2(-110, -10), Vector2(-30, -60), Color(0.1, 0.05, 0.02), 3.0)
		"captives":
			# Троє зв'язаних селян і стовп
			draw_rect(Rect2(-4, -70, 8, 70), Color(0.4, 0.28, 0.14))
			for i in 3:
				var x := -40.0 + i * 40.0
				Gfx.draw(self, "peasant", Vector2(0, 1), Gfx.DEAD if not alive else (Gfx.HURT if part < 0.5 else Gfx.IDLE), Vector2(x - 24, -34), tint)
				draw_line(Vector2(x - 10, -14), Vector2(x + 10, -12), Color(0.75, 0.65, 0.45), 2.0)
		"wounded":
			Gfx.draw(self, "cossack_sabre", Vector2(1, 0), Gfx.DEAD, Vector2(-24, -34), tint if alive else Color(0.45, 0.4, 0.4))
			if alive:
				draw_rect(Rect2(-12, -8, 24, 6), Color(0.9, 0.9, 0.9))
				draw_rect(Rect2(-6, -8, 4, 6), Color(0.8, 0.15, 0.15))
