import Foundation

public enum BookMetadataResult: Sendable, Hashable {
    case success(BookMetadata)
    case notFound
    case error(String)
}

public protocol BookMetadataProvider: Sendable {
    var providerName: String { get }
    func lookup(isbn: String) async throws -> BookMetadataResult
}

public protocol MetadataCache: Sendable {
    func get(isbn: String) async -> BookMetadata?
    func set(isbn: String, metadata: BookMetadata) async
    func clear() async
}

public actor InMemoryMetadataCache: MetadataCache {
    private var cache: [String: BookMetadata] = [:]

    public init() {}

    public func get(isbn: String) async -> BookMetadata? {
        return cache[isbn]
    }

    public func set(isbn: String, metadata: BookMetadata) async {
        cache[isbn] = metadata
    }

    public func clear() async {
        cache.removeAll()
    }
}
