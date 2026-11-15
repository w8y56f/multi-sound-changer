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
    private var dismissal: DispatchWorkItem?

    func hide() {
        dismissal?.cancel()
        panel?.orderOut(nil)
    }

    func show(_ feedback: VolumeFeedback) {
        hide()
        let panel = self.panel ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                         backing: .buffered, defer: false)
        self.panel = panel
        panel.appearance = AppPreferences.shared.appearance.appearance
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let content = NSHostingView(rootView: FeedbackView(feedback: feedback))
        let size = content.fittingSize
        panel.contentView = content
        panel.setFrame(NSRect(x: screen.visibleFrame.midX - size.width / 2,
                              y: screen.visibleFrame.minY + 60, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        let dismissal = DispatchWorkItem { [weak panel] in panel?.orderOut(nil) }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: dismissal)
    }
}

private struct FeedbackView: View {
    @ObservedObject private var preferences = AppPreferences.shared
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
                            Text(level, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                        } else {
                            Text(preferences.text("Unavailable")).foregroundStyle(.secondary)
                        }
                    }.font(.caption)
                    if let level = row.level { ProgressView(value: level).tint(.accentColor) }
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
}
