import AppKit
import Carbon
import SwiftUI

struct VolumeShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var label: String {
        [(UInt32(controlKey), "⌃"), (UInt32(optionKey), "⌥"),
         (UInt32(shiftKey), "⇧"), (UInt32(cmdKey), "⌘")]
            .filter { modifiers & $0.0 != 0 }.map(\.1).joined() + keyLabel
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags
        // Require Command, Control or Option so ordinary typing is never intercepted.
        guard !flags.intersection([.command, .control, .option]).isEmpty else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0)
            | (flags.contains(.control) ? UInt32(controlKey) : 0)
            | (flags.contains(.option) ? UInt32(optionKey) : 0)
            | (flags.contains(.shift) ? UInt32(shiftKey) : 0)
        let names: [UInt16: String] = [123: "←", 124: "→", 125: "↓", 126: "↑", 49: "Space",
            36: "Return", 48: "Tab", 51: "Delete", 117: "Forward Delete", 115: "Home", 119: "End",
            116: "Page Up", 121: "Page Down", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        keyLabel = names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
    }

    func matches(_ other: VolumeShortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}

enum VolumeAction: UInt32, CaseIterable {
    case increase = 1, decrease = 2
    var title: String { self == .increase ? "Increase Volume" : "Decrease Volume" }
    var defaultsKey: String { "volumeShortcut.\(rawValue)" }
}

@MainActor
final class VolumeShortcutController: ObservableObject {
    static let shared = VolumeShortcutController()
    let audio = AudioPanelModel()
    @Published private(set) var shortcuts: [VolumeAction: VolumeShortcut] = [:]
    @Published private(set) var recording: VolumeAction?
    @Published private(set) var error: String?
    @Published private(set) var errorStatus: OSStatus?
    @Published var step: Int {
        didSet { UserDefaults.standard.set(step, forKey: "volumeStep") }
    }
    @Published var showFeedback: Bool {
        didSet {
            UserDefaults.standard.set(showFeedback, forKey: "showVolumeFeedback")
            if !showFeedback { VolumeFeedbackWindow.shared.hide() }
        }
    }
    private var hotKeys: [VolumeAction: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var monitor: Any?
    private let signature: OSType = 0x4D534356 // MSCV

    private init() {
        let savedStep = UserDefaults.standard.integer(forKey: "volumeStep")
        step = (1...20).contains(savedStep) ? savedStep : 5
        showFeedback = UserDefaults.standard.object(forKey: "showVolumeFeedback") as? Bool ?? true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                          nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x4D534356,
                  let action = VolumeAction(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<VolumeShortcutController>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { controller.trigger(action) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            errorStatus = status
            error = "Couldn’t initialize global shortcuts (%d)."
            return
        }
        for action in VolumeAction.allCases {
            if let data = UserDefaults.standard.data(forKey: action.defaultsKey),
               let shortcut = try? JSONDecoder().decode(VolumeShortcut.self, from: data) {
                _ = assign(shortcut, to: action)
            }
        }
    }

    @discardableResult
    func assign(_ shortcut: VolumeShortcut?, to action: VolumeAction) -> Bool {
        error = nil
        errorStatus = nil
        guard handler != nil else {
            error = "Global shortcuts are unavailable. Restart the app to retry."
            return false
        }
        if let shortcut {
            if shortcuts.contains(where: { $0.key != action && $0.value.matches(shortcut) }) {
                error = "Increase and decrease must use different shortcuts."
                return false
            }
            if let existing = shortcuts[action], existing.matches(shortcut) { return true }
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                             EventHotKeyID(signature: signature, id: action.rawValue),
                                             GetApplicationEventTarget(), 0, &reference)
            guard status == noErr, let reference else {
                errorStatus = status
                error = "Shortcut unavailable or already in use (%d). Choose another combination."
                return false
            }
            if let old = hotKeys[action] { UnregisterEventHotKey(old) }
            hotKeys[action] = reference
            shortcuts[action] = shortcut
            UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: action.defaultsKey)
        } else {
            if let old = hotKeys.removeValue(forKey: action) { UnregisterEventHotKey(old) }
            shortcuts.removeValue(forKey: action)
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
        return true
    }

    func beginRecording(_ action: VolumeAction) {
        cancelRecording()
        error = nil
        errorStatus = nil
        recording = action
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self, let action = self.recording else { return false }
                if event.keyCode == 53 { self.cancelRecording(); return true }
                guard let shortcut = VolumeShortcut(event: event) else {
                    self.error = "Include Command, Control or Option in the shortcut."
                    return true
                }
                if self.assign(shortcut, to: action) { self.cancelRecording() }
                return true
            }
            return consumed ? nil : event
        }
    }

    func cancelRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
    }

    private func trigger(_ action: VolumeAction) {
        if let recording {
            // Already registered shortcuts arrive as Carbon events, not local keyDown events.
            if let shortcut = shortcuts[action], assign(shortcut, to: recording) { cancelRecording() }
            return
        }
        let feedback = audio.adjustLinkedVolume(by: Double(step) / 100 * (action == .increase ? 1 : -1))
        if showFeedback { VolumeFeedbackWindow.shared.show(feedback) }
    }
}

struct VolumeShortcutSettings: View {
    @ObservedObject private var preferences = AppPreferences.shared
    @ObservedObject private var controller = VolumeShortcutController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preferences.text("Volume Shortcuts")).font(.headline)
            ForEach(VolumeAction.allCases, id: \.rawValue) { action in
                HStack {
                    Text(preferences.text(action.title))
                    Spacer()
                    Button(controller.recording == action ? preferences.text("Press shortcut…") : controller.shortcuts[action]?.label ?? preferences.text("Not Set")) {
                        controller.beginRecording(action)
                    }.frame(minWidth: 140)
                    Button {
                        controller.cancelRecording()
                        controller.assign(nil, to: action)
                    } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .disabled(controller.shortcuts[action] == nil && controller.recording != action)
                        .help(preferences.text("Clear shortcut"))
                        .accessibilityLabel(preferences.text("Clear %@ shortcut", preferences.text(action.title)))
                }
            }
            Stepper(preferences.text("Step: %d percentage points", controller.step), value: $controller.step, in: 1...20)
            Toggle(preferences.text("Show volume feedback"), isOn: $controller.showFeedback)
            Text(preferences.text("Follows the current output. Skips BlackHole and unsupported devices. Keeps volume differences; stops the whole group at either limit."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if controller.recording != nil {
                Text(preferences.text("Press Escape to cancel. Include Command, Control or Option."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = controller.error {
                Text(controller.errorStatus.map { preferences.text(error, $0) } ?? preferences.text(error)).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear { controller.cancelRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            controller.cancelRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            controller.cancelRecording()
        }
    }
}
