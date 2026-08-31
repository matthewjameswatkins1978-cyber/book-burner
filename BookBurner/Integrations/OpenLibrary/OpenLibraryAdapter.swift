import Foundation

// Internal DTOs for Open Library Books API JSON schema
struct OpenLibraryBookResponseDTO: Codable {
    let title: String?
    let authors: [OpenLibraryAuthorDTO]?
    let publishers: [OpenLibraryPublisherDTO]?
    let publishDate: String?
    let numberOFPages: Int?
    let description: OpenLibraryDescriptionDTO?
    let cover: OpenLibraryCoverDTO?

    enum CodingKeys: String, CodingKey {
        case title
        case authors
        case publishers
        case publishDate = "publish_date"
        case numberOFPages = "number_of_pages"
        case description
        case cover
    }
}

struct OpenLibraryAuthorDTO: Codable {
    let name: String?
}

struct OpenLibraryPublisherDTO: Codable {
    let name: String?
}

struct OpenLibraryDescriptionDTO: Codable {
    let value: String?
}

struct OpenLibraryCoverDTO: Codable {
    let small: String?
    let medium: String?
    let large: String?
}

public actor OpenLibraryAdapter: BookMetadataProvider {
    public let providerName = "OpenLibrary"
    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://openlibrary.org/api/books")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func lookup(isbn: String) async throws -> BookMetadataResult {
        let cleanedISBN = ISBNDecoder.clean(isbn)
        guard !cleanedISBN.isEmpty else {
            return .error("Invalid empty ISBN")
        }

        // Open Library Books API format: https://openlibrary.org/api/books?bibkeys=ISBN:0306406152&format=json&jscmd=data
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(cleanedISBN)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data")
        ]

        guard let url = components?.url else {
            return .error("Invalid URL generated for Open Library lookup")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Non-HTTP response received from Open Library")
            }

            if httpResponse.statusCode == 404 || httpResponse.statusCode == 204 {
                return .notFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .error("Open Library returned status code \(httpResponse.statusCode)")
            }

            // Open Library returns a dictionary where key is "ISBN:<isbn>"
            let decoder = JSONDecoder()
            guard let jsonDict = try? decoder.decode([String: OpenLibraryBookResponseDTO].self, from: data),
                  let bookDTO = jsonDict["ISBN:\(cleanedISBN)"] ?? jsonDict["isbn:\(cleanedISBN)"] ?? jsonDict.values.first else {
                return .notFound
            }

            let title = bookDTO.title ?? "Unknown Title"
            let authors = bookDTO.authors?.compactMap { $0.name } ?? ["Unknown Author"]
            let publisher = bookDTO.publishers?.first?.name
            let descriptionVal = bookDTO.description?.value
            
            var thumbnailURL: URL? = nil
            if let coverLarge = bookDTO.cover?.large ?? bookDTO.cover?.medium ?? bookDTO.cover?.small {
                var secureCover = coverLarge
                if secureCover.hasPrefix("http://") {
                    secureCover = "https://" + secureCover.dropFirst(7)
                }
                thumbnailURL = URL(string: secureCover)
            }

            let metadata = BookMetadata(
                isbn: cleanedISBN,
                title: title,
                authors: authors,
                publisher: publisher,
                publishedDate: bookDTO.publishDate,
                description: descriptionVal,
                pageCount: bookDTO.numberOFPages,
                thumbnailURL: thumbnailURL,
                provenance: .openLibrary
            )

            return .success(metadata)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
