extends Control
## Вікно розмови: портрет, ім'я, текст, що друкується поступово, кнопки «Далі» / «Пропустити» та вибір відповіді.
## Після останньої репліки (і вибору, якщо він є) випромінює finished(choice): -1, якщо вибору не було.

signal finished(choice: int)

const Story := preload("res://scripts/data/story.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const PortraitScript := preload("res://scripts/ui/portrait.gd")

var lines: Array = []
var choices: Array = []
var _i := 0
var _choice := -1
var _portrait
var _name: Label
var _text: Label
var _buttons: HBoxContainer
var _tween: Tween


func setup(p_lines: Array, p_choices: Array) -> void:
	lines = p_lines.duplicate()
	choices = p_choices


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 7
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -270
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.1, 0.08, 0.06, 0.96), Color(0.95, 0.75, 0.2), 16, 16))
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel.add_child(h)
	_portrait = PortraitScript.new()
	_portrait.custom_minimum_size = Vector2(200, 200)
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	_name = UI.label("", 26, UI.GOLD, false)
	v.add_child(_name)
	_text = UI.label("", 24, UI.TEXT, false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 12)
	v.add_child(_buttons)
	if lines.is_empty():
		_finish.call_deferred()
		return
	_show_line()


func _show_line() -> void:
	var line: Array = lines[_i]
	var npc: String = line[0]
	var info: Dictionary = Story.NPCS.get(npc, {"name": npc, "role": ""})
	_portrait.npc = npc
	_portrait.queue_redraw()
	_name.text = info["name"] + (("  •  " + info["role"]) if info["role"] != "" else "")
	_text.text = line[1]
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, clampf(line[1].length() * 0.022, 0.3, 2.5))
	_clear_buttons()
	var last := _i == lines.size() - 1
	if last and not choices.is_empty() and _choice < 0:
		for ci in choices.size():
			_buttons.add_child(UI.button(choices[ci]["text"], _pick.bind(ci), Vector2(0, 60), 20))
	else:
		if not last:
			_buttons.add_child(UI.button("Пропустити", _skip, Vector2(200, 60), 20))
		_buttons.add_child(UI.button("Далі ▸" if not last else "Гаразд", _next, Vector2(200, 60), 22))


func _clear_buttons() -> void:
	for b in _buttons.get_children():
		b.queue_free()


func _next() -> void:
	# Перше натискання дописує текст до кінця, друге — переходить далі
	if _text.visible_ratio < 1.0:
		if _tween:
			_tween.kill()
		_text.visible_ratio = 1.0
		return
	if _i < lines.size() - 1:
		_i += 1
		_show_line()
	else:
		_finish()


func _skip() -> void:
	_i = lines.size() - 1
	_show_line()
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0


func _pick(ci: int) -> void:
	_choice = ci
	var reply: String = choices[ci].get("reply", "")
	if reply == "":
		_finish()
		return
	# Відповідь мовця на вибір — ще одна репліка того, хто говорив останнім
	lines.append([lines[_i][0], reply])
	_i += 1
	_show_line()


func _finish() -> void:
	finished.emit(_choice)
