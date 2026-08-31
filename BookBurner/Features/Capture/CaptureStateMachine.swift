import Foundation

public enum CaptureState: String, Sendable, Equatable {
    case readyToScan
    case barcodeLocked
    case awaitingFrontPhoto
    case saving
    case saved
}

public enum CaptureAction: Sendable, Equatable {
    case scanBarcode(String)
    case triggerNoISBN
    case capturePhoto(data: Data)
    case confirmSave
    case reset
}

/// CaptureStateMachine implements the rapid capture workflow states:
/// readyToScan -> barcodeLocked -> awaitingFrontPhoto -> saving -> saved -> readyToScan.
/// Ensures duplicate ISBNs are accepted as distinct physical captures with unique BB-IDs.
/// Implements 'No ISBN / Can't Scan' path to allow BB-ID allocation and photo capture without barcode.
@MainActor
public final class CaptureStateMachine: ObservableObject {
    @Published public private(set) var currentState: CaptureState = .readyToScan
    @Published public private(set) var activeISBN: String? = nil
    @Published public private(set) var activeBBID: BBID? = nil
    @Published public private(set) var isNoISBNFlow: Bool = false
    @Published public private(set) var lastCapturedCopy: BookCopy? = nil
    @Published public private(set) var errorMessage: String? = nil

    private let bbidAllocator: BBIDAllocator
    private let photoStorage: PhotoStorage
    private var persistenceHandler: ((BookCopy) async -> Void)?

    public init(bbidAllocator: BBIDAllocator, photoStorage: PhotoStorage) {
        self.bbidAllocator = bbidAllocator
        self.photoStorage = photoStorage
    }

    public func setPersistenceHandler(_ handler: @escaping (BookCopy) async -> Void) {
        self.persistenceHandler = handler
    }

    /// Dispatches an action into the state machine.
    public func handle(_ action: CaptureAction) async {
        switch action {
        case .scanBarcode(let rawCode):
            guard currentState == .readyToScan else { return }
            guard let (normalized, _) = ISBNDecoder.validateAndNormalize(rawCode) else {
                // If barcode is invalid or unreadable, treat as scan error or allow No ISBN
                self.errorMessage = "Invalid ISBN: \(rawCode)"
                return
            }
            self.errorMessage = nil
            self.activeISBN = normalized
            self.isNoISBNFlow = false
            self.activeBBID = await bbidAllocator.nextID()
            self.currentState = .barcodeLocked
            // Immediately transition to awaiting front photo for rapid capture loop
            self.currentState = .awaitingFrontPhoto

        case .triggerNoISBN:
            guard currentState == .readyToScan else { return }
            self.errorMessage = nil
            self.activeISBN = nil
            self.isNoISBNFlow = true
            self.activeBBID = await bbidAllocator.nextID()
            self.currentState = .awaitingFrontPhoto

        case .capturePhoto(let imageData):
            guard currentState == .awaitingFrontPhoto, let bbid = activeBBID else { return }
            self.currentState = .saving
            
            do {
                let photoResult = try await photoStorage.storePhoto(imageData: imageData, bbid: bbid, photoType: "front")
                
                let status: BookStatus = isNoISBNFlow ? .noISBN : .lookupPending
                let bookCopy = BookCopy(
                    bbid: bbid,
                    isbn: activeISBN,
                    status: status,
                    photo: photoResult,
                    metadataProvenance: isNoISBNFlow ? "No ISBN Flow" : "Pending Lookup"
                )
                
                if let handler = persistenceHandler {
                    await handler(bookCopy)
                }
                
                self.lastCapturedCopy = bookCopy
                self.currentState = .saved
                
                // Auto-reset to readyToScan for high-speed capture loop without modal interruption
                await resetState()
            } catch {
                self.errorMessage = "Photo storage failed: \(error.localizedDescription)"
                self.currentState = .awaitingFrontPhoto
            }

        case .confirmSave:
            // Handled automatically in rapid capture loop
            break

        case .reset:
            await resetState()
        }
    }

    private func resetState() async {
        self.currentState = .readyToScan
        self.activeISBN = nil
        self.activeBBID = nil
        self.isNoISBNFlow = false
        self.errorMessage = nil
    }
}
