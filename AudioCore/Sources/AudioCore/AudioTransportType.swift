import Foundation
import CoreAudio

/// How an output device is connected, reduced to what the UI distinguishes.
public enum AudioTransportType: Equatable, CaseIterable {
    case builtIn, bluetooth, airPlay, usb, hdmiDisplayPort, other

    /// Maps a CoreAudio `kAudioDeviceTransportType*` value.
    public init(coreAudioValue: UInt32) {
        switch coreAudioValue {
        case kAudioDeviceTransportTypeBuiltIn: self = .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: self = .bluetooth
        case kAudioDeviceTransportTypeAirPlay: self = .airPlay
        case kAudioDeviceTransportTypeUSB: self = .usb
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: self = .hdmiDisplayPort
        default: self = .other
        }
    }

    /// SF Symbol shown next to the device name.
    public var symbolName: String {
        switch self {
        case .builtIn: return "laptopcomputer"
        case .bluetooth: return "headphones"
        case .airPlay: return "airplayaudio"
        case .usb: return "cable.connector"
        case .hdmiDisplayPort: return "display"
        case .other: return "speaker.wave.2"
        }
    }
}
