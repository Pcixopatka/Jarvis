#!/usr/bin/env bash
# Збирає APK і кладе його в export/ з версією в кінці назви: kozatska-zvytiaha-0.47.5.apk.
# Версію бере з export_presets.cfg, тож назва файла завжди збігається з тим, що всередині.
# Ключ підпису задається змінними GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER і _PASSWORD.
# Інший Godot можна вказати змінною GODOT. Шлях до готового файла друкується останнім рядком.
# Збірка йде через Gradle (у грі плагін реклами addons/kz_ads), тож потрібні Android SDK і JDK з налаштувань
# редактора Godot (export/android/android_sdk_path, java_sdk_path) і мережа до Google Maven і Maven Central.
# Шаблон збірки android/build (поза git) ставиться сам, якщо його ще нема.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep -m1 '^version/name=' export_presets.cfg | cut -d'"' -f2)
if [ -z "$version" ]; then
	echo "Не знайшов version/name в export_presets.cfg" >&2
	exit 1
fi

out="export/kozatska-zvytiaha-${version}.apk"
mkdir -p export
rm -f "$out"  # щоб невдала збірка не видала старий файл за новий
install=()
if [ ! -f android/build/build.gradle ]; then
	install=(--install-android-build-template)
fi
"${GODOT:-godot}" --headless --path . "${install[@]}" --export-release "Android" "$out"

if [ ! -s "$out" ]; then
	echo "Збірка не дала файла $out" >&2
	exit 1
fi
echo "$out"
