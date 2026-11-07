#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
output_dir="$project_dir/temp/outputs"
app="$output_dir/TashAir.app"
build_options=(-c release)
widget_options=(ONLY_ACTIVE_ARCH=NO)
if [[ "${TASHAIR_UNIVERSAL:-0}" == 1 ]]; then
    build_options+=(--arch arm64 --arch x86_64)
    widget_options+=("ARCHS=arm64 x86_64")
else
    widget_options+=("ARCHS=$(uname -m)")
fi
bash scripts/swift.sh build --product TashAir "${build_options[@]}"
binary_dir="$(bash scripts/swift.sh build "${build_options[@]}" --show-bin-path)"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/PlugIns"
cp "$binary_dir/TashAir" "$app/Contents/MacOS/TashAir"
cp packaging/AppInfo.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp docs/DATA_SOURCES.md "$app/Contents/Resources/DATA_SOURCES.md"
xcrun swift -module-cache-path temp/module-cache scripts/draw-icon.swift temp/icon.iconset
iconutil -c icns temp/icon.iconset -o "$app/Contents/Resources/TashAir.icns"
xcodebuild -quiet -project packaging/TashAirWidgets.xcodeproj -scheme TashAirWidgets \
    -configuration Release -destination 'generic/platform=macOS' -derivedDataPath temp/widget-build \
    CODE_SIGNING_ALLOWED=NO "${widget_options[@]}" build
ditto temp/widget-build/Build/Products/Release/TashAirWidgets.appex "$app/Contents/PlugIns/TashAirWidgets.appex"
if [[ -n "${TASHAIR_SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --entitlements packaging/Widget.entitlements --sign "$TASHAIR_SIGN_IDENTITY" "$app/Contents/PlugIns/TashAirWidgets.appex"
    codesign --force --options runtime --timestamp --sign "$TASHAIR_SIGN_IDENTITY" "$app"
else
    codesign --force --entitlements packaging/Widget.entitlements --sign - "$app/Contents/PlugIns/TashAirWidgets.appex"
    codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$output_dir/TashAir-macOS.zip"
echo "$app"
