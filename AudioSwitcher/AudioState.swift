//
//  AudioState.swift
//  AudioSwitcher
//
//  Production CoreAudio bindings for AudioCore (logic lives in the AudioCore package).
//

import Foundation
import AudioCore
import SimplyCoreAudio

/// Production adapter around a SimplyCoreAudio device.
final class CoreAudioOutputDevice: AudioOutputDevice {
    private let device: AudioDevice
    init(_ device: AudioDevice) { self.device = device }

    var name: String { device.name }
    var id: UInt32 { device.id }
    var isDefaultOutputDevice: Bool {
        get { device.isDefaultOutputDevice }
        set { device.isDefaultOutputDevice = newValue }
    }
    func setOutputVolume(_ volume: Float) {
        device.setVolume(volume, channel: 0, scope: .output)
    }
    func outputVolume() -> Float? {
        device.volumeInfo(channel: 0, scope: .output)?.volume
    }
    func isOutputMuted() -> Bool? {
        device.isMuted(channel: 0, scope: .output)
    }
}

/// Production provider backed by SimplyCoreAudio.
final class CoreAudioDeviceProvider: AudioDeviceProvider {
    private let sca = SimplyCoreAudio()
    var outputDevices: [AudioOutputDevice] {
        sca.allOutputDevices.map { CoreAudioOutputDevice($0) }
    }
}

extension AudioState {
    static func LoadAudioEnvironment() -> AudioState {
        return LoadAudioEnvironment(provider: CoreAudioDeviceProvider())
    }
}
