import Foundation
import UniformTypeIdentifiers

public final class ExportService: ExportServiceProtocol, Sendable {
    public init() {}

    public func exportCollection(books: [BookCopy], photosDirectoryURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 1. Generate books.csv with robust RFC-4180 UTF-8 escaping
        let csvString = generateCSV(for: books)
        let csvURL = tempDir.appendingPathComponent("books.csv")
        try csvString.write(to: csvURL, atomically: true, encoding: .utf8)

        // 2. Generate books.json containing schema-versioned rich payload
        let exportRecords = books.map { ExportRecord(from: $0, dateFormatter: dateFormatter) }
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try jsonEncoder.encode(exportRecords)
        let jsonURL = tempDir.appendingPathComponent("books.json")
        try jsonData.write(to: jsonURL, options: [.atomic])

        // 3. Generate manifest.json
        let nowString = dateFormatter.string(from: Date())
        let manifest = ExportManifest(schemaVersion: "1.0", appVersion: "0.1.0", exportTimestamp: nowString, bookCount: books.count)
        let manifestData = try jsonEncoder.encode(manifest)
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestURL, options: [.atomic])

        // 4. Create photos/ folder and copy relative assets
        let exportPhotosDir = tempDir.appendingPathComponent("photos", isDirectory: true)
        try fileManager.createDirectory(at: exportPhotosDir, withIntermediateDirectories: true)

        for book in books {
            if let photo = book.photo {
                let sourcePhotoURL = photosDirectoryURL.appendingPathComponent(photo.relativePath)
                if fileManager.fileExists(atPath: sourcePhotoURL.path) {
                    let destPhotoURL = exportPhotosDir.appendingPathComponent(photo.relativePath)
                    // Ensure subdirectories (if any) are created
                    let parentDir = destPhotoURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: parentDir.path) {
                        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    }
                    if fileManager.fileExists(atPath: destPhotoURL.path) {
                        try fileManager.removeItem(at: destPhotoURL)
                    }
                    try fileManager.copyItem(at: sourcePhotoURL, to: destPhotoURL)
                }
            }
        }

        // 5. ZIP archive generation packaging books.csv, books.json, manifest.json, and photos/
        let dateFormatterFile = DateFormatter()
        dateFormatterFile.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatterFile.string(from: Date())
        let zipFileName = "BookBurner-\(dateString).zip"
        let outputZipURL = fileManager.temporaryDirectory.appendingPathComponent(zipFileName)

        if fileManager.fileExists(atPath: outputZipURL.path) {
            try fileManager.removeItem(at: outputZipURL)
        }

        // Use NSFileCoordinator or Process / compression utility, or FileManager coordinate/zip if available.
        // On iOS/macOS Foundation, archiveItem(at:to:shouldUseFileCoordination:) is available in iOS 16+/macOS 13+.
        try fileManager.coordinate(writingItemAt: tempDir, options: [.forUploading]) { zippedURL in
            if fileManager.fileExists(atPath: outputZipURL.path) {
                try fileManager.removeItem(at: outputZipURL)
            }
            try fileManager.copyItem(at: zippedURL, to: outputZipURL)
        }

        return outputZipURL
    }

    public func generateCSV(for books: [BookCopy]) -> String {
        let headers = ["BBID", "ISBN", "Title", "Author", "Publisher", "PublishedYear", "Status", "Location", "MetadataProvenance", "PhotoPath", "CapturedAt"]
        var lines: [String] = [headers.joined(separator: ",")]

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for book in books {
            let fields: [String?] = [
                book.bbidString,
                book.isbn,
                book.title,
                book.author,
                book.publisher,
                book.publishedYear.map { String($0) },
                book.status.rawValue,
                book.locationName,
                book.metadataProvenance,
                book.photo?.relativePath,
                dateFormatter.string(from: book.capturedAt)
            ]

            let escapedFields = fields.map { field -> String in
                guard let value = field else { return "" }
                return escapeCSVField(value)
            }
            lines.append(escapedFields.joined(separator: ","))
        }

        return lines.joined(separator: "\r\n")
    }

    private func escapeCSVField(_ field: String) -> String {
        // RFC-4180: If field contains commas, double quotes, or newlines/carriage returns, enclose in double quotes and escape internal double quotes by doubling them ("").
        let needsEscaping = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        if needsEscaping {
            let escapedValue = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedValue)\""
        }
        return field
    }
}
