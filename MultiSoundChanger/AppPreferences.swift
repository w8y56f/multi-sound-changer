import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system = "System"
    case english = "English"
    case chinese = "中文"

    static func preferredLanguage(in identifiers: [String]) -> AppLanguage {
        for identifier in identifiers {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "zh": return .chinese
            case "en": return .english
            default: continue
            }
        }
        return .english
    }
}

enum VolumeFeedbackPosition: String, CaseIterable {
    case center, lowerCenter, bottom

    var label: String {
        switch self {
        case .center: "Center"
        case .lowerCenter: "Lower Center"
        case .bottom: "Bottom"
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
            applyAppearance()
        }
    }

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    @Published var volumeFeedbackPosition: VolumeFeedbackPosition {
        didSet { UserDefaults.standard.set(volumeFeedbackPosition.rawValue, forKey: "volumeFeedbackPosition") }
    }

    private init() {
        let defaults = UserDefaults.standard
        appearance = defaults.string(forKey: "appAppearance").flatMap(AppAppearance.init(rawValue:)) ?? .system
        language = defaults.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .system
        volumeFeedbackPosition = defaults.string(forKey: "volumeFeedbackPosition")
            .flatMap(VolumeFeedbackPosition.init(rawValue:)) ?? .lowerCenter
    }

    func applyAppearance() {
        NSApp.appearance = appearance.appearance
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let effectiveLanguage = language == .system ? AppLanguage.preferredLanguage(in: Locale.preferredLanguages) : language
        let value = effectiveLanguage == .chinese ? Self.chinese[key] ?? key : key
        return arguments.isEmpty ? value : String(format: value, arguments: arguments)
    }

    private static let chinese = [
        "Settings": "设置",
        "General": "通用",
        "About": "关于",
        "Audio MIDI Setup…": "音频 MIDI 设置…",
        "Sound Settings…": "声音设置…",
        "Show or Hide System Sound Icon…": "显示或隐藏系统音量图标…",
        "Exit": "退出",
        "Settings…": "设置…",
        "Copy Device Name": "复制设备名称",
        "Copy device name: %@": "复制设备名称：%@",
        "Copied": "已复制",
        "Appearance": "外观",
        "Language": "语言",
        "System": "跟随系统",
        "Light": "浅色",
        "Dark": "深色",
        "Quit Multi Sound Changer": "退出 Multi Sound Changer",
        "Quit Multi Sound Changer?": "退出 Multi Sound Changer？",
        "Quit": "退出",
        "Cancel": "取消",
        "Input": "输入",
        "Output": "输出",
        "No input devices": "没有输入设备",
        "No output devices": "没有输出设备",
        "Output Members": "输出成员",
        "Output Volume": "输出音量",
        "No connected output members": "没有已连接的输出成员",
        "Recording · Protected": "录音 · 受保护",
        "Volume unavailable": "音量不可调",
        "Volume for %@": "%@ 的音量",
        "Built-in": "内置",
        "Bluetooth": "蓝牙",
        "Virtual": "虚拟",
        "Aggregate": "聚合",
        "Device": "设备",
        "Open at Login": "登录时打开",
        "Allow Multi Sound Changer in Login Items to finish setup.": "请在系统的登录项中允许 Multi Sound Changer，以完成设置。",
        "Open Login Items Settings": "打开登录项设置",
        "Version %@ (%@)": "版本 %@（%@）",
        "Powered by Stone Wang": "由 Stone Wang 开发",
        "Volume Shortcuts": "音量快捷键",
        "Shortcut Group %d": "第 %d 组快捷键",
        "Increase Volume": "提高音量",
        "Decrease Volume": "降低音量",
        "Press shortcut…": "请按下快捷键…",
        "Not Set": "未设置",
        "Clear shortcut": "清除快捷键",
        "Clear %@ shortcut": "清除「%@」快捷键",
        "Step: %d percentage points": "步长：%d 个百分点",
        "Show volume feedback": "显示音量提示",
        "Feedback Position": "提示位置",
        "Center": "屏幕中央",
        "Lower Center": "中央偏下",
        "Bottom": "屏幕底部",
        "Follows the current output. Skips BlackHole and unsupported devices. Keeps volume differences; stops the whole group at either limit.": "跟随当前输出，跳过 BlackHole 和音量不可调的设备。保留设备之间的音量差，任一设备到达上限或下限时，整组停止向该方向调整。",
        "Press Escape to cancel. Include Command, Control or Option.": "按 Esc 取消。组合键须包含 Command、Control 或 Option。",
        "Couldn’t initialize global shortcuts (%d).": "无法初始化全局快捷键（%d）。",
        "Global shortcuts are unavailable. Restart the app to retry.": "全局快捷键不可用，请重启应用后重试。",
        "This shortcut is already assigned to another volume binding.": "这组按键已绑定到另一个音量快捷键。",
        "Shortcut unavailable or already in use (%d). Choose another combination.": "快捷键不可用或已被占用（%d），请选择其他组合。",
        "Include Command, Control or Option in the shortcut.": "快捷键须包含 Command、Control 或 Option。",
        "Volume": "音量",
        "No current output device.": "当前没有输出设备。",
        "Current output does not support volume adjustment.": "当前输出不支持音量调节。",
        "Some devices couldn’t be adjusted. Showing current levels.": "部分设备调节失败，已显示当前音量。",
        "Linked upper limit reached.": "已达联动上限。",
        "Linked lower limit reached.": "已达联动下限。",
        "Some devices do not support volume adjustment.": "部分设备不支持音量调节。",
        "Unavailable": "不可用",
        "Couldn’t switch input": "无法切换输入设备",
        "Couldn’t switch output": "无法切换输出设备",
        "Couldn’t change volume": "无法调整音量",
        "Some devices couldn’t be adjusted": "部分设备调节失败"
    ]
}
