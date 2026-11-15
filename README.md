# Multi Sound Changer

[English](README.en.md)

Multi Sound Changer 是一款 macOS 菜单栏工具。它可以切换系统默认麦克风和扬声器，也可以独立调节 Multi-Output Device 中各个支持音量控制的输出设备。

## 运行

需要 macOS 13 或更高版本，以及 Xcode。打开 `MultiSoundChanger.xcodeproj`，选择 `MultiSoundChanger` scheme，按 **⌘R**。启动后点击菜单栏里的扬声器图标。

## 使用

- 在 **Output** 和 **Input** 中切换 macOS 的默认设备。
- 使用 BlackHole 录音时，先在 **Audio MIDI Setup** 创建包含 BlackHole 和扬声器的 Multi-Output Device，然后在 **Output** 选中它。
- 在 **Output Members** 下拖动扬声器的滑块。支持音量控制的扬声器各有一条滑块。BlackHole 标为 **Recording · Protected**，应用不会修改它的音量。没有可写音量控制的设备显示 **Volume unavailable**。
- 点菜单栏面板的齿轮，在 **Settings → General** 设置登录时启动。安装时先把应用放到 **Applications**，再启用 **Open at Login**。
- 从面板点 **About**，或打开 **Settings → About**，查看版本和构建时的 Git 提交 ID。未提交的改动会加上 `-dirty`。

使用 OBS 时，可以播放一段固定音频，拖动扬声器滑块，同时观察 OBS 中 BlackHole 的电平。

当前版本 **0.1.0**。Powered by Stone Wang.

## 打包

在项目目录运行 `bash scripts/package-dmg.sh`。脚本生成 `build/MultiSoundChanger-<版本>-universal.dmg`，包含 Apple Silicon 和 Intel 两种架构。

在项目根目录运行 `bash scripts/build-release.sh` 构建 Release，之后用 `open "build/Build/Products/Release/Multi Sound Changer.app"` 启动。DMG 打包也使用同一份 Release 应用。

在 **Settings → General** 可选 **Appearance**（System、Light、Dark，默认 System）和 **Language**（English、中文，默认 English）。设置即时生效，并在重启后保留。

## 音量快捷键

在 **Settings → General → Volume Shortcuts** 设置 Increase Volume / Decrease Volume；默认均为 Not Set。点击录入组合键（含 Command、Control 或 Option），Esc 取消，× 清除。绑定会保存；注册冲突会提示。Step 默认 5 个百分点，可设为 1–20。

快捷键跟随当前默认输出。Multi-Output 中仅调整支持调节的成员，跳过 BlackHole 和不可调设备；每个成员同幅增减，任一个成员到达 100% / 0% 时整组停止。例如 50% / 30% → 55% / 35%，上限为 100% / 80%。手动调整单个滑块后，以新的实际音量差继续联动。音量属于设备自身，切换组合不会重置。

屏幕底部显示各成员的实际音量，约 1.2 秒后消失，不抢焦点；可关闭 Show volume feedback。BetterAndBetter 可配置为发送相同组合键，需在本机验证合成按键兼容性。应用必须保持运行。设备写入失败时尝试恢复已调整成员，并显示实际读取的音量。

边界计算测试：`swiftc -module-cache-path /tmp/msc-module-cache MultiSoundChanger/LinkedVolume.swift Tests/LinkedVolumeTests.swift -o /tmp/msc-tests && /tmp/msc-tests`。
