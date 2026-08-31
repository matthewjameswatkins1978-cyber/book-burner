import Foundation

/// CaptureUndoManager implements single-step Undo Last Book:
/// cleanly removes the last BookCopy record and associated photo assets without reusing or corrupting the BB-ID sequence.
@MainActor
public final class CaptureUndoManager: ObservableObject {
    @Published public private(set) var recentCopies: [BookCopy] = []
    
    private let photoStorage: PhotoStorage
    private let bbidAllocator: BBIDAllocator

    public init(photoStorage: PhotoStorage, bbidAllocator: BBIDAllocator) {
        self.photoStorage = photoStorage
        self.bbidAllocator = bbidAllocator
    }

    /// Records a newly captured book copy onto the undo stack.
    public func recordCapture(_ bookCopy: BookCopy) {
        recentCopies.append(bookCopy)
        // Keep a reasonable history or just single/recent steps
        if recentCopies.count > 50 {
            recentCopies.removeFirst()
        }
    }

    /// Returns the most recently captured book copy available for undo, if any.
    public var lastCapturedCopy: BookCopy? {
        return recentCopies.last
    }

    /// Performs single-step Undo Last Book:
    /// Removes the last BookCopy record, deletes associated photo assets from disk,
    /// and preserves the monotonic BB-ID sequence without reuse.
    @discardableResult
    public func undoLastBook() async -> BookCopy? {
        guard let lastCopy = recentCopies.popLast() else {
            return nil
        }

        // Delete associated photo assets if present
        if let photo = lastCopy.photo {
            try? await photoStorage.deletePhoto(relativePath: photo.relativePath)
        }

        // Note: BBID sequence is monotonic and never reallocated after deletion (per FR-002 / FR-007).
        // The allocator state remains unchanged (monotonic counter increments forward only).

        return lastCopy
    }

    /// Clears undo history (e.g. on app restart or session reset).
    public func clear() {
        recentCopies.removeAll()
    }
}
