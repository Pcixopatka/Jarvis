extends Control
## Нерухоме тло мініігри. Малюється один раз (і ще раз, коли змінився розмір), а не щокадру:
## сотні плиток трави чи води не мають перемальовуватись заради одного звіра, що біжить.
## painter — функція, яка малює тло на переданому полотні: func(canvas: Control) -> void.

var painter: Callable


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true  # тло лежить під рухомими малюнками батьківського вузла


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
