//
//  AudioSwitcherApp.swift
//  AudioSwitcher
//
//  Menu bar entry point: a single MenuBarExtra in .window style.
//

import SwiftUI
import AudioCore

@main
struct AudioSwitcherApp: App {
    @State private var model = AudioSwitcherApp.makeModel()

    var body: some Scene {
        MenuBarExtra {
            AudioMenuView(model: model)
        } label: {
            Image("plugmenuicon")
        }
        .menuBarExtraStyle(.window)
    }

    /// Wires the view model to real CoreAudio. Created at launch so Sticky works
    /// even if the popover is never opened.
    @MainActor
    private static func makeModel() -> AudioMenuViewModel {
        DefaultOutputDeviceMonitor.shared.start()
        AudioDeviceListMonitor.shared.start()
        OutputVolumeMonitor.shared.start()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return AudioMenuViewModel(provider: NativeAudioProvider(),
                                  stickyPreference: StickyPreference(),
                                  chosenPreference: ChosenDevicePreference(),
                                  switchCounter: PlistSwitchCounter(url: docs.appendingPathComponent("Stats.plist")))
    }
}
