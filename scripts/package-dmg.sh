#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
build_dir="$root/build"
mkdir -p "$build_dir"
work_dir=$(mktemp -d "$build_dir/package.XXXXXXXX")
trap 'rm -rf "$work_dir"' EXIT

bash "$root/scripts/build-release.sh"
app="$build_dir/Build/Products/Release/Multi Sound Changer.app"
info="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info")
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info")
[[ "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || { printf 'Invalid app version: %s\n' "$version" >&2; exit 1; }
xcrun lipo "$app/Contents/MacOS/$executable" -verify_arch arm64 x86_64
xcrun lipo "$app/Contents/MacOS/$executable" -archs
codesign --verify --strict "$app"
test -s "$app/Contents/Resources/BuildRevision.txt"

payload="$work_dir/payload"
mkdir "$payload"
ditto "$app" "$payload/$(basename "$app")"
ln -s /Applications "$payload/Applications"

name="MultiSoundChanger-$version-universal.dmg"
hdiutil makehybrid -quiet -hfs -hfs-volume-name 'Multi Sound Changer' \
    -o "$work_dir/payload.dmg" "$payload"
hdiutil convert -quiet "$work_dir/payload.dmg" -format UDZO -o "$work_dir/$name"
hdiutil verify -quiet "$work_dir/$name"
mv -f "$work_dir/$name" "$build_dir/$name"
printf '%s\n' "$build_dir/$name"
