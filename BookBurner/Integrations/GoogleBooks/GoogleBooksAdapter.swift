import Foundation

// Internal DTOs for Google Books API JSON schema (hidden from domain)
struct GoogleBooksResponseDTO: Codable {
    let totalItems: Int?
    let items: [GoogleBookItemDTO]?
}

struct GoogleBookItemDTO: Codable {
    let volumeInfo: GoogleVolumeInfoDTO?
}

struct GoogleVolumeInfoDTO: Codable {
    let title: String?
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let description: String?
    let pageCount: Int?
    let imageLinks: GoogleImageLinksDTO?
}

struct GoogleImageLinksDTO: Codable {
    let thumbnail: String?
    let smallThumbnail: String?
}

public actor GoogleBooksAdapter: BookMetadataProvider {
    public let providerName = "GoogleBooks"
    private let session: URLSession
    private let apiKey: String?
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        apiKey: String? = nil,
        baseURL: URL = URL(string: "https://www.googleapis.com/books/v1/volumes")!
    ) {
        self.session = session
        // Resolve API key from passed argument, environment variable, or Info.plist / xcconfig fallback
        let resolvedKey = apiKey ?? ProcessInfo.processInfo.environment["GOOGLE_BOOKS_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String
        self.apiKey = resolvedKey
        self.baseURL = baseURL
    }

    public func lookup(isbn: String) async throws -> BookMetadataResult {
        let cleanedISBN = ISBNDecoder.clean(isbn)
        guard !cleanedISBN.isEmpty else {
            return .error("Invalid empty ISBN")
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(cleanedISBN)")
        ]
        if let key = apiKey, !key.isEmpty {
            queryItems.append(URLQueryItem(name: "key", value: key))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            return .error("Invalid URL generated for Google Books lookup")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Non-HTTP response received from Google Books")
            }

            if httpResponse.statusCode == 404 || httpResponse.statusCode == 204 {
                return .notFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .error("Google Books returned status code \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(GoogleBooksResponseDTO.self, from: data)

            guard let items = decoded.items, let firstItem = items.first, let volumeInfo = firstItem.volumeInfo else {
                return .notFound
            }

            let title = volumeInfo.title ?? "Unknown Title"
            let authors = volumeInfo.authors ?? ["Unknown Author"]
            
            var thumbnailURL: URL? = nil
            if let thumbString = volumeInfo.imageLinks?.thumbnail ?? volumeInfo.imageLinks?.smallThumbnail {
                // Ensure https if http
                var secureThumb = thumbString
                if secureThumb.hasPrefix("http://") {
                    secureThumb = "https://" + secureThumb.dropFirst(7)
                }
                thumbnailURL = URL(string: secureThumb)
            }

            let metadata = BookMetadata(
                isbn: cleanedISBN,
                title: title,
                authors: authors,
                publisher: volumeInfo.publisher,
                publishedDate: volumeInfo.publishedDate,
                description: volumeInfo.description,
                pageCount: volumeInfo.pageCount,
                thumbnailURL: thumbnailURL,
                provenance: .googleBooks
            )

            return .success(metadata)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
