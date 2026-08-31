import Foundation

public struct BookPhoto: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Relative path within app document/container storage (adhering to atomic write & relative path constraints)
    public var relativePath: String
    public var capturedAt: Date
    public var fileSizeBytes: Int64

    public init(id: UUID = UUID(), relativePath: String, capturedAt: Date = Date(), fileSizeBytes: Int64 = 0) {
        self.id = id
        self.relativePath = relativePath
        self.capturedAt = capturedAt
        self.fileSizeBytes = fileSizeBytes
    }
}
