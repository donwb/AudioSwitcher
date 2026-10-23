import Foundation
import ServiceManagement

/// State of the "Launch at login" registration, mirroring `SMAppService.Status`.
public enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    /// Registered, but the user still has to allow it in System Settings > Login Items.
    case requiresApproval
    /// The service couldn't be found (typically an unsigned or relocated build).
    case notFound
}

/// The slice of `SMAppService.mainApp` the app needs. The view model only sees
/// this, so tests use a fake and never register a real login item.
public protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    /// Opens System Settings at Login Items (for the "requires approval" case).
    func openSystemSettings()
}

/// The real thing. Only the app wires this in; tests must never instantiate it.
public struct SMAppServiceLoginItem: LoginItemControlling {
    public init() {}

    public var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .disabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    public func register() throws { try SMAppService.mainApp.register() }
    public func unregister() throws { try SMAppService.mainApp.unregister() }
    public func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
