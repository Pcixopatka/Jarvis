extends SceneTree
## Вивантажує довідник гри (WikiService) у docs/wiki.md, щоб його можна було читати й поза грою.
## Запуск: godot --headless --path . -s res://tools/wiki_export.gd
func _initialize() -> void:
	load("res://scripts/game/holiday_service.gd").forced = "none"
	var md: String = load("res://scripts/game/wiki_service.gd").to_markdown()
	var f := FileAccess.open("res://docs/wiki.md", FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("docs/wiki.md: %d рядків" % md.split("\n").size())
	quit()
