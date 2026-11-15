import AppKit
import SwiftUI

struct VolumeFeedback {
    struct Row: Identifiable {
        let id: String
        let name: String
        let level: Double?
    }
    let output: String
    let rows: [Row]
    let message: String?
}

@MainActor
final class VolumeFeedbackWindow {
    static let shared = VolumeFeedbackWindow()
    private var panel: NSPanel?
    private var content: NSHostingView<FeedbackView>?
    private var dismissal: Task<Void, Never>?

    func hide() {
        dismissal?.cancel()
        dismissal = nil
        panel?.orderOut(nil)
    }

    func show(_ feedback: VolumeFeedback) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }

        let view = FeedbackView(feedback: feedback)
        let panel: NSPanel
        let content: NSHostingView<FeedbackView>
        if let existingPanel = self.panel, let existingContent = self.content {
            panel = existingPanel
            content = existingContent
            content.rootView = view
        } else {
            content = NSHostingView(rootView: view)
            panel = makePanel()
            panel.contentView = content
            self.panel = panel
            self.content = content
        }

        let preferences = AppPreferences.shared
        panel.appearance = preferences.appearance.appearance
        place(panel, size: content.fittingSize, on: screen, at: preferences.volumeFeedbackPosition)
        if !panel.isVisible { panel.orderFrontRegardless() }

        dismissal?.cancel()
        dismissal = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1200))
            } catch {
                return
            }
            self?.hide()
        }
    }

    func reposition(to position: VolumeFeedbackPosition) {
        guard let panel, panel.isVisible, let screen = panel.screen else { return }
        place(panel, size: panel.frame.size, on: screen, at: position)
    }

    private func place(_ panel: NSPanel, size: NSSize, on screen: NSScreen, at position: VolumeFeedbackPosition) {
        let visible = screen.visibleFrame
        let y: CGFloat
        switch position {
        case .center:
            y = visible.midY - size.height / 2
        case .lowerCenter:
            y = visible.minY + visible.height * 0.30 - size.height / 2
        case .bottom:
            y = visible.minY + 60
        }
        let clampedY = max(visible.minY, min(y, visible.maxY - size.height))
        let frame = NSRect(x: visible.midX - size.width / 2, y: clampedY,
                           width: size.width, height: size.height)
        if panel.frame != frame { panel.setFrame(frame, display: true, animate: false) }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

private struct FeedbackView: View {
    @ObservedObject private var preferences = AppPreferences.shared
    @Environment(\.colorScheme) private var colorScheme
    let feedback: VolumeFeedback
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(feedback.output, systemImage: "speaker.wave.2.fill")
                .font(.headline)
                .lineLimit(2)
            ForEach(feedback.rows) { row in
                VStack(spacing: 4) {
                    HStack {
                        Text(row.name).lineLimit(2)
                        Spacer()
                        if let level = row.level {
                            Text(level, format: .percent.precision(.fractionLength(0)))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .fixedSize()
                        } else {
                            Text(preferences.text("Unavailable")).foregroundStyle(.secondary)
                        }
                    }.font(.caption)
                    if let level = row.level { volumeBar(level) }
                }
            }
            if let message = feedback.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func volumeBar(_ level: Double) -> some View {
        let isDark = colorScheme == .dark
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: isDark ? 0.32 : 0.78))
                Rectangle().fill(Color(white: isDark ? 0.96 : 0.19))
                    .frame(width: geometry.size.width * level)
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
