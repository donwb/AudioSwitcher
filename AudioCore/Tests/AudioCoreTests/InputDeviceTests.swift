import XCTest
@testable import AudioCore

final class FakeInputDevice: AudioInputDevice {
    let name: String
    let id: UInt32
    let transportType: AudioTransportType
    var onBecameDefault: ((FakeInputDevice) -> Void)?
    var isDefaultInputDevice: Bool {
        didSet { if isDefaultInputDevice && !oldValue { onBecameDefault?(self) } }
    }
    init(name: String, id: UInt32, isDefault: Bool = false, transport: AudioTransportType = .other) {
        self.name = name; self.id = id; self.transportType = transport; isDefaultInputDevice = isDefault
    }
}

final class FakeInputProvider: AudioInputDeviceProvider {
    var devices: [FakeInputDevice] {
        didSet { wire() }
    }
    init(_ devices: [FakeInputDevice]) { self.devices = devices; wire() }
    private func wire() {
        for d in devices {
            d.onBecameDefault = { [unowned self] new in
                for other in self.devices where other !== new { other.isDefaultInputDevice = false }
            }
        }
    }
    var inputDevices: [AudioInputDevice] { devices }
}

@MainActor
final class InputDeviceTests: XCTestCase {
    var output: FakeOutputDevice!
    var mic: FakeInputDevice!
    var buds: FakeInputDevice!
    var usb: FakeInputDevice!
    var inputs: FakeInputProvider!
    var center: NotificationCenter!
    var suiteName: String!
    var defaults: UserDefaults!
    var model: AudioMenuViewModel!

    override func setUp() {
        super.setUp()
        output = FakeOutputDevice(name: "Speakers", id: 1, isDefault: true)
        mic = FakeInputDevice(name: "MacBook Microphone", id: 20, isDefault: true, transport: .builtIn)
        buds = FakeInputDevice(name: "AirPods", id: 21, transport: .bluetooth)
        usb = FakeInputDevice(name: "USB Mic", id: 22, transport: .usb)
        inputs = FakeInputProvider([mic, buds, usb])
        center = NotificationCenter()
        suiteName = "InputDeviceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        model = AudioMenuViewModel(provider: FakeProvider([output]),
                                   stickyPreference: StickyPreference(defaults: defaults),
                                   chosenPreference: ChosenDevicePreference(defaults: defaults),
                                   switchCounter: InMemorySwitchCounter(),
                                   inputProvider: inputs, center: center)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testListsInputsWithTransportSymbolsAndDefaultCheckmark() {
        XCTAssertEqual(model.inputRows.map(\.name), ["AirPods", "MacBook Microphone", "USB Mic"])
        XCTAssertEqual(model.inputRows.map(\.symbolName), ["headphones", "laptopcomputer", "cable.connector"])
        XCTAssertEqual(model.inputRows.filter(\.isDefault).map(\.name), ["MacBook Microphone"])
    }

    func testClickingAnInputMakesItTheDefaultInput() throws {
        model.selectInput(try XCTUnwrap(model.inputRows.first { $0.name == "USB Mic" }))
        XCTAssertTrue(usb.isDefaultInputDevice)
        XCTAssertFalse(mic.isDefaultInputDevice)
        XCTAssertEqual(model.inputRows.filter(\.isDefault).map(\.name), ["USB Mic"])
        XCTAssertTrue(output.isDefaultOutputDevice, "output default untouched")
    }

    func testDefaultInputChangedElsewhereMovesTheCheckmark() {
        buds.isDefaultInputDevice = true
        XCTAssertEqual(model.inputRows.filter(\.isDefault).map(\.name), ["MacBook Microphone"], "stale until notified")
        center.post(name: .defaultInputDeviceChanged, object: nil)
        XCTAssertEqual(model.inputRows.filter(\.isDefault).map(\.name), ["AirPods"])
    }

    func testInputAddedAndRemovedShowUpOnDeviceListChange() {
        inputs.devices.append(FakeInputDevice(name: "Studio Mic", id: 30, transport: .usb))
        center.post(name: .audioDeviceListChanged, object: nil)
        XCTAssertTrue(model.inputRows.contains { $0.name == "Studio Mic" })
        inputs.devices.removeAll { $0.name == "AirPods" }
        center.post(name: .audioDeviceListChanged, object: nil)
        XCTAssertFalse(model.inputRows.contains { $0.name == "AirPods" })
    }

    func testChangingInputIsNotSticky() throws {
        model.setSticky(true)
        model.selectInput(try XCTUnwrap(model.inputRows.first { $0.name == "USB Mic" }))
        center.post(name: .defaultInputDeviceChanged, object: nil)
        mic.isDefaultInputDevice = true       // changed elsewhere
        center.post(name: .defaultInputDeviceChanged, object: nil)
        XCTAssertTrue(mic.isDefaultInputDevice, "Sticky never reverts the input")
        XCTAssertNotEqual(ChosenDevicePreference(defaults: defaults).deviceName, "USB Mic",
                          "an input is never recorded as the chosen output")
    }

    func testNoInputProviderMeansNoInputRows() {
        let plain = AudioMenuViewModel(provider: FakeProvider([output]),
                                       stickyPreference: StickyPreference(defaults: defaults),
                                       chosenPreference: nil, switchCounter: InMemorySwitchCounter(), center: center)
        XCTAssertTrue(plain.inputRows.isEmpty)
    }

    func testDefaultInputMonitorPostsOnlyThroughTheFakeBackend() {
        let listening = FakeListening()
        let monitor = DefaultInputDeviceMonitor(backend: listening, center: center)
        XCTAssertTrue(monitor.start())
        var posts = 0
        let t = center.addObserver(forName: .defaultInputDeviceChanged, object: nil, queue: nil) { _ in posts += 1 }
        defer { center.removeObserver(t) }
        listening.live.first?.handler()
        XCTAssertEqual(posts, 1)
        monitor.stop()
        XCTAssertTrue(listening.live.isEmpty)
    }
}
