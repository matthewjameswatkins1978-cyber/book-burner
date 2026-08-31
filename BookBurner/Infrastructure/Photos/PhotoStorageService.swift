import Foundation

public protocol PhotoStorageServiceProtocol: Sendable {
    /// Saves image data atomically (Stage 1: write temp -> Stage 2: verify -> Stage 3: move/rename to permanent location -> Stage 4: return relative path).
    func storeImage(data: Data, for bbid: BBID, suffix: String) throws -> String
    /// Deletes a photo file by its relative path (used for Undo).
    func deletePhoto(relativePath: String) throws
    /// Resolves a relative path to an absolute file URL.
    func fileURL(for relativePath: String) -> URL
}

public enum PhotoStorageError: Error, LocalizedError {
    case invalidImageData
    case tempWriteFailed(Error)
    case verificationFailed
    case permanentMoveFailed(Error)
    case deletionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The provided image data is invalid or empty."
        case .tempWriteFailed(let err):
            return "Failed to write temporary image file: \(err.localizedDescription)"
        case .verificationFailed:
            return "Image verification failed: file size is zero or unreadable."
        case .permanentMoveFailed(let err):
            return "Failed to move verified image to permanent location: \(err.localizedDescription)"
        case .deletionFailed(let err):
            return "Failed to delete photo file: \(err.localizedDescription)"
        }
    }
}

public final class AtomicPhotoStorageService: PhotoStorageServiceProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let baseDirectory: URL

    public init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseDirectory = documents.appendingPathComponent("BookPhotos", isDirectory: true)
        }
        createBaseDirectoryIfNeeded()
    }

    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func fileURL(for relativePath: String) -> URL {
        return baseDirectory.appendingPathComponent(relativePath)
    }

    public func storeImage(data: Data, for bbid: BBID, suffix: String = "front") throws -> String {
        guard !data.isEmpty else {
            throw PhotoStorageError.invalidImageData
        }

        // Ensure base directory exists
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        let fileName = "\(bbid.description)-\(suffix).heic"
        let permanentURL = baseDirectory.appendingPathComponent(fileName)

        // If a file already exists at permanent location (e.g. re-capture or overwrite), remove it first
        if fileManager.fileExists(atPath: permanentURL.path) {
            try? fileManager.removeItem(at: permanentURL)
        }

        // Stage 1: Write to temporary file in temporary directory
        let tempUUID = UUID().uuidString
        let tempFileName = "temp-\(tempUUID)-\(fileName)"
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(tempFileName)

        do {
            try data.write(to: tempURL, options: .atomic)
        } catch {
            throw PhotoStorageError.tempWriteFailed(error)
        }

        // Stage 2: Verify the temp file exists and has non-zero size
        guard fileManager.fileExists(atPath: tempURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: tempURL.path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            try? fileManager.removeItem(at: tempURL)
            throw PhotoStorageError.verificationFailed
        }

        // Stage 3: Move/rename from temporary file to deterministic sandbox filename
        do {
            try fileManager.moveItem(at: tempURL, to: permanentURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw PhotoStorageError.permanentMoveFailed(error)
        }

        // Stage 4: Return relative path (relative to baseDirectory or filename)
        // Storing relative path such as "BB-000001-front.heic" or subfolder relative path
        return fileName
    }

    public func deletePhoto(relativePath: String) throws {
        let url = fileURL(for: relativePath)
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw PhotoStorageError.deletionFailed(error)
            }
        }
    }
}
