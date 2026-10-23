import Foundation
import Combine

/// One row in the output device list.
public struct AudioDeviceRow: Identifiable, Equatable {
    public let id: UInt32
    public let name: String
    public let transportType: AudioTransportType
    public let isDefault: Bool

    public var symbolName: String { transportType.symbolName }
}

/// Removes notification observers when the owner goes away.
private final class ObserverBag {
    let center: NotificationCenter
    var tokens: [NSObjectProtocol] = []
    init(center: NotificationCenter) { self.center = center }
    deinit { tokens.forEach(center.removeObserver) }
}

/// All state and behaviour of the menu bar popover. Views only render it and
/// forward user actions. Driven by an `AudioDeviceProvider`, so it runs on fakes.
///
/// Live updates arrive as `.defaultOutputDeviceChanged` / `.audioDeviceListChanged` /
/// `.outputVolumeChanged`
/// notifications on `center`; both are posted on the main thread.
@MainActor
public final class AudioMenuViewModel: ObservableObject {
    @Published public private(set) var rows: [AudioDeviceRow] = []
    /// Volume of the current default device, 0...1.
    /// Input devices, sorted by name. Empty without an input provider.
    @Published public private(set) var inputRows: [AudioDeviceRow] = []
    @Published public private(set) var volume: Double = 0
    /// False when the current device has no settable volume.
    @Published public private(set) var hasVolumeControl = false
    /// True when the current device is muted.
    @Published public private(set) var isMuted = false
    @Published public private(set) var isSticky: Bool
    @Published public private(set) var switchCount: Int

    /// Icon next to the volume slider: a slash when muted.
    public var volumeSymbolName: String { isMuted ? "speaker.slash" : "speaker.fill" }

    private let state: AudioState
    private let inputProvider: AudioInputDeviceProvider?
    private let stickyPreference: StickyPreference
    private let counter: SwitchCounting
    private let observers: ObserverBag

    public init(provider: AudioDeviceProvider,
                stickyPreference: StickyPreference,
                chosenPreference: ChosenDevicePreference?,
                switchCounter: SwitchCounting,
                inputProvider: AudioInputDeviceProvider? = nil,
                center: NotificationCenter = .default) {
        state = AudioState(provider: provider, chosenPreference: chosenPreference)
        self.inputProvider = inputProvider
        self.stickyPreference = stickyPreference
        counter = switchCounter
        isSticky = stickyPreference.isOn
        switchCount = switchCounter.total
        observers = ObserverBag(center: center)

        // Restore the chosen device before Sticky is armed (see AudioState.ApplyLaunchState).
        state.reload()
        state.ApplyLaunchState(sticky: isSticky)
        refresh()

        let handler: (Notification) -> Void = { [weak self] note in
            // Monitors post on the main thread.
            MainActor.assumeIsolated {
                if note.name == .defaultOutputDeviceChanged {
                    self?.defaultOutputChanged()
                } else if note.name == .defaultInputDeviceChanged {
                    self?.refreshInputs()
                } else if note.name == .outputVolumeChanged {
                    self?.refreshVolume()
                } else {
                    self?.refresh()
                }
            }
        }
        observers.tokens = [.defaultOutputDeviceChanged, .audioDeviceListChanged, .outputVolumeChanged, .defaultInputDeviceChanged].map {
            center.addObserver(forName: $0, object: nil, queue: nil, using: handler)
        }
    }

    /// Re-reads devices, default and volume from the provider.
    public func refresh() {
        state.reload()
        rows = state.Devices
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
            .map { d in
                let transport = state.findDevice(selectedDevice: d)?.transportType ?? .other
                return AudioDeviceRow(id: d.id, name: d.name, transportType: transport, isDefault: d.enabled)
            }
        refreshVolume()
        refreshInputs()
    }

    private func refreshInputs() {
        inputRows = (inputProvider?.inputDevices ?? [])
            .map { AudioDeviceRow(id: $0.id, name: $0.name, transportType: $0.transportType,
                                  isDefault: $0.isDefaultInputDevice) }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
    }

    private func refreshVolume() {
        if let active = state.ActiveOutputDevice, let v = state.GetVolumeLevel(selectedDevice: active) {
            hasVolumeControl = true
            volume = v
        } else {
            hasVolumeControl = false
            volume = 0
        }
        isMuted = state.ActiveOutputDevice.map { state.IsDeviceMuted(selectedDevice: $0) } ?? false
    }

    private func defaultOutputChanged() {
        state.HandleDefaultOutputChanged()   // Sticky: undo a change away from the chosen device
        counter.increment()
        switchCount = counter.total
        refresh()
    }

    // MARK: Actions

    /// Makes the device the system default (and the one Sticky protects).
    public func select(_ row: AudioDeviceRow) {
        state.MakeActiveOutputDevice(device: MyAudioDevice(name: row.name, id: row.id, enabled: false))
        refresh()
    }

    /// Selects the Nth output device (1-based, ⌘1...⌘9). No-op when there is no such row.
    public func selectOutput(number: Int) {
        guard let row = DeviceOrdering.row(number: number, in: rows) else { return }
        select(row)
    }

    /// Switches to the next output device in list order, wrapping (the global hotkey).
    /// Counts as the chosen device for Sticky, like a click.
    public func selectNextOutput() {
        refresh()   // the popover may never have been opened; don't trust stale rows
        guard let row = DeviceOrdering.next(in: rows) else { return }
        select(row)
    }

    /// Makes the input device the system default input. Not affected by Sticky.
    public func selectInput(_ row: AudioDeviceRow) {
        for d in inputProvider?.inputDevices ?? [] where d.name == row.name { d.isDefaultInputDevice = true }
        refreshInputs()
    }

    /// Sets the current device's volume. No-op without a volume control.
    public func setVolume(_ value: Double) {
        guard hasVolumeControl, let active = state.ActiveOutputDevice else { return }
        let clamped = min(max(value, 0), 1)
        state.ChangeDeviceVolue(selectedDevice: active, volume: clamped)
        volume = clamped
    }

    public func setSticky(_ on: Bool) {
        stickyPreference.isOn = on
        state.SetSticky(on)
        isSticky = on
    }
}
