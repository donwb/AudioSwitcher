import XCTest
@testable import AudioCore

final class ChosenDevicePersistenceTests: XCTestCase {
    private func makeProvider() -> FakeProvider {
        FakeProvider([FakeOutputDevice(name: "Speakers", id: 30, isDefault: true),
                      FakeOutputDevice(name: "Headphones", id: 10)])
    }

    func testChosenDeviceSurvivesRelaunch() {
        let defaults = UserDefaults(suiteName: "chosen-\(UUID())")!
        let pref = ChosenDevicePreference(defaults: defaults)

        let first = AudioState.LoadAudioEnvironment(provider: makeProvider(), chosenPreference: pref)
        first.MakeActiveOutputDevice(device: first.Devices.first { $0.name == "Headphones" }!)

        // "Relaunch": system default has reverted to Speakers.
        let second = AudioState.LoadAudioEnvironment(provider: makeProvider(), chosenPreference: pref)
        XCTAssertEqual(second.ActiveOutputDevice?.name, "Speakers")
        XCTAssertTrue(second.RestoreChosenDevice())
        XCTAssertEqual(second.ActiveOutputDevice?.name, "Headphones")
    }

    func testMissingDeviceIsIgnored() {
        let defaults = UserDefaults(suiteName: "chosen-\(UUID())")!
        let pref = ChosenDevicePreference(defaults: defaults)
        pref.deviceName = "Unplugged"
        let s = AudioState.LoadAudioEnvironment(provider: makeProvider(), chosenPreference: pref)
        XCTAssertFalse(s.RestoreChosenDevice())
        XCTAssertEqual(s.ActiveOutputDevice?.name, "Speakers")
    }
}
