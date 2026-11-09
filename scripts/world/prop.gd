extends Node2D
## Об'єкт на землі (дерево, камінь, хата): малюється з атласу, опора — низ спрайта, сортується з героєм за y.

const Tiles := preload("res://scripts/world/tiles.gd")

var kind := "tree"


func setup(k: String, pos: Vector2) -> void:
	kind = k
	position = pos
	z_index = 0
	queue_redraw()


func _draw() -> void:
	var info: Dictionary = Tiles.PROPS[kind]
	var r: Array = info["r"]
	var w: float = r[2] * Tiles.TILE
	var h: float = r[3] * Tiles.TILE
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w * 0.38, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var src: Rect2 = Tiles.rg_src(r) if info["sheet"] == "rg" else Tiles.src(r)
	draw_texture_rect_region(Tiles.sheet(info["sheet"]), Rect2(Vector2(-w / 2.0, -h + 6.0), Vector2(w, h)), src)
