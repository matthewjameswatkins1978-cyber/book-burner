import SwiftUI
import SwiftData

@main
struct BookBurnerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
        }
        .modelContainer(for: [PersistedBookCopy.self, PersistedLocation.self])
    }
}

public final class AppState: ObservableObject {
    @Published public var books: [BookCopy] = []
    @Published public var locations: [StorageLocation] = [
        StorageLocation(name: "Unassigned"),
        StorageLocation(name: "Box 1"),
        StorageLocation(name: "Office Shelf")
    ]
    @Published public var activeLocation: StorageLocation {
        didSet {
            captureStateMachine.setActiveLocation(name: activeLocation.name, id: activeLocation.id)
        }
    }
    @Published public var searchText: String = ""
    @Published public var selectedStatusFilter: BookStatusFilter = .all

    public let captureStateMachine: CaptureStateMachine
    public let bbidAllocator: BBIDAllocator
    public let photoStorage: AtomicPhotoStorageService
    public let exportService: ExportService

    public init() {
        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDir = docsDir.appendingPathComponent("Photos", isDirectory: true)
        try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        self.photoStorage = AtomicPhotoStorageService(fileManager: fileManager, baseDirectory: photosDir)
        self.bbidAllocator = BBIDAllocator(defaults: UserDefaults(suiteName: "BookBurnerPrefs") ?? .standard)
        
        let initialLoc = locations.first!
        self.activeLocation = initialLoc

        self.captureStateMachine = CaptureStateMachine(
            bbidAllocator: bbidAllocator,
            photoStorage: photoStorage,
            initialLocationName: initialLoc.name,
            initialLocationID: initialLoc.id
        )
        self.exportService = ExportService()
    }

    public func addBook(_ book: BookCopy) {
        books.append(book)
    }

    public func updateBook(_ book: BookCopy) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        }
    }

    public func deleteBook(id: UUID) {
        books.removeAll { $0.id == id }
    }

    public var filteredBooks: [BookCopy] {
        return books.filter { book in
            // Status filter
            let matchesStatus: Bool
            switch selectedStatusFilter {
            case .all:
                matchesStatus = true
            case .unresolved:
                matchesStatus = (book.status != .resolved)
            case .lookupPending:
                matchesStatus = (book.status == .lookupPending)
            case .needsReview:
                matchesStatus = (book.status == .needsReview || book.status == .noISBN)
            case .location(let locName):
                matchesStatus = (book.locationName.localizedCaseInsensitiveCompare(locName) == .orderedSame)
            }

            guard matchesStatus else { return false }

            // Search text filter across BBID, title, author, ISBN, publisher, location
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            let bbidMatch = book.bbidString.lowercased().contains(query)
            let titleMatch = book.title?.lowercased().contains(query) ?? false
            let authorMatch = book.author?.lowercased().contains(query) ?? false
            let isbnMatch = book.isbn?.lowercased().contains(query) ?? false
            let publisherMatch = book.publisher?.lowercased().contains(query) ?? false
            let locationMatch = book.locationName.lowercased().contains(query)

            return bbidMatch || titleMatch || authorMatch || isbnMatch || publisherMatch || locationMatch
        }
    }
}

public enum BookStatusFilter: Hashable, Sendable {
    case all
    case unresolved
    case lookupPending
    case needsReview
    case location(String)

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .unresolved: return "Unresolved"
        case .lookupPending: return "Lookup Pending"
        case .needsReview: return "Needs Review"
        case .location(let name): return "Location: \(name)"
        }
    }
}

@Model
public final class PersistedBookCopy {
    @Attribute(.unique) public var id: UUID
    public var bbidString: String
    public var isbn: String?
    public var title: String?
    public var author: String?
    public var publisher: String?
    public var publishedYear: Int?
    public var statusRaw: String
    public var locationID: UUID?
    public var locationName: String
    public var photoRelativePath: String?
    public var photoSize: Int64?
    public var metadataProvenance: String?
    public var capturedAt: Date

    public init(book: BookCopy) {
        self.id = book.id
        self.bbidString = book.bbidString
        self.isbn = book.isbn
        self.title = book.title
        self.author = book.author
        self.publisher = book.publisher
        self.publishedYear = book.publishedYear
        self.statusRaw = book.status.rawValue
        self.locationID = book.locationID
        self.locationName = book.locationName
        self.photoRelativePath = book.photo?.relativePath
        self.photoSize = book.photo?.fileSizeBytes
        self.metadataProvenance = book.metadataProvenance
        self.capturedAt = book.capturedAt
    }

    public func toBookCopy() -> BookCopy {
        let photo: BookPhoto? = photoRelativePath.map { BookPhoto(relativePath: $0, fileSizeBytes: photoSize ?? 0) }
        let status = BookStatus(rawValue: statusRaw) ?? .lookupPending
        return BookCopy(
            id: id,
            bbid: BBID(string: bbidString) ?? BBID(rawValue: 1),
            isbn: isbn,
            title: title,
            author: author,
            publisher: publisher,
            publishedYear: publishedYear,
            status: status,
            locationID: locationID,
            locationName: locationName,
            photo: photo,
            metadataProvenance: metadataProvenance,
            capturedAt: capturedAt
        )
    }
}

@Model
public final class PersistedLocation {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var notes: String?
    public var createdAt: Date

    public init(location: StorageLocation) {
        self.id = location.id
        self.name = location.name
        self.notes = location.notes
        self.createdAt = location.createdAt
    }

    public func toStorageLocation() -> StorageLocation {
        StorageLocation(id: id, name: name, notes: notes, createdAt: createdAt)
    }
}
