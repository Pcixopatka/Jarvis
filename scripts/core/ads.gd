extends Node
## Реклама спонсорів (автозавантаження «Ads»). Лише добровільна — за нагороду.
##
## Зараз працює заглушка: замість справжньої реклами показується 5-секундний екран «Реклама спонсора».
## Щоб підключити справжню мережу (AdMob, Unity Ads), достатньо замінити _show_provider():
## викликати SDK і після перегляду викликати _finish(true), а при скасуванні — _finish(false).

signal ad_finished(placement: String, rewarded: bool)

const STUB_SECONDS := 5.0

var provider := "stub"
var instant := false  # для автотестів: нагорода без очікування
var views := 0  # скільки реклам переглянуто (для аналітики)
var _layer: CanvasLayer
var _cb: Callable
var _placement := ""
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_busy() -> bool:
	return _busy


## Показати рекламу за нагороду. on_done(rewarded: bool) викликається після закриття.
func show_rewarded(placement: String, on_done: Callable) -> void:
	if _busy:
		return
	_busy = true
	_cb = on_done
	_placement = placement
	if instant:
		_finish.call_deferred(true)
		return
	_show_provider()


func _show_provider() -> void:
	# Заглушка замість справжнього SDK
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	bg.add_child(box)
	box.add_child(_label("РЕКЛАМА СПОНСОРА", 22, Color(0.7, 0.7, 0.7)))
	box.add_child(_label("Тут буде реклама партнера гри", 40, Color(1.0, 0.85, 0.3)))
	box.add_child(_label("Дякуємо, що підтримуєте «Козацьку Звитягу»!", 24, Color(0.9, 0.9, 0.85)))
	var timer_label := _label("", 26, Color.WHITE)
	box.add_child(timer_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Скасувати"
	cancel.custom_minimum_size = Vector2(220, 64)
	cancel.pressed.connect(func(): _finish(false))
	row.add_child(cancel)
	var take := Button.new()
	take.text = "Отримати нагороду"
	take.custom_minimum_size = Vector2(320, 64)
	take.disabled = true
	take.pressed.connect(func(): _finish(true))
	row.add_child(take)
	var left := STUB_SECONDS
	while left > 0.0 and is_instance_valid(take):
		timer_label.text = "Нагорода через %d с" % ceili(left)
		await get_tree().create_timer(0.25, true, false, true).timeout
		left -= 0.25
	if is_instance_valid(take):
		timer_label.text = "Готово!"
		take.disabled = false


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _finish(rewarded: bool) -> void:
	if _layer:
		_layer.queue_free()
		_layer = null
	_busy = false
	if rewarded:
		views += 1
	ad_finished.emit(_placement, rewarded)
	if _cb.is_valid():
		_cb.call(rewarded)
