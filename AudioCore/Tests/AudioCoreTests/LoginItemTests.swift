import XCTest
@testable import AudioCore

final class FakeLoginItem: LoginItemControlling {
    struct Failure: LocalizedError { var errorDescription: String? { "boom" } }
    var status: LoginItemStatus = .disabled
    /// Status after a successful register(), e.g. .requiresApproval.
    var statusAfterRegister: LoginItemStatus = .enabled
    var failNext = false
    var registerCalls = 0, unregisterCalls = 0, settingsOpened = 0

    func register() throws {
        registerCalls += 1
        if failNext { failNext = false; throw Failure() }
        status = statusAfterRegister
    }
    func unregister() throws {
        unregisterCalls += 1
        if failNext { failNext = false; throw Failure() }
        status = .disabled
    }
    func openSystemSettings() { settingsOpened += 1 }
}

@MainActor
final class LoginItemTests: XCTestCase {
    var login: FakeLoginItem!
    var suiteName: String!
    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        login = FakeLoginItem()
        suiteName = "LoginItemTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeModel(loginItem: LoginItemControlling?) -> AudioMenuViewModel {
        AudioMenuViewModel(provider: FakeProvider([FakeOutputDevice(name: "Speakers", id: 1, isDefault: true)]),
                           stickyPreference: StickyPreference(defaults: defaults),
                           chosenPreference: nil, switchCounter: InMemorySwitchCounter(),
                           loginItem: loginItem, center: NotificationCenter())
    }

    func testShowsTheRealStatusAtLaunchAndWhenThePopoverOpens() {
        login.status = .enabled
        let model = makeModel(loginItem: login)
        XCTAssertTrue(model.isLaunchAtLoginOn)
        login.status = .disabled          // user removed it in System Settings meanwhile
        model.refresh()                   // what the popover's onAppear calls
        XCTAssertFalse(model.isLaunchAtLoginOn)
        XCTAssertEqual(model.loginItemStatus, .disabled)
    }

    func testTurningOnRegistersAndTurningOffUnregisters() {
        let model = makeModel(loginItem: login)
        model.setLaunchAtLogin(true)
        XCTAssertEqual(login.registerCalls, 1)
        XCTAssertTrue(model.isLaunchAtLoginOn)
        XCTAssertNil(model.launchAtLoginDetail)
        model.setLaunchAtLogin(false)
        XCTAssertEqual(login.unregisterCalls, 1)
        XCTAssertFalse(model.isLaunchAtLoginOn)
    }

    func testRequiresApprovalIsShownAsPendingNotAsPlainOn() {
        login.statusAfterRegister = .requiresApproval
        let model = makeModel(loginItem: login)
        model.setLaunchAtLogin(true)
        XCTAssertEqual(model.loginItemStatus, .requiresApproval)
        XCTAssertTrue(model.isLaunchAtLoginOn)
        XCTAssertEqual(model.launchAtLoginDetail, "Requires approval in System Settings")
        model.openLoginItemSettings()
        XCTAssertEqual(login.settingsOpened, 1)
    }

    func testRequiresApprovalIsShownWhenPopoverOpens() {
        login.status = .requiresApproval
        let model = makeModel(loginItem: login)
        XCTAssertEqual(model.launchAtLoginDetail, "Requires approval in System Settings")
    }

    func testFailureShowsTheErrorAndKeepsTheRealStatus() {
        let model = makeModel(loginItem: login)
        login.failNext = true
        model.setLaunchAtLogin(true)
        XCTAssertEqual(model.launchAtLoginDetail, "boom")
        XCTAssertFalse(model.isLaunchAtLoginOn, "toggle reflects the real status, not the click")
        model.refresh()
        XCTAssertNil(model.loginItemError)
    }

    func testNotFoundIsReportedAsUnavailable() {
        login.status = .notFound
        let model = makeModel(loginItem: login)
        XCTAssertFalse(model.isLaunchAtLoginOn)
        XCTAssertEqual(model.launchAtLoginDetail, "Unavailable for this build")
    }

    func testWithoutALoginItemBackendTheToggleIsHiddenAndInert() {
        let model = makeModel(loginItem: nil)
        XCTAssertFalse(model.isLaunchAtLoginAvailable)
        model.setLaunchAtLogin(true)
        XCTAssertFalse(model.isLaunchAtLoginOn)
    }
}
