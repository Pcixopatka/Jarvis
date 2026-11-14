@tool
extends EditorExportPlugin
## Плагін реклами для збірки Android (Gradle, схема плагінів Godot v2): AAR з класом KzAdsPlugin
## (зібраний tools/build_ads_plugin.sh з android_plugins/kz_ads), бібліотеки Google з Maven і запис
## APPLICATION_ID у маніфест. Ідентифікатор застосунку — з data/settings.json (запис «admob»), там само,
## звідки його бере гра, тож він записаний один раз.

const AAR := "res://addons/kz_ads/bin/kz_ads.aar"
const SETTINGS := "res://data/settings.json"
## Ті самі версії, що в android_plugins/kz_ads/build.gradle (adsVersion, umpVersion).
const DEPENDENCIES := [
	"com.google.android.gms:play-services-ads:25.5.0",
	"com.google.android.ump:user-messaging-platform:4.0.0",
]


func _get_name() -> String:
	return "KzAds"


## Ресурсів плагін не змінює; метод обов'язковий у EditorExportPlugin.
func _get_customization_configuration_hash() -> int:
	return 0


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([AAR])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(DEPENDENCIES)


func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	var id := app_id()
	if id == "":
		push_error("KzAds: у %s нема admob.app_id — без нього застосунок з рекламою впаде на старті" % SETTINGS)
		return ""
	return "\n\t\t<meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"%s\"/>\n" % id


## Ідентифікатор застосунку AdMob з налаштувань гри; "" — якщо його нема.
static func app_id() -> String:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if not raw is Dictionary or not raw.get("admob") is Dictionary:
		return ""
	return str(raw["admob"].get("app_id", ""))
