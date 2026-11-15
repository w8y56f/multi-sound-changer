# Multi Sound Changer

[简体中文](README.md)

Multi Sound Changer is a macOS menu bar app for switching the default microphone and speakers and adjusting each supported member of a Multi-Output Device independently.

## Run

Requires macOS 13 or later and Xcode. Open `MultiSoundChanger.xcodeproj`, select the `MultiSoundChanger` scheme, and press **⌘R**. Click the speaker icon in the menu bar.

## Use

- Choose the macOS default devices under **Output** and **Input**.
- To record through BlackHole, create a Multi-Output Device with BlackHole and your speakers in **Audio MIDI Setup**, then select it under **Output**.
- Adjust your speakers under **Output Members**. Each speaker with a writable volume control gets its own slider. BlackHole is marked **Recording · Protected**, and the app leaves its volume alone. Devices without a writable volume control show **Volume unavailable**.
- Click the gear in the menu bar panel and use **Settings → General** to configure launch at login. Move the app to **Applications** before enabling **Open at Login**.
- Click **About** in the menu bar panel or open **Settings → About** to see the version and build-time Git commit ID. Uncommitted changes add a `-dirty` suffix.

To check your setup in OBS, play a steady audio source and watch the BlackHole meter while moving the speaker slider.

Current version **0.1.0**. Powered by Stone Wang.

## Package

Run `bash scripts/package-dmg.sh` from the project root. It creates `build/MultiSoundChanger-<version>-universal.dmg` with Apple Silicon and Intel slices.

From the project root, run `bash scripts/build-release.sh` to build Release, then run `open "build/Build/Products/Release/Multi Sound Changer.app"`. DMG packaging uses the same Release app.

In **Settings → General**, choose **Appearance** (System, Light, Dark, default System) and **Language** (English or 中文, default English). Both preferences apply immediately and persist across launches.

## Volume shortcuts

Open **Settings → General → Volume Shortcuts** to record Increase Volume / Decrease Volume. Both start as Not Set. Include Command, Control or Option; Escape cancels and × clears. Bindings persist and registration conflicts are reported. Step defaults to 5 percentage points (range 1–20).

Shortcuts follow the current default output and adjust its writable members, skipping BlackHole and unsupported devices. Every participating device receives the same delta; the entire group stops when any member reaches either boundary. For example, 50% / 30% becomes 55% / 35%, with an upper limit of 100% / 80%. Manual slider edits establish a new balance. Levels belong to physical devices and are not reset when switching groups.

Optional feedback displays each device's actual level near the bottom of the pointer's screen for 1.2 seconds without taking focus. Configure BetterAndBetter to send the same shortcuts; synthetic-key compatibility needs local testing. The app must remain running. Failed group writes trigger best-effort rollback and display freshly read levels.

Boundary tests: `swiftc -module-cache-path /tmp/msc-module-cache MultiSoundChanger/LinkedVolume.swift Tests/LinkedVolumeTests.swift -o /tmp/msc-tests && /tmp/msc-tests`.
