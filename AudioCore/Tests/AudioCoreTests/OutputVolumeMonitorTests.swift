import XCTest
@testable import AudioCore

final class OutputVolumeMonitorTests: XCTestCase {
    var listening: FakeListening!
    var center: NotificationCenter!
    var defaultID: UInt32? = 10
    var monitor: OutputVolumeMonitor!
    let systemObject: UInt32 = 1

    override func setUp() {
        super.setUp()
        listening = FakeListening()
        center = NotificationCenter()
        defaultID = 10
        monitor = OutputVolumeMonitor(backend: listening, center: center,
                                      defaultDeviceID: { [unowned self] in self.defaultID },
                                      channelCount: { _ in 2 })
    }

    func testAttachesVolumeAndMuteListenersToTheDefaultDevice() {
        XCTAssertTrue(monitor.start())
        XCTAssertEqual(monitor.attachedDeviceID, 10)
        let keys = listening.live(on: 10).map(\.key)
        XCTAssertTrue(keys.contains(VolumeControl.mainVolumeKey))
        XCTAssertTrue(keys.contains(VolumeControl.virtualMainVolumeKey))
        XCTAssertTrue(keys.contains(VolumeControl.muteKey))
        XCTAssertTrue(keys.contains(VolumeControl.channelVolumeKey(1)))
        XCTAssertTrue(keys.contains(VolumeControl.channelVolumeKey(2)))
    }

    func testExternalVolumeOrMuteChangePostsNotification() {
        monitor.start()
        var posts = 0
        let token = center.addObserver(forName: .outputVolumeChanged, object: nil, queue: nil) { _ in posts += 1 }
        defer { center.removeObserver(token) }
        listening.live(on: 10).first { $0.key == VolumeControl.muteKey }?.handler()
        listening.live(on: 10).first { $0.key == VolumeControl.mainVolumeKey }?.handler()
        XCTAssertEqual(posts, 2)
    }

    func testDefaultChangeMovesListenersToTheNewDevice() {
        monitor.start()
        defaultID = 20
        listening.fire(on: systemObject)   // the default-output-device property changed
        XCTAssertEqual(monitor.attachedDeviceID, 20)
        XCTAssertTrue(listening.live(on: 10).isEmpty, "old device must be detached")
        XCTAssertFalse(listening.live(on: 20).isEmpty)
        XCTAssertEqual(listening.live(on: systemObject).count, 1)
    }

    func testOldDeviceNoLongerPostsAfterDefaultChange() {
        monitor.start()
        let old = listening.live(on: 10)
        defaultID = 20
        listening.fire(on: systemObject)
        var posts = 0
        let token = center.addObserver(forName: .outputVolumeChanged, object: nil, queue: nil) { _ in posts += 1 }
        defer { center.removeObserver(token) }
        XCTAssertTrue(old.allSatisfy(\.removed))
        listening.fire(on: 20)
        XCTAssertGreaterThan(posts, 0)
    }

    func testNoDefaultDeviceMeansNoDeviceListeners() {
        defaultID = nil
        monitor.start()
        XCTAssertNil(monitor.attachedDeviceID)
        XCTAssertEqual(listening.live.count, 1, "only the system default-device listener")
    }

    func testStartIsIdempotentAndStopRemovesEverything() {
        monitor.start(); monitor.start()
        XCTAssertEqual(listening.live(on: systemObject).count, 1)
        monitor.stop()
        XCTAssertTrue(listening.live.isEmpty)
        XCTAssertFalse(monitor.isRunning)
    }

    func testStartFailsWhenSystemListenerCannotBeAdded() {
        listening.unsupported = [systemObject]
        XCTAssertFalse(monitor.start())
        XCTAssertFalse(monitor.isRunning)
    }
}
