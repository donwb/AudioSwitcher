import Foundation
import CoreAudio

public extension Notification.Name {
    /// Posted on the main queue whenever a device is added to or removed from the system.
    static let audioDeviceListChanged = Notification.Name("AudioCore.audioDeviceListChanged")
}

/// Listens for CoreAudio device list changes (plug/unplug) and re-posts them as
/// `.audioDeviceListChanged`. Read-only: never changes audio state.
public final class AudioDeviceListMonitor {
    public static let shared = AudioDeviceListMonitor()

    private let center: NotificationCenter
    private var listener: AudioObjectPropertyListenerBlock?
    private var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: 0)

    public init(center: NotificationCenter = .default) {
        self.center = center
    }

    public var isRunning: Bool { listener != nil }

    @discardableResult
    public func start() -> Bool {
        guard listener == nil else { return true }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.postChange() }
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                                         &address, DispatchQueue.main, block)
        guard status == noErr else { return false }
        listener = block
        return true
    }

    public func stop() {
        guard let block = listener else { return }
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                               &address, DispatchQueue.main, block)
        listener = nil
    }

    func postChange() {
        center.post(name: .audioDeviceListChanged, object: nil)
    }

    deinit { stop() }
}
