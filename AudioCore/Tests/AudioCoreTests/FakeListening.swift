import Foundation
@testable import AudioCore

/// Records listener registrations instead of touching CoreAudio.
final class FakeListening: AudioPropertyListening {
    final class Token {
        let object: UInt32
        let key: AudioPropertyKey
        let handler: () -> Void
        var removed = false
        init(object: UInt32, key: AudioPropertyKey, handler: @escaping () -> Void) {
            self.object = object; self.key = key; self.handler = handler
        }
    }
    var tokens: [Token] = []
    /// Objects whose properties "don't exist" (listener not attachable).
    var unsupported: Set<UInt32> = []

    var live: [Token] { tokens.filter { !$0.removed } }
    func live(on object: UInt32) -> [Token] { live.filter { $0.object == object } }

    func addListener(object: UInt32, key: AudioPropertyKey, handler: @escaping () -> Void) -> AnyObject? {
        guard !unsupported.contains(object) else { return nil }
        let t = Token(object: object, key: key, handler: handler)
        tokens.append(t)
        return t
    }
    func removeListener(_ token: AnyObject) { (token as? Token)?.removed = true }

    /// Fires every live listener on `object`, like CoreAudio would.
    func fire(on object: UInt32) { live(on: object).forEach { $0.handler() } }
}
