import XCTest
import CoreAudio
@testable import AudioCore

@MainActor
final class AudioMenuViewModelTests: XCTestCase {
    var speakers: FakeOutputDevice!
    var buds: FakeOutputDevice!
    var tv: FakeOutputDevice!
    var provider: FakeProvider!
    var center: NotificationCenter!
    var suiteName: String!
    var defaults: UserDefaults!
    var counter: InMemorySwitchCounter!
    var model: AudioMenuViewModel!

    override func setUp() {
        super.setUp()
        speakers = FakeOutputDevice(name: "MacBook Speakers", id: 30, isDefault: true, transport: .builtIn)
        buds = FakeOutputDevice(name: "AirPods", id: 10, transport: .bluetooth)
        tv = FakeOutputDevice(name: "TV", id: 77, volume: nil, transport: .hdmiDisplayPort)
        provider = FakeProvider([speakers, buds, tv])
        center = NotificationCenter()
        suiteName = "AudioMenuViewModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        counter = InMemorySwitchCounter()
        model = makeModel()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeModel() -> AudioMenuViewModel {
        AudioMenuViewModel(provider: provider,
                           stickyPreference: StickyPreference(defaults: defaults),
                           chosenPreference: ChosenDevicePreference(defaults: defaults),
                           switchCounter: counter, center: center)
    }

    private func row(_ name: String) throws -> AudioDeviceRow {
        try XCTUnwrap(model.rows.first { $0.name == name })
    }

    /// Simulates what CoreAudio's monitor does after the default changed.
    private func postDefaultChanged() { center.post(name: .defaultOutputDeviceChanged, object: nil) }
    private func postListChanged() { center.post(name: .audioDeviceListChanged, object: nil) }

    // List and checkmark
    func testListsDevicesWithTransportAndSymbolSortedByName() {
        XCTAssertEqual(model.rows.map(\.name), ["AirPods", "MacBook Speakers", "TV"])
        XCTAssertEqual(model.rows.map(\.transportType), [.bluetooth, .builtIn, .hdmiDisplayPort])
        XCTAssertEqual(model.rows.map(\.symbolName), ["headphones", "laptopcomputer", "display"])
    }

    func testOnlyTheDefaultDeviceIsChecked() {
        XCTAssertEqual(model.rows.filter(\.isDefault).map(\.name), ["MacBook Speakers"])
    }

    func testOrderDoesNotChangeWhenDefaultChanges() throws {
        model.select(try row("TV"))
        XCTAssertEqual(model.rows.map(\.name), ["AirPods", "MacBook Speakers", "TV"])
    }

    // Selecting
    func testSelectingADeviceMakesItDefaultAndMovesTheCheckmark() throws {
        model.select(try row("AirPods"))
        XCTAssertTrue(buds.isDefaultOutputDevice)
        XCTAssertFalse(speakers.isDefaultOutputDevice)
        XCTAssertEqual(model.rows.filter(\.isDefault).map(\.name), ["AirPods"])
    }

    // Volume
    func testVolumeReflectsDefaultDeviceAndIsEnabled() {
        speakers.volume = 0.25
        model.refresh()
        XCTAssertTrue(model.hasVolumeControl)
        XCTAssertEqual(model.volume, 0.25, accuracy: 0.001)
    }

    func testSettingVolumeWritesToTheDefaultDeviceOnly() {
        model.setVolume(0.8)
        XCTAssertEqual(speakers.volume ?? -1, 0.8, accuracy: 0.001)
        XCTAssertEqual(buds.volume ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(model.volume, 0.8, accuracy: 0.001)
    }

    func testVolumeIsClamped() {
        model.setVolume(3)
        XCTAssertEqual(speakers.volume, 1)
    }

    func testDeviceWithoutVolumeControlDisablesSliderAndIgnoresWrites() throws {
        model.select(try row("TV"))
        XCTAssertFalse(model.hasVolumeControl)
        model.setVolume(0.9)
        XCTAssertNil(tv.volume)
        XCTAssertEqual(model.volume, 0)
    }

    func testVolumeFollowsSelection() throws {
        buds.volume = 0.1
        model.select(try row("AirPods"))
        XCTAssertEqual(model.volume, 0.1, accuracy: 0.001)
    }

    // Sticky
    func testStickyDefaultsOnAndTogglePersists() {
        XCTAssertTrue(model.isSticky)
        model.setSticky(false)
        XCTAssertFalse(model.isSticky)
        XCTAssertFalse(StickyPreference(defaults: defaults).isOn)
        XCTAssertFalse(makeModel().isSticky, "a new model starts from the saved value")
        model.setSticky(true)
        XCTAssertTrue(StickyPreference(defaults: defaults).isOn)
    }

    func testStickyOnRevertsExternalDefaultChange() {
        buds.isDefaultOutputDevice = true   // changed elsewhere
        postDefaultChanged()
        XCTAssertTrue(speakers.isDefaultOutputDevice)
        XCTAssertEqual(model.rows.filter(\.isDefault).map(\.name), ["MacBook Speakers"])
    }

    func testStickyOffFollowsExternalDefaultChange() {
        model.setSticky(false)
        buds.isDefaultOutputDevice = true
        postDefaultChanged()
        XCTAssertEqual(model.rows.filter(\.isDefault).map(\.name), ["AirPods"])
    }

    // Live updates
    func testDeviceAddedAppearsWithoutRefresh() {
        provider.devices.append(FakeOutputDevice(name: "USB DAC", id: 5, transport: .usb))
        postListChanged()
        XCTAssertEqual(model.rows.map(\.name), ["AirPods", "MacBook Speakers", "TV", "USB DAC"])
        XCTAssertEqual(model.rows.last?.symbolName, "cable.connector")
    }

    func testDeviceRemovedDisappears() {
        provider.devices.removeAll { $0 === buds }
        postListChanged()
        XCTAssertEqual(model.rows.map(\.name), ["MacBook Speakers", "TV"])
    }

    func testDefaultRemovedLeavesNoCheckmarkAndNoVolume() {
        provider.devices.removeAll { $0 === speakers }
        postListChanged()
        XCTAssertTrue(model.rows.allSatisfy { !$0.isDefault })
        XCTAssertFalse(model.hasVolumeControl)
    }

    func testDefaultChangedElsewhereMovesCheckmarkAndVolume() {
        model.setSticky(false)
        buds.volume = 0.6
        buds.isDefaultOutputDevice = true
        postDefaultChanged()
        XCTAssertEqual(model.rows.filter(\.isDefault).map(\.name), ["AirPods"])
        XCTAssertEqual(model.volume, 0.6, accuracy: 0.001)
    }

    // Switch count
    func testSwitchCountIncrementsOnDefaultChange() {
        XCTAssertEqual(model.switchCount, 0)
        postDefaultChanged()
        XCTAssertEqual(model.switchCount, 1)
        postListChanged()
        XCTAssertEqual(model.switchCount, 1, "list changes are not switches")
    }

    func testPlistSwitchCounterPersistsAndKeepsExistingTotal() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Stats-\(UUID()).plist")
        defer { try? FileManager.default.removeItem(at: url) }
        try (["total": 41] as NSDictionary).write(to: url)
        let c = PlistSwitchCounter(url: url)
        XCTAssertEqual(c.total, 41)
        c.increment()
        XCTAssertEqual(PlistSwitchCounter(url: url).total, 42)
        XCTAssertEqual(PlistSwitchCounter(url: url.appendingPathExtension("missing")).total, 0)
    }

    // Transport mapping
    func testSymbolForEachTransportType() {
        XCTAssertEqual(AudioTransportType.builtIn.symbolName, "laptopcomputer")
        XCTAssertEqual(AudioTransportType.bluetooth.symbolName, "headphones")
        XCTAssertEqual(AudioTransportType.airPlay.symbolName, "airplayaudio")
        XCTAssertEqual(AudioTransportType.usb.symbolName, "cable.connector")
        XCTAssertEqual(AudioTransportType.hdmiDisplayPort.symbolName, "display")
        XCTAssertEqual(AudioTransportType.other.symbolName, "speaker.wave.2")
        XCTAssertEqual(Set(AudioTransportType.allCases.map(\.symbolName)).count, AudioTransportType.allCases.count)
    }

    func testCoreAudioTransportValuesMapToTypes() {
        let cases: [(UInt32, AudioTransportType)] = [
            (kAudioDeviceTransportTypeBuiltIn, .builtIn),
            (kAudioDeviceTransportTypeBluetooth, .bluetooth),
            (kAudioDeviceTransportTypeBluetoothLE, .bluetooth),
            (kAudioDeviceTransportTypeAirPlay, .airPlay),
            (kAudioDeviceTransportTypeUSB, .usb),
            (kAudioDeviceTransportTypeHDMI, .hdmiDisplayPort),
            (kAudioDeviceTransportTypeDisplayPort, .hdmiDisplayPort),
            (kAudioDeviceTransportTypeVirtual, .other),
            (kAudioDeviceTransportTypeAggregate, .other),
            (0, .other),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(AudioTransportType(coreAudioValue: raw), expected, "raw \(raw)")
        }
    }
}
