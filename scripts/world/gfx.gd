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
	# Від'ємна ширина лише віддзеркалює кадр: лівий край прямокутника лишається на місці
	var dst := Rect2(origin, Vector2(-SIZE if d[1] else SIZE, SIZE))
	ci.draw_texture_rect_region(tex, dst, src, tint)


# ---------- Значки здобичі ----------
const OBJECTS := preload("res://assets/gfx/cc0/objects.png")  # Zelda-like objects (CC0): скриня, монети, серце
## Порядок значків на листі assets/gfx/sprites/icons.png (його малює tools/pixel/icons.py, там той самий ORDER).
const ICON_ORDER := ["potion", "wood", "iron", "herbs", "trophy", "varenyk", "mana", "meat", "ryba", "veg",
	"tok_rizdvo", "tok_velykden", "tok_kupala", "tok_spas", "tok_nezalezhnist", "tok_pokrova", "tok_andrii", "glory", "khmil",
	"tok_malanka", "tok_vodokhreshche", "tok_sobornist", "tok_stritennia", "tok_masnytsia", "tok_shevchenko", "tok_blahovishchennia",
	"tok_verbna", "tok_yurii", "tok_vyshyvanka", "tok_zeleni", "tok_petra", "tok_derzhavnist", "tok_illi", "tok_obzhynky",
	"tok_zdvyzhennia", "tok_didy", "tok_mykhaila", "tok_kuzma", "tok_kateryny", "tok_mykolai"]
static var _loot_tex := {}


## Текстура значка здобичі (для інтерфейсу: TextureRect поруч із числом); null, якщо такого значка нема.
static func icon_tex(id: String) -> Texture2D:
	var i := ICON_ORDER.find(id)
	if i < 0:
		return null
	if not _loot_tex.has(id):
		var base := sheet("icons")
		if base == null:
			return null
		var at := AtlasTexture.new()
		at.atlas = base
		at.region = Rect2(i * 16, 0, 16, 16)
		_loot_tex[id] = at
	return _loot_tex[id]
const OBJ := {"chest": [0, 0], "chest_open": [1, 0], "coin": [0, 4], "coin_small": [3, 4], "heart": [0, 3]}


## Значок 16×16 у масштабі scale (за замовчуванням ×2) із центром у pos.
static func icon(ci: CanvasItem, id: String, pos: Vector2, scale: float = 2.0, tint: Color = Color.WHITE) -> void:
	var size := Vector2(16, 16) * scale
	if OBJ.has(id):
		var c: Array = OBJ[id]
		ci.draw_texture_rect_region(OBJECTS, Rect2(pos - size / 2.0, size), Rect2(c[0] * 16, c[1] * 16, 16, 16), tint)
		return
	var i := ICON_ORDER.find(id)
	if i < 0:
		return
	var tex := sheet("icons")
	if tex == null:
		return
	ci.draw_texture_rect_region(tex, Rect2(pos - size / 2.0, size), Rect2(i * 16, 0, 16, 16), tint)


# ---------- Значки вмінь ----------
const SkillIconIndex := preload("res://scripts/data/skill_icon_index.gd")
static var _icon_tex := {}


## Текстура значка вміння (для кнопок інтерфейсу); null, якщо значка нема.
static func skill_icon_tex(id: String) -> Texture2D:
	if not SkillIconIndex.INDEX.has(id):
		return null
	if not _icon_tex.has(id):
		var base := sheet("skill_icons")
		if base == null:
			return null
		var at := AtlasTexture.new()
		at.atlas = base
		var i: int = SkillIconIndex.INDEX[id]
		var sz: int = SkillIconIndex.SIZE
		at.region = Rect2((i % SkillIconIndex.COLS) * sz, (i / SkillIconIndex.COLS) * sz, sz, sz)
		_icon_tex[id] = at
	return _icon_tex[id]


## Намалювати значок вміння з центром у pos, розміром size (пікселів).
static func skill_icon(ci: CanvasItem, id: String, pos: Vector2, size: float, tint: Color = Color.WHITE) -> void:
	var tex := skill_icon_tex(id)
	if tex == null:
		return
	ci.draw_texture_rect(tex, Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), false, tint)


# ---------- Мури оборони (assets/gfx/sprites/defense.png, tools/pixel/defense.py) ----------
const DEFENSE := {
	"wagon": Rect2(0, 52, 64, 52),
	"palisade": Rect2(66, 32, 32, 72),
	"palisade_broken": Rect2(100, 32, 32, 72),
	"gate": Rect2(134, 16, 96, 88),
	"gate_broken": Rect2(232, 16, 96, 88),
	"tower": Rect2(330, 0, 56, 104),
	"fence": Rect2(388, 60, 32, 44),
	"camp_gate": Rect2(422, 40, 80, 64),
	"camp_gate_broken": Rect2(504, 40, 80, 64),
}


## Частина муру: опора — низ по центру, масштаб ×2.
static func wall_part(ci: CanvasItem, name: String, base: Vector2, scale_k: float = 2.0, tint: Color = Color.WHITE) -> void:
	var tex := sheet("defense")
	if tex == null or not DEFENSE.has(name):
		return
	var r: Rect2 = DEFENSE[name]
	var sz := r.size * scale_k
	ci.draw_texture_rect_region(tex, Rect2(base - Vector2(sz.x / 2.0, sz.y), sz), r, tint)
