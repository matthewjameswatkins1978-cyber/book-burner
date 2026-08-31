import XCTest
@testable import BookBurner

@MainActor
final class CaptureTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var bbidAllocator: BBIDAllocator!
    private var photoStorage: PhotoStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defaults = UserDefaults(suiteName: #file)!
        defaults.removePersistentDomain(forName: #file)
        
        bbidAllocator = BBIDAllocator(defaults: defaults)
        photoStorage = PhotoStorage(fileManager: .default, rootDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    func testBarcodeScannerSeamMock() async {
        let scanner = MockBarcodeScannerController()
        var events: [BarcodeScannerEvent] = []

        let task = Task {
            for await event in scanner.eventStream {
                events.append(event)
                if case .sessionStopped = event {
                    break
                }
            }
        }

        await scanner.startScanning()
        await scanner.simulateBarcodeScan("9780306406157")
        await scanner.setTorchEnabled(true)
        await scanner.stopScanning()

        _ = await task.result

        XCTAssertTrue(events.contains(.sessionStarted))
        XCTAssertTrue(events.contains(.barcodeDetected("9780306406157")))
        XCTAssertTrue(events.contains(.torchToggled(true)))
        XCTAssertTrue(events.contains(.sessionStopped))
    }

    func testCaptureStateMachineWorkflowAndDuplicateISBNs() async {
        let machine = CaptureStateMachine(bbidAllocator: bbidAllocator, photoStorage: photoStorage)
        var persistedCopies: [BookCopy] = []
        
        machine.setPersistenceHandler { copy in
            persistedCopies.append(copy)
        }

        XCTAssertEqual(machine.currentState, .readyToScan)

        // 1. Scan valid ISBN-13
        await machine.handle(.scanBarcode("978-0-306-40615-7"))
        XCTAssertEqual(machine.currentState, .awaitingFrontPhoto)
        XCTAssertEqual(machine.activeISBN, "9780306406157")
        let firstBBID = machine.activeBBID

        // 2. Capture photo to complete first scan
        let dummyImageData = Data("fake-jpeg-image-data".utf8)
        await machine.handle(.capturePhoto(data: dummyImageData))

        XCTAssertEqual(machine.currentState, .readyToScan)
        XCTAssertEqual(persistedCopies.count, 1)
        XCTAssertEqual(persistedCopies[0].bbid, firstBBID)
        XCTAssertEqual(persistedCopies[0].isbn, "9780306406157")

        // 3. Scan exact same ISBN again (Duplicate ISBN test: accepted as distinct physical capture with unique BB-ID)
        await machine.handle(.scanBarcode("978-0-306-40615-7"))
        XCTAssertEqual(machine.currentState, .awaitingFrontPhoto)
        XCTAssertEqual(machine.activeISBN, "9780306406157")
        let secondBBID = machine.activeBBID
        XCTAssertNotEqual(firstBBID, secondBBID)

        await machine.handle(.capturePhoto(data: dummyImageData))
        XCTAssertEqual(persistedCopies.count, 2)
        XCTAssertEqual(persistedCopies[1].bbid, secondBBID)
        XCTAssertEqual(persistedCopies[1].isbn, "9780306406157")
    }

    func testNoISBNWorkflow() async {
        let machine = CaptureStateMachine(bbidAllocator: bbidAllocator, photoStorage: photoStorage)
        var persistedCopies: [BookCopy] = []
        
        machine.setPersistenceHandler { copy in
            persistedCopies.append(copy)
        }

        // Trigger No ISBN flow
        await machine.handle(.triggerNoISBN)
        XCTAssertEqual(machine.currentState, .awaitingFrontPhoto)
        XCTAssertTrue(machine.isNoISBNFlow)
        XCTAssertNil(machine.activeISBN)
        let allocatedBBID = machine.activeBBID

        let dummyImageData = Data("no-isbn-photo".utf8)
        await machine.handle(.capturePhoto(data: dummyImageData))

        XCTAssertEqual(persistedCopies.count, 1)
        XCTAssertEqual(persistedCopies[0].bbid, allocatedBBID)
        XCTAssertNil(persistedCopies[0].isbn)
        XCTAssertEqual(persistedCopies[0].status, .noISBN)
    }

    func testAtomicPhotoStorage() async throws {
        let bbid = BBID(rawValue: 127)
        let imageData = Data("atomic-image-content".utf8)

        let photo = try await photoStorage.storePhoto(imageData: imageData, bbid: bbid, photoType: "front")
        XCTAssertEqual(photo.relativePath, "BookBurnerPhotos/BB-000127-front.heic")
        XCTAssertGreaterThan(photo.fileSizeBytes, 0)

        // Verify file exists physically at disk
        let fullFileURL = tempDir.appendingPathComponent("BB-000127-front.heic")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullFileURL.path))

        let readBack = try Data(contentsOf: fullFileURL)
        XCTAssertEqual(readBack, imageData)

        // Test deletion
        try await photoStorage.deletePhoto(relativePath: photo.relativePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fullFileURL.path))
    }

    func testCaptureUndoManagerAndMonotonicBBIDPreservation() async throws {
        let undoManager = CaptureUndoManager(photoStorage: photoStorage, bbidAllocator: bbidAllocator)
        
        let id1 = await bbidAllocator.nextID()
        let photo1 = try await photoStorage.storePhoto(imageData: Data("p1".utf8), bbid: id1)
        let copy1 = BookCopy(bbid: id1, isbn: "9780306406157", title: "Book 1", photo: photo1)

        let id2 = await bbidAllocator.nextID()
        let photo2 = try await photoStorage.storePhoto(imageData: Data("p2".utf8), bbid: id2)
        let copy2 = BookCopy(bbid: id2, isbn: "9780132350884", title: "Book 2", photo: photo2)

        undoManager.recordCapture(copy1)
        undoManager.recordCapture(copy2)

        XCTAssertEqual(undoManager.lastCapturedCopy?.bbid, id2)

        // Perform Undo Last Book
        let undone = await undoManager.undoLastBook()
        XCTAssertEqual(undone?.bbid, id2)
        XCTAssertEqual(undoManager.lastCapturedCopy?.bbid, id1)

        // Verify photo2 file was deleted from disk
        let fullPath2 = tempDir.appendingPathComponent("BB-000002-front.heic")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fullPath2.path))

        // Verify BBID monotonicity: next allocated ID should be BB-000003, ensuring no reuse of BB-000002
        let nextID = await bbidAllocator.nextID()
        XCTAssertEqual(nextID.rawValue, 3)
        XCTAssertEqual(nextID.description, "BB-000003")
    }
}
