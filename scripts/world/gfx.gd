extends RefCounted
## Спрайти персонажів і нечисті (assets/gfx/sprites, генеруються tools/pixel/sprites.py).
## Лист: 3 ряди (вниз, вгору, вбік-ліворуч) × 10 кадрів (стоїть, крок 1–4, удар 1–3, поранений, лежить), кадр 48×48.

const SIZE := 48
const DIR := "res://assets/gfx/sprites/"
static var _cache := {}  # id -> Texture2D або null, якщо листа нема
const ROW := {"down": 0, "up": 1, "side": 2}
const IDLE := 0
const WALK0 := 1
const ATK0 := 5
const HURT := 8
const DEAD := 9


static func sheet(id: String) -> Texture2D:
	if not _cache.has(id):
		var path := DIR + id + ".png"
		_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[id]


static func has(id: String) -> bool:
	return sheet(id) != null


## Напрям ряду за вектором погляду; flip — чи дивиться праворуч (кадр вбік намальовано ліворуч).
static func dir_of(facing: Vector2) -> Array:
	if absf(facing.x) >= absf(facing.y) * 0.9:
		return ["side", facing.x > 0.0]
	return ["up" if facing.y < 0.0 else "down", false]


static func walk_frame(phase: float) -> int:
	return WALK0 + (int(phase / (PI / 2.0)) % 4)


## Кадр удару за часткою замаху (0 — початок, 1 — кінець).
static func attack_frame(t: float) -> int:
	return ATK0 + clampi(int(t * 3.0), 0, 2)


static func draw(ci: CanvasItem, id: String, facing: Vector2, frame: int, origin: Vector2, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = sheet(id)
	var d := dir_of(facing)
	var src := Rect2(frame * SIZE, ROW[d[0]] * SIZE, SIZE, SIZE)
	var dst := Rect2(origin + Vector2(SIZE if d[1] else 0, 0), Vector2(-SIZE if d[1] else SIZE, SIZE))
	ci.draw_texture_rect_region(tex, dst, src, tint)
