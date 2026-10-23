// Renders the popover with fake devices via ImageRenderer. See render-screenshots.sh.
import SwiftUI
import AppKit
import AudioCore

final class Fake: AudioOutputDevice {
    let name: String, id: UInt32, transportType: AudioTransportType
    var isDefaultOutputDevice: Bool
    var volume: Float?
    init(_ n: String, _ id: UInt32, _ t: AudioTransportType, def: Bool = false, vol: Float? = 0.6) {
        name = n; self.id = id; transportType = t; isDefaultOutputDevice = def; volume = vol
    }
    func setOutputVolume(_ v: Float) { volume = v }
    func outputVolume() -> Float? { volume }
    func isOutputMuted() -> Bool? { false }
}
final class FakeInput: AudioInputDevice {
    let name: String, id: UInt32, transportType: AudioTransportType
    var isDefaultInputDevice: Bool
    init(_ n: String, _ id: UInt32, _ t: AudioTransportType, def: Bool = false) {
        name = n; self.id = id; transportType = t; isDefaultInputDevice = def
    }
}
struct InputProvider: AudioInputDeviceProvider {
    let devices: [FakeInput]
    var inputDevices: [AudioInputDevice] { devices }
}
final class FakeLogin: LoginItemControlling {
    var status: LoginItemStatus
    init(_ s: LoginItemStatus) { status = s }
    func register() throws {}
    func unregister() throws {}
    func openSystemSettings() {}
}
struct Provider: AudioDeviceProvider {
    let devices: [Fake]
    var outputDevices: [AudioOutputDevice] { devices }
}

@MainActor func render(scheme: ColorScheme, login: LoginItemStatus, to path: String) {
    let provider = Provider(devices: [
        Fake("MacBook Pro Speakers", 1, .builtIn, def: true),
        Fake("AirPods Pro", 2, .bluetooth),
        Fake("Living Room HomePod", 3, .airPlay),
        Fake("USB DAC", 4, .usb),
        Fake("LG UltraFine", 5, .hdmiDisplayPort),
        Fake("Aggregate Device", 6, .other),
    ])
    let suite = UserDefaults(suiteName: "render-\(UUID())")!
    let model = AudioMenuViewModel(provider: provider, stickyPreference: StickyPreference(defaults: suite),
                                   chosenPreference: nil, switchCounter: InMemorySwitchCounter(total: 42),
                                   inputProvider: InputProvider(devices: [
                                       FakeInput("MacBook Pro Microphone", 11, .builtIn, def: true),
                                       FakeInput("AirPods Pro", 12, .bluetooth),
                                       FakeInput("USB DAC", 14, .usb),
                                   ]),
                                   loginItem: FakeLogin(login))
    let view = AudioMenuView(model: model)
        .background(scheme == .dark ? Color(white: 0.16) : Color(white: 0.96))
        .environment(\.colorScheme, scheme)
    let r = ImageRenderer(content: view)
    r.scale = 2
    guard let img = r.nsImage, let tiff = img.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        print("ImageRenderer returned no image for \(scheme)"); exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) \(Int(img.size.width))x\(Int(img.size.height))pt")
}

MainActor.assumeIsolated {
    let out = CommandLine.arguments[1]
    render(scheme: .light, login: .enabled, to: "\(out)/popover-light.png")
    render(scheme: .dark, login: .enabled, to: "\(out)/popover-dark.png")
    render(scheme: .light, login: .requiresApproval, to: "\(out)/popover-light-requires-approval.png")
}
