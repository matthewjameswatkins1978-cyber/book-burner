import SwiftUI

public struct BooksListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingExportSheet: Bool = false
    @State private var exportedZipURL: URL? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Status Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(for: .all, title: "All")
                    filterChip(for: .unresolved, title: "Unresolved")
                    filterChip(for: .lookupPending, title: "Lookup Pending")
                    filterChip(for: .needsReview, title: "Needs Review")
                    ForEach(appState.locations, id: \.id) { loc in
                        filterChip(for: .location(loc.name), title: loc.name)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))

            // Performant List
            List {
                ForEach(appState.filteredBooks) { book in
                    NavigationLink(destination: BookDetailView(book: book).environmentObject(appState)) {
                        BookItemRow(book: book)
                    }
                    .accessibilityIdentifier("BookRow-\(book.bbidString)")
                }
            }
            .searchable(text: $appState.searchText, prompt: "Search BBID, title, author, ISBN, location...")
            .accessibilityIdentifier("BooksSearchField")
        }
        .navigationTitle("Books (\(appState.filteredBooks.count))")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    do {
                        let photosDir = appState.photoStorage.baseDirectory
                        let zipURL = try appState.exportService.exportCollection(books: appState.books, photosDirectoryURL: photosDir)
                        exportedZipURL = zipURL
                        showingExportSheet = true
                    } catch {
                        // Handle export error
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityIdentifier("ExportShareButton")
                .accessibilityLabel("Export Collection")
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedZipURL {
                ExportShareExportActivityView(activityItems: [url])
            }
        }
    }

    private func filterChip(for filter: BookStatusFilter, title: String) -> some View {
        let isSelected = (appState.selectedStatusFilter == filter)
        return Button(action: {
            appState.selectedStatusFilter = filter
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .accessibilityIdentifier("FilterChip-\(title)")
    }
}

public struct BookItemRow: View {
    public let book: BookCopy

    public var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder / image
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray4))
                    .frame(width: 48, height: 64)
                Image(systemName: "book.fill")
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(book.title ?? "Untitled Book")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(book.bbidString)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }

                Text(book.author ?? "Unknown Author")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    Text(book.locationName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    statusBadge(for: book.status)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(for status: BookStatus) -> some View {
        let color: Color
        switch status {
        case .resolved: color = .green
        case .lookupPending: color = .orange
        case .needsReview: color = .red
        case .noISBN: color = .purple
        }

        return Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

public struct ExportShareExportActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
