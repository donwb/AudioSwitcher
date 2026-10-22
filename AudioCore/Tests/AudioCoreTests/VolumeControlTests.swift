import XCTest
import CoreAudio
@testable import AudioCore

/// In-memory property store. Never touches hardware.
final class FakePropertyStore: AudioPropertyStore {
    struct Entry { var float: Float?; var uint: UInt32?; var settable: Bool }
    var entries: [String: Entry] = [:]
    var writes: [String] = []

    private func k(_ key: AudioPropertyKey) -> String { "\(key.selector)/\(key.scope)/\(key.element)" }

    func addFloat(_ key: AudioPropertyKey, _ v: Float, settable: Bool = true) {
        entries[k(key)] = Entry(float: v, uint: nil, settable: settable)
    }
    func addUInt(_ key: AudioPropertyKey, _ v: UInt32, settable: Bool = true) {
        entries[k(key)] = Entry(float: nil, uint: v, settable: settable)
    }
    func current(_ key: AudioPropertyKey) -> Float? { entries[k(key)]?.float }

    func hasProperty(_ key: AudioPropertyKey) -> Bool { entries[k(key)] != nil }
    func isSettable(_ key: AudioPropertyKey) -> Bool { entries[k(key)]?.settable ?? false }
    func float(_ key: AudioPropertyKey) -> Float? { entries[k(key)]?.float }
    func setFloat(_ value: Float, for key: AudioPropertyKey) -> Bool {
        guard var e = entries[k(key)], e.settable else { return false }
        e.float = value; entries[k(key)] = e; writes.append(k(key)); return true
    }
    func uint32(_ key: AudioPropertyKey) -> UInt32? { entries[k(key)]?.uint }
    func setUInt32(_ value: UInt32, for key: AudioPropertyKey) -> Bool {
        guard var e = entries[k(key)], e.settable else { return false }
        e.uint = value; entries[k(key)] = e; return true
    }
}

final class VolumeControlTests: XCTestCase {
    let main = VolumeControl.mainVolumeKey
    let virtualMain = VolumeControl.virtualMainVolumeKey
    let ch1 = VolumeControl.channelVolumeKey(1)
    let ch2 = VolumeControl.channelVolumeKey(2)

    func testUsesMainVolumeWhenPresent() {
        let s = FakePropertyStore()
        s.addFloat(main, 0.3); s.addFloat(virtualMain, 0.9); s.addFloat(ch1, 0.7)
        XCTAssertEqual(VolumeControl(store: s, channelCount: 2).volume() ?? -1, 0.3, accuracy: 1e-6)
    }

    func testFallsBackToVirtualMainVolume() {
        let s = FakePropertyStore()   // e.g. Bluetooth/AirPlay: no element-0 scalar
        s.addFloat(virtualMain, 0.65); s.addFloat(ch1, 0.1)
        XCTAssertEqual(VolumeControl(store: s, channelCount: 2).volume() ?? -1, 0.65, accuracy: 1e-6)
    }

    func testFallsBackToAveragedPerChannelVolume() {
        let s = FakePropertyStore()
        s.addFloat(ch1, 0.2); s.addFloat(ch2, 0.6)
        XCTAssertEqual(VolumeControl(store: s, channelCount: 2).volume() ?? -1, 0.4, accuracy: 1e-6)
    }

    func testNilWhenNoVolumeControlAtAll() {
        XCTAssertNil(VolumeControl(store: FakePropertyStore(), channelCount: 2).volume())
        XCTAssertNil(VolumeControl(store: FakePropertyStore(), channelCount: 0).volume())
    }

    func testSetVolumeWritesMainOnlyWhenAvailable() {
        let s = FakePropertyStore()
        s.addFloat(main, 0.1); s.addFloat(virtualMain, 0.1); s.addFloat(ch1, 0.1)
        XCTAssertTrue(VolumeControl(store: s, channelCount: 2).setVolume(0.8))
        XCTAssertEqual(s.current(main) ?? -1, 0.8, accuracy: 1e-6)
        XCTAssertEqual(s.current(virtualMain) ?? -1, 0.1, accuracy: 1e-6)
        XCTAssertEqual(s.current(ch1) ?? -1, 0.1, accuracy: 1e-6)
    }

    func testSetVolumeSkipsUnsettableMainAndUsesVirtual() {
        let s = FakePropertyStore()
        s.addFloat(main, 0.1, settable: false); s.addFloat(virtualMain, 0.1)
        XCTAssertTrue(VolumeControl(store: s, channelCount: 2).setVolume(0.5))
        XCTAssertEqual(s.current(virtualMain) ?? -1, 0.5, accuracy: 1e-6)
    }

    func testSetVolumeFallsBackToEveryChannel() {
        let s = FakePropertyStore()
        s.addFloat(ch1, 0.1); s.addFloat(ch2, 0.1)
        XCTAssertTrue(VolumeControl(store: s, channelCount: 2).setVolume(0.9))
        XCTAssertEqual(s.current(ch1) ?? -1, 0.9, accuracy: 1e-6)
        XCTAssertEqual(s.current(ch2) ?? -1, 0.9, accuracy: 1e-6)
    }

    func testSetVolumeClampsAndReportsFailure() {
        let s = FakePropertyStore()
        s.addFloat(main, 0.5)
        let vc = VolumeControl(store: s, channelCount: 2)
        vc.setVolume(1.7)
        XCTAssertEqual(s.current(main) ?? -1, 1.0, accuracy: 1e-6)
        vc.setVolume(-3)
        XCTAssertEqual(s.current(main) ?? -1, 0.0, accuracy: 1e-6)
        XCTAssertFalse(VolumeControl(store: FakePropertyStore(), channelCount: 2).setVolume(0.5))
    }

    func testMuteState() {
        let s = FakePropertyStore()
        XCTAssertNil(VolumeControl(store: s, channelCount: 2).isMuted())
        s.addUInt(VolumeControl.muteKey, 1)
        XCTAssertEqual(VolumeControl(store: s, channelCount: 2).isMuted(), true)
        s.addUInt(VolumeControl.muteKey, 0)
        XCTAssertEqual(VolumeControl(store: s, channelCount: 2).isMuted(), false)
    }
}
