import XCTest
@testable import AudioCore

@MainActor
final class ShortcutTests: XCTestCase {
    var a: FakeOutputDevice!, b: FakeOutputDevice!, c: FakeOutputDevice!
    var provider: FakeProvider!
    var center: NotificationCenter!
    var suiteName: String!
    var defaults: UserDefaults!
    var model: AudioMenuViewModel!

    override func setUp() {
        super.setUp()
        // List order is by name: Alpha, Bravo, Charlie.
        a = FakeOutputDevice(name: "Alpha", id: 3, isDefault: true)
        b = FakeOutputDevice(name: "Bravo", id: 2)
        c = FakeOutputDevice(name: "Charlie", id: 1)
        provider = FakeProvider([c, b, a])
        center = NotificationCenter()
        suiteName = "ShortcutTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        model = AudioMenuViewModel(provider: provider,
                                   stickyPreference: StickyPreference(defaults: defaults),
                                   chosenPreference: ChosenDevicePreference(defaults: defaults),
                                   switchCounter: InMemorySwitchCounter(), center: center)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private var defaultName: String? { model.rows.first(where: \.isDefault)?.name }

    // ⌘1...⌘9
    func testNumberSelectsTheNthOutputInListOrder() {
        model.selectOutput(number: 3)
        XCTAssertEqual(defaultName, "Charlie")
        XCTAssertTrue(c.isDefaultOutputDevice)
        model.selectOutput(number: 2)
        XCTAssertEqual(defaultName, "Bravo")
    }

    func testNumberOutOfRangeDoesNothing() {
        model.selectOutput(number: 0)
        model.selectOutput(number: 4)
        model.selectOutput(number: 9)
        XCTAssertEqual(defaultName, "Alpha")
    }

    // Hotkey
    func testNextOutputAdvancesInListOrderAndWraps() {
        model.selectNextOutput(); XCTAssertEqual(defaultName, "Bravo")
        model.selectNextOutput(); XCTAssertEqual(defaultName, "Charlie")
        model.selectNextOutput(); XCTAssertEqual(defaultName, "Alpha")
    }

    func testNextOutputSeesDevicesAddedWhilePopoverWasClosed() {
        provider.devices.append(FakeOutputDevice(name: "Beta", id: 9))   // no notification delivered
        model.selectNextOutput()
        XCTAssertEqual(defaultName, "Beta")
    }

    func testNextOutputWithOneDeviceStaysPut() {
        provider.devices = [a]
        model.refresh()
        model.selectNextOutput()
        XCTAssertEqual(defaultName, "Alpha")
    }

    func testNextOutputWithNoDevicesDoesNothing() {
        provider.devices = []
        model.refresh()
        model.selectNextOutput()
        XCTAssertTrue(model.rows.isEmpty)
    }

    func testHotkeyChoiceCountsAsChosenDeviceForSticky() {
        model.setSticky(true)
        model.selectNextOutput()                 // Bravo, chosen via the hotkey
        XCTAssertEqual(ChosenDevicePreference(defaults: defaults).deviceName, "Bravo")
        a.isDefaultOutputDevice = true           // something else steals the default
        center.post(name: .defaultOutputDeviceChanged, object: nil)
        XCTAssertTrue(b.isDefaultOutputDevice, "Sticky restores the hotkey's choice")
    }

    func testNumberChoiceAlsoCountsForSticky() {
        model.setSticky(true)
        model.selectOutput(number: 3)
        a.isDefaultOutputDevice = true
        center.post(name: .defaultOutputDeviceChanged, object: nil)
        XCTAssertTrue(c.isDefaultOutputDevice)
    }

    // Pure ordering
    func testOrderingHelpers() {
        let rows = (1...3).map { AudioDeviceRow(id: UInt32($0), name: "D\($0)", transportType: .other, isDefault: $0 == 3) }
        XCTAssertEqual(DeviceOrdering.next(in: rows)?.name, "D1")
        XCTAssertEqual(DeviceOrdering.next(in: rows.map { AudioDeviceRow(id: $0.id, name: $0.name, transportType: .other, isDefault: false) })?.name, "D1")
        XCTAssertNil(DeviceOrdering.next(in: []))
        XCTAssertEqual(DeviceOrdering.row(number: 2, in: rows)?.name, "D2")
        XCTAssertNil(DeviceOrdering.row(number: 4, in: rows))
    }
}
