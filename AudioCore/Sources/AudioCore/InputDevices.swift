import Foundation
import CoreAudio

// MARK: - Abstraction

/// The slice of an audio input device the app needs. Inputs are only listed and
/// made the default: no volume, no Sticky.
public protocol AudioInputDevice: AnyObject {
    var name: String { get }
    var id: UInt32 { get }
    var transportType: AudioTransportType { get }
    var isDefaultInputDevice: Bool { get set }
}

/// Source of input devices (CoreAudio in the app, fakes in tests).
public protocol AudioInputDeviceProvider {
    var inputDevices: [AudioInputDevice] { get }
}

// MARK: - CoreAudio

public final class NativeInputDevice: AudioInputDevice {
    public let id: UInt32
    public init(id: UInt32) { self.id = id }

    public var name: String { NativeCoreAudio.deviceName(id) ?? "" }
    public var transportType: AudioTransportType { NativeCoreAudio.transportType(id) }

    public var isDefaultInputDevice: Bool {
        get { NativeCoreAudio.defaultInputDeviceID() == id }
        set { if newValue { _ = NativeCoreAudio.setDefaultInputDeviceID(id) } }
    }
}

public struct NativeInputProvider: AudioInputDeviceProvider {
    public init() {}
    public var inputDevices: [AudioInputDevice] {
        NativeCoreAudio.inputDeviceIDs().map { NativeInputDevice(id: $0) }
    }
}

public extension Notification.Name {
    /// Posted on the main queue whenever the system default input device changes.
    static let defaultInputDeviceChanged = Notification.Name("AudioCore.defaultInputDeviceChanged")
}

/// Listens for default-input-device changes and re-posts them as
/// `.defaultInputDeviceChanged`. Read-only: never changes audio state.
public final class DefaultInputDeviceMonitor {
    public static let shared = DefaultInputDeviceMonitor()

    private let backend: AudioPropertyListening
    private let center: NotificationCenter
    private var token: AnyObject?

    public init(backend: AudioPropertyListening = HardwarePropertyListening(),
                center: NotificationCenter = .default) {
        self.backend = backend
        self.center = center
    }

    public var isRunning: Bool { token != nil }

    @discardableResult
    public func start() -> Bool {
        guard token == nil else { return true }
        let key = AudioPropertyKey(kAudioHardwarePropertyDefaultInputDevice,
                                   scope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal), element: 0)
        token = backend.addListener(object: AudioObjectID(kAudioObjectSystemObject), key: key) { [weak self] in
            self?.center.post(name: .defaultInputDeviceChanged, object: nil)
        }
        return token != nil
    }

    public func stop() {
        if let t = token { backend.removeListener(t) }
        token = nil
    }

    deinit { stop() }
}

extension NativeCoreAudio {
    static func inputChannelCount(_ id: AudioObjectID) -> Int {
        var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                           mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeInput), mElement: 0)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    public static func inputDeviceIDs() -> [UInt32] {
        allDeviceIDs().filter { inputChannelCount($0) > 0 }
    }

    public static func defaultInputDeviceID() -> UInt32? {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    /// Changes the system default input device. Never call from tests on real hardware.
    @discardableResult
    public static func setDefaultInputDeviceID(_ id: UInt32) -> Bool {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var v = AudioObjectID(id)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil,
                                          UInt32(MemoryLayout<AudioObjectID>.size), &v) == noErr
    }
}
