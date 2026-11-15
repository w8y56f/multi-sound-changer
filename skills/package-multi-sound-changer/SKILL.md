---
name: package-multi-sound-changer
description: Build and verify the Multi Sound Changer universal macOS DMG. Use when asked to package this project, create a DMG, or 打包.
---

# Package Multi Sound Changer

1. From the project root, run `git status --short --untracked-files=normal` before packaging. If status is clean, proceed. If Git status cannot be read, report that the preflight check failed and ask whether to package the current files anyway.
2. If there are staged, unstaged, or untracked changes, summarize them and ask whether to **commit and push the intended changes before packaging** or **package the current working tree directly**. Wait for the answer unless the request already makes that choice. If the user authorized only one of commit or push, ask before performing the other.
3. If the user chooses commit and push, review the changes, commit only the intended files, and verify the push to the configured remote branch before building. If the push fails, report it and ask before proceeding with a local-only build. If the user chooses to package directly, leave the Git state as is and note that the build revision may show `-dirty`.
4. Run `bash scripts/package-dmg.sh`. The script reads the app version and writes `build/MultiSoundChanger-<version>-universal.dmg`. It checks the app signature, the `arm64` and `x86_64` slices, and the DMG checksum before replacing any existing output for that version.
5. Report the DMG path and actual verification results. Running on Intel requires an Intel Mac. The local build uses ad hoc signing.
