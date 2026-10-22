import Foundation
import CoreAudio
import AudioToolbox

/// Output volume/mute logic over an `AudioPropertyStore`.
///
/// Volume strategy (Bluetooth/AirPlay devices often lack a channel-0 control):
///   1. main (element 0) `kAudioDevicePropertyVolumeScalar`
///   2. `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`
///   3. per-channel `kAudioDevicePropertyVolumeScalar` (elements 1...channelCount, averaged)
public struct VolumeControl {
    public let store: AudioPropertyStore
    public let channelCount: Int

    public init(store: AudioPropertyStore, channelCount: Int) {
        self.store = store
        self.channelCount = channelCount
    }

    static let output = AudioObjectPropertyScope(kAudioObjectPropertyScopeOutput)

    static var mainVolumeKey: AudioPropertyKey {
        AudioPropertyKey(kAudioDevicePropertyVolumeScalar, scope: output, element: 0)
    }
    static var virtualMainVolumeKey: AudioPropertyKey {
        AudioPropertyKey(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: output, element: 0)
    }
    static func channelVolumeKey(_ channel: Int) -> AudioPropertyKey {
        AudioPropertyKey(kAudioDevicePropertyVolumeScalar, scope: output, element: AudioObjectPropertyElement(channel))
    }
    static var muteKey: AudioPropertyKey {
        AudioPropertyKey(kAudioDevicePropertyMute, scope: output, element: 0)
    }

    private var channelKeys: [AudioPropertyKey] {
        guard channelCount > 0 else { return [] }
        return (1...channelCount).map(Self.channelVolumeKey).filter { store.hasProperty($0) }
    }

    /// Volume in 0...1, or nil if the device exposes no volume control.
    public func volume() -> Float? {
        if let v = store.float(Self.mainVolumeKey) { return v }
        if let v = store.float(Self.virtualMainVolumeKey) { return v }
        let values = channelKeys.compactMap { store.float($0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    /// Sets volume (clamped to 0...1) using the first strategy that works.
    @discardableResult
    public func setVolume(_ volume: Float) -> Bool {
        let v = min(max(volume, 0), 1)
        if store.setFloat(v, for: Self.mainVolumeKey) { return true }
        if store.setFloat(v, for: Self.virtualMainVolumeKey) { return true }
        var any = false
        for key in channelKeys where store.setFloat(v, for: key) { any = true }
        return any
    }

    /// Mute state of the main output element, nil if unsupported.
    public func isMuted() -> Bool? {
        store.uint32(Self.muteKey).map { $0 != 0 }
    }
}
