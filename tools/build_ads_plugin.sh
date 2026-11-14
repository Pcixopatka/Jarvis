#!/usr/bin/env bash
# Збирає рідну частину плагіна реклами (android_plugins/kz_ads, Java) в AAR і кладе його в addons/kz_ads/bin/.
# Готовий AAR лежить у репозиторії, тож для збірки гри цей скрипт запускати не треба: лише коли змінено Java-код
# або версії SDK у android_plugins/kz_ads/build.gradle (тоді й DEPENDENCIES у addons/kz_ads/kz_ads_export.gd).
#
# Потрібні JDK 17+ і Android SDK (платформа 36, build-tools 36.1.0). Шляхи беруться зі змінних JAVA_HOME і
# ANDROID_HOME, а як їх нема — з налаштувань редактора Godot (export/android/java_sdk_path, android_sdk_path).
# Gradle 8.11.1 завантажує обгортка gradlew; бібліотеки — з Google Maven і Maven Central.
# Проміжні файли Gradle лишаються в android_plugins/kz_ads/build і .gradle (поза git).
# Шлях до готового AAR друкується останнім рядком.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(pwd)
proj="$root/android_plugins/kz_ads"
out_dir="$root/addons/kz_ads/bin"
out="$out_dir/kz_ads.aar"

# Значення з налаштувань редактора Godot (найновіший файл editor_settings-4*.tres)
editor_setting() {
	local f
	f=$(ls -t "${XDG_CONFIG_HOME:-$HOME/.config}"/godot/editor_settings-4*.tres 2>/dev/null | head -1 || true)
	[ -n "$f" ] && grep -m1 "^export/android/$1 = " "$f" | cut -d'"' -f2 || true
}

if [ -z "${JAVA_HOME:-}" ]; then
	JAVA_HOME=$(editor_setting java_sdk_path)
fi
if [ -z "${ANDROID_HOME:-}" ]; then
	ANDROID_HOME=${ANDROID_SDK_ROOT:-$(editor_setting android_sdk_path)}
fi
if [ -z "$JAVA_HOME" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
	echo "Не знайшов JDK: задай JAVA_HOME" >&2
	exit 1
fi
if [ -z "$ANDROID_HOME" ] || [ ! -d "$ANDROID_HOME/platforms" ]; then
	echo "Не знайшов Android SDK: задай ANDROID_HOME" >&2
	exit 1
fi
export JAVA_HOME ANDROID_HOME

cd "$proj"
sh ./gradlew --no-daemon -q assembleRelease
built="$proj/build/outputs/aar/kz_ads-release.aar"
if [ ! -s "$built" ]; then
	echo "Збірка не дала файла $built" >&2
	exit 1
fi
mkdir -p "$out_dir"
cp "$built" "$out"
echo "$out"
