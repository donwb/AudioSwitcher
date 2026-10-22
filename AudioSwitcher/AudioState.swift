//
//  AudioState.swift
//  AudioSwitcher
//
//  Wires AudioCore's AudioState to the real CoreAudio hardware.
//

import Foundation
import AudioCore

extension AudioState {
    static func LoadAudioEnvironment() -> AudioState {
        // Keeps `.defaultOutputDeviceChanged` notifications flowing to the UI.
        DefaultOutputDeviceMonitor.shared.start()
        return LoadAudioEnvironment(provider: NativeAudioProvider(),
                                    chosenPreference: ChosenDevicePreference())
    }
}
