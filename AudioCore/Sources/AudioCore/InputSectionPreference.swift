import Foundation

/// Persists whether the Input section of the menu is expanded. Collapsed by default,
/// since most people only switch output devices.
public struct InputSectionPreference {
    public static let key = "inputSectionExpanded"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isExpanded: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
