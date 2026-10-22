import Foundation

/// Persists the name of the last device the user chose, between launches.
public struct ChosenDevicePreference {
    public static let key = "lastChosenDeviceName"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var deviceName: String? {
        get { defaults.string(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
