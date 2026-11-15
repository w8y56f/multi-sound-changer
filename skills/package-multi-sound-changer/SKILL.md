---
name: package-multi-sound-changer
description: Build and verify the Multi Sound Changer universal macOS DMG. Use when asked to package this project, create a DMG, or 打包.
---

# Package Multi Sound Changer

1. From the project root, run `bash scripts/package-dmg.sh`.
2. Report the DMG path printed by the script. The script reads the marketing version from the built app and writes `build/MultiSoundChanger-<version>-universal.dmg`.
3. Build both `arm64` and `x86_64`. The script checks the app signature, both architectures, and the DMG checksum before replacing any existing output for that version.
4. Report actual verification results. A universal binary check confirms both slices are present. Running on Intel requires an Intel Mac. The local build uses ad hoc signing.
