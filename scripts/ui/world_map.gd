extends Control
## Мапа України: моря, річки, Карпати, ліси, міста, дикі місцевості та печери.
## Координати — довгота/широта, спроєктовані на екран.

signal location_selected(id: String)

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")

# Спрощений контур України (довгота, широта), за годинниковою стрілкою.
const BORDER := [
	Vector2(22.15, 48.4), Vector2(22.7, 49.05), Vector2(22.9, 49.6), Vector2(23.6, 50.4), Vector2(24.1, 50.85),
	Vector2(23.65, 51.55), Vector2(24.6, 51.9), Vector2(25.8, 51.92), Vector2(27.2, 51.65), Vector2(28.4, 51.58),
	Vector2(29.3, 51.38), Vector2(30.55, 51.25), Vector2(30.9, 52.05), Vector2(31.8, 52.1), Vector2(32.4, 52.3),
	Vector2(33.2, 52.37), Vector2(34.1, 51.7), Vector2(34.4, 51.25), Vector2(35.4, 50.5), Vector2(36.2, 50.4),
	Vector2(37.5, 50.35), Vector2(38.2, 49.95), Vector2(39.2, 49.85), Vector2(40.15, 49.6), Vector2(39.8, 48.85),
	Vector2(39.9, 48.2), Vector2(39.0, 47.85), Vector2(38.3, 47.6), Vector2(38.2, 47.1), Vector2(37.5, 47.05),
	Vector2(36.7, 46.75), Vector2(35.8, 46.5), Vector2(34.9, 46.2), Vector2(35.3, 45.45), Vector2(35.9, 45.4),
	Vector2(36.6, 45.4), Vector2(36.4, 45.05), Vector2(35.4, 44.95), Vector2(34.4, 44.5), Vector2(33.6, 44.5),
	Vector2(33.4, 44.9), Vector2(32.5, 45.35), Vector2(33.2, 45.8), Vector2(33.7, 46.15), Vector2(32.6, 46.1),
	Vector2(31.6, 46.55), Vector2(30.7, 46.45), Vector2(30.2, 45.85), Vector2(29.7, 45.35), Vector2(28.95, 45.3),
	Vector2(28.25, 45.45), Vector2(28.95, 46.45), Vector2(29.9, 46.55), Vector2(29.6, 47.3), Vector2(29.2, 47.95),
	Vector2(28.5, 48.15), Vector2(27.5, 48.45), Vector2(26.6, 48.25), Vector2(25.3, 47.9), Vector2(24.6, 47.95),
	Vector2(23.5, 48.0), Vector2(22.9, 47.95),
]
const BLACK_SEA := [
	Vector2(27.5, 45.3), Vector2(28.95, 45.3), Vector2(29.7, 45.35), Vector2(30.2, 45.85), Vector2(30.7, 46.45),
	Vector2(31.6, 46.55), Vector2(32.6, 46.1), Vector2(33.7, 46.15), Vector2(33.2, 45.8), Vector2(32.5, 45.35),
	Vector2(33.4, 44.9), Vector2(33.6, 44.5), Vector2(34.4, 44.5), Vector2(35.4, 44.95), Vector2(36.4, 45.05),
	Vector2(37.5, 44.6), Vector2(39.0, 44.2), Vector2(41.5, 42.0), Vector2(41.5, 40.5), Vector2(27.5, 40.5),
]
const AZOV_SEA := [
	Vector2(34.9, 46.2), Vector2(35.8, 46.5), Vector2(36.7, 46.75), Vector2(37.5, 47.05), Vector2(38.2, 47.1),
	Vector2(39.3, 47.2), Vector2(38.5, 46.6), Vector2(38.0, 46.0), Vector2(37.6, 45.6), Vector2(36.6, 45.4),
	Vector2(35.9, 45.4), Vector2(35.3, 45.45),
]
const RIVERS := [
	["Дніпро", [Vector2(30.6, 52.4), Vector2(30.6, 51.55), Vector2(30.55, 50.9), Vector2(30.5, 50.45), Vector2(31.2, 49.95),
		Vector2(32.0, 49.45), Vector2(32.6, 49.1), Vector2(33.5, 48.9), Vector2(34.1, 48.5), Vector2(35.0, 48.1),
		Vector2(35.1, 47.8), Vector2(34.6, 47.5), Vector2(33.9, 47.2), Vector2(33.3, 46.85), Vector2(32.6, 46.65), Vector2(31.9, 46.58)]],
	["Дністер", [Vector2(23.2, 49.4), Vector2(24.5, 49.2), Vector2(25.5, 48.9), Vector2(26.6, 48.6), Vector2(27.5, 48.4),
		Vector2(28.4, 48.05), Vector2(29.0, 47.4), Vector2(29.6, 46.8), Vector2(30.2, 46.3)]],
	["Південний Буг", [Vector2(26.8, 49.75), Vector2(28.5, 49.25), Vector2(29.5, 48.75), Vector2(30.3, 48.1),
		Vector2(31.0, 47.5), Vector2(31.9, 46.95)]],
	["Десна", [Vector2(33.6, 52.4), Vector2(32.9, 51.85), Vector2(31.3, 51.48), Vector2(30.9, 51.0), Vector2(30.55, 50.6)]],
	["Сіверський Донець", [Vector2(36.6, 50.4), Vector2(37.3, 49.6), Vector2(38.0, 49.0), Vector2(38.9, 48.85), Vector2(39.9, 48.4), Vector2(40.6, 47.8)]],
	["Дніпро (верхів'я)", [Vector2(32.05, 54.78), Vector2(31.2, 54.6), Vector2(30.4, 54.5), Vector2(30.3, 53.9), Vector2(30.1, 53.2), Vector2(30.6, 52.4)]],
	["Прип'ять", [Vector2(24.5, 51.75), Vector2(25.8, 51.9), Vector2(27.3, 52.1), Vector2(28.6, 52.1), Vector2(29.6, 51.8), Vector2(30.2, 51.35), Vector2(30.55, 51.0)]],
	["Вісла", [Vector2(19.0, 50.05), Vector2(19.9, 50.05), Vector2(21.0, 50.4), Vector2(21.8, 51.0), Vector2(21.6, 51.6), Vector2(21.0, 52.25), Vector2(20.2, 52.5), Vector2(19.0, 52.7)]],
	["Західний Буг", [Vector2(24.1, 49.9), Vector2(24.1, 50.85), Vector2(23.65, 51.55), Vector2(23.6, 52.1), Vector2(22.6, 52.4), Vector2(21.4, 52.6)]],
	["Дон", [Vector2(38.4, 54.0), Vector2(38.9, 53.0), Vector2(39.2, 51.66), Vector2(40.0, 50.5), Vector2(41.2, 49.6), Vector2(42.0, 48.9)]],
	["Німан", [Vector2(26.6, 53.5), Vector2(25.5, 53.6), Vector2(24.4, 53.9), Vector2(23.9, 54.6), Vector2(22.9, 55.0)]],
]
const POLAND := [
	Vector2(19.0, 54.4), Vector2(22.8, 54.38), Vector2(23.5, 53.95), Vector2(23.9, 53.2), Vector2(23.5, 52.6),
	Vector2(23.2, 52.2), Vector2(23.65, 51.55), Vector2(24.1, 50.85), Vector2(23.6, 50.4), Vector2(22.9, 49.6),
	Vector2(22.7, 49.05), Vector2(22.15, 49.15), Vector2(20.9, 49.35), Vector2(19.8, 49.2), Vector2(19.0, 49.6),
]
const BELARUS := [
	Vector2(23.5, 53.95), Vector2(25.0, 54.15), Vector2(25.8, 54.85), Vector2(26.6, 55.65), Vector2(28.2, 56.1),
	Vector2(29.5, 55.95), Vector2(30.9, 55.6), Vector2(31.0, 54.7), Vector2(31.8, 54.1), Vector2(32.6, 53.4),
	Vector2(31.6, 52.9), Vector2(31.4, 52.4), Vector2(31.8, 52.1), Vector2(30.9, 52.05), Vector2(30.55, 51.25),
	Vector2(29.3, 51.38), Vector2(28.4, 51.58), Vector2(27.2, 51.65), Vector2(25.8, 51.92), Vector2(24.6, 51.9),
	Vector2(23.65, 51.55), Vector2(23.2, 52.2), Vector2(23.5, 52.6), Vector2(23.9, 53.2),
]
const BALTIC := [
	Vector2(18.0, 54.4), Vector2(19.6, 54.45), Vector2(19.95, 54.95), Vector2(21.2, 55.2), Vector2(21.1, 56.5), Vector2(18.0, 56.5),
]
const COUNTRY_NAMES := [
	["ПОЛЬЩА", Vector2(20.9, 52.9)], ["БІЛОРУСЬ", Vector2(27.6, 53.4)], ["МОСКОВІЯ", Vector2(38.2, 52.8)],
	["УКРАЇНА", Vector2(29.0, 49.75)], ["МОЛДОВА", Vector2(28.6, 47.2)], ["РУМУНІЯ", Vector2(24.8, 46.9)],
	["СЛОВАЧЧИНА", Vector2(20.6, 48.75)], ["УГОРЩИНА", Vector2(21.0, 47.4)], ["ЛИТВА", Vector2(24.6, 55.0)],
]
# Міста сусідів — лише орієнтири на мапі
const TOWNS := [
	["Варшава", Vector2(21.0, 52.23)], ["Краків", Vector2(19.94, 50.06)], ["Люблін", Vector2(22.57, 51.25)],
	["Мінськ", Vector2(27.56, 53.9)], ["Брест", Vector2(23.7, 52.1)], ["Гомель", Vector2(31.0, 52.43)],
	["Смоленськ", Vector2(32.05, 54.78)], ["Брянськ", Vector2(34.36, 53.24)], ["Курськ", Vector2(36.19, 51.73)],
	["Бєлгород", Vector2(36.6, 50.6)], ["Воронеж", Vector2(39.2, 51.66)], ["Ростов", Vector2(39.7, 47.24)],
	["Яси", Vector2(27.6, 47.16)], ["Вільнюс", Vector2(25.28, 54.69)],
]

const MOUNTAINS := [
	Vector2(22.8, 48.6), Vector2(23.3, 48.45), Vector2(23.8, 48.3), Vector2(24.3, 48.15), Vector2(24.9, 47.98),
	Vector2(23.2, 48.85), Vector2(23.7, 48.7), Vector2(24.2, 48.5), Vector2(24.7, 48.35), Vector2(25.2, 48.15),
	Vector2(34.2, 44.75), Vector2(34.8, 44.8),
]
const FORESTS := [
	Vector2(24.8, 51.45), Vector2(25.9, 51.5), Vector2(27.0, 51.3), Vector2(28.2, 51.2), Vector2(29.4, 51.1),
	Vector2(30.0, 50.8), Vector2(31.9, 51.85), Vector2(33.0, 51.9), Vector2(32.3, 48.55), Vector2(32.0, 48.35),
	Vector2(26.0, 50.6), Vector2(25.0, 50.2),
	Vector2(23.9, 52.75), Vector2(26.2, 52.5), Vector2(27.6, 52.3), Vector2(28.6, 54.2), Vector2(25.3, 53.3),
	Vector2(33.5, 53.2), Vector2(34.6, 53.6), Vector2(35.1, 52.6), Vector2(22.8, 51.8), Vector2(21.6, 53.6),
]


# Межі мапи (довгота/широта)
const LON0 := 19.0
const LON1 := 42.0
const LAT0 := 43.8
const LAT1 := 56.3
const KX := 0.67  # довгота коротша за широту на цих широтах
const MAP_W := (LON1 - LON0) * KX
const MAP_H := LAT1 - LAT0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.0

var selected := ""
var current := ""  # де зараз козак
var targets := {}  # місцевості з активними завданнями
var story_target := ""  # куди веде сюжет (зірка)
var plague := {}  # id місцевості -> рівень зарази (0..3)
var hero_level := 1
var map_rect := Rect2()  # область для мапи на екрані
var zoom := 1.6
var center := Vector2(MAP_W * 0.55, MAP_H * 0.55)  # центр огляду в одиницях мапи
var _scale := 60.0
var _origin := Vector2.ZERO
var _k := 1.0  # множник розміру підписів і значків
var _pulse := 0.0
var _markers := {}  # id -> екранна позиція
var _touches := {}  # індекс дотику -> позиція (для щипка)
var _pinch_dist := 0.0
var _dragging := false
var _press_pos := Vector2.ZERO
var _zoom_box: VBoxContainer


func _ready() -> void:
	clip_contents = true
	_zoom_box = VBoxContainer.new()
	_zoom_box.add_theme_constant_override("separation", 8)
	add_child(_zoom_box)
	for t in ["+", "−"]:
		var b := Button.new()
		b.text = t
		b.custom_minimum_size = Vector2(64, 64)
		b.pressed.connect(_zoom_button.bind(1.35 if t == "+" else 1.0 / 1.35))
		_zoom_box.add_child(b)


func _zoom_button(f: float) -> void:
	_zoom_at(map_rect.get_center(), f)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse += delta * 4.0
	if _zoom_box:
		_zoom_box.position = Vector2(map_rect.position.x + 8, map_rect.end.y - 144)
	queue_redraw()


# ---------- Проєкція і масштаб ----------

func _unit(ll: Vector2) -> Vector2:
	return Vector2((ll.x - LON0) * KX, LAT1 - ll.y)


func _proj(ll: Vector2) -> Vector2:
	return _origin + _unit(ll) * _scale


func _to_unit(screen: Vector2) -> Vector2:
	return (screen - _origin) / _scale


func _poly(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_proj(p))
	return out


## Переводить центр огляду в на екранні параметри і не дає вийти за межі мапи.
func _layout() -> void:
	var r := map_rect if map_rect.size.x > 10 else Rect2(Vector2.ZERO, size)
	var base := minf(r.size.x / MAP_W, r.size.y / MAP_H)
	zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	_scale = base * zoom
	var half := r.size / (2.0 * _scale)
	center.x = clampf(center.x, half.x, MAP_W - half.x) if MAP_W > half.x * 2.0 else MAP_W / 2.0
	center.y = clampf(center.y, half.y, MAP_H - half.y) if MAP_H > half.y * 2.0 else MAP_H / 2.0
	_origin = r.get_center() - center * _scale
	_k = clampf(_scale / 60.0, 0.75, 2.0)


func _zoom_at(screen_pt: Vector2, factor: float) -> void:
	_layout()
	var before := _to_unit(screen_pt)
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_layout()
	var after := _to_unit(screen_pt)
	center += before - after
	queue_redraw()


func focus_on(id: String) -> void:
	var ll: Vector2 = Data.CITIES[id]["pos"] if Data.CITIES.has(id) else (Data.LOCATIONS[id]["pos"] if Data.LOCATIONS.has(id) else Vector2(31, 49))
	center = _unit(ll)


# ---------- Керування: тап, перетягування, щипок, коліщатко ----------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_touches.clear()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_dist = 0.0
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d: float = pts[0].distance_to(pts[1])
			if _pinch_dist > 0.0 and d > 0.0:
				_zoom_at((pts[0] + pts[1]) / 2.0, d / _pinch_dist)
			_pinch_dist = d
			_dragging = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragging = false
			elif not _dragging:
				_tap(event.position)
			accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _touches.size() >= 2:
			return
		if _dragging or event.position.distance_to(_press_pos) > 14.0:
			_dragging = true
			center -= event.relative / _scale
			queue_redraw()


func _tap(pos: Vector2) -> void:
	var best := ""
	var best_d := 34.0 * _k
	for id in _markers:
		var d: float = pos.distance_to(_markers[id])
		if d < best_d:
			best_d = d
			best = id
	if best != "":
		selected = best
		location_selected.emit(best)


# ---------- Малювання ----------

func _draw() -> void:
	_layout()
	var font := ThemeDB.fallback_font
	var k := _k
	# Суходіл сусідів і моря
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.47, 0.48, 0.4))
	draw_colored_polygon(_poly(BLACK_SEA), Color(0.18, 0.36, 0.55))
	draw_colored_polygon(_poly(AZOV_SEA), Color(0.22, 0.42, 0.6))
	draw_colored_polygon(_poly(BALTIC), Color(0.18, 0.36, 0.55))
	var poland := _poly(POLAND)
	var belarus := _poly(BELARUS)
	draw_colored_polygon(poland, Color(0.55, 0.53, 0.43))
	draw_colored_polygon(belarus, Color(0.5, 0.55, 0.45))
	# Україна
	var land := _poly(BORDER)
	draw_colored_polygon(land, Color(0.62, 0.67, 0.4))
	# Степ на півдні й сході
	for p in [Vector2(35.5, 47.6), Vector2(37.5, 48.3), Vector2(33.0, 47.2), Vector2(30.0, 47.2), Vector2(34.0, 46.6), Vector2(38.5, 49.0), Vector2(40.0, 48.0)]:
		draw_circle(_proj(p), _scale * 1.0, Color(0.78, 0.72, 0.38, 0.3))
	# Ліси
	for p in FORESTS:
		var c := _proj(p)
		for i in 4:
			draw_circle(c + Vector2(i * 7 - 10, (i % 2) * 5) * k, _scale * 0.2, Color(0.22, 0.42, 0.2, 0.85))
	# Річки
	for r in RIVERS:
		draw_polyline(_poly(r[1]), Color(0.25, 0.48, 0.75), maxf(2.0, _scale * 0.06), true)
	# Гори
	for p in MOUNTAINS:
		var c := _proj(p)
		var s := _scale * 0.3
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.5), c + Vector2(s, s * 0.5), c + Vector2(0, -s)]), Color(0.45, 0.4, 0.35))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(s * 0.3, -s * 0.4), c + Vector2(0, -s)]), Color(0.95, 0.95, 0.95))
	# Кордони
	draw_polyline(poland + PackedVector2Array([poland[0]]), Color(0.3, 0.27, 0.2, 0.8), 1.5, true)
	draw_polyline(belarus + PackedVector2Array([belarus[0]]), Color(0.3, 0.27, 0.2, 0.8), 1.5, true)
	draw_polyline(land + PackedVector2Array([land[0]]), Color(0.25, 0.22, 0.12), 2.5, true)
	# Назви країн і морів — великі, напівпрозорі, ростуть разом із масштабом
	for cn in COUNTRY_NAMES:
		var fs := int(clampf(_scale * 0.42, 14, 64))
		if cn[0] == "УКРАЇНА" or cn[0].length() > 8:
			fs = int(fs * 0.75)
		_text(font, _proj(cn[1]), cn[0], fs, Color(1, 1, 1, 0.28), false)
	_text(font, _proj(Vector2(31.5, 44.1)), "Чорне море", int(clampf(_scale * 0.3, 13, 40)), Color(0.75, 0.88, 1.0))
	_text(font, _proj(Vector2(37.2, 46.3)), "Азовське море", int(clampf(_scale * 0.22, 11, 30)), Color(0.75, 0.88, 1.0))
	# Міста сусідів (орієнтири): ховаються, якщо мапа сильно віддалена
	var town_fs := int(clampf(_scale * 0.2, 0, 22))
	for t in TOWNS:
		var c := _proj(t[1])
		draw_circle(c, 3.0 * k, Color(0.25, 0.22, 0.18))
		if town_fs >= 11:
			_text(font, c + Vector2(0, 16 * k), t[0], town_fs, Color(0.92, 0.9, 0.84, 0.85))

	# Зараза: зелений туман довкола заражених місцевостей
	var tpl := Time.get_ticks_msec() / 1000.0
	for id in plague:
		var pl := int(plague[id])
		if pl <= 0 or not Data.LOCATIONS.has(id):
			continue
		var pc := _proj(Data.LOCATIONS[id]["pos"])
		var pr := (26.0 + 16.0 * pl) * k * (1.0 + 0.05 * sin(tpl * 1.5 + pc.x))
		draw_circle(pc, pr, Color(0.35, 0.7, 0.1, 0.1 + 0.05 * pl))
		draw_circle(pc, pr * 0.65, Color(0.25, 0.55, 0.05, 0.1 + 0.05 * pl))
		draw_arc(pc, pr, 0.0, TAU, 32, Color(0.6, 1.0, 0.2, 0.35), 2.0)

	# Маркери місць
	_markers.clear()
	var label_fs := int(clampf(15.0 * k, 12, 28))
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		var c := _proj(L["pos"])
		_markers[id] = c
		var danger: bool = L["level"] > hero_level + 2
		var r := 14.0 * k
		if L["type"] == "dungeon":
			draw_circle(c, r, Color(0.12, 0.08, 0.06))
			draw_arc(c + Vector2(0, 4) * k, r * 0.68, PI, TAU, 12, Color(0.85, 0.6, 0.3), 4.0 * k)
		else:
			draw_circle(c, r, Color(0.25, 0.15, 0.1))
			draw_line(c + Vector2(-8, -8) * k, c + Vector2(8, 8) * k, Color(0.9, 0.9, 0.95), 3.0 * k)
			draw_line(c + Vector2(8, -8) * k, c + Vector2(-8, 8) * k, Color(0.9, 0.9, 0.95), 3.0 * k)
		draw_arc(c, r + 1, 0, TAU, 24, Color(1.0, 0.35, 0.3) if danger else Color(0.95, 0.85, 0.5), 2.5)
		_text(font, c + Vector2(0, r + label_fs + 2), "%s (%d)" % [L["name"], L["level"]], label_fs, Color(1, 0.85, 0.75) if danger else Color.WHITE)
	var city_fs := int(clampf(18.0 * k, 13, 32))
	for id in Data.CITIES:
		var C: Dictionary = Data.CITIES[id]
		var c := _proj(C["pos"])
		_markers[id] = c
		var red := Color(0.55, 0.15, 0.12)
		draw_rect(Rect2(c + Vector2(-13, -8) * k, Vector2(26, 16) * k), red)
		for dx in [-13, -2, 9]:
			draw_rect(Rect2(c + Vector2(dx, -14) * k, Vector2(5, 7) * k), red)
		draw_rect(Rect2(c + Vector2(-13, -8) * k, Vector2(26, 16) * k), Color(0.95, 0.8, 0.3), false, 2.0)
		draw_rect(Rect2(c + Vector2(-3, 0) * k, Vector2(6, 8) * k), Color(0.2, 0.1, 0.05))
		_text(font, c + Vector2(0, 12 * k + city_fs), C["name"], city_fs, Color(1.0, 0.9, 0.55))

	# Хутір козака
	var hc := _proj(Camp.CAMP["pos"])
	_markers[Camp.CAMP_ID] = hc
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-14, 0) * k, hc + Vector2(0, -14) * k, hc + Vector2(14, 0) * k]), Color(0.7, 0.55, 0.25))
	draw_rect(Rect2(hc + Vector2(-11, 0) * k, Vector2(22, 12) * k), Color(0.95, 0.92, 0.82))
	draw_rect(Rect2(hc + Vector2(-3, 4) * k, Vector2(6, 8) * k), Color(0.35, 0.22, 0.1))
	draw_line(hc + Vector2(10, -6) * k, hc + Vector2(10, -24) * k, Color(0.3, 0.2, 0.1), 2.0)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(10, -24) * k, hc + Vector2(22, -21) * k, hc + Vector2(10, -18) * k]), Color(0.15, 0.35, 0.8))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(10, -21) * k, hc + Vector2(22, -21) * k, hc + Vector2(10, -18) * k]), Color(1.0, 0.85, 0.1))
	_text(font, hc + Vector2(0, 14 * k + city_fs), Camp.CAMP["name"], city_fs, Color(0.75, 1.0, 0.7))

	# Завдання
	for id in targets:
		if _markers.has(id):
			var c: Vector2 = _markers[id] + Vector2(16, -22) * k
			draw_circle(c, 10 * k, Color(1.0, 0.8, 0.1))
			_text(font, c + Vector2(0, 6 * k), "!", int(18 * k), Color(0.2, 0.1, 0.0), false)
	# Сюжет — пульсуюча зірка
	if _markers.has(story_target):
		var sc: Vector2 = _markers[story_target] + Vector2(-18, -26) * k
		var rr := (13.0 + sin(_pulse * 1.5) * 2.0) * k
		var star := PackedVector2Array()
		for i in 10:
			star.append(sc + Vector2.from_angle(-PI / 2 + i * PI / 5) * (rr if i % 2 == 0 else rr * 0.45))
		draw_colored_polygon(star, Color(1.0, 0.85, 0.2))
		draw_polyline(star + PackedVector2Array([star[0]]), Color(0.4, 0.2, 0.0), 2.0, true)
	# Де козак
	if _markers.has(current):
		var c: Vector2 = _markers[current] + Vector2(-20, -18) * k
		draw_line(c, c + Vector2(0, -26) * k, Color(0.3, 0.2, 0.1), 3.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26) * k, c + Vector2(16, -21) * k, c + Vector2(0, -15) * k]), Color(0.9, 0.15, 0.15))
	# Вибране місце
	if _markers.has(selected):
		draw_arc(_markers[selected], (24 + sin(_pulse) * 3) * k, 0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)


## Підпис по центру; ширина рахується за реальним розміром тексту.
func _text(font: Font, pos: Vector2, text: String, fs: int, col: Color, outline: bool = true) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w / 2.0, 0)
	if outline:
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 4), Color(0, 0, 0, 0.8))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
