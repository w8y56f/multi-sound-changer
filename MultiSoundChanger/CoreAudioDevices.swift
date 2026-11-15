import AudioToolbox
import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let iconURL: URL?
    let transport: UInt32?
    let inputChannels: UInt32
    let outputChannels: UInt32
    let canBeDefaultInput: Bool
    let canBeDefaultOutput: Bool
    let isAggregate: Bool
    let isBlackHole: Bool

    func symbolName(for direction: AudioDirection) -> String? {
        switch transport {
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return direction == .output ? "display" : nil
        case kAudioDeviceTransportTypeBuiltIn:
            return name.localizedCaseInsensitiveContains("MacBook") ? "laptopcomputer" : nil
        default:
            return nil
        }
    }

    var connection: String {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: "Built-in"
        case kAudioDeviceTransportTypeUSB: "USB"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: "Bluetooth"
        case kAudioDeviceTransportTypeHDMI: "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: "AirPlay"
        case kAudioDeviceTransportTypeVirtual: "Virtual"
        default: isAggregate ? "Aggregate" : "Device"
        }
    }
}

enum AudioDirection {
    case input, output

    var scope: AudioObjectPropertyScope {
        self == .input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
    }

    var defaultSelector: AudioObjectPropertySelector {
        self == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    }

    var label: String { self == .input ? "Input" : "Output" }
}

struct CoreAudioFailure: Error {
    let status: OSStatus
}

private enum AudioProperty {
    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func read<T>(_ id: AudioObjectID, _ property: AudioObjectPropertyAddress, initial: T) -> T? {
        var property = property
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) {
            AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0.baseAddress!)
        }
        return status == noErr && size == MemoryLayout<T>.size ? value : nil
    }

    static func readCF<T: AnyObject>(
        _ id: AudioObjectID, _ selector: AudioObjectPropertySelector, as type: T.Type
    ) -> T? {
        let value = read(id, address(selector), initial: Optional<Unmanaged<T>>.none) ?? nil
        return value?.takeRetainedValue()
    }

    static func readIDs(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var property = address(selector)
        var size: UInt32 = 0
        let stride = UInt32(MemoryLayout<AudioObjectID>.stride)
        guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr,
              size >= stride else { return [] }

        var ids = [AudioObjectID](repeating: kAudioObjectUnknown, count: Int(size / stride))
        size = UInt32(ids.count) * stride
        let status = ids.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(ids.prefix(Int(size / stride)))
    }

    static func canWrite(_ id: AudioObjectID, _ property: AudioObjectPropertyAddress) -> Bool {
        var property = property
        guard AudioObjectHasProperty(id, &property) else { return false }
        var writable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(id, &property, &writable) == noErr && writable.boolValue
    }

    static func write<T>(_ value: T, to id: AudioObjectID, _ property: AudioObjectPropertyAddress) throws {
        var property = property
        let status = withUnsafeBytes(of: value) {
            AudioObjectSetPropertyData(id, &property, 0, nil, UInt32($0.count), $0.baseAddress!)
        }
        if status != noErr { throw CoreAudioFailure(status: status) }
    }

    static func channelCount(_ id: AudioDeviceID, direction: AudioDirection) -> UInt32 {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: direction.scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, storage) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(storage.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + $1.mNumberChannels }
    }
}

enum CoreAudioDevices {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func connected() -> [AudioDevice] {
        AudioProperty.readIDs(system, kAudioHardwarePropertyDevices)
            .compactMap { describe($0) }
    }

    static func defaultDevice(_ direction: AudioDirection) -> AudioDeviceID? {
        let id = AudioProperty.read(system, AudioProperty.address(direction.defaultSelector), initial: AudioDeviceID(0))
        return id == kAudioObjectUnknown ? nil : id
    }

    static func select(_ device: AudioDevice, for direction: AudioDirection) throws {
        try verifyIdentity(device)
        try AudioProperty.write(device.id, to: system, AudioProperty.address(direction.defaultSelector))
    }

    static func outputMembers(of aggregate: AudioDevice, among devices: [AudioDevice]) -> [AudioDevice] {
        guard aggregate.isAggregate else { return [] }

        // Resolve configured UIDs to the normal device objects that own the volume controls.
        var seen = Set<String>()
        return memberUIDs(of: aggregate).compactMap { uid in
            guard seen.insert(uid).inserted else { return nil }
            return devices.first { $0.uid == uid && $0.id != aggregate.id && $0.outputChannels > 0 }
        }
    }

    private static func memberUIDs(of aggregate: AudioDevice) -> [String] {
        if let configured = AudioProperty.readCF(
            aggregate.id, kAudioAggregateDevicePropertyFullSubDeviceList, as: CFArray.self
        ) {
            return (configured as NSArray).compactMap { $0 as? String }
        }
        return AudioProperty.readIDs(
            aggregate.id, kAudioAggregateDevicePropertyActiveSubDeviceList
        ).compactMap { uid(of: $0) }
    }

    static func volume(of device: AudioDevice) -> Double? {
        volumeControls(for: device)?.map { Double($0.value) }.max()
    }

    static func setVolume(_ value: Double, of device: AudioDevice, routedThrough output: AudioDevice) throws {
        try verifyIdentity(output)
        try verifyIdentity(device)
        guard defaultDevice(.output) == output.id,
              output.isAggregate ? memberUIDs(of: output).contains(device.uid) : output.id == device.id
        else { throw CoreAudioFailure(status: kAudioHardwareBadDeviceError) }
        guard value.isFinite, let controls = volumeControls(for: device),
              let loudest = controls.map(\.value).max() else {
            throw CoreAudioFailure(status: kAudioHardwareUnsupportedOperationError)
        }
        let target = Float32(min(max(value, 0), 1))
        var written: [(property: AudioObjectPropertyAddress, value: Float32)] = []
        do {
            for control in controls {
                let level = loudest > 0 ? (control.value / loudest) * target : target
                try AudioProperty.write(level, to: device.id, control.property)
                written.append(control)
            }
        } catch {
            // A channel write can fail mid-change, for instance when a USB device is unplugged.
            if uid(of: device.id) == device.uid {
                for control in written.reversed() {
                    try? AudioProperty.write(control.value, to: device.id, control.property)
                }
            }
            throw error
        }
    }

    private static func describe(_ id: AudioDeviceID) -> AudioDevice? {
        guard let uid = uid(of: id),
              AudioProperty.read(id, AudioProperty.address(kAudioDevicePropertyDeviceIsAlive), initial: UInt32(1)) != 0
        else { return nil }

        let name = (AudioProperty.readCF(id, kAudioObjectPropertyName, as: CFString.self) as String?) ?? uid
        let iconURL = AudioProperty.readCF(id, kAudioDevicePropertyIcon, as: CFURL.self) as URL?
        let model = AudioProperty.readCF(id, kAudioDevicePropertyModelUID, as: CFString.self) as String? ?? ""
        let transport = AudioProperty.read(id, AudioProperty.address(kAudioDevicePropertyTransportType), initial: UInt32(0))
        var composition = AudioProperty.address(kAudioAggregateDevicePropertyComposition)
        let isAggregate = transport == kAudioDeviceTransportTypeAggregate || AudioObjectHasProperty(id, &composition)
        return AudioDevice(
            id: id,
            uid: uid,
            name: name,
            iconURL: iconURL,
            transport: transport,
            inputChannels: AudioProperty.channelCount(id, direction: .input),
            outputChannels: AudioProperty.channelCount(id, direction: .output),
            canBeDefaultInput: canBeDefault(id, direction: .input),
            canBeDefaultOutput: canBeDefault(id, direction: .output),
            isAggregate: isAggregate,
            isBlackHole: [uid, name, model].contains { $0.localizedCaseInsensitiveContains("BlackHole") }
        )
    }

    private static func canBeDefault(_ id: AudioDeviceID, direction: AudioDirection) -> Bool {
        let address = AudioProperty.address(kAudioDevicePropertyDeviceCanBeDefaultDevice, scope: direction.scope)
        return AudioProperty.read(id, address, initial: UInt32(0)) != 0
    }

    private static func uid(of id: AudioDeviceID) -> String? {
        AudioProperty.readCF(id, kAudioDevicePropertyDeviceUID, as: CFString.self) as String?
    }

    private static func verifyIdentity(_ device: AudioDevice) throws {
        guard uid(of: device.id) == device.uid else {
            throw CoreAudioFailure(status: kAudioHardwareBadDeviceError)
        }
    }

    private static func volumeControls(
        for device: AudioDevice
    ) -> [(property: AudioObjectPropertyAddress, value: Float32)]? {
        guard !device.isBlackHole, !device.isAggregate, device.outputChannels > 0 else { return nil }

        let mainSelectors = [kAudioDevicePropertyVolumeScalar, kAudioHardwareServiceDeviceProperty_VirtualMainVolume]
        for selector in mainSelectors {
            let property = AudioProperty.address(selector, scope: kAudioObjectPropertyScopeOutput)
            if let value = writableVolume(device.id, property) { return [(property, value)] }
        }

        var controls: [(AudioObjectPropertyAddress, Float32)] = []
        for element in 1...device.outputChannels {
            let property = AudioProperty.address(
                kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput, element: element
            )
            guard let value = writableVolume(device.id, property) else { return nil }
            controls.append((property, value))
        }
        return controls
    }

    private static func writableVolume(_ id: AudioDeviceID, _ property: AudioObjectPropertyAddress) -> Float32? {
        guard AudioProperty.canWrite(id, property),
              let value = AudioProperty.read(id, property, initial: Float32(0)),
              value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }
}
