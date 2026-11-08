extends SceneTree
## Завантажує кожен скрипт проєкту (з автозавантаженнями) і повідомляє про помилки компіляції.
## Запуск: godot --headless --path . -s res://tests/check_scripts.gd


func _initialize() -> void:
	var failed := 0
	var files := _collect("res://scripts")
	for f in files:
		var s = load(f)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			failed += 1
			printerr("ПОМИЛКА: ", f)
	print("Перевірено скриптів: %d, з помилками: %d" % [files.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_collect(dir + "/" + d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	return out
