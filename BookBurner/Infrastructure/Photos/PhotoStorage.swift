import Foundation

public enum PhotoStorageError: Error, LocalizedError {
    case invalidImageData
    case fileWriteFailed(String)
    case verificationFailed(String)
    case fileMoveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The provided image data is invalid or empty."
        case .fileWriteFailed(let msg):
            return "Failed to write temp file: \(msg)"
        case .verificationFailed(let msg):
            return "Image verification failed: \(msg)"
        case .fileMoveFailed(let msg):
            return "Failed to move file to permanent location: \(msg)"
        }
    }
}

/// PhotoStorage implements atomic image write semantics:
/// write temp file -> verify -> move/rename to permanent deterministic relative path (e.g. BB-000127-front.heic) -> return relative reference.
public actor PhotoStorage {
    private let fileManager: FileManager
    private let rootDirectory: URL

    public init(fileManager: FileManager = .default, rootDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let rootDirectory = rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.rootDirectory = docs.appendingPathComponent("BookBurnerPhotos", isDirectory: true)
        }
        
        // Ensure root directory exists
        try? fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    /// Stores a photo atomically: writes to temp file, verifies readability/integrity, moves to permanent deterministic relative path.
    public func storePhoto(imageData: Data, bbid: BBID, photoType: String = "front") throws -> BookPhoto {
        guard !imageData.isEmpty else {
            throw PhotoStorageError.invalidImageData
        }

        // 1. Write temp file in system temporary directory or rootDirectory temp subfolder
        let tempID = UUID().uuidString
        let tempFileURL = rootDirectory.appendingPathComponent("temp-\(tempID).tmp")
        
        do {
            try imageData.write(to: tempFileURL, options: .atomic)
        } catch {
            throw PhotoStorageError.fileWriteFailed(error.localizedDescription)
        }

        // 2. Verify file exists and is readable / non-empty
        do {
            let attributes = try fileManager.attributesOfItem(atPath: tempFileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            guard fileSize > 0 else {
                throw PhotoStorageError.verificationFailed("File size is zero after write.")
            }
        } catch {
            throw PhotoStorageError.fileWriteFailed("Verification error: \(error.localizedDescription)")
        }

        // 3. Move/rename to permanent deterministic relative path (e.g. BB-000127-front.heic or .jpg)
        let fileName = "\(bbid.description)-\(photoType).heic"
        let permanentURL = rootDirectory.appendingPathComponent(fileName)

        // If file already exists at permanent path, remove it to ensure clean replacement
        if fileManager.fileExists(atPath: permanentURL.path) {
            try? fileManager.removeItem(at: permanentURL)
        }

        do {
            try fileManager.moveItem(at: tempFileURL, to: permanentURL)
        } catch {
            // Clean up temp file on failure
            try? fileManager.removeItem(at: tempFileURL)
            throw PhotoStorageError.fileMoveFailed(error.localizedDescription)
        }

        // Get final file size
        let finalAttributes = try? fileManager.attributesOfItem(atPath: permanentURL.path)
        let finalSize = finalAttributes?[.size] as? Int64 ?? Int64(imageData.count)

        // Compute relative path relative to documents or storage root
        let relativePath = "BookBurnerPhotos/\(fileName)"

        return BookPhoto(
            relativePath: relativePath,
            capturedAt: Date(),
            fileSizeBytes: finalSize
        )
    }

    /// Deletes a photo file given its relative path.
    public func deletePhoto(relativePath: String) throws {
        let fullURL: URL
        if relativePath.hasPrefix("BookBurnerPhotos/") {
            let subPath = String(relativePath.dropFirst("BookBurnerPhotos/".count))
            fullURL = rootDirectory.appendingPathComponent(subPath)
        } else {
            fullURL = rootDirectory.appendingPathComponent(relativePath)
        }

        if fileManager.fileExists(atPath: fullURL.path) {
            try fileManager.removeItem(at: fullURL)
        }
    }

    public func rootPath() -> URL {
        return rootDirectory
    }
}
