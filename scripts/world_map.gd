extends Control
## Мапа України: моря, річки, Карпати, ліси, міста, дикі місцевості та печери.
## Координати — довгота/широта, спроєктовані на екран.

signal location_selected(id: String)

const Data := preload("res://scripts/data.gd")

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
	["Сіверський Донець", [Vector2(36.6, 50.4), Vector2(37.3, 49.6), Vector2(38.0, 49.0), Vector2(38.9, 48.85), Vector2(39.9, 48.4)]],
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
]

var main
var selected := ""
var current := ""  # де зараз козак
var targets := {}  # місцевості з активними завданнями
var hero_level := 1
var map_rect := Rect2()  # область для мапи на екрані
var _scale := 60.0
var _origin := Vector2.ZERO
var _pulse := 0.0
var _markers := {}  # id -> екранна позиція


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse += delta * 4.0
	queue_redraw()


func _proj(ll: Vector2) -> Vector2:
	return _origin + Vector2((ll.x - 21.6) * 0.67, 52.6 - ll.y) * _scale


func _poly(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_proj(p))
	return out


func _layout() -> void:
	var r := map_rect if map_rect.size.x > 10 else Rect2(Vector2.ZERO, size)
	var w := (40.6 - 21.6) * 0.67
	var h := 52.6 - 44.2
	_scale = minf(r.size.x / w, r.size.y / h)
	_origin = r.position + (r.size - Vector2(w, h) * _scale) / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var best_d := 46.0
		for id in _markers:
			var d: float = event.position.distance_to(_markers[id])
			if d < best_d:
				best_d = d
				best = id
		if best != "":
			selected = best
			location_selected.emit(best)
			accept_event()


func _draw() -> void:
	_layout()
	var font := ThemeDB.fallback_font
	# Суходіл сусідів і моря
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.38, 0.3))
	draw_colored_polygon(_poly(BLACK_SEA), Color(0.18, 0.36, 0.55))
	draw_colored_polygon(_poly(AZOV_SEA), Color(0.22, 0.42, 0.6))
	# Україна
	var land := _poly(BORDER)
	draw_colored_polygon(land, Color(0.62, 0.67, 0.4))
	# Степ на півдні й сході
	for p in [Vector2(35.5, 47.6), Vector2(37.5, 48.3), Vector2(33.0, 47.2), Vector2(30.0, 47.2), Vector2(34.0, 46.6), Vector2(38.5, 49.0)]:
		draw_circle(_proj(p), _scale * 1.0, Color(0.78, 0.72, 0.38, 0.35))
	# Ліси
	for p in FORESTS:
		var c := _proj(p)
		for k in 4:
			draw_circle(c + Vector2(k * 7 - 10, (k % 2) * 5), _scale * 0.22, Color(0.22, 0.42, 0.2, 0.85))
	# Річки
	for r in RIVERS:
		draw_polyline(_poly(r[1]), Color(0.25, 0.48, 0.75), maxf(2.0, _scale * 0.07), true)
	# Гори
	for p in MOUNTAINS:
		var c := _proj(p)
		var s := _scale * 0.32
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.5), c + Vector2(s, s * 0.5), c + Vector2(0, -s)]), Color(0.45, 0.4, 0.35))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.4), c + Vector2(s * 0.3, -s * 0.4), c + Vector2(0, -s)]), Color(0.95, 0.95, 0.95))
	draw_polyline(land + PackedVector2Array([land[0]]), Color(0.25, 0.22, 0.12), 2.5, true)
	# Підписи морів
	_text(font, _proj(Vector2(31.5, 44.0)), "Чорне море", 18, Color(0.75, 0.88, 1.0))
	_text(font, _proj(Vector2(37.2, 46.3)), "Азовське море", 14, Color(0.75, 0.88, 1.0))

	# Маркери місць
	_markers.clear()
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		var c := _proj(L["pos"])
		_markers[id] = c
		var danger: bool = L["level"] > hero_level + 2
		if L["type"] == "dungeon":
			draw_circle(c, 15, Color(0.12, 0.08, 0.06))
			draw_arc(c + Vector2(0, 4), 10, PI, TAU, 12, Color(0.85, 0.6, 0.3), 4.0)
		else:
			draw_circle(c, 14, Color(0.25, 0.15, 0.1))
			draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color(0.9, 0.9, 0.95), 3.0)
			draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color(0.9, 0.9, 0.95), 3.0)
		draw_arc(c, 15, 0, TAU, 24, Color(1.0, 0.35, 0.3) if danger else Color(0.95, 0.85, 0.5), 2.5)
		_text(font, c + Vector2(0, 32), "%s (%d)" % [L["name"], L["level"]], 14, Color(1, 0.85, 0.75) if danger else Color.WHITE)
	for id in Data.CITIES:
		var C: Dictionary = Data.CITIES[id]
		var c := _proj(C["pos"])
		_markers[id] = c
		# Фортеця
		draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 16)), Color(0.55, 0.15, 0.12))
		for dx in [-13, -2, 9]:
			draw_rect(Rect2(c + Vector2(dx, -14), Vector2(5, 7)), Color(0.55, 0.15, 0.12))
		draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 16)), Color(0.95, 0.8, 0.3), false, 2.0)
		draw_rect(Rect2(c + Vector2(-3, 0), Vector2(6, 8)), Color(0.2, 0.1, 0.05))
		_text(font, c + Vector2(0, 30), C["name"], 17, Color(1.0, 0.9, 0.55))

	# Завдання
	for id in targets:
		if _markers.has(id):
			var c: Vector2 = _markers[id] + Vector2(16, -22)
			draw_circle(c, 10, Color(1.0, 0.8, 0.1))
			_text(font, c + Vector2(0, 6), "!", 18, Color(0.2, 0.1, 0.0), false)
	# Де козак
	if _markers.has(current):
		var c: Vector2 = _markers[current] + Vector2(-20, -18)
		draw_line(c, c + Vector2(0, -26), Color(0.3, 0.2, 0.1), 3.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(16, -21), c + Vector2(0, -15)]), Color(0.9, 0.15, 0.15))
	# Вибране місце
	if _markers.has(selected):
		draw_arc(_markers[selected], 24 + sin(_pulse) * 3, 0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)


func _text(font: Font, pos: Vector2, text: String, fs: int, col: Color, outline: bool = true) -> void:
	var w := 260.0
	if outline:
		draw_string_outline(font, pos - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 5, Color(0, 0, 0, 0.8))
	draw_string(font, pos - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
