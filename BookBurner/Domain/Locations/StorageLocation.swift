import Foundation

public struct StorageLocation: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var notes: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, notes: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes
        self.createdAt = createdAt
    }
}
