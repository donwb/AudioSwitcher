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

    public init(provider: AudioDeviceProvider) {
        _provider = provider
    }

    public static func LoadAudioEnvironment(provider: AudioDeviceProvider) -> AudioState {
        let state = AudioState(provider: provider)
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
        for d in _provider.outputDevices where d.name == device.name {
            d.isDefaultOutputDevice = true
        }
        reload()
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

    public func RevertToSonos() {
        MakeActiveOutputDevice(device: MyAudioDevice(name: "HIFI DSD", id: 77, enabled: false))
    }

    public var Devices: [MyAudioDevice] { _devices }

    public var ActiveOutputDevice: MyAudioDevice? { _devices.last { $0.enabled } }
}
