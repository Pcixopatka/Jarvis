extends Node
## Гортання дотиком із будь-якої точки екрана.
## Кнопки й картки ковтають дотик, тож вбудоване гортання спрацьовує лише на порожньому місці.
## Цей вузол сам стежить за пальцем: якщо під ним є список, що гортається, і палець зрушив далі порогу,
## список їде за пальцем, а натиск кнопки, з якої почався рух, скасовується. Короткий дотик лишається дотиком.

const DEADZONE := 14.0  # на скільки пікселів треба зрушити палець, щоб дотик став гортанням
const FRICTION := 5.0  # як швидко згасає розгін після відпускання

var _sc: ScrollContainer = null  # список під пальцем
var _start := Vector2.ZERO
var _dragging := false
var _blocked: Object = null  # кнопка, чий натиск скасовано на час гортання
var _vel := Vector2.ZERO  # розгін після відпускання, пікселів за секунду
var _glide: ScrollContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # екран героя ставить гру на паузу, а гортати треба й там


## Найвищий видимий елемент інтерфейсу під точкою (той, що отримав би дотик).
static func control_at(node: Node, pos: Vector2) -> Control:
	if node is CanvasItem and not node.visible:
		return null
	for i in range(node.get_child_count() - 1, -1, -1):
		var hit := control_at(node.get_child(i), pos)
		if hit != null:
			return hit
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(pos):
		return node
	return null


## Найближчий список над елементом, якому справді є куди гортатись.
static func scroller_of(c: Control) -> ScrollContainer:
	var n: Node = c
	while n != null:
		if n is ScrollContainer:
			var v: ScrollBar = n.get_v_scroll_bar()
			var h: ScrollBar = n.get_h_scroll_bar()
			if v.max_value > v.page + 1.0 or h.max_value > h.page + 1.0:
				return n
		n = n.get_parent()
	return null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_release_block()
			_vel = Vector2.ZERO
			_glide = null
			_dragging = false
			_start = event.position
			var c := control_at(get_tree().root, event.position)
			# повзунки, смуги прокрутки й поля вводу тягнуться самі
			_sc = null if c == null or c is Range or c is LineEdit or c is TextEdit else scroller_of(c)
		elif _sc != null:
			if _dragging:
				_glide = _sc
				_release_block.call_deferred()  # кнопка отримає відпускання, але сигналу не дасть
			_sc = null
			_dragging = false
	elif event is InputEventMouseMotion and _sc != null and is_instance_valid(_sc):
		if not _dragging and event.position.distance_to(_start) > DEADZONE:
			_dragging = true
			var c := control_at(get_tree().root, _start)
			if c is BaseButton:
				_blocked = c
				c.set_block_signals(true)
		if _dragging:
			_move(_sc, event.relative)
			var dt: float = maxf(get_process_delta_time(), 0.008)
			_vel = _vel.lerp(event.relative / dt, 0.5)
		get_viewport().set_input_as_handled()  # вбудоване гортання не має їхати вдруге


func _move(sc: ScrollContainer, rel: Vector2) -> void:
	if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_vertical = sc.scroll_vertical - int(round(rel.y))
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_horizontal = sc.scroll_horizontal - int(round(rel.x))


func _release_block() -> void:
	if _blocked != null and is_instance_valid(_blocked):
		_blocked.set_block_signals(false)
	_blocked = null


func _process(delta: float) -> void:
	if _glide == null:
		return
	if not is_instance_valid(_glide) or _vel.length() < 20.0:
		_glide = null
		return
	_move(_glide, _vel * delta)
	_vel = _vel.lerp(Vector2.ZERO, minf(1.0, FRICTION * delta))
