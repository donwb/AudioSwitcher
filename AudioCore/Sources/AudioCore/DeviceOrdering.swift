import Foundation

/// Pure ordering/selection rules for the output list (shortcuts and hotkey).
public enum DeviceOrdering {
    /// The row after the default one, in list order, wrapping at the end.
    /// With no default row, the first row. Nil for an empty list.
    public static func next(in rows: [AudioDeviceRow]) -> AudioDeviceRow? {
        guard !rows.isEmpty else { return nil }
        guard let current = rows.firstIndex(where: \.isDefault) else { return rows[0] }
        return rows[(current + 1) % rows.count]
    }

    /// The Nth row (1-based, as in ⌘1...⌘9), nil when out of range.
    public static func row(number: Int, in rows: [AudioDeviceRow]) -> AudioDeviceRow? {
        guard number >= 1, number <= rows.count else { return nil }
        return rows[number - 1]
    }
}
