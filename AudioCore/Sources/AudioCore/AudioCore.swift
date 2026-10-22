import Foundation

// MARK: - Device abstraction

/// The slice of an audio output device that AudioState needs.
public protocol AudioOutputDevice: AnyObject {
    var name: String { get }
    var id: UInt32 { get }
    var isDefaultOutputDevice: Bool { get set }
    func setOutputVolume(_ volume: Float)
    func outputVolume() -> Float?
    func isOutputMuted() -> Bool?
}

/// Source of output devices (CoreAudio in the app, fakes in tests).
public protocol AudioDeviceProvider {
    var outputDevices: [AudioOutputDevice] { get }
}

// MARK: - Model

public struct MyAudioDevice: Codable, Equatable {
    public let name: String
    public let id: UInt32
    public let enabled: Bool

    public init(name: String, id: UInt32, enabled: Bool) {
        self.name = name
        self.id = id
        self.enabled = enabled
    }
}

// MARK: - State

public class AudioState {
    private let _provider: AudioDeviceProvider
    private var _devices = [MyAudioDevice]()
    private var _isSticky = false
    private var _chosenDeviceName: String? {
        didSet { _chosenPreference?.deviceName = _chosenDeviceName }
    }
    private let _chosenPreference: ChosenDevicePreference?

    public init(provider: AudioDeviceProvider, chosenPreference: ChosenDevicePreference? = nil) {
        _provider = provider
        _chosenPreference = chosenPreference
        _chosenDeviceName = chosenPreference?.deviceName
    }

    public static func LoadAudioEnvironment(provider: AudioDeviceProvider,
                                            chosenPreference: ChosenDevicePreference? = nil) -> AudioState {
        let state = AudioState(provider: provider, chosenPreference: chosenPreference)
        state.reload()
        return state
    }

    private func loadDevices() -> [MyAudioDevice] {
        let devices = _provider.outputDevices.map {
            MyAudioDevice(name: $0.name, id: $0.id, enabled: $0.isDefaultOutputDevice)
        }
        // Active device first, then by id.
        return devices.sorted {
            if $0.enabled != $1.enabled { return $0.enabled }
            return $0.id < $1.id
        }
    }

    public func reload() {
        _devices = loadDevices()
    }

    public func MakeActiveOutputDevice(device: MyAudioDevice) {
        var found = false
        for d in _provider.outputDevices where d.name == device.name {
            d.isDefaultOutputDevice = true
            found = true
        }
        // A device the user picks in the app becomes the one Sticky protects.
        if found { _chosenDeviceName = device.name }
        reload()
    }

    /// Re-selects the persisted last-chosen device as the default output, if it
    /// is currently present. Returns true if it was applied.
    @discardableResult
    public func RestoreChosenDevice() -> Bool {
        reload()
        guard let chosen = _chosenDeviceName,
              _provider.outputDevices.contains(where: { $0.name == chosen }) else { return false }
        if ActiveOutputDevice?.name != chosen {
            MakeActiveOutputDevice(device: MyAudioDevice(name: chosen, id: 0, enabled: false))
        }
        return true
    }

    /// Launch-time setup. With Sticky on, the persisted chosen device is made
    /// the default output first (SetSticky would otherwise record whatever the
    /// system happens to be using). With Sticky off, nothing is switched; the
    /// chosen device is only remembered so the UI can highlight it.
    public func ApplyLaunchState(sticky: Bool) {
        if sticky { RestoreChosenDevice() }
        SetSticky(sticky)
    }

    // MARK: Sticky

    /// When on, a system default change away from the chosen device is undone.
    public var isSticky: Bool { _isSticky }

    /// Name of the device Sticky restores, if any.
    public var ChosenDeviceName: String? { _chosenDeviceName }

    /// Turning Sticky on records the current default output as the chosen device.
    public func SetSticky(_ on: Bool) {
        if on && !_isSticky {
            reload()
            _chosenDeviceName = ActiveOutputDevice?.name ?? _chosenDeviceName
        }
        _isSticky = on
    }

    /// Call when the system default output changed. Switches back to the chosen
    /// device if Sticky is on and it is present. Returns true if it switched.
    @discardableResult
    public func HandleDefaultOutputChanged() -> Bool {
        reload()
        guard _isSticky, let chosen = _chosenDeviceName else { return false }
        if ActiveOutputDevice?.name == chosen { return false }
        guard _provider.outputDevices.contains(where: { $0.name == chosen }) else { return false }
        MakeActiveOutputDevice(device: MyAudioDevice(name: chosen, id: 0, enabled: false))
        return true
    }

    public func ChangeDeviceVolue(selectedDevice: MyAudioDevice, volume: Double) {
        findDevice(selectedDevice: selectedDevice)?.setOutputVolume(Float(volume))
    }

    public func GetVolumeLevel(selectedDevice: MyAudioDevice) -> Double? {
        guard let volume = findDevice(selectedDevice: selectedDevice)?.outputVolume() else { return nil }
        return Double(volume)
    }

    public func IsDeviceMuted(selectedDevice: MyAudioDevice) -> Bool {
        return findDevice(selectedDevice: selectedDevice)?.isOutputMuted() ?? false
    }

    public func findDevice(selectedDevice: MyAudioDevice) -> AudioOutputDevice? {
        return _provider.outputDevices.first { $0.name == selectedDevice.name }
    }

    public var Devices: [MyAudioDevice] { _devices }

    public var ActiveOutputDevice: MyAudioDevice? { _devices.last { $0.enabled } }
}
