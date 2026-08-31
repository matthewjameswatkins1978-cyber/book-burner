import XCTest
@testable import BookBurner

struct MockProvider: BookMetadataProvider {
    let providerName: String
    let result: BookMetadataResult

    func lookup(isbn: String) async throws -> BookMetadataResult {
        return result
    }
}

final class MetadataTests: XCTestCase {

    func testBookMetadataModelInit() {
        let meta = BookMetadata(
            isbn: "9780306406157",
            title: "Test Book",
            authors: ["Author A"],
            publisher: "Publisher X",
            publishedDate: "2020",
            description: "A description",
            pageCount: 123,
            thumbnailURL: URL(string: "https://example.com/cover.jpg"),
            provenance: .googleBooks
        )
        XCTAssertEqual(meta.isbn, "9780306406157")
        XCTAssertEqual(meta.title, "Test Book")
        XCTAssertEqual(meta.authors, ["Author A"])
        XCTAssertEqual(meta.provenance, .googleBooks)
    }

    func testCompositeMetadataServiceFallbackChain() async {
        let failingProvider = MockProvider(providerName: "Failing", result: .notFound)
        let successProvider = MockProvider(
            providerName: "Success",
            result: .success(BookMetadata(
                isbn: "9780306406157",
                title: "Fallback Success",
                authors: ["Author B"],
                provenance: .openLibrary
            ))
        )

        let service = CompositeMetadataService(providers: [failingProvider, successProvider])
        let result = try? await service.lookup(isbn: "9780306406157")

        guard case .success(let metadata) = result else {
            XCTFail("Expected success metadata")
            return
        }

        XCTAssertEqual(metadata.title, "Fallback Success")
        XCTAssertEqual(metadata.provenance, .openLibrary)
    }

    func testCompositeMetadataServiceNeedsReviewFallback() async {
        let failing1 = MockProvider(providerName: "F1", result: .notFound)
        let failing2 = MockProvider(providerName: "F2", result: .error("Network error"))

        let service = CompositeMetadataService(providers: [failing1, failing2])
        let result = try? await service.lookup(isbn: "9780306406157")

        guard case .success(let metadata) = result else {
            XCTFail("Expected success with needsReview fallback")
            return
        }

        XCTAssertEqual(metadata.provenance, .needsReview)
    }

    func testCachingBehavior() async {
        let successProvider = MockProvider(
            providerName: "Success",
            result: .success(BookMetadata(
                isbn: "9780306406157",
                title: "Cached Book",
                authors: ["Author C"],
                provenance: .googleBooks
            ))
        )

        let cache = InMemoryMetadataCache()
        let service = CompositeMetadataService(providers: [successProvider], cache: cache)

        // First lookup hits provider
        let r1 = try? await service.lookup(isbn: "9780306406157")
        guard case .success(let m1) = r1 else {
            XCTFail("First lookup failed")
            return
        }
        XCTAssertEqual(m1.title, "Cached Book")

        // Verify cached
        let cachedItem = await cache.get(isbn: "9780306406157")
        XCTAssertNotNil(cachedItem)
        XCTAssertEqual(cachedItem?.title, "Cached Book")
    }

    func testUnassignedISBN() async {
        let service = CompositeMetadataService(providers: [])
        let result = try? await service.lookup(isbn: "")

        guard case .success(let metadata) = result else {
            XCTFail("Expected success for empty ISBN")
            return
        }
        XCTAssertEqual(metadata.provenance, .unassigned)
    }
}
