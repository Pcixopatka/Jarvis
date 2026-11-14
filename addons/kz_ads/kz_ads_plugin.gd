@tool
extends EditorPlugin
## Вмикає експорт плагіна реклами (kz_ads_export.gd). Працює лише в редакторі й під час експорту.

const ExportPlugin := preload("res://addons/kz_ads/kz_ads_export.gd")

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = ExportPlugin.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
		_export = null
