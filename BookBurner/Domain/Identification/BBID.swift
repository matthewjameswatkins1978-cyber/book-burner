import Foundation

/// BBID represents a monotonic, unique, human-readable identifier for a physical book copy
/// formatted as BB-000001, persisting sequence state, guaranteeing uniqueness and no reuse.
public struct BBID: Codable, Hashable, Sendable, CustomStringConvertible, Comparable {
    public let rawValue: Int

    public var description: String {
        return String(format: "BB-%06d", rawValue)
    }

    public init(rawValue: Int) {
        precondition(rawValue > 0, "BBID rawValue must be positive.")
        self.rawValue = rawValue
    }

    public init?(string: String) {
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.hasPrefix("BB-") else { return nil }
        let numberString = String(cleaned.dropFirst(3))
        guard let val = Int(numberString), val > 0 else { return nil }
        self.rawValue = val
    }

    public static func < (lhs: BBID, rhs: BBID) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Allocator logic for monotonic identifiers ensuring persistence, uniqueness, and no reuse.
public actor BBIDAllocator {
    private let storageKey = "BookBurner_BBID_NextSequence"
    private let defaults: UserDefaults
    private var currentSequence: Int

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: storageKey) == nil {
            defaults.set(1, forKey: storageKey)
        }
        let stored = defaults.integer(forKey: storageKey)
        self.currentSequence = stored > 0 ? stored : 1
    }

    /// Allocates the next unique BBID and persistently increments the sequence state.
    public func nextID() -> BBID {
        let assigned = currentSequence
        currentSequence += 1
        defaults.set(currentSequence, forKey: storageKey)
        return BBID(rawValue: assigned)
    }

    /// Returns the current sequence value without incrementing (useful for testing/status).
    public func peekCurrent() -> Int {
        return currentSequence
    }

    /// Resets the allocator state (primarily for testing purposes).
    public func reset(to value: Int = 1) {
        precondition(value > 0, "Reset value must be positive.")
        currentSequence = value
        defaults.set(currentSequence, forKey: storageKey)
    }
}
