extends RefCounted
## Тайли з CC0-наборів (assets/gfx/cc0): координати клітинок 16×16 на листах, малюються ×2 (32 px).
## OV — Overworld (ArMM1998), CAVE — cave.png (ArMM1998). Кожен запис: [стовпець, рядок, ширина, висота] у клітинках.

const OV := preload("res://assets/gfx/cc0/overworld.png")
const CAVE := preload("res://assets/gfx/cc0/cave.png")
const RG := preload("res://assets/gfx/cc0/roguelike.png")  # Kenney: клітинки 16×16 з полем 1 px
const RG_STEP := 17
const T := 16  # розмір клітинки на листі
const SCALE := 2  # на екрані клітинка 32 px
const TILE := T * SCALE

# ---- земля (1×1) ----
const GRASS := [[0, 0], [2, 16], [3, 16]]
const GRASS_TALL := [[11, 5], [12, 5], [11, 6], [12, 6]]
const FLOWERS := [[0, 8], [1, 8], [3, 11], [3, 12]]
const ROCKS_SMALL := [[7, 5], [8, 5], [9, 5], [10, 5]]
const DIRT := [[12, 13], [13, 13], [12, 14], [13, 14]]
const WATER := [[3, 3], [4, 3], [5, 3], [3, 4], [4, 4], [5, 4]]
const WAVES := [[0, 1], [1, 1], [2, 1], [3, 1], [0, 2], [1, 2], [2, 2], [3, 2]]
const LILY := [[2, 0], [3, 0], [4, 0], [5, 0]]
const STONE := [[7, 3], [7, 3], [7, 3], [7, 3], [7, 3], [8, 2]]  # RG: світлий камінь (гори), зрідка бруківка
const STONE_DARK := [[5, 4], [6, 4], [5, 5]]  # RG
const SNOW := [[8, 0], [8, 1]]  # RG: сніг
const CAVE_FLOOR := [[5, 4], [5, 5], [6, 4], [6, 5], [8, 4], [9, 5]]  # на листі Kenney (RG): кам'яна підлога
const CAVE_FLOOR_LIGHT := [[6, 2], [7, 2], [8, 2], [7, 3]]  # світліший камінь (RG)
const RG_GRASS := [[5, 0], [5, 1]]
const RG_DIRT := [[6, 0], [6, 1]]  # втоптана земля (майдан)
const RG_PINES := [[16, 9], [16, 10], [18, 9], [18, 10]]
const CAVE_VOID := [[1, 1]]
const CAVE_WALL := [[1, 4], [2, 4], [3, 4]]  # передня стіна печери (над нею — верх [1,3])
const CAVE_WALL_TOP := [[1, 3], [2, 3], [3, 3]]

# ---- об'єкти (ставляться як Prop у шар сутностей, щоб сортувались із героєм) ----
const PROPS := {
	"tree": {"sheet": "ov", "r": [5, 16, 2, 2]},
	"bush": {"sheet": "ov", "r": [2, 14, 1, 1]},
	"stump": {"sheet": "ov", "r": [0, 12, 1, 1]},
	"stump2": {"sheet": "ov", "r": [1, 12, 1, 1]},
	"rock": {"sheet": "ov", "r": [4, 2, 2, 1]},
	"log": {"sheet": "ov", "r": [3, 5, 3, 1]},
	"house": {"sheet": "ov", "r": [6, 0, 5, 5]},
	"hut": {"sheet": "ov", "r": [13, 5, 2, 3]},
	"fence": {"sheet": "ov", "r": [3, 17, 1, 1]},
	"post": {"sheet": "ov", "r": [0, 17, 1, 1]},
	"boulder": {"sheet": "cave", "r": [5, 4, 1, 1]},
	"boulder2": {"sheet": "cave", "r": [6, 4, 1, 1]},
	"boulder_big": {"sheet": "cave", "r": [7, 5, 2, 2]},
	"pebbles": {"sheet": "cave", "r": [5, 3, 2, 1]},
	"idol": {"sheet": "cave", "r": [6, 0, 1, 3]},
	"idol2": {"sheet": "cave", "r": [8, 0, 1, 3]},
	"torch": {"sheet": "cave", "r": [0, 6, 1, 1]},
	"pine": {"sheet": "rg", "r": [16, 9, 1, 2]},
	"pine2": {"sheet": "rg", "r": [18, 9, 1, 2]},
	"tree_orange": {"sheet": "rg", "r": [14, 9, 1, 2]},
}


static func sheet(name: String) -> Texture2D:
	if name == "cave":
		return CAVE
	return RG if name == "rg" else OV


## Клітинка з листа Kenney (поле 1 px між клітинками).
static func rg_src(cell: Array) -> Rect2:
	var w: int = cell[2] if cell.size() > 2 else 1
	var h: int = cell[3] if cell.size() > 3 else 1
	return Rect2(cell[0] * RG_STEP, cell[1] * RG_STEP, w * T + (w - 1), h * T + (h - 1))


static func rg_tile(ci: CanvasItem, cell: Array, pos: Vector2, tint: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(RG, Rect2(pos, Vector2(TILE, TILE)), rg_src(cell), tint)


static func src(cell: Array) -> Rect2:
	var w: int = cell[2] if cell.size() > 2 else 1
	var h: int = cell[3] if cell.size() > 3 else 1
	return Rect2(cell[0] * T, cell[1] * T, w * T, h * T)


## Намалювати клітинку 1×1 у позиції екрана (ліво-верх).
static func tile(ci: CanvasItem, tex: Texture2D, cell: Array, pos: Vector2, tint: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(tex, Rect2(pos, Vector2(TILE, TILE)), src(cell), tint)
