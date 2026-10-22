import Foundation

/// Persists the Sticky checkbox state between launches.
public struct StickyPreference {
    public static let key = "stickyEnabled"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saved state; defaults to on when nothing has been saved yet.
    public var isOn: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
