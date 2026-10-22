import Foundation
import CoreAudio

/// Identifies a CoreAudio property on an audio object.
public struct AudioPropertyKey: Equatable {
    public var selector: AudioObjectPropertySelector
    public var scope: AudioObjectPropertyScope
    public var element: AudioObjectPropertyElement

    public init(_ selector: AudioObjectPropertySelector,
                scope: AudioObjectPropertyScope,
                element: AudioObjectPropertyElement) {
        self.selector = selector
        self.scope = scope
        self.element = element
    }

    var address: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
}

/// Property access for one audio object. The real implementation talks to
/// CoreAudio; tests supply a fake so fallback logic can run without hardware.
public protocol AudioPropertyStore {
    func hasProperty(_ key: AudioPropertyKey) -> Bool
    func isSettable(_ key: AudioPropertyKey) -> Bool
    func float(_ key: AudioPropertyKey) -> Float?
    @discardableResult func setFloat(_ value: Float, for key: AudioPropertyKey) -> Bool
    func uint32(_ key: AudioPropertyKey) -> UInt32?
    @discardableResult func setUInt32(_ value: UInt32, for key: AudioPropertyKey) -> Bool
}

/// CoreAudio-backed store.
public struct HardwarePropertyStore: AudioPropertyStore {
    public let objectID: AudioObjectID
    public init(objectID: AudioObjectID) { self.objectID = objectID }

    public func hasProperty(_ key: AudioPropertyKey) -> Bool {
        var a = key.address
        return AudioObjectHasProperty(objectID, &a)
    }

    public func isSettable(_ key: AudioPropertyKey) -> Bool {
        var a = key.address
        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(objectID, &a, &settable) == noErr else { return false }
        return settable.boolValue
    }

    public func float(_ key: AudioPropertyKey) -> Float? {
        guard hasProperty(key) else { return nil }
        var a = key.address
        var v = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &v) == noErr else { return nil }
        return v
    }

    public func setFloat(_ value: Float, for key: AudioPropertyKey) -> Bool {
        guard isSettable(key) else { return false }
        var a = key.address
        var v = Float32(value)
        return AudioObjectSetPropertyData(objectID, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    public func uint32(_ key: AudioPropertyKey) -> UInt32? {
        guard hasProperty(key) else { return nil }
        var a = key.address
        var v = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(objectID, &a, 0, nil, &size, &v) == noErr else { return nil }
        return v
    }

    public func setUInt32(_ value: UInt32, for key: AudioPropertyKey) -> Bool {
        guard isSettable(key) else { return false }
        var a = key.address
        var v = value
        return AudioObjectSetPropertyData(objectID, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v) == noErr
    }
}
