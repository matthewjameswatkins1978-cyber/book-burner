import Foundation

public enum BookStatus: String, Codable, Sendable, Hashable {
    case lookupPending = "Lookup Pending"
    case resolved = "Resolved"
    case needsReview = "Needs Review"
    case noISBN = "No ISBN"
}

public struct BookCopy: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Unique human-readable monotonic identifier (e.g., BB-000001)
    public var bbidString: String
    public var isbn: String?
    public var title: String?
    public var author: String?
    public var publisher: String?
    public var publishedYear: Int?
    public var status: BookStatus
    public var locationID: UUID?
    public var locationName: String
    public var photo: BookPhoto?
    public var metadataProvenance: String?
    public var capturedAt: Date

    public init(
        id: UUID = UUID(),
        bbid: BBID,
        isbn: String? = nil,
        title: String? = nil,
        author: String? = nil,
        publisher: String? = nil,
        publishedYear: Int? = nil,
        status: BookStatus = .lookupPending,
        locationID: UUID? = nil,
        locationName: String = "Unassigned",
        photo: BookPhoto? = nil,
        metadataProvenance: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.bbidString = bbid.description
        self.isbn = isbn
        self.title = title
        self.author = author
        self.publisher = publisher
        self.publishedYear = publishedYear
        self.status = status
        self.locationID = locationID
        self.locationName = locationName
        self.photo = photo
        self.metadataProvenance = metadataProvenance
        self.capturedAt = capturedAt
    }

    public var bbid: BBID {
        return BBID(string: bbidString) ?? BBID(rawValue: 1)
    }
}
