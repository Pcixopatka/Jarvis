extends Control
## Стрілка до мети в бою: біля героя посеред екрана показує, куди йти, і підписує, що там.
## Напрямок і підпис дає Combat.objective(); тут лише малюнок. Коли мета поруч, стрілки нема.

const RADIUS := 120.0  # на якій відстані від героя стоїть стрілка
const NEAR := 240.0  # мета ближче за це вже на видноті: стрілка ховається

var dir := Vector2.ZERO  # напрямок до мети (одиничний), ZERO — мети нема
var label := ""
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # саме з відступами: інакше шар лишається нульового розміру


## Показати мету: to — вектор від героя до неї в одиницях світу. Порожній підпис ховає стрілку.
func show_target(to: Vector2, text: String) -> void:
	var on: bool = text != "" and to.length() > NEAR
	var d: Vector2 = to.normalized() if on else Vector2.ZERO
	if d != dir or text != label:
		dir = d
		label = text
		queue_redraw()
	visible = on


func _process(delta: float) -> void:
	if visible:
		_pulse += delta * 4.0
		queue_redraw()


func _draw() -> void:
	if dir == Vector2.ZERO:
		return
	var c: Vector2 = size / 2.0 + dir * (RADIUS + sin(_pulse) * 5.0)
	var side := dir.orthogonal()
	var tri := PackedVector2Array([c + dir * 28.0, c - dir * 14.0 + side * 19.0, c - dir * 4.0, c - dir * 14.0 - side * 19.0])
	draw_colored_polygon(tri, Color(1.0, 0.85, 0.3))
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.25, 0.12, 0.0), 2.5, true)
	var font := ThemeDB.fallback_font
	var fs := 20
	var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# підпис за вістрям стрілки: не налазить ні на героя, ні на саму стрілку
	var at: Vector2 = c + dir * 52.0 + Vector2(-w / 2.0, 7.0)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.05, 0.04, 0.03))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.7))
