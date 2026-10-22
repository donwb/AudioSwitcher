import XCTest
@testable import AudioCore

/// Read-only checks against the machine's real audio devices.
/// These tests must NEVER change real audio state: no default-device, volume or mute writes.
final class LiveDeviceTests: XCTestCase {
    private var devices: [AudioOutputDevice] { NativeAudioProvider().outputDevices }

    func testExactlyOneDefaultOutputDevice() throws {
        let all = devices
        try XCTSkipIf(all.isEmpty, "no output devices on this machine")
        let defaults = all.filter { $0.isDefaultOutputDevice }
        XCTAssertEqual(defaults.count, 1, "defaults: \(defaults.map { $0.name })")
        XCTAssertEqual(defaults.first?.id, NativeCoreAudio.defaultOutputDeviceID())
    }

    func testVolumesAreWithinZeroToOneOrNil() {
        for d in devices {
            if let v = d.outputVolume() {
                XCTAssertTrue((0...1).contains(v), "\(d.name) volume \(v) out of range")
            }
        }
    }

    func testDeviceNamesAreNonEmpty() {
        for d in devices {
            XCTAssertFalse(d.name.isEmpty, "device \(d.id) has empty name")
        }
    }

    func testDeviceIDsAreUniqueAndListedIDsMatchOutputDeviceIDs() {
        let ids = devices.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(ids), Set(NativeCoreAudio.outputDeviceIDs()))
    }

    func testAudioStateLoadsLiveDevicesWithOneActive() throws {
        let state = AudioState.LoadAudioEnvironment(provider: NativeAudioProvider())
        try XCTSkipIf(state.Devices.isEmpty, "no output devices on this machine")
        XCTAssertEqual(state.Devices.filter { $0.enabled }.count, 1)
        XCTAssertNotNil(state.ActiveOutputDevice)
    }
}

/// Monitor tests: registering a listener is read-only, and the notification path is
/// exercised by invoking the handler directly (we never change the real default device).
final class DefaultOutputMonitorTests: XCTestCase {
    func testStartIsIdempotentAndStopRemovesListener() {
        let monitor = DefaultOutputDeviceMonitor(center: NotificationCenter())
        XCTAssertFalse(monitor.isRunning)
        XCTAssertTrue(monitor.start())
        XCTAssertTrue(monitor.start())
        XCTAssertTrue(monitor.isRunning)
        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testChangePostsNotification() {
        let center = NotificationCenter()
        let monitor = DefaultOutputDeviceMonitor(center: center)
        var count = 0
        let token = center.addObserver(forName: .defaultOutputDeviceChanged, object: nil, queue: nil) { _ in count += 1 }
        defer { center.removeObserver(token) }
        monitor.postChange()
        XCTAssertEqual(count, 1)
    }
}
