import XCTest
@testable import AudioCore

final class FakeOutputDevice: AudioOutputDevice {
    let name: String
    let id: UInt32
    let transportType: AudioTransportType
    /// Like CoreAudio, only one device can be the default; the provider enforces it.
    var onBecameDefault: ((FakeOutputDevice) -> Void)?
    var isDefaultOutputDevice: Bool {
        didSet { if isDefaultOutputDevice && !oldValue { onBecameDefault?(self) } }
    }
    var volume: Float?
    var muted: Bool?

    init(name: String, id: UInt32, isDefault: Bool = false, volume: Float? = 0.5, muted: Bool? = false,
         transport: AudioTransportType = .other) {
        self.transportType = transport
        self.name = name
        self.id = id
        self.isDefaultOutputDevice = isDefault
        self.volume = volume
        self.muted = muted
    }

    func setOutputVolume(_ volume: Float) { self.volume = volume }
    func outputVolume() -> Float? { volume }
    func isOutputMuted() -> Bool? { muted }
}

final class FakeProvider: AudioDeviceProvider {
    var devices: [FakeOutputDevice]
    init(_ devices: [FakeOutputDevice]) {
        self.devices = devices
        for d in devices {
            d.onBecameDefault = { [unowned self] new in
                for other in self.devices where other !== new { other.isDefaultOutputDevice = false }
            }
        }
    }
    var outputDevices: [AudioOutputDevice] { devices }
}

final class AudioStateTests: XCTestCase {
    var speakers: FakeOutputDevice!
    var headphones: FakeOutputDevice!
    var hifi: FakeOutputDevice!
    var provider: FakeProvider!
    var state: AudioState!

    override func setUp() {
        super.setUp()
        speakers = FakeOutputDevice(name: "Speakers", id: 30, isDefault: true)
        headphones = FakeOutputDevice(name: "Headphones", id: 10)
        hifi = FakeOutputDevice(name: "HIFI DSD", id: 77)
        provider = FakeProvider([speakers, headphones, hifi])
        state = AudioState.LoadAudioEnvironment(provider: provider)
    }

    private func device(_ name: String) throws -> MyAudioDevice {
        try XCTUnwrap(state.Devices.first { $0.name == name })
    }

    // Listing
    func testListsAllOutputDevicesActiveFirstThenById() {
        XCTAssertEqual(state.Devices.map { $0.name }, ["Speakers", "Headphones", "HIFI DSD"])
    }

    func testEmptyProviderYieldsNoDevicesAndNoActive() {
        let empty = AudioState.LoadAudioEnvironment(provider: FakeProvider([]))
        XCTAssertTrue(empty.Devices.isEmpty)
        XCTAssertNil(empty.ActiveOutputDevice)
    }

    func testReloadPicksUpAddedAndRemovedDevices() {
        provider.devices.append(FakeOutputDevice(name: "USB DAC", id: 5))
        XCTAssertEqual(state.Devices.count, 3, "no change until reload")
        state.reload()
        XCTAssertEqual(state.Devices.count, 4)
        provider.devices.removeAll { $0.name == "Headphones" }
        state.reload()
        XCTAssertEqual(state.Devices.map { $0.name }, ["Speakers", "USB DAC", "HIFI DSD"])
    }

    // Picking output
    func testActiveDeviceIsTheSystemDefault() {
        XCTAssertEqual(state.ActiveOutputDevice?.name, "Speakers")
        XCTAssertEqual(state.Devices.filter { $0.enabled }.count, 1)
    }

    func testNoDefaultDeviceMeansNoActiveDevice() {
        speakers.isDefaultOutputDevice = false
        state.reload()
        XCTAssertNil(state.ActiveOutputDevice)
    }

    func testMakeActiveSetsDefaultAndMovesDeviceToFront() throws {
        state.MakeActiveOutputDevice(device: try device("Headphones"))
        XCTAssertTrue(headphones.isDefaultOutputDevice)
        XCTAssertEqual(state.ActiveOutputDevice?.name, "Headphones")
        XCTAssertEqual(state.Devices.first?.name, "Headphones")
    }

    func testMakeActiveWithUnknownDeviceChangesNothing() {
        state.MakeActiveOutputDevice(device: MyAudioDevice(name: "Ghost", id: 9, enabled: false))
        XCTAssertEqual(state.ActiveOutputDevice?.name, "Speakers")
    }

    // Sticky (fake provider only; never touches real devices)
    func testStickyRevertsToChosenDevice() {
        state.SetSticky(true)               // chosen = Speakers
        headphones.isDefaultOutputDevice = true   // external change
        XCTAssertTrue(state.HandleDefaultOutputChanged())
        XCTAssertTrue(speakers.isDefaultOutputDevice)
        XCTAssertEqual(state.ActiveOutputDevice?.name, "Speakers")
    }

    func testStickyOffDoesNotRevert() {
        state.SetSticky(true)
        state.SetSticky(false)
        headphones.isDefaultOutputDevice = true
        XCTAssertFalse(state.HandleDefaultOutputChanged())
        XCTAssertEqual(state.ActiveOutputDevice?.name, "Headphones")
    }

    func testStickyDoesNothingWhenChosenDeviceMissing() {
        state.SetSticky(true)
        provider.devices.removeAll { $0 === speakers }
        headphones.isDefaultOutputDevice = true
        XCTAssertFalse(state.HandleDefaultOutputChanged())
        XCTAssertEqual(state.ActiveOutputDevice?.name, "Headphones")
    }

    func testStickyDoesNotRevertChangeMadeFromApp() throws {
        state.SetSticky(true)
        state.MakeActiveOutputDevice(device: try device("Headphones"))
        XCTAssertFalse(state.HandleDefaultOutputChanged())
        XCTAssertTrue(headphones.isDefaultOutputDevice)
        XCTAssertEqual(state.ChosenDeviceName, "Headphones")
        // later external change reverts to the app-chosen device
        hifi.isDefaultOutputDevice = true
        XCTAssertTrue(state.HandleDefaultOutputChanged())
        XCTAssertTrue(headphones.isDefaultOutputDevice)
    }

    func testTurningStickyOnCapturesCurrentDefault() {
        headphones.isDefaultOutputDevice = true   // changed outside app, before Sticky
        state.SetSticky(true)
        XCTAssertEqual(state.ChosenDeviceName, "Headphones")
    }

    // Volume
    func testSetVolumeAffectsOnlySelectedDevice() throws {
        state.ChangeDeviceVolue(selectedDevice: try device("Headphones"), volume: 0.8)
        XCTAssertEqual(try XCTUnwrap(headphones.volume), 0.8, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(speakers.volume), 0.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(hifi.volume), 0.5, accuracy: 0.0001)
    }

    func testGetVolumeReadsDeviceValue() throws {
        headphones.volume = 0.25
        XCTAssertEqual(try XCTUnwrap(state.GetVolumeLevel(selectedDevice: try device("Headphones"))), 0.25, accuracy: 0.0001)
    }

    func testSetThenGetVolumeRoundTrips() throws {
        let hp = try device("Headphones")
        state.ChangeDeviceVolue(selectedDevice: hp, volume: 0.6)
        XCTAssertEqual(try XCTUnwrap(state.GetVolumeLevel(selectedDevice: hp)), 0.6, accuracy: 0.0001)
    }

    func testGetVolumeNilWhenDeviceHasNoVolumeControl() throws {
        headphones.volume = nil
        XCTAssertNil(state.GetVolumeLevel(selectedDevice: try device("Headphones")))
    }

    func testVolumeOperationsOnUnknownDeviceAreSafe() {
        let ghost = MyAudioDevice(name: "Ghost", id: 999, enabled: false)
        XCTAssertNil(state.GetVolumeLevel(selectedDevice: ghost))
        state.ChangeDeviceVolue(selectedDevice: ghost, volume: 1.0)
        XCTAssertEqual(speakers.volume, 0.5)
        XCTAssertEqual(headphones.volume, 0.5)
        XCTAssertEqual(hifi.volume, 0.5)
    }

    // Mute
    func testMuteStateReadFromDevice() throws {
        headphones.muted = true
        XCTAssertTrue(state.IsDeviceMuted(selectedDevice: try device("Headphones")))
        XCTAssertFalse(state.IsDeviceMuted(selectedDevice: try device("Speakers")))
    }

    func testMuteDefaultsToFalseWhenUnsupportedOrUnknown() throws {
        headphones.muted = nil
        XCTAssertFalse(state.IsDeviceMuted(selectedDevice: try device("Headphones")))
        XCTAssertFalse(state.IsDeviceMuted(selectedDevice: MyAudioDevice(name: "Ghost", id: 1, enabled: false)))
    }

    func testMyAudioDeviceCodableRoundTrip() throws {
        let original = MyAudioDevice(name: "Speakers", id: 42, enabled: true)
        let decoded = try JSONDecoder().decode(MyAudioDevice.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }
}
