import XCTest
@testable import BookBurner

final class UIViewStateTests: XCTestCase {

    var appState: AppState!

    override func setUpWithError() throws {
        try super.setUp()
        appState = AppState()
    }

    override func tearDownWithError() throws {
        appState = nil
        try super.tearDown()
    }

    func testAppStateSearchFiltering() {
        let book1 = BookCopy(
            bbid: BBID(rawValue: 1),
            isbn: "9780306406157",
            title: "SwiftUI Mastery",
            author: "Jane Doe",
            publisher: "Tech Press",
            publishedYear: 2023,
            status: .resolved,
            locationName: "Box 1"
        )
        let book2 = BookCopy(
            bbid: BBID(rawValue: 2),
            isbn: "9781491957660",
            title: "Advanced Swift",
            author: "John Smith",
            publisher: "OReilly",
            publishedYear: 2022,
            status: .lookupPending,
            locationName: "Office Shelf"
        )

        appState.books = [book1, book2]

        // Test search by BBID
        appState.searchText = "BB-000001"
        XCTAssertEqual(appState.filteredBooks.count, 1)
        XCTAssertEqual(appState.filteredBooks.first?.bbidString, "BB-000001")

        // Test search by title
        appState.searchText = "advanced swift"
        XCTAssertEqual(appState.filteredBooks.count, 1)
        XCTAssertEqual(appState.filteredBooks.first?.title, "Advanced Swift")

        // Test search by author
        appState.searchText = "jane doe"
        XCTAssertEqual(appState.filteredBooks.count, 1)
        XCTAssertEqual(appState.filteredBooks.first?.author, "Jane Doe")

        // Test search by ISBN
        appState.searchText = "9781491957660"
        XCTAssertEqual(appState.filteredBooks.count, 1)

        // Test search by publisher
        appState.searchText = "tech press"
        XCTAssertEqual(appState.filteredBooks.count, 1)

        // Test search by location
        appState.searchText = "box 1"
        XCTAssertEqual(appState.filteredBooks.count, 1)

        // Reset search
        appState.searchText = ""
        XCTAssertEqual(appState.filteredBooks.count, 2)
    }

    func testStatusPredicatesAndFilters() {
        let book1 = BookCopy(bbid: BBID(rawValue: 1), title: "Book One", status: .resolved, locationName: "Box 1")
        let book2 = BookCopy(bbid: BBID(rawValue: 2), title: "Book Two", status: .lookupPending, locationName: "Box 1")
        let book3 = BookCopy(bbid: BBID(rawValue: 3), title: "Book Three", status: .needsReview, locationName: "Box 2")
        let book4 = BookCopy(bbid: BBID(rawValue: 4), title: "Book Four", status: .noISBN, locationName: "Box 2")

        appState.books = [book1, book2, book3, book4]

        // All filter
        appState.selectedStatusFilter = .all
        XCTAssertEqual(appState.filteredBooks.count, 4)

        // Unresolved filter (status != .resolved) -> book2, book3, book4
        appState.selectedStatusFilter = .unresolved
        XCTAssertEqual(appState.filteredBooks.count, 3)

        // Lookup Pending filter -> book2
        appState.selectedStatusFilter = .lookupPending
        XCTAssertEqual(appState.filteredBooks.count, 1)
        XCTAssertEqual(appState.filteredBooks.first?.bbidString, "BB-000002")

        // Needs Review filter (.needsReview or .noISBN) -> book3, book4
        appState.selectedStatusFilter = .needsReview
        XCTAssertEqual(appState.filteredBooks.count, 2)

        // Location filter ("Box 1") -> book1, book2
        appState.selectedStatusFilter = .location("Box 1")
        XCTAssertEqual(appState.filteredBooks.count, 2)
    }

    func testActiveLocationStateSync() async {
        let newLoc = StorageLocation(name: "Warehouse B")
        appState.locations.append(newLoc)
        appState.activeLocation = newLoc

        let stateMachineLoc = await appState.captureStateMachine.getActiveLocation()
        XCTAssertEqual(stateMachineLoc.name, "Warehouse B")
    }
}
