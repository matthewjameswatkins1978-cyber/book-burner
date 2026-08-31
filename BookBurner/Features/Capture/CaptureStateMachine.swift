import Foundation

public enum CaptureState: String, Codable, Sendable, Equatable {
    case readyToScan = "readyToScan"
    case barcodeLocked = "barcodeLocked"
    case awaitingFrontPhoto = "awaitingFrontPhoto"
    case saving = "saving"
    case saved = "saved"
}

public protocol CapturePersistenceDelegate: Sendable {
    func saveBookCopy(_ book: BookCopy) async throws
    func fetchLastBookCopy() async -> BookCopy?
    func deleteBookCopy(id: UUID) async throws
}

public actor CaptureStateMachine {
    private var currentState: CaptureState = .readyToScan
    private var activeLocationName: String
    private var activeLocationID: UUID?
    private var currentISBN: String?
    private var currentBBID: BBID?
    private var capturedBooks: [BookCopy] = []
    
    private let bbidAllocator: BBIDAllocator
    private let photoStorage: PhotoStorageServiceProtocol
    private weak var persistenceDelegate: CapturePersistenceDelegate?

    public init(
        bbidAllocator: BBIDAllocator,
        photoStorage: PhotoStorageServiceProtocol,
        persistenceDelegate: CapturePersistenceDelegate? = nil,
        initialLocationName: String = "Unassigned",
        initialLocationID: UUID? = nil
    ) {
        self.bbidAllocator = bbidAllocator
        self.photoStorage = photoStorage
        self.persistenceDelegate = persistenceDelegate
        self.activeLocationName = initialLocationName
        self.activeLocationID = initialLocationID
    }

    public func getState() -> CaptureState {
        return currentState
    }

    public func getActiveLocation() -> (name: String, id: UUID?) {
        return (activeLocationName, activeLocationID)
    }

    public func setActiveLocation(name: String, id: UUID? = nil) {
        self.activeLocationName = name
        self.activeLocationID = id
    }

    public func getCapturedBooksCount() -> Int {
        return capturedBooks.count
    }

    public func getLastCapturedBook() -> BookCopy? {
        return capturedBooks.last
    }

    /// Step 1: Barcode scanned (or valid ISBN received). Transitions readyToScan -> barcodeLocked -> awaitingFrontPhoto.
    public func handleBarcodeScanned(rawISBN: String) async -> Bool {
        guard currentState == .readyToScan else { return false }
        
        guard let validated = ISBNDecoder.validateAndNormalize(rawISBN) else {
            return false
        }

        currentState = .barcodeLocked
        currentISBN = validated.normalized

        // Allocate monotonic BBID (persists sequence, never reallocated after deletion)
        let bbid = await bbidAllocator.nextID()
        currentBBID = bbid

        currentState = .awaitingFrontPhoto
        return true
    }

    /// 'No ISBN / Can't Scan' escape path: allocates BBID, skips ISBN scan, transitions directly to awaitingFrontPhoto with status .needsReview / .noISBN.
    public func handleNoISBN() async -> BBID {
        guard currentState == .readyToScan else {
            // If already in middle of scan, reset or handle
            currentState = .readyToScan
        }

        let bbid = await bbidAllocator.nextID()
        currentBBID = bbid
        currentISBN = nil
        currentState = .awaitingFrontPhoto
        return bbid
    }

    /// Captures photo, persists record atomically, gives success feedback, and auto-resets to readyToScan.
    public func capturePhotoAndSave(imageData: Data) async throws -> BookCopy {
        guard currentState == .awaitingFrontPhoto, let bbid = currentBBID else {
            throw PhotoStorageError.invalidImageData
        }

        currentState = .saving

        // Store photo atomically (write temp -> verify -> move/rename -> relative path)
        let relativePath = try photoStorage.storeImage(data: data, for: bbid, suffix: "front")
        let photoAttributes = try? FileManager.default.attributesOfItem(atPath: photoStorage.fileURL(for: relativePath).path)
        let sizeBytes = (photoAttributes?[.size] as? Int64) ?? Int64(imageData.count)

        let photo = BookPhoto(relativePath: relativePath, fileSizeBytes: sizeBytes)

        let isNoISBN = (currentISBN == nil)
        let status: BookStatus = isNoISBN ? .needsReview : .lookupPending
        let provenance = isNoISBN ? "No ISBN Escape Path" : "Queued for Enrichment"

        let book = BookCopy(
            bbid: bbid,
            isbn: currentISBN,
            status: status,
            locationID: activeLocationID,
            locationName: activeLocationName,
            photo: photo,
            metadataProvenance: provenance
        )

        // Persist record
        capturedBooks.append(book)
        if let delegate = persistenceDelegate {
            try await delegate.saveBookCopy(book)
        }

        currentState = .saved
        
        // Auto-reset to readyToScan without save confirmation modal
        resetToReady()
        return book
    }

    public func resetToReady() {
        currentState = .readyToScan
        currentISBN = nil
        currentBBID = nil
    }

    /// Undo Last Book: removes most recent BookCopy, deletes its photo file, and preserves monotonic BBID sequence without reuse.
    public func undoLastBook() async throws -> BookCopy? {
        guard !capturedBooks.isEmpty else { return nil }
        let lastBook = capturedBooks.removeLast()

        // Delete photo file if present
        if let photo = lastBook.photo {
            try? photoStorage.deletePhoto(relativePath: photo.relativePath)
        }

        // Delete from persistence delegate if present
        if let delegate = persistenceDelegate {
            try? await delegate.deleteBookCopy(id: lastBook.id)
        }

        // Reset state machine to ready
        resetToReady()
        return lastBook
    }
}
