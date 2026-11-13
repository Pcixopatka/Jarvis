extends Control
## Мапа України: моря, річки, Карпати, ліси, міста, дикі місцевості та печери.
## Координати — довгота/широта, спроєктовані на екран.

signal location_selected(id: String)
signal point_tapped(ll: Vector2)  # дотик до порожнього місця мапи: довгота й широта точки
signal travel_tapped  # дотик під час подорожі — прискорити
signal guide_pressed  # дотик до кнопки «Далі: …» (головна порада порадника)
signal legend_pressed  # дотик до «?»: що означають позначки

const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Acts := preload("res://scripts/data/activities.gd")
const PARCHMENT := preload("res://assets/gfx/sprites/map_parchment.png")
const ICONS := preload("res://assets/gfx/sprites/map_icons.png")
const ICON_ORDER := ["castle", "hut", "tree", "pine", "mountain", "swamp", "cave", "tower", "skull", "sabres", "wave", "camp", "ship", "rider", "flag", "town", "raid", "wagon", "chains", "wounded", "tent", "moon", "chest", "mound", "bow", "fish", "cart", "dice", "rider2", "serpent", "dune", "island", "ruin", "mine", "oak", "izba", "cannon", "leshy", "doghead", "kotel", "frost", "bell"]
# Кольори чорнила старовинної мапи
const INK := Color(0.23, 0.16, 0.1)
const BATTLE_EV := ["village_raid", "caravan", "sich_siege", "captives", "wounded"]
const INK_SOFT := Color(0.35, 0.26, 0.17, 0.8)
const SEA := Color(0.55, 0.66, 0.68)
const LAND_UA := Color(0.93, 0.86, 0.68)
const LAND_NEAR := Color(0.86, 0.8, 0.64)
const LAND_FAR := Color(0.82, 0.77, 0.62)


## Значок мапи з центром у pos, розмір size (на екрані).
func _icon(name: String, pos: Vector2, size: float, tint: Color = Color.WHITE) -> void:
	var i := ICON_ORDER.find(name)
	if i < 0:
		return
	draw_texture_rect_region(ICONS, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), Rect2(i * 24, 0, 24, 24), tint)


## Який значок у місцевості (див. Data.place_icon).
func _loc_icon(L: Dictionary) -> String:
	return Data.place_icon(L)


## Пунктирна лінія (кордони, шлях).
func _dashed(pts: PackedVector2Array, col: Color, width: float, dash: float, closed: bool = false) -> void:
	var n := pts.size()
	for i in (n if closed else n - 1):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var len := a.distance_to(b)
		var t := 0.0
		while t < len:
			var t2 := minf(len, t + dash)
			draw_line(a.lerp(b, t / len), a.lerp(b, t2 / len), col, width)
			t += dash * 2.0

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
	Vector2(28.95, 45.3), Vector2(29.7, 45.35), Vector2(30.2, 45.85), Vector2(30.7, 46.45), Vector2(31.6, 46.55), Vector2(32.6, 46.1), Vector2(33.7, 46.15), Vector2(33.2, 45.8), Vector2(32.5, 45.35), Vector2(33.4, 44.9), Vector2(33.6, 44.5), Vector2(34.4, 44.5), Vector2(35.4, 44.95), Vector2(36.4, 45.05), Vector2(37.5, 44.6), Vector2(38.3, 44.35), Vector2(39, 44.1), Vector2(39.7, 43.55), Vector2(41, 42.95), Vector2(41.65, 42.1), Vector2(41.6, 41.55), Vector2(40.2, 41), Vector2(38.4, 40.95), Vector2(37, 41.15), Vector2(36.1, 41.7), Vector2(35.1, 42.05), Vector2(33.3, 42), Vector2(32.3, 41.75), Vector2(31.4, 41.15), Vector2(29.9, 41.15), Vector2(29.1, 41.2), Vector2(28.2, 41.5), Vector2(28, 42), Vector2(27.6, 42.5), Vector2(27.9, 43.2), Vector2(28.6, 43.4), Vector2(28.65, 44.15), Vector2(29, 44.8), Vector2(29.6, 45.1),
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
	["Дніпро (верхів'я)", [Vector2(33.35, 55.85), Vector2(33.45, 55.35), Vector2(33.28, 54.91), Vector2(32.05, 54.78), Vector2(32.05, 54.78), Vector2(31.2, 54.6), Vector2(30.4, 54.5), Vector2(30.3, 53.9), Vector2(30.1, 53.2), Vector2(30.6, 52.4)]],
	["Прип'ять", [Vector2(24.5, 51.75), Vector2(25.8, 51.9), Vector2(27.3, 52.1), Vector2(28.6, 52.1), Vector2(29.6, 51.8), Vector2(30.2, 51.35), Vector2(30.55, 51.0)]],
	["Вісла", [Vector2(19.0, 50.05), Vector2(19.9, 50.05), Vector2(21.0, 50.4), Vector2(21.8, 51.0), Vector2(21.6, 51.6), Vector2(21.0, 52.25), Vector2(20.2, 52.5), Vector2(19.0, 52.7)]],
	["Західний Буг", [Vector2(24.1, 49.9), Vector2(24.1, 50.85), Vector2(23.65, 51.55), Vector2(23.6, 52.1), Vector2(22.6, 52.4), Vector2(21.4, 52.6)]],
	["Дон", [Vector2(38.4, 54.0), Vector2(38.9, 53.0), Vector2(39.2, 51.66), Vector2(40.0, 50.5), Vector2(41.2, 49.6), Vector2(42.0, 48.9)]],
	["Німан", [Vector2(26.6, 53.5), Vector2(25.5, 53.6), Vector2(24.4, 53.9), Vector2(23.9, 54.6), Vector2(22.9, 55.0)]],
	["Волга", [Vector2(32.47, 57.25), Vector2(33, 57.05), Vector2(33.47, 56.85), Vector2(34, 56.35), Vector2(34.33, 56.26), Vector2(34.6, 56.2), Vector2(34.93, 56.48), Vector2(35.4, 56.75), Vector2(35.9, 56.86), Vector2(36.6, 56.78), Vector2(37.17, 56.73), Vector2(37.5, 56.95), Vector2(37.84, 57.24), Vector2(38.33, 57.53), Vector2(38.84, 58.05), Vector2(39.4, 57.85), Vector2(39.89, 57.63), Vector2(40.4, 57.7), Vector2(40.93, 57.77), Vector2(41.5, 57.6), Vector2(42, 57.47)]],
	["Ока", [Vector2(36.07, 52.97), Vector2(36.15, 53.5), Vector2(36.13, 53.81), Vector2(36, 54.2), Vector2(36.25, 54.51), Vector2(36.7, 54.45), Vector2(37.07, 54.51), Vector2(37.41, 54.92), Vector2(38.15, 54.83), Vector2(38.78, 55.1), Vector2(39.3, 54.8), Vector2(39.74, 54.63), Vector2(40.4, 54.75), Vector2(41, 54.75), Vector2(41.42, 54.94), Vector2(41.8, 55.3), Vector2(42, 55.55)]],
	["Москва-ріка", [Vector2(35.7, 55.6), Vector2(36.03, 55.5), Vector2(36.86, 55.73), Vector2(37.3, 55.8), Vector2(37.62, 55.75), Vector2(37.95, 55.6), Vector2(38.4, 55.45), Vector2(38.68, 55.32), Vector2(38.78, 55.1)]],
	["Клязьма", [Vector2(37, 56), Vector2(37.6, 55.95), Vector2(38.2, 55.9), Vector2(38.9, 55.95), Vector2(39.4, 56.05), Vector2(40, 56.12), Vector2(40.4, 56.13), Vector2(41, 56.2), Vector2(41.6, 56.25), Vector2(42, 56.2)]],
	["Угра", [Vector2(33.3, 54.6), Vector2(34, 54.75), Vector2(34.6, 54.8), Vector2(35.24, 54.74), Vector2(35.8, 54.62), Vector2(36.3, 54.53)]],
	["Західна Двіна", [Vector2(32.75, 56.9), Vector2(32.27, 56.65), Vector2(32.07, 56.26), Vector2(31.2, 55.6), Vector2(30.2, 55.2), Vector2(28.8, 55.5), Vector2(27.5, 55.8), Vector2(26.5, 55.87), Vector2(25.3, 56.4), Vector2(24.1, 56.95)]],
	["Сосна", [Vector2(36.6, 52.45), Vector2(37.6, 52.42), Vector2(38.5, 52.62), Vector2(38.98, 52.65)]],
	["Волга (пониззя)", [Vector2(42, 57.47), Vector2(43.1, 56.9), Vector2(44, 56.33), Vector2(46, 56.1), Vector2(47.5, 56.1), Vector2(49.1, 55.8), Vector2(49.4, 54.9), Vector2(48.6, 54.3), Vector2(49.6, 53.4), Vector2(50.1, 53.2), Vector2(48.8, 52.6), Vector2(47.4, 52), Vector2(46, 51.5), Vector2(45.4, 50.1), Vector2(44.5, 48.7), Vector2(45.6, 48.3), Vector2(46.8, 47.4), Vector2(48, 46.35), Vector2(48.5, 45.9)]],
	["Кама", [Vector2(56.25, 58), Vector2(55.2, 57.3), Vector2(53.8, 56.5), Vector2(52.3, 55.7), Vector2(51, 55.5), Vector2(49.3, 55.35)]],
	["Урал", [Vector2(59, 53.4), Vector2(58.6, 51.2), Vector2(57, 51.3), Vector2(55.1, 51.77), Vector2(53, 51.5), Vector2(51.4, 51.2), Vector2(51.6, 49.8), Vector2(52, 48.4), Vector2(51.9, 47.1)]],
	["Дон (пониззя)", [Vector2(42, 48.9), Vector2(43.5, 48.7), Vector2(42.9, 47.9), Vector2(42, 47.5), Vector2(40.9, 47.4), Vector2(39.7, 47.24), Vector2(39.3, 47.2)]],
	["Північна Двіна", [Vector2(46.3, 60.75), Vector2(46.6, 61.25), Vector2(44.3, 62.1), Vector2(42.8, 62.9), Vector2(41.9, 63.7), Vector2(40.6, 64.5)]],
	["Дунай", [Vector2(17, 48), Vector2(18.9, 47.8), Vector2(19.05, 47.5), Vector2(18.9, 46.2), Vector2(19.85, 45.25), Vector2(20.46, 44.8), Vector2(21.4, 44.75), Vector2(22.5, 44.6), Vector2(22.7, 44.1), Vector2(22.9, 43.95), Vector2(24, 43.75), Vector2(25.6, 43.65), Vector2(26, 43.9), Vector2(27.3, 44.1), Vector2(27.9, 44.4), Vector2(28.05, 45.4), Vector2(28.8, 45.25), Vector2(29.6, 45.15)]],
	["Кубань", [Vector2(42.1, 43.9), Vector2(42.05, 44.2), Vector2(41.1, 45), Vector2(39, 45.05), Vector2(38, 45.2), Vector2(37.4, 45.3)]],
	["Терек", [Vector2(44.5, 42.7), Vector2(44.7, 43), Vector2(44.65, 43.75), Vector2(46, 43.55), Vector2(46.7, 43.85), Vector2(47.4, 43.8)]],
	["Кура", [Vector2(43.3, 41.95), Vector2(44.8, 41.7), Vector2(46, 41), Vector2(47, 40.6), Vector2(48, 40.45)]],
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
	Vector2(17, 54.5), Vector2(18.3, 54.8), Vector2(18.6, 54.4), Vector2(19.6, 54.45), Vector2(19.95, 54.95), Vector2(21.2, 55.2), Vector2(21.05, 56.5), Vector2(21.55, 57.4), Vector2(22.6, 57.75), Vector2(23.5, 57.05), Vector2(24.1, 57), Vector2(24.35, 57.75), Vector2(24.5, 58.35), Vector2(23.5, 58.6), Vector2(23.45, 59.2), Vector2(24.75, 59.5), Vector2(26.5, 59.55), Vector2(28, 59.5), Vector2(29.9, 59.9), Vector2(28.6, 60.55), Vector2(26.5, 60.45), Vector2(24.9, 60.15), Vector2(23, 59.85), Vector2(21.5, 60.6), Vector2(21.4, 61.6), Vector2(21.3, 62.6), Vector2(22, 63.3), Vector2(24.6, 64.9), Vector2(25.3, 65.5), Vector2(24.2, 65.8), Vector2(22.2, 65.7), Vector2(21.3, 64.6), Vector2(20.3, 63.8), Vector2(18.6, 62.9), Vector2(17.4, 62), Vector2(17, 61.2),
]
const CASPIAN := [
	Vector2(47.3, 45.6), Vector2(48.2, 46.2), Vector2(49.2, 46.45), Vector2(51, 46.9), Vector2(52.6, 46.9), Vector2(53.1, 46.4), Vector2(52.9, 45.4), Vector2(51.3, 45.2), Vector2(50.3, 44.5), Vector2(50.9, 44), Vector2(51.2, 43.1), Vector2(52.6, 41.9), Vector2(52.9, 41), Vector2(53, 40.4), Vector2(49.6, 40.4), Vector2(49.3, 41), Vector2(48.6, 41.8), Vector2(48.2, 42.2), Vector2(47.5, 43), Vector2(47.4, 43.8), Vector2(46.8, 44.5),
]
const WHITE_SEA := [
	Vector2(34.7, 64.5), Vector2(35.9, 64), Vector2(37, 63.85), Vector2(38.1, 64.2), Vector2(37.9, 64.75), Vector2(39.5, 64.55), Vector2(40.5, 64.55), Vector2(40.3, 65.2), Vector2(41.6, 66), Vector2(42.6, 66.45), Vector2(44.2, 66.2), Vector2(43.8, 67.5), Vector2(41.3, 67.5), Vector2(41, 66.9), Vector2(39.5, 66.2), Vector2(37, 66.2), Vector2(35, 66.55), Vector2(33.2, 66.75), Vector2(32.5, 67.1), Vector2(32.6, 66.75), Vector2(33.6, 66.2), Vector2(34.5, 65.7), Vector2(34.7, 65),
]
const LADOGA := [Vector2(30.9, 59.95), Vector2(31.6, 60.15), Vector2(32.6, 60.3), Vector2(33, 60.75), Vector2(32.5, 61.25), Vector2(31, 61.7), Vector2(30, 61.25), Vector2(30.1, 60.6)]
const ONEGA := [Vector2(34.3, 61.3), Vector2(35.2, 61), Vector2(36.3, 61.2), Vector2(36, 62), Vector2(35, 62.6), Vector2(34.4, 62.6), Vector2(34.8, 61.9)]
## Усі води мапи: моря й великі озера (малюються однаково).
const SEAS := [BLACK_SEA, AZOV_SEA, BALTIC, CASPIAN, WHITE_SEA, LADOGA, ONEGA]
## Підписи вод: [назва, де, частка розміру підпису країни]
const SEA_NAMES := [["Чорне море", Vector2(33.6, 43.2), 0.3], ["Азовське море", Vector2(37.2, 46.3), 0.22], ["Каспійське море", Vector2(50.9, 42.3), 0.3],
	["Балтійське море", Vector2(19.3, 57.2), 0.3], ["Біле море", Vector2(37.6, 65.3), 0.26]]
const COUNTRY_NAMES := [
	["ПОЛЬЩА", Vector2(20.9, 52.9)], ["БІЛОРУСЬ", Vector2(27.6, 53.4)], ["МОСКОВІЯ", Vector2(40.7, 53.4)], ["ЛАТВІЯ", Vector2(25.8, 57.2)],
	["УКРАЇНА", Vector2(29.0, 49.75)], ["МОЛДОВА", Vector2(28.6, 47.2)], ["РУМУНІЯ", Vector2(24.8, 46.9)],
	["СЛОВАЧЧИНА", Vector2(20.6, 48.75)], ["УГОРЩИНА", Vector2(21.0, 47.4)], ["ЛИТВА", Vector2(24.6, 55.0)],
	["БОЛГАРІЯ", Vector2(25.3, 43.25)], ["СЕРБІЯ", Vector2(20.8, 44.0)], ["ТУРЕЧЧИНА", Vector2(33.6, 40.8)], ["ГРУЗІЯ", Vector2(43.6, 42.05)],
	["АЗЕРБАЙДЖАН", Vector2(47.3, 40.9)], ["КАЗАХСТАН", Vector2(56.2, 48.2)], ["ЕСТОНІЯ", Vector2(25.9, 58.9)], ["ФІНЛЯНДІЯ", Vector2(26.3, 62.5)],
	["ШВЕЦІЯ", Vector2(18.3, 64.6)],
]
# Міста сусідів — лише орієнтири на мапі
const TOWNS := [
	["Варшава", Vector2(21.0, 52.23)], ["Краків", Vector2(19.94, 50.06)], ["Люблін", Vector2(22.57, 51.25)],
	["Мінськ", Vector2(27.56, 53.9)], ["Брест", Vector2(23.7, 52.1)], ["Гомель", Vector2(31.0, 52.43)],
	["Смоленськ", Vector2(32.05, 54.78)], ["Брянськ", Vector2(34.36, 53.24)], ["Курськ", Vector2(36.19, 51.73)],
	["Бєлгород", Vector2(36.6, 50.6)], ["Воронеж", Vector2(39.2, 51.66)], ["Ростов", Vector2(39.7, 47.24)],
	["Яси", Vector2(27.6, 47.16)], ["Вільнюс", Vector2(25.28, 54.69)],
	["Калуга", Vector2(36.25, 54.51)], ["Рязань", Vector2(39.74, 54.63)], ["Кострома", Vector2(40.93, 57.77)], ["Вітебськ", Vector2(30.2, 55.19)], ["Псков", Vector2(28.33, 57.82)], ["Рига", Vector2(24.1, 56.95)],
	["Казань", Vector2(49.1, 55.8)], ["Нижній Новгород", Vector2(44, 56.33)], ["Астрахань", Vector2(48.03, 46.35)], ["Царицин", Vector2(44.5, 48.7)], ["Архангельськ", Vector2(40.53, 64.54)], ["Вологда", Vector2(39.9, 59.2)], ["Перм", Vector2(56.25, 58)], ["Уфа", Vector2(55.97, 54.74)], ["Самара", Vector2(50.1, 53.2)], ["Оренбург", Vector2(55.1, 51.77)], ["Тбілісі", Vector2(44.8, 41.7)], ["Софія", Vector2(23.32, 42.7)], ["Белград", Vector2(20.46, 44.8)], ["Бухарест", Vector2(26.1, 44.43)], ["Стамбул", Vector2(28.98, 41)], ["Таллінн", Vector2(24.75, 59.44)], ["Новгород", Vector2(31.27, 58.52)],
]

## Степ: де малювати рідкі штрихи трави
const STEPPE := [Vector2(35.5, 47.6), Vector2(37.5, 48.3), Vector2(33.0, 47.2), Vector2(30.0, 47.2), Vector2(34.0, 46.6), Vector2(38.5, 49.0), Vector2(40.0, 48.0),
	Vector2(43.5, 47.0), Vector2(45.5, 48.0), Vector2(47.0, 49.5), Vector2(50.0, 49.0), Vector2(53.0, 49.5), Vector2(56.0, 49.6), Vector2(59.0, 49.8), Vector2(44.5, 45.5),
	Vector2(46.0, 46.6), Vector2(54.5, 47.2), Vector2(57.5, 46.5), Vector2(55.5, 44.5), Vector2(58.5, 43.5), Vector2(56.0, 42.0), Vector2(60.0, 45.5), Vector2(49.5, 51.5),
	Vector2(52.5, 52.0), Vector2(46.5, 51.0), Vector2(59.5, 41.6), Vector2(54.5, 41.2)]
const MOUNTAINS := [
	Vector2(22.8, 48.6), Vector2(23.3, 48.45), Vector2(23.8, 48.3), Vector2(24.3, 48.15), Vector2(24.9, 47.98),
	Vector2(23.2, 48.85), Vector2(23.7, 48.7), Vector2(24.2, 48.5), Vector2(24.7, 48.35), Vector2(25.2, 48.15),
	Vector2(34.2, 44.75), Vector2(34.8, 44.8),
	Vector2(39.8, 43.9), Vector2(40.6, 43.6), Vector2(41.4, 43.4), Vector2(42.2, 43.3), Vector2(43, 43.1), Vector2(43.8, 42.9), Vector2(44.6, 42.7), Vector2(45.4, 42.6), Vector2(46.2, 42.3), Vector2(47, 41.9), Vector2(47.7, 41.4), Vector2(42.6, 42.8), Vector2(44.2, 42.4), Vector2(22.8, 43.3), Vector2(23.6, 42.95), Vector2(24.4, 42.8), Vector2(25.2, 42.75), Vector2(26, 42.8), Vector2(26.8, 42.85), Vector2(23.5, 42.1), Vector2(24.5, 41.75), Vector2(25.4, 41.6), Vector2(19.3, 43.4), Vector2(20, 42.8), Vector2(20.6, 42.2), Vector2(22.8, 45.4), Vector2(23.8, 45.45), Vector2(24.8, 45.5), Vector2(25.6, 45.45), Vector2(59.3, 53), Vector2(58.6, 53.9), Vector2(58.9, 54.8), Vector2(59.4, 55.7), Vector2(59.7, 56.6), Vector2(59.6, 57.6), Vector2(59.3, 58.6), Vector2(59.1, 59.6), Vector2(59.4, 60.6), Vector2(59.6, 61.6), Vector2(60, 62.6), Vector2(60.4, 63.6), Vector2(60.9, 64.6), Vector2(61.4, 65.6), Vector2(58.2, 54.4), Vector2(58.7, 56.1), Vector2(58.6, 58.1),
]
const FORESTS := [
	Vector2(24.8, 51.45), Vector2(25.9, 51.5), Vector2(27.0, 51.3), Vector2(28.2, 51.2), Vector2(29.4, 51.1),
	Vector2(30.0, 50.8), Vector2(31.9, 51.85), Vector2(33.0, 51.9), Vector2(32.3, 48.55), Vector2(32.0, 48.35),
	Vector2(26.0, 50.6), Vector2(25.0, 50.2),
	Vector2(23.9, 52.75), Vector2(26.2, 52.5), Vector2(27.6, 52.3), Vector2(28.6, 54.2), Vector2(25.3, 53.3),
	Vector2(33.5, 53.2), Vector2(34.6, 53.6), Vector2(35.1, 52.6), Vector2(22.8, 51.8), Vector2(21.6, 53.6),
	Vector2(34.3, 55.9), Vector2(37.3, 57.2), Vector2(40.3, 58.25), Vector2(41.2, 56.3), Vector2(37.2, 53.0), Vector2(34.7, 55.4), Vector2(39.4, 54.1), Vector2(31.4, 56.9), Vector2(35.6, 57.9), Vector2(41.3, 54.4), Vector2(32.0, 57.8),
	Vector2(33, 59.6), Vector2(36, 59.8), Vector2(38.5, 60.4), Vector2(41, 59.6), Vector2(43.5, 60.2), Vector2(45.5, 59), Vector2(48, 58.4), Vector2(50.5, 58.9), Vector2(53, 59.4), Vector2(55.5, 59.9), Vector2(44, 62), Vector2(47.5, 62.5), Vector2(50.5, 62), Vector2(53.5, 61.5), Vector2(56.5, 61), Vector2(38, 62.5), Vector2(41.5, 61.3), Vector2(31.5, 62.8), Vector2(33.5, 63.6), Vector2(29, 62), Vector2(27, 63.5), Vector2(29.5, 65), Vector2(45, 64.5), Vector2(49, 64.8), Vector2(53, 64.2), Vector2(57, 63.4), Vector2(44.5, 57.6), Vector2(47, 57.2), Vector2(52, 57.3), Vector2(55, 56.2), Vector2(57, 55.2), Vector2(54, 54.2), Vector2(26.5, 58.2), Vector2(26.5, 61.5), Vector2(24, 62.3), Vector2(23.5, 64.2), Vector2(27.5, 60.9), Vector2(46.5, 65.9), Vector2(51, 66.3), Vector2(56, 65.6), Vector2(21, 44.3), Vector2(22, 43.6), Vector2(24.5, 43.3), Vector2(26.5, 43.3), Vector2(25.5, 45), Vector2(23, 46.2), Vector2(21.5, 46), Vector2(40, 44.5), Vector2(41.5, 44), Vector2(45.5, 43.2),
]


# Межі мапи (довгота/широта)
## Від Балкан і Кавказу на півдні до Білого моря на півночі, від Балтики на заході до Уралу на сході.
const LON0 := 17.0
const LON1 := 62.0
const LAT0 := 40.4
const LAT1 := 67.5
const KX := 0.67  # довгота коротша за широту на цих широтах
const MAP_W := (LON1 - LON0) * KX
const MAP_H := LAT1 - LAT0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 7.5
const HOME := Vector2(31.65, 49.4)  # де відкривається мапа: Наддніпрянщина

var selected := ""
var current := ""  # де зараз козак
var current_ll = null  # Vector2, якщо козак стоїть не в місці, а просто на мапі (вільна точка)
var targets := {}  # місцевості з активними завданнями
var turn_ins := {}  # місто -> скільки виконаного там можна здати (зелена позначка з галочкою)
var story_target := ""  # куди веде сюжет: перша сюжетна місія (зірка)
var stars := {}  # місця решти сюжетних місій (теж зірка, QuestEngine.map_marks)
var dim_stars := {}  # міста, де сюжетна місія чекає, поки герой підросте (бліда зірка)
var dim_targets := {}  # те саме для решти місій (блідий «!»)
const DIM := 0.5  # прозорість блідої позначки (як у закритих місць занять)
var plague := {}  # id місцевості -> рівень зарази (0..3)
var sieges := {}  # місто/хутір -> походів до падіння (облога)
var events := []  # значки подій: [{"id", "ll", "icon", "label", "kind"}] (див. EventService.map_marks)
var hero_level := 1
## Подорож: {"from": id, "to": id, "t": 0..1} або порожньо. Фігурка їде дугою, камера слідує.
var travel := {}
var map_rect := Rect2()  # область для мапи на екрані
var zoom := 2.9
var center := Vector2((HOME.x - LON0) * KX, LAT1 - HOME.y)  # центр огляду в одиницях мапи
var _scale := 60.0
var _origin := Vector2.ZERO
var _k := 1.0  # множник розміру підписів і значків
var _pulse := 0.0
var _markers := {}  # id -> екранна позиція
var _touches := {}  # індекс дотику -> позиція (для щипка)
var is_covered := Callable()  # чи мапу зараз затуляє інший екран: тоді щипок її не масштабує
var _pinch_dist := 0.0
var _dragging := false
var _press_pos := Vector2.ZERO
var _zoom_box: VBoxContainer
var guide_btn: Button  # «Далі: …» унизу мапи: головна порада, дотик веде до неї


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
	var lb := Button.new()
	lb.text = "?"
	lb.custom_minimum_size = Vector2(64, 64)
	lb.pressed.connect(func(): legend_pressed.emit())
	_zoom_box.add_child(lb)
	guide_btn = Button.new()
	guide_btn.visible = false
	guide_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	guide_btn.clip_text = true
	guide_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	guide_btn.add_theme_font_size_override("font_size", 20)
	guide_btn.pressed.connect(func(): guide_pressed.emit())
	add_child(guide_btn)


## Головна порада на кнопці внизу мапи ("" — кнопки нема).
func set_guide(text: String) -> void:
	guide_btn.text = text
	guide_btn.visible = text != ""


func _zoom_button(f: float) -> void:
	_zoom_at(map_rect.get_center(), f)


## Скільки разів на секунду мапа перемальовується, коли на ній нічого не рухається. Пульсують лише
## позначки (зірка сюжету, коло вибраного місця, значки подій), і їм цього досить. Повне перемалювання
## мапи коштує в сотню разів більше за будь-який інший екран: шістдесят разів на секунду воно лише гріло телефон.
const IDLE_FPS := 12.0
var _idle_t := 0.0  # скільки ще чекати до наступного перемалювання в спокої
var redraws := 0  # скільки разів мапу перемальовано (для перевірки, що вона не працює вхолосту)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_idle_t = 0.0  # щойно мапу покажуть, вона намалюється в тому ж кадрі
		return
	_pulse += delta * 4.0
	if not travel.is_empty():
		# Камера м'яко слідує за фігуркою: у дорозі малюємо кожен кадр
		var want := _unit(_travel_ll(travel["t"]))
		center = center.lerp(want, minf(1.0, delta * 4.0))
		_place_overlays()
		queue_redraw()
		return
	_idle_t -= delta
	if _idle_t <= 0.0:
		_idle_t = 1.0 / IDLE_FPS
		_place_overlays()
		queue_redraw()


## Кнопки поверх мапи: масштаб і порада «Далі: …».
func _place_overlays() -> void:
	if _zoom_box:
		_zoom_box.position = Vector2(map_rect.position.x + 8, map_rect.end.y - 216)
	if guide_btn and guide_btn.visible:
		# праворуч від кнопок масштабу, не ширша за вільне місце на мапі
		var fs: int = guide_btn.get_theme_font_size("font_size")
		var want: float = guide_btn.get_theme_font("font").get_string_size(guide_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
		guide_btn.size = Vector2(clampf(want, 160.0, maxf(160.0, map_rect.size.x - 100.0)), 60.0)
		guide_btn.position = Vector2(map_rect.position.x + 84, map_rect.end.y - 68)


## Координати (довгота, широта) точки шляху для прогресу t — пряма між місцями.
func _place_ll(id: String) -> Vector2:
	if Data.is_city(id):
		return Data.city(id)["pos"]
	if Data.is_place(id):
		return Data.place(id)["pos"]
	if id == Camp.CAMP_ID:
		return Camp.camp()["pos"]
	if Acts.is_spot(id):
		return Acts.spot(id)["pos"]
	return Vector2(31, 49)


## Початок і кінець поїздки: місце або вільна точка мапи ("from_ll" / "to_ll").
func _travel_from() -> Vector2:
	return travel["from_ll"] if travel.has("from_ll") else _place_ll(travel["from"])


func _travel_to() -> Vector2:
	return travel["to_ll"] if travel.has("to_ll") else _place_ll(travel["to"])


func _travel_ll(t: float) -> Vector2:
	return _travel_from().lerp(_travel_to(), clampf(t, 0.0, 1.0))


## Чи точка лежить у морі чи великому озері: там замість вершника пливе чайка.
static func at_sea(ll: Vector2) -> bool:
	for sea in SEAS:
		if Geometry2D.is_point_in_polygon(ll, PackedVector2Array(sea)):
			return true
	return false


## Точка мапи під пальцем: довгота й широта, не ближче ніж EDGE до краю мапи.
const EDGE := 0.6

func ll_at(screen: Vector2) -> Vector2:
	var u := _to_unit(screen)
	return Vector2(clampf(u.x / KX + LON0, LON0 + EDGE, LON1 - EDGE), clampf(LAT1 - u.y, LAT0 + EDGE, LAT1 - EDGE))


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


func focus_ll(ll: Vector2) -> void:
	center = _unit(ll)
	queue_redraw()


func focus_on(id: String) -> void:
	queue_redraw()
	center = _unit(_place_ll(id))
	# подія, що рухається мапою (конвой із бранцями), стоїть не там, де її мета
	for ev in events:
		if ev["id"] == id and ev["kind"] == "captives":
			center = _unit(ev["ll"])


# ---------- Керування: тап, перетягування, щипок, коліщатко ----------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (is_covered.is_valid() and is_covered.call()):
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
				if not travel.is_empty():
					travel_tapped.emit()  # під час поїздки дотик — лише прискорити
				else:
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
		queue_redraw()  # коло вибраного місця з'являється одразу, не чекаючи спокійного такту
		location_selected.emit(best)
	elif map_rect.has_point(pos):
		point_tapped.emit(ll_at(pos))  # порожнє місце: козак може їхати просто туди


# ---------- Малювання ----------

func _draw() -> void:
	redraws += 1
	_layout()
	var font := ThemeDB.fallback_font
	var k := _k
	# Пергамент на всю мапу (плитка), далі — суходіл і моря
	draw_texture_rect(PARCHMENT, Rect2(Vector2.ZERO, size), true, LAND_FAR)
	var poland := _poly(POLAND)
	var belarus := _poly(BELARUS)
	var land := _poly(BORDER)
	draw_colored_polygon(poland, Color(LAND_NEAR, 0.6))
	draw_colored_polygon(belarus, Color(LAND_NEAR, 0.6))
	draw_colored_polygon(land, Color(LAND_UA, 0.75))
	for sea in SEAS:
		var sp := _poly(sea)
		draw_colored_polygon(sp, Color(SEA, 0.85))
		draw_polyline(sp + PackedVector2Array([sp[0]]), INK_SOFT, 1.5, true)
	# Штрихування моря хвильками
	var wave_step := maxf(26.0, _scale * 0.5)
	for sea in SEAS:
		var sp := _poly(sea)
		var rr := Rect2(sp[0], Vector2.ZERO)
		for q in sp:
			rr = rr.expand(q)
		var yy := rr.position.y
		var row := 0
		while yy < rr.end.y:
			var xx := rr.position.x + (row % 2) * wave_step * 0.5
			while xx < rr.end.x:
				if Geometry2D.is_point_in_polygon(Vector2(xx, yy), sp):
					draw_arc(Vector2(xx, yy), wave_step * 0.18, PI * 1.1, PI * 1.9, 6, Color(INK, 0.25), 1.0)
				xx += wave_step
			yy += wave_step * 0.6
			row += 1
	# Степ: рідкі штрихи трави на півдні
	for p in STEPPE:
		var c := _proj(p)
		for i in 5:
			var q := c + Vector2((i - 2) * 0.35, (i % 2) * 0.2 - 0.1) * _scale
			draw_line(q, q + Vector2(-3, -7) * k, Color(0.45, 0.5, 0.25, 0.7), 1.5)
			draw_line(q + Vector2(4, 0) * k, q + Vector2(6, -8) * k, Color(0.45, 0.5, 0.25, 0.7), 1.5)
	# Ліси: купки дерев
	var ico := clampf(_scale * 0.42, 18.0, 44.0)
	for p in FORESTS:
		var c := _proj(p)
		for i in 3:
			_icon("tree" if (i + int(p.x * 10)) % 3 != 0 else "pine", c + Vector2(i * 0.3 - 0.3, (i % 2) * 0.18 - 0.1) * _scale, ico)
	# Річки: темна жилка зі світлою серединою
	for r in RIVERS:
		var pts := _poly(r[1])
		draw_polyline(pts, Color(0.33, 0.45, 0.55), maxf(3.0, _scale * 0.08), true)
		draw_polyline(pts, Color(0.7, 0.82, 0.88), maxf(1.0, _scale * 0.03), true)
	# Гори
	for p in MOUNTAINS:
		_icon("mountain", _proj(p), ico * 1.2)
	# Кордони — пунктир чорнилом
	_dashed(poland, INK_SOFT, 1.5, 6.0 * k, true)
	_dashed(belarus, INK_SOFT, 1.5, 6.0 * k, true)
	draw_polyline(land + PackedVector2Array([land[0]]), INK, 2.5, true)
	# Назви країн і морів — чорнилом, із розрядкою
	for cn in COUNTRY_NAMES:
		var fs := int(clampf(_scale * 0.42, 14, 64))
		if cn[0] == "УКРАЇНА" or cn[0].length() > 8:
			fs = int(fs * 0.75)
		_text(font, _proj(cn[1]), " ".join(cn[0].split()), fs, Color(INK, 0.3), false)
	for sn in SEA_NAMES:
		_text(font, _proj(sn[1]), sn[0], int(clampf(_scale * float(sn[2]), 11, 40)), Color(0.2, 0.3, 0.38), false)
	for sh in [Vector2(31.2, 43.9), Vector2(36.8, 42.7), Vector2(29.3, 42.6), Vector2(50.6, 44.9), Vector2(19.0, 55.9), Vector2(20.0, 59.6), Vector2(38.9, 65.7)]:
		_icon("ship", _proj(sh), ico * 1.2)
	# Міста сусідів (орієнтири): ховаються, якщо мапа сильно віддалена
	var town_fs := int(clampf(_scale * 0.2, 0, 22))
	for t in TOWNS:
		var c := _proj(t[1])
		_icon("town", c, ico * 0.8)
		if town_fs >= 11:
			_text(font, c + Vector2(0, 16 * k + ico * 0.3), t[0], town_fs, Color(INK, 0.85), false)

	# Зараза: зелений туман довкола заражених місцевостей
	var tpl := Time.get_ticks_msec() / 1000.0
	for id in plague:
		var pl := int(plague[id])
		if pl <= 0 or not Data.is_place(id):
			continue
		var pc := _proj(Data.place(id)["pos"])
		var pr := (26.0 + 16.0 * pl) * k * (1.0 + 0.05 * sin(tpl * 1.5 + pc.x))
		draw_circle(pc, pr, Color(0.35, 0.7, 0.1, 0.1 + 0.05 * pl))
		draw_circle(pc, pr * 0.65, Color(0.25, 0.55, 0.05, 0.1 + 0.05 * pl))
		draw_arc(pc, pr, 0.0, TAU, 32, Color(0.6, 1.0, 0.2, 0.35), 2.0)

	# Маркери місць (назви — окремо, після всіх маркерів: ті, що налазять, ховаються)
	_markers.clear()
	var labels := []  # [пріоритет, id, позиція, текст, розмір, колір]
	var label_fs := int(clampf(15.0 * k, 12, 28))
	for id in Data.place_ids():
		var L: Dictionary = Data.place(id)
		var c := _proj(L["pos"])
		_markers[id] = c
		var danger: bool = L["level"] > hero_level + 2
		var r := 16.0 * k
		# Кружечок-печатка й піксельний значок місцевості
		draw_circle(c, r, Color(0.96, 0.92, 0.8, 0.9))
		draw_arc(c, r, 0, TAU, 24, Color(0.75, 0.2, 0.15) if danger else INK, 2.0)
		_icon(_loc_icon(L), c, r * 1.5)
		# печери з босом ростуть із героєм: позначка «21+» — із якого рівня туди можна; поле має сталий рівень
		var lvl_text := ("%d+" % int(L["level"])) if L.get("scale", false) else str(L["level"])
		labels.append([10, id, c + Vector2(0, r + label_fs + 2), "%s (%s)" % [L["name"], lvl_text], label_fs, Color(0.6, 0.12, 0.08) if danger else INK])
	var city_fs := int(clampf(18.0 * k, 13, 32))
	for id in Data.city_ids():
		var C: Dictionary = Data.city(id)
		var c := _proj(C["pos"])
		_markers[id] = c
		_icon("castle", c, 40.0 * k)
		labels.append([70 if id == "sich" else 50, id, c + Vector2(0, 14 * k + city_fs), C["name"], city_fs, Color(0.45, 0.1, 0.06)])

	# Хутір козака
	var hc := _proj(Camp.camp()["pos"])
	_markers[Camp.CAMP_ID] = hc
	_icon("camp", hc, 40.0 * k)
	labels.append([45, Camp.CAMP_ID, hc + Vector2(0, 14 * k + city_fs), Camp.camp()["name"], city_fs, Color(0.2, 0.4, 0.15)])
	# Місця занять: варта, полювання, рибалка
	for sid in Acts.spot_ids():
		var S: Dictionary = Acts.spot(sid)
		var sc := _proj(S["pos"])
		_markers[sid] = sc
		var locked: bool = hero_level < int(S["level"])
		draw_circle(sc, 16.0 * k, Color(0.96, 0.92, 0.8, 0.9))
		draw_arc(sc, 16.0 * k, 0, TAU, 24, Color(0.2, 0.4, 0.15) if not locked else Color(INK, 0.4), 2.0)
		_icon(S["icon"], sc, 26.0 * k, Color.WHITE if not locked else Color(1, 1, 1, 0.45))
		labels.append([12, sid, sc + Vector2(0, 16 * k + label_fs + 2), S["name"], label_fs, Color(0.2, 0.4, 0.15) if not locked else Color(INK, 0.5)])
	_draw_labels(font, labels)

	# Завдання й несюжетні місії; блідий «!» — місія чекає, поки герой підросте (як закриті місця занять)
	for id in dim_targets:
		if _markers.has(id) and not targets.has(id):
			var c: Vector2 = _markers[id] + Vector2(16, -22) * k
			draw_circle(c, 10 * k, Color(1.0, 0.8, 0.1, DIM))
			_text(font, c + Vector2(0, 6 * k), "!", int(18 * k), Color(0.2, 0.1, 0.0, 0.8), false)
	for id in targets:
		if _markers.has(id):
			var c: Vector2 = _markers[id] + Vector2(16, -22) * k
			draw_circle(c, 10 * k, Color(1.0, 0.8, 0.1))
			_text(font, c + Vector2(0, 6 * k), "!", int(18 * k), Color(0.2, 0.1, 0.0), false)
	# Виконане: зелена позначка з галочкою на місті, де це здають
	for id in turn_ins:
		if _markers.has(id):
			var tc: Vector2 = _markers[id] + Vector2(20, -24) * k
			var tr := (12.0 + sin(_pulse * 1.5) * 1.5) * k
			draw_circle(tc, tr + 2.0 * k, Color(0.08, 0.25, 0.08))
			draw_circle(tc, tr, Color(0.3, 0.8, 0.3))
			draw_polyline(PackedVector2Array([tc + Vector2(-5.5, 0.5) * k, tc + Vector2(-1.5, 4.5) * k, tc + Vector2(6, -4.5) * k]), Color.WHITE, 3.0 * k, true)
			if int(turn_ins[id]) > 1:
				_text(font, tc + Vector2(tr + 8.0 * k, 7.0 * k), str(int(turn_ins[id])), int(clampf(17.0 * k, 13, 28)), Color(0.1, 0.4, 0.1))
	# Облоги: червоне пульсуюче кільце й напис
	for id in sieges:
		if _markers.has(id):
			var sc: Vector2 = _markers[id]
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			draw_arc(sc, (24.0 + 6.0 * pulse) * k, 0.0, TAU, 32, Color(1.0, 0.25, 0.15, 0.6 + 0.4 * pulse), 4.0 * k)
			_text(font, sc + Vector2(0, -30 * k), "Облога! (%d)" % int(sieges[id]), int(clampf(16.0 * k, 12, 26)), Color(1.0, 0.45, 0.35))
	# Події світу: значок біля місця (конвой із бранцями — там, куди дійшов)
	for ev in events:
		var ec: Vector2 = _proj(ev["ll"])
		var off := Vector2(18, -22) * k if ev["kind"] in ["night", "treasure", "burned"] else Vector2(-20, -26) * k
		if ev["kind"] == "captives":
			off = Vector2.ZERO
			_markers[ev["id"]] = ec
		var bob := sin(_pulse * 1.3 + ec.x) * 2.0 * k if ev["kind"] in BATTLE_EV else 0.0
		var sz := (34.0 if ev["kind"] in BATTLE_EV else 24.0) * k
		if ev["kind"] in BATTLE_EV:
			draw_circle(ec + off, sz * 0.62, Color(1.0, 0.92, 0.7, 0.9))
			draw_arc(ec + off, sz * 0.62, 0, TAU, 24, Color(0.75, 0.2, 0.15), 2.0)
		_icon(ev["icon"], ec + off + Vector2(0, bob), sz)
		if ev["label"] != "":
			_text(font, ec + off + Vector2(0, -sz * 0.7), ev["label"], int(clampf(14.0 * k, 11, 22)), Color(0.6, 0.12, 0.08))
	# Сюжет — пульсуюча зірка (над кожною сюжетною місією); бліда — сюжетна місія чекає, поки герой підросте
	for id in dim_stars:
		if _markers.has(id) and id != story_target and not stars.has(id):
			_draw_star(_markers[id] + Vector2(-18, -26) * k, 13.0 * k, DIM)
	for id in stars:
		if _markers.has(id) and id != story_target:
			_draw_star(_markers[id] + Vector2(-18, -26) * k, (13.0 + sin(_pulse * 1.5) * 2.0) * k, 1.0)
	if _markers.has(story_target):
		_draw_star(_markers[story_target] + Vector2(-18, -26) * k, (13.0 + sin(_pulse * 1.5) * 2.0) * k, 1.0)
	# Де козак: прапорець на місці або фігурка в дорозі
	if not travel.is_empty():
		_draw_traveler(k)
	elif current_ll != null:
		_draw_rider(_proj(current_ll), 1.0, 0.0, k, at_sea(current_ll))  # стоїть просто на мапі
	elif _markers.has(current):
		_icon("flag", _markers[current] + Vector2(-18, -22) * k, 36.0 * k)
	# Рамка старовинної мапи
	var fr := Rect2(Vector2.ZERO, size)
	draw_rect(fr.grow(-3), INK, false, 6.0)
	draw_rect(fr.grow(-11), Color(INK, 0.6), false, 2.0)
	# Вибране місце
	if _markers.has(selected):
		draw_arc(_markers[selected], (24 + sin(_pulse) * 3) * k, 0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)


## Зірка сюжетної місії; alpha < 1 — бліда (місія чекає, поки герой підросте).
func _draw_star(sc: Vector2, rr: float, alpha: float) -> void:
	var star := PackedVector2Array()
	for i in 10:
		star.append(sc + Vector2.from_angle(-PI / 2 + i * PI / 5) * (rr if i % 2 == 0 else rr * 0.45))
	draw_colored_polygon(star, Color(1.0, 0.85, 0.2, alpha))
	draw_polyline(star + PackedVector2Array([star[0]]), Color(0.4, 0.2, 0.0, alpha), 2.0, true)


## Підпис по центру; ширина рахується за реальним розміром тексту.
## Фігурка героя в дорозі: пунктирний шлях, вершник із хоругвою, підскок у такт.
func _draw_traveler(k: float) -> void:
	var t: float = travel["t"]
	var a := _proj(_travel_from())
	var b := _proj(_travel_to())
	# Пунктир шляху: пройдене — яскраве, попереду — бліде
	var seg := 14.0 * k
	var n := maxi(2, int(a.distance_to(b) / seg))
	for i in n:
		if i % 2 == 1:
			continue
		var f0 := float(i) / n
		var f1 := float(i + 1) / n
		var col := Color(1.0, 0.85, 0.3, 0.9) if f1 <= t else Color(1.0, 1.0, 1.0, 0.35)
		draw_line(a.lerp(b, f0), a.lerp(b, f1), col, 3.0 * k)
	if travel.has("to_ll"):
		draw_arc(b, (9.0 + sin(_pulse) * 2.0) * k, 0, TAU, 20, Color(1.0, 0.85, 0.3, 0.9), 2.5 * k)  # куди їдемо, коли там порожньо
	var bob := absf(sin(_pulse * 2.5)) * 4.0 * k
	_draw_rider(a.lerp(b, t), 1.0 if b.x >= a.x else -1.0, bob, k, at_sea(_travel_ll(t)))


## Фігурка героя на мапі: вершник із хоругвою, а над морем чайка. side — куди дивиться (1 праворуч, -1 ліворуч).
func _draw_rider(p: Vector2, side: float, bob: float, k: float, sea: bool) -> void:
	draw_set_transform(p + Vector2(0, 6 * k), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0 * k, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Значок дивиться праворуч, ліворуч віддзеркалюємо довкола точки на шляху.
	# (Від'ємна ширина прямокутника лише перевертає кадр, а лівий край лишає на місці — фігурка з'їжджала вбік.)
	var sz := 48.0 * k
	var i := ICON_ORDER.find("ship" if sea else (rider_frame(_pulse) if bob > 0.0 else "rider"))
	draw_set_transform(p + Vector2(0, -(bob * 0.4 if sea else bob)), 0.0, Vector2(side, 1.0))
	draw_texture_rect_region(ICONS, Rect2(Vector2(-sz / 2.0, -sz * 0.7), Vector2(sz, sz)), Rect2(i * 24, 0, 24, 24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sea:
		_icon("flag", p + Vector2(10, -38) * k, 26.0 * k)  # прапорець, щоб чайку героя не сплутати з іншими кораблями


## Кадр вершника: у верхній точці підскоку кінь летить із витягнутими ногами, внизу — ноги на землі.
static func rider_frame(pulse: float) -> String:
	return "rider2" if absf(sin(pulse * 2.5)) > 0.45 else "rider"


## Назви місць без накладання: важливіші (вибране, мета, міста) малюються першими,
## а ті, що налазять на вже намальовані, ховаються до наближення мапи.
func _draw_labels(font: Font, labels: Array) -> void:
	for l in labels:
		if l[1] == selected:
			l[0] = 100
		elif l[1] == story_target or stars.has(l[1]) or targets.has(l[1]) or turn_ins.has(l[1]):
			l[0] += 30
		elif l[1] == current:
			l[0] += 20
	labels.sort_custom(func(a, b): return a[0] > b[0])
	var placed := []
	for l in labels:
		var w := font.get_string_size(l[3], HORIZONTAL_ALIGNMENT_LEFT, -1, l[4]).x
		var rect := Rect2(l[2] - Vector2(w / 2.0, l[4]), Vector2(w, l[4] * 1.15)).grow(2.0)
		var hit := false
		for r in placed:
			if r.intersects(rect):
				hit = true
				break
		if hit and l[0] < 100:
			continue
		placed.append(rect)
		_text(font, l[2], l[3], l[4], l[5])


func _text(font: Font, pos: Vector2, text: String, fs: int, col: Color, outline: bool = true) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w / 2.0, 0)
	if outline:
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 4), Color(0.96, 0.92, 0.8, 0.9))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
