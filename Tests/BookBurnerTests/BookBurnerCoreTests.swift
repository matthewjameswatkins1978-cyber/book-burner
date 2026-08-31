import XCTest
@testable import BookBurner

final class BookBurnerCoreTests: XCTestCase {

    func testBBIDFormatting() {
        let bbid = BBID(rawValue: 42)
        XCTAssertEqual(bbid.description, "BB-000042")
        
        let parsed = BBID(string: "BB-000123")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.rawValue, 123)
        
        XCTAssertNil(BBID(string: "INVALID"))
        XCTAssertNil(BBID(string: "BB-0"))
    }

    func testBBIDAllocator() async {
        let defaults = UserDefaults(suiteName: #file)!
        defaults.removePersistentDomain(forName: #file)
        
        let allocator = BBIDAllocator(defaults: defaults)
        let id1 = await allocator.nextID()
        let id2 = await allocator.nextID()
        
        XCTAssertEqual(id1.description, "BB-000001")
        XCTAssertEqual(id2.description, "BB-000002")
        XCTAssertTrue(id1 < id2)
    }

    func testISBNValidationAndNormalization() {
        // ISBN-10: 0306406152
        let result10 = ISBNDecoder.validateAndNormalize("0-306-40615-2")
        XCTAssertNotNil(result10)
        XCTAssertEqual(result10?.normalized, "0306406152")
        XCTAssertEqual(result10?.format, .isbn10)

        // ISBN-13: 9780306406157
        let result13 = ISBNDecoder.validateAndNormalize("978-0-306-40615-7")
        XCTAssertNotNil(result13)
        XCTAssertEqual(result13?.normalized, "9780306406157")
        XCTAssertEqual(result13?.format, .isbn13)

        // Invalid ISBN
        XCTAssertNil(ISBNDecoder.validateAndNormalize("0306406153"))
    }

    func testISBN10To13Conversion() {
        let converted = ISBNDecoder.convertISBN10To13("0306406152")
        XCTAssertEqual(converted, "9780306406157")
        XCTAssertNil(ISBNDecoder.convertISBN10To13("INVALID"))
    }

    func testDomainModels() {
        let location = StorageLocation(name: "Shelf A", notes: "Top row")
        XCTAssertEqual(location.name, "Shelf A")

        let photo = BookPhoto(relativePath: "photos/BB-000001.jpg", fileSizeBytes: 1024)
        XCTAssertEqual(photo.relativePath, "photos/BB-000001.jpg")

        let bbid = BBID(rawValue: 1)
        let book = BookCopy(
            bbid: bbid,
            isbn: "9780306406157",
            title: "The Code Book",
            author: "Simon Singh",
            status: .resolved,
            locationID: location.id,
            locationName: location.name,
            photo: photo,
            metadataProvenance: "Google Books"
        )
        XCTAssertEqual(book.bbidString, "BB-000001")
        XCTAssertEqual(book.status, .resolved)
        XCTAssertEqual(book.locationName, "Shelf A")
        XCTAssertEqual(book.photo?.relativePath, "photos/BB-000001.jpg")
    }
}
