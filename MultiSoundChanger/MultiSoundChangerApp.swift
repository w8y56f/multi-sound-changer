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
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let speaker = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        let letter = NSAttributedString(string: "M", attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold)])
        let letterSize = letter.size()
        let speakerWidth = speaker?.size.width ?? 0
        let icon = NSImage(size: NSSize(width: ceil(speakerWidth + 3 + letterSize.width), height: 18), flipped: false) { rect in
            if let speaker {
                speaker.draw(at: NSPoint(x: 0, y: (rect.height - speaker.size.height) / 2),
                             from: .zero, operation: .sourceOver, fraction: 1)
            }
            letter.draw(at: NSPoint(x: speakerWidth + 3, y: (rect.height - letterSize.height) / 2))
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
            Button {
                SettingsWindow.shared.show(.about)
            } label: {
                Text(preferences.text("About"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(PanelButtonStyle())
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refresh() }
        .onReceive(updates) { _ in model.refresh() }
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
    let name: String
    let iconURL: URL?
    let symbolName: String?
    let direction: AudioDirection
    let connection: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
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
                Text(connection)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(PanelButtonStyle())
        .help(name)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
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
        .frame(width: 470, height: 490)
        .onChange(of: preferences.language) { _ in SettingsWindow.shared.updateTitle() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }

    private var general: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Picker(preferences.text("Appearance"), selection: $preferences.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(preferences.text(appearance.rawValue)).tag(appearance)
                    }
                }
                Picker(preferences.text("Language"), selection: $preferences.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.rawValue).tag(language)
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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
