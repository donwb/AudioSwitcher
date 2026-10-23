//
//  AudioSwitcherApp.swift
//  AudioSwitcher
//
//  Menu bar entry point: a single MenuBarExtra in .window style.
//

import SwiftUI
import AudioCore
import Carbon.HIToolbox

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
    /// Kept alive for the life of the app.
    @MainActor private static var nextOutputHotKey: GlobalHotKey?

    @MainActor
    private static func makeModel() -> AudioMenuViewModel {
        DefaultOutputDeviceMonitor.shared.start()
        AudioDeviceListMonitor.shared.start()
        OutputVolumeMonitor.shared.start()
        DefaultInputDeviceMonitor.shared.start()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let model = AudioMenuViewModel(provider: NativeAudioProvider(),
                                  stickyPreference: StickyPreference(),
                                  chosenPreference: ChosenDevicePreference(),
                                  switchCounter: PlistSwitchCounter(url: docs.appendingPathComponent("Stats.plist")),
                                  inputProvider: NativeInputProvider(),
                                  loginItem: SMAppServiceLoginItem())

        // ⌃⌥⌘O: next output device, also while the popover is closed. Carbon hot keys
        // need no Accessibility permission.
        nextOutputHotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_O),
                                        modifiers: UInt32(controlKey | optionKey | cmdKey)) {
            MainActor.assumeIsolated { model.selectNextOutput() }
        }
        return model
    }
}

/// Thin wrapper over Carbon `RegisterEventHotKey`. Handlers run on the main thread.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        guard installed == noErr else { return nil }
        let id = EventHotKeyID(signature: OSType(0x41535748), id: 1)   // 'ASWH'
        guard RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr else {
            RemoveEventHandler(handlerRef)
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
