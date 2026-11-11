extends Node
## Оплата справжніми грошима (автозавантаження «Billing»).
##
## Зараз працює заглушка: замість магазину застосунків показується екран «Тестова оплата», і гроші
## не списуються. Щоб підключити Google Play Billing, достатньо замінити _pay_provider():
## запустити покупку товару product у магазині й після підтвердженої оплати викликати _finish(true),
## а при відмові чи помилці — _finish(false). Назви товарів — у Shop.PACKS.
## Поки provider == "stub", збірку не можна викладати в магазин: червінці в ній безкоштовні.

signal purchase_finished(product: String, paid: bool)

var provider := "stub"
var instant := false  # для автотестів: оплата проходить одразу
var purchases := 0  # скільки оплат пройшло (для аналітики)
var _layer: CanvasLayer
var _cb: Callable
var _product := ""
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_busy() -> bool:
	return _busy


## Чи оплата тестова (гроші не списуються).
func is_test() -> bool:
	return provider == "stub"


## Купити товар. on_done(paid: bool) викликається, коли оплату завершено чи скасовано.
func purchase(product: String, title: String, price: String, on_done: Callable) -> void:
	if _busy:
		return
	_busy = true
	_cb = on_done
	_product = product
	if instant:
		_finish.call_deferred(true)
		return
	_pay_provider(title, price)


func _pay_provider(title: String, price: String) -> void:
	# Заглушка замість магазину застосунків
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
	box.add_theme_constant_override("separation", 20)
	bg.add_child(box)
	box.add_child(_label("ТЕСТОВА ОПЛАТА", 22, Color(0.7, 0.7, 0.7)))
	box.add_child(_label(title, 40, Color(1.0, 0.85, 0.3)))
	box.add_child(_label("Ціна в магазині застосунків: %s" % price, 26, Color(0.9, 0.9, 0.85)))
	box.add_child(_label("Це тестова збірка: справжні гроші не списуються.", 22, Color(0.6, 1.0, 0.6)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Скасувати"
	cancel.custom_minimum_size = Vector2(220, 64)
	cancel.pressed.connect(func(): _finish(false))
	row.add_child(cancel)
	var pay := Button.new()
	pay.text = "Оплатити (тест)"
	pay.custom_minimum_size = Vector2(320, 64)
	pay.pressed.connect(func(): _finish(true))
	row.add_child(pay)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _finish(paid: bool) -> void:
	if not _busy:
		return
	_busy = false
	if _layer != null:
		_layer.queue_free()
		_layer = null
	if paid:
		purchases += 1
	var cb := _cb
	var product := _product
	_cb = Callable()
	_product = ""
	purchase_finished.emit(product, paid)
	if cb.is_valid():
		cb.call(paid)
