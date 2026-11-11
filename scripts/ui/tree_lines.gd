extends Control
## Полотно дерева вмінь: малює лінії між значками (під самими значками, які лежать дітьми зверху).

var links: Array = []  # [[звідки: Vector2, куди: Vector2, чи відкрито: bool], ...]


func _draw() -> void:
	for l in links:
		var lit: bool = l[2]
		draw_line(l[0], l[1], Color(0.1, 0.08, 0.07), 8.0)
		draw_line(l[0], l[1], Color(1.0, 0.8, 0.3) if lit else Color(0.4, 0.33, 0.25), 4.0)
