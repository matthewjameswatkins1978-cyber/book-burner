import Foundation

public protocol ExportServiceProtocol: Sendable {
    /// Exports the book collection and photos into a self-contained ZIP archive.
    /// Returns the file URL of the generated ZIP archive (e.g. in temporary directory).
    func exportCollection(books: [BookCopy], photosDirectoryURL: URL) throws -> URL
}

public struct ExportManifest: Codable, Sendable, Equatable {
    public var schemaVersion: String
    public var appVersion: String
    public var exportTimestamp: String
    public var bookCount: Int

    public init(schemaVersion: String = "1.0", appVersion: String = "0.1.0", exportTimestamp: String, bookCount: Int) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportTimestamp = exportTimestamp
        self.bookCount = bookCount
    }
}

public struct ExportRecord: Codable, Sendable, Equatable {
    public var bbid: String
    public var isbn: String?
    public var title: String?
    public var author: String?
    public var publisher: String?
    public var publishedYear: Int?
    public var status: String
    public var locationName: String
    public var metadataProvenance: String?
    public var photoRelativePath: String?
    public var capturedAt: String

    public init(from book: BookCopy, dateFormatter: ISO8601DateFormatter) {
        self.bbid = book.bbidString
        self.isbn = book.isbn
        self.title = book.title
        self.author = book.author
        self.publisher = book.publisher
        self.publishedYear = book.publishedYear
        self.status = book.status.rawValue
        self.locationName = book.locationName
        self.metadataProvenance = book.metadataProvenance
        self.photoRelativePath = book.photo?.relativePath
        self.capturedAt = dateFormatter.string(from: book.capturedAt)
    }
}
