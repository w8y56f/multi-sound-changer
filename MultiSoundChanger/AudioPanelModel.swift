import CoreAudio
import SwiftUI

@MainActor
final class AudioPanelModel: ObservableObject {
    @Published private(set) var inputs: [AudioDevice] = []
    @Published private(set) var outputs: [AudioDevice] = []
    @Published private(set) var currentOutput: AudioDevice?
    @Published private(set) var volumeDevices: [AudioDevice] = []
    @Published private(set) var volumes: [AudioDeviceID: Double] = [:]
    @Published private(set) var failureAction: String?
    @Published private(set) var failureStatus: OSStatus?
    var error: String? {
        guard let failureAction else { return nil }
        let action = AppPreferences.shared.text(failureAction)
        return failureStatus.map { "\(action) (Core Audio \($0))." } ?? "\(action)."
    }
    @Published private var inputID: AudioDeviceID?

    func refresh() {
        let devices = CoreAudioDevices.connected().sorted {
            let nameOrder = $0.name.localizedStandardCompare($1.name)
            return nameOrder == .orderedSame ? $0.id < $1.id : nameOrder == .orderedAscending
        }
        let inputID = CoreAudioDevices.defaultDevice(.input)
        let outputID = CoreAudioDevices.defaultDevice(.output)
        let inputs = devices.filter { $0.inputChannels > 0 && ($0.canBeDefaultInput || $0.id == inputID) }
        let outputs = devices.filter { $0.outputChannels > 0 && ($0.canBeDefaultOutput || $0.id == outputID) }
        let currentOutput = outputs.first { $0.id == outputID }
        let volumeDevices = currentOutput.map {
            $0.isAggregate ? CoreAudioDevices.outputMembers(of: $0, among: devices) : [$0]
        } ?? []
        let volumes = Dictionary(uniqueKeysWithValues: volumeDevices.compactMap { device in
            CoreAudioDevices.volume(of: device).map { (device.id, $0) }
        })

        if self.inputID != inputID { self.inputID = inputID }
        if self.inputs != inputs { self.inputs = inputs }
        if self.outputs != outputs { self.outputs = outputs }
        if self.currentOutput != currentOutput { self.currentOutput = currentOutput }
        if self.volumeDevices != volumeDevices { self.volumeDevices = volumeDevices }
        if self.volumes != volumes { self.volumes = volumes }
    }

    func isSelected(_ device: AudioDevice, direction: AudioDirection) -> Bool {
        device.id == (direction == .input ? inputID : currentOutput?.id)
    }

    func select(_ device: AudioDevice, direction: AudioDirection) {
        defer { refresh() }
        do {
            try CoreAudioDevices.select(device, for: direction)
            failureAction = nil
        } catch {
            show(error, action: "Couldn’t switch \(direction.label.lowercased())")
        }
    }

    func setVolume(_ value: Double, of device: AudioDevice) {
        guard volumeDevices.contains(device), let currentOutput else {
            refresh()
            return
        }
        do {
            try CoreAudioDevices.setVolume(value, of: device, routedThrough: currentOutput)
            volumes[device.id] = CoreAudioDevices.volume(of: device)
            failureAction = nil
        } catch {
            show(error, action: "Couldn’t change volume")
            refresh()
        }
    }

    /// Re-read the route and levels for every shortcut, never apply a cached volume preset.
    func adjustLinkedVolume(by requested: Double) -> VolumeFeedback {
        refresh()
        guard let output = currentOutput else {
            return VolumeFeedback(output: AppPreferences.shared.text("Volume"), rows: [], message: AppPreferences.shared.text("No current output device."))
        }
        let candidates = volumeDevices.filter { !$0.isBlackHole }
        let targets = candidates.compactMap { device -> (AudioDevice, Double)? in
            guard let level = volumes[device.id] else { return nil }
            return (device, level)
        }
        guard !targets.isEmpty else {
            return VolumeFeedback(output: output.name, rows: [], message: AppPreferences.shared.text("Current output does not support volume adjustment."))
        }
        let delta = LinkedVolume.delta(levels: targets.map { $0.1 }, requested: requested)
        var failed = false
        var written: [(AudioDevice, Double)] = []
        failureAction = nil
        if abs(delta) > 0.000001 {
            do {
                for (device, level) in targets {
                    try CoreAudioDevices.setVolume(level + delta, of: device, routedThrough: output)
                    written.append((device, level))
                }
            } catch {
                failed = true
                // Best effort rollback preserves the group balance if a member disappears mid-write.
                // setVolume also revalidates the route and identity before every write.
                for (device, level) in written.reversed() {
                    try? CoreAudioDevices.setVolume(level, of: device, routedThrough: output)
                }
                show(error, action: "Some devices couldn’t be adjusted")
            }
        }
        refresh()
        let rows = targets.map { device, _ in
            VolumeFeedback.Row(id: device.uid, name: device.name, level: CoreAudioDevices.volume(of: device))
        }
        var messages: [String] = []
        if failed {
            messages.append("Some devices couldn’t be adjusted. Showing current levels.")
        } else if abs(delta) < abs(requested) - 0.000001 || rows.contains(where: {
            guard let level = $0.level else { return false }
            return requested > 0 ? level >= 0.999999 : level <= 0.000001
        }) {
            messages.append(requested > 0 ? "Linked upper limit reached." : "Linked lower limit reached.")
        }
        if candidates.count > targets.count { messages.append("Some devices do not support volume adjustment.") }
        return VolumeFeedback(output: output.name, rows: rows,
                              message: messages.isEmpty ? nil : messages.map { AppPreferences.shared.text($0) }.joined(separator: " "))
    }

    private func show(_ error: Error, action: String) {
        failureStatus = (error as? CoreAudioFailure)?.status
        failureAction = action
    }
}
