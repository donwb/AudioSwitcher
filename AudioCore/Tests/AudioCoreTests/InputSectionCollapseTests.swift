import XCTest
@testable import AudioCore

@MainActor
final class InputSectionCollapseTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "InputSectionCollapseTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func makeModel(withPreference: Bool = true) -> AudioMenuViewModel {
        AudioMenuViewModel(provider: FakeProvider([FakeOutputDevice(name: "Speakers", id: 1, isDefault: true)]),
                           stickyPreference: StickyPreference(defaults: defaults),
                           chosenPreference: ChosenDevicePreference(defaults: defaults),
                           switchCounter: InMemorySwitchCounter(),
                           inputProvider: FakeInputProvider([FakeInputDevice(name: "Mic", id: 20, isDefault: true)]),
                           inputSectionPreference: withPreference ? InputSectionPreference(defaults: defaults) : nil,
                           center: NotificationCenter())
    }

    func testPreferenceDefaultsToCollapsed() {
        XCTAssertFalse(InputSectionPreference(defaults: defaults).isExpanded)
    }

    func testModelStartsCollapsed() {
        XCTAssertFalse(makeModel().isInputSectionExpanded)
    }

    func testExpandAndCollapseToggleState() {
        let model = makeModel()
        model.setInputSectionExpanded(true)
        XCTAssertTrue(model.isInputSectionExpanded)
        model.setInputSectionExpanded(false)
        XCTAssertFalse(model.isInputSectionExpanded)
    }

    func testExpandedStatePersistsToNextLaunch() {
        makeModel().setInputSectionExpanded(true)
        XCTAssertTrue(makeModel().isInputSectionExpanded)
    }

    func testCollapsingDoesNotDropInputRows() {
        let model = makeModel()
        model.setInputSectionExpanded(true)
        model.setInputSectionExpanded(false)
        XCTAssertEqual(model.inputRows.map(\.name), ["Mic"])
    }

    func testWorksWithoutPreferenceStore() {
        let model = makeModel(withPreference: false)
        model.setInputSectionExpanded(true)
        XCTAssertTrue(model.isInputSectionExpanded)
    }
}
