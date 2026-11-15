import AppKit
import ServiceManagement
import SwiftUI

@main
struct MultiSoundChangerApp: App {
    @NSApplicationDelegateAdaptor(ShortcutAppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            AudioPanel()
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("Multi Sound Changer")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class ShortcutAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.shared.applyAppearance()
        _ = VolumeShortcutController.shared
    }
}

@MainActor
private enum MenuBarIcon {
    static let image: NSImage = {
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let silhouette = CGMutablePath()
            silhouette.addRoundedRect(in: CGRect(x: 0.5, y: 0.5, width: 17, height: 17),
                                      cornerWidth: 4, cornerHeight: 4)

            // Enlarge the symbol as a unit, centered within the unchanged badge.
            let symbolTransform = CGAffineTransform(translationX: 9.1, y: 9)
                .scaledBy(x: 1.19, y: 1.19)
                .translatedBy(x: -9.4, y: -9)

            // The speaker and waves are transparent. The M restores the fill inside the speaker.
            let speaker = CGMutablePath()
            speaker.move(to: CGPoint(x: 3.5, y: 7))
            speaker.addLine(to: CGPoint(x: 5.4, y: 7))
            speaker.addLine(to: CGPoint(x: 9.6, y: 4.4))
            speaker.addQuadCurve(to: CGPoint(x: 10.5, y: 4.9), control: CGPoint(x: 10.5, y: 3.9))
            speaker.addLine(to: CGPoint(x: 10.5, y: 13.1))
            speaker.addQuadCurve(to: CGPoint(x: 9.6, y: 13.6), control: CGPoint(x: 10.5, y: 14.1))
            speaker.addLine(to: CGPoint(x: 5.4, y: 11))
            speaker.addLine(to: CGPoint(x: 3.5, y: 11))
            speaker.addQuadCurve(to: CGPoint(x: 3, y: 10.5), control: CGPoint(x: 3, y: 11))
            speaker.addLine(to: CGPoint(x: 3, y: 7.5))
            speaker.addQuadCurve(to: CGPoint(x: 3.5, y: 7), control: CGPoint(x: 3, y: 7))
            speaker.closeSubpath()
            silhouette.addPath(speaker, transform: symbolTransform)

            let waves = CGMutablePath()
            waves.move(to: CGPoint(x: 11.8, y: 6.8))
            waves.addQuadCurve(to: CGPoint(x: 11.8, y: 11.2), control: CGPoint(x: 13.9, y: 9))
            waves.move(to: CGPoint(x: 13.3, y: 5.2))
            waves.addQuadCurve(to: CGPoint(x: 13.3, y: 12.8), control: CGPoint(x: 17.3, y: 9))
            silhouette.addPath(waves.copy(strokingWithWidth: 1, lineCap: .round,
                                          lineJoin: .round, miterLimit: 1),
                               transform: symbolTransform)

            let letter = CGMutablePath()
            letter.addLines(between: [
                CGPoint(x: 5.5, y: 7.4), CGPoint(x: 6.45, y: 7.4),
                CGPoint(x: 7.5, y: 8.65), CGPoint(x: 8.55, y: 7.4),
                CGPoint(x: 9.5, y: 7.4), CGPoint(x: 9.5, y: 10.6),
                CGPoint(x: 8.55, y: 10.6), CGPoint(x: 8.55, y: 8.95),
                CGPoint(x: 7.5, y: 10.15), CGPoint(x: 6.45, y: 8.95),
                CGPoint(x: 6.45, y: 10.6), CGPoint(x: 5.5, y: 10.6)
            ])
            letter.closeSubpath()
            silhouette.addPath(letter, transform: symbolTransform)

            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.addPath(silhouette)
            context.fillPath(using: .evenOdd)
            return true
        }
        icon.isTemplate = true
        return icon
    }()
}

private struct AudioPanel: View {
    @ObservedObject private var preferences = AppPreferences.shared
    @ObservedObject private var model = VolumeShortcutController.shared.audio
    private let updates = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Multi Sound Changer")
                        .font(.headline)
                    Text(AppVersion.number)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    SettingsWindow.shared.show()
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PanelButtonStyle())
                .help(preferences.text("Settings"))
                .accessibilityLabel(preferences.text("Settings"))
                Button {
                    confirmQuit()
                } label: {
                    Image(systemName: "power")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PanelButtonStyle())
                .help(preferences.text("Quit Multi Sound Changer"))
                .accessibilityLabel(preferences.text("Quit Multi Sound Changer"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 15) {
                deviceList(.output, devices: model.outputs)
                if let output = model.currentOutput {
                    Divider()
                    outputVolume(output)
                }
                Divider()
                deviceList(.input, devices: model.inputs)
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)

            Divider()
            VStack(spacing: 0) {
                footerButton("Audio MIDI Setup…") {
                    let workspace = NSWorkspace.shared
                    let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.audio.AudioMIDISetup")
                        ?? URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")
                    workspace.open(url)
                }
                footerButton("Sound Settings…") {
                    let workspace = NSWorkspace.shared
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension"),
                       workspace.open(url) {
                        return
                    }
                    if let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                        workspace.open(legacyURL)
                    }
                }
                footerButton("Show or Hide System Sound Icon…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                footerButton("Exit", action: confirmQuit)
                footerButton("Settings…") {
                    SettingsWindow.shared.show()
                }
                footerButton("About") {
                    SettingsWindow.shared.show(.about)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refresh() }
        .onReceive(updates) { _ in model.refresh() }
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(preferences.text(title))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(PanelButtonStyle())
    }

    private func confirmQuit() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = preferences.text("Quit Multi Sound Changer?")
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: preferences.text("Quit"))
        let cancel = alert.addButton(withTitle: preferences.text("Cancel"))
        alert.buttons[0].keyEquivalent = ""
        cancel.keyEquivalent = "\u{1b}"
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    private func deviceList(_ direction: AudioDirection, devices: [AudioDevice]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(preferences.text(direction.label))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 3)

            if devices.isEmpty {
                Text(preferences.text(direction == .input ? "No input devices" : "No output devices"))
                    .foregroundStyle(.secondary)
            }

            ForEach(devices) { device in
                let selected = model.isSelected(device, direction: direction)
                DeviceRow(
                    name: device.name,
                    iconURL: device.iconURL,
                    symbolName: device.symbolName(for: direction),
                    direction: direction,
                    connection: disambiguation(for: device, in: devices),
                    selected: selected
                ) {
                    if !selected {
                        model.select(device, direction: direction)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func outputVolume(_ output: AudioDevice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preferences.text(output.isAggregate ? "Output Members" : "Output Volume"))
                .font(output.isAggregate ? .headline : .subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if model.volumeDevices.isEmpty {
                Text(preferences.text("No connected output members"))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(model.volumeDevices.enumerated()), id: \.element.id) { index, device in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        if output.isAggregate {
                            Text("\(index + 1).")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .accessibilityHidden(true)
                        }
                        Text(memberName(device))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if let value = model.volumes[device.id] {
                            Text(value, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else {
                            Text(preferences.text(device.isBlackHole ? "Recording · Protected" : "Volume unavailable"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)

                    if model.volumes[device.id] != nil {
                        Slider(value: Binding(
                            get: { model.volumes[device.id] ?? 0 },
                            set: { model.setVolume($0, of: device) }
                        ), in: 0...1) {
                            Text(preferences.text("Volume for %@", memberName(device)))
                        }
                        .labelsHidden()
                    }
                }
                .padding(.leading, output.isAggregate ? 10 : 0)
            }
        }
    }

    private func memberName(_ device: AudioDevice) -> String {
        guard model.volumeDevices.filter({ $0.name == device.name }).count > 1 else { return device.name }
        return "\(device.name) · \(disambiguation(for: device, in: model.volumeDevices))"
    }

    private func disambiguation(for device: AudioDevice, in devices: [AudioDevice]) -> String {
        let sameName = devices.filter { $0.name == device.name && $0.connection == device.connection }
        let connection = preferences.text(device.connection)
        guard sameName.count > 1 else { return connection }
        return "\(connection) · \(device.id)"
    }
}

private struct DeviceRow: View {
    @ObservedObject private var preferences = AppPreferences.shared
    @State private var isHovered = false
    @State private var copied = false
    @State private var copyFeedback: Task<Void, Never>?
    @FocusState private var selectionFocused: Bool
    @FocusState private var copyFocused: Bool

    let name: String
    let iconURL: URL?
    let symbolName: String?
    let direction: AudioDirection
    let connection: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            selectionButton
            copyButton
        }
        .padding(.trailing, 4)
        .onHover { isHovered = $0 }
        .onDisappear {
            copyFeedback?.cancel()
            copied = false
        }
    }

    private var selectionButton: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.accentColor)
                    .opacity(selected ? 1 : 0)
                    .frame(width: 14)
                    .accessibilityHidden(true)
                deviceIcon
                    .frame(width: 16, height: 16)
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(selected ? Color.accentColor : Color.primary.opacity(0.08))
                    }
                    .accessibilityHidden(true)
                Text(name)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(copied ? preferences.text("Copied") : connection)
                    .font(.caption)
                    .foregroundStyle(copied ? Color.accentColor : Color.secondary)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(PanelButtonStyle())
        .focused($selectionFocused)
        .help(name)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var copyButton: some View {
        Button(action: copyName) {
            Image(systemName: copied ? "checkmark" : "square.on.square")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(copied ? Color.accentColor : Color.secondary)
                .opacity(isHovered || selectionFocused || copyFocused || copied ? 1 : 0)
                .frame(width: 24, height: 26)
        }
        .buttonStyle(PanelButtonStyle())
        .focused($copyFocused)
        .help(preferences.text("Copy Device Name"))
        .accessibilityLabel(preferences.text("Copy device name: %@", name))
    }

    private func copyName() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(name, forType: .string) else { return }

        copied = true
        copyFeedback?.cancel()
        copyFeedback = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            copied = false
        }
    }

    @ViewBuilder
    private var deviceIcon: some View {
        if let symbolName {
            symbolIcon(symbolName)
        } else if let iconURL, iconURL.isFileURL, let image = NSImage(contentsOf: iconURL), image.isValid {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            symbolIcon(direction == .input ? "mic.fill" : "speaker.wave.2.fill")
        }
    }

    private func symbolIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? Color.white : Color.secondary)
    }
}

private struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverLabel(label: configuration.label, isPressed: configuration.isPressed)
    }

    private struct HoverLabel: View {
        let label: Configuration.Label
        let isPressed: Bool
        @State private var hovered = false

        var body: some View {
            label
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(isPressed ? 0.15 : hovered ? 0.09 : 0))
                }
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
        }
    }
}

private enum AppVersion {
    static let number = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    static let revision = Bundle.main.url(forResource: "BuildRevision", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? "unknown"
}

private enum SettingsTab {
    case general, about
}

@MainActor
private final class SettingsModel: ObservableObject {
    @Published var tab: SettingsTab = .general
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published private(set) var loginError: String?

    var openAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

    func refresh() {
        loginStatus = SMAppService.mainApp.status
    }

    func setOpenAtLogin(_ enabled: Bool) {
        defer { refresh() }
        loginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = error.localizedDescription
        }
    }
}

@MainActor
private final class SettingsWindow {
    static let shared = SettingsWindow()
    private let window: NSWindow
    private let model = SettingsModel()

    private init() {
        let content = NSHostingController(rootView: SettingsView(model: model))
        window = NSWindow(contentViewController: content)
        window.title = AppPreferences.shared.text("Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func updateTitle() {
        window.title = AppPreferences.shared.text("Settings")
    }

    func show(_ tab: SettingsTab = .general) {
        updateTitle()
        model.tab = tab
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject private var preferences = AppPreferences.shared
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView(selection: $model.tab) {
            general
                .tabItem { Label(preferences.text("General"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            about
                .tabItem { Label(preferences.text("About"), systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(16)
        .frame(width: 470, height: 640)
        .onChange(of: preferences.language) { _ in SettingsWindow.shared.updateTitle() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(preferences.text("Appearance"), selection: $preferences.appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    Text(preferences.text(appearance.rawValue)).tag(appearance)
                }
            }
            Picker(preferences.text("Language"), selection: $preferences.language) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language == .system ? preferences.text("System") : language.rawValue).tag(language)
                }
            }
            Divider()
            Toggle(preferences.text("Open at Login"), isOn: Binding(
                get: { model.openAtLogin },
                set: { model.setOpenAtLogin($0) }
            ))
            if model.loginStatus == .requiresApproval {
                Text(preferences.text("Allow Multi Sound Changer in Login Items to finish setup."))
                    .foregroundStyle(.secondary)
                Button(preferences.text("Open Login Items Settings")) { SMAppService.openSystemSettingsLoginItems() }
            }
            if let error = model.loginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VolumeShortcutSettings()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Multi Sound Changer")
                .font(.title2.weight(.semibold))
            Text(preferences.text("Version %@ (%@)", AppVersion.number, AppVersion.revision))
                .textSelection(.enabled)
            Text(preferences.text("Powered by Stone Wang"))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
