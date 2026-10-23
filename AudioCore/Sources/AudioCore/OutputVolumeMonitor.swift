import Foundation
import CoreAudio

public extension Notification.Name {
    /// Posted on the main queue when the volume or mute of the current default
    /// output device changed (from the app or from outside, e.g. keyboard keys).
    static let outputVolumeChanged = Notification.Name("AudioCore.outputVolumeChanged")
}

/// Adds and removes CoreAudio property listeners. The real one talks to the HAL;
/// tests use a fake so no listener is ever registered for real.
public protocol AudioPropertyListening {
    /// Returns a token for `removeListener`, or nil if the property doesn't exist or can't be observed.
    func addListener(object: UInt32, key: AudioPropertyKey, handler: @escaping () -> Void) -> AnyObject?
    func removeListener(_ token: AnyObject)
}

/// CoreAudio-backed listener registration; handlers run on the main queue.
public struct HardwarePropertyListening: AudioPropertyListening {
    public init() {}

    private final class Token {
        let object: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
        init(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
            self.object = object; self.address = address; self.block = block
        }
    }

    public func addListener(object: UInt32, key: AudioPropertyKey, handler: @escaping () -> Void) -> AnyObject? {
        var address = key.address
        guard AudioObjectHasProperty(object, &address) else { return nil }
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main, block) == noErr else { return nil }
        return Token(object: object, address: address, block: block)
    }

    public func removeListener(_ token: AnyObject) {
        guard let t = token as? Token else { return }
        AudioObjectRemovePropertyListenerBlock(t.object, &t.address, DispatchQueue.main, t.block)
    }
}

/// Watches volume and mute of the current default output device and posts
/// `.outputVolumeChanged`. When the default output changes it detaches from the
/// old device and attaches to the new one. Read-only: never changes audio state.
public final class OutputVolumeMonitor {
    public static let shared = OutputVolumeMonitor()

    private let backend: AudioPropertyListening
    private let center: NotificationCenter
    private let defaultDeviceID: () -> UInt32?
    private let channelCount: (UInt32) -> Int
    private var systemToken: AnyObject?
    private var deviceTokens: [AnyObject] = []
    /// Device the volume listeners are currently attached to.
    public private(set) var attachedDeviceID: UInt32?

    public init(backend: AudioPropertyListening = HardwarePropertyListening(),
                center: NotificationCenter = .default,
                defaultDeviceID: @escaping () -> UInt32? = { NativeCoreAudio.defaultOutputDeviceID() },
                channelCount: @escaping (UInt32) -> Int = { NativeCoreAudio.outputChannelCount($0) }) {
        self.backend = backend
        self.center = center
        self.defaultDeviceID = defaultDeviceID
        self.channelCount = channelCount
    }

    public var isRunning: Bool { systemToken != nil }

    /// Starts listening. Safe to call repeatedly.
    @discardableResult
    public func start() -> Bool {
        guard systemToken == nil else { return true }
        let key = AudioPropertyKey(kAudioHardwarePropertyDefaultOutputDevice,
                                   scope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal), element: 0)
        systemToken = backend.addListener(object: AudioObjectID(kAudioObjectSystemObject), key: key) { [weak self] in
            self?.reattach()
        }
        guard systemToken != nil else { return false }
        reattach()
        return true
    }

    public func stop() {
        detach()
        if let t = systemToken { backend.removeListener(t) }
        systemToken = nil
    }

    /// Moves the volume/mute listeners to the current default output device.
    func reattach() {
        detach()
        guard let id = defaultDeviceID() else { return }
        for key in VolumeControl.watchedKeys(channelCount: channelCount(id)) {
            if let t = backend.addListener(object: id, key: key, handler: { [weak self] in self?.postChange() }) {
                deviceTokens.append(t)
            }
        }
        attachedDeviceID = id
    }

    private func detach() {
        deviceTokens.forEach(backend.removeListener)
        deviceTokens = []
        attachedDeviceID = nil
    }

    func postChange() {
        center.post(name: .outputVolumeChanged, object: nil)
    }

    deinit { stop() }
}
