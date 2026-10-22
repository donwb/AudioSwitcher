import XCTest
import SimplyCoreAudio
@testable import AudioCore

/// Read-only comparison of our CoreAudio wrapper against SimplyCoreAudio on the
/// machine's real devices. These tests must NEVER write to hardware: no default
/// device changes, no volume or mute writes. Writes are tested against fakes only.
final class ParityTests: XCTestCase {
    let sca = SimplyCoreAudio()

    func testOutputDeviceIDsMatch() {
        let ours = Set(NativeCoreAudio.outputDeviceIDs())
        let theirs = Set(sca.allOutputDevices.map { $0.id })
        XCTAssertEqual(ours, theirs)
    }

    func testDeviceNamesMatch() {
        let theirs = sca.allOutputDevices
        for d in theirs {
            XCTAssertEqual(NativeAudioDevice(id: d.id).name, d.name, "name mismatch for id \(d.id)")
        }
    }

    func testDefaultOutputDeviceMatches() {
        XCTAssertEqual(NativeCoreAudio.defaultOutputDeviceID(), sca.defaultOutputDevice?.id)
        for d in sca.allOutputDevices {
            XCTAssertEqual(NativeAudioDevice(id: d.id).isDefaultOutputDevice, d.isDefaultOutputDevice,
                           "default flag mismatch for \(d.name)")
        }
    }

    func testProviderListsSameDevicesAsSimplyCoreAudio() {
        let ours = NativeAudioProvider().outputDevices.map { "\($0.id):\($0.name)" }.sorted()
        let theirs = sca.allOutputDevices.map { "\($0.id):\($0.name)" }.sorted()
        XCTAssertEqual(ours, theirs)
    }

    func testVolumeReadsAgreeWhereSimplyCoreAudioHasAValue() {
        for d in sca.allOutputDevices {
            let ours = NativeAudioDevice(id: d.id).outputVolume()
            if let theirs = d.volumeInfo(channel: 0, scope: .output)?.volume {
                guard let ours = ours else {
                    XCTFail("\(d.name): SimplyCoreAudio reports \(theirs) but ours is nil"); continue
                }
                XCTAssertEqual(ours, theirs, accuracy: 0.001, "volume mismatch for \(d.name)")
            }
            // Where SimplyCoreAudio has no channel-0 volume, our fallbacks may legitimately
            // return a value (that is the point), so nothing is asserted for that case.
        }
    }

    func testMuteReadsAgree() {
        for d in sca.allOutputDevices {
            XCTAssertEqual(NativeAudioDevice(id: d.id).isOutputMuted(),
                           d.isMuted(channel: 0, scope: .output),
                           "mute mismatch for \(d.name)")
        }
    }
}
