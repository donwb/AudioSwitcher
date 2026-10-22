import Foundation
import CoreAudio

/// An output device backed directly by CoreAudio (no third-party wrapper).
public final class NativeAudioDevice: AudioOutputDevice {
    public let id: UInt32
    private let store: AudioPropertyStore
    private let volumeControl: VolumeControl

    public init(id: UInt32) {
        self.id = id
        let store = HardwarePropertyStore(objectID: id)
        self.store = store
        self.volumeControl = VolumeControl(store: store, channelCount: NativeCoreAudio.outputChannelCount(id))
    }

    public var name: String { NativeCoreAudio.deviceName(id) ?? "" }

    public var isDefaultOutputDevice: Bool {
        get { NativeCoreAudio.defaultOutputDeviceID() == id }
        set { if newValue { _ = NativeCoreAudio.setDefaultOutputDeviceID(id) } }
    }

    public func setOutputVolume(_ volume: Float) { volumeControl.setVolume(volume) }
    public func outputVolume() -> Float? { volumeControl.volume() }
    public func isOutputMuted() -> Bool? { volumeControl.isMuted() }
}

/// Provider listing real output devices via CoreAudio.
public struct NativeAudioProvider: AudioDeviceProvider {
    public init() {}
    public var outputDevices: [AudioOutputDevice] {
        NativeCoreAudio.outputDeviceIDs().map { NativeAudioDevice(id: $0) }
    }
}

/// Thin helpers over the CoreAudio HAL system object.
public enum NativeCoreAudio {
    private static let system = AudioObjectID(kAudioObjectSystemObject)
    private static let outputScope = AudioObjectPropertyScope(kAudioObjectPropertyScopeOutput)

    static func allDeviceIDs() -> [AudioObjectID] {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: 0)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    /// Number of output channels (sum over output stream buffers).
    static func outputChannelCount(_ id: AudioObjectID) -> Int {
        var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                           mScope: outputScope, mElement: 0)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    public static func outputDeviceIDs() -> [UInt32] {
        allDeviceIDs().filter { outputChannelCount($0) > 0 }
    }

    public static func deviceName(_ id: AudioObjectID) -> String? {
        var a = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var ref: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &ref) == noErr,
              let cf = ref else { return nil }
        return cf.takeRetainedValue() as String
    }

    public static func defaultOutputDeviceID() -> UInt32? {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    /// Changes the system default output device. Never call from tests on real hardware.
    @discardableResult
    public static func setDefaultOutputDeviceID(_ id: UInt32) -> Bool {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var v = AudioObjectID(id)
        return AudioObjectSetPropertyData(system, &a, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &v) == noErr
    }
}
