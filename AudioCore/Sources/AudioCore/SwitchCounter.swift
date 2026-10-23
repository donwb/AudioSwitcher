import Foundation

/// Counts how many times the default output device has changed.
public protocol SwitchCounting: AnyObject {
    var total: Int { get }
    func increment()
}

public final class InMemorySwitchCounter: SwitchCounting {
    public private(set) var total: Int
    public init(total: Int = 0) { self.total = total }
    public func increment() { total += 1 }
}

/// Persists the count in a plist with the same `total` / `lastChange` keys the
/// app's existing Stats.plist uses, so an existing count carries over.
public final class PlistSwitchCounter: SwitchCounting {
    private let url: URL

    public init(url: URL) { self.url = url }

    private func read() -> NSMutableDictionary {
        NSMutableDictionary(contentsOf: url) ?? NSMutableDictionary()
    }

    public var total: Int { read()["total"] as? Int ?? 0 }

    public func increment() {
        let dict = read()
        dict["total"] = (dict["total"] as? Int ?? 0) + 1
        dict["lastChange"] = Date()
        dict.write(to: url, atomically: true)
    }
}
