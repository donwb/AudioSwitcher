import XCTest
@testable import AudioCore

final class StickyPreferenceTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "StickyPreferenceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsToOnWhenNothingSaved() {
        XCTAssertTrue(StickyPreference(defaults: defaults).isOn)
    }

    func testOffPersistsAcrossInstances() {
        StickyPreference(defaults: defaults).isOn = false
        XCTAssertFalse(StickyPreference(defaults: defaults).isOn)
    }

    func testOnPersistsAfterBeingOff() {
        StickyPreference(defaults: defaults).isOn = false
        StickyPreference(defaults: defaults).isOn = true
        XCTAssertTrue(StickyPreference(defaults: defaults).isOn)
    }
}
