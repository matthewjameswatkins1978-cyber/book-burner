import Foundation

public actor CompositeMetadataService: BookMetadataProvider {
    public let providerName = "CompositeMetadataService"
    private let providers: [any BookMetadataProvider]
    private let cache: any MetadataCache

    public init(
        providers: [any BookMetadataProvider] = [GoogleBooksAdapter(), OpenLibraryAdapter()],
        cache: any MetadataCache = InMemoryMetadataCache()
    ) {
        self.providers = providers
        self.cache = cache
    }

    public func lookup(isbn: String) async throws -> BookMetadataResult {
        let cleaned = ISBNDecoder.clean(isbn)
        guard !cleaned.isEmpty else {
            let unassignedMeta = BookMetadata(
                isbn: isbn,
                title: "Unassigned Book",
                authors: [],
                provenance: .unassigned
            )
            return .success(unassignedMeta)
        }

        // 1. Check cache first
        if let cached = await cache.get(isbn: cleaned) {
            return .success(cached)
        }

        // 2. Iterate through provider fallback chain
        var lastError: String? = nil
        for provider in providers {
            do {
                let result = try await provider.lookup(isbn: cleaned)
                switch result {
                case .success(let metadata):
                    await cache.set(isbn: cleaned, metadata: metadata)
                    return .success(metadata)
                case .notFound:
                    continue
                case .error(let msg):
                    lastError = msg
                    continue
                }
            } catch {
                lastError = error.localizedDescription
                continue
            }
        }

        // 3. Fallback to Needs Review if all providers missed or errored
        let needsReviewMeta = BookMetadata(
            isbn: cleaned,
            title: "Needs Review (Lookup Failed)",
            authors: ["Unknown Author"],
            provenance: .needsReview
        )
        await cache.set(isbn: cleaned, metadata: needsReviewMeta)
        return .success(needsReviewMeta)
    }

    public func getCachedMetadata(isbn: String) async -> BookMetadata? {
        let cleaned = ISBNDecoder.clean(isbn)
        return await cache.get(isbn: cleaned)
    }

    public func setCachedMetadata(isbn: String, metadata: BookMetadata) async {
        let cleaned = ISBNDecoder.clean(isbn)
        await cache.set(isbn: cleaned, metadata: metadata)
    }

    public func clearCache() async {
        await cache.clear()
    }
}
