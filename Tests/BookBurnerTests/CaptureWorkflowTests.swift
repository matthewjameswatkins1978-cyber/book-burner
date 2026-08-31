import XCTest
@testable import BookBurner

final class CaptureWorkflowTests: XCTestCase {
    
    var tempDir: URL!
    var fileManager: FileManager!
    var photoStorage: AtomicPhotoStorageService!
    var defaults: UserDefaults!
    var bbidAllocator: BBIDAllocator!

    override func setUpWithError() throws {
        try super.setUp()
        fileManager = .default
        tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        photoStorage = AtomicPhotoStorageService(fileManager: fileManager, baseDirectory: tempDir)
        
        defaults = UserDefaults(suiteName: #file)!
        defaults.removePersistentDomain(forName: #file)
        bbidAllocator = BBIDAllocator(defaults: defaults)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDir)
        try super.tearDown()
    }

    func testAtomicPhotoStorageAndDeletion() async throws {
        let bbid = BBID(rawValue: 1)
        let sampleData = "fakeheicdata".data(using: .utf8)!

        let relativePath = try photoStorage.storeImage(data: sampleData, for: bbid, suffix: "front")
        XCTAssertEqual(relativePath, "BB-000001-front.heic")

        let fileURL = photoStorage.fileURL(for: relativePath)
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))

        let readData = try Data(contentsOf: fileURL)
        XCTAssertEqual(readData, sampleData)

        // Test deletion (for Undo)
        try photoStorage.deletePhoto(relativePath: relativePath)
        XCTAssertFalse(fileManager.fileExists(atPath: fileURL.path))
    }

    func testAtomicPhotoStorageInvalidData() async {
        let bbid = BBID(rawValue: 1)
        let emptyData = Data()

        do {
            _ = try photoStorage.storeImage(data: emptyData, for: bbid, suffix: "front")
            XCTFail("Expected error for empty data")
        } catch {
            XCTAssertTrue(error is PhotoStorageError)
        }
    }

    func testBarcodeScannerSeamMock() async throws {
        let scanner = MockBarcodeScannerSeam()
        try await scanner.startScanning()
        
        var receivedEvents: [BarcodeScannerEvent] = []
        let task = Task {
            for await event in scanner.eventStream {
                receivedEvents.append(event)
                if receivedEvents.count >= 2 { break }
            }
        }

        await scanner.setTorch(on: true)
        await scanner.simulateScan(isbn: "9780306406157")
        
        _ = await task.result
        XCTAssertTrue(await scanner.isScanning())
        XCTAssertTrue(await scanner.isTorchOn())
        XCTAssertEqual(receivedEvents.count, 2)
        XCTAssertEqual(receivedEvents[0], .torchToggled(isOn: true))
        XCTAssertEqual(receivedEvents[1], .scanned(isbn: "9780306406157"))
    }

    func testCaptureStateMachineHappyPathAndAutoReset() async throws {
        let sampleData = "photoBytes".data(using: .utf8)!
        let stateMachine = CaptureStateMachine(
            bbidAllocator: bbidAllocator,
            photoStorage: photoStorage,
            initialLocationName: "Office Shelf",
            initialLocationID: UUID()
        )

        XCTAssertEqual(await stateMachine.getState(), .readyToScan)

        // Scan valid ISBN-13
        let scanned = await stateMachine.handleBarcodeScanned(rawISBN: "978-0-306-40615-7")
        XCTAssertTrue(scanned)
        XCTAssertEqual(await stateMachine.getState(), .awaitingFrontPhoto)

        // Capture photo & save
        let book = try await stateMachine.capturePhotoAndSave(imageData: sampleData)
        XCTAssertEqual(book.bbidString, "BB-000001")
        XCTAssertEqual(book.isbn, "9780306406157")
        XCTAssertEqual(book.status, .lookupPending)
        XCTAssertEqual(book.locationName, "Office Shelf")
        XCTAssertNotNil(book.photo)
        XCTAssertEqual(book.photo?.relativePath, "BB-000001-front.heic")

        // Auto-reset check
        XCTAssertEqual(await stateMachine.getState(), .readyToScan)
        XCTAssertEqual(await stateMachine.getCapturedBooksCount(), 1)
    }

    func testDuplicateISBNHandlingDistinctBBIDs() async throws {
        let sampleData = "photoBytes".data(using: .utf8)!
        let stateMachine = CaptureStateMachine(bbidAllocator: bbidAllocator, photoStorage: photoStorage)

        // Scan first copy
        _ = await stateMachine.handleBarcodeScanned(rawISBN: "9780306406157")
        let book1 = try await stateMachine.capturePhotoAndSave(imageData: sampleData)
        XCTAssertEqual(book1.bbidString, "BB-000001")
        XCTAssertEqual(book1.isbn, "9780306406157")

        // Scan identical ISBN second copy (duplicate ISBN without modal block)
        _ = await stateMachine.handleBarcodeScanned(rawISBN: "9780306406157")
        let book2 = try await stateMachine.capturePhotoAndSave(imageData: sampleData)
        XCTAssertEqual(book2.bbidString, "BB-000002")
        XCTAssertEqual(book2.isbn, "9780306406157")
        XCTAssertNotEqual(book1.id, book2.id)
    }

    func testNoISBNEscapePath() async throws {
        let sampleData = "noIsbnPhoto".data(using: .utf8)!
        let stateMachine = CaptureStateMachine(bbidAllocator: bbidAllocator, photoStorage: photoStorage)

        XCTAssertEqual(await stateMachine.getState(), .readyToScan)

        let assignedBBID = await stateMachine.handleNoISBN()
        XCTAssertEqual(assignedBBID.description, "BB-000001")
        XCTAssertEqual(await stateMachine.getState(), .awaitingFrontPhoto)

        let book = try await stateMachine.capturePhotoAndSave(imageData: sampleData)
        XCTAssertEqual(book.bbidString, "BB-000001")
        XCTAssertNil(book.isbn)
        XCTAssertEqual(book.status, .needsReview)
        XCTAssertEqual(book.metadataProvenance, "No ISBN Escape Path")
        XCTAssertEqual(await stateMachine.getState(), .readyToScan)
    }

    func testUndoLastBookPreservesBBIDSequenceAndDeletesPhoto() async throws {
        let sampleData = "undoTest".data(using: .utf8)!
        let stateMachine = CaptureStateMachine(bbidAllocator: bbidAllocator, photoStorage: photoStorage)

        // Capture book 1 (BB-000001)
        _ = await stateMachine.handleBarcodeScanned(rawISBN: "9780306406157")
        let book1 = try await stateMachine.capturePhotoAndSave(imageData: sampleData)
        XCTAssertEqual(book1.bbidString, "BB-000001")
        let photoURL = photoStorage.fileURL(for: book1.photo!.relativePath)
        XCTAssertTrue(fileManager.fileExists(atPath: photoURL.path))

        // Undo last book
        let undone = try await stateMachine.undoLastBook()
        XCTAssertNotNil(undone)
        XCTAssertEqual(undone?.bbidString, "BB-000001")
        XCTAssertFalse(fileManager.fileExists(atPath: photoURL.path))
        XCTAssertEqual(await stateMachine.getCapturedBooksCount(), 0)

        // Capture next book: sequence should be BB-000002 (never reused BB-000001)
        _ = await stateMachine.handleBarcodeScanned(rawISBN: "9780306406157")
        let book2 = try await stateMachine.capturePhotoAndSave(imageData: sampleData)
        XCTAssertEqual(book2.bbidString, "BB-000002")
    }
}
