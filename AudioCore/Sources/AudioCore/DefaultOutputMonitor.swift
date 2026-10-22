import Foundation
import CoreAudio

public extension Notification.Name {
    /// Posted on the main queue whenever the system default output device changes.
    static let defaultOutputDeviceChanged = Notification.Name("AudioCore.defaultOutputDeviceChanged")
}

/// Listens for CoreAudio default-output-device changes and re-posts them as
/// `.defaultOutputDeviceChanged` notifications. Read-only: never changes audio state.
public final class DefaultOutputDeviceMonitor {
    public static let shared = DefaultOutputDeviceMonitor()

    private let center: NotificationCenter
    private var listener: AudioObjectPropertyListenerBlock?
    private var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: 0)

    public init(center: NotificationCenter = .default) {
        self.center = center
    }

    public var isRunning: Bool { listener != nil }

    /// Starts listening. Safe to call repeatedly.
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
        center.post(name: .defaultOutputDeviceChanged, object: nil)
    }

    deinit { stop() }
}
