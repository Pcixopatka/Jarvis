extends Node
## Реклама спонсорів (автозавантаження «Ads»). Лише добровільна — за нагороду.
##
## На Android зі збіркою, у якій є плагін addons/kz_ads (одинак рушія «KzAds»), показується справжня реклама
## Google AdMob «за нагороду» (provider == "admob"). Перед першою рекламою плагін питає згоду (Google UMP), потім
## вантажить оголошення наперед: щойно одне закрито, вантажиться наступне. Справжній рекламний блок береться лише
## в збірці з ознакою «store» (пресет «Google Play»); усі інші збірки показують тестову рекламу Google, бо клацати
## справжню рекламу у власному застосунку не можна. Ідентифікатори — data/settings.json, запис «admob».
##
## Без плагіна (комп'ютер, тести, збірка без плагіна) працює заглушка: 5-секундний екран «Реклама спонсора».
## Тести підставляють замість плагіна власний об'єкт з тими самими методами й сигналами (use_provider).

signal ad_finished(placement: String, rewarded: bool)

const GameDB := preload("res://scripts/core/game_db.gd")

const STUB_SECONDS := 5.0
const SINGLETON := "KzAds"
const UNAVAILABLE := "Реклама зараз недоступна. Спробуй трохи пізніше."
## Невдале завантаження повторюється через стільки секунд (що далі, то довше); після останнього — лише на прохання гравця.
const RETRY_DELAYS := [10.0, 30.0, 90.0, 240.0]
const START_TIMEOUT := 15.0  # секунд гри від «показати» до відповіді плагіна; поки реклама на екрані, гра стоїть
const SHOW_TIMEOUT := 300.0  # запобіжник, якщо після показу не прийшло «закрито»

## Ідентифікатори AdMob (data/settings.json, запис «admob»; робочі копії, їх заповнює apply_settings()).
static var APP_ID: String
static var REWARDED_UNIT: String
static var TEST_REWARDED_UNIT: String

var provider := "stub"
var instant := false  # для автотестів: нагорода без очікування
var views := 0  # скільки реклам переглянуто (для аналітики)
var has_feature: Callable = OS.has_feature  # тести підставляють власну перевірку ознаки збірки «store»
var last_message := ""  # останнє повідомлення гравцеві (для тестів)
var load_requests := 0  # скільки разів просили плагін завантажити рекламу
var _layer: CanvasLayer
var _cb: Callable
var _placement := ""
var _busy := false
var _native: Object = null  # плагін «KzAds» або підставлений тестами об'єкт
var _can_request := false  # згоду з'ясовано, рекламу можна просити
var _loading := false
var _retry_step := 0
var _retry_timer: Timer
var _show_timer: Timer
var _showing := false  # справжня реклама запущена й ще не закрита
var _earned := false
var _muted_before := false
var _input_before := false
var _toast: CanvasLayer


static func _static_init() -> void:
	apply_settings()


static func apply_settings() -> void:
	var S := GameDB.settings("admob")
	APP_ID = S["app_id"]
	REWARDED_UNIT = S["rewarded_unit"]
	TEST_REWARDED_UNIT = S["test_rewarded_unit"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_retry_timer = _timer(_on_retry)
	_show_timer = _timer(_on_show_timeout)
	if OS.get_name() == "Android":
		if Engine.has_singleton(SINGLETON):
			use_provider(Engine.get_singleton(SINGLETON))
		else:
			print("Реклама: плагіна %s у збірці нема, працює заглушка" % SINGLETON)


func _timer(on_timeout: Callable) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.timeout.connect(on_timeout)
	add_child(t)
	return t


func is_busy() -> bool:
	return _busy


## Чи збірка для магазину (ознака «store»): лише тоді справжній рекламний блок.
func is_store() -> bool:
	return bool(has_feature.call("store"))


## Рекламний блок цієї збірки: справжній у збірці для магазину, тестовий Google — в усіх інших.
func unit_id() -> String:
	return REWARDED_UNIT if is_store() else TEST_REWARDED_UNIT


## Підключити плагін реклами (або тестовий об'єкт із тими самими методами й сигналами); null — назад до заглушки.
func use_provider(obj: Object) -> void:
	if _native != null:
		for s in _SIGNALS:
			if _native.has_signal(s) and _native.is_connected(s, Callable(self, _SIGNALS[s])):
				_native.disconnect(s, Callable(self, _SIGNALS[s]))
	_native = obj
	_can_request = false
	_loading = false
	_retry_step = 0
	_retry_timer.stop()
	if obj == null:
		provider = "stub"
		return
	provider = "admob"
	for s in _SIGNALS:
		obj.connect(s, Callable(self, _SIGNALS[s]))
	var store := is_store()
	print("Реклама: AdMob, %s, блок %s" % ["справжні оголошення (збірка для магазину)" if store else "тестові оголошення Google", unit_id()])
	obj.init(not store)


const _SIGNALS := {
	"initialized": "_on_initialized",
	"rewarded_loaded": "_on_loaded",
	"rewarded_failed_to_load": "_on_failed_to_load",
	"rewarded_shown": "_on_shown",
	"rewarded_earned": "_on_earned",
	"rewarded_dismissed": "_on_dismissed",
	"rewarded_failed_to_show": "_on_failed_to_show",
}


## Чи гравцеві треба дати змогу змінити згоду на рекламу (так вимагають правила ЄС і подібні).
func privacy_options_required() -> bool:
	return _native != null and bool(_native.privacyOptionsRequired())


## Відкрити форму Google, де гравець змінює згоду на рекламу.
func show_privacy_options() -> void:
	if _native != null:
		_native.showPrivacyOptions()


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
	if _native != null:
		_show_native()
		return
	_show_provider()


# ================= Справжня реклама (плагін KzAds) =================

func _show_native() -> void:
	if not bool(_native.isRewardedReady()):
		_say(UNAVAILABLE)
		_load(true)
		_finish.call_deferred(false)
		return
	_showing = true
	_earned = false
	# Поки реклама на екрані, гра мовчить і не відповідає на дотики
	_muted_before = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_input_before = get_viewport().gui_disable_input
	get_viewport().gui_disable_input = true
	_show_timer.start(START_TIMEOUT)
	_native.showRewarded()


## Попросити плагін завантажити рекламу. by_player — гравець хотів рекламу, а її нема: вантажити одразу.
func _load(by_player: bool = false) -> void:
	if _native == null or not _can_request or _loading or bool(_native.isRewardedReady()):
		return
	if not by_player and not _retry_timer.is_stopped():
		return
	_retry_timer.stop()
	_loading = true
	load_requests += 1
	_native.loadRewarded(unit_id())


func _on_initialized(can_request_ads) -> void:
	_can_request = bool(can_request_ads)
	print("Реклама: згоду з'ясовано, рекламу %s" % ("можна показувати" if _can_request else "показувати не можна"))
	_load()


func _on_loaded() -> void:
	_loading = false
	_retry_step = 0
	_retry_timer.stop()


func _on_failed_to_load(code, message) -> void:
	_loading = false
	if _retry_step < RETRY_DELAYS.size():
		_retry_timer.start(RETRY_DELAYS[_retry_step])
		_retry_step += 1
		print("Реклама не завантажилась (%s: %s), ще раз через %d с" % [code, message, int(_retry_timer.wait_time)])
	else:
		print("Реклама не завантажилась (%s: %s); далі — лише коли гравець попросить" % [code, message])


func _on_retry() -> void:
	_load()


func _on_shown() -> void:
	if _showing:
		_show_timer.start(SHOW_TIMEOUT)


func _on_earned(_type = "", _amount = 0) -> void:
	if _showing:
		_earned = true


func _on_dismissed() -> void:
	if _showing:
		_end_native(_earned)
		_load()


func _on_failed_to_show(code, message) -> void:
	if not _showing:
		return
	print("Реклама не показалась (%s: %s)" % [code, message])
	_end_native(false)
	_say(UNAVAILABLE)
	_load(true)


func _on_show_timeout() -> void:
	if _showing:
		print("Реклама: плагін не відповів, показ завершено")
		_end_native(_earned)


func _end_native(rewarded: bool) -> void:
	_showing = false
	_show_timer.stop()
	AudioServer.set_bus_mute(0, _muted_before)
	get_viewport().gui_disable_input = _input_before
	_finish(rewarded)


## Коротке повідомлення внизу екрана, саме зникає.
func _say(text: String) -> void:
	last_message = text
	if _toast != null:
		_toast.queue_free()
	_toast = CanvasLayer.new()
	_toast.layer = 60
	add_child(_toast)
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -60
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(16)
	box.add_theme_stylebox_override("panel", st)
	box.add_child(_label(text, 24, Color(1.0, 0.85, 0.3)))
	_toast.add_child(box)
	var layer := _toast
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())


# ================= Заглушка =================

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


## Кінець показу: нагорода (чи ні) іде тому, хто просив рекламу, рівно один раз.
func _finish(rewarded: bool) -> void:
	if not _busy:
		return
	if _layer:
		_layer.queue_free()
		_layer = null
	_busy = false
	if rewarded:
		views += 1
	var cb := _cb
	_cb = Callable()
	ad_finished.emit(_placement, rewarded)
	if cb.is_valid():
		cb.call(rewarded)
