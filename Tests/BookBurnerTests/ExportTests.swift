import XCTest
@testable import BookBurner

final class ExportTests: XCTestCase {

    func testCSVGenerationAndEscaping() {
        let exportService = ExportService()
        
        let book1 = BookCopy(
            bbid: BBID(rawValue: 1),
            isbn: "9780306406157",
            title: "Llyfr Cymraeg (Welsh Book)",
            author: "Maldwyn ap Tomos",
            publisher: "Gwasg Prifysgol Cymru",
            publishedYear: 2021,
            status: .resolved,
            locationName: "Shelf, Room #1",
            photo: BookPhoto(relativePath: "BB-000001-front.heic"),
            metadataProvenance: "google_books"
        )

        let book2 = BookCopy(
            bbid: BBID(rawValue: 2),
            isbn: nil,
            title: "Book with \"Quotes\" and, Commas and\nNewlines",
            author: "Author, Co.",
            publisher: nil,
            publishedYear: nil,
            status: .needsReview,
            locationName: "Box 2",
            photo: BookPhoto(relativePath: "BB-000002-front.heic"),
            metadataProvenance: "No ISBN"
        )

        let csv = exportService.generateCSV(for: [book1, book2])
        XCTAssertTrue(csv.contains("BB-000001"))
        XCTAssertTrue(csv.contains("Llyfr Cymraeg (Welsh Book)"))
        XCTAssertTrue(csv.contains("Maldwyn ap Tomos"))
        XCTAssertTrue(csv.contains("\"Book with \"\"Quotes\"\" and, Commas and\nNewlines\""))
        XCTAssertTrue(csv.contains("\"Author, Co.\""))
    }

    func testExportManifestAndRecords() {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let book = BookCopy(
            bbid: BBID(rawValue: 1),
            isbn: "9780306406157",
            title: "Test Export",
            status: .resolved,
            locationName: "Office"
        )

        let record = ExportRecord(from: book, dateFormatter: dateFormatter)
        XCTAssertEqual(record.bbid, "BB-000001")
        XCTAssertEqual(record.isbn, "9780306406157")
        XCTAssertEqual(record.title, "Test Export")
        XCTAssertEqual(record.status, "Resolved")
        XCTAssertEqual(record.locationName, "Office")

        let manifest = ExportManifest(schemaVersion: "1.0", appVersion: "0.1.0", exportTimestamp: "2026-08-31T00:00:00.000Z", bookCount: 1)
        XCTAssertEqual(manifest.schemaVersion, "1.0")
        XCTAssertEqual(manifest.bookCount, 1)
    }

    func testExportServiceZipGeneration() throws {
        let fileManager = FileManager.default
        let tempPhotosDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempPhotosDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempPhotosDir) }

        // Create sample photo file
        let photoName = "BB-000001-front.heic"
        let photoURL = tempPhotosDir.appendingPathComponent(photoName)
        try Data("dummy-image-bytes".utf8).write(to: photoURL)

        let book = BookCopy(
            bbid: BBID(rawValue: 1),
            isbn: "9780306406157",
            title: "Archived Book 📚",
            author: "Author Welsh: Dafydd",
            status: .resolved,
            locationName: "Box A",
            photo: BookPhoto(relativePath: photoName),
            metadataProvenance: "google_books"
        )

        let exportService = ExportService()
        let zipURL = try exportService.exportCollection(books: [book], photosDirectoryURL: tempPhotosDir)
        defer { try? fileManager.removeItem(at: zipURL) }

        XCTAssertTrue(fileManager.fileExists(atPath: zipURL.path))
        XCTAssertTrue(zipURL.lastPathComponent.hasPrefix("BookBurner-"))
        XCTAssertTrue(zipURL.lastPathComponent.hasSuffix(".zip"))
    }
}
