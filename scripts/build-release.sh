#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
xcodebuild -quiet \
    -project "$root/MultiSoundChanger.xcodeproj" \
    -scheme MultiSoundChanger -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$root/build" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
