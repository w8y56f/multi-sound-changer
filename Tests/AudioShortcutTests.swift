// Runs the real AudioPanelModel with simulated hardware; never changes system audio.
import CoreAudio
import Foundation

struct AudioDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    var uid: String { String(id) }
    let name: String
    var isAggregate = false
    var isBlackHole = false
    var inputChannels = 0
    var outputChannels = 2
    var canBeDefaultInput = false
    var canBeDefaultOutput = true
}
enum AudioDirection {
    case input, output
    var label: String { self == .input ? "Input" : "Output" }
}
struct CoreAudioFailure: Error { let status: OSStatus }
struct VolumeFeedback {
    struct Row { let id: String; let name: String; let level: Double? }
    let output: String
    let rows: [Row]
    let message: String?
}
@MainActor
enum CoreAudioDevices {
    static let e = AudioDevice(id: 1, name: "e")
    static let b = AudioDevice(id: 2, name: "b")
    static let blackHole = AudioDevice(id: 3, name: "BlackHole", isBlackHole: true)
    static let unsupported = AudioDevice(id: 4, name: "HDMI")
    static let m = AudioDevice(id: 5, name: "m", isAggregate: true)
    static let k = AudioDevice(id: 6, name: "k", isAggregate: true)
    static var levels: [AudioDeviceID: Double] = [1: 0.5, 2: 0.3]
    static var route: AudioDeviceID = 5
    static var failingID: AudioDeviceID?
    static var writes: [AudioDeviceID] = []
    static var groups: [AudioDeviceID: [AudioDevice]] = [5: [blackHole, e], 6: [e, b]]
    static func connected() -> [AudioDevice] { [e, b, blackHole, unsupported, m, k] }
    static func defaultDevice(_ direction: AudioDirection) -> AudioDeviceID? { direction == .output ? route : nil }
    static func outputMembers(of output: AudioDevice, among: [AudioDevice]) -> [AudioDevice] { groups[output.id] ?? [] }
    static func volume(of device: AudioDevice) -> Double? { levels[device.id] }
    static func select(_ device: AudioDevice, for direction: AudioDirection) throws { route = device.id }
    static func setVolume(_ value: Double, of device: AudioDevice, routedThrough output: AudioDevice) throws {
        precondition(!device.isBlackHole)
        guard output.id == route, failingID != device.id else { throw CoreAudioFailure(status: -1) }
        levels[device.id] = value
        writes.append(device.id)
    }
}

@main
struct AudioShortcutTests {
    @MainActor static func expect(_ id: AudioDeviceID, _ level: Double) {
        precondition(abs(CoreAudioDevices.levels[id]! - level) < 0.000001)
    }
    @MainActor static func main() {
        let model = AudioPanelModel()
        let first = model.adjustLinkedVolume(by: 0.05)
        expect(1, 0.55)
        precondition(first.rows.count == 1 && CoreAudioDevices.writes == [1])
        model.select(CoreAudioDevices.e, direction: .output)
        expect(1, 0.55) // switching does not reset volume
        model.select(CoreAudioDevices.k, direction: .output)
        _ = model.adjustLinkedVolume(by: 0.05)
        expect(1, 0.6); expect(2, 0.35)
        CoreAudioDevices.levels = [1: 0.98, 2: 0.78]
        let capped = model.adjustLinkedVolume(by: 0.05)
        expect(1, 1); expect(2, 0.8)
        precondition(capped.message?.contains("upper limit") == true)
        let count = CoreAudioDevices.writes.count
        _ = model.adjustLinkedVolume(by: 0.05)
        precondition(CoreAudioDevices.writes.count == count)
        CoreAudioDevices.levels = [1: 0.5, 2: 0.3]
        CoreAudioDevices.failingID = 2
        let failed = model.adjustLinkedVolume(by: 0.05)
        expect(1, 0.5); expect(2, 0.3) // first device rolled back after second failed
        precondition(failed.message?.contains("couldn’t") == true)
        CoreAudioDevices.failingID = nil
        CoreAudioDevices.groups[6] = [.init(id: 3, name: "BlackHole", isBlackHole: true), CoreAudioDevices.e, CoreAudioDevices.unsupported]
        let partial = model.adjustLinkedVolume(by: 0.05)
        expect(1, 0.55)
        precondition(partial.rows.count == 1 && partial.message?.contains("Some devices do not support") == true)
        model.select(CoreAudioDevices.unsupported, direction: .output)
        let unavailable = model.adjustLinkedVolume(by: 0.05)
        precondition(unavailable.rows.isEmpty && unavailable.message?.contains("does not support") == true)
        print("Audio shortcut model tests passed (routing, protection, shared levels, boundaries, rollback, unsupported devices).")
    }
}
