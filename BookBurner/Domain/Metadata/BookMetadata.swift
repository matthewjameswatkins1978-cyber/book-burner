import Foundation

public enum MetadataProvenance: String, Codable, Sendable, Hashable, CaseIterable {
    case googleBooks = "google_books"
    case openLibrary = "open_library"
    case needsReview = "needs_review"
    case unassigned = "unassigned"
}

public struct BookMetadata: Codable, Sendable, Hashable {
    public let isbn: String
    public let title: String
    public let authors: [String]
    public let publisher: String?
    public let publishedDate: String?
    public let description: String?
    public let pageCount: Int?
    public let thumbnailURL: URL?
    public let provenance: MetadataProvenance

    public init(
        isbn: String,
        title: String,
        authors: [String],
        publisher: String? = nil,
        publishedDate: String? = nil,
        description: String? = nil,
        pageCount: Int? = nil,
        thumbnailURL: URL? = nil,
        provenance: MetadataProvenance
    ) {
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.description = description
        self.pageCount = pageCount
        self.thumbnailURL = thumbnailURL
        self.provenance = provenance
    }
}
